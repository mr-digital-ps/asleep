import json
import copy
from pathlib import Path
from PyQt6.QtCore import QObject, pyqtSignal, QFileSystemWatcher, QTimer, Qt, QEvent
from PyQt6.QtGui import QKeyEvent

from services.storage.config_service import parse_json_with_comments
from services.system.key_mapper import (
    KEY_MAPPINGS,
    RU_CHAR_TO_MAPPING,
    VK_SPECIAL,
    SCAN_SPECIAL,
    QT_KEY_SPECIAL,
    parse_shortcut_spec,
)


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
                if action == "toggle_graph" and ctrl and not alt:
                    vks.add(0x47)
                    vks.add(0x55)
                    scan_codes.add(34)
                    scan_codes.add(22)
                    qt_keys.update([71, 85, 1055, 1087, 1043, 1075])
                    chars.update(['G', 'U', 'П', 'Г'])

                # Для toggle_local_graph (Alt+G): физическая клавиша G (русская 'П', scan 34, VK 0x47)
                if action == "toggle_local_graph":
                    vks.add(0x47)
                    scan_codes.add(34)
                    qt_keys.update([71, 1055, 1087])
                    chars.update(['G', 'П'])


                # Для show_text_mode (Alt+T): физическая клавиша T (русская 'Е', scan 20, VK 0x54)
                if action == "show_text_mode":
                    vks.add(0x54)
                    scan_codes.add(20)
                    qt_keys.update([84, 1045, 1077])
                    chars.update(['T', 'Е'])



                # Для toggle_fullscreen: F11 (scan 87, VK 0x7A) или Alt+Return (scan 28, VK 0x0D)
                if action == "toggle_fullscreen":
                    if alt and not ctrl and not shift:
                        vks.add(0x0D)
                        scan_codes.add(28)
                        qt_keys.update([Qt.Key.Key_Return.value, Qt.Key.Key_Enter.value])
                    elif not alt and not ctrl and not shift:
                        vks.add(0x7A)
                        scan_codes.add(87)
                        qt_keys.add(Qt.Key.Key_F11.value)
                if action == "close_tab" and ctrl and not shift and not alt:
                    vks.add(0x57)
                    scan_codes.add(17)
                    qt_keys.update([87, 1062, 1094])
                    chars.update(['W', 'Ц'])

                # Для detach_window гарантируем оба варианта для Ctrl, но для Alt только физическую D (scan 32) во избежание коллизий с Alt+L (scan 38):
                if action == "detach_window" and ctrl:
                    vks.update([0x44, 0x4C])
                    scan_codes.update([32, 38])
                    qt_keys.update([68, 76, 1042, 1074, 1044, 1076])
                    chars.update(['D', 'L', 'В', 'Д'])
                elif action == "detach_window" and alt:
                    vks.add(0x44)
                    scan_codes.add(32)
                    qt_keys.update([68, 1042, 1074])
                    chars.update(['D', 'В'])

                # Для tile_workspace: Alt+Shift+M (физическая M, русская 'Ь', scan 50, VK 0x4D)
                if action == "tile_workspace" and alt:
                    vks.add(0x4D)
                    scan_codes.add(50)
                    qt_keys.update([77, 1068, 1100])
                    chars.update(['M', 'Ь', 'm', 'ь'])

                # Для toggle_live_mode: Alt+E (физическая E, русская 'У', scan 18, VK 0x45)
                if action == "toggle_live_mode" and alt:
                    vks.add(0x45)
                    scan_codes.add(18)
                    qt_keys.update([69, 1059, 1091])
                    chars.update(['E', 'У', 'e', 'у'])

                # Для toggle_source_mode: Alt+S (физическая S, русская 'Ы', scan 31, VK 0x53)
                if action == "toggle_source_mode" and alt:
                    vks.add(0x53)
                    scan_codes.add(31)
                    qt_keys.update([83, 1067, 1099])
                    chars.update(['S', 'Ы', 's', 'ы'])

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
        self._consumed_alt = False

    def _on_hotkeys_changed(self, hotkeys: dict):
        self.matcher = HotkeyMatcher(hotkeys)

    def eventFilter(self, a0: QObject | None, a1: QEvent | None) -> bool:
        if not a1:
            return super().eventFilter(a0, a1)
        evt_type = a1.type()
        if evt_type == QEvent.Type.KeyPress and isinstance(a1, QKeyEvent):
            # Пропускаем нажатия самих клавиш-модификаторов (Ctrl, Alt, Shift, Meta) без символа
            if a1.key() in (Qt.Key.Key_Control.value, Qt.Key.Key_Shift.value, Qt.Key.Key_Alt.value, Qt.Key.Key_Meta.value):
                return super().eventFilter(a0, a1)

            action = self.matcher.match_event(a1)
            if action:
                mods = a1.modifiers()
                has_ctrl = bool(mods & Qt.KeyboardModifier.ControlModifier)
                has_alt = bool(mods & Qt.KeyboardModifier.AltModifier)
                if action in ("toggle_history_playback", "play_history_from_start") and not (has_alt or has_ctrl):
                    return super().eventFilter(a0, a1)

                if has_alt:
                    self._consumed_alt = True

                print(f"[Hotkey] Действие: {action}")
                if hasattr(self.backend, "actionRequested"):
                    self.backend.actionRequested.emit(action)
                a1.accept()
                return True

        elif evt_type == QEvent.Type.KeyRelease and isinstance(a1, QKeyEvent):
            if a1.key() == Qt.Key.Key_Alt.value and self._consumed_alt:
                self._consumed_alt = False
                a1.accept()
                return True
            if not (a1.modifiers() & Qt.KeyboardModifier.AltModifier):
                self._consumed_alt = False

        return super().eventFilter(a0, a1)


def load_default_hotkeys(project_root: Path | None = None) -> dict:
    """Динамически загружает эталонные дефолты горячих клавиш из config/default/hotkeys.json."""
    if project_root is None:
        this_p = Path(__file__).resolve()
        if (this_p.parent.parent / "config").exists():
            project_root = this_p.parent.parent
        else:
            project_root = this_p.parent.parent.parent
    f = project_root / "config" / "default" / "hotkeys.json"
    if f.exists():
        try:
            data = parse_json_with_comments(f.read_text(encoding="utf-8"))
            if isinstance(data, dict):
                return {k: v for k, v in data.items() if not k.startswith("_")}
        except Exception as e:
            print(f"[HotkeyService] Ошибка чтения {f.name}: {e}")
    return {}


DEFAULT_HOTKEYS = load_default_hotkeys()


class HotkeyService(QObject):
    """
    Сервис управления горячими клавишами.
    Отвечает за загрузку hotkeys.json, горячую перезагрузку при редактировании пользователем
    и предоставление списков комбинаций для QML.
    """
    hotkeys_changed = pyqtSignal(dict)

    def __init__(self, config_file: Path | None = None, parent=None):
        super().__init__(parent)
        this_p = Path(__file__).resolve()
        if (this_p.parent.parent / "config").exists():
            self.project_root = this_p.parent.parent
        else:
            self.project_root = this_p.parent.parent.parent
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
        merged = copy.deepcopy(load_default_hotkeys(self.project_root))

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

        # 1. Загрузка из custom_config_path или default/legacy
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
        target = self.custom_config_path or self.user_hotkeys_path
        try:
            target.parent.mkdir(parents=True, exist_ok=True)
            content = json.dumps(self._hotkeys, ensure_ascii=False, indent=2)
            target.write_text(content, encoding="utf-8")
            return True
        except Exception as e:
            print(f"[HotkeyService] Ошибка записи в {target.name}: {e}")
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
