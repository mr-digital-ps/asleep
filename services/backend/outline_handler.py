# services/backend/outline_handler.py — Обработчик аутлайна документов и структуры проекта
from PyQt6.QtCore import pyqtSlot, QUrl
from services.backend.app_initializer import safe_print


class OutlineHandlerMixin:
    """Миксин для парсинга и манипуляции структурой документа и иерархией проекта."""

    @pyqtSlot(str, result="QVariantList")
    def get_document_outline(self, text: str) -> list:
        """Разбирает markdown-текст на плоский список иерархических блоков"""
        try:
            h_regex = None
            if hasattr(self, "block_engine") and self.block_engine:
                h_regex = self.block_engine.get_heading_regex()
            return self.outline_service.parse_document(text, heading_regex=h_regex)
        except Exception as e:
            safe_print(f"[Backend] Ошибка парсинга аутлайна: {e}")
            return []

    @pyqtSlot(str, result=bool)
    def is_project_structure_file(self, filename: str) -> bool:
        """Проверяет, является ли файл файлом структуры проекта по конфигурации диалекта"""
        if not filename:
            return False
        try:
            md_cfg = self.config_service.get_markdown_config(self._current_folder) or {}
            struct_file = md_cfg.get("system_files", {}).get("structure_file", "_Структура.md")
            from pathlib import Path
            fn = Path(filename).name.lower()
            return fn == struct_file.lower() or "_структура" in fn or "структура" in fn
        except Exception:
            return "_структура" in filename.lower()

    @pyqtSlot(str, int, int, str, result=str)
    def reorder_document_outline(self, text: str, source_idx: int, target_idx: int, position: str = "before") -> str:
        """Перемещает блок и его подразделы до или после другого блока"""
        try:
            return self.outline_service.reorder_blocks(text, source_idx, target_idx, position)
        except Exception as e:
            safe_print(f"[Backend] Ошибка перестановки блоков: {e}")
            return text

    @pyqtSlot(str, int, int, result=str)
    def change_outline_level(self, text: str, block_idx: int, delta: int) -> str:
        """Изменяет уровень заголовка блока (например H2 -> H3)"""
        try:
            return self.outline_service.change_block_level(text, block_idx, delta)
        except Exception as e:
            safe_print(f"[Backend] Ошибка изменения уровня заголовка: {e}")
            return text

    @pyqtSlot(str, result="QVariantMap")
    @pyqtSlot(result="QVariantMap")
    def sync_project_structure_file(self, folder_url: str = "") -> dict:
        """Гарантирует создание и возвращает данные файла структуры проекта для открытия"""
        folder = self.file_service.to_path(folder_url) if folder_url else self._current_folder
        if not folder or not folder.exists() or not folder.is_dir():
            return {}
        try:
            md_cfg = self.config_service.get_markdown_config(folder) or {}
            sys_cfg = md_cfg.get("system_files", {})
            struct_file = sys_cfg.get("structure_file", "_Структура.md")
            ignore_pfx = tuple(sys_cfg.get("ignore_prefixes", [".", "_"]))
            files = [p.name for p in folder.iterdir() if p.is_file() and not p.name.startswith(ignore_pfx)]
            fpath = self.outline_service.sync_project_structure_file(folder, files, structure_filename=struct_file, ignore_prefixes=ignore_pfx)
            url = QUrl.fromLocalFile(str(fpath.resolve())).toString()
            return {
                "fileUrl": url,
                "fileName": fpath.name,
                "filePath": str(fpath)
            }
        except Exception as e:
            safe_print(f"[Backend] Ошибка sync_project_structure_file: {e}")
            return {}

    @pyqtSlot(str, result="QVariantList")
    @pyqtSlot(result="QVariantList")
    def get_project_structure_tree(self, folder_url: str = "") -> list:
        """Возвращает древовидную структуру проекта из файла структуры"""
        folder = self.file_service.to_path(folder_url) if folder_url else self._current_folder
        if not folder or not folder.exists() or not folder.is_dir():
            return []
        md_cfg = self.config_service.get_markdown_config(folder) or {}
        struct_file = md_cfg.get("system_files", {}).get("structure_file", "_Структура.md")
        fpath = folder / struct_file
        if not fpath.exists():
            return []
        try:
            text = fpath.read_text(encoding="utf-8")
            return self.outline_service.parse_project_tree(text)
        except Exception as e:
            safe_print(f"[Backend] Ошибка чтения дерева проекта: {e}")
            return []

    @pyqtSlot(str, result="QVariantMap")
    def get_project_tree_flat(self, text: str) -> dict:
        """Возвращает заголовок и плоский список элементов структуры проекта"""
        try:
            return self.outline_service.parse_project_tree_flat(text)
        except Exception as e:
            safe_print(f"[Backend] Ошибка get_project_tree_flat: {e}")
            return {"header": "", "items": []}

    @pyqtSlot(str, int, int, str, result=str)
    @pyqtSlot(str, int, int, result=str)
    def reorder_project_tree(self, text: str, source_idx: int, target_idx: int, position: str = "before") -> str:
        """Перемещает элемент в структуре проекта с учетом его вложенности"""
        try:
            return self.outline_service.reorder_project_tree(text, source_idx, target_idx, position)
        except Exception as e:
            safe_print(f"[Backend] Ошибка reorder_project_tree: {e}")
            return text

    @pyqtSlot(str, int, int, result=str)
    def change_project_tree_level(self, text: str, item_idx: int, delta: int) -> str:
        """Повышает/понижает отступ элемента дерева проекта"""
        try:
            return self.outline_service.change_project_tree_level(text, item_idx, delta)
        except Exception as e:
            safe_print(f"[Backend] Ошибка change_project_tree_level: {e}")
            return text

    @pyqtSlot(str, str, str, int, result=str)
    @pyqtSlot(str, str, str, result=str)
    def add_project_tree_item(self, text: str, label: str, item_type: str = "file", target_idx: int = -1) -> str:
        """Добавляет новый элемент (папку или заметку) в структуру проекта"""
        try:
            return self.outline_service.add_project_tree_item(text, label, item_type, target_idx)
        except Exception as e:
            safe_print(f"[Backend] Ошибка add_project_tree_item: {e}")
            return text
