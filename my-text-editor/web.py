import sys
import os
from pathlib import Path
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtCore import QObject, pyqtSlot, QFileSystemWatcher, QTimer, QUrl

# Обеспечиваем корректный вывод UTF-8 в консоль Windows
if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if sys.stderr and hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")


class Backend(QObject):
    """
    Бэкенд для работы с файлами.
    Принимает запросы от кнопок QML и читает/сохраняет файлы на диск.
    """

    def _to_path(self, file_url: str) -> Path:
        """Переводит QML URL 'file:///C:/doc.txt' в путь Windows 'C:/doc.txt'"""
        if not file_url:
            return Path()
        if file_url.startswith("file:"):
            return Path(QUrl(file_url).toLocalFile())
        return Path(file_url)

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
            return True
        except Exception as e:
            print(f"[Python] Ошибка сохранения: {e}")
            return False

    @pyqtSlot(str, result=str)
    def get_filename(self, file_url: str) -> str:
        """Получить только имя файла без пути"""
        return self._to_path(file_url).name or "Новый файл"

    @pyqtSlot(result="QVariantMap")
    def get_cursor_state(self) -> dict:
        """Возвращает глобальные экранные координаты курсора и статус зажатия ЛКМ"""
        try:
            import ctypes
            from ctypes import wintypes
            pt = wintypes.POINT()
            ctypes.windll.user32.GetCursorPos(ctypes.byref(pt))
            is_lmb = bool(ctypes.windll.user32.GetAsyncKeyState(0x01) & 0x8000)
            return {"x": int(pt.x), "y": int(pt.y), "leftPressed": is_lmb}
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

    app = QGuiApplication(sys.argv)
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
