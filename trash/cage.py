from PyQt6.QtWidgets import QApplication, QWidget, QPushButton, QGridLayout

app = QApplication([])
window = QWidget()

layout = QGridLayout()

# addWidget(виджет, строка, столбец, [количество_строк_которое_занимает, количество_столбцов])
layout.addWidget(QPushButton("7"), 0, 0)
layout.addWidget(QPushButton("8"), 0, 1)
layout.addWidget(QPushButton("9"), 0, 2)

layout.addWidget(QPushButton("4"), 1, 0)
layout.addWidget(QPushButton("5"), 1, 1)
layout.addWidget(QPushButton("6"), 1, 2)

# Эта кнопка будет занимать 3 столбца
btn_zero = QPushButton("0")
layout.addWidget(btn_zero, 2, 0, 1, 3) 

window.setLayout(layout)
window.show()
app.exec()
