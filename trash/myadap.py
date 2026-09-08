import sys

from PyQt6.QtWidgets import (QApplication, QWidget, QPushButton, QVBoxLayout, QTextEdit, QSplitter, QFrame, QMainWindow)
from PyQt6.QtCore import Qt


class MainApp(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("App")
        self.resize(800, 600)
    
        splitter = QSplitter(Qt.Orientation.Horizontal)

        sidebar_widget = QFrame()
        sidebar_layout = QVBoxLayout()

        btn1 = QPushButton("main")
        btn2 = QPushButton("secondary")

        sidebar_layout.addWidget(btn1)
        sidebar_layout.addWidget(btn2)
        sidebar_layout.addStretch()

        sidebar_widget.setLayout(sidebar_layout)
        sidebar_widget.setMinimumWidth(100)

        content_widget = QTextEdit("")
        content_widget.setMinimumWidth(200)

        splitter.addWidget(sidebar_widget)
        splitter.addWidget(content_widget)
        
        # Приклеиваем сплиттер в самый центр нашего QMainWindow
        self.setCentralWidget(splitter)


if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = MainApp()
    window.show()
    sys.exit(app.exec())
