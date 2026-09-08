import sys
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget,
    QVBoxLayout, QPushButton, QLineEdit, QMessageBox, QLabel
)
from PyQt6.QtCore import Qt

# Главное окно, которое откроется после успешного входа
class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Главное приложение")
        self.resize(400, 300)
        
        # Центральный виджет и компоновка
        self.central_widget = QWidget()
        self.setCentralWidget(self.central_widget)
        self.layout = QVBoxLayout()
        self.central_widget.setLayout(self.layout)
        
        # Добавим приветственную надпись
        label = QLabel("Добро пожаловать в систему!", self)
        # Выравниваем текст по центру
        label.setAlignment(Qt.AlignmentFlag.AlignCenter) 
        # Стилизуем конкретно эту надпись
        
        self.layout.addWidget(label)


class LoginWindow(QMainWindow):
    def __init__(self):
        super().__init__() 
        
        self.setWindowTitle("Вход в систему")
        self.resize(300, 150)
        
        self.init_ui() 

    def init_ui(self):
        self.central_widget = QWidget()
        self.setCentralWidget(self.central_widget)
        self.layout = QVBoxLayout()
        self.central_widget.setLayout(self.layout)
        
        self.input_field = QLineEdit()
        self.input_field.setEchoMode(QLineEdit.EchoMode.Password)
        self.input_field.setPlaceholderText("Введите пароль (admin)") # Добавили серую подсказку
        
        # 1. ОБРАБОТКА ENTER: 
        # У QLineEdit есть встроенный сигнал returnPressed, который срабатывает при нажатии Enter
        self.input_field.returnPressed.connect(self.check_password)
        
        self.btn_login = QPushButton("Войти")
        self.btn_login.clicked.connect(self.check_password)
        
        self.layout.addWidget(self.input_field)
        self.layout.addWidget(self.btn_login)

        
    def check_password(self):
        if self.input_field.text() == "admin":
            # 3. ОТКРЫТИЕ НОВОГО ОКНА
            # Обязательно сохраняем окно в атрибут класса (self.main_window), 
            # иначе Python удалит его из памяти сразу после завершения этого метода, и окно моргнет и исчезнет!
            self.main_window = MainWindow() 
            self.main_window.show()
            
            # Закрываем текущее окно (окно логина)
            self.close()
        else:
            QMessageBox.warning(self, "Доступ", "Пароль неверный")
            self.input_field.clear() # Очищаем поле, чтобы было удобно вводить заново


if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = LoginWindow() 
    window.show()
    sys.exit(app.exec())