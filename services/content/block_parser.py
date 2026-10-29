import sys
import re
import time
from pathlib import Path
from PyQt6.QtCore import QUrl
from services.content.document_outline import parse_user_dialect
from services.storage.file_service import list_project_notes

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if sys.stderr and hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

def _safe_print(*args, **kwargs):
    try:
        print(*args, **kwargs)
    except Exception:
        pass


def parse_syntax_blocks(text: str, heading_regex: re.Pattern | None = None) -> list:
    """
    Разбивает текст на именованные блоки `Имя Блока { ... }` по спецификации диалекта.
    Возвращает список словарей со свойствами каждого блока.
    """
    if not text:
        return []
    res = parse_user_dialect(text)
    blocks = []
    for b in res["blocks"]:
        raw_cnt = b["content"].strip("\r\n")
        blocks.append({
            "title": b["name"],
            "title_norm": b["name_norm"],
            "content": b["content"].strip(),
            "raw_content": raw_cnt,
            "heading_start": b["start_char"],
            "content_start": b["start_char"],
            "level": b.get("level", 1),
            "parent_name": b.get("parent_name", ""),
            "parent_norm": b.get("parent_norm", ""),
            "children": b.get("children", [])
        })
    return blocks


def replace_syntax_block(text: str, target_heading_norm: str, new_content: str, heading_regex: re.Pattern | None = None) -> tuple[str, bool]:
    """
    Находит именованный блок с указанным именем (без учета регистра) и заменяет его содержимое.
    Возвращает (обновленный_текст, был_ли_заменен).
    """
    if not text:
        return text, False
    res = parse_user_dialect(text)
    norm = target_heading_norm.strip().lower()
    for b in res["blocks"]:
        if b["name_norm"] == norm:
            clean_new = new_content.strip("\r\n")
            formatted = f"{b['name']} {{\n    {clean_new}\n}}" if clean_new else f"{b['name']} {{\n}}"
            new_text = text[:b["start_char"]] + formatted + text[b["end_char"]:]
            return new_text, True
    return text, False


class BlockEngine:
    """
    Движок индексации и синхронизации именованных блоков (Трансклюзия).
    Управляет кэшем блоков в памяти и слиянием коллизий.
    """
    def __init__(self, config_service=None):
        self.config_service = config_service
        self._block_cache = {}  # norm_title -> {"title": raw, "content": text, "source": url, "time": float}
        self.workspace_folder: Path | None = None

    def get_heading_regex(self) -> re.Pattern | None:
        return None

    def reindex_folder(self, folder: Path, extensions: list[str] | set[str] | None = None):
        """Сканирует папку и индексирует именованные блоки из всех файлов"""
        if not folder or not folder.exists() or not folder.is_dir():
            return
        self.workspace_folder = folder
        try:
            files = list_project_notes(folder, config_service=self.config_service)
            if extensions is not None:
                exts = {e.lower().strip() for e in extensions}
                files = [p for p in files if p.suffix.lower() in exts]
            self._block_cache.clear()
            files.sort(key=lambda x: x.stat().st_mtime if x.exists() else 0)
            for p in files:
                try:
                    text = p.read_text(encoding="utf-8")
                    blocks = parse_syntax_blocks(text)
                    file_url = QUrl.fromLocalFile(str(p.resolve())).toString()
                    mtime = p.stat().st_mtime
                    for b in blocks:
                        if b["content"]:
                            self._block_cache[b["title_norm"]] = {
                                "title": b["title"],
                                "content": b["content"],
                                "raw_content": b.get("raw_content", b["content"]),
                                "source": file_url,
                                "time": mtime
                            }
                except Exception:
                    pass
        except Exception as e:
            _safe_print(f"[BlockEngine] Ошибка индексации папки: {e}")

    def index_file_content(self, file_url: str, text: str):
        """Обновляет индекс блоков из сохраненного файла"""
        blocks = parse_syntax_blocks(text)
        now = time.time()
        for b in blocks:
            if b["content"]:
                self._block_cache[b["title_norm"]] = {
                    "title": b["title"],
                    "content": b["content"],
                    "raw_content": b.get("raw_content", b["content"]),
                    "source": file_url,
                    "time": now
                }

    def get_block(self, heading: str) -> dict:
        """Возвращает блок по имени (для подтягивания контента в локальной трансклюзии Имя())"""
        if not heading:
            return {"found": False, "title": "", "content": "", "raw_content": "", "source_file": "", "source_url": ""}
        norm = heading.strip().lower()
        if norm in self._block_cache:
            item = self._block_cache[norm]
            if item["content"].strip():
                src = item.get("source", "")
                stem = Path(QUrl(src).toLocalFile()).stem if src else ""
                return {
                    "found": True,
                    "title": item["title"],
                    "content": item["content"],
                    "raw_content": item.get("raw_content", item["content"]),
                    "source_file": stem,
                    "source_url": src
                }
        return {"found": False, "title": heading, "content": "", "raw_content": "", "source_file": "", "source_url": ""}

    def get_external_block(self, file_stem: str, block_name: str) -> dict:
        """Возвращает блок из конкретного внешнего файла Файл.Блок()"""
        if not file_stem or not block_name:
            return {"found": False, "title": "", "content": "", "raw_content": "", "source_file": "", "source_url": ""}
        f_norm = file_stem.strip().lower()
        b_norm = block_name.strip().lower()

        # 1. Поиск в кэше
        for norm_title, item in self._block_cache.items():
            if norm_title == b_norm:
                src = item.get("source", "")
                if src:
                    stem = Path(QUrl(src).toLocalFile()).stem.lower()
                    if stem == f_norm:
                        return {
                            "found": True,
                            "title": item["title"],
                            "content": item["content"],
                            "raw_content": item.get("raw_content", item["content"]),
                            "source_file": Path(QUrl(src).toLocalFile()).stem,
                            "source_url": src
                        }

        # 2. Если в кэше не найден, ищем файл в workspace_folder
        if self.workspace_folder and self.workspace_folder.exists():
            for p in self.workspace_folder.glob(f"**/{file_stem}.*"):
                if p.suffix.lower() in (".af", ".txt", ".md"):
                    try:
                        text = p.read_text(encoding="utf-8")
                        blocks = parse_syntax_blocks(text)
                        file_url = QUrl.fromLocalFile(str(p.resolve())).toString()
                        for b in blocks:
                            if b["title_norm"] == b_norm and b["content"]:
                                return {
                                    "found": True,
                                    "title": b["title"],
                                    "content": b["content"],
                                    "raw_content": b.get("raw_content", b["content"]),
                                    "source_file": p.stem,
                                    "source_url": file_url
                                }
                    except Exception:
                        pass

        return {"found": False, "title": block_name, "content": "", "raw_content": "", "source_file": file_stem, "source_url": ""}

    def get_available_blocks(self, query: str = "") -> list:
        """Возвращает список известных блоков для подсказок"""
        query_norm = query.strip().lower()
        res = []
        for norm, item in self._block_cache.items():
            if not query_norm or query_norm in norm:
                res.append({
                    "title": item["title"],
                    "content": item["content"][:100],
                })
        return res

    def sync_block_data(self, source_file_url: str, heading: str, content: str) -> tuple[str, str, bool]:
        """
        Проверяет и готовит контент к синхронизации с защитой от пустоты и слиянием коллизий.
        Возвращает: (norm_title, final_content, should_broadcast).
        """
        if not heading:
            return "", "", False
        norm = heading.strip().lower()
        raw_title = heading.strip()
        clean_content = content.strip("\r\n")

        # Защита 1: Пустой контент свежего блока не должен затирать существующий блок
        if not clean_content:
            if norm in self._block_cache and self._block_cache[norm]["content"].strip():
                _safe_print(f"[BlockEngine] Защита: блок '{raw_title}' уже содержит данные, затирание пустотой отклонено.")
                return norm, self._block_cache[norm]["content"], False

        self._block_cache[norm] = {
            "title": raw_title,
            "content": clean_content,
            "source": source_file_url,
            "time": time.time()
        }
        return norm, clean_content, True
