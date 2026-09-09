import sys
import os
import json
from pathlib import Path
from PyQt6.QtWidgets import QApplication, QFileDialog
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtCore import QObject, pyqtSlot, pyqtSignal, QFileSystemWatcher, QTimer, QUrl

# Обеспечиваем корректный вывод UTF-8 в консоль Windows
if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if sys.stderr and hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

CONFIG_FILE = Path(__file__).parent.resolve() / ".session_config.json"

def load_session_config() -> dict:
    try:
        if CONFIG_FILE.exists():
            return json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
    except Exception:
        pass
    return {}

def save_session_config(data: dict):
    try:
        cfg = load_session_config()
        cfg.update(data)
        CONFIG_FILE.write_text(json.dumps(cfg, ensure_ascii=False, indent=2), encoding="utf-8")
    except Exception as e:
        print(f"[Python] Ошибка сохранения сессии: {e}")


class Backend(QObject):
    """
    Бэкенд для работы с файлами и папками.
    Принимает запросы от кнопок QML и читает/сохраняет файлы на диск.
    """
    folderFilesChanged = pyqtSignal()

    def __init__(self):
        super().__init__()
        self.folder_watcher = QFileSystemWatcher(self)
        self.folder_watcher.directoryChanged.connect(lambda _: self.folderFilesChanged.emit())
        self._windows = []  # Список кортежей: (win, root_item)

    @pyqtSlot(QObject, QObject)
    def register_window(self, win: QObject, root_item: QObject):
        """Регистрация открытого окна приложения в общем реестре окон"""
        if not win:
            return
        # Проверяем, не зарегистрировано ли уже это окно
        for w, r in self._windows:
            if w == win:
                return
        self._windows.append((win, root_item))
        print(f"[WindowManager] Окно зарегистрировано. Всего активных окон: {len(self._windows)}")

    @pyqtSlot(QObject)
    def unregister_window(self, win: QObject):
        """Удаление закрытого окна из реестра"""
        self._windows = [(w, r) for w, r in self._windows if w != win]
        print(f"[WindowManager] Окно разрегистрировано. Осталось активных окон: {len(self._windows)}")

    @pyqtSlot(float, float, QObject, result="QVariantMap")
    def find_target_window_at(self, gx: float, gy: float, exclude_win: QObject = None) -> dict:
        """
        Проверяет, над каким окном приложения находится курсор (gx, gy).
        Возвращает информацию о целевом окне и зону сброса (left, right, center).
        """
        for win, root in self._windows:
            if win == exclude_win:
                continue
            if hasattr(win, "isVisible") and not win.isVisible():
                continue
            wx = win.x()
            wy = win.y()
            ww = win.width()
            wh = win.height()
            if wx <= gx <= wx + ww and wy <= gy <= wy + wh:
                rel_x = (gx - wx) / max(1, ww)
                if rel_x < 0.28:
                    zone = "left"
                elif rel_x > 0.72:
                    zone = "right"
                else:
                    zone = "center"
                return {
                    "found": True,
                    "targetWin": win,
                    "targetRoot": root,
                    "zone": zone,
                }
        return {"found": False, "zone": ""}

    @pyqtSlot(QObject, str)
    def set_window_drop_zone(self, win: QObject, zone: str):
        """Устанавливает визуальную зону сброса на целевом окне"""
        for w, root in self._windows:
            if w == win and root:
                root.setProperty("dropZone", zone)

    @pyqtSlot()
    def clear_all_drop_zones(self):
        """Очищает подсветку зон сброса во всех открытых окнах"""
        for _, root in self._windows:
            if root:
                root.setProperty("dropZone", "")

    def _to_path(self, file_url: str) -> Path:
        """Переводит QML URL 'file:///C:/doc.txt' в путь Windows 'C:/doc.txt'"""
        if not file_url:
            return Path()
        if file_url.startswith("file:"):
            return Path(QUrl(file_url).toLocalFile())
        return Path(file_url)

    @pyqtSlot(str)
    def watch_folder(self, folder_url: str):
        """Отслеживает изменения файлов в рабочей папке"""
        try:
            folder = self._to_path(folder_url)
            existing = self.folder_watcher.directories()
            if existing:
                self.folder_watcher.removePaths(existing)
            if folder.exists() and folder.is_dir():
                self.folder_watcher.addPath(str(folder.resolve()))
        except Exception as e:
            print(f"[Python] Ошибка отслеживания папки: {e}")

    @pyqtSlot(str, result="QVariantList")
    def get_folder_files(self, folder_url: str) -> list:
        """Возвращает список файлов в рабочей папке"""
        try:
            folder = self._to_path(folder_url)
            if not folder.exists() or not folder.is_dir():
                return []

            items = []
            for p in sorted(folder.iterdir(), key=lambda x: (not x.is_dir(), x.name.lower())):
                # Пропускаем служебные папки и скрытые файлы
                if p.name.startswith(".") or p.name in ["__pycache__", "venv", ".venv"]:
                    continue
                if p.is_file():
                    items.append({
                        "name": p.name,
                        "fileUrl": QUrl.fromLocalFile(str(p.resolve())).toString(),
                        "isDir": False,
                        "ext": p.suffix.lower(),
                    })
            return items
        except Exception as e:
            print(f"[Python] Ошибка получения файлов папки: {e}")
            return []

    @pyqtSlot(str, result=bool)
    def delete_file(self, file_url: str) -> bool:
        """Удаляет файл с диска"""
        try:
            path = self._to_path(file_url)
            if path.exists() and path.is_file():
                path.unlink()
                print(f"[Python] Файл удален: {path.name}")
                self.folderFilesChanged.emit()
                return True
            return False
        except Exception as e:
            print(f"[Python] Ошибка удаления файла: {e}")
            return False

    @pyqtSlot(str, result=str)
    def read_file(self, file_url: str) -> str:
        """Чтение файла по пути из диалога Open"""
        try:
            path = self._to_path(file_url)
            content = path.read_text(encoding="utf-8")
            print(f"[Python] Файл прочитан: {path.name}")
            return content
        except Exception as e:
            print(f"[Python] Ошибка чтения: {e}")
            return ""

    @pyqtSlot(str, str, result=bool)
    def save_file(self, file_url: str, text: str) -> bool:
        """Запись текста в файл по пути из диалога Save"""
        try:
            path = self._to_path(file_url)
            path.write_text(text, encoding="utf-8")
            print(f"[Python] Файл успешно сохранен: {path.name}")
            self.folderFilesChanged.emit()
            return True
        except Exception as e:
            print(f"[Python] Ошибка сохранения: {e}")
            return False

    @pyqtSlot(str, result=str)
    def get_filename(self, file_url: str) -> str:
        """Получить только имя файла без пути"""
        return self._to_path(file_url).name or "Новый файл"

    @pyqtSlot(result=str)
    def get_default_folder(self) -> str:
        """Возвращает URL последней сохраненной папки либо дефолтной папки заметок"""
        try:
            cfg = load_session_config()
            last_folder = cfg.get("last_folder", "")
            if last_folder:
                p = self._to_path(last_folder)
                if p.exists() and p.is_dir():
                    return last_folder

            # По умолчанию: папка Notes в Документах пользователя
            notes_dir = Path.home() / "Documents" / "Notes"
            try:
                notes_dir.mkdir(parents=True, exist_ok=True)
                return QUrl.fromLocalFile(str(notes_dir.resolve())).toString()
            except Exception:
                project_dir = Path(__file__).parent.resolve()
                return QUrl.fromLocalFile(str(project_dir)).toString()
        except Exception:
            return ""

    @pyqtSlot(str)
    def save_last_folder(self, folder_url: str):
        """Сохраняет последнюю открытую пользователем папку"""
        if folder_url:
            save_session_config({"last_folder": folder_url})

    @pyqtSlot(str, result=str)
    def get_folder_name(self, folder_url: str) -> str:
        """Возвращает имя папки для отображения в интерфейсе"""
        try:
            path = self._to_path(folder_url)
            name = path.name
            if not name:
                name = str(path)
            return name or "Заметки"
        except Exception:
            return "Заметки"

    @pyqtSlot(result="QVariantMap")
    @pyqtSlot(str, result="QVariantMap")
    def choose_folder_dialog(self, initial_folder: str = "") -> dict:
        """Открывает нативный диалог выбора папки Windows и сохраняет выбор в сессию"""
        try:
            start_dir = ""
            if initial_folder:
                start_dir = str(self._to_path(initial_folder).resolve())
            if not start_dir or not Path(start_dir).exists():
                cfg = load_session_config()
                last_f = cfg.get("last_folder", "")
                if last_f and self._to_path(last_f).exists():
                    start_dir = str(self._to_path(last_f).resolve())
                else:
                    start_dir = str(Path.home() / "Documents")

            chosen = QFileDialog.getExistingDirectory(
                None,
                "Выберите рабочую папку",
                start_dir
            )
            if chosen:
                path = Path(chosen).resolve()
                url = QUrl.fromLocalFile(str(path)).toString()
                name = path.name or str(path)
                print(f"[Python] Выбрана новая рабочая папка: {path} (имя: {name})")
                self.save_last_folder(url)
                self.watch_folder(url)
                self.folderFilesChanged.emit()
                return {
                    "success": True,
                    "folderUrl": url,
                    "folderName": name,
                    "folderPath": str(path),
                }
            return {"success": False, "folderUrl": "", "folderName": ""}
        except Exception as e:
            print(f"[Python] Ошибка выбора папки: {e}")
            return {"success": False, "folderUrl": "", "folderName": ""}

    @pyqtSlot(str, str, result="QVariantMap")
    def create_file_in_folder(self, folder_url: str, base_name: str = "Новый документ") -> dict:
        """Создает реальный файл в указанной папке и возвращает его параметры"""
        try:
            folder = self._to_path(folder_url)
            if not folder.exists():
                folder.mkdir(parents=True, exist_ok=True)

            ext = ".md"
            raw_name = base_name.strip()
            if raw_name.endswith(".md"):
                raw_name = raw_name[:-3]
            elif raw_name.endswith(".txt"):
                raw_name = raw_name[:-4]
            if not raw_name:
                raw_name = "Новый документ"

            candidate = folder / f"{raw_name}{ext}"
            idx = 1
            while candidate.exists():
                candidate = folder / f"{raw_name} ({idx}){ext}"
                idx += 1

            candidate.write_text("", encoding="utf-8")
            print(f"[Python] Создан новый файл на диске: {candidate.resolve()}")
            self.folderFilesChanged.emit()

            return {
                "fileUrl": QUrl.fromLocalFile(str(candidate.resolve())).toString(),
                "fileName": candidate.name,
                "filePath": str(candidate.resolve()),
                "success": True,
            }
        except Exception as e:
            print(f"[Python] Ошибка создания файла: {e}")
            return {"fileUrl": "", "fileName": base_name, "filePath": "", "success": False}

    @pyqtSlot(str, str, result="QVariantMap")
    def rename_file(self, file_url: str, new_name: str) -> dict:
        """Переименовывает существующий файл на диске при смене имени вкладки"""
        try:
            path = self._to_path(file_url)
            if not path.exists() or not path.is_file():
                return {"fileUrl": file_url, "fileName": new_name, "success": False}

            clean_name = new_name.strip()
            if not clean_name:
                return {"fileUrl": file_url, "fileName": path.name, "success": False}

            # Сохраняем расширение, если пользователь не указал новое
            if "." not in clean_name and path.suffix:
                target_name = f"{clean_name}{path.suffix}"
            else:
                target_name = clean_name

            target_path = path.parent / target_name
            if target_path != path:
                if target_path.exists():
                    print(f"[Python] Файл с именем {target_name} уже существует")
                    return {"fileUrl": file_url, "fileName": path.name, "success": False}
                path.rename(target_path)
                print(f"[Python] Файл переименован: {path.name} -> {target_path.name}")
                self.folderFilesChanged.emit()

            return {
                "fileUrl": QUrl.fromLocalFile(str(target_path.resolve())).toString(),
                "fileName": target_path.name,
                "success": True,
            }
        except Exception as e:
            print(f"[Python] Ошибка переименования файла: {e}")
            return {"fileUrl": file_url, "fileName": new_name, "success": False}

    @pyqtSlot(result="QVariantMap")
    def get_cursor_state(self) -> dict:
        """Возвращает глобальные экранные координаты курсора и статус зажатия ЛКМ"""
        try:
            import ctypes
            from PyQt6.QtGui import QCursor
            pos = QCursor.pos()
            is_lmb = bool(ctypes.windll.user32.GetAsyncKeyState(0x01) & 0x8000)
            return {"x": int(pos.x()), "y": int(pos.y()), "leftPressed": is_lmb}
        except Exception:
            return {"x": 0, "y": 0, "leftPressed": False}



class HotReloader(QObject):
    """Класс для авто-перезагрузки web.qml при нажатии Ctrl+S"""
    def __init__(self, engine: QQmlApplicationEngine, root_dir: Path, target_qml: str = "web.qml"):
        super().__init__()
        self.engine = engine
        self.root_dir = root_dir.resolve()
        self.target_qml = target_qml

        self.reload_timer = QTimer(self)
        self.reload_timer.setSingleShot(True)
        self.reload_timer.setInterval(100)
        self.reload_timer.timeout.connect(self._do_reload)

        self.watcher = QFileSystemWatcher(self)
        self.setup_watchers()
        self.watcher.fileChanged.connect(lambda _: self.reload_timer.start())
        self.watcher.directoryChanged.connect(self.setup_watchers)

    def setup_watchers(self):
        # Следим за всеми .qml и .js файлами (кроме неизменного каркаса window.qml)
        watch_files = [str(p) for p in self.root_dir.glob("*.*") if p.name != "window.qml" and p.suffix in [".qml", ".js"]]
        if watch_files:
            existing = self.watcher.files()
            if existing:
                self.watcher.removePaths(existing)
            self.watcher.addPaths(watch_files)
        print(f"[Live Reload] Отслеживаются: {', '.join(Path(f).name for f in watch_files)}")

    def _do_reload(self):
        print("[Live Reload] Обновление интерфейса...")
        self.engine.clearComponentCache()
        if self.engine.rootObjects():
            window = self.engine.rootObjects()[0]
            loader = window.findChild(QObject, "hotLoader")
            if loader:
                loader.setProperty("source", "")
                loader.setProperty("source", self.target_qml)
                print("[Live Reload] Готово! Изменения применились.")
        self.setup_watchers()


def main():
    os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"

    app = QApplication(sys.argv)
    engine = QQmlApplicationEngine()

    engine.warnings.connect(
        lambda warnings: [print("[QML Warning]:", w.toString()) for w in warnings]
    )

    root_dir = Path(__file__).parent

    # 1. Создаем бэкенд для файлов и регистрируем его под именем 'backend'
    backend = Backend()
    engine.rootContext().setContextProperty("backend", backend)

    # 2. Запускаем Live Reload
    reloader = HotReloader(engine, root_dir, target_qml="web.qml")

    # 3. Загружаем окно
    engine.load(str(root_dir / "window.qml"))

    if not engine.rootObjects():
        print("Ошибка: не удалось загрузить window.qml")
        sys.exit(-1)

    print("[Старт] Редактор запущен! Меняйте web.qml или logic.js — всё обновится на лету.")
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
