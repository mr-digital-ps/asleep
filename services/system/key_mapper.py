# services/key_mapper.py — Таблицы трансляции скан-кодов, виртуальных клавиш и парсинг хоткеев
from PyQt6.QtCore import Qt

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
    '[': {'scan': 26, 'vk': 0xDB, 'ru': 'Х', 'qt_ru': [1061, 1093]},
    ']': {'scan': 27, 'vk': 0xDD, 'ru': 'Ъ', 'qt_ru': [1066, 1098]},
    ';': {'scan': 39, 'vk': 0xBA, 'ru': 'Ж', 'qt_ru': [1046, 1078]},
    "'": {'scan': 40, 'vk': 0xDE, 'ru': 'Э', 'qt_ru': [1069, 1101]},
    ',': {'scan': 51, 'vk': 0xBC, 'ru': 'Б', 'qt_ru': [1041, 1073]},
    '.': {'scan': 52, 'vk': 0xBE, 'ru': 'Ю', 'qt_ru': [1070, 1102]},
    '`': {'scan': 41, 'vk': 0xC0, 'ru': 'Ё', 'qt_ru': [1025, 1105]},
    '\\': {'scan': 43, 'vk': 0xDC, 'ru': '\\', 'qt_ru': [92]},
    '/': {'scan': 53, 'vk': 0xBF, 'ru': '/', 'qt_ru': [47]},
}

# Обратный поиск: русская буква -> запись KEY_MAPPINGS
RU_CHAR_TO_MAPPING = {data['ru']: (letter, data) for letter, data in KEY_MAPPINGS.items()}

VK_SPECIAL = {
    'ESCAPE': 0x1B, 'ESC': 0x1B,
    'TAB': 0x09,
    'RETURN': 0x0D, 'ENTER': 0x0D,
    'BACKSLASH': 0xDC, '\\': 0xDC,
    'SLASH': 0xBF, '/': 0xBF,
    'SPACE': 0x20, ' ': 0x20,
    'LEFT': 0x25, 'ARROWLEFT': 0x25,
    'UP': 0x26, 'ARROWUP': 0x26,
    'RIGHT': 0x27, 'ARROWRIGHT': 0x27,
    'DOWN': 0x28, 'ARROWDOWN': 0x28,
}
for _i in range(1, 13):
    VK_SPECIAL[f'F{_i}'] = 0x70 + (_i - 1)

SCAN_SPECIAL = {
    'ESCAPE': {1}, 'ESC': {1},
    'TAB': {15},
    'RETURN': {28}, 'ENTER': {28},
    'BACKSLASH': {43, 86}, '\\': {43, 86},
    'SLASH': {53}, '/': {53},
    'SPACE': {57}, ' ': {57},
    'LEFT': {75, 57419, 0x4B}, 'ARROWLEFT': {75, 57419, 0x4B},
    'UP': {72, 57416, 0x48}, 'ARROWUP': {72, 57416, 0x48},
    'RIGHT': {77, 57421, 0x4D}, 'ARROWRIGHT': {77, 57421, 0x4D},
    'DOWN': {80, 57424, 0x50}, 'ARROWDOWN': {80, 57424, 0x50},
}
for _i in range(1, 13):
    if _i <= 10:
        SCAN_SPECIAL[f'F{_i}'] = {58 + _i}
    elif _i == 11:
        SCAN_SPECIAL[f'F{_i}'] = {87}
    elif _i == 12:
        SCAN_SPECIAL[f'F{_i}'] = {88}

QT_KEY_SPECIAL = {
    'ESCAPE': Qt.Key.Key_Escape, 'ESC': Qt.Key.Key_Escape,
    'TAB': Qt.Key.Key_Tab,
    'RETURN': Qt.Key.Key_Return, 'ENTER': Qt.Key.Key_Return,
    'BACKSLASH': Qt.Key.Key_Backslash, '\\': Qt.Key.Key_Backslash,
    'SLASH': Qt.Key.Key_Slash, '/': Qt.Key.Key_Slash,
    'SPACE': Qt.Key.Key_Space, ' ': Qt.Key.Key_Space,
    'LEFT': Qt.Key.Key_Left, 'ARROWLEFT': Qt.Key.Key_Left,
    'UP': Qt.Key.Key_Up, 'ARROWUP': Qt.Key.Key_Up,
    'RIGHT': Qt.Key.Key_Right, 'ARROWRIGHT': Qt.Key.Key_Right,
    'DOWN': Qt.Key.Key_Down, 'ARROWDOWN': Qt.Key.Key_Down,
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
        if up in SCAN_SPECIAL:
            scan_codes.update(SCAN_SPECIAL[up])
        if up in QT_KEY_SPECIAL:
            qt_keys.add(QT_KEY_SPECIAL[up].value)
        if up in KEY_MAPPINGS:
            m = KEY_MAPPINGS[up]
            scan_codes.add(m['scan'])
            vks.add(m['vk'])
            chars.add(m['ru'])
            q_ru = m['qt_ru']
            if isinstance(q_ru, (list, tuple, set)):
                for qtr in q_ru:
                    qt_keys.add(qtr)
            elif isinstance(q_ru, int):
                qt_keys.add(q_ru)

        # Буквы латиницы (A-Z)
        if len(up) == 1 and 'A' <= up <= 'Z':
            vks.add(ord(up))
            qt_key_enum = getattr(Qt.Key, f"Key_{up}", None)
            if qt_key_enum is not None:
                qt_keys.add(qt_key_enum.value)

        # Буквы кириллицы (ЙЦУКЕН)
        elif up in RU_CHAR_TO_MAPPING:
            lat_char, m = RU_CHAR_TO_MAPPING[up]
            chars.add(lat_char)
            scan_codes.add(m['scan'])
            vks.add(m['vk'])
            qt_key_enum = getattr(Qt.Key, f"Key_{lat_char}", None)
            if qt_key_enum is not None:
                qt_keys.add(qt_key_enum.value)
            q_ru = m['qt_ru']
            if isinstance(q_ru, (list, tuple, set)):
                for qtr in q_ru:
                    qt_keys.add(qtr)
            elif isinstance(q_ru, int):
                qt_keys.add(q_ru)

        # Цифры (0-9)
        elif len(up) == 1 and '0' <= up <= '9':
            vks.add(ord(up))
            qt_key_enum = getattr(Qt.Key, f"Key_{up}", None)
            if qt_key_enum is not None:
                qt_keys.add(qt_key_enum.value)
            digit = int(up)
            scan_codes.add(11 if digit == 0 else (1 + digit))

    return ctrl, shift, alt, vks, qt_keys, scan_codes, chars
