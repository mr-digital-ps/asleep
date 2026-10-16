import os
import sys
import json
from pathlib import Path
from PyQt6.QtCore import QUrl
from PyQt6.QtWidgets import QFileDialog

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if sys.stderr and hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

def _safe_print(*args, **kwargs):
    try:
        print(*args, **kwargs)
    except Exception:
        pass

from services.storage.config_service import ConfigService, deep_merge, parse_json_with_comments

_this_p = Path(__file__).resolve()
_root = _this_p.parent.parent if (_this_p.parent.parent / "config").exists() else _this_p.parent.parent.parent
DEFAULT_SESSION_FILE = _root / "config" / "default" / "session.json"
CONFIG_DIR = _root / "config" / "user"
CONFIG_FILE = CONFIG_DIR / "session.json"
_LEGACY_CONFIG_FILE = _root / ".session_config.json"

def load_session_config() -> dict:
    """Загружает настройки сессии по правилу Config-First (default -> user)"""
    cfg = {}
    try:
        if DEFAULT_SESSION_FILE.exists():
            cfg = parse_json_with_comments(DEFAULT_SESSION_FILE.read_text(encoding="utf-8"))
    except Exception as e:
        _safe_print(f"[FileService] Ошибка чтения {DEFAULT_SESSION_FILE.name}: {e}")

    try:
        if CONFIG_FILE.exists():
            user_cfg = parse_json_with_comments(CONFIG_FILE.read_text(encoding="utf-8"))
            if isinstance(user_cfg, dict):
                cfg = deep_merge(cfg, user_cfg)
                return cfg
        if _LEGACY_CONFIG_FILE.exists():
            data = json.loads(_LEGACY_CONFIG_FILE.read_text(encoding="utf-8"))
            try:
                CONFIG_DIR.mkdir(parents=True, exist_ok=True)
                CONFIG_FILE.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
                _LEGACY_CONFIG_FILE.unlink(missing_ok=True)
            except Exception:
                pass
            if isinstance(data, dict):
                cfg = deep_merge(cfg, data)
                return cfg
    except Exception:
        pass
    return cfg

def save_session_config(data: dict):
    try:
        user_cfg = {}
        if CONFIG_FILE.exists():
            try:
                user_cfg = parse_json_with_comments(CONFIG_FILE.read_text(encoding="utf-8"))
            except Exception:
                user_cfg = {}
        user_cfg.update(data)
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        CONFIG_FILE.write_text(json.dumps(user_cfg, ensure_ascii=False, indent=2), encoding="utf-8")
    except Exception as e:
        _safe_print(f"[FileService] Ошибка сохранения сессии: {e}")

def list_project_notes(folder_path: Path, *, config_service=None) -> list[Path]:
    """List project notes deterministically, without traversing hidden/service folders."""
    if not folder_path or not folder_path.is_dir():
        return []
    config = config_service or ConfigService()
    app = config.get_app_config(folder_path)
    syntax = config.get_syntax_config(folder_path).get("system_files", {})
    extensions = {ext.lower() for ext in app.get("supported_extensions", [".txt", ".md"])}
    ignored = {name.lower() for name in app.get("ignored_directories", [])}
    ignored.update({".git", ".asleep", "__pycache__", ".obsidian", "node_modules"})
    prefixes = tuple(syntax.get("ignore_prefixes", [".", "_"]))
    system_files = {syntax.get("graph_file", "_Граф связей.txt"), syntax.get("structure_file", "_notes.txt")}
    notes = []
    for directory, dirs, files in os.walk(folder_path, followlinks=False):
        dirs[:] = sorted(name for name in dirs if name.lower() not in ignored
                         and not name.startswith(".") and not name.startswith(prefixes)
                         and not (Path(directory) / name).is_symlink())
        for name in files:
            path = Path(directory) / name
            if (not name.startswith(".") and not name.startswith(prefixes)
                    and name not in system_files and path.suffix.lower() in extensions
                    and not path.is_symlink() and path.is_file()):
                notes.append(path)
    return sorted(notes, key=lambda path: path.relative_to(folder_path).as_posix())


class FileService:
    """
    Сервис файловой системы.
    Отвечает за чтение, запись, создание, переименование, удаление и выбор рабочих папок.
    """
    def __init__(self, config_service=None):
        self.config_service = config_service

    def list_project_notes(self, folder_path: Path) -> list[Path]:
        return list_project_notes(folder_path, config_service=self.config_service)

    @staticmethod
    def to_path(file_url: str) -> Path:
        """Переводит QML URL 'file:///C:/doc.txt' в путь Windows Path('C:/doc.txt')"""
        if not file_url:
            return Path()
        if file_url.startswith("file:"):
            return Path(QUrl(file_url).toLocalFile())
        return Path(file_url)

    @staticmethod
    def to_url(path_or_str: str | Path) -> str:
        """Переводит локальный путь или строку в формат QUrl (file:///C:/doc.txt)"""
        if not path_or_str:
            return ""
        s = str(path_or_str)
        if s.startswith("file:"):
            return s
        return QUrl.fromLocalFile(str(Path(s).resolve())).toString()

    def get_ignored_directories(self, folder: Path | None = None) -> set[str]:
        if self.config_service:
            try:
                app_cfg = self.config_service.get_app_config(folder)
                if "ignored_directories" in app_cfg and isinstance(app_cfg["ignored_directories"], list):
                    return {d.lower().strip() for d in app_cfg["ignored_directories"] if d}
            except Exception:
                pass
        return {".git", ".venv", "__pycache__", "node_modules", "venv", ".asleep"}

    def get_supported_extensions(self, folder: Path | None = None) -> set[str]:
        if self.config_service:
            try:
                app_cfg = self.config_service.get_app_config(folder)
                if "supported_extensions" in app_cfg and isinstance(app_cfg["supported_extensions"], list):
                    return {ext.lower().strip() for ext in app_cfg["supported_extensions"] if ext}
            except Exception:
                pass
        return {".txt", ".md"}

    def get_folder_files(self, folder_url: str) -> list:
        """Возвращает список файлов в рабочей папке с учетом настроек ignored_directories и supported_extensions"""
        try:
            folder = self.to_path(folder_url)
            if not folder.exists() or not folder.is_dir():
                return []

            ignored_dirs = self.get_ignored_directories(folder)
            supported_exts = self.get_supported_extensions(folder)

            items = []
            for p in sorted(folder.iterdir(), key=lambda x: (not x.is_dir(), x.name.lower())):
                if p.is_dir() and p.name.lower() in ignored_dirs:
                    continue
                if p.name.startswith("."):
                    continue
                if p.is_file():
                    if supported_exts and p.suffix.lower() not in supported_exts:
                        continue
                    items.append({
                        "name": p.name,
                        "fileUrl": QUrl.fromLocalFile(str(p.resolve())).toString(),
                        "isDir": False,
                        "ext": p.suffix.lower(),
                        "isSystem": p.name.startswith("_"),
                    })
            return items
        except Exception as e:
            _safe_print(f"[FileService] Ошибка получения файлов папки: {e}")
            return []

    def read_file(self, file_url: str) -> str:
        """Чтение файла по URL"""
        try:
            path = self.to_path(file_url)
            content = path.read_text(encoding="utf-8")
            return content
        except Exception as e:
            _safe_print(f"[FileService] Ошибка чтения: {e}")
            return ""

    def save_file(self, file_url: str, text: str) -> bool:
        try:
            path = self.to_path(file_url)
            path.parent.mkdir(parents=True, exist_ok=True)
            if path.exists():
                try:
                    if path.read_text(encoding="utf-8") == text:
                        return True
                except Exception:
                    pass
            path.write_text(text, encoding="utf-8")
            return True
        except Exception as e:
            _safe_print(f"[FileService] Ошибка сохранения: {e}")
            return False

    def delete_file(self, file_url: str) -> bool:
        """Удаляет файл с диска"""
        try:
            path = self.to_path(file_url)
            if path.exists() and path.is_file():
                path.unlink()
                _safe_print(f"[FileService] Файл удален: {path.name}")
                return True
            return False
        except Exception as e:
            _safe_print(f"[FileService] Ошибка удаления файла: {e}")
            return False

    def create_file_in_folder(self, folder_url: str, base_name: str = "Новый документ") -> dict:
        """Создает новый файл .txt на диске в рабочей папке"""
        try:
            folder = self.to_path(folder_url)
            if not folder.exists():
                folder.mkdir(parents=True, exist_ok=True)

            ext = ".txt"
            raw_name = base_name.strip()
            if raw_name.endswith(".txt"):
                raw_name = raw_name[:-4]
            if not raw_name:
                raw_name = "Новый документ"

            candidate = folder / f"{raw_name}{ext}"
            idx = 1
            while candidate.exists():
                candidate = folder / f"{raw_name} ({idx}){ext}"
                idx += 1

            candidate.write_text("", encoding="utf-8")
            _safe_print(f"[FileService] Создан новый файл: {candidate.resolve()}")

            return {
                "fileUrl": QUrl.fromLocalFile(str(candidate.resolve())).toString(),
                "fileName": candidate.name,
                "filePath": str(candidate.resolve()),
                "success": True,
            }
        except Exception as e:
            _safe_print(f"[FileService] Ошибка создания файла: {e}")
            return {"fileUrl": "", "fileName": base_name, "filePath": "", "success": False}

    def rename_file(self, file_url: str, new_name: str) -> dict:
        """Переименовывает существующий файл на диске"""
        try:
            path = self.to_path(file_url)
            if not path.exists():
                return {"success": False, "fileUrl": file_url, "fileName": path.name}

            raw = new_name.strip()
            if not raw:
                return {"success": False, "fileUrl": file_url, "fileName": path.name}

            target_ext = path.suffix or ".txt"
            if not raw.lower().endswith(target_ext.lower()):
                raw += target_ext

            new_path = path.parent / raw
            if new_path.resolve() == path.resolve():
                return {
                    "success": True,
                    "fileUrl": QUrl.fromLocalFile(str(new_path.resolve())).toString(),
                    "fileName": new_path.name
                }

            path.rename(new_path)
            _safe_print(f"[FileService] Файл переименован: {path.name} -> {new_path.name}")
            return {
                "success": True,
                "fileUrl": QUrl.fromLocalFile(str(new_path.resolve())).toString(),
                "fileName": new_path.name
            }
        except Exception as e:
            _safe_print(f"[FileService] Ошибка переименования: {e}")
            return {"success": False, "fileUrl": file_url, "fileName": ""}

    def get_default_folder(self) -> str:
        """Возвращает последнюю сохраненную папку либо дефолтную папку из конфигурации session.json"""
        try:
            cfg = load_session_config()
            last_folder = cfg.get("last_folder", "")
            if last_folder:
                p = self.to_path(last_folder)
                if p.exists() and p.is_dir():
                    return last_folder

            def_folder_str = cfg.get("default_folder", "~/Documents/Notes")
            def_path = Path(os.path.expanduser(def_folder_str)).resolve()
            try:
                def_path.mkdir(parents=True, exist_ok=True)
                return QUrl.fromLocalFile(str(def_path)).toString()
            except Exception:
                project_dir = Path(__file__).parent.resolve()
                return QUrl.fromLocalFile(str(project_dir)).toString()
        except Exception:
            return ""

    def choose_folder_dialog(self, initial_folder: str = "") -> dict:
        """Открывает нативный диалог выбора папки"""
        try:
            start_dir = ""
            if initial_folder:
                start_dir = str(self.to_path(initial_folder).resolve())
            if not start_dir or not Path(start_dir).exists():
                cfg = load_session_config()
                last_f = cfg.get("last_folder", "")
                if last_f and self.to_path(last_f).exists():
                    start_dir = str(self.to_path(last_f).resolve())
                else:
                    def_folder_str = cfg.get("default_folder", "~/Documents/Notes")
                    start_dir = str(Path(os.path.expanduser(def_folder_str)).resolve())

            chosen = QFileDialog.getExistingDirectory(None, "Выберите рабочую папку", start_dir)
            if chosen:
                path = Path(chosen).resolve()
                url = QUrl.fromLocalFile(str(path)).toString()
                name = path.name or str(path)
                save_session_config({"last_folder": url})
                return {
                    "success": True,
                    "folderUrl": url,
                    "folderName": name,
                    "folderPath": str(path),
                }
            return {"success": False, "folderUrl": "", "folderName": ""}
        except Exception as e:
            _safe_print(f"[FileService] Ошибка выбора папки: {e}")
            return {"success": False, "folderUrl": "", "folderName": ""}
