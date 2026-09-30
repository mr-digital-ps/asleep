# services/content/outline_service.py — Фасад для управления структурой заметок и документа
from pathlib import Path
from typing import Any

from services.content.document_outline import DocumentOutlineManager


class OutlineService(DocumentOutlineManager):
    """
    Единый сервис управления структурой заметок и документов (DocumentOutlineManager).
    Обеспечивает унифицированный разбор и манипуляцию иерархией всех Markdown-файлов.
    """

    def _get_subtree_indices(self, blocks: list[dict[str, Any]], start_index: int) -> list[int]:
        """Псевдоним приватного метода для обратной совместимости."""
        return self.get_subtree_indices(blocks, start_index)

    def parse_project_tree_flat(self, text: str) -> dict[str, Any]:
        """Обертка для обратной совместимости: парсит через единый DocumentOutlineManager."""
        items = self.parse_document(text)
        return {"header": "", "items": items, "graph_section": ""}

    def reorder_project_tree(self, text: str, source_idx: int, target_idx: int, position: str = "before") -> str:
        """Обертка для обратной совместимости: переставляет блоки через DocumentOutlineManager."""
        return self.reorder_blocks(text, source_idx, target_idx, position)

    def change_project_tree_level(self, text: str, item_index: int, delta: int) -> str:
        """Обертка для обратной совместимости: меняет уровень блока через DocumentOutlineManager."""
        return self.change_block_level(text, item_index, delta)

    def add_project_tree_item(self, text: str, label: str, item_type: str = "file", target_idx: int = -1) -> str:
        """Обертка для обратной совместимости: добавляет элемент в документ."""
        clean_lbl = label.strip()
        if item_type in ("folder", "section"):
            addition = f"\n\n## {clean_lbl}\n"
        else:
            addition = f"\n- [[{clean_lbl}]]\n"
        return text.rstrip() + addition
