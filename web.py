import sys
import os
from pathlib import Path

# Гарантируем корректный sys.path независимо от рабочей директории запуска
PROJECT_DIR = Path(__file__).parent.resolve()
if str(PROJECT_DIR) not in sys.path:
    sys.path.insert(0, str(PROJECT_DIR))

# Предотвращаем сбой загрузки отсутствующего плагина Windows стиля в PyQt6
os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"

# Обеспечиваем корректный вывод UTF-8 в консоль Windows
if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if sys.stderr and hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

from PyQt6.QtWidgets import QApplication
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtCore import QUrl

from services.core import Backend, configure_surface_format
from services.system import setup_live_reload

# Реэкспорт Backend для обратной совместимости с тестами и модулями
__all__ = ["Backend", "main"]


def main():
    """Точка входа приложения Asleep Text Editor."""
    configure_surface_format()
    app = QApplication(sys.argv)
    app.setApplicationName("Asleep Text Editor")
    app.setOrganizationName("Asleep")

    engine = QQmlApplicationEngine()
    engine.addImportPath(str(PROJECT_DIR))
    engine.addImportPath(str(PROJECT_DIR / "components"))
    backend = Backend()
    engine.rootContext().setContextProperty("backend", backend)

    qml_file = PROJECT_DIR / "views" / "window.qml"
    engine.load(QUrl.fromLocalFile(str(qml_file)))

    if not engine.rootObjects():
        print("[Python] Критическая ошибка: Не удалось загрузить окно QML!")
        sys.exit(-1)

    setup_live_reload(engine, qml_file)
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
