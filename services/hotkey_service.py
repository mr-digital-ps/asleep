import json
import copy
from pathlib import Path
from PyQt6.QtCore import QObject, pyqtSignal, QFileSystemWatcher, QTimer

DEFAULT_HOTKEYS = {
    "toggle_header_footer": {
        "keys": ["F9", "Ctrl+Shift+H", "Alt+H"],
        "description": "Показать / скрыть заголовок и статус-бар (Header и Footer)"
    },
    "toggle_footer": {
        "keys": ["Ctrl+Shift+F", "Alt+F"],
        "description": "Показать / скрыть только нижний статус-бар (Footer)"
    },
    "toggle_header": {
        "keys": ["Ctrl+Shift+U", "Alt+U"],
        "description": "Показать / скрыть только верхний заголовок (Header)"
    },
    "toggle_sidebar": {
        "keys": ["Ctrl+B"],
        "description": "Показать / скрыть боковую панель"
    },
    "toggle_split": {
        "keys": ["Ctrl+\\"],
        "description": "Разделить экран (Split View)"
    },
    "toggle_centered_mode": {
        "keys": ["Alt+W", "Ctrl+Shift+W"],
        "description": "Переключить ширину листа (по центру / на всю ширину)"
    },
    "close_tab": {
        "keys": ["Ctrl+W", "Ctrl+Q", "Ctrl+F4"],
        "description": "Закрыть текущую вкладку или сплит"
    },
    "new_tab": {
        "keys": ["Ctrl+N"],
        "description": "Создать новый документ"
    },
    "open_file": {
        "keys": ["Ctrl+O"],
        "description": "Открыть файл"
    },
    "save_file": {
        "keys": ["Ctrl+S"],
        "description": "Сохранить файл"
    },
    "toggle_bold": {
        "keys": ["Ctrl+B"],
        "description": "Сделать выделенный текст жирным (**текст**)"
    },
    "toggle_italic": {
        "keys": ["Ctrl+I"],
        "description": "Сделать выделенный текст курсивом (*текст*)"
    },
    "detach_window": {
        "keys": ["Ctrl+D"],
        "description": "Открепить документ в отдельное окно"
    }
}


class HotkeyService(QObject):
    """
    Сервис управления горячими клавишами.
    Отвечает за загрузку hotkeys.json, горячую перезагрузку при редактировании пользователем
    и предоставление списков комбинаций для QML.
    """
    hotkeys_changed = pyqtSignal(dict)

    def __init__(self, config_file: Path | None = None, parent=None):
        super().__init__(parent)
        if config_file is None:
            self.config_path = Path(__file__).parent.parent.resolve() / "hotkeys.json"
        else:
            self.config_path = Path(config_file).resolve()

        self._hotkeys: dict = copy.deepcopy(DEFAULT_HOTKEYS)
        self._watcher = QFileSystemWatcher(self)
        self._reload_timer = QTimer(self)
        self._reload_timer.setSingleShot(True)
        self._reload_timer.setInterval(150)
        self._reload_timer.timeout.connect(self._on_reload_triggered)

        self._load_from_disk()
        self._setup_watcher()

    def _setup_watcher(self):
        if self.config_path.exists():
            watched = self._watcher.files()
            p_str = str(self.config_path)
            if p_str not in watched:
                self._watcher.addPath(p_str)
            self._watcher.fileChanged.connect(self._on_file_changed)

    def _on_file_changed(self, path: str):
        # На некоторых ОС при сохранении файл удаляется и создается заново
        self._reload_timer.start()

    def _on_reload_triggered(self):
        if not self.config_path.exists():
            return
        p_str = str(self.config_path)
        if p_str not in self._watcher.files():
            self._watcher.addPath(p_str)
        self._load_from_disk()
        self.hotkeys_changed.emit(self._hotkeys)
        print(f"[HotkeyService] Горячие клавиши перезагружены из {self.config_path.name}")

    def _load_from_disk(self):
        if not self.config_path.exists():
            self._hotkeys = copy.deepcopy(DEFAULT_HOTKEYS)
            self.save_to_disk()
            return

        try:
            content = self.config_path.read_text(encoding="utf-8")
            data = json.loads(content)
            if isinstance(data, dict):
                # Дополняем отсутствующими в файле дефолтными ключами
                merged = copy.deepcopy(DEFAULT_HOTKEYS)
                for action, val in data.items():
                    if isinstance(val, dict):
                        merged[action] = {
                            "keys": val.get("keys", DEFAULT_HOTKEYS.get(action, {}).get("keys", [])),
                            "description": val.get("description", DEFAULT_HOTKEYS.get(action, {}).get("description", ""))
                        }
                    elif isinstance(val, list):
                        merged[action] = {
                            "keys": val,
                            "description": DEFAULT_HOTKEYS.get(action, {}).get("description", "")
                        }
                self._hotkeys = merged
            else:
                self._hotkeys = copy.deepcopy(DEFAULT_HOTKEYS)
        except Exception as e:
            print(f"[HotkeyService] Ошибка чтения {self.config_path.name}: {e}")
            self._hotkeys = copy.deepcopy(DEFAULT_HOTKEYS)

    def save_to_disk(self) -> bool:
        try:
            content = json.dumps(self._hotkeys, ensure_ascii=False, indent=2)
            self.config_path.write_text(content, encoding="utf-8")
            return True
        except Exception as e:
            print(f"[HotkeyService] Ошибка записи в {self.config_path.name}: {e}")
            return False

    def get_hotkeys(self) -> dict:
        """Возвращает полный словарь действий со списком клавиш и описанием."""
        return self._hotkeys

    def get_flat_shortcuts(self) -> list[dict]:
        """
        Возвращает плоский список шорткатов для удобного биндинга в QML:
        [{"action": "toggle_header_footer", "key": "F9", "description": "..."}, ...]
        """
        result = []
        for action, data in self._hotkeys.items():
            keys = data.get("keys", [])
            desc = data.get("description", "")
            for k in keys:
                k_clean = str(k).strip()
                if k_clean:
                    result.append({
                        "action": action,
                        "key": k_clean,
                        "description": desc
                    })
        return result

    def get_action_keys(self, action: str) -> list[str]:
        return self._hotkeys.get(action, {}).get("keys", [])
