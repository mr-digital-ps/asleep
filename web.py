import sys
import os
from pathlib import Path

# Гарантируем корректный sys.path независимо от текущей рабочей директории запуска
PROJECT_DIR = Path(__file__).parent.resolve()
if str(PROJECT_DIR) not in sys.path:
    sys.path.insert(0, str(PROJECT_DIR))

# Предотвращаем сбой загрузки отсутствующего плагина qtquickcontrols2windowsstyleimplplugin.dll
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

from PyQt6.QtWidgets import QApplication
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtCore import QObject, pyqtSlot, pyqtSignal, QFileSystemWatcher, QTimer, QUrl, QEvent, Qt
from PyQt6.QtGui import QWindow, QTextCursor, QTextOption, QFontDatabase
from PyQt6.QtQuick import QQuickTextDocument


import json
from services.block_engine import BlockEngine, replace_block_in_markdown
from services.window_manager import WindowManager
from services.file_service import FileService, save_session_config, load_session_config
from services.config_service import ConfigService
from services.syntax_highlighter import MarkdownHighlighter
from services.hotkey_service import HotkeyService
from services.graph_service import GraphService
from services.reloader import setup_live_reload


# Обеспечиваем корректный вывод UTF-8 в консоль Windows
if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if sys.stderr and hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

def _safe_print(*args, **kwargs):
    try:
        print(*args, **kwargs)
    except Exception:
        pass


class Backend(QObject):
    """
    Главный фасад для взаимодействия Python бэкенда и интерфейса QML.
    Делегирует задачи в специализированные сервисы.
    """
    folderFilesChanged = pyqtSignal()
    blockUpdated = pyqtSignal(str, str, str)  # (heading_norm, content, source_file_url)
    configUpdated = pyqtSignal(str)  # JSON-строка актуальной конфигурации
    hotkeysChanged = pyqtSignal()
    graphDataChanged = pyqtSignal()
    themeConfigChanged = pyqtSignal()
    appConfigChanged = pyqtSignal()

    def __init__(self):
        super().__init__()
        self.block_engine = BlockEngine()
        self.file_service = FileService()
        self.window_manager = WindowManager()
        self.config_service = ConfigService()
        self.hotkey_service = HotkeyService()
        self.graph_service = GraphService(self.block_engine, self.file_service)
        self.hotkey_service.hotkeys_changed.connect(lambda _: self.hotkeysChanged.emit())

        self.folder_watcher = QFileSystemWatcher(self)
        self.folder_watcher.directoryChanged.connect(self._on_directory_changed)
        self._current_folder: Path = None
        self._is_syncing_files = False
        self._last_config_mtime: int = 0

        self.config_watcher = QFileSystemWatcher(self)
        self.config_watcher.fileChanged.connect(self._on_config_file_changed)
        self.config_watcher.directoryChanged.connect(self._on_config_dir_changed)

        config_dir = self.config_service.config_dir
        if config_dir.exists():
            self.config_watcher.addPath(str(config_dir))
            for sub in [config_dir / "default", config_dir / "user"]:
                if sub.exists():
                    self.config_watcher.addPath(str(sub))
            for f in config_dir.rglob("*.json"):
                self.config_watcher.addPath(str(f))

    def _on_config_dir_changed(self, path: str):
        config_dir = Path(path)
        if config_dir.exists():
            for sub in [config_dir / "default", config_dir / "user"]:
                if sub.exists() and str(sub) not in self.config_watcher.directories():
                    self.config_watcher.addPath(str(sub))
            for f in config_dir.rglob("*.json"):
                f_str = str(f)
                if f_str not in self.config_watcher.files():
                    self.config_watcher.addPath(f_str)

    def _on_config_file_changed(self, path: str):
        p = Path(path)
        if p.exists() and path not in self.config_watcher.files():
            self.config_watcher.addPath(path)

        name = p.name.lower()
        if "graph" in name:
            self.graphDataChanged.emit()
        elif "hotkey" in name:
            self.hotkey_service._reload_timer.start()
        elif "theme" in name:
            self.themeConfigChanged.emit()
        elif "editor" in name:
            self.config_service.load_folder_config(self._current_folder)
            self.configUpdated.emit(json.dumps(self.config_service.current_config))
        elif "app" in name:
            self.appConfigChanged.emit()

    def _on_directory_changed(self, path: str):
        if not self._is_syncing_files and self._current_folder:
            self.block_engine.reindex_folder(self._current_folder)
            cfg_path = self.config_service.get_config_file_path(self._current_folder)
            if cfg_path and cfg_path.exists():
                cur_mtime = cfg_path.stat().st_mtime_ns
                if self._last_config_mtime > 0 and cur_mtime != self._last_config_mtime:
                    self._last_config_mtime = cur_mtime
                    self.config_service.load_folder_config(self._current_folder)
                    self.configUpdated.emit(json.dumps(self.config_service.current_config))
                elif self._last_config_mtime == 0:
                    self._last_config_mtime = cur_mtime

            # Фоновая проекция структуры связей в _Граф связей.md
            try:
                self._is_syncing_files = True
                self.graph_service.sync_graph_markdown_file(self._current_folder)
            except Exception as e:
                _safe_print(f"[Backend] Ошибка синхронизации графа связей: {e}")
            finally:
                self._is_syncing_files = False

        self.folderFilesChanged.emit()
        self.graphDataChanged.emit()

    # --- WindowManager Facade ---
    @pyqtSlot(QObject, QObject)
    def register_window(self, win: QObject, root_item: QObject):
        self.window_manager.register_window(win, root_item)

    @pyqtSlot(QObject)
    def unregister_window(self, win: QObject):
        self.window_manager.unregister_window(win)

    @pyqtSlot(float, float, QObject, QObject, result="QVariantMap")
    @pyqtSlot(float, float, QObject, result="QVariantMap")
    def find_target_window_at(self, gx: float, gy: float, exclude_win: QObject = None, exclude_win2: QObject = None) -> dict:
        return self.window_manager.find_target_window_at(gx, gy, exclude_win, exclude_win2)

    @pyqtSlot(QObject, str)
    def set_window_drop_zone(self, win: QObject, zone: str):
        self.window_manager.set_window_drop_zone(win, zone)

    @pyqtSlot()
    def clear_all_drop_zones(self):
        self.window_manager.clear_all_drop_zones()

    # --- FileService Facade ---
    @pyqtSlot(str)
    def watch_folder(self, folder_url: str):
        """Отслеживает изменения файлов в рабочей папке"""
        try:
            folder = self.file_service.to_path(folder_url)
            self._current_folder = folder
            existing = self.folder_watcher.directories()
            if existing:
                self.folder_watcher.removePaths(existing)
            if folder.exists() and folder.is_dir():
                self.folder_watcher.addPath(str(folder.resolve()))
                self.block_engine.reindex_folder(folder)
                self.config_service.load_folder_config(folder)
                cfg_path = self.config_service.get_config_file_path(folder)
                if cfg_path and cfg_path.exists():
                    self._last_config_mtime = cfg_path.stat().st_mtime_ns
                self.configUpdated.emit(json.dumps(self.config_service.current_config))

                # Первичная генерация _Граф связей.md при открытии каталога
                try:
                    self._is_syncing_files = True
                    self.graph_service.sync_graph_markdown_file(folder)
                except Exception as e:
                    _safe_print(f"[Backend] Ошибка создания _Граф связей.md: {e}")
                finally:
                    self._is_syncing_files = False
        except Exception as e:
            print(f"[Backend] Ошибка отслеживания папки: {e}")

    @pyqtSlot(str, result="QVariantList")
    def get_folder_files(self, folder_url: str) -> list:
        return self.file_service.get_folder_files(folder_url)

    @pyqtSlot(str, result=bool)
    def delete_file(self, file_url: str) -> bool:
        success = self.file_service.delete_file(file_url)
        if success:
            self.folderFilesChanged.emit()
        return success

    @pyqtSlot(str, result=str)
    def read_file(self, file_url: str) -> str:
        return self.file_service.read_file(file_url)

    @pyqtSlot(str, str, result=bool)
    def save_file(self, file_url: str, text: str) -> bool:
        path = self.file_service.to_path(file_url)
        if path.exists():
            try:
                if path.read_text(encoding="utf-8") == text:
                    return True
            except Exception:
                pass

        success = self.file_service.save_file(file_url, text)
        if success:
            self.block_engine.index_file_content(file_url, text)
            if self.config_service.is_config_filename(path.name):
                new_cfg = self.config_service.parse_and_update(text)
                cfg_path = self.config_service.get_config_file_path(path.parent)
                if cfg_path and cfg_path.exists():
                    self._last_config_mtime = cfg_path.stat().st_mtime_ns
                self.configUpdated.emit(json.dumps(new_cfg))
                _safe_print(f"[ConfigService] Конфигурация обновлена из {path.name}")
            
            fn = path.name.lower()
            if "graph" in fn:
                self.graphDataChanged.emit()
            elif "hotkey" in fn:
                self.hotkey_service._reload_timer.start()
            elif "theme" in fn:
                self.themeConfigChanged.emit()
            elif "editor" in fn:
                self.config_service.load_folder_config(self._current_folder)
                self.configUpdated.emit(json.dumps(self.config_service.current_config))
            elif "app" in fn:
                self.appConfigChanged.emit()

            self.folderFilesChanged.emit()
        return success

    @pyqtSlot(str, str, result="QVariantMap")
    def create_file_in_folder(self, folder_url: str, base_name: str = "Новый документ") -> dict:
        res = self.file_service.create_file_in_folder(folder_url, base_name)
        if res.get("success"):
            self.folderFilesChanged.emit()
        return res

    @pyqtSlot(str, str, result="QVariantMap")
    def rename_file(self, file_url: str, new_name: str) -> dict:
        res = self.file_service.rename_file(file_url, new_name)
        if res.get("success"):
            self.folderFilesChanged.emit()
        return res

    @pyqtSlot(str, result=str)
    def get_filename(self, file_url: str) -> str:
        return self.file_service.to_path(file_url).name or "Новый файл"

    @pyqtSlot(result=str)
    def get_default_folder(self) -> str:
        return self.file_service.get_default_folder()

    @pyqtSlot(str)
    def save_last_folder(self, folder_url: str):
        if folder_url:
            save_session_config({"last_folder": folder_url})

    @pyqtSlot(str, result=str)
    def get_folder_name(self, folder_url: str) -> str:
        path = self.file_service.to_path(folder_url)
        return path.name or str(path) or "Заметки"

    @pyqtSlot(result="QVariantMap")
    @pyqtSlot(str, result="QVariantMap")
    def choose_folder_dialog(self, initial_folder: str = "") -> dict:
        res = self.file_service.choose_folder_dialog(initial_folder)
        if res.get("success"):
            url = res.get("folderUrl", "")
            self.watch_folder(url)
            self.folderFilesChanged.emit()
        return res

    # --- BlockEngine Facade ---
    @pyqtSlot(str, str, str)
    def sync_block(self, source_file_url: str, heading: str, content: str):
        """Синхронизирует блок между открытыми редакторами и файлами на диске"""
        norm, clean_content, should_sync = self.block_engine.sync_block_data(source_file_url, heading, content)
        if not should_sync:
            return

        # Оповещаем UI для мгновенного обновления открытых редакторов
        self.blockUpdated.emit(norm, clean_content, source_file_url)

        # Обновляем остальные файлы в папке на диске
        if not self._current_folder or not self._current_folder.exists():
            return

        source_path = None
        if source_file_url:
            try:
                source_path = self.file_service.to_path(source_file_url).resolve()
            except Exception:
                pass

        self._is_syncing_files = True
        try:
            for p in self._current_folder.iterdir():
                if not p.is_file() or p.suffix.lower() not in [".md", ".markdown", ".txt"]:
                    continue
                if source_path and p.resolve() == source_path:
                    continue
                try:
                    file_text = p.read_text(encoding="utf-8")
                    new_text, modified = replace_block_in_markdown(file_text, norm, clean_content)
                    if modified and new_text != file_text:
                        p.write_text(new_text, encoding="utf-8")
                        _safe_print(f"[SyncBlock] Синхронизирован блок '{heading}' в файл: {p.name}")
                except Exception as ex:
                    _safe_print(f"[SyncBlock] Ошибка синхронизации {p.name}: {ex}")
        finally:
            self._is_syncing_files = False

    @pyqtSlot(str, result="QVariantMap")
    def get_block(self, heading: str) -> dict:
        return self.block_engine.get_block(heading)

    @pyqtSlot(result="QVariantList")
    @pyqtSlot(str, result="QVariantList")
    def get_available_blocks(self, query: str = "") -> list:
        return self.block_engine.get_available_blocks(query)

    # --- ConfigService Facade ---
    @pyqtSlot(result=str)
    def get_current_config(self) -> str:
        return json.dumps(self.config_service.current_config)

    @pyqtSlot(str, result="QVariantMap")
    @pyqtSlot(result="QVariantMap")
    def open_or_create_folder_config(self, folder_url: str = "") -> dict:
        folder = self.file_service.to_path(folder_url) if folder_url else self._current_folder
        if not folder or not folder.exists():
            return {"success": False, "error": "Рабочая папка не выбрана"}
        config_path = self.config_service.ensure_folder_config(folder)
        file_url = QUrl.fromLocalFile(str(config_path.resolve())).toString()
        self.folderFilesChanged.emit()
        return {
            "success": True,
            "fileUrl": file_url,
            "fileName": config_path.name
        }

    @pyqtSlot(str, result=bool)
    def is_config_file(self, file_url: str) -> bool:
        path = self.file_service.to_path(file_url)
        return self.config_service.is_config_filename(path.name)

    @pyqtSlot(QObject, float)
    @pyqtSlot(QObject)
    def set_editor_line_height(self, editor_area_item: QObject, percent: float = 100.0):
        """Устанавливает высоту строки пропорционально размеру шрифта (ProportionalHeight)"""
        try:
            if not editor_area_item:
                return
            doc_wrapper = editor_area_item.property("textDocument")
            if isinstance(doc_wrapper, QQuickTextDocument):
                qtdoc = doc_wrapper.textDocument()
                cursor = QTextCursor(qtdoc)
                cursor.select(QTextCursor.SelectionType.Document)
                bf = cursor.blockFormat()
                # 1 = QTextBlockFormat.LineHeightTypes.ProportionalHeight
                # percent, например 135.0 (135%) или 200.0 (200%)
                target_percent = float(percent) if (percent and percent > 0) else 135.0
                bf.setLineHeight(target_percent, 1)
                cursor.setBlockFormat(bf)
                opt = qtdoc.defaultTextOption()
                opt.setFlags(opt.flags() | QTextOption.Flag.AddSpaceForLineAndParagraphSeparators)
                qtdoc.setDefaultTextOption(opt)
        except Exception as e:
            _safe_print(f"[Backend] Ошибка установки line_height: {e}")

    @pyqtSlot(QObject)
    def attach_highlighter(self, editor_area_item: QObject):
        """Подключает подсветку синтаксиса Markdown к документу TextArea"""
        try:
            if not editor_area_item:
                return
            doc_wrapper = editor_area_item.property("textDocument")
            if isinstance(doc_wrapper, QQuickTextDocument):
                qtdoc = doc_wrapper.textDocument()
                if not hasattr(qtdoc, "_highlighter") or qtdoc._highlighter is None:
                    qtdoc._highlighter = MarkdownHighlighter(qtdoc)
                    _safe_print("[Backend] MarkdownHighlighter успешно подключен")
        except Exception as e:
            _safe_print(f"[Backend] Ошибка подключения MarkdownHighlighter: {e}")


    @pyqtSlot(float)
    def update_sheet_width(self, width: float):
        """Сохраняет текущую ширину листа в конфигурацию сессии и папку"""
        w = int(width)
        if "editor" in self.config_service.current_config:
            self.config_service.current_config["editor"]["sheet_width"] = w
        save_session_config({"sheet_width": w})
        if self._current_folder:
            new_mtime = self.config_service.update_folder_editor_setting(self._current_folder, "sheet_width", w)
            if new_mtime > 0:
                self._last_config_mtime = new_mtime

    @pyqtSlot(int)
    def update_font_size(self, font_size: int):
        """Сохраняет текущий размер шрифта в конфигурацию сессии и папку"""
        sz = int(font_size)
        if "editor" in self.config_service.current_config:
            self.config_service.current_config["editor"]["font_size"] = sz
        save_session_config({"font_size": sz})
        if self._current_folder:
            new_mtime = self.config_service.update_folder_editor_setting(self._current_folder, "font_size", sz)
            if new_mtime > 0:
                self._last_config_mtime = new_mtime


    @pyqtSlot(float, float, float, float)
    def save_window_geometry(self, x: float, y: float, w: float, h: float):
        """Сохраняет геометрию главного окна в сессию"""
        save_session_config({
            "win_x": int(x),
            "win_y": int(y),
            "win_width": int(w),
            "win_height": int(h)
        })

    @pyqtSlot(float)
    def save_sidebar_width(self, width: float):
        """Сохраняет ширину сайдбара в сессию"""
        save_session_config({"sidebar_width": int(width)})

    @pyqtSlot(bool)
    def save_header_pinned(self, pinned: bool):
        """Сохраняет состояние закрепления верхнего заголовка в сессию"""
        save_session_config({"header_pinned": bool(pinned)})

    @pyqtSlot(bool)
    def save_footer_pinned(self, pinned: bool):
        """Сохраняет состояние закрепления нижнего статус-бара в сессию"""
        save_session_config({"footer_pinned": bool(pinned)})

    @pyqtSlot(bool)
    def save_header_visible(self, visible: bool):
        """Сохраняет видимость верхнего заголовка в сессию"""
        save_session_config({"header_visible": bool(visible)})

    @pyqtSlot(bool)
    def save_footer_visible(self, visible: bool):
        """Сохраняет видимость нижнего статус-бара в сессию"""
        save_session_config({"footer_visible": bool(visible)})

    @pyqtSlot(result="QVariantMap")
    def get_session_config(self) -> dict:
        """Возвращает параметры сохраненной сессии"""
        return load_session_config()

    @pyqtSlot(result="QVariantMap")
    def get_hotkeys(self) -> dict:
        """Возвращает конфигурацию горячих клавиш"""
        return self.hotkey_service.get_hotkeys()

    @pyqtSlot(result="QVariantList")
    def get_flat_shortcuts(self) -> list:
        """Возвращает плоский список шорткатов для привязки в QML"""
        return self.hotkey_service.get_flat_shortcuts()

    @pyqtSlot(str, result="QVariantList")
    def get_action_keys(self, action: str) -> list:
        """Возвращает комбинации клавиш для указанного действия"""
        return self.hotkey_service.get_action_keys(action)

    @pyqtSlot(result="QVariantMap")
    @pyqtSlot(str, result="QVariantMap")
    def get_graph_data(self, folder_url: str = "") -> dict:
        """Возвращает узлы и связи графа для текущей или указанной рабочей папки"""
        folder = self.file_service.to_path(folder_url) if folder_url else self._current_folder
        return self.graph_service.build_graph(folder)

    @pyqtSlot(result="QVariantMap")
    @pyqtSlot(str, result="QVariantMap")
    def sync_graph_file(self, folder_url: str = "") -> dict:
        """Синхронизирует _Граф связей.md в рабочей папке и возвращает метаданные для открытия"""
        folder = self.file_service.to_path(folder_url) if folder_url else self._current_folder
        if not folder or not folder.exists() or not folder.is_dir():
            return {}
        try:
            self._is_syncing_files = True
            p = self.graph_service.sync_graph_markdown_file(folder)
            if p and p.exists():
                return {
                    "fileUrl": QUrl.fromLocalFile(str(p.resolve())).toString(),
                    "fileName": p.name,
                    "filePath": str(p)
                }
        except Exception as e:
            _safe_print(f"[Backend] Ошибка sync_graph_file: {e}")
        finally:
            self._is_syncing_files = False
        return {}

    @pyqtSlot(result="QVariantMap")
    @pyqtSlot(str, result="QVariantMap")
    def get_graph_config(self, folder_url: str = "") -> dict:
        """Возвращает текущую объединенную конфигурацию физики и визуала графа"""
        folder = self.file_service.to_path(folder_url) if folder_url else self._current_folder
        return self.graph_service.get_config(folder)

    @pyqtSlot(result="QVariantMap")
    @pyqtSlot(str, result="QVariantMap")
    def get_theme_config(self, folder_url: str = "") -> dict:
        """Возвращает актуальные настройки темы и интерфейса"""
        folder = self.file_service.to_path(folder_url) if folder_url else self._current_folder
        return self.config_service.get_theme_config(folder)

    @pyqtSlot(result="QVariantMap")
    @pyqtSlot(str, result="QVariantMap")
    def get_editor_config(self, folder_url: str = "") -> dict:
        """Возвращает актуальные настройки редактора из config/editor_*.json"""
        folder = self.file_service.to_path(folder_url) if folder_url else self._current_folder
        return self.config_service.get_editor_config(folder)

    @pyqtSlot(result="QVariantMap")
    @pyqtSlot(str, result="QVariantMap")
    def get_app_config(self, folder_url: str = "") -> dict:
        """Возвращает актуальные системные настройки приложения"""
        folder = self.file_service.to_path(folder_url) if folder_url else self._current_folder
        return self.config_service.get_app_config(folder)



def load_application_fonts():
    """Сканирует папку fonts/ в корне проекта и регистрирует все TTF/OTF шрифты в QFontDatabase."""
    fonts_dir = PROJECT_DIR / "fonts"
    if not fonts_dir.exists():
        fonts_dir.mkdir(exist_ok=True)
        return
    for ext in ["*.ttf", "*.otf", "*.TTF", "*.OTF"]:
        for font_file in fonts_dir.glob(ext):
            font_id = QFontDatabase.addApplicationFont(str(font_file.resolve()))
            if font_id != -1:
                families = QFontDatabase.applicationFontFamilies(font_id)
                _safe_print(f"[Fonts] Загружен шрифт '{font_file.name}': {', '.join(families)}")
            else:
                _safe_print(f"[Fonts] Не удалось загрузить шрифт '{font_file.name}'")


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("Asleep Text Editor")
    app.setOrganizationName("Asleep")

    load_application_fonts()

    engine = QQmlApplicationEngine()
    engine.addImportPath(str(PROJECT_DIR))
    engine.addImportPath(str(PROJECT_DIR / "components"))
    backend = Backend()
    engine.rootContext().setContextProperty("backend", backend)

    qml_file = Path(__file__).parent.resolve() / "views" / "window.qml"
    engine.load(QUrl.fromLocalFile(str(qml_file)))

    if not engine.rootObjects():
        print("[Python] Критическая ошибка: Не удалось загрузить окно QML!")
        sys.exit(-1)

    setup_live_reload(engine, qml_file)
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
