import sys
import re
import time
from pathlib import Path
from PyQt6.QtCore import QUrl

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if sys.stderr and hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

def _safe_print(*args, **kwargs):
    try:
        print(*args, **kwargs)
    except Exception:
        pass

BLOCK_HEADING_REGEX = re.compile(r'^[ \t]*(#{1,6})\s+(.+)$', re.MULTILINE)

def parse_markdown_blocks(text: str) -> list:
    """
    Разбивает Markdown текст на блоки по заголовкам #..###### Заголовок.
    Возвращает список словарей со свойствами каждого блока.
    """
    if not text:
        return []
    matches = list(BLOCK_HEADING_REGEX.finditer(text))
    blocks = []
    for i, m in enumerate(matches):
        raw_title = m.group(2).strip()
        level = len(m.group(1).strip())
        content_start = m.end()
        content_end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        raw_content = text[content_start:content_end]
        clean_content = raw_content.strip("\r\n")
        blocks.append({
            "title": raw_title,
            "title_norm": raw_title.lower(),
            "content": clean_content,
            "heading_start": m.start(),
            "content_start": content_start,
            "content_end": content_end,
            "level": level
        })
    return blocks

def replace_block_in_markdown(text: str, target_heading_norm: str, new_content: str) -> tuple[str, bool]:
    """
    Находит блок с указанным заголовком (без учета регистра) и заменяет его содержимое.
    Возвращает (обновленный_текст, был_ли_заменен).
    """
    if not text:
        return text, False
    matches = list(BLOCK_HEADING_REGEX.finditer(text))
    for i, m in enumerate(matches):
        raw_title = m.group(2).strip()
        if raw_title.lower() == target_heading_norm.lower():
            content_start = m.end()
            content_end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
            
            clean_new = new_content.strip("\r\n")
            if clean_new:
                formatted = "\n" + clean_new + ("\n\n" if i + 1 < len(matches) else "\n")
            else:
                formatted = "\n"
                
            new_text = text[:content_start] + formatted + text[content_end:]
            return new_text, True
    return text, False


class BlockEngine:
    """
    Движок индексации и синхронизации блоков Markdown (Трансклюзия).
    Управляет кэшем блоков в памяти и слиянием коллизий.
    """
    def __init__(self):
        self._block_cache = {}  # norm_title -> {"title": raw, "content": text, "source": url, "time": float}

    def reindex_folder(self, folder: Path, extensions: list[str] | set[str] | None = None):
        """Сканирует папку и индексирует блоки из всех поддерживаемых файлов"""
        if not folder or not folder.exists() or not folder.is_dir():
            return
        try:
            exts = {e.lower().strip() for e in extensions} if extensions else {".md", ".markdown", ".txt"}
            files = [p for p in folder.iterdir() if p.is_file() and p.suffix.lower() in exts]
            files.sort(key=lambda x: x.stat().st_mtime if x.exists() else 0)
            for p in files:
                try:
                    text = p.read_text(encoding="utf-8")
                    blocks = parse_markdown_blocks(text)
                    file_url = QUrl.fromLocalFile(str(p.resolve())).toString()
                    mtime = p.stat().st_mtime
                    for b in blocks:
                        if b["content"]:
                            self._block_cache[b["title_norm"]] = {
                                "title": b["title"],
                                "content": b["content"],
                                "source": file_url,
                                "time": mtime
                            }
                except Exception:
                    pass
        except Exception as e:
            _safe_print(f"[BlockEngine] Ошибка индексации папки: {e}")

    def index_file_content(self, file_url: str, text: str):
        """Обновляет индекс блоков из сохраненного файла"""
        blocks = parse_markdown_blocks(text)
        now = time.time()
        for b in blocks:
            if b["content"]:
                self._block_cache[b["title_norm"]] = {
                    "title": b["title"],
                    "content": b["content"],
                    "source": file_url,
                    "time": now
                }

    def get_block(self, heading: str) -> dict:
        """Возвращает блок по заголовку (для подтягивания контента в новый файл)"""
        if not heading:
            return {"found": False, "title": "", "content": ""}
        norm = heading.strip().lower()
        if norm in self._block_cache:
            item = self._block_cache[norm]
            if item["content"].strip():
                return {
                    "found": True,
                    "title": item["title"],
                    "content": item["content"],
                }
        return {"found": False, "title": heading, "content": ""}

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

        # Сохраняем актуальный контент блока в кэше
        self._block_cache[norm] = {
            "title": raw_title,
            "content": clean_content,
            "source": source_file_url,
            "time": time.time()
        }
        return norm, clean_content, True
