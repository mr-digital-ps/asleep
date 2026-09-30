# services/core/document_session.py — Single Source of Truth и стек Undo/Redo
import re
from typing import Any


class DocumentSession:
    """
    Единый источник правды (Single Source of Truth) для открытого документа.
    Обеспечивает сквозной Undo/Redo и двустороннюю синхронизацию курсора
    между представлениями Source (текст) и Hierarchy (карточки { ... }).
    """

    def __init__(self, initial_text: str = ""):
        self._text: str = initial_text
        self._undo_stack: list[str] = [initial_text]
        self._redo_stack: list[str] = []
        self._max_history: int = 100
        self._active_block_index: int = 0
        self._cursor_offset: int = 0

    @property
    def text(self) -> str:
        return self._text

    def get_text(self) -> str:
        return self._text

    def set_text(self, new_text: str, record_undo: bool = True) -> bool:
        """Обновляет мастер-текст документа с записью в единый стек отмены."""
        if new_text == self._text:
            return False
        if record_undo:
            self._undo_stack.append(self._text)
            if len(self._undo_stack) > self._max_history:
                self._undo_stack.pop(0)
            self._redo_stack.clear()
        self._text = new_text
        return True

    def undo(self) -> str | None:
        """Откатывает последнее изменение документа (из любого представления)."""
        if len(self._undo_stack) <= 1:
            return None
        self._redo_stack.append(self._text)
        self._text = self._undo_stack.pop()
        return self._text

    def redo(self) -> str | None:
        """Повторяет отмененное изменение документа."""
        if not self._redo_stack:
            return None
        self._undo_stack.append(self._text)
        self._text = self._redo_stack.pop()
        return self._text

    @property
    def can_undo(self) -> bool:
        return len(self._undo_stack) > 1

    @property
    def can_redo(self) -> bool:
        return len(self._redo_stack) > 0

    # --- Двусторонняя проекция курсора ---

    def parse_blocks_offsets(self) -> list[dict[str, Any]]:
        """
        Возвращает список блоков с точными координатами символов (start, end)
        для проекции курсора.
        """
        blocks = []
        pattern = re.compile(r'\{([^{}]*)\}', re.DOTALL)
        for idx, match in enumerate(pattern.finditer(self._text)):
            content = match.group(1).strip()
            lines = [l for l in content.splitlines() if l.strip()]
            label = lines[0].strip() if lines else f"Блок {idx + 1}"
            blocks.append({
                "index": idx,
                "label": label,
                "start": match.start(),
                "end": match.end(),
                "content": content
            })
        return blocks

    def get_block_offset(self, block_index: int) -> int:
        """
        Возвращает символьное смещение начала блока в тексте (для перехода Hierarchy -> Source).
        """
        blocks = self.parse_blocks_offsets()
        if 0 <= block_index < len(blocks):
            return blocks[block_index]["start"]
        return 0

    def get_block_at_offset(self, char_offset: int) -> int:
        """
        Возвращает индекс блока, внутри которого находится курсор (для перехода Source -> Hierarchy).
        """
        blocks = self.parse_blocks_offsets()
        for blk in blocks:
            if blk["start"] <= char_offset <= blk["end"]:
                return blk["index"]
        if blocks:
            # Если курсор правее последнего блока, возвращаем последний
            if char_offset >= blocks[-1]["end"]:
                return len(blocks) - 1
            # Иначе ищем ближайший следующий
            for blk in blocks:
                if char_offset <= blk["start"]:
                    return blk["index"]
        return 0
