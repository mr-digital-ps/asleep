import sys
from PyQt6.QtWidgets import QApplication, QWidget, QVBoxLayout, QPushButton, QLabel, QLineEdit
from PyQt6.QtCore import pyqtSignal, QObject

class EventBus(QObject):
    user_logged_in = pyqtSignal(str)

bus = EventBus()

class LoginWindow(QWidget):
    def __init__(self):
        super().__init__()
        layout = QVBoxLayout()
        
        self.input_name = QLineEdit("Иван")
        self.btn_login = QPushButton("Войти")
        
        self.btn_login.clicked.connect(self.broadcast_login)
        
        layout.addWidget(self.input_name)
        layout.addWidget(self.btn_login)
        self.setLayout(layout)

    def broadcast_login(self):
        # 1. ОТПРАВЛЯЕМ СИГНАЛ (Диктор говорит в микрофон)
        bus.user_logged_in.emit(self.input_name.text())


class DashboardWindow(QWidget):
    def __init__(self):
        super().__init__()
        layout = QVBoxLayout()
        
        self.label = QLabel("Ожидание...")
        layout.addWidget(self.label)
        self.setLayout(layout)
        
        # 2. СЛУШАЕМ СИГНАЛ (Настраиваем радио на волну)
        bus.user_logged_in.connect(self.show_welcome)

    def show_welcome(self, user_name):
        self.label.setText(f"Привет, {user_name}!")

if __name__ == "__main__":
    app = QApplication(sys.argv)
    
    window_a = LoginWindow()
    window_b = DashboardWindow()
    
    window_a.show()
    window_b.show()
    
    sys.exit(app.exec())
