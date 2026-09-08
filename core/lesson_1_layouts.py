import sys
from PyQt6.QtWidgets import (QApplication, QWidget, QPushButton, 
                             QVBoxLayout, QHBoxLayout, QGridLayout)

class LayoutDemo(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Урок 1: Компоновки (Layouts)")
        self.resize(300, 200)
        
        # 1. ГЛАВНАЯ КОМПОНОВКА (Вертикальная - элементы идут сверху вниз)
        main_layout = QVBoxLayout()
        
        # 2. ГОРИЗОНТАЛЬНАЯ КОМПОНОВКА (элементы идут слева направо)
        h_layout = QHBoxLayout()
        h_layout.addWidget(QPushButton("Кнопка 1"))
        h_layout.addWidget(QPushButton("Кнопка 2"))
        h_layout.addWidget(QPushButton("Кнопка 3"))
        
        # 3. СЕТОЧНАЯ КОМПОНОВКА (как таблица, элементы по строкам и столбцам)
        grid_layout = QGridLayout()
        # Метод addWidget для сетки принимает координаты: (Виджет, Строка, Столбец)
        grid_layout.addWidget(QPushButton("Сетка 0,0"), 0, 0)
        grid_layout.addWidget(QPushButton("Сетка 0,1"), 0, 1)
        grid_layout.addWidget(QPushButton("Сетка 1,0"), 1, 0)
        grid_layout.addWidget(QPushButton("Сетка 1,1"), 1, 1)
        
        # 4. ВЛОЖЕННОСТЬ (Магия PyQt!)
        # Мы можем вкладывать компоновки друг в друга с помощью addLayout()
        main_layout.addLayout(h_layout)     # Верхний блок (строка кнопок)
        main_layout.addLayout(grid_layout)  # Нижний блок (квадрат кнопок)
        
        # 5. Применяем главную компоновку к самому окну
        self.setLayout(main_layout)

if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = LayoutDemo()
    window.show()
    sys.exit(app.exec())
