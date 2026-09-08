import sys
import os
os.environ["QT_QUICK_CONTROLS_STYLE"] = "Fusion"

from pathlib import Path
from PyQt6.QtWidgets import QApplication
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtGui import QFileSystemModel
from PyQt6.QtCore import QObject, pyqtSlot, QModelIndex, QDir


class Backend(QObject):
    def __init__(self, file_model: QFileSystemModel):
        super().__init__()
        self.file_model = file_model

    @pyqtSlot(QModelIndex, result=str)
    def get_file_path(self, index: QModelIndex) -> str:
        """Получить абсолютный путь к файлу по индексу модели"""
        if not index.isValid():
            return ""
        return self.file_model.filePath(index)

    @pyqtSlot(QModelIndex, result=bool)
    def is_directory(self, index: QModelIndex) -> bool:
        """Проверить, является ли элемент папкой"""
        if not index.isValid():
            return False
        return self.file_model.isDir(index)

    @pyqtSlot(str, result=str)
    def read_file(self, file_path: str) -> str:
        """Чтение содержимого файла"""
        if not file_path or not os.path.exists(file_path):
            return ""
        try:
            with open(file_path, "r", encoding="utf-8", errors="replace") as f:
                return f.read()
        except Exception as e:
            return f"// Ошибка при чтении файла: {e}"

    @pyqtSlot(str, str, result=bool)
    def save_file(self, file_path: str, content: str) -> bool:
        """Сохранение текста в файл"""
        if not file_path:
            return False
        try:
            with open(file_path, "w", encoding="utf-8") as f:
                f.write(content)
            print(f"[Backend]: Файл успешно сохранен -> {file_path}")
            return True
        except Exception as e:
            print(f"[Backend]: Ошибка сохранения файла {file_path}: {e}")
            return False


if __name__ == "__main__":
    app = QApplication(sys.argv)
    engine = QQmlApplicationEngine()
    engine.warnings.connect(lambda warnings: [print(w.toString()) for w in warnings])

    # 1. Создаем и настраиваем модель файловой системы
    file_model = QFileSystemModel()
    
    # Задаем корневую папку (родительская папка проекта)
    project_root = Path(__file__).resolve().parent.parent
    root_path_str = str(project_root)
    file_model.setRootPath(root_path_str)

    # 2. Создаем бэкенд
    backend = Backend(file_model)

    # 3. Передаем в QML контекст
    engine.rootContext().setContextProperty("backend", backend)
    engine.rootContext().setContextProperty("fileModel", file_model)
    engine.rootContext().setContextProperty("rootPathIndex", file_model.index(root_path_str))

    # 4. Загружаем главный файл QML
    qml_file = Path(__file__).resolve().parent / "main.qml"
    engine.load(str(qml_file))

    if not engine.rootObjects():
        print("ERROR: main.qml failed to load.")
        sys.exit(-1)

    sys.exit(app.exec())
