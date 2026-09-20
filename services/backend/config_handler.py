# services/backend/config_handler.py — Обработчик конфигураций редактора, темы и сессии
import json
from PyQt6.QtWidgets import QApplication
from PyQt6.QtCore import QObject, pyqtSlot, QUrl
from PyQt6.QtGui import QTextCursor, QTextOption
from PyQt6.QtQuick import QQuickTextDocument
from services.file_service import save_session_config, load_session_config
from services.syntax_highlighter import MarkdownHighlighter
from services.backend.app_initializer import safe_print


class ConfigHandlerMixin:
    """Миксин для управления настройками темы, редактора, форматирования текста и геометрии."""

    @pyqtSlot(result=str)
    def get_current_config(self) -> str:
        return json.dumps(self.config_service.current_config)

    @pyqtSlot(str, result="QVariantMap")
    @pyqtSlot(result="QVariantMap")
    def open_or_create_folder_config(self, folder_url: str = "") -> dict:
        folder = self.file_service.to_path(folder_url) if folder_url else self._current_folder
        if not folder or not folder.exists():
            return {"success": False, "error": "Рабочая папка не выбрана"}
        config_path = self.config_service.ensure_folder_config(folder)
        file_url = QUrl.fromLocalFile(str(config_path.resolve())).toString()
        self.folderFilesChanged.emit()
        return {
            "success": True,
            "fileUrl": file_url,
            "fileName": config_path.name
        }

    @pyqtSlot(str, result=bool)
    def is_config_file(self, file_url: str) -> bool:
        path = self.file_service.to_path(file_url)
        return self.config_service.is_config_filename(path.name)

    @pyqtSlot(QObject, float)
    @pyqtSlot(QObject)
    def set_editor_line_height(self, editor_area_item: QObject, percent: float = 100.0):
        """Устанавливает высоту строки пропорционально размеру шрифта (ProportionalHeight)"""
        try:
            if not editor_area_item:
                return
            doc_wrapper = editor_area_item.property("textDocument")
            if isinstance(doc_wrapper, QQuickTextDocument):
                qtdoc = doc_wrapper.textDocument()
                cursor = QTextCursor(qtdoc)
                cursor.select(QTextCursor.SelectionType.Document)
                bf = cursor.blockFormat()
                target_percent = float(percent) if (percent and percent > 0) else 135.0
                bf.setLineHeight(target_percent, 1)
                cursor.setBlockFormat(bf)
                opt = qtdoc.defaultTextOption()
                opt.setFlags(opt.flags() | QTextOption.Flag.AddSpaceForLineAndParagraphSeparators)
                qtdoc.setDefaultTextOption(opt)
        except Exception as e:
            safe_print(f"[Backend] Ошибка установки line_height: {e}")

    @pyqtSlot(QObject)
    def attach_highlighter(self, editor_area_item: QObject):
        """Подключает подсветку синтаксиса Markdown к документу TextArea"""
        try:
            if not editor_area_item:
                return
            doc_wrapper = editor_area_item.property("textDocument")
            if isinstance(doc_wrapper, QQuickTextDocument):
                qtdoc = doc_wrapper.textDocument()
                if not hasattr(qtdoc, "_highlighter") or qtdoc._highlighter is None:
                    qtdoc._highlighter = MarkdownHighlighter(qtdoc)
                    safe_print("[Backend] MarkdownHighlighter успешно подключен")
        except Exception as e:
            safe_print(f"[Backend] Ошибка подключения MarkdownHighlighter: {e}")

    @pyqtSlot(float)
    def update_sheet_width(self, width: float):
        """Сохраняет текущую ширину листа в конфигурацию сессии и папку"""
        w = int(width)
        if "editor" in self.config_service.current_config:
            self.config_service.current_config["editor"]["sheet_width"] = w
        save_session_config({"sheet_width": w})
        if self._current_folder:
            new_mtime = self.config_service.update_folder_editor_setting(self._current_folder, "sheet_width", w)
            if new_mtime > 0:
                self._last_config_mtime = new_mtime

    @pyqtSlot(int)
    def update_font_size(self, font_size: int):
        """Сохраняет текущий размер шрифта в конфигурацию сессии и папку"""
        sz = int(font_size)
        if "editor" in self.config_service.current_config:
            self.config_service.current_config["editor"]["font_size"] = sz
        save_session_config({"font_size": sz})
        if self._current_folder:
            new_mtime = self.config_service.update_folder_editor_setting(self._current_folder, "font_size", sz)
            if new_mtime > 0:
                self._last_config_mtime = new_mtime

    @pyqtSlot(float, float, float, float)
    def save_window_geometry(self, x: float, y: float, w: float, h: float):
        """Сохраняет геометрию главного окна в сессию"""
        save_session_config({
            "win_x": int(x),
            "win_y": int(y),
            "win_width": int(w),
            "win_height": int(h)
        })

    @pyqtSlot(bool)
    def save_header_pinned(self, pinned: bool):
        """Сохраняет состояние закрепления верхнего заголовка в сессию"""
        save_session_config({"header_pinned": bool(pinned)})

    @pyqtSlot(bool)
    def save_footer_pinned(self, pinned: bool):
        """Сохраняет состояние закрепления нижнего статус-бара в сессию"""
        save_session_config({"footer_pinned": bool(pinned)})

    @pyqtSlot(bool)
    def save_header_visible(self, visible: bool):
        """Сохраняет видимость верхнего заголовка в сессию"""
        save_session_config({"header_visible": bool(visible)})

    @pyqtSlot(bool)
    def save_footer_visible(self, visible: bool):
        """Сохраняет видимость нижнего статус-бара в сессию"""
        save_session_config({"footer_visible": bool(visible)})

    @pyqtSlot(result="QVariantMap")
    def get_session_config(self) -> dict:
        """Возвращает параметры сохраненной сессии"""
        return load_session_config()

    @pyqtSlot(result="QVariantMap")
    @pyqtSlot(str, result="QVariantMap")
    def get_theme_config(self, folder_url: str = "") -> dict:
        """Возвращает актуальные настройки темы и интерфейса"""
        folder = self.file_service.to_path(folder_url) if folder_url else self._current_folder
        return self.config_service.get_theme_config(folder)

    @pyqtSlot(result="QVariantMap")
    @pyqtSlot(str, result="QVariantMap")
    def get_editor_config(self, folder_url: str = "") -> dict:
        """Возвращает актуальные настройки редактора из config/editor_*.json"""
        folder = self.file_service.to_path(folder_url) if folder_url else self._current_folder
        return self.config_service.get_editor_config(folder)

    @pyqtSlot(result="QVariantMap")
    @pyqtSlot(str, result="QVariantMap")
    def get_app_config(self, folder_url: str = "") -> dict:
        """Возвращает актуальные системные настройки приложения"""
        folder = self.file_service.to_path(folder_url) if folder_url else self._current_folder
        return self.config_service.get_app_config(folder)

    @pyqtSlot(result=float)
    def get_screen_refresh_rate(self) -> float:
        """Возвращает физическую частоту развертки экрана в Гц"""
        app = QApplication.instance()
        if app:
            screen = app.primaryScreen()
            if screen:
                rate = screen.refreshRate()
                if rate > 0:
                    return float(rate)
        return 60.0

    @pyqtSlot(result=int)
    def get_target_fps(self) -> int:
        """
        Возвращает целевой FPS интерфейса из config/app.json.
        0 — неограниченный (unlimited), >0 — автоматический по герцовке экрана или фиксированный.
        """
        try:
            cfg = self.config_service.get_app_config(self._current_folder)
            tf = cfg.get("target_fps", "auto")
            tf_str = str(tf).strip().lower()
            if tf_str in ("auto", ""):
                rate = self.get_screen_refresh_rate()
                return int(round(rate)) if rate > 0 else 60
            if tf_str in ("unlimited", "-1", "none", "off", "max", "0"):
                return 0
            val = int(tf)
            return max(15, min(360, val))
        except Exception:
            return 60
