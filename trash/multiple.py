from PyQt6.QtWidgets import QApplication, QWidget, QPushButton, QVBoxLayout, QHBoxLayout, QTextEdit

app = QApplication([])
window = QWidget()

# Главный вертикальный слой
main_layout = QVBoxLayout()

# Текстовое поле сверху
text_area = QTextEdit()
main_layout.addWidget(text_area)

# Горизонтальный слой для кнопок
buttons_layout = QHBoxLayout()
buttons_layout.addWidget(QPushButton("Сохранить"))
buttons_layout.addWidget(QPushButton("Отмена"))

# Вкладываем горизонтальный слой в главный вертикальный
main_layout.addLayout(buttons_layout)

window.setLayout(main_layout)
window.show()
app.exec()
