import sys
from PyQt6.QtWidgets import QApplication, QGraphicsView, QGraphicsScene, QGraphicsRectItem
from PyQt6.QtGui import QBrush, QColor
from PyQt6.QtCore import Qt

# 1. Создаем само приложение
app = QApplication(sys.argv)

# 2. Создаем Сцену (наш мир)
scene = QGraphicsScene()
scene.setSceneRect(0, 0, 800, 600) # Размер мира: 800x600 пикселей

# 3. Создаем "Игрока" (Синий квадрат)
# Координаты (x=0, y=0, ширина=50, высота=50)
player = QGraphicsRectItem(0, 0, 50, 50)
player.setBrush(QBrush(QColor("blue"))) # Раскрашиваем в синий
player.setPos(375, 275) # Ставим по центру мира

# Добавляем игрока на сцену
scene.addItem(player)

# 4. Создаем Камеру/Окно, чтобы увидеть Сцену
view = QGraphicsView(scene)
view.setFixedSize(800, 600) # Размер окна совпадает с размером мира
view.setWindowTitle("Моя первая 2D сцена")
view.show() # Показываем окно

# Запускаем бесконечный цикл приложения (тот самый Game Loop)
sys.exit(app.exec())
