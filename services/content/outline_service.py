# services/content/outline_service.py — Прямой реэкспорт из единого document_outline.py
from services.content.document_outline import DocumentOutlineManager, OutlineService

__all__ = ["OutlineService", "DocumentOutlineManager"]

