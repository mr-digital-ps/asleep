# services/backend/file_handler.py — Обработчик файловых операций и заметок
import json
from datetime import datetime
from pathlib import Path
from PyQt6.QtCore import pyqtSlot, QUrl
from services.storage.file_service import save_session_config
from services.backend.app_initializer import safe_print, configure_app_font


class FileHandlerMixin:
    """Миксин для файловых операций, резолвинга путей и управления папкой заметок."""

    @pyqtSlot(str)
    def watch_folder(self, folder_url: str):
        """Отслеживает изменения файлов в рабочей папке"""
        try:
            folder = self.file_service.to_path(folder_url)
            self._current_folder = folder
            existing = self.folder_watcher.directories()
            if existing:
                self.folder_watcher.removePaths(existing)
            if folder.exists() and folder.is_dir():
                dirs_to_watch = [str(folder.resolve())]
                try:
                    for p in folder.rglob("*"):
                        if p.is_dir() and not any(part.startswith((".", "_")) for part in p.relative_to(folder).parts):
                            dirs_to_watch.append(str(p.resolve()))
                except Exception:
                    pass
                self.folder_watcher.addPaths(dirs_to_watch)
                self.block_engine.reindex_folder(folder)
                self.config_service.load_folder_config(folder)
                cfg_path = self.config_service.get_config_file_path(folder)
                if cfg_path and cfg_path.exists():
                    self._last_config_mtime = cfg_path.stat().st_mtime_ns
                self.configUpdated.emit(json.dumps(self.config_service.current_config))

                # Автоматическая синхронизация файла структуры проекта (_notes.md)
                if hasattr(self, "sync_project_structure_file"):
                    try:
                        self.sync_project_structure_file(folder_url)
                    except Exception as e:
                        safe_print(f"[Backend] Ошибка синхронизации структуры при watch_folder: {e}")

                self._last_user_files_snapshot = self._get_user_files_snapshot()
        except Exception as e:
            print(f"[Backend] Ошибка отслеживания папки: {e}")

    @pyqtSlot(str, result="QVariantList")
    def get_folder_files(self, folder_url: str) -> list:
        return self.file_service.get_folder_files(folder_url)

    @pyqtSlot(str, result=bool)
    def delete_file(self, file_url: str) -> bool:
        success = self.file_service.delete_file(file_url)
        if success:
            if hasattr(self, "sync_project_structure_file"):
                try:
                    self.sync_project_structure_file()
                except Exception:
                    pass
            self.folderFilesChanged.emit()
        return success

    @pyqtSlot(str, result=str)
    def read_file(self, file_url: str) -> str:
        return self.file_service.read_file(file_url)

    @pyqtSlot(str, str, result=bool)
    def save_file(self, file_url: str, text: str) -> bool:
        path = self.file_service.to_path(file_url)
        is_new_file = not path.exists()
        if not is_new_file:
            try:
                if path.read_text(encoding="utf-8") == text:
                    return True
            except Exception:
                pass

        success = self.file_service.save_file(file_url, text)
        if success:
            self.block_engine.index_file_content(file_url, text)
            if self.config_service.is_config_filename(path.name):
                new_cfg = self.config_service.parse_and_update(text)
                cfg_path = self.config_service.get_config_file_path(path.parent)
                if cfg_path and cfg_path.exists():
                    self._last_config_mtime = cfg_path.stat().st_mtime_ns
                self.configUpdated.emit(json.dumps(new_cfg))
                safe_print(f"[ConfigService] Конфигурация обновлена из {path.name}")

            fn = path.name.lower()
            if "graph" in fn:
                self.graphDataChanged.emit()
            elif "hotkey" in fn:
                self.hotkey_service._reload_timer.start()
            elif "theme" in fn:
                configure_app_font()
                self.themeConfigChanged.emit()
            elif "editor" in fn:
                self.config_service.load_folder_config(self._current_folder)
                self.configUpdated.emit(json.dumps(self.config_service.current_config))
            elif "app" in fn:
                self.appConfigChanged.emit()

            # Если создан новый файл — обновляем структуру проекта
            if is_new_file and hasattr(self, "sync_project_structure_file"):
                try:
                    self.sync_project_structure_file()
                except Exception:
                    pass

            # Неявная фиксация контрольной точки дня в историю проекта (не чаще 1 раза в день)
            target_folder = self._current_folder or path.parent
            if target_folder and target_folder.is_dir():
                try:
                    g_data = self.graph_service.build_graph(target_folder)
                    snap = self.history_service.record_daily_snapshot(target_folder, file_path=str(path), graph_data=g_data)
                    if snap:
                        self.historyUpdated.emit()
                except Exception as e:
                    safe_print(f"[Backend] Ошибка фиксации дневного снимка истории: {e}")

            self.folderFilesChanged.emit()
        return success

    @pyqtSlot(str, str, result="QVariantMap")
    def create_file_in_folder(self, folder_url: str, base_name: str = "Новый документ") -> dict:
        res = self.file_service.create_file_in_folder(folder_url, base_name)
        if res.get("success"):
            if hasattr(self, "sync_project_structure_file"):
                try:
                    self.sync_project_structure_file(folder_url)
                except Exception:
                    pass
            self.folderFilesChanged.emit()
        return res

    @pyqtSlot(str, str, result="QVariantMap")
    def rename_file(self, file_url: str, new_name: str) -> dict:
        res = self.file_service.rename_file(file_url, new_name)
        if res.get("success"):
            if hasattr(self, "sync_project_structure_file"):
                try:
                    self.sync_project_structure_file()
                except Exception:
                    pass
            self.folderFilesChanged.emit()
        return res

    @pyqtSlot(str, result=str)
    def get_filename(self, file_url: str) -> str:
        return self.file_service.to_path(file_url).name or "Новый файл"

    @pyqtSlot(result=str)
    def get_default_folder(self) -> str:
        return self.file_service.get_default_folder()

    @pyqtSlot(str)
    def save_last_folder(self, folder_url: str):
        if folder_url:
            save_session_config({"last_folder": folder_url})

    @pyqtSlot(str, result=str)
    def get_folder_name(self, folder_url: str) -> str:
        path = self.file_service.to_path(folder_url)
        return path.name or str(path) or "Заметки"

    @pyqtSlot(result="QVariantMap")
    @pyqtSlot(str, result="QVariantMap")
    def choose_folder_dialog(self, initial_folder: str = "") -> dict:
        res = self.file_service.choose_folder_dialog(initial_folder)
        if res.get("success"):
            url = res.get("folderUrl", "")
            self.watch_folder(url)
            self.folderFilesChanged.emit()
        return res

    @pyqtSlot(str, str, result=str)
    @pyqtSlot(str, result=str)
    def get_note_file_url(self, note_name: str, folder_url: str = "") -> str:
        """Находит или создает заметку по имени в каталоге и возвращает ее fileUrl"""
        folder = self.file_service.to_path(folder_url) if folder_url else self._current_folder
        if not folder or not folder.exists() or not folder.is_dir():
            return ""
        clean = note_name.strip()
        if not clean:
            return ""
        # 1. Мгновенная прямая проверка в корне каталога
        clean_ext = f"{clean}.md" if not clean.endswith(".md") else clean
        cand = folder / clean_ext
        if cand.exists() and cand.is_file():
            return QUrl.fromLocalFile(str(cand.resolve())).toString()

        # 2. Быстрый поиск в подпапках 1-го уровня (без зависания на тяжелом рекурсивном rglob)
        try:
            ignored = {".git", ".venv", "__pycache__", "node_modules", ".asleep"}
            for sub in folder.iterdir():
                if sub.is_dir() and sub.name not in ignored and not sub.name.startswith("."):
                    sub_cand = sub / clean_ext
                    if sub_cand.exists() and sub_cand.is_file():
                        return QUrl.fromLocalFile(str(sub_cand.resolve())).toString()
        except Exception:
            pass

        # Если файла нет, создаем новую заметку с начальным заголовком
        try:
            title = clean.replace(".md", "")
            target_path = folder / f"{title}.md"
            target_path.write_text(f"# {title}\n\n", encoding="utf-8")
            return QUrl.fromLocalFile(str(target_path.resolve())).toString()
        except Exception as e:
            safe_print(f"[Backend] Ошибка создания заметки '{clean}': {e}")
            return ""

    @pyqtSlot(str, str, result=bool)
    @pyqtSlot(str, result=bool)
    def open_wiki_link(self, target: str, folder_url: str = "") -> bool:
        """
        Универсальный фасад перехода по Wiki-ссылке ([[Заметка]], [[Заметка#Блок]], [[#Блок]]).
        Эмитит сигнал noteOpened(file_url, block_name) и возвращает успех.
        """
        raw = target.strip()
        if not raw:
            return False
        # Очистка от скобок [[ ]] если переданы с ними
        if raw.startswith("[[") and raw.endswith("]]"):
            raw = raw[2:-2].strip()

        # Разбор: Заметка#Блок или #Блок или Заметка
        note_name = ""
        block_name = ""
        if "#" in raw:
            parts = raw.split("#", 1)
            note_name = parts[0].strip()
            block_name = parts[1].strip()
        else:
            note_name = raw

        file_url = ""
        if note_name:
            file_url = self.get_note_file_url(note_name, folder_url)
        elif folder_url:
            # Ссылка на блок внутри текущего открытого файла
            file_url = folder_url

        if not file_url:
            safe_print(f"[Backend] open_wiki_link: не удалось найти или создать файл для '{target}'")
            return False

        safe_print(f"[Backend] open_wiki_link -> noteOpened(file_url='{file_url}', block_name='{block_name}')")
        if hasattr(self, "noteOpened"):
            self.noteOpened.emit(file_url, block_name)
        return True

    @pyqtSlot(str, result="QVariantMap")
    @pyqtSlot(str, str, result="QVariantMap")
    def get_file_created_time(self, file_url_or_path: str, folder_url: str = "") -> dict:
        """Возвращает дату и время создания файла"""
        folder = self.file_service.to_path(folder_url) if folder_url else self._current_folder
        fpath = self.file_service.to_path(file_url_or_path)
        if not fpath or not fpath.exists():
            if folder and folder.is_dir():
                cand = folder / file_url_or_path
                if cand.exists():
                    fpath = cand
        if not fpath or not fpath.exists():
            return {}
        try:
            st = fpath.stat()
            # На Windows st_ctime — время создания файла
            ctime = getattr(st, "st_ctime", st.st_mtime)
            dt = datetime.fromtimestamp(ctime)
            return {
                "timestamp": ctime,
                "createdAt": dt.strftime("%d.%m.%Y, %H:%M:%S"),
                "iso": dt.isoformat(),
                "fileName": fpath.name
            }
        except Exception as e:
            safe_print(f"[Backend] Ошибка чтения времени создания файла: {e}")
            return {}
