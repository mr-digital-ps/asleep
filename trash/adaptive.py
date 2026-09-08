from PyQt6.QtWidgets import (QApplication, QWidget, QPushButton, QVBoxLayout, 
                             QTextEdit, QSplitter, QFrame)
from PyQt6.QtCore import Qt

app = QApplication([])
window = QWidget()
window.setWindowTitle("Адаптивный интерфейс (QSplitter)")
window.resize(600, 400)

# Главный слой окна
main_layout = QVBoxLayout()
# Убираем отступы по краям, чтобы было красивее
main_layout.setContentsMargins(5, 5, 5, 5) 

# Создаем QSplitter (разделитель). Qt.Orientation.Horizontal означает, что элементы будут слева и справа
splitter = QSplitter(Qt.Orientation.Horizontal)

# --- 1. Левая панель (Сайдбар) ---
# Для QSplitter нужны виджеты, поэтому упаковываем наш сайдбар в QFrame (это как QWidget, но для рамок)
sidebar_widget = QFrame()
sidebar_layout = QVBoxLayout()

btn1 = QPushButton("Главная")
btn2 = QPushButton("Настройки")

sidebar_layout.addWidget(btn1)
sidebar_layout.addWidget(btn2)
sidebar_layout.addStretch()
sidebar_widget.setLayout(sidebar_layout)

# Базовая настройка для разработчика: минимальная ширина сайдбара
sidebar_widget.setMinimumWidth(100) 

# --- 2. Правая панель (Контент) ---
content_widget = QTextEdit("Основной текст.\n\nПопробуй потянуть за разделитель между кнопками и этим текстом!")
# Базовая настройка: минимальная ширина контента
content_widget.setMinimumWidth(200)

# --- Добавляем обе панели в сплиттер ---
splitter.addWidget(sidebar_widget)
splitter.addWidget(content_widget)

# Настройка пропорций по умолчанию (например, сайдбар 150px, контент 450px)
splitter.setSizes([150, 450])

# Добавляем сплиттер в главный слой
main_layout.addWidget(splitter)
window.setLayout(main_layout)

window.show()
app.exec()
