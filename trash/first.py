from PyQt6.QtWidgets import QApplication, QWidget, QPushButton, QHBoxLayout

app = QApplication([])
window = QWidget()

btn1 = QPushButton("Левая кнопка")
btn2 = QPushButton("Правая кнопка")

layout = QHBoxLayout()
layout.addWidget(btn1)
layout.addWidget(btn2)

window.setLayout(layout)
window.show()
app.exec()
