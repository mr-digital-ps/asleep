import sys
from pathlib import Path
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlApplicationEngine

if __name__ == "__main__":
    # В QML мы используем QGuiApplication вместо QApplication
    app = QGuiApplication(sys.argv)
    
    # Движок, который читает и запускает QML код
    engine = QQmlApplicationEngine()
    
    # Загружаем наш QML файл (ищем его в той же папке, где этот скрипт)
    qml_file = Path(__file__).parent / "main.qml"
    engine.load(str(qml_file)) # Обязательно переводим Path в обычную строку (str)
    
    # Если QML файл с ошибками и не загрузился - закрываем программу
    if not engine.rootObjects():
        sys.exit(-1)
        
    sys.exit(app.exec())
