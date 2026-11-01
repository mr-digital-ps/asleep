# services/content/markdown_exporter.py — Двусторонний конвертер и экспорт диалекта в стандартный Markdown
from __future__ import annotations
import re
from pathlib import Path
from urllib.parse import urlparse, unquote


def dialect_to_markdown(text: str) -> str:
    """
    Конвертирует 14 единиц диалекта asleep-pyqt в чистый стандартный Markdown (CommonMark / Obsidian).
    - Именованные блоки `Имя { ... }` -> `### Имя\n\n...`
    - Трансклюзии `Файл.Блок()` -> `![[Файл#Блок]]`
    - Локальные трансклюзии `Блок()` -> `![[#Блок]]`
    - Акторы `@[Персонаж]` -> `**@Персонаж**`
    - Свернутые маркеры `Имя ....` -> `### Имя`
    """
    if not text:
        return ""

    lines = text.split("\n")
    out_lines = []
    i = 0
    n = len(lines)

    # Регулярки для элементов диалекта
    re_block_start = re.compile(r"^(\s*)([A-Za-z0-9А-Яа-я_\-\s\.\(\)]+?)\s*\{\s*$")
    re_block_single = re.compile(r"^(\s*)([A-Za-z0-9А-Яа-я_\-\s\.\(\)]+?)\s*\{\s*(.*?)\s*\}\s*$")
    re_block_collapsed = re.compile(r"^(\s*)([A-Za-z0-9А-Яа-я_\-\s\.\(\)]+?)\s*\.{3,4}\s*$")
    re_actor = re.compile(r"@\[([^\]]+)\]")
    re_ext_trans = re.compile(r"(?<!\S)([A-Za-z0-9А-Яа-я_\-]+(?:\s+[A-Za-z0-9А-Яа-я_\-]+)*)\.([A-Za-z0-9А-Яа-я_\-]+)\(\)")
    re_loc_trans = re.compile(r"(?<!\S)([A-Za-z0-9А-Яа-я_\-]+)\(\)")

    def convert_line_inline(line_str: str) -> str:
        # 1. Трансклюзии внешние: Файл.Блок() -> ![[Файл#Блок]]
        line_str = re_ext_trans.sub(r"![[\1#\2]]", line_str)
        # 2. Трансклюзии локальные: Блок() -> ![[#Блок]]
        line_str = re_loc_trans.sub(r"![[#\1]]", line_str)
        # 3. Акторы: @[Имя] -> **@Имя**
        line_str = re_actor.sub(r"**@\1**", line_str)
        return line_str

    while i < n:
        raw_line = lines[i]

        # Однострочный блок: Имя { текст }
        m_single = re_block_single.match(raw_line)
        if m_single:
            indent, name, body = m_single.group(1), m_single.group(2).strip(), m_single.group(3)
            out_lines.append(f"{indent}### {name}\n")
            if body:
                out_lines.append(f"{indent}{convert_line_inline(body)}")
            i += 1
            continue

        # Свернутый блок: Имя ....
        m_collapsed = re_block_collapsed.match(raw_line)
        if m_collapsed:
            indent, name = m_collapsed.group(1), m_collapsed.group(2).strip()
            out_lines.append(f"{indent}### {name}")
            i += 1
            continue

        # Начало многострочного блока: Имя {
        m_start = re_block_start.match(raw_line)
        if m_start:
            indent, name = m_start.group(1), m_start.group(2).strip()
            out_lines.append(f"{indent}### {name}")
            i += 1
            continue

        # Закрытие блока: отдельная фигурная скобка }
        if raw_line.strip() == "}":
            # Закрывающую скобку просто пропускаем или оставляем пустую строку
            i += 1
            continue

        # Обычная строка текста
        out_lines.append(convert_line_inline(raw_line))
        i += 1

    return "\n".join(out_lines)


class MarkdownExporter:
    """Сервис для экспорта диалекта в стандартные .md файлы."""

    @staticmethod
    def to_path(file_url: str) -> Path:
        if file_url.startswith("file:///"):
            parsed = urlparse(file_url)
            p = unquote(parsed.path)
            if p.startswith("/") and len(p) > 2 and p[2] == ":":
                p = p[1:]
            return Path(p)
        return Path(file_url)

    @classmethod
    def export_file(cls, file_url: str, output_dir: str = "") -> dict:
        """Экспортирует одну заметку в .md."""
        try:
            src_path = cls.to_path(file_url)
            if not src_path.exists() or not src_path.is_file():
                return {"success": False, "error": "Файл не найден"}

            raw_text = src_path.read_text(encoding="utf-8")
            md_text = dialect_to_markdown(raw_text)

            if output_dir:
                out_dir = cls.to_path(output_dir)
            else:
                out_dir = src_path.parent / "exports"

            out_dir.mkdir(parents=True, exist_ok=True)
            out_file = out_dir / (src_path.stem + ".md")
            out_file.write_text(md_text, encoding="utf-8")

            return {
                "success": True,
                "filePath": str(out_file),
                "fileName": out_file.name,
                "message": f"Экспортировано: {out_file.name}"
            }
        except Exception as e:
            return {"success": False, "error": str(e)}

    @classmethod
    def export_folder(cls, folder_url: str, output_dir: str = "") -> dict:
        """Экспортирует всю папку заметок в .md."""
        try:
            src_dir = cls.to_path(folder_url)
            if not src_dir.exists() or not src_dir.is_dir():
                return {"success": False, "error": "Папка не найдена"}

            if output_dir:
                out_dir = cls.to_path(output_dir)
            else:
                out_dir = src_dir / "exports"

            out_dir.mkdir(parents=True, exist_ok=True)
            count = 0
            for f in src_dir.glob("*.txt"):
                if f.name.startswith("."):
                    continue
                raw_text = f.read_text(encoding="utf-8")
                md_text = dialect_to_markdown(raw_text)
                (out_dir / (f.stem + ".md")).write_text(md_text, encoding="utf-8")
                count += 1

            return {
                "success": True,
                "count": count,
                "outputDir": str(out_dir),
                "message": f"Экспортировано {count} заметок в {out_dir.name}/"
            }
        except Exception as e:
            return {"success": False, "error": str(e)}
