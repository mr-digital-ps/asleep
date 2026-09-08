from PyQt6.QtWidgets import QGraphicsView
from PyQt6.QtWidgets import QGraphicsScene
from PyQt6.QtWidgets import QApplication, QWidget, QPushButton, QVBoxLayout, QMessageBox
import sys

def show_info():
    QMessageBox.information(None, "Information", "close it", QMessageBox.StandardButton.Ok)


app = QApplication(sys.argv)

scene = QGraphicsScene()
scene.setSceneRect(0, 0, 1000, 700)

view = QGraphicsView(scene)
view.show()

btn = QPushButton("button")
btn.clicked.connect(show_info)
scene.addWidget(btn)


sys.exit(app.exec())


