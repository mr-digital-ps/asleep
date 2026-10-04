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
