# services/document_outline.py — Парсинг и манипуляция заголовками отдельного Markdown-документа
import re
from typing import Any

class DocumentOutlineManager:
    """
    Отвечает за разбор иерархии заголовков (# .. ######) в отдельной заметке,
    манипуляцию блоками и их Drag-and-Drop перестановку.
    """

    HEADING_REGEX = re.compile(r'^(#{1,6})\s+(.+)$', re.MULTILINE)

    def parse_document(self, text: str, heading_regex: re.Pattern | None = None) -> list[dict[str, Any]]:
        """
        Разбирает markdown-текст на плоский упорядоченный список блоков с уровнями вложенности.
        Каждый блок содержит заголовок, уровень (1..6, либо 0 для начального текста),
        текстовое содержимое, стабильный ключ и флаги дочерних элементов.
        """
        if not text:
            return []

        rx = heading_regex or self.HEADING_REGEX
        lines = text.splitlines(keepends=True)
        blocks: list[dict[str, Any]] = []

        current_id = 0
        current_level = 0
        current_heading = ""
        current_lines: list[str] = []

        for line in lines:
            stripped = line.strip()
            heading_match = rx.match(stripped)

            if heading_match:
                if current_heading or current_lines:
                    lbl = current_heading if current_heading else "Введение"
                    blocks.append({
                        "id": f"blk_{current_id}",
                        "key": f"heading:{current_level}:{lbl}" if current_heading else f"prelude_{current_id}",
                        "index": current_id,
                        "level": current_level,
                        "heading": current_heading,
                        "label": lbl,
                        "type": "heading" if current_level > 0 else "prelude",
                        "content": "".join(current_lines).strip(),
                        "collapsed": False,
                    })
                    current_id += 1

                hashes, title = heading_match.groups()
                current_level = len(hashes)
                current_heading = title.strip()
                current_lines = []
            else:
                current_lines.append(line)

        if current_heading or current_lines:
            lbl = current_heading if current_heading else "Введение"
            blocks.append({
                "id": f"blk_{current_id}",
                "key": f"heading:{current_level}:{lbl}" if current_heading else f"prelude_{current_id}",
                "index": current_id,
                "level": current_level,
                "heading": current_heading,
                "label": lbl,
                "type": "heading" if current_level > 0 else "prelude",
                "content": "".join(current_lines).strip(),
                "collapsed": False,
            })

        # Вычисляем наличие дочерних элементов
        for i in range(len(blocks)):
            b_level = blocks[i].get("level", 0)
            blocks[i]["hasChildren"] = (i + 1 < len(blocks) and blocks[i + 1].get("level", 0) > b_level)

        return blocks

    def get_subtree_indices(self, blocks: list[dict[str, Any]], start_index: int) -> list[int]:
        """
        Возвращает индексы блока и всех его дочерних подблоков (более глубокого уровня).
        """
        if start_index < 0 or start_index >= len(blocks):
            return []

        indices = [start_index]
        base_level = blocks[start_index]["level"]
        if base_level == 0:
            return indices

        for i in range(start_index + 1, len(blocks)):
            if blocks[i]["level"] > base_level:
                indices.append(i)
            else:
                break
        return indices

    def blocks_to_markdown(self, blocks: list[dict[str, Any]]) -> str:
        """
        Собирает список блоков обратно в цельный markdown-текст.
        """
        chunks = []
        for blk in blocks:
            level = blk.get("level", 0)
            heading = blk.get("heading", "").strip()
            content = blk.get("content", "").strip()

            chunk_parts = []
            if heading:
                prefix = "#" * max(1, min(6, level))
                chunk_parts.append(f"{prefix} {heading}")
            if content:
                chunk_parts.append(content)

            if chunk_parts:
                chunks.append("\n\n".join(chunk_parts))

        return "\n\n".join(chunks) + ("\n" if chunks else "")

    def reorder_blocks(self, text: str, source_index: int, target_index: int, position: str = "before") -> str:
        """
        Перемещает блок source_index (вместе со всеми его подразделами!)
        до или после target_index.
        """
        blocks = self.parse_document(text)
        if not blocks:
            return text

        if source_index < 0 or source_index >= len(blocks):
            return text
        if target_index < 0 or target_index >= len(blocks):
            return text
        if source_index == target_index:
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

    def change_block_level(self, text: str, block_index: int, delta: int) -> str:
        """
        Изменяет уровень заголовка блока (и пропорционально всех его дочерних подблоков).
        """
        blocks = self.parse_document(text)
        if not blocks or block_index < 0 or block_index >= len(blocks):
            return text

        subtree_indices = self.get_subtree_indices(blocks, block_index)
        cur_level = blocks[block_index]["level"]
        new_level = max(1, min(6, cur_level + delta))
        actual_delta = new_level - cur_level

        if actual_delta == 0:
            return text

        for idx in subtree_indices:
            if blocks[idx]["heading"]:
                blocks[idx]["level"] = max(1, min(6, blocks[idx]["level"] + actual_delta))

        return self.blocks_to_markdown(blocks)
