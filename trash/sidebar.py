from PyQt6.QtWidgets import QApplication, QWidget, QPushButton, QHBoxLayout, QVBoxLayout, QTextEdit

app = QApplication([])
window = QWidget()
window.setWindowTitle("Пример с сайдбаром")
window.resize(400, 300)

# Главный горизонтальный слой (слева сайдбар, справа контент)
main_layout = QHBoxLayout()

# 1. Создаем сайдбар (вертикальный слой для кнопок)
sidebar_layout = QVBoxLayout()
btn1 = QPushButton("Главная")
btn2 = QPushButton("Настройки")
btn3 = QPushButton("Выход")

sidebar_layout.addWidget(btn1)
sidebar_layout.addWidget(btn2)
sidebar_layout.addWidget(btn3)
sidebar_layout.addStretch() # Добавляем "пружину", чтобы кнопки прижались наверх

# 2. Создаем основную часть (например, текстовое поле)
content = QTextEdit("Здесь будет основной контент")

# 3. Добавляем сайдбар и контент в главный слой
main_layout.addLayout(sidebar_layout) # Добавляем Layout сайдбара
main_layout.addWidget(content)        # Добавляем Widget контента

# Устанавливаем главный слой окну
window.setLayout(main_layout)
window.show()
app.exec()
