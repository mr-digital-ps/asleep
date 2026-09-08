import sys
from PyQt6.QtWidgets import (QApplication, QMainWindow, QSplitter, 
                             QTextEdit, QTreeView)
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QFileSystemModel

class EditorApp(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Мой Текстовый Редактор")
        self.resize(900, 600)
    
        # Главный сплиттер
        splitter = QSplitter(Qt.Orientation.Horizontal)

        # --- 1. Левая панель - Дерево файлов ---
        # QFileSystemModel - это встроенный "движок" Qt, который сам читает диск!
        self.file_model = QFileSystemModel()
        self.file_model.setRootPath("") # Начинаем с корня диска (можно указать конкретную папку)
        
        # QTreeView - это виджет, который визуально отображает данные в виде дерева
        self.tree_view = QTreeView()
        self.tree_view.setModel(self.file_model)
        
        # Опционально: скроем лишние колонки (размер, тип, дата), оставим только имя файла
        self.tree_view.setColumnHidden(1, True)
        self.tree_view.setColumnHidden(2, True)
        self.tree_view.setColumnHidden(3, True)

        # --- 2. Правая панель - Текстовый редактор ---
        self.editor = QTextEdit("Выбери файл слева...")
        
        # Добавляем в сплиттер
        splitter.addWidget(self.tree_view)
        splitter.addWidget(self.editor)
        
        # Задаем пропорции: дерево файлов поменьше (250), редактор побольше (650)
        splitter.setSizes([250, 650])
        
        # Приклеиваем сплиттер в центр окна
        self.setCentralWidget(splitter)


if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = EditorApp()
    window.show()
    sys.exit(app.exec())
