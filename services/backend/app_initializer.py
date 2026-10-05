# services/backend/app_initializer.py — Настройка графики, шрифтов и консоли
import sys
from pathlib import Path
from PyQt6.QtGui import QFontDatabase, QSurfaceFormat
from services.storage.config_service import ConfigService


def safe_print(*args, **kwargs):
    """Безопасный вывод в консоль Windows без падений при проблемах кодировки."""
    try:
        print(*args, **kwargs)
    except Exception:
        pass


def configure_surface_format():
    """Настраивает вертикальную синхронизацию (VSync) на основе config/app.json"""
    try:
        cfg = ConfigService().get_app_config()
        vsync = cfg.get("vsync", True)
        tf_str = str(cfg.get("target_fps", "auto")).strip().lower()

        fmt = QSurfaceFormat()
        if vsync is False or tf_str in ("unlimited", "-1", "none", "off", "max", "0"):
            fmt.setSwapInterval(0)
            safe_print("[Graphics] VSync отключен: FPS не ограничен (SwapInterval=0)")
        else:
            fmt.setSwapInterval(1)
            safe_print("[Graphics] VSync включен: синхронизация с кадровой разверткой монитора (SwapInterval=1)")
        QSurfaceFormat.setDefaultFormat(fmt)
    except Exception as e:
        safe_print(f"[Graphics] Ошибка настройки QSurfaceFormat: {e}")


from PyQt6.QtGui import QFontDatabase, QSurfaceFormat, QGuiApplication, QFont


def configure_app_font(app=None):
    """Единый шрифт приложения из config theme.json → font_family.
    Все элементы UI и QML наследуют его глобально через QApplication.setFont."""
    try:
        if app is None:
            app = QGuiApplication.instance()
        if app is None:
            return

        cfg = ConfigService().get_theme_config()
        family = str(cfg.get("font_family", "")).strip()
        if not family:
            return

        available = {f.lower(): f for f in QFontDatabase.families()}
        matched_family = available.get(family.lower(), family)

        font = app.font()
        font.setFamily(matched_family)
        font.setStyleHint(QFont.StyleHint.Monospace)
        app.setFont(font)
        if family.lower() not in available:
            safe_print(f"[Font] Предупреждение: шрифт '{family}' не найден в Windows. Qt использует моноширинный fallback.")
        else:
            safe_print(f"[Font] Глобальный шрифт приложения установлен: {matched_family}")
    except Exception as e:
        safe_print(f"[Font] Ошибка установки шрифта: {e}")

