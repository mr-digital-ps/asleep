# services/backend/outline_handler.py — Обработчик аутлайна документов и структуры проекта
from PyQt6.QtCore import pyqtSlot, QUrl
from services.backend.app_initializer import safe_print


class OutlineHandlerMixin:
    """Миксин для парсинга и манипуляции структурой документа и иерархией проекта."""

    @pyqtSlot(str, result="QVariantList")
    @pyqtSlot(str, str, result="QVariantList")
    def get_document_outline(self, text: str, filename: str = "") -> list:
        """Разбирает markdown-текст на плоский список иерархических блоков"""
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
        """Возвращает настроенное имя файла структуры проекта из конфигурации (user -> default: _notes.md)."""
        folder = self.file_service.to_path(folder_url) if folder_url else self._current_folder
        md_cfg = self.config_service.get_markdown_config(folder) or {}
        struct_file = md_cfg.get("system_files", {}).get("structure_file", "_notes.md")
        if not struct_file.endswith(".md"):
            struct_file += ".md"
        return struct_file

    @pyqtSlot(str, result=bool)
    @pyqtSlot(str, str, result=bool)
    def is_project_structure_file(self, filename: str, folder_url: str = "") -> bool:
        """Служебные файлы структуры удалены из архитектуры"""
        return False


    @pyqtSlot(str, int, int, str, result=str)
    @pyqtSlot(str, int, int, str, str, result=str)
    def reorder_document_outline(self, text: str, source_idx: int, target_idx: int, position: str = "before", filename: str = "") -> str:
        """Перемещает блок и его подразделы до или после другого блока"""
        try:
            is_proj = bool(filename and hasattr(self, "is_project_structure_file") and self.is_project_structure_file(filename))
            return self.outline_service.reorder_blocks(text, source_idx, target_idx, position, parse_list_items=is_proj)
        except Exception as e:
            safe_print(f"[Backend] Ошибка перестановки блоков: {e}")
            return text

    @pyqtSlot(str, int, int, result=str)
    @pyqtSlot(str, int, int, str, result=str)
    def change_outline_level(self, text: str, block_idx: int, delta: int, filename: str = "") -> str:
        """Изменяет уровень заголовка блока (например H2 -> H3)"""
        try:
            is_proj = bool(filename and hasattr(self, "is_project_structure_file") and self.is_project_structure_file(filename))
            return self.outline_service.change_block_level(text, block_idx, delta, parse_list_items=is_proj)
        except Exception as e:
            safe_print(f"[Backend] Ошибка изменения уровня заголовка: {e}")
            return text

    @pyqtSlot(str, int, str, result=str)
    @pyqtSlot(str, int, str, str, result=str)
    def update_outline_block_heading(self, text: str, block_idx: int, new_heading: str, filename: str = "") -> str:
        """Обновляет заголовок или текст списочного элемента блока в документе и возвращает обновленный текст документа"""
        try:
            is_proj = bool(filename and hasattr(self, "is_project_structure_file") and self.is_project_structure_file(filename))
            return self.outline_service.update_block_heading(text, block_idx, new_heading, parse_list_items=is_proj)
        except Exception as e:
            safe_print(f"[Backend] Ошибка update_outline_block_heading: {e}")
            return text

    @pyqtSlot(str, int, str, result=str)
    @pyqtSlot(str, int, str, str, result=str)
    def update_outline_block_content(self, text: str, block_idx: int, new_content: str, filename: str = "") -> str:
        """Обновляет текст блока в документе и возвращает обновленный текст документа"""
        try:
            is_proj = bool(filename and hasattr(self, "is_project_structure_file") and self.is_project_structure_file(filename))
            return self.outline_service.update_block_content(text, block_idx, new_content, parse_list_items=is_proj)
        except Exception as e:
            safe_print(f"[Backend] Ошибка update_outline_block_content: {e}")
            return text


    @pyqtSlot(str, result="QVariantMap")
    @pyqtSlot(result="QVariantMap")
    def sync_project_structure_file(self, folder_url: str = "") -> dict:
        """Гарантирует создание и возвращает данные файла структуры проекта для открытия"""
        folder = self.file_service.to_path(folder_url) if folder_url else self._current_folder
        if not folder or not folder.exists() or not folder.is_dir():
            return {}
        try:
            struct_file = self.get_project_structure_filename(folder_url)
            md_cfg = self.config_service.get_markdown_config(folder) or {}
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

    # --- Сквозной Single Source of Truth, Undo/Redo и Проекция курсора ---

    def _get_document_session(self, file_url: str = ""):
        if not hasattr(self, "_doc_sessions"):
            self._doc_sessions = {}
        key = file_url or "default"
        if key not in self._doc_sessions:
            from services.core.document_session import DocumentSession
            self._doc_sessions[key] = DocumentSession()
        return self._doc_sessions[key]

    @pyqtSlot(str, int, result=int)
    def get_block_offset(self, text: str, block_idx: int) -> int:
        """Возвращает символьное смещение начала блока в тексте (Hierarchy -> Source)"""
        from services.core.document_session import DocumentSession
        sess = DocumentSession(text)
        return sess.get_block_offset(block_idx)

    @pyqtSlot(str, int, result=int)
    def get_block_at_offset(self, text: str, char_offset: int) -> int:
        """Возвращает индекс блока под курсором (Source -> Hierarchy)"""
        from services.core.document_session import DocumentSession
        sess = DocumentSession(text)
        return sess.get_block_at_offset(char_offset)

    @pyqtSlot(str, str)
    def record_document_state(self, file_url: str, text: str):
        """Записывает изменение текста документа в единый стек отмены"""
        sess = self._get_document_session(file_url)
        sess.set_text(text, record_undo=True)

    @pyqtSlot(str, result=str)
    def undo_document(self, file_url: str) -> str:
        """Откатывает последнее изменение в документе"""
        sess = self._get_document_session(file_url)
        res = sess.undo()
        return res if res is not None else sess.text

    @pyqtSlot(str, result=str)
    def redo_document(self, file_url: str) -> str:
        """Повторяет отмененное изменение в документе"""
        sess = self._get_document_session(file_url)
        res = sess.redo()
        return res if res is not None else sess.text

    @pyqtSlot(str, result=bool)
    def can_undo_document(self, file_url: str) -> bool:
        sess = self._get_document_session(file_url)
        return bool(sess.can_undo)

    @pyqtSlot(str, result=bool)
    def can_redo_document(self, file_url: str) -> bool:
        sess = self._get_document_session(file_url)
        return bool(sess.can_redo)

