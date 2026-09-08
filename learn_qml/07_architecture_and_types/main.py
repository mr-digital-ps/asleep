import sys
import os
import time
from pathlib import Path
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtCore import QObject, pyqtSlot, pyqtSignal, pyqtProperty, QThread

# =============================================================================
# BACKEND: Контроллер / ViewModel, мост между Python и QML
# =============================================================================
class BackendBridge(QObject):
    # Сигналы с разными типами данных (Python -> QML)
    stringReceived = pyqtSignal(str)
    numberCalculated = pyqtSignal(float)
    listUpdated = pyqtSignal(list)
    dictReceived = pyqtSignal("QVariant")
    statusChanged = pyqtSignal(str)
    
    # Сигнал для реактивного свойства
    userNameChanged = pyqtSignal()

    def __init__(self):
        super().__init__()
        self._user_name = "Alex_Dev"

    # -------------------------------------------------------------------------
    # РЕАКТИВНОЕ СВОЙСТВО (pyqtProperty)
    # Позволяет QML обращаться к переменной Python как к обычному свойству:
    # Text { text: backend.userName } (и сам обновляется при изменении!)
    # -------------------------------------------------------------------------
    @pyqtProperty(str, notify=userNameChanged)
    def userName(self) -> str:
        return self._user_name

    @userName.setter
    def userName(self, new_name: str):
        if self._user_name != new_name:
            self._user_name = new_name
            self.userNameChanged.emit()

    # -------------------------------------------------------------------------
    # СЛОТЫ: Передача и возврат простых типов (str, int, float, bool)
    # -------------------------------------------------------------------------
    @pyqtSlot(str, int, float, bool, result=str)
    def send_primitives(self, text: str, count: int, price: float, is_active: bool) -> str:
        res = f"Python принял: текст='{text}', целое={count}, дробное={price}, флаг={is_active}"
        print(res)
        return f"Успешно обработано: {count * price:.2f} руб."

    # -------------------------------------------------------------------------
    # СЛОТЫ: Передача и возврат СПИСКОВ (list <-> JS Array)
    # -------------------------------------------------------------------------
    @pyqtSlot(list, result=list)
    def process_list(self, items: list) -> list:
        print(f"Python получил список из {len(items)} элементов: {items}")
        # Добавляем новые элементы и переворачиваем
        modified = [f"Обработано [{x}]" for x in items]
        modified.append("⭐ Новый элемент из Python")
        return modified

    # -------------------------------------------------------------------------
    # СЛОТЫ: Передача и возврат СЛОВАРЕЙ / JSON (dict <-> JS Object)
    # -------------------------------------------------------------------------
    @pyqtSlot("QVariant", result="QVariant")
    def process_dictionary(self, user_data) -> dict:
        # В PyQt6 JS-объект может прийти как QJSValue.
        # Метод toVariant() мгновенно превращает его в стандартный dict Python!
        if hasattr(user_data, "toVariant"):
            user_data = user_data.toVariant()
            
        print(f"Python получил объект данных: {user_data}")
        # Модифицируем словарь
        response = {
            "status": "success",
            "original_name": user_data.get("name", "Unknown") if isinstance(user_data, dict) else "User",
            "role": "Senior Developer",
            "permissions": ["read", "write", "admin"],
            "server_timestamp": time.strftime("%H:%M:%S")
        }
        return response

    # -------------------------------------------------------------------------
    # СЛОТ: Смена реактивного свойства из QML
    # -------------------------------------------------------------------------
    @pyqtSlot(str)
    def update_user_name(self, new_name: str):
        self.userName = new_name
        self.statusChanged.emit(f"Имя пользователя изменено на: {new_name}")


def main():
    os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
    
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    engine.warnings.connect(lambda warnings: [print("QML Warning/Error:", w.toString()) for w in warnings])
    
    # Создаем наш бэкенд и регистрируем в QML под именем 'backend'
    backend = BackendBridge()
    engine.rootContext().setContextProperty("backend", backend)
    
    qml_file = Path(__file__).parent / "main.qml"
    engine.load(str(qml_file))
    
    if not engine.rootObjects():
        print("Failed to load QML file!")
        sys.exit(-1)
        
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
