import sys
import os
from pathlib import Path
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlApplicationEngine

def main():
    os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    
    # Загружаем наш QML-файл
    qml_file = Path(__file__).parent / "main.qml"
    engine.load(str(qml_file))
    
    # Проверка, успешно ли загрузился файл
    if not engine.rootObjects():
        print("Ошибка загрузки QML файла!")
        sys.exit(-1)
        
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
