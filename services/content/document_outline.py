# services/content/document_outline.py — Парсинг и манипуляция пользовательским диалектом (блоки, трансклюзия, аутлайнер)
import re
from pathlib import Path
from typing import Any, TypedDict


class BlockItem(TypedDict):
    name: str
    name_norm: str
    content: str
    start_line: int
    end_line: int
    start_char: int
    end_char: int


class ExternalCallItem(TypedDict):
    target_file: str
    target_block: str
    line: int
    raw: str


class LocalCallItem(TypedDict):
    target_block: str
    line: int
    raw: str


class DialectParseResult(TypedDict):
    blocks: list[BlockItem]
    local_calls: list[LocalCallItem]
    external_calls: list[ExternalCallItem]
    wikilinks: list[str]
    free_text: str
    errors: list[str]


# Регулярные выражения пользовательского диалекта
RE_CODE_FENCE = re.compile(r'^[ \t]*```')
RE_BLOCK_START = re.compile(r'^([^{}\n\r]+?)\s*\{[ \t]*$')
RE_BLOCK_END = re.compile(r'^[ \t]*\}[ \t]*$')

# Вызовы блоков: Файл.Блок() и Блок()
RE_EXTERNAL_CALL = re.compile(r'([^.(){}\n\r]+)\.([^.(){}\n\r]+)\(\)')
RE_LOCAL_CALL = re.compile(r'([^.(){}\n\r]+)\(\)')

# Вики-ссылки [[Имя]]
RE_WIKILINK = re.compile(r'\[\[([^\]|\n\r]+)(?:\|[^\]\n\r]+)?\]\]')

# Для структуры проекта
LIST_ITEM_REGEX = re.compile(r'^([ \t]*)([-*+]|\d+[.)])\s+(.+)$')
PURE_WIKILINK_REGEX = re.compile(r'^\s*(?:[-*+]\s+)?\[\[([^\]|]+)(?:\|[^\]]+)?\]\]\s*$', re.MULTILINE)


def parse_user_dialect(text: str) -> DialectParseResult:
    """
    Разбирает текст в соответствии с пользовательским диалектом:
    - Плоские именованные блоки `Имя Блока { ... }`
    - Проверка уникальности имен внутри файла
    - Вызовы `Блок()` и `Файл.Блок()`
    - Вики-ссылки `[[Имя Файла]]`
    - Полное экранирование синтаксиса внутри блоков кода ```
    """
    if not text:
        return {
            "blocks": [],
            "local_calls": [],
            "external_calls": [],
            "wikilinks": [],
            "free_text": "",
            "errors": []
        }

    lines = text.splitlines(keepends=True)

    in_code_block = False
    in_user_block = False
    current_block_name = ""
    current_block_start_line = 0
    current_block_start_char = 0
    current_block_lines: list[str] = []

    blocks: list[BlockItem] = []
    seen_block_names: set[str] = set()
    errors: list[str] = []

    local_calls: list[LocalCallItem] = []
    external_calls: list[ExternalCallItem] = []
    wikilinks: list[str] = []
    free_text_lines: list[str] = []

    current_char_offset = 0

    for line_idx, line_raw in enumerate(lines, start=1):
        line_len = len(line_raw)
        stripped = line_raw.strip()

        # 1. Проверка блоков кода ```
        if RE_CODE_FENCE.match(line_raw):
            in_code_block = not in_code_block
            if in_user_block:
                current_block_lines.append(line_raw)
            else:
                free_text_lines.append(line_raw)
            current_char_offset += line_len
            continue

        if in_code_block:
            if in_user_block:
                current_block_lines.append(line_raw)
            else:
                free_text_lines.append(line_raw)
            current_char_offset += line_len
            continue

        # 2. Обработка закрытия блока
        if in_user_block:
            if RE_BLOCK_END.match(line_raw):
                content = "".join(current_block_lines)
                end_char = current_char_offset + line_len
                blocks.append({
                    "name": current_block_name,
                    "name_norm": current_block_name.lower(),
                    "content": content,
                    "start_line": current_block_start_line,
                    "end_line": line_idx,
                    "start_char": current_block_start_char,
                    "end_char": end_char
                })
                in_user_block = False
                current_block_name = ""
                current_block_lines = []
                current_char_offset += line_len
                continue

            nested_match = RE_BLOCK_START.match(stripped)
            if nested_match and "{" in line_raw:
                errors.append(f"Line {line_idx}: Nested blocks are forbidden ('{nested_match.group(1).strip()}')")

            _extract_links_and_calls(line_raw, line_idx, local_calls, external_calls, wikilinks)
            current_block_lines.append(line_raw)
            current_char_offset += line_len
            continue

        # 3. Вне блока: проверка на открытие нового блока
        block_match = RE_BLOCK_START.match(stripped)
        if block_match:
            raw_name = block_match.group(1).strip()
            if "." in raw_name:
                errors.append(f"Line {line_idx}: Block name cannot contain '.' ('{raw_name}')")
            elif not raw_name:
                errors.append(f"Line {line_idx}: Empty block name")
            else:
                name_norm = raw_name.lower()
                if name_norm in seen_block_names:
                    errors.append(f"Line {line_idx}: Duplicate block name '{raw_name}'")
                else:
                    seen_block_names.add(name_norm)

                in_user_block = True
                current_block_name = raw_name
                current_block_start_line = line_idx
                current_block_start_char = current_char_offset
                current_block_lines = []
                current_char_offset += line_len
                continue

        # 4. Свободный текст
        free_text_lines.append(line_raw)
        _extract_links_and_calls(line_raw, line_idx, local_calls, external_calls, wikilinks)
        current_char_offset += line_len

    if in_user_block:
        errors.append(f"Unclosed block '{current_block_name}' starting at line {current_block_start_line}")
        content = "".join(current_block_lines)
        blocks.append({
            "name": current_block_name,
            "name_norm": current_block_name.lower(),
            "content": content,
            "start_line": current_block_start_line,
            "end_line": len(lines),
            "start_char": current_block_start_char,
            "end_char": current_char_offset
        })

    return {
        "blocks": blocks,
        "local_calls": local_calls,
        "external_calls": external_calls,
        "wikilinks": list(dict.fromkeys(wikilinks)),
        "free_text": "".join(free_text_lines),
        "errors": errors
    }


def _extract_links_and_calls(
    line: str,
    line_num: int,
    local_calls: list[LocalCallItem],
    external_calls: list[ExternalCallItem],
    wikilinks: list[str]
):
    for m in RE_WIKILINK.finditer(line):
        target = m.group(1).strip()
        if target:
            wikilinks.append(target)

    clean_line = RE_WIKILINK.sub(" ", line)
    clean_line = re.sub(r'`[^`]+`', ' ', clean_line)

    for m in RE_EXTERNAL_CALL.finditer(clean_line):
        f_name = m.group(1).strip()
        b_name = m.group(2).strip()
        if f_name and b_name:
            external_calls.append({
                "target_file": f_name,
                "target_block": b_name,
                "line": line_num,
                "raw": m.group(0)
            })

    clean_for_local = RE_EXTERNAL_CALL.sub(" ", clean_line)
    for m in RE_LOCAL_CALL.finditer(clean_for_local):
        b_name = m.group(1).strip()
        if b_name:
            local_calls.append({
                "target_block": b_name,
                "line": line_num,
                "raw": m.group(0)
            })


class DocumentOutlineManager:
    """
    Отвечает за разбор именованных блоков `Имя { ... }` в заметке,
    манипуляцию блоками в аутлайнере и синхронизацию структуры.
    """

    LIST_ITEM_REGEX = LIST_ITEM_REGEX
    PURE_WIKILINK_REGEX = PURE_WIKILINK_REGEX

    def parse_document(
        self,
        text: str,
        heading_regex: re.Pattern | None = None,
        parse_list_items: bool | None = None
    ) -> list[dict[str, Any]]:
        """
        Разбор документа на плоские блоки:
        1. Для файлов структуры проекта (_notes.txt) поддерживаются списки файлов - [[...]].
        2. Для обычных заметок парсинг выполняется через единый `parse_user_dialect`:
           - Именованные блоки `Имя { ... }` формируют карточки оглавления.
           - Если блоков нет, свободный текст делится на карточки параграфов.
        """
        if not text:
            return []

        # Проверка на режим структуры проекта (список файлов)
        is_structure_tree = bool(parse_list_items) or (
            parse_list_items is None and bool(self.PURE_WIKILINK_REGEX.search(text))
        )

        if is_structure_tree:
            return self._parse_structure_tree(text)

        parsed = parse_user_dialect(text)
        blocks: list[dict[str, Any]] = []

        # 1. Если есть именованные блоки:
        if parsed["blocks"]:
            # Проверяем свободный текст до первого блока
            first_blk = parsed["blocks"][0]
            if first_blk["start_char"] > 0:
                prelude = text[:first_blk["start_char"]].strip()
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
                        "end_char": first_blk["start_char"],
                    })

            for b in parsed["blocks"]:
                idx = len(blocks)
                clean_content = b["content"].strip("\r\n")
                blocks.append({
                    "id": f"blk_{idx}",
                    "key": f"block_{idx}",
                    "index": idx,
                    "level": 0,
                    "indent": 0,
                    "heading": b["name"],
                    "label": b["name"],
                    "type": "block",
                    "marker": "",
                    "isOrdered": False,
                    "content": clean_content,
                    "collapsed": False,
                    "has_children": False,
                    "start_char": b["start_char"],
                    "end_char": b["end_char"],
                })
        else:
            # Если явных блоков еще нет: делим текст на абзацы без старых решеток #
            raw_blocks = re.split(r'\n{2,}', text.strip())
            for idx, raw in enumerate(raw_blocks):
                raw = raw.strip()
                if not raw:
                    continue
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
        """Разбор дерева проекта для файлов _notes.txt."""
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

    def blocks_to_text(self, blocks: list[dict[str, Any]]) -> str:
        """
        Сериализует список блоков в текст заметки по каноническому синтаксису 14 единиц:
        - Именованные блоки форматируются как `Имя {\nСодержимое\n}`
        - Ликвидированы любые символы '#'
        """
        if not blocks:
            return ""

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

        block_strings = []
        for blk in blocks:
            content = blk.get("content", "").strip()
            heading = blk.get("heading", "").strip()
            # Очищаем заголовки решетками, если встретились
            content = re.sub(r'^#{1,6}\s*', '', content, flags=re.MULTILINE).strip()
            
            # Если это прелюдия / свободный текст без имени
            if blk.get("key") == "prelude_0" or not heading:
                if content:
                    block_strings.append(content)
            else:
                if content:
                    block_strings.append(f"{heading} {{\n    {content}\n}}")
                else:
                    block_strings.append(f"{heading} {{\n}}")

        return "\n\n".join(block_strings).rstrip() + "\n"

    def update_block_heading(self, text: str, block_index: int, new_heading: str, parse_list_items: bool | None = None) -> str:
        blocks = self.parse_document(text, parse_list_items=parse_list_items)
        if not blocks or block_index < 0 or block_index >= len(blocks):
            return text
        val = new_heading.strip()
        blocks[block_index]["heading"] = val
        blocks[block_index]["label"] = val
        return self.blocks_to_text(blocks)

    def update_block_content(self, text: str, block_index: int, new_content: str, parse_list_items: bool | None = None) -> str:
        blocks = self.parse_document(text, parse_list_items=parse_list_items)
        if not blocks or block_index < 0 or block_index >= len(blocks):
            return text
        val = new_content.strip()
        blocks[block_index]["content"] = val
        return self.blocks_to_text(blocks)

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

        return self.blocks_to_text(result_blocks)

    def change_block_level(self, text: str, block_index: int, delta: int, parse_list_items: bool | None = None) -> str:
        return text

    def generate_project_structure_tree(
        self,
        folder_path: Path,
        files: list[str] | None = None,
        structure_filename: str = "_notes.txt",
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
                    and f.suffix.lower() == ".txt"
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
        structure_filename: str = "_notes.txt",
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




# Псевдоним класса для единой архитектуры без лишних файлов-обёрток
OutlineService = DocumentOutlineManager
