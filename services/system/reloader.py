from pathlib import Path
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtCore import QFileSystemWatcher, QTimer, QUrl

def setup_live_reload(engine: QQmlApplicationEngine, root_file: Path):
    """
    Горячая перезагрузка QML при сохранении любого файла разметки без перезапуска Python.
    """
    watcher = QFileSystemWatcher(engine)
    project_dir = root_file.parent.parent if root_file.parent.name == "views" else root_file.parent
    ignored = {".venv", ".git", "__pycache__", "trash", ".backup_my-text-editor-pre-split"}
    watched_files = []
    file_mtimes = {}

    for ext in ("*.qml", "*.js"):
        for f in project_dir.rglob(ext):
            if any(part in ignored for part in f.parts):
                continue
            p = str(f.resolve())
            watcher.addPath(p)
            file_mtimes[p] = f.stat().st_mtime_ns
            watched_files.append(f.name)

    print(f"[Live Reload] Активен ({len(set(watched_files))} файлов)")

    reload_timer = QTimer(engine)
    reload_timer.setSingleShot(True)
    reload_timer.setInterval(200)

    def do_reload():
        print("\n[Live Reload] Изменение в QML обнаружено. Перезагрузка интерфейса...")
        engine.clearComponentCache()
        root_objs = engine.rootObjects()
        for obj in list(root_objs):
            obj.deleteLater()
        QTimer.singleShot(50, lambda: engine.load(QUrl.fromLocalFile(str(root_file.resolve()))))

    def on_file_changed(path_str: str):
        p = Path(path_str)
        if not p.exists():
            return
        cur_m = p.stat().st_mtime_ns
        if cur_m == file_mtimes.get(path_str, 0):
            return
        file_mtimes[path_str] = cur_m
        reload_timer.start()

    reload_timer.timeout.connect(do_reload)
    watcher.fileChanged.connect(on_file_changed)
