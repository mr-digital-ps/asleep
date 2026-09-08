import sys
import os
from pathlib import Path
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlApplicationEngine

def main():
    os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
    
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    engine.warnings.connect(lambda warnings: [print("QML Warning/Error:", w.toString()) for w in warnings])
    
    qml_file = Path(__file__).parent / "main.qml"
    engine.load(str(qml_file))
    
    if not engine.rootObjects():
        print("Failed to load QML file!")
        sys.exit(-1)
        
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
