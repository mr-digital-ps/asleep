import sys
from PyQt6.QtWidgets import QApplication, QWidget, QPushButton, QLabel
from PyQt6.QtCore import Qt

class MainWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Кастомный блок для текста")
        self.resize(500, 400)
        self.setStyleSheet("background-color: #1e1e1e;") # Темный фон основного окна

        # 1. Создаем кнопку, которая будет вызывать текст
        self.btn = QPushButton("Показать сообщение", self)
        self.btn.setGeometry(175, 40, 150, 40)
        self.btn.setStyleSheet("background-color: #007acc; color: white; border-radius: 5px;")
        self.btn.clicked.connect(self.toggle_message_block)

        # 2. Создаем выделенный квадрат для вывода текста
        self.text_block = QLabel("Это выделенный квадрат.\nЗдесь будет ваш текст.", self)
        
        # Задаем позицию и жесткие размеры (квадрат 200x200) в центре окна
        self.text_block.setGeometry(150, 120, 200, 200)
        
        # Настраиваем выравнивание текста по центру
        self.text_block.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        # Кастомизируем внешний вид квадрата через QSS
        self.text_block.setStyleSheet("""
            QLabel {
                background-color: #2d2d2d;      /* Цвет фона квадрата */
                color: #ffffff;                 /* Цвет текста */
                border: 2px solid #007acc;      /* Цвет и толщина рамки */
                border-radius: 10px;            /* Скругление углов */
                font-size: 14px;                /* Размер шрифта */
                padding: 10px;                  /* Отступы от краев до текста */
            }
        """)
        
        # Изначально скрываем квадрат
        self.text_block.hide()

    def toggle_message_block(self):
        # Переключаем видимость квадрата при нажатии на кнопку
        if self.text_block.isVisible():
            self.text_block.hide()
            self.btn.setText("Показать сообщение")
        else:
            self.text_block.show()
            self.btn.setText("Скрыть сообщение")

if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec())
