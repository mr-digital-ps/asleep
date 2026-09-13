import json
import copy
from pathlib import Path
from PyQt6.QtCore import QObject, pyqtSignal, QFileSystemWatcher, QTimer
from services.config_service import parse_json_with_comments

# Полная таблица аппаратных скан-кодов (PS/2 Set 1 для Windows), виртуальных клавиш (VK) и Qt/Unicode символов
KEY_MAPPINGS = {
    'Q': {'scan': 16, 'vk': 0x51, 'ru': 'Й', 'qt_ru': [1049, 1081]},
    'W': {'scan': 17, 'vk': 0x57, 'ru': 'Ц', 'qt_ru': [1062, 1094]},
    'E': {'scan': 18, 'vk': 0x45, 'ru': 'У', 'qt_ru': [1059, 1091]},
    'R': {'scan': 19, 'vk': 0x52, 'ru': 'К', 'qt_ru': [1050, 1082]},
    'T': {'scan': 20, 'vk': 0x54, 'ru': 'Е', 'qt_ru': [1045, 1077]},
    'Y': {'scan': 21, 'vk': 0x59, 'ru': 'Н', 'qt_ru': [1053, 1085]},
    'U': {'scan': 22, 'vk': 0x55, 'ru': 'Г', 'qt_ru': [1043, 1075]},
    'I': {'scan': 23, 'vk': 0x49, 'ru': 'Ш', 'qt_ru': [1064, 1096]},
    'O': {'scan': 24, 'vk': 0x4F, 'ru': 'Щ', 'qt_ru': [1065, 1097]},
    'P': {'scan': 25, 'vk': 0x50, 'ru': 'З', 'qt_ru': [1047, 1079]},
    'A': {'scan': 30, 'vk': 0x41, 'ru': 'Ф', 'qt_ru': [1060, 1092]},
    'S': {'scan': 31, 'vk': 0x53, 'ru': 'Ы', 'qt_ru': [1067, 1099]},
    'D': {'scan': 32, 'vk': 0x44, 'ru': 'В', 'qt_ru': [1042, 1074]},
    'F': {'scan': 33, 'vk': 0x46, 'ru': 'А', 'qt_ru': [1040, 1072]},
    'G': {'scan': 34, 'vk': 0x47, 'ru': 'П', 'qt_ru': [1055, 1087]},
    'H': {'scan': 35, 'vk': 0x48, 'ru': 'Р', 'qt_ru': [1056, 1088]},
    'J': {'scan': 36, 'vk': 0x4A, 'ru': 'О', 'qt_ru': [1054, 1086]},
    'K': {'scan': 37, 'vk': 0x4B, 'ru': 'Л', 'qt_ru': [1051, 1083]},
    'L': {'scan': 38, 'vk': 0x4C, 'ru': 'Д', 'qt_ru': [1044, 1076]},
    'Z': {'scan': 44, 'vk': 0x5A, 'ru': 'Я', 'qt_ru': [1071, 1103]},
    'X': {'scan': 45, 'vk': 0x58, 'ru': 'Ч', 'qt_ru': [1063, 1095]},
    'C': {'scan': 46, 'vk': 0x43, 'ru': 'С', 'qt_ru': [1057, 1089]},
    'V': {'scan': 47, 'vk': 0x56, 'ru': 'М', 'qt_ru': [1052, 1084]},
    'B': {'scan': 48, 'vk': 0x42, 'ru': 'И', 'qt_ru': [1048, 1080]},
    'N': {'scan': 49, 'vk': 0x4E, 'ru': 'Т', 'qt_ru': [1058, 1090]},
    'M': {'scan': 50, 'vk': 0x4D, 'ru': 'Ь', 'qt_ru': [1068, 1100]},
}

# Обратный поиск: русская буква -> запись KEY_MAPPINGS
RU_CHAR_TO_MAPPING = {data['ru']: (letter, data) for letter, data in KEY_MAPPINGS.items()}

VK_SPECIAL = {
    'ESCAPE': 0x1B, 'ESC': 0x1B,
    'TAB': 0x09,
    'RETURN': 0x0D, 'ENTER': 0x0D,
    'BACKSLASH': 0xDC, '\\': 0xDC,
    'SLASH': 0xBF, '/': 0xBF,
}
for _i in range(1, 13):
    VK_SPECIAL[f'F{_i}'] = 0x70 + (_i - 1)

from PyQt6.QtCore import Qt, QEvent
from PyQt6.QtGui import QKeyEvent

QT_KEY_SPECIAL = {
    'ESCAPE': Qt.Key.Key_Escape, 'ESC': Qt.Key.Key_Escape,
    'TAB': Qt.Key.Key_Tab,
    'RETURN': Qt.Key.Key_Return, 'ENTER': Qt.Key.Key_Return,
    'BACKSLASH': Qt.Key.Key_Backslash, '\\': Qt.Key.Key_Backslash,
    'SLASH': Qt.Key.Key_Slash, '/': Qt.Key.Key_Slash,
}
for _i in range(1, 13):
    QT_KEY_SPECIAL[f'F{_i}'] = getattr(Qt.Key, f'Key_F{_i}')


def parse_shortcut_spec(spec: str) -> tuple[bool, bool, bool, set[int], set[int], set[int], set[str]]:
    """
    Разбирает строку хоткея (например 'Ctrl+Shift+H', 'Ctrl+G', 'Ctrl+П', 'F9', 'Ctrl+\\')
    в кортеж: (ctrl, shift, alt, vks_set, qt_keys_set, scan_codes_set, chars_set).
    """
    parts = [p.strip() for p in spec.split("+") if p.strip()]
    ctrl = False
    shift = False
    alt = False
    vks = set()
    qt_keys = set()
    scan_codes = set()
    chars = set()

    key_token = ""
    for p in parts:
        pl = p.lower()
        if pl in ("ctrl", "control"):
            ctrl = True
        elif pl == "shift":
            shift = True
        elif pl == "alt":
            alt = True
        else:
            key_token = p

    if key_token:
        up = key_token.upper()
        chars.add(up)
        if up in VK_SPECIAL:
            vks.add(VK_SPECIAL[up])
        if up in QT_KEY_SPECIAL:
            qt_keys.add(QT_KEY_SPECIAL[up].value)

        # Буквы латиницы (A-Z)
        if len(up) == 1 and 'A' <= up <= 'Z':
            vks.add(ord(up))
            qt_key_enum = getattr(Qt.Key, f"Key_{up}", None)
            if qt_key_enum is not None:
                qt_keys.add(qt_key_enum.value)
            if up in KEY_MAPPINGS:
                m = KEY_MAPPINGS[up]
                scan_codes.add(m['scan'])
                chars.add(m['ru'])
                for qtr in m['qt_ru']:
                    qt_keys.add(qtr)

        # Буквы кириллицы (ЙЦУКЕН)
        elif up in RU_CHAR_TO_MAPPING:
            lat_char, m = RU_CHAR_TO_MAPPING[up]
            chars.add(lat_char)
            scan_codes.add(m['scan'])
            vks.add(m['vk'])
            qt_key_enum = getattr(Qt.Key, f"Key_{lat_char}", None)
            if qt_key_enum is not None:
                qt_keys.add(qt_key_enum.value)
            for qtr in m['qt_ru']:
                qt_keys.add(qtr)

        # Цифры (0-9)
        elif len(up) == 1 and '0' <= up <= '9':
            vks.add(ord(up))
            qt_key_enum = getattr(Qt.Key, f"Key_{up}", None)
            if qt_key_enum is not None:
                qt_keys.add(qt_key_enum.value)
            # Scan code для 0-9
            digit = int(up)
            scan_codes.add(11 if digit == 0 else (1 + digit))

    return ctrl, shift, alt, vks, qt_keys, scan_codes, chars


class HotkeyMatcher:
    """
    Высокопроизводительный матчер клавиш для кросс-раскладочной обработки хоткеев.
    Сопоставляет события нажатия клавиш на уровнях:
    1. nativeScanCode (аппаратный код физической клавиши на клавиатуре — 100% не зависит от раскладки)
    2. nativeVirtualKey (код виртуальной клавиши Windows)
    3. Qt.Key (перечисление Qt и Unicode кодовые точки)
    4. event.text() (символьное представление)
    """
    def __init__(self, hotkeys_dict: dict):
        self.rules = []
        self._compile(hotkeys_dict)

    def _compile(self, hotkeys_dict: dict):
        self.rules = []
        for action, data in hotkeys_dict.items():
            keys = data.get("keys", [])
            for k in keys:
                ctrl, shift, alt, vks, qt_keys, scan_codes, chars = parse_shortcut_spec(str(k))
                if not vks and not qt_keys and not scan_codes:
                    continue

                # Для toggle_graph гарантируем оба варианта:
                # 1. Физическая клавиша G (русская буква 'П', scan 34, VK 0x47)
                # 2. Мнемоническая буква 'Г' для "Граф" (физическая клавиша U, scan 22, VK 0x55)
                if action == "toggle_graph" and ctrl and not shift and not alt:
                    vks.add(0x47)
                    vks.add(0x55)
                    scan_codes.add(34)
                    scan_codes.add(22)
                    qt_keys.update([71, 85, 1055, 1087, 1043, 1075])
                    chars.update(['G', 'U', 'П', 'Г'])

                # Для close_tab гарантируем W (scan 17, 'Ц') и Q (scan 16, 'Й')
                if action == "close_tab" and ctrl and not shift and not alt:
                    vks.add(0x57)
                    vks.add(0x51)
                    scan_codes.add(17)
                    scan_codes.add(16)
                    qt_keys.update([87, 81, 1062, 1094, 1049, 1081])
                    chars.update(['W', 'Q', 'Ц', 'Й'])

                self.rules.append({
                    "action": action,
                    "ctrl": ctrl,
                    "shift": shift,
                    "alt": alt,
                    "vks": vks,
                    "qt_keys": qt_keys,
                    "scan_codes": scan_codes,
                    "chars": chars,
                })

    def match_event(self, event: QKeyEvent) -> str | None:
        mods = event.modifiers()
        ctrl = bool(mods & Qt.KeyboardModifier.ControlModifier)
        shift = bool(mods & Qt.KeyboardModifier.ShiftModifier)
        alt = bool(mods & Qt.KeyboardModifier.AltModifier)
        scan = event.nativeScanCode()
        vk = event.nativeVirtualKey()
        qt_key = event.key()
        txt = (event.text() or "").upper()

        for rule in self.rules:
            if rule["ctrl"] == ctrl and rule["shift"] == shift and rule["alt"] == alt:
                # 1. Сравнение по аппаратному скан-коду клавиши (неуязвимо к языку ввода)
                if scan and scan in rule["scan_codes"]:
                    return rule["action"]
                # 2. Сравнение по Virtual Key (Windows)
                if vk and vk in rule["vks"]:
                    return rule["action"]
                # 3. Сравнение по Qt.Key / Unicode коду
                if qt_key and qt_key in rule["qt_keys"]:
                    return rule["action"]
                # 4. Сравнение по тексту символа
                if txt and txt in rule["chars"]:
                    return rule["action"]
        return None


class GlobalHotkeyFilter(QObject):
    """
    Глобальный фильтр событий QApplication.
    Перехватывает нажатия горячих клавиш в любой точке приложения до того,
    как они могут быть поглощены элементами ввода или QML Shortcut.
    """
    def __init__(self, hotkey_service, backend, parent=None):
        super().__init__(parent)
        self.hotkey_service = hotkey_service
        self.backend = backend
        self.matcher = HotkeyMatcher(self.hotkey_service.get_hotkeys())
        self.hotkey_service.hotkeys_changed.connect(self._on_hotkeys_changed)

    def _on_hotkeys_changed(self, hotkeys: dict):
        self.matcher = HotkeyMatcher(hotkeys)

    def eventFilter(self, watched: QObject, event: QEvent) -> bool:
        if event.type() == QEvent.Type.KeyPress:
            action = self.matcher.match_event(event)
            if action:
                if hasattr(self.backend, "actionRequested"):
                    self.backend.actionRequested.emit(action)
                event.accept()
                return True
        return super().eventFilter(watched, event)


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
        "keys": ["Ctrl+D", "Alt+D"],
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
        Автоматически генерирует дублирующие шорткаты для русской раскладки клавиатуры.
        """
        EN_TO_RU = {
            'A': 'Ф', 'B': 'И', 'C': 'С', 'D': 'В', 'E': 'У', 'F': 'А', 'G': 'П', 'H': 'Р',
            'I': 'Ш', 'J': 'О', 'K': 'Л', 'L': 'Д', 'M': 'Ь', 'N': 'Т', 'O': 'Щ', 'P': 'З',
            'Q': 'Й', 'R': 'К', 'S': 'Ы', 'T': 'Е', 'U': 'Г', 'V': 'М', 'W': 'Ц', 'X': 'Ч',
            'Y': 'Н', 'Z': 'Я'
        }
        result = []
        seen = set()
        for action, data in self._hotkeys.items():
            keys = data.get("keys", [])
            desc = data.get("description", "")
            for k in keys:
                k_clean = str(k).strip()
                if k_clean and (action, k_clean) not in seen:
                    seen.add((action, k_clean))
                    result.append({
                        "action": action,
                        "key": k_clean,
                        "description": desc
                    })
                    # Генерируем аналог для русской раскладки
                    parts = k_clean.split("+")
                    last = parts[-1].upper()
                    if last in EN_TO_RU:
                        ru_key = "+".join(parts[:-1] + [EN_TO_RU[last]])
                        if (action, ru_key) not in seen:
                            seen.add((action, ru_key))
                            result.append({
                                "action": action,
                                "key": ru_key,
                                "description": desc
                            })
        return result

    def get_action_keys(self, action: str) -> list[str]:
        return self._hotkeys.get(action, {}).get("keys", [])
