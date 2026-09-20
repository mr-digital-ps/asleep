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

CONFIG_FILE = Path(__file__).parent.parent.resolve() / ".session_config.json"

def load_session_config() -> dict:
    try:
        if CONFIG_FILE.exists():
            return json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
    except Exception:
        pass
    return {}

def save_session_config(data: dict):
    try:
        cfg = load_session_config()
        cfg.update(data)
        CONFIG_FILE.write_text(json.dumps(cfg, ensure_ascii=False, indent=2), encoding="utf-8")
    except Exception as e:
        _safe_print(f"[FileService] Ошибка сохранения сессии: {e}")

class FileService:
    """
    Сервис файловой системы.
    Отвечает за чтение, запись, создание, переименование, удаление и выбор рабочих папок.
    """
    def __init__(self, config_service=None):
        self.config_service = config_service

    @staticmethod
    def to_path(file_url: str) -> Path:
        """Переводит QML URL 'file:///C:/doc.txt' в путь Windows Path('C:/doc.txt')"""
        if not file_url:
            return Path()
        if file_url.startswith("file:"):
            return Path(QUrl(file_url).toLocalFile())
        return Path(file_url)

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
        return {".md", ".markdown", ".txt"}

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
        """Создает новый файл .md на диске в рабочей папке"""
        try:
            folder = self.to_path(folder_url)
            if not folder.exists():
                folder.mkdir(parents=True, exist_ok=True)

            ext = ".md"
            raw_name = base_name.strip()
            if raw_name.endswith(".md"):
                raw_name = raw_name[:-3]
            elif raw_name.endswith(".txt"):
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

            target_ext = path.suffix or ".md"
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
        """Возвращает последнюю сохраненную папку либо дефолтную папку Notes"""
        try:
            cfg = load_session_config()
            last_folder = cfg.get("last_folder", "")
            if last_folder:
                p = self.to_path(last_folder)
                if p.exists() and p.is_dir():
                    return last_folder

            notes_dir = Path.home() / "Documents" / "Notes"
            try:
                notes_dir.mkdir(parents=True, exist_ok=True)
                return QUrl.fromLocalFile(str(notes_dir.resolve())).toString()
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
                    start_dir = str(Path.home() / "Documents")

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
