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

FRONTMATTER_REGEX = re.compile(r"^---\r?\n(.*?)\r?\n---", re.DOTALL)

DEFAULT_CONFIG = {
    "editor": {
        "sheet_width": 800,
        "font_family": "Segoe UI, Inter, -apple-system, sans-serif",
        "font_size": 15,
        "line_height": 1.0,
        "show_line_dots": True,
        "padding_left": 0,
        "padding_right": 0,
        "padding_top": 6,
        "padding_bottom": 0,
        "typewriter_mode": False,
        "focus_mode": False,
    },
    "hotkeys": {
        # Основные операции
        "Ctrl+S": "save_file",                 # Сохранить файл
        "Ctrl+N": "new_document",              # Создать новый документ
        "Ctrl+W": "close_tab",                 # Закрыть текущую вкладку
        "Ctrl+Wheel": "zoom_font",             # Масштаб шрифта (Ctrl + колесико мыши)

        # Работа со строками
        "Ctrl+D": "duplicate_line",            # Дублировать строку
        "Alt+Up": "move_line_up",              # Переместить строку вверх
        "Alt+Down": "move_line_down",          # Переместить строку вниз

        # Форматирование текста
        "Ctrl+B": "bold_text",                 # Жирный текст (**текст**)
        "Ctrl+I": "italic_text",               # Курсив (*текст*)
        "Ctrl+E": "code_inline",               # Встроенный код (`код`)
        "Ctrl+K": "link_insert",               # Ссылка ([текст](url))
        "Ctrl+Enter": "toggle_task_checkbox",  # Переключить задачу (- [ ] / - [x])

        # Уровни заголовков
        "Ctrl+1": "heading_1",                 # # Заголовок 1
        "Ctrl+2": "heading_2",                 # ## Заголовок 2
        "Ctrl+3": "heading_3",                 # ### Заголовок 3
        "Ctrl+4": "heading_4",                 # #### Заголовок 4
        "Ctrl+5": "heading_5",                 # ##### Заголовок 5
        "Ctrl+6": "heading_6",                 # ###### Заголовок 6
        "Ctrl+0": "heading_clear",             # Обычный текст (снять заголовок)

        # Режимы фокуса и набора
        "Alt+Shift+T": "toggle_typewriter_mode", # Режим печатной машинки (курсор по центру)
        "Alt+Shift+F": "toggle_focus_mode",      # Режим фокусировки (подсветка активной строки)

        # Вид и размеры
        "Alt+Z": "toggle_full_width",          # Переключить ширину листа (занять всё пространство)
        "Alt+F": "toggle_full_width",          # Альтернатива: развернуть лист на всю ширину
    },
    "tags": [],
    "pinned": [],
}

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

def extract_frontmatter(md_text: str) -> tuple[dict, str, bool]:
    """
    Извлекает YAML frontmatter из начала Markdown текста.
    Возвращает (parsed_dict, remaining_body, has_frontmatter).
    В случае синтаксических ошибок в YAML возвращает ({}, md_text, False) без падений.
    """
    if not md_text:
        return {}, "", False
    match = FRONTMATTER_REGEX.match(md_text)
    if not match:
        return {}, md_text, False
    
    yaml_block = match.group(1)
    body = md_text[match.end():]
    try:
        loaded = yaml.safe_load(yaml_block)
        if isinstance(loaded, dict):
            return loaded, body, True
        return {}, body, True
    except Exception as e:
        _safe_print(f"[ConfigService] Ошибка парсинга YAML frontmatter: {e}")
        return {}, body, False

def generate_folder_config_template(folder_name: str) -> str:
    """Генерирует стандартный самодокументированный Markdown файл настроек с комментариями."""
    return f"""---
# === Настройки редактора для этого каталога ===
editor:
  sheet_width: 800        # Ширина листа (в пикселях)
  font_size: 15           # Размер шрифта (в пикселях)
  line_height: 1.35       # Межстрочный интервал (от 1.2 до 1.8)
  show_line_dots: true    # Показывать ли точки строк слева

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

  # Быстрое форматирование Markdown
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

  # Вид и размеры
  Alt+Z: toggle_full_width          # Переключить ширину листа (занять всё пространство)
  Alt+F: toggle_full_width          # Альтернатива: развернуть лист на всю ширину

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

class ConfigService:
    """
    Сервис управления конфигурациями каталогов, редактора и модульных настроек приложения (config/).
    Отвечает за чтение Markdown Frontmatter, модульных JSON-конфигов, слияние с эталоном и генерацию шаблонов.
    """
    def __init__(self):
        self.project_root = Path(__file__).resolve().parent.parent
        self.config_dir = self.project_root / "config"
        self._current_folder: Path | None = None
        self._current_config: dict = copy.deepcopy(DEFAULT_CONFIG)

    @property
    def current_config(self) -> dict:
        return self._current_config

    def load_category_config(self, category: str, folder_path: Path | None = None) -> dict:
        """
        Загружает настройки указанной категории (editor, theme, app, hotkeys, graph):
        1. config/<category>_default.json
        2. config/<category>_user.json
        3. folder_path/_<category>_settings.json (если передан)
        """
        cfg = {}
        default_file = self.config_dir / f"{category}_default.json"
        if default_file.exists():
            try:
                import json
                data = json.loads(default_file.read_text(encoding="utf-8"))
                if isinstance(data, dict):
                    cfg = deep_merge(cfg, data)
            except Exception as e:
                _safe_print(f"[ConfigService] Ошибка чтения {default_file.name}: {e}")

        user_file = self.config_dir / f"{category}_user.json"
        if user_file.exists():
            try:
                import json
                data = json.loads(user_file.read_text(encoding="utf-8"))
                if isinstance(data, dict):
                    cfg = deep_merge(cfg, data)
            except Exception as e:
                _safe_print(f"[ConfigService] Ошибка чтения {user_file.name}: {e}")

        if folder_path and folder_path.exists() and folder_path.is_dir():
            for fn in [f"_{category}_settings.json", f"{category}_settings.json"]:
                v_file = folder_path / fn
                if v_file.exists():
                    try:
                        import json
                        data = json.loads(v_file.read_text(encoding="utf-8"))
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

    @staticmethod
    def get_config_filename(folder_name: str) -> str:
        return f"_Настройка каталога {folder_name}.md"

    @staticmethod
    def is_config_filename(filename: str) -> bool:
        if not filename:
            return False
        fn = filename.strip().lower()
        return (
            fn.startswith("_настройка каталога ")
            or fn.startswith("настройка каталога ")
            or fn in ["_settings.md", ".settings.md", "folder_settings.md"]
        )

    def get_config_file_path(self, folder_path: Path) -> Path:
        if not folder_path or not folder_path.exists() or not folder_path.is_dir():
            return Path()
        preferred = folder_path / self.get_config_filename(folder_path.name)
        if preferred.exists():
            return preferred
        legacy = folder_path / f"Настройка каталога {folder_path.name}.md"
        if legacy.exists():
            return legacy
        return preferred

    def ensure_folder_config(self, folder_path: Path) -> Path:
        """Создает файл настроек, если он еще не существует, и возвращает путь."""
        if not folder_path or not folder_path.exists() or not folder_path.is_dir():
            return Path()
        config_path = self.get_config_file_path(folder_path)
        if not config_path.exists():
            template = generate_folder_config_template(folder_path.name)
            config_path.write_text(template, encoding="utf-8")
            _safe_print(f"[ConfigService] Создан файл настроек каталога: {config_path.name}")
        return config_path

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

