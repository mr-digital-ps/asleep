from sys import exc_info
import sys
import os
from pathlib import Path
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtCore import QFileSystemWatcher, QObject, pyqtSlot, QTimer

class HotReloader(QObject):
    def __init__(self, engine: QQmlApplicationEngine, root_dir: Path):
        super().__init__()
        self.engine = engine
        self.root_dir = root_dir.resolve()
        self.watcher = QFileSystemWatcher(self)
        
        self.reload_timer = QTimer(self)
        self.reload_timer.setSingleShot(True)
        self.reload_timer.setInterval(100)
        self.reload_timer.timeout.connect(self._do_reload)
        
        self.setup_watchers()
        self.watcher.fileChanged.connect(self.on_file_changed)
        self.watcher.directoryChanged.connect(self.setup_watchers)

    def setup_watchers(self):
        # Следим за всеми QML файлами, КРОМЕ window.qml (окно мы не перезагружаем)
        qml_files = [str(p) for p in self.root_dir.rglob("*.qml") if p.name != "window.qml"]
        if qml_files:
            self.watcher.addPaths(qml_files)
        print(f"[Live Reload] Отслеживается {len(qml_files)} QML файлов контента...")

    @pyqtSlot(str)
    def on_file_changed(self, path: str):
        self.reload_timer.start()

    def _do_reload(self):
        print(f"[Live Reload] Запрос на обновление контента...")
        
        # 1. Очищаем кэш компонентов QML
        self.engine.clearComponentCache()
        
        # 2. Ищем Loader внутри главного окна
        if self.engine.rootObjects():
            window = self.engine.rootObjects()[0]
            loader = window.findChild(QObject, "hotLoader")
            
            if loader:
                # 3. Принудительно перезагружаем source
                loader.setProperty("source", "")
                loader.setProperty("source", "main.qml")
                print(f"[Live Reload] Успешно! Контент обновлен без морганий.")
            else:
                print("[Live Reload] Ошибка: Компонент Loader не найден в окне!")
        
        self.setup_watchers()

def main():
    os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    
    engine.warnings.connect(lambda warnings: [print("QML Warning:", w.toString()) for w in warnings])
    
    root_dir = Path(__file__).parent
    window_qml = root_dir / "window.qml"
    
    reloader = HotReloader(engine, root_dir)
    
    # Загружаем нерушимое окно 1 раз
    engine.load(str(window_qml))

    if not engine.rootObjects():
        sys.exit(-1)

    sys.exit(app.exec())

if __name__ == "__main__":
    main()