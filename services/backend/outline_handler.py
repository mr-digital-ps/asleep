# services/backend/outline_handler.py — Обработчик аутлайна документов и структуры проекта
from PyQt6.QtCore import pyqtSlot, QUrl
from services.backend.app_initializer import safe_print


class OutlineHandlerMixin:
    """Миксин для парсинга и манипуляции структурой документа и иерархией проекта."""

    @pyqtSlot(str, result="QVariantList")
    @pyqtSlot(str, str, result="QVariantList")
    def get_document_outline(self, text: str, filename: str = "") -> list:
        """Разбирает текст на плоский список иерархических блоков"""
        try:
            h_regex = None
            if hasattr(self, "block_engine") and self.block_engine:
                h_regex = self.block_engine.get_heading_regex()
            is_proj = False
            if filename and hasattr(self, "is_project_structure_file"):
                is_proj = self.is_project_structure_file(filename)
            return self.outline_service.parse_document(text, heading_regex=h_regex, parse_list_items=is_proj)
        except Exception as e:
            safe_print(f"[Backend] Ошибка парсинга аутлайна: {e}")
            return []

    @pyqtSlot(str, result="QVariantMap")
    def parse_dialect(self, text: str) -> dict:
        """Разбирает пользовательский диалект сценария/заметок (блоки, трансклюзия, ссылки)."""
        try:
            from services.content.document_outline import parse_user_dialect
            res = parse_user_dialect(text)
            return dict(res)
        except Exception as e:
            safe_print(f"[Backend] Ошибка парсинга диалекта: {e}")
            return {"blocks": [], "local_calls": [], "external_calls": [], "wikilinks": [], "free_text": "", "errors": [str(e)]}

    @pyqtSlot(result=str)
    @pyqtSlot(str, result=str)
    def get_project_structure_filename(self, folder_url: str = "") -> str:
        """Возвращает настроенное имя файла структуры проекта из конфигурации (user -> default: _notes.txt)."""
        folder = self.file_service.to_path(folder_url) if folder_url else self._current_folder
        md_cfg = self.config_service.get_syntax_config(folder) or {}
        struct_file = md_cfg.get("system_files", {}).get("structure_file", "_notes.txt")
        if not struct_file.endswith(".txt"):
            struct_file += ".txt"
        return struct_file

    @pyqtSlot(str, result=bool)
    @pyqtSlot(str, str, result=bool)
    def is_project_structure_file(self, filename: str, folder_url: str = "") -> bool:
        """Служебные файлы структуры удалены из архитектуры"""
        return False


    @pyqtSlot(str, result="QVariantMap")
    @pyqtSlot(result="QVariantMap")
    def sync_project_structure_file(self, folder_url: str = "") -> dict:
        """Гарантирует создание и возвращает данные файла структуры проекта для открытия"""
        folder = self.file_service.to_path(folder_url) if folder_url else self._current_folder
        if not folder or not folder.exists() or not folder.is_dir():
            return {}
        try:
            struct_file = self.get_project_structure_filename(folder_url)
            md_cfg = self.config_service.get_syntax_config(folder) or {}
            sys_cfg = md_cfg.get("system_files", {})
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
        struct_file = self.get_project_structure_filename(folder_url)
        fpath = folder / struct_file
        if not fpath.exists():
            return []
        try:
            text = fpath.read_text(encoding="utf-8")
            return self.outline_service.parse_document(text, parse_list_items=True)
        except Exception as e:
            safe_print(f"[Backend] Ошибка чтения дерева проекта: {e}")
            return []
