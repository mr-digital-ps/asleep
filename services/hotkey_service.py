import json
import copy
from pathlib import Path
from PyQt6.QtCore import QObject, pyqtSignal, QFileSystemWatcher, QTimer
from services.config_service import parse_json_with_comments

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
        "keys": ["Ctrl+Shift+B", "Alt+S"],
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
    },
    "toggle_graph": {
        "keys": ["Ctrl+G", "Ctrl+Shift+G"],
        "description": "Показать / скрыть интерактивный граф связей (Graph View)"
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
        self.project_root = Path(__file__).parent.parent.resolve()
        self.config_dir = self.project_root / "config"
        self.user_hotkeys_path = self.config_dir / "user" / "hotkeys.json"
        self.default_hotkeys_path = self.config_dir / "default" / "hotkeys.json"
        self.legacy_hotkeys_path = self.project_root / "hotkeys.json"
        self.custom_config_path = Path(config_file).resolve() if config_file else None

        self._hotkeys: dict = copy.deepcopy(DEFAULT_HOTKEYS)
        self._watcher = QFileSystemWatcher(self)
        self._reload_timer = QTimer(self)
        self._reload_timer.setSingleShot(True)
        self._reload_timer.setInterval(150)
        self._reload_timer.timeout.connect(self._on_reload_triggered)

        self._load_from_disk()
        self._setup_watcher()

    def _setup_watcher(self):
        paths_to_watch = []
        if self.custom_config_path:
            paths_to_watch.append(self.custom_config_path)
        else:
            paths_to_watch.extend([self.user_hotkeys_path, self.default_hotkeys_path, self.legacy_hotkeys_path])

        for p in paths_to_watch:
            if p.exists():
                p_str = str(p)
                if p_str not in self._watcher.files():
                    self._watcher.addPath(p_str)
        try:
            self._watcher.fileChanged.disconnect(self._on_file_changed)
        except Exception:
            pass
        self._watcher.fileChanged.connect(self._on_file_changed)

    def _on_file_changed(self, path: str):
        self._reload_timer.start()

    def _on_reload_triggered(self):
        self._setup_watcher()
        self._load_from_disk()
        self.hotkeys_changed.emit(self._hotkeys)
        print("[HotkeyService] Горячие клавиши перезагружены")

    def _load_from_disk(self):
        merged = copy.deepcopy(DEFAULT_HOTKEYS)

        def _merge_hk_dict(source_dict: dict):
            for action, val in source_dict.items():
                if action.startswith("_"):
                    continue
                if isinstance(val, dict):
                    merged[action] = {
                        "keys": val.get("keys", merged.get(action, {}).get("keys", [])),
                        "description": val.get("description", merged.get(action, {}).get("description", ""))
                    }
                elif isinstance(val, list):
                    merged[action] = {
                        "keys": val,
                        "description": merged.get(action, {}).get("description", "")
                    }

        # 1. Загрузка из default или legacy
        if self.custom_config_path and self.custom_config_path.exists():
            try:
                data = parse_json_with_comments(self.custom_config_path.read_text(encoding="utf-8"))
                if isinstance(data, dict):
                    _merge_hk_dict(data)
            except Exception as e:
                print(f"[HotkeyService] Ошибка чтения {self.custom_config_path.name}: {e}")
        else:
            if self.default_hotkeys_path.exists():
                try:
                    data = parse_json_with_comments(self.default_hotkeys_path.read_text(encoding="utf-8"))
                    if isinstance(data, dict):
                        _merge_hk_dict(data)
                except Exception as e:
                    print(f"[HotkeyService] Ошибка чтения {self.default_hotkeys_path.name}: {e}")
            elif self.legacy_hotkeys_path.exists():
                try:
                    data = parse_json_with_comments(self.legacy_hotkeys_path.read_text(encoding="utf-8"))
                    if isinstance(data, dict):
                        _merge_hk_dict(data)
                except Exception as e:
                    print(f"[HotkeyService] Ошибка чтения {self.legacy_hotkeys_path.name}: {e}")

            # 2. Переопределение из user_hotkeys_path
            if self.user_hotkeys_path.exists():
                try:
                    data = parse_json_with_comments(self.user_hotkeys_path.read_text(encoding="utf-8"))
                    if isinstance(data, dict):
                        _merge_hk_dict(data)
                except Exception as e:
                    print(f"[HotkeyService] Ошибка чтения {self.user_hotkeys_path.name}: {e}")

        self._hotkeys = merged

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
