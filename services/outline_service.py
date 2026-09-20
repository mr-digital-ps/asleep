# services/outline_service.py — Фасад для управления структурой заметок и документа
from pathlib import Path
from typing import Any

from services.document_outline import DocumentOutlineManager
from services.project_tree import ProjectTreeManager


class OutlineService(DocumentOutlineManager, ProjectTreeManager):
    """
    Фасад, объединяющий управление локальной структурой документа (DocumentOutlineManager)
    и глобальной структурой проекта (ProjectTreeManager).
    Обеспечивает полную обратную совместимость для всех существующих вызовов и тестов.
    """

    def _get_subtree_indices(self, blocks: list[dict[str, Any]], start_index: int) -> list[int]:
        """Псевдоним приватного метода для обратной совместимости."""
        return self.get_subtree_indices(blocks, start_index)

    def _get_project_tree_subtree(self, items: list[dict[str, Any]], start_index: int) -> list[int]:
        """Псевдоним приватного метода для обратной совместимости."""
        return self.get_project_tree_subtree(items, start_index)
