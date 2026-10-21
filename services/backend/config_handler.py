# services/backend/config_handler.py — Обработчик конфигураций редактора, темы и сессии
import json
from PyQt6.QtWidgets import QApplication
from PyQt6.QtCore import QObject, pyqtSlot
from PyQt6.QtGui import QTextCursor, QTextOption
from PyQt6.QtQuick import QQuickTextDocument
from PyQt6.sip import isdeleted, unwrapinstance
from services.content.dialect_highlighter import DialectHighlighter
from services.storage.file_service import save_session_config, load_session_config
from services.backend.app_initializer import safe_print

_active_highlighters: dict[int, DialectHighlighter] = {}


class ConfigHandlerMixin:
    """Миксин для управления настройками темы, редактора, форматирования текста и геометрии."""

    @pyqtSlot(result=str)
    def get_current_config(self) -> str:
        return json.dumps(self.config_service.current_config)


    @pyqtSlot(str, result=bool)
    def is_config_file(self, file_url: str) -> bool:
        path = self.file_service.to_path(file_url)
        return self.config_service.is_config_filename(path.name)

    @pyqtSlot(QObject, float)
    @pyqtSlot(QObject)
    @pyqtSlot(QObject, float)
    def set_editor_line_height(self, editor_area_item: QObject, percent: float = 135.0):
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
                if opt.flags() & QTextOption.Flag.AddSpaceForLineAndParagraphSeparators:
                    opt.setFlags(opt.flags() & ~QTextOption.Flag.AddSpaceForLineAndParagraphSeparators)
                    qtdoc.setDefaultTextOption(opt)
        except Exception as e:
            safe_print(f"[Backend] Ошибка установки line_height: {e}")

    @pyqtSlot(QObject, bool)
    @pyqtSlot(QObject)
    def set_editor_live_mode(self, editor_area_item: QObject, is_live_mode: bool = True):
        """Включает или отключает подсветку диалекта для Live Mode / Source Mode."""
        try:
            if not editor_area_item:
                return
            doc_wrapper = editor_area_item.property("textDocument")
            if isinstance(doc_wrapper, QQuickTextDocument):
                qtdoc = doc_wrapper.textDocument()
                if not qtdoc:
                    return
                doc_key = unwrapinstance(qtdoc)
                hl = _active_highlighters.get(doc_key)
                need_create = (hl is None)
                if not need_create:
                    try:
                        if isdeleted(hl):
                            need_create = True
                        else:
                            hl.set_live_mode(is_live_mode)
                    except (RuntimeError, Exception):
                        need_create = True

                if need_create:
                    theme = self.config_service.get_theme_config()
                    hl = DialectHighlighter(qtdoc, theme, is_live_mode=is_live_mode)
                    _active_highlighters[doc_key] = hl
        except Exception as e:
            safe_print(f"[Backend] Ошибка set_editor_live_mode: {e}")

    @pyqtSlot("QVariant", bool)
    @pyqtSlot("QVariant", bool, "QVariant")
    def set_editor_diff_mode(self, editor_area, is_diff_mode: bool, diff_lines=None):
        if not editor_area:
            return
        try:
            doc_prop = editor_area.property("textDocument")
            if doc_prop and hasattr(doc_prop, "textDocument"):
                qtdoc = doc_prop.textDocument()
                doc_key = id(qtdoc)
                if doc_key in _active_highlighters:
                    hl = _active_highlighters[doc_key]
                    if hasattr(hl, "set_diff_mode"):
                        hl.set_diff_mode(is_diff_mode, diff_lines)
        except Exception as e:
            safe_print(f"[Backend] Ошибка set_editor_diff_mode: {e}")

    def update_highlighters_theme(self):
        """Обновляет цветовую палитру всех активных подсветчиков при смене темы"""
        theme = self.config_service.get_theme_config()
        for hl in list(_active_highlighters.values()):
            try:
                hl.update_theme(theme)
            except Exception:
                pass

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
        sz = font_size
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
        save_session_config({"header_pinned": pinned})

    @pyqtSlot(bool)
    def save_header_visible(self, visible: bool):
        """Сохраняет видимость верхнего заголовка в сессию"""
        save_session_config({"header_visible": visible})

    @pyqtSlot(bool)
    def save_show_scrollbar(self, show: bool):
        """Сохраняет отображение скроллбара в сессию"""
        save_session_config({"show_scrollbar": show})

    @pyqtSlot(bool)
    def save_show_line_dots(self, show: bool):
        """Сохраняет отображение точек строк в сессию"""
        save_session_config({"show_line_dots": show})

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

    @pyqtSlot(result="QVariantMap")
    @pyqtSlot(str, result="QVariantMap")
    def get_syntax_config(self, folder_url: str = "") -> dict:
        """Возвращает актуальные настройки синтаксиса из config/syntax.json"""
        folder = self.file_service.to_path(folder_url) if folder_url else self._current_folder
        return self.config_service.get_syntax_config(folder)

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
                return round(rate) if rate > 0 else 60
            if tf_str in ("unlimited", "-1", "none", "off", "max", "0"):
                return 0
            val = int(tf)
            return max(15, min(360, val))
        except Exception:
            return 60
