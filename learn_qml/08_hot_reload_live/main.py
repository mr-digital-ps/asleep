import sys
import os
from pathlib import Path
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtCore import QFileSystemWatcher, QObject, pyqtSlot

class HotReloader(QObject):
    def __init__(self, engine: QQmlApplicationEngine, root_qml_path: Path):
        super().__init__()
        self.engine = engine
        self.root_qml_path = root_qml_path.resolve()
        self.watcher = QFileSystemWatcher(self)
        
        # Следим за всеми .qml файлами в текущей директории и подпапках
        self.setup_watchers()
        self.watcher.fileChanged.connect(self.on_file_changed)
        self.watcher.directoryChanged.connect(self.setup_watchers)

    def setup_watchers(self):
        watch_dir = self.root_qml_path.parent
        qml_files = [str(p) for p in watch_dir.rglob("*.qml")]
        if qml_files:
            self.watcher.addPaths(qml_files)
        print(f"[Live Reload] Tracking {len(qml_files)} QML files...")

    @pyqtSlot(str)
    def on_file_changed(self, path: str):
        print(f"[Live Reload] Changed: {Path(path).name}! Reloading UI...")
        
        # 1. Очищаем кэш скомпилированных QML компонентов
        self.engine.clearComponentCache()
        
        # 2. Закрываем и удаляем старые окна
        for obj in self.engine.rootObjects():
            obj.deleteLater()
            
        # 3. Мгновенно загружаем обновленный QML файл
        self.engine.load(str(self.root_qml_path))
        
        # Переподключаем вотчер (некоторые редакторы удаляют/создают файл заново при сохранении)
        self.setup_watchers()


def main():
    os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
    
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    engine.warnings.connect(lambda warnings: [print("QML Warning/Error:", w.toString()) for w in warnings])
    
    qml_file = Path(__file__).parent / "main.qml"
    
    # Запускаем Hot Reload вотчер!
    reloader = HotReloader(engine, qml_file)
    
    # Первичная загрузка
    engine.load(str(qml_file))
    
    if not engine.rootObjects():
        print("Failed to load QML file!")
        sys.exit(-1)
        
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
