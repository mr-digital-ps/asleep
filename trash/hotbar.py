from PyQt6.QtWidgets import QApplication, QWidget, QPushButton, QHBoxLayout, QVBoxLayout, QTextEdit

app = QApplication([])
window = QWidget()
window.setWindowTitle("Пример с хотбаром")
window.resize(400, 300)

# Главный вертикальный слой (сверху хотбар, снизу контент)
main_layout = QVBoxLayout()

# 1. Создаем хотбар (горизонтальный слой для кнопок)
hotbar_layout = QHBoxLayout()
btn_save = QPushButton("Сохранить")
btn_load = QPushButton("Загрузить")
btn_delete = QPushButton("Удалить")

hotbar_layout.addWidget(btn_save)
hotbar_layout.addWidget(btn_load)
hotbar_layout.addWidget(btn_delete)
hotbar_layout.addStretch() # Пружина, чтобы кнопки прижались влево

# 2. Создаем основную часть
content = QTextEdit("Основной рабочий экран")

# 3. Складываем всё в главный слой
main_layout.addLayout(hotbar_layout)
main_layout.addWidget(content)

window.setLayout(main_layout)
window.show()
app.exec()
