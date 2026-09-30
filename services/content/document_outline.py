# services/document_outline.py — Парсинг и манипуляция блоками { ... }
import re
from pathlib import Path
from typing import Any


class DocumentOutlineManager:
    """
    Отвечает за разбор плоских блоков в фигурных скобках { ... } в заметке,
    манипуляцию блоками и их Drag-and-Drop перестановку.
    Заголовки H1-H6 и YAML-шапки полностью устранены.
    """

    CURLY_BLOCK_REGEX = re.compile(r'\{([^{}]*)\}', re.DOTALL)
    LIST_ITEM_REGEX = re.compile(r'^([ \t]*)([-*+]|\d+[.)])\s+(.+)$')
    PURE_WIKILINK_REGEX = re.compile(r'^\s*(?:[-*+]\s+)?\[\[([^\]|]+)(?:\|[^\]]+)?\]\]\s*$', re.MULTILINE)
    WIKILINK_FINDER = re.compile(r'\[\[(.*?)\]\]')

    def parse_document(
        self,
        text: str,
        heading_regex: re.Pattern | None = None,
        parse_list_items: bool | None = None
    ) -> list[dict[str, Any]]:
        """
        Разбор документа на плоские блоки:
        1. Если в документе есть блоки { ... }, они парсятся как основные блоки карточек.
        2. Для файлов структуры проекта (_Структура.md / _notes.md) поддерживаются списки файлов - [[...]].
        3. Если в обычном тексте еще нет { ... }, абзацы разделяются на блоки.
        """
        if not text:
            return []

        # Проверка на режим структуры проекта (список файлов)
        is_structure_tree = bool(parse_list_items) or (
            parse_list_items is None and bool(self.PURE_WIKILINK_REGEX.search(text))
        )

        if is_structure_tree:
            return self._parse_structure_tree(text)

        blocks: list[dict[str, Any]] = []
        matches = list(self.CURLY_BLOCK_REGEX.finditer(text))

        if matches:
            # Текст до первого блока (если есть)
            first_start = matches[0].start()
            if first_start > 0:
                prelude = text[:first_start].strip()
                if prelude:
                    lines = [l for l in prelude.splitlines() if l.strip()]
                    lbl = lines[0].strip() if lines else "Введение"
                    blocks.append({
                        "id": "blk_0",
                        "key": "prelude_0",
                        "index": 0,
                        "level": 0,
                        "indent": 0,
                        "heading": lbl,
                        "label": lbl,
                        "type": "block",
                        "marker": "",
                        "isOrdered": False,
                        "content": prelude,
                        "collapsed": False,
                        "has_children": False,
                        "start_char": 0,
                        "end_char": first_start,
                    })

            for m in matches:
                idx = len(blocks)
                raw_inner = m.group(1).strip()
                lines = [l for l in raw_inner.splitlines() if l.strip()]
                lbl = lines[0].strip() if lines else f"Блок {idx + 1}"
                # Первую строку берем как заголовок/лейбл карточки
                heading = lbl
                # Тело блока: если больше одной строки, остальное идет в content
                content = raw_inner

                blocks.append({
                    "id": f"blk_{idx}",
                    "key": f"block_{idx}",
                    "index": idx,
                    "level": 0,
                    "indent": 0,
                    "heading": heading,
                    "label": lbl,
                    "type": "block",
                    "marker": "",
                    "isOrdered": False,
                    "content": content,
                    "collapsed": False,
                    "has_children": False,
                    "start_char": m.start(),
                    "end_char": m.end(),
                })
        else:
            # Если фигурных скобок еще нет в тексте: разделяем текст по непустым параграфам
            raw_blocks = re.split(r'\n{2,}', text.strip())
            for idx, raw in enumerate(raw_blocks):
                raw = raw.strip()
                if not raw:
                    continue
                # Удаляем старые решетки #, если они были в тексте
                cleaned = re.sub(r'^#{1,6}\s*', '', raw, flags=re.MULTILINE).strip()
                lines = [l for l in cleaned.splitlines() if l.strip()]
                lbl = lines[0].strip() if lines else f"Блок {idx + 1}"
                blocks.append({
                    "id": f"blk_{idx}",
                    "key": f"block_{idx}",
                    "index": idx,
                    "level": 0,
                    "indent": 0,
                    "heading": lbl,
                    "label": lbl,
                    "type": "block",
                    "marker": "",
                    "isOrdered": False,
                    "content": cleaned,
                    "collapsed": False,
                    "has_children": False,
                })

        return blocks

    def _parse_structure_tree(self, text: str) -> list[dict[str, Any]]:
        """Разбор дерева проекта для файлов _notes.md / _Структура.md."""
        lines = text.splitlines()
        blocks = []
        heading_rx = re.compile(r'^(#{1,6})\s+(.+)$')
        current_header_level = 0
        for idx, line in enumerate(lines):
            stripped = line.strip()
            if not stripped:
                continue
            h_match = heading_rx.match(stripped)
            if h_match:
                hashes, title = h_match.groups()
                lvl = len(hashes)
                current_header_level = lvl
                blocks.append({
                    "id": f"tree_{idx}",
                    "key": f"tree_{idx}",
                    "index": len(blocks),
                    "level": lvl,
                    "indent": lvl,
                    "heading": title.strip(),
                    "label": title.strip(),
                    "type": "folder" if lvl > 1 else "heading",
                    "marker": hashes,
                    "isOrdered": False,
                    "content": "",
                    "collapsed": False,
                    "has_children": False,
                })
                continue

            l_match = self.LIST_ITEM_REGEX.match(line)
            if l_match:
                raw_indent, marker, rest = l_match.groups()
                rest = rest.strip()
                indent_cnt = raw_indent.count("\t") if "\t" in raw_indent else len(raw_indent) // 2
                pure_wiki = self.PURE_WIKILINK_REGEX.match(rest)
                if pure_wiki:
                    lbl = pure_wiki.group(1).strip()
                    btype = "file"
                else:
                    lbl = rest
                    btype = "folder"
                effective_level = (current_header_level + 1 + indent_cnt) if current_header_level > 0 else (indent_cnt + 2)
                blocks.append({
                    "id": f"tree_{idx}",
                    "key": f"tree_{idx}",
                    "index": len(blocks),
                    "level": effective_level,
                    "indent": indent_cnt,
                    "heading": lbl,
                    "label": lbl,
                    "type": btype,
                    "marker": marker,
                    "isOrdered": False,
                    "content": "",
                    "collapsed": False,
                    "has_children": False,
                })
        return blocks

    def get_subtree_indices(self, blocks: list[dict[str, Any]], start_index: int) -> list[int]:
        """Для плоских заметок поддеревьев нет; для структуры проекта переносятся все вложенные элементы."""
        if start_index < 0 or start_index >= len(blocks):
            return []
        if any(b.get("type") in ("file", "folder", "heading") for b in blocks):
            indices = [start_index]
            base_level = blocks[start_index].get("level", 0)
            for i in range(start_index + 1, len(blocks)):
                if blocks[i].get("level", 0) > base_level:
                    indices.append(i)
                else:
                    break
            return indices
        return [start_index]

    def blocks_to_markdown(self, blocks: list[dict[str, Any]]) -> str:
        """
        Сериализует список блоков в Markdown:
        - Обычные блоки оборачиваются в { ... } с ровным разделением в 1 пустую строку.
        - Списочные элементы структуры сохраняются как списки.
        - Никаких символов # и YAML ---!
        """
        if not blocks:
            return ""

        # Если это структура проекта
        if any(b.get("type") in ("file", "folder") for b in blocks):
            lines = []
            for blk in blocks:
                btype = blk.get("type")
                indent = "\t" * blk.get("indent", 0)
                heading = blk.get("heading", "")
                if btype == "file":
                    lines.append(f"{indent}- [[{heading}]]")
                elif btype == "heading":
                    lvl = blk.get("level", 1)
                    lines.append(f"{'#' * lvl} {heading}")
                elif btype == "folder" and blk.get("marker", "").startswith("#"):
                    lvl = blk.get("level", 2)
                    lines.append(f"{'#' * lvl} {heading}")
                else:
                    lines.append(f"{indent}- {heading}")
            return "\n".join(lines).rstrip() + "\n"

        # Обычные блоки заметок
        block_strings = []
        for blk in blocks:
            content = blk.get("content", "").strip()
            heading = blk.get("heading", "").strip()
            # Устраняем остатки решеток # и YAML
            content = re.sub(r'^#{1,6}\s*', '', content, flags=re.MULTILINE).strip()
            if not content and heading:
                content = heading
            if content:
                block_strings.append(f"{{\n{content}\n}}")

        return "\n\n".join(block_strings).rstrip() + "\n"

    def update_block_heading(self, text: str, block_index: int, new_heading: str, parse_list_items: bool | None = None) -> str:
        blocks = self.parse_document(text, parse_list_items=parse_list_items)
        if not blocks or block_index < 0 or block_index >= len(blocks):
            return text
        val = new_heading.strip()
        blocks[block_index]["heading"] = val
        blocks[block_index]["label"] = val
        # Обновляем первую строку контента
        content = blocks[block_index].get("content", "")
        lines = content.splitlines()
        if lines:
            lines[0] = val
            blocks[block_index]["content"] = "\n".join(lines)
        else:
            blocks[block_index]["content"] = val
        return self.blocks_to_markdown(blocks)

    def update_block_content(self, text: str, block_index: int, new_content: str, parse_list_items: bool | None = None) -> str:
        blocks = self.parse_document(text, parse_list_items=parse_list_items)
        if not blocks or block_index < 0 or block_index >= len(blocks):
            return text
        val = new_content.strip()
        blocks[block_index]["content"] = val
        lines = [l for l in val.splitlines() if l.strip()]
        if lines:
            blocks[block_index]["heading"] = lines[0].strip()
            blocks[block_index]["label"] = lines[0].strip()
        return self.blocks_to_markdown(blocks)

    def reorder_blocks(self, text: str, source_index: int, target_index: int, position: str = "before", parse_list_items: bool | None = None) -> str:
        blocks = self.parse_document(text, parse_list_items=parse_list_items)
        if not blocks or source_index < 0 or source_index >= len(blocks):
            return text
        if target_index < 0 or target_index >= len(blocks) or source_index == target_index:
            return text

        moving_indices = set(self.get_subtree_indices(blocks, source_index))
        if target_index in moving_indices:
            return text

        moving_blocks = [blocks[i] for i in sorted(moving_indices)]
        remaining_blocks = [blocks[i] for i in range(len(blocks)) if i not in moving_indices]

        target_block_id = blocks[target_index]["id"]
        new_target_index = -1
        for idx, blk in enumerate(remaining_blocks):
            if blk["id"] == target_block_id:
                new_target_index = idx
                break

        if new_target_index == -1:
            return text

        insert_idx = new_target_index if position == "before" else new_target_index + 1
        result_blocks = remaining_blocks[:insert_idx] + moving_blocks + remaining_blocks[insert_idx:]

        for idx, blk in enumerate(result_blocks):
            blk["index"] = idx

        return self.blocks_to_markdown(result_blocks)

    def change_block_level(self, text: str, block_index: int, delta: int, parse_list_items: bool | None = None) -> str:
        # В плоской блочной модели уровней нет
        return text

    def generate_project_structure_tree(
        self,
        folder_path: Path,
        files: list[str] | None = None,
        structure_filename: str = "_notes.md",
        ignore_prefixes: tuple[str, ...] | list[str] = (".", "_")
    ) -> str:
        pfx = tuple(ignore_prefixes) if isinstance(ignore_prefixes, (list, tuple)) else (".", "_")
        lines = []
        struct_name_lower = structure_filename.lower()

        def _scan_dir(dir_path: Path, depth: int):
            indent = "\t" * depth
            try:
                entries = list(dir_path.iterdir())
            except Exception:
                return

            subdirs = sorted(
                [d for d in entries if d.is_dir() and not d.name.startswith(pfx)],
                key=lambda x: x.name.lower()
            )
            dir_files = sorted(
                [
                    f for f in entries
                    if f.is_file()
                    and not f.name.startswith(pfx)
                    and f.name.lower() != struct_name_lower
                    and f.suffix.lower() in (".md", ".markdown", ".txt")
                ],
                key=lambda x: x.name.lower()
            )

            for d in subdirs:
                lines.append(f"{indent}- {d.name}")
                _scan_dir(d, depth + 1)

            for f in dir_files:
                lines.append(f"{indent}- [[{f.stem}]]")

        _scan_dir(folder_path, 0)
        return "\n".join(lines).rstrip() + "\n"

    def sync_project_structure_file(
        self,
        folder_path: Path,
        files: list[str] | None = None,
        structure_filename: str = "_notes.md",
        ignore_prefixes: tuple[str, ...] | list[str] = (".", "_")
    ) -> Path:
        fpath = folder_path / structure_filename
        pfx = tuple(ignore_prefixes) if isinstance(ignore_prefixes, (list, tuple)) else (".", "_")
        if not fpath.exists():
            content = self.generate_project_structure_tree(
                folder_path, files, structure_filename=structure_filename, ignore_prefixes=pfx
            )
            if files and not content.strip():
                lines = []
                for f in sorted(files):
                    if not f.startswith(pfx):
                        stem = Path(f).stem
                        lines.append(f"- [[{stem}]]")
                content = "\n".join(lines) + "\n"
            fpath.write_text(content, encoding="utf-8")
        else:
            try:
                existing_text = fpath.read_text(encoding="utf-8")
                if files:
                    missing = []
                    for f in files:
                        if f.startswith(pfx):
                            continue
                        stem = Path(f).stem
                        if f"[[{stem}]]" not in existing_text and stem not in existing_text:
                            missing.append(stem)
                    if missing:
                        append_parts = ["\n"]
                        for m in missing:
                            append_parts.append(f"- [[{m}]]\n")
                        fpath.write_text(existing_text.rstrip() + "".join(append_parts), encoding="utf-8")
            except Exception:
                pass
        return fpath
