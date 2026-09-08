import sys
import os
from pathlib import Path
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtCore import QObject, pyqtSlot, pyqtSignal, QUrl


class TextEditorBackend(QObject):
    """
    Бэкенд текстового редактора.
    Отвечает за работу с файлами (чтение, сохранение) и вспомогательную логику.
    Интерфейс QML вызывает методы этого класса при нажатии на кнопки.
    """

    # Сигналы для передачи сообщений из Python в QML:
    statusChanged = pyqtSignal(str)   # Сообщение в статус-бар (например, "Файл сохранен")
    errorOccurred = pyqtSignal(str)   # Сообщение об ошибке (например, "Не удалось открыть файл")

    def __init__(self):
        super().__init__()

    def _url_to_path(self, file_url_or_path: str) -> Path:
        """
        Вспомогательная функция.
        QML диалоги возвращают пути в виде URL: 'file:///C:/folder/doc.txt'.
        QUrl(url).toLocalFile() аккуратно переводит это в обычный путь: 'C:/folder/doc.txt'.
        """
        if not file_url_or_path:
            return Path()
        if file_url_or_path.startswith("file:"):
            return Path(QUrl(file_url_or_path).toLocalFile())
        return Path(file_url_or_path)

    @pyqtSlot(str, result=str)
    def read_file(self, file_url: str) -> str:
        """
        СЛОТ: Чтение файла.
        Принимает URL или путь к файлу из QML и возвращает его текстовое содержимое.
        """
        try:
            path = self._url_to_path(file_url)
            if not path.is_file():
                self.errorOccurred.emit(f"Файл не найден: {path.name}")
                return ""

            # Сначала пробуем стандартный UTF-8
            try:
                content = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                # Если в файле кодировка Windows-1251
                content = path.read_text(encoding="cp1251")

            self.statusChanged.emit(f"Открыт файл: {path.name}")
            return content

        except Exception as e:
            self.errorOccurred.emit(f"Ошибка при чтении: {e}")
            return ""

    @pyqtSlot(str, str, result=bool)
    def save_file(self, file_url: str, content: str) -> bool:
        """
        СЛОТ: Сохранение текста в файл.
        Принимает путь и строку текста, записывает в файл в кодировке UTF-8.
        """
        try:
            path = self._url_to_path(file_url)
            if not path.name:
                self.errorOccurred.emit("Не указано имя файла!")
                return False

            path.write_text(content, encoding="utf-8")
            self.statusChanged.emit(f"Успешно сохранен: {path.name}")
            return True

        except Exception as e:
            self.errorOccurred.emit(f"Ошибка при сохранении: {e}")
            return False

    @pyqtSlot(str, result=str)
    def get_filename(self, file_url: str) -> str:
        """
        СЛОТ: Возвращает только имя файла (без папок),
        чтобы показать его в заголовке окна или строке статуса.
        """
        path = self._url_to_path(file_url)
        return path.name if path.name else "Новый документ"


def main():
    # Чтобы на Windows стили Qt Quick Controls работали без конфликтов
    os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"

    # Создаем экземпляр GUI приложения
    app = QGuiApplication(sys.argv)

    # Создаем QML движок
    engine = QQmlApplicationEngine()

    # Создаем наш бэкенд и передаем его в контекст QML под именем 'backend'
    backend = TextEditorBackend()
    engine.rootContext().setContextProperty("backend", backend)

    # Путь к QML файлу интерфейса
    qml_file = Path(__file__).parent / "main.qml"
    engine.load(str(qml_file))

    # Если корневой объект не создался — выходим с ошибкой
    if not engine.rootObjects():
        print("Не удалось загрузить QML интерфейс.")
        sys.exit(-1)

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
