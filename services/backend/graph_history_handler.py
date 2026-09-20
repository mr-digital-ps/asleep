# services/backend/graph_history_handler.py — Обработчик графа знаний и истории проекта
from PyQt6.QtCore import pyqtSlot, QUrl
from services.backend.app_initializer import safe_print


class GraphHistoryHandlerMixin:
    """Миксин для взаимодействия с графом знаний и историей изменений проекта."""

    @pyqtSlot(result="QVariantMap")
    @pyqtSlot(str, result="QVariantMap")
    def get_graph_data(self, folder_url: str = "") -> dict:
        """Возвращает узлы и связи графа для текущей или указанной рабочей папки"""
        folder = self.file_service.to_path(folder_url) if folder_url else self._current_folder
        return self.graph_service.build_graph(folder)

    @pyqtSlot(result="QVariantMap")
    @pyqtSlot(str, result="QVariantMap")
    def sync_graph_file(self, folder_url: str = "") -> dict:
        """Синхронизирует _Граф связей.md в рабочей папке и возвращает метаданные для открытия"""
        folder = self.file_service.to_path(folder_url) if folder_url else self._current_folder
        if not folder or not folder.exists() or not folder.is_dir():
            return {}
        try:
            self._is_syncing_files = True
            p = self.graph_service.sync_graph_markdown_file(folder)
            if p and p.exists():
                return {
                    "fileUrl": QUrl.fromLocalFile(str(p.resolve())).toString(),
                    "fileName": p.name,
                    "filePath": str(p)
                }
        except Exception as e:
            safe_print(f"[Backend] Ошибка sync_graph_file: {e}")
        finally:
            self._is_syncing_files = False
        return {}

    @pyqtSlot(result="QVariantMap")
    @pyqtSlot(str, result="QVariantMap")
    def get_graph_config(self, folder_url: str = "") -> dict:
        """Возвращает текущую объединенную конфигурацию физики и визуала графа"""
        folder = self.file_service.to_path(folder_url) if folder_url else self._current_folder
        return self.graph_service.get_config(folder)

    @pyqtSlot(str, "QVariantMap")
    def save_node_positions(self, folder_url: str, positions: dict):
        """Сохраняет пользовательские или равновесные координаты узлов графа"""
        folder = self.file_service.to_path(folder_url) if folder_url else self._current_folder
        self.graph_service.save_node_positions(folder, positions)

    @pyqtSlot(result="QVariantMap")
    @pyqtSlot(str, result="QVariantMap")
    def get_node_positions(self, folder_url: str = "") -> dict:
        """Возвращает сохраненные координаты узлов графа"""
        folder = self.file_service.to_path(folder_url) if folder_url else self._current_folder
        return self.graph_service.get_node_positions(folder)

    @pyqtSlot(result="QVariantList")
    @pyqtSlot(str, result="QVariantList")
    def get_history_timeline(self, folder_url: str = "") -> list:
        folder = self.file_service.to_path(folder_url) if folder_url else self._current_folder
        if not folder or not folder.exists() or not folder.is_dir():
            return []
        return self.history_service.get_timeline(folder)

    @pyqtSlot(str, result="QVariantList")
    @pyqtSlot(str, str, result="QVariantList")
    def get_file_history_timeline(self, file_url_or_path: str, folder_url: str = "") -> list:
        """Возвращает историю снимков конкретного файла заметки"""
        folder = self.file_service.to_path(folder_url) if folder_url else self._current_folder
        if not folder or not folder.exists() or not folder.is_dir() or not file_url_or_path:
            return []
        fpath = self.file_service.to_path(file_url_or_path)
        if fpath:
            try:
                rel_or_name = str(fpath.relative_to(folder))
            except ValueError:
                rel_or_name = fpath.name
        else:
            rel_or_name = str(file_url_or_path)
        return self.history_service.get_file_timeline(folder, rel_or_name)

    @pyqtSlot(int, result="QVariantMap")
    @pyqtSlot(str, int, result="QVariantMap")
    def get_history_snapshot_graph(self, arg1, arg2: int = -1) -> dict:
        if isinstance(arg1, int):
            snap_id = arg1
            folder = self._current_folder
        else:
            snap_id = arg2
            folder = self.file_service.to_path(arg1) if arg1 else self._current_folder
        if not folder or not folder.exists() or not folder.is_dir():
            return {}
        return self.history_service.get_snapshot_graph(folder, snap_id)

    @pyqtSlot(int, str, result=str)
    @pyqtSlot(str, int, str, result=str)
    def get_history_file_content(self, arg1, arg2, arg3=None) -> str:
        if arg3 is None:
            folder = self._current_folder
            snap_id = int(arg1)
            file_path = str(arg2)
        else:
            folder = self.file_service.to_path(arg1) if arg1 else self._current_folder
            snap_id = int(arg2)
            file_path = str(arg3)
        if not folder or not folder.exists():
            return ""
        if str(file_path).startswith("file:"):
            fpath = self.file_service.to_path(file_path)
            if fpath:
                try:
                    file_path = str(fpath.relative_to(folder))
                except ValueError:
                    file_path = fpath.name
        return self.history_service.get_snapshot_file_content(folder, snap_id, file_path)

    @pyqtSlot(str)
    @pyqtSlot(str, str)
    def record_manual_snapshot(self, description: str, folder_url: str = ""):
        folder = self.file_service.to_path(folder_url) if folder_url else self._current_folder
        if folder and folder.exists() and folder.is_dir():
            try:
                g_data = self.graph_service.build_graph(folder)
                snap = self.history_service.create_snapshot(
                    folder, trigger="manual", description=description, graph_data=g_data, force=True
                )
                if snap:
                    self.historyUpdated.emit()
            except Exception as e:
                safe_print(f"[Backend] Ошибка создания ручного снимка истории: {e}")
