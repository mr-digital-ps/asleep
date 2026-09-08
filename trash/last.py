from PyQt6.QtWidgets import QApplication, QWidget, QPushButton, QVBoxLayout

app = QApplication([])
window = QWidget()

# Создаем кнопки
btn1 = QPushButton("Кнопка 1")
btn2 = QPushButton("Кнопка 2")

# Создаем вертикальный layout и добавляем в него кнопки
layout = QVBoxLayout()
layout.addWidget(btn1)
layout.addWidget(btn2)

# Устанавливаем layout для главного окна
window.setLayout(layout)
window.show()
app.exec()
