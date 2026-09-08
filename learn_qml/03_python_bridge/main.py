import sys
import os
import random
from pathlib import Path
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtCore import QObject, pyqtSlot, pyqtSignal

# Бэкенд класс — мост между логикой Python и интерфейсом QML
class AppBridge(QObject):
    # 1. Сигналы (Python -> QML): сообщают интерфейсу, что что-то изменилось
    statusChanged = pyqtSignal(str)
    numberGenerated = pyqtSignal(int)

    def __init__(self):
        super().__init__()

    # 2. Слоты (QML -> Python): функции, которые QML может вызывать напрямую
    @pyqtSlot(str, result=str)
    def process_text(self, text: str) -> str:
        """Принимает строку из QML, обрабатывает в Python и возвращает результат"""
        reversed_text = text[::-1]
        self.statusChanged.emit(f"Python перевернул строку '{text}'!")
        return reversed_text

    @pyqtSlot()
    def generate_random(self):
        """Генерирует случайное число и шлет сигнал в QML"""
        val = random.randint(1, 100)
        self.numberGenerated.emit(val)
        self.statusChanged.emit(f"Сгенерировано новое число: {val}")


def main():
    # Обход проблемы с Windows Style Plugin (не находит dll)
    os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()

    # Создаем экземпляр нашего бэкенда
    bridge = AppBridge()

    # Регистрируем объект 'bridge' в глобальном контексте QML под именем 'bridge'
    engine.rootContext().setContextProperty("bridge", bridge)

    qml_file = Path(__file__).parent / "main.qml"
    engine.load(str(qml_file))

    if not engine.rootObjects():
        sys.exit(-1)

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
