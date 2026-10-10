import sys
import re
import copy
from pathlib import Path
import yaml

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if sys.stderr and hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

def _safe_print(*args, **kwargs):
    try:
        print(*args, **kwargs)
    except Exception:
        pass

def strip_json_comments(text: str) -> str:
    """
    Удаляет комментарии вида // и /* */ из JSON, корректно сохраняя строки в кавычках
    (включая URL и escape-последовательности), а также очищает завершающие запятые.
    """
    pattern = r'("(?:\\.|[^"\\])*")|//[^\r\n]*|/\*[\s\S]*?\*/'
    def replace(match):
        if match.group(1):
            return match.group(1)
        return ""
    cleaned = re.sub(pattern, replace, text)
    cleaned = re.sub(r',(\s*[}\]])', r'\1', cleaned)
    return cleaned

def parse_json_with_comments(text: str) -> dict:
    """Безопасно парсит JSON с комментариями и висячими запятыми."""
    import json
    return json.loads(strip_json_comments(text))

FRONTMATTER_REGEX = re.compile(r"^---\r?\n(.*?)\r?\n---", re.DOTALL)

def load_default_base_config() -> dict:
    """Динамически загружает базовые настройки из config/default/*.json (Single Source of Truth)."""
    cfg = {
        "editor": {},
        "hotkeys": {},
        "tags": [],
        "pinned": [],
    }
    this_p = Path(__file__).resolve()
    if (this_p.parent.parent / "config" / "default").exists():
        config_dir = this_p.parent.parent / "config" / "default"
    else:
        config_dir = this_p.parent.parent.parent / "config" / "default"
    ed_f = config_dir / "editor.json"
    if ed_f.exists():
        try:
            data = parse_json_with_comments(ed_f.read_text(encoding="utf-8"))
            if isinstance(data, dict):
                cfg["editor"] = data
        except Exception as e:
            _safe_print(f"[ConfigService] Ошибка чтения {ed_f.name}: {e}")

    hk_f = config_dir / "hotkeys.json"
    if hk_f.exists():
        try:
            data = parse_json_with_comments(hk_f.read_text(encoding="utf-8"))
            if isinstance(data, dict):
                for action, val in data.items():
                    if isinstance(val, dict) and "keys" in val and isinstance(val["keys"], list):
                        for k in val["keys"]:
                            cfg["hotkeys"][k] = action
                    elif isinstance(val, str):
                        cfg["hotkeys"][action] = val
        except Exception as e:
            _safe_print(f"[ConfigService] Ошибка чтения {hk_f.name}: {e}")

    return cfg

DEFAULT_CONFIG = load_default_base_config()

def deep_merge(base: dict, override: dict) -> dict:
    """Глубокое рекурсивное слияние словарей: override дополняет и заменяет ключи base."""
    result = copy.deepcopy(base)
    if not isinstance(override, dict):
        return result
    for key, value in override.items():
        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = copy.deepcopy(value)
    return result

def extract_frontmatter(text: str) -> tuple[dict, str, bool]:
    """
    Извлекает YAML frontmatter из начала текста документа.
    Возвращает (parsed_dict, remaining_body, has_frontmatter).
    В случае синтаксических ошибок в YAML возвращает ({}, text, False) без падений.
    """
    if not text:
        return {}, "", False
    match = FRONTMATTER_REGEX.match(text)
    if not match:
        return {}, text, False
    
    yaml_block = match.group(1)
    body = text[match.end():]
    try:
        loaded = yaml.safe_load(yaml_block)
        if isinstance(loaded, dict):
            return loaded, body, True
        return {}, body, True
    except Exception as e:
        _safe_print(f"[ConfigService] Ошибка парсинга YAML frontmatter: {e}")
        return {}, body, False

def generate_folder_config_template(folder_name: str) -> str:
    """Генерирует стандартный самодокументированный файл настроек с комментариями."""
    return f"""---
# === Настройки редактора для этого каталога ===
editor:
  sheet_width: 800        # Ширина листа (в пикселях)
  font_size: 15           # Размер шрифта (в пикселях)
  line_height: 1.35       # Межстрочный интервал (от 1.2 до 1.8)
  show_line_dots: true    # Показывать ли точки строк слева
  tab_size: 4             # Количество пробелов при нажатии Tab

# === Полный список горячих клавиш редактора ===
hotkeys:
  # Основные
  Ctrl+S: save_file                 # Сохранить файл
  Ctrl+N: new_document              # Новый документ
  Ctrl+W: close_tab                 # Закрыть вкладку
  Ctrl+Wheel: zoom_font             # Масштаб шрифта (Ctrl + колесико мыши)

  # Работа со строками
  Ctrl+D: duplicate_line            # Дублировать текущую строку
  Alt+Up: move_line_up              # Переместить строку выше
  Alt+Down: move_line_down          # Переместить строку ниже

  # Быстрое форматирование
  Ctrl+B: bold_text                 # **Жирный текст**
  Ctrl+I: italic_text               # *Курсив*
  Ctrl+E: code_inline               # `Встроенный код`
  Ctrl+K: link_insert               # [Ссылка](url)
  Ctrl+Enter: toggle_task_checkbox  # Переключить чекбокс задачи (- [ ] / - [x])

  # Уровни заголовков
  Ctrl+1: heading_1                 # # Заголовок 1
  Ctrl+2: heading_2                 # ## Заголовок 2
  Ctrl+3: heading_3                 # ### Заголовок 3
  Ctrl+0: heading_clear             # Обычный текст

  # Вид, интерфейс и размеры
  Alt+W: toggle_centered_mode       # Переключить ширину листа (по центру / на всю ширину)
  Alt+F: toggle_footer              # Показать / скрыть нижний статус-бар (Footer)
  Alt+U: toggle_header              # Показать / скрыть верхний заголовок (Header)
  Alt+H: toggle_header_footer       # Показать / скрыть заголовок и статус-бар (F9)
  Alt+D: detach_window              # Открепить вкладку в отдельное окно (Ctrl+D)

# === Теги папки (для фильтрации и поиска) ===
tags:
  - проект
  - заметки

# === Закрепленные файлы в боковой панели ===
pinned: []
---

# _Настройка каталога {folder_name}
Этот файл содержит параметры рабочей папки. Префикс `_` указывает, что файл является служебным/системным.
Вы можете изменять значения выше между `---`. Настройки применяются автоматически при сохранении (Ctrl+S).

Ниже блока настроек можно вести любые заметки, ссылки и описание этого каталога.
"""

def compile_safe_regex(pattern: str | None, default_pattern: re.Pattern | str, flags: int = 0) -> re.Pattern:
    """
    Безопасно компилирует регулярное выражение.
    Если передан некорректный паттерн (синтаксическая ошибка от пользователя),
    выводит понятное предупреждение в лог и возвращает fallback (дефолтный паттерн),
    гарантируя, что парсер никогда не упадет.
    """
    fallback = default_pattern if isinstance(default_pattern, re.Pattern) else re.compile(default_pattern, flags)
    if not pattern or not isinstance(pattern, str):
        return fallback
    try:
        return re.compile(pattern, flags)
    except Exception as e:
        _safe_print(f"[ConfigService] Ошибка в пользовательском регулярном выражении '{pattern}': {e}. Применен безопасный дефолт.")
        return fallback

class ConfigService:
    """
    Сервис управления конфигурациями каталогов, редактора и модульных настроек приложения (config/).
    Отвечает за чтение Frontmatter, модульных JSON-конфигов, слияние с эталоном и генерацию шаблонов.
    """
    def __init__(self):
        this_p = Path(__file__).resolve()
        if (this_p.parent.parent / "config").exists():
            self.project_root = this_p.parent.parent
        else:
            self.project_root = this_p.parent.parent.parent
        self.config_dir = self.project_root / "config"
        self._current_folder: Path | None = None
        self._current_config: dict = copy.deepcopy(DEFAULT_CONFIG)

    @property
    def current_config(self) -> dict:
        return self._current_config

    def load_category_config(self, category: str, folder_path: Path | None = None) -> dict:
        """
        Загружает настройки указанной категории (editor, theme, app, hotkeys, graph):
        1. config/default/<category>.json
        2. config/user/<category>.json
        3. folder_path/_<category>_settings.json (если передан)
        """
        cfg = {}
        # 1. Системные дефолты (config/default/<category>.json)
        default_file = self.config_dir / "default" / f"{category}.json"
        if default_file.exists():
            try:
                data = parse_json_with_comments(default_file.read_text(encoding="utf-8"))
                if isinstance(data, dict):
                    cfg = deep_merge(cfg, data)
            except Exception as e:
                _safe_print(f"[ConfigService] Ошибка чтения {default_file.name}: {e}")

        # 2. Пользовательские переопределения (config/user/<category>.json), если папка/файл существуют
        user_file = self.config_dir / "user" / f"{category}.json"
        if user_file.exists():
            try:
                data = parse_json_with_comments(user_file.read_text(encoding="utf-8"))
                if isinstance(data, dict):
                    cfg = deep_merge(cfg, data)
            except Exception as e:
                _safe_print(f"[ConfigService] Ошибка чтения {user_file.name}: {e}")

        if folder_path and folder_path.exists() and folder_path.is_dir():
            candidates = [
                folder_path / ".asleep" / f"{category}_settings.json",
                folder_path / ".asleep" / f"_{category}_settings.json",
                folder_path / f"_{category}_settings.json",
                folder_path / f"{category}_settings.json"
            ]
            for v_file in candidates:
                if v_file.exists():
                    try:
                        data = parse_json_with_comments(v_file.read_text(encoding="utf-8"))
                        if isinstance(data, dict):
                            cfg = deep_merge(cfg, data)
                        break
                    except Exception as e:
                        _safe_print(f"[ConfigService] Ошибка чтения {v_file.name}: {e}")

        return cfg

    def get_editor_config(self, folder_path: Path | None = None) -> dict:
        return self.load_category_config("editor", folder_path)

    def get_theme_config(self, folder_path: Path | None = None) -> dict:
        return self.load_category_config("theme", folder_path)

    def get_app_config(self, folder_path: Path | None = None) -> dict:
        return self.load_category_config("app", folder_path)

    def get_syntax_config(self, folder_path: Path | None = None) -> dict:
        return self.load_category_config("syntax", folder_path)

    def get_session_config(self) -> dict:
        return self.load_category_config("session")

    @staticmethod
    def get_config_filename(folder_name: str) -> str:
        return f"_Настройка каталога {folder_name}.txt"

    @staticmethod
    def is_config_filename(filename: str) -> bool:
        return False


    def get_config_file_path(self, folder_path: Path) -> Path:
        if not folder_path or not folder_path.exists() or not folder_path.is_dir():
            return Path()
        return folder_path / self.get_config_filename(folder_path.name)

    def load_folder_config(self, folder_path: Path) -> dict:
        """Считывает настройки из папки, выполняет слияние с дефолтами и сохраняет в память."""
        self._current_folder = folder_path
        base = copy.deepcopy(DEFAULT_CONFIG)
        ed_cfg = self.get_editor_config(folder_path)
        if ed_cfg:
            base["editor"] = deep_merge(base["editor"], ed_cfg)

        if not folder_path or not folder_path.exists() or not folder_path.is_dir():
            self._current_config = base
            return self._current_config

        config_path = self.get_config_file_path(folder_path)
        if not config_path.exists():
            self._current_config = base
            return self._current_config

        try:
            content = config_path.read_text(encoding="utf-8")
            parsed_dict, _, _ = extract_frontmatter(content)
            self._current_config = deep_merge(base, parsed_dict)
        except Exception as e:
            _safe_print(f"[ConfigService] Ошибка чтения {config_path.name}: {e}")
            self._current_config = base

        return self._current_config

    def parse_and_update(self, text: str) -> dict:
        """Обновляет текущую конфигурацию из текста файла (при сохранении)"""
        base = copy.deepcopy(DEFAULT_CONFIG)
        ed_cfg = self.get_editor_config(self._current_folder)
        if ed_cfg:
            base["editor"] = deep_merge(base["editor"], ed_cfg)
        parsed_dict, _, _ = extract_frontmatter(text)
        self._current_config = deep_merge(base, parsed_dict)
        return self._current_config

    def update_folder_editor_setting(self, folder_path: Path, key: str, value) -> int:
        """
        Обновляет отдельный параметр редактора (например sheet_width или font_size) в файле настроек каталога.
        Возвращает новый st_mtime_ns файла или 0.
        """
        if not folder_path or not folder_path.exists():
            return 0
        cfg_file = self.get_config_file_path(folder_path)
        if not cfg_file or not cfg_file.exists():
            return 0
        try:
            content = cfg_file.read_text(encoding="utf-8")
            pattern = rf"^(\s*{re.escape(key)}\s*:\s*)[^\s#]+"
            if re.search(pattern, content, flags=re.MULTILINE):
                new_content = re.sub(pattern, rf"\g<1>{value}", content, count=1, flags=re.MULTILINE)
            else:
                parsed_dict, body, has_fm = extract_frontmatter(content)
                if has_fm:
                    if "editor" not in parsed_dict or not isinstance(parsed_dict["editor"], dict):
                        parsed_dict["editor"] = {}
                    parsed_dict["editor"][key] = value
                    new_yaml = yaml.dump(parsed_dict, allow_unicode=True, sort_keys=False)
                    new_content = f"---\n{new_yaml}---\n{body}"
                else:
                    return 0

            if new_content != content:
                cfg_file.write_text(new_content, encoding="utf-8")
            return cfg_file.stat().st_mtime_ns
        except Exception as e:
            _safe_print(f"[ConfigService] Ошибка обновления {key} в файле настроек: {e}")
            return 0

