from PyQt6.QtCore import QObject
from PyQt6 import sip

class WindowManager:
    """
    Менеджер окон приложения.
    Ведет реестр активных окон и рассчитывает геометрию сброса (Drop Zones) при перетаскивании.
    """
    def __init__(self):
        self._windows = []  # Список кортежей: (win, root_item)

    def _is_valid_qobject(self, obj) -> bool:
        if not obj:
            return False
        try:
            if sip.isdeleted(obj):
                return False
            return True
        except Exception:
            return False

    def clean_windows(self):
        self._windows = [(w, r) for w, r in self._windows if self._is_valid_qobject(w) and self._is_valid_qobject(r)]

    def register_window(self, win: QObject, root_item: QObject):
        """Регистрация открытого окна приложения в реестре"""
        if not win:
            return
        self.clean_windows()
        for i, (w, r) in enumerate(self._windows):
            if w == win:
                self._windows[i] = (win, root_item)
                return
        self._windows.append((win, root_item))
        print(f"[WindowManager] Окно зарегистрировано. Всего активных окон: {len(self._windows)}")

    def unregister_window(self, win: QObject):
        """Удаление закрытого окна из реестра"""
        self._windows = [(w, r) for w, r in self._windows if self._is_valid_qobject(w) and w != win]
        print(f"[WindowManager] Окно разрегистрировано. Осталось активных окон: {len(self._windows)}")

    def find_target_window_at(self, gx: float, gy: float, exclude_win: QObject = None, exclude_win2: QObject = None) -> dict:
        """
        Проверяет, над каким окном приложения находится курсор (gx, gy).
        Возвращает информацию о целевом окне и зону сброса (left, right, center).
        """
        self.clean_windows()
        for win, root in self._windows:
            if win == exclude_win or win == exclude_win2:
                continue
            try:
                if hasattr(win, "isVisible") and not win.isVisible():
                    continue
                wx = win.x()
                wy = win.y()
                ww = win.width()
                wh = win.height()
                if wx <= gx <= wx + ww and wy <= gy <= wy + wh:
                    rel_x = (gx - wx) / max(1, ww)
                    if rel_x < 0.25:
                        zone = "left"
                    elif rel_x > 0.75:
                        zone = "right"
                    else:
                        zone = "center"
                    return {
                        "found": True,
                        "targetWin": win,
                        "targetRoot": root,
                        "zone": zone,
                    }
            except Exception:
                continue
        return {"found": False, "zone": ""}

    def set_window_drop_zone(self, win: QObject, zone: str):
        """Устанавливает визуальную зону сброса на целевом окне"""
        self.clean_windows()
        for w, root in self._windows:
            try:
                if w == win:
                    root.setProperty("dropZone", zone)
                else:
                    root.setProperty("dropZone", "")
            except RuntimeError:
                pass

    def clear_all_drop_zones(self):
        """Очищает подсветку зон сброса во всех открытых окнах"""
        self.clean_windows()
        for _, root in self._windows:
            try:
                root.setProperty("dropZone", "")
            except RuntimeError:
                pass
