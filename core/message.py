import sys
from PyQt6.QtWidgets import QApplication, QWidget, QPushButton, QVBoxLayout, QMessageBox

class MainWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Окна сообщений")
        self.resize(300, 200)

        # Создаем вертикальный слой для кнопок
        layout = QVBoxLayout()

        # Кнопка для информационного окна
        btn_info = QPushButton("Инфо")
        btn_info.clicked.connect(self.show_info)
        layout.addWidget(btn_info)

        # Кнопка для окна вопроса
        btn_question = QPushButton("Вопрос")
        btn_question.clicked.connect(self.show_question)
        layout.addWidget(btn_question)

        self.setLayout(layout)
        self.show()

    # 1. Простая информация, предупреждение или ошибка
    def show_info(self):
        # Доступные статические методы: information(), warning(), critical()
        QMessageBox.information(
            self, 
            "Успех", 
            "Операция выполнена успешно!", 
            QMessageBox.StandardButton.Ok
        )

    # 2. Диалог с выбором действия (Да / Нет)
    def show_question(self):
        reply = QMessageBox.question(
            self, 
            "Подтверждение", 
            "Вы уверены, что хотите выйти?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No # Кнопка по умолчанию
        )

        if reply == QMessageBox.StandardButton.Yes:
            print("Пользователь нажал Да")
            self.close()
        else:
            print("Пользователь нажал Нет")

if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = MainWindow()
    sys.exit(app.exec())
