# services/backend/main_backend.py — Главный фасад бэкенда для взаимодействия с QML
import json
from pathlib import Path
from PyQt6.QtCore import QObject, pyqtSlot, pyqtSignal, QFileSystemWatcher, QCoreApplication

from services.content.block_parser import BlockEngine, replace_syntax_block
from services.system.window_manager import WindowManager
from services.storage.file_service import FileService
from services.storage.config_service import ConfigService
from services.system.hotkey_service import HotkeyService, GlobalHotkeyFilter
from services.graph_service import GraphService
from services.history_service import HistoryService
from services.content.outline_service import OutlineService
from services.content.document_session import DocumentSession

from services.backend.app_initializer import safe_print, configure_app_font
from services.backend.file_handler import FileHandlerMixin
from services.backend.config_handler import ConfigHandlerMixin
from services.backend.outline_handler import OutlineHandlerMixin
from services.backend.graph_history_handler import GraphHistoryHandlerMixin


class Backend(
    QObject,
    FileHandlerMixin,
    ConfigHandlerMixin,
    OutlineHandlerMixin,
    GraphHistoryHandlerMixin,
):
    """
    Главный фасад для взаимодействия Python бэкенда и интерфейса QML.
    Делегирует задачи в специализированные сервисы и миксины.
    """
    folderFilesChanged = pyqtSignal()
    blockUpdated = pyqtSignal(str, str, str)  # (heading_norm, content, source_file_url)
    configUpdated = pyqtSignal(str)  # JSON-строка актуальной конфигурации
    hotkeysChanged = pyqtSignal()
    actionRequested = pyqtSignal(str)  # Глобальное действие от хоткеев (toggle_graph, close_tab и др.)
    graphDataChanged = pyqtSignal()
    themeConfigChanged = pyqtSignal()
    appConfigChanged = pyqtSignal()
    historyUpdated = pyqtSignal()
    noteOpened = pyqtSignal(str, str)  # (file_url, block_name) — прямой фасад навигации по ссылкам

    def __init__(self):
        super().__init__()
        self.config_service = ConfigService()
        self.block_engine = BlockEngine(self.config_service)
        self.file_service = FileService(self.config_service)
        self.window_manager = WindowManager()
        self.hotkey_service = HotkeyService()
        self.graph_service = GraphService(self.block_engine, self.file_service, self.config_service)
        self.history_service = HistoryService(self.file_service, self.graph_service)
        self.outline_service = OutlineService()

        self.hotkey_service.hotkeys_changed.connect(lambda _: self.hotkeysChanged.emit())
        self.hotkey_filter = GlobalHotkeyFilter(self.hotkey_service, self)
        _core_app = QCoreApplication.instance()
        if _core_app:
            _core_app.installEventFilter(self.hotkey_filter)

        self.folder_watcher = QFileSystemWatcher(self)
        self.folder_watcher.directoryChanged.connect(self._on_directory_changed)
        self._current_folder: Path | None = None
        self._is_syncing_files = False
        self._last_config_mtime: int = 0
        self._last_user_files_snapshot: dict = {}

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

    def _get_user_files_snapshot(self) -> dict:
        if not self._current_folder or not self._current_folder.exists() or not self._current_folder.is_dir():
            return {}
        try:
            exts = self.file_service.get_supported_extensions(self._current_folder)
            md_cfg = self.config_service.get_syntax_config(self._current_folder) or {}
            sys_cfg = md_cfg.get("system_files", {})
            graph_file = sys_cfg.get("graph_file", "_Граф связей.txt")
            struct_file = sys_cfg.get("structure_file", "_notes.txt")
            ignore_pfx = tuple(sys_cfg.get("ignore_prefixes", [".", "_"]))
            snap = {}
            for p in self._current_folder.rglob("*"):
                if p.is_file() and p.suffix.lower() in exts:
                    rel_parts = p.relative_to(self._current_folder).parts
                    if not any(part.startswith(ignore_pfx) for part in rel_parts) and p.name != graph_file and p.name != struct_file:
                        snap[str(p.relative_to(self._current_folder))] = p.stat().st_mtime_ns
            return snap
        except Exception:
            return {}

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
            configure_app_font()
            self.themeConfigChanged.emit()
        elif "editor" in name:
            self.config_service.load_folder_config(self._current_folder)
            self.configUpdated.emit(json.dumps(self.config_service.current_config))
        elif "app" in name:
            self.appConfigChanged.emit()

    def _on_directory_changed(self, path: str):
        if self._is_syncing_files or not self._current_folder:
            return

        new_snapshot = self._get_user_files_snapshot()
        cfg_path = self.config_service.get_config_file_path(self._current_folder)
        cfg_changed = False
        if cfg_path and cfg_path.exists():
            cur_mtime = cfg_path.stat().st_mtime_ns
            if self._last_config_mtime > 0 and cur_mtime != self._last_config_mtime:
                self._last_config_mtime = cur_mtime
                self.config_service.load_folder_config(self._current_folder)
                self.configUpdated.emit(json.dumps(self.config_service.current_config))
                cfg_changed = True
            elif self._last_config_mtime == 0:
                self._last_config_mtime = cur_mtime

        # Если файлы заметок не изменились — не перестраиваем граф
        if new_snapshot == self._last_user_files_snapshot and not cfg_changed:
            return

        self._last_user_files_snapshot = new_snapshot
        self.graph_service.invalidate_cache(self._current_folder)
        exts = self.file_service.get_supported_extensions(self._current_folder)
        self.block_engine.reindex_folder(self._current_folder, exts)

        # Синхронизация структуры проекта при обнаружении изменений в файлах
        try:
            self.sync_project_structure_file()
        except Exception as e:
            safe_print(f"[Backend] Ошибка sync_project_structure_file в _on_directory_changed: {e}")

        self.folderFilesChanged.emit()
        self.graphDataChanged.emit()

    # --- WindowManager Facade ---
    @pyqtSlot(QObject, QObject)
    def register_window(self, win: QObject, root_item: QObject):
        self.window_manager.register_window(win, root_item)

    @pyqtSlot(result=int)
    def get_window_count(self) -> int:
        return len(self.window_manager.get_windows())

    @pyqtSlot(QObject)
    def unregister_window(self, win: QObject):
        self.window_manager.unregister_window(win)

    @pyqtSlot(float, float, QObject, QObject, result="QVariantMap")
    @pyqtSlot(float, float, QObject, result="QVariantMap")
    def find_target_window_at(self, gx: float, gy: float, exclude_win: QObject | None = None, exclude_win2: QObject | None = None) -> dict:
        return self.window_manager.find_target_window_at(gx, gy, exclude_win, exclude_win2)

    @pyqtSlot(QObject, str)
    def set_window_drop_zone(self, win: QObject, zone: str):
        self.window_manager.set_window_drop_zone(win, zone)

    @pyqtSlot()
    def clear_all_drop_zones(self):
        self.window_manager.clear_all_drop_zones()

    # --- BlockEngine Facade ---
    @pyqtSlot(str, str, str)
    def sync_block(self, source_file_url: str, heading: str, content: str):
        """Синхронизирует блок между открытыми редакторами и файлами на диске"""
        norm, clean_content, should_sync = self.block_engine.sync_block_data(source_file_url, heading, content)
        if not should_sync:
            return

        self.blockUpdated.emit(norm, clean_content, source_file_url)

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
            exts = self.file_service.get_supported_extensions(self._current_folder)
            for p in self._current_folder.iterdir():
                if not p.is_file() or p.suffix.lower() not in exts:
                    continue
                if source_path and p.resolve() == source_path:
                    continue
                try:
                    file_text = p.read_text(encoding="utf-8")
                    new_text, modified = replace_syntax_block(file_text, norm, clean_content)
                    if modified and new_text != file_text:
                        p.write_text(new_text, encoding="utf-8")
                        safe_print(f"[SyncBlock] Синхронизирован блок '{heading}' в файл: {p.name}")
                except Exception as ex:
                    safe_print(f"[SyncBlock] Ошибка синхронизации {p.name}: {ex}")
        finally:
            self._is_syncing_files = False

    @pyqtSlot(str, str, str, result=str)
    def replace_block_text(self, text: str, heading_norm: str, new_content: str) -> str:
        """Заменяет именованный блок в тексте по правилам синтаксиса диалекта"""
        updated, _ = replace_syntax_block(text, heading_norm, new_content)
        return updated

    @pyqtSlot(str, result="QVariantMap")
    def get_block(self, heading: str) -> dict:
        return self.block_engine.get_block(heading)

    @pyqtSlot(result="QVariantList")
    @pyqtSlot(str, result="QVariantList")
    def get_available_blocks(self, query: str = "") -> list:
        return self.block_engine.get_available_blocks(query)

    # --- Hotkey Facade ---
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

    @pyqtSlot(str, str)
    def log_event(self, tag: str, message: str):
        """Логирует события приложения в консоль и debug.log в кодировке UTF-8"""
        line = f"[{tag}] {message}"
        safe_print(line)
        try:
            log_dir = Path(".agents")
            log_dir.mkdir(exist_ok=True)
            with open(log_dir / "debug.log", "a", encoding="utf-8") as f:
                f.write(line + "\n")
        except Exception:
            pass
