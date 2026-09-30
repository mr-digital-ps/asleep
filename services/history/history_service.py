import os
import json
import zlib
import time
import hashlib
import sqlite3
from datetime import datetime
from pathlib import Path


class HistoryService:
    """
    Сервис фиксации и хранения истории проекта на базе легковесного SQLite.
    Хранит снимки файлов и структуры графа с zlib-компрессией и дедупликацией.
    """
    def __init__(self, file_service=None, graph_service=None):
        self.file_service = file_service
        self.graph_service = graph_service
        self._last_fingerprints: dict[str, str] = {}  # folder_key -> fingerprint

    def _get_db_path(self, folder: Path) -> Path:
        asleep_dir = folder / ".asleep"
        asleep_dir.mkdir(parents=True, exist_ok=True)
        return asleep_dir / "history.db"

    def _connect_db(self, folder: Path) -> sqlite3.Connection:
        db_path = self._get_db_path(folder)
        conn = sqlite3.connect(str(db_path), timeout=10.0)
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("PRAGMA synchronous=NORMAL")
        self._init_schema(conn)
        return conn

    def _init_schema(self, conn: sqlite3.Connection):
        conn.executescript("""
            CREATE TABLE IF NOT EXISTS snapshots (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp REAL NOT NULL,
                created_at TEXT NOT NULL,
                trigger TEXT NOT NULL,
                timeline_type TEXT NOT NULL DEFAULT 'work',
                description TEXT,
                files_count INTEGER DEFAULT 0,
                nodes_count INTEGER DEFAULT 0,
                links_count INTEGER DEFAULT 0,
                fingerprint TEXT,
                graph_data_blob BLOB
            );

            CREATE TABLE IF NOT EXISTS file_snapshots (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                snapshot_id INTEGER NOT NULL,
                file_path TEXT NOT NULL,
                file_name TEXT NOT NULL,
                content_hash TEXT NOT NULL,
                content_blob BLOB,
                FOREIGN KEY(snapshot_id) REFERENCES snapshots(id) ON DELETE CASCADE
            );

            CREATE INDEX IF NOT EXISTS idx_snapshots_time ON snapshots(timestamp);
            CREATE INDEX IF NOT EXISTS idx_file_snapshots_snap ON file_snapshots(snapshot_id);
        """)
        conn.commit()

    def _compute_folder_files_state(self, folder: Path) -> tuple[dict[str, str], str]:
        """
        Сканирует файлы заметок в папке и вычисляет их хэши и коллективный fingerprint.
        Возвращает: ({rel_path: content_str}, collective_fingerprint)
        """
        if not folder.exists() or not folder.is_dir():
            return {}, ""

        exts = {".md", ".markdown", ".txt"}
        if self.file_service:
            try:
                exts = self.file_service.get_supported_extensions(folder)
            except Exception:
                pass

        files_data = {}
        hash_list = []

        try:
            for p in sorted(folder.rglob("*")):
                if not p.is_file():
                    continue
                # Пропускаем скрытые файлы и папки (.git, .asleep, __pycache__ и т.д.)
                parts = p.relative_to(folder).parts
                if any(part.startswith(".") for part in parts) or "_Граф связей.md" in parts:
                    continue
                if p.suffix.lower() not in exts:
                    continue

                rel_str = str(p.relative_to(folder)).replace("\\", "/")
                try:
                    text = p.read_text(encoding="utf-8", errors="replace")
                    file_hash = hashlib.sha256(text.encode("utf-8")).hexdigest()
                    files_data[rel_str] = text
                    hash_list.append(f"{rel_str}:{file_hash}")
                except Exception:
                    continue
        except Exception:
            pass

        collective_fingerprint = hashlib.sha256(";".join(hash_list).encode("utf-8")).hexdigest() if hash_list else ""
        return files_data, collective_fingerprint

    def create_snapshot(self, folder: Path, trigger: str = "save", description: str = "",
                        graph_data: dict | None = None, force: bool = False,
                        custom_timestamp: float | None = None,
                        custom_created_at: str | None = None) -> dict | None:
        """
        Создает снимок состояния проекта (файлы + граф).
        Если файлы и граф не изменились с момента последнего снимка — дубликат не создается.
        """
        if not folder or not folder.exists() or not folder.is_dir():
            return None

        folder_key = str(folder.resolve())
        files_data, fingerprint = self._compute_folder_files_state(folder)

        # Проверка дедупликации: если изменений нет и не форсировано — выходим
        if not force and fingerprint and self._last_fingerprints.get(folder_key) == fingerprint:
            return None

        # Сбор графа связей, если не передан явно
        if graph_data is None and self.graph_service:
            try:
                self.graph_service.invalidate_cache(folder)
                graph_data = self.graph_service.build_graph(folder)
            except Exception:
                graph_data = {"nodes": [], "links": []}
        elif graph_data is None:
            graph_data = {"nodes": [], "links": []}

        nodes = graph_data.get("nodes", [])
        links = graph_data.get("links", [])
        nodes_count = len(nodes)
        links_count = len(links)
        files_count = len(files_data)

        if not description:
            if trigger == "session_start":
                description = f"Начало сессии • {files_count} заметок"
            elif trigger == "session_end":
                description = f"Завершение сессии • {files_count} заметок"
            else:
                description = f"Сохранение • {files_count} заметок, {links_count} связей"

        now = custom_timestamp if custom_timestamp is not None else time.time()
        created_at_str = custom_created_at if custom_created_at is not None else datetime.fromtimestamp(now).strftime("%d.%m.%Y, %H:%M")

        graph_blob = zlib.compress(json.dumps(graph_data).encode("utf-8"), level=6)

        conn = None
        try:
            conn = self._connect_db(folder)
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO snapshots (
                    timestamp, created_at, trigger, timeline_type, description,
                    files_count, nodes_count, links_count, fingerprint, graph_data_blob
                ) VALUES (?, ?, ?, 'work', ?, ?, ?, ?, ?, ?)
            """, (now, created_at_str, trigger, description, files_count, nodes_count, links_count, fingerprint, graph_blob))

            snapshot_id = cursor.lastrowid

            # Сохранение снимков каждого файла со сжатием
            for rel_path, content in files_data.items():
                content_bytes = content.encode("utf-8")
                content_hash = hashlib.sha256(content_bytes).hexdigest()
                content_compressed = zlib.compress(content_bytes, level=6)
                file_name = Path(rel_path).name

                cursor.execute("""
                    INSERT INTO file_snapshots (
                        snapshot_id, file_path, file_name, content_hash, content_blob
                    ) VALUES (?, ?, ?, ?, ?)
                """, (snapshot_id, rel_path, file_name, content_hash, content_compressed))

            conn.commit()

            self._last_fingerprints[folder_key] = fingerprint
            return {
                "id": snapshot_id,
                "timestamp": now,
                "createdAt": created_at_str,
                "trigger": trigger,
                "timelineType": "work",
                "description": description,
                "filesCount": files_count,
                "nodesCount": nodes_count,
                "linksCount": links_count
            }
        except Exception as e:
            print(f"[HistoryService] Ошибка сохранения снимка: {e}")
            return None
        finally:
            if conn:
                try:
                    conn.close()
                except Exception:
                    pass

    def get_timeline(self, folder: Path, timeline_type: str = "work") -> list[dict]:
        """Возвращает хронологический список всех сохраненных снимков проекта"""
        if not folder or not folder.exists() or not folder.is_dir():
            return []

        db_path = self._get_db_path(folder)
        if not db_path.exists():
            return []

        conn = None
        try:
            conn = self._connect_db(folder)
            cursor = conn.cursor()
            cursor.execute("""
                SELECT id, timestamp, created_at, trigger, timeline_type, description,
                       files_count, nodes_count, links_count
                FROM snapshots
                WHERE timeline_type = ?
                ORDER BY timestamp ASC
            """, (timeline_type,))
            rows = cursor.fetchall()
            return [{
                "id": r[0],
                "timestamp": r[1],
                "createdAt": r[2],
                "trigger": r[3],
                "timelineType": r[4],
                "description": r[5] or "",
                "filesCount": r[6] or 0,
                "nodesCount": r[7] or 0,
                "linksCount": r[8] or 0
            } for r in rows]
        except Exception as e:
            print(f"[HistoryService] Ошибка получения таймлайна: {e}")
            return []
        finally:
            if conn:
                try:
                    conn.close()
                except Exception:
                    pass

    def get_file_timeline(self, folder: Path, file_path: str) -> list[dict]:
        """Возвращает хронологический список снимков, в которых изменялся указанный файл"""
        if not folder or not folder.exists() or not folder.is_dir() or not file_path:
            return []

        db_path = self._get_db_path(folder)
        if not db_path.exists():
            return []

        try:
            p = Path(file_path)
            if p.is_absolute():
                try:
                    rel_str = str(p.relative_to(folder)).replace("\\", "/")
                except ValueError:
                    rel_str = p.name
            else:
                rel_str = str(p).replace("\\", "/")
        except Exception:
            rel_str = str(file_path).replace("\\", "/")

        file_name = Path(rel_str).name
        name_with_md = file_name if file_name.lower().endswith(".md") else f"{file_name}.md"
        name_no_md = file_name[:-3] if file_name.lower().endswith(".md") else file_name
        rel_with_md = rel_str if rel_str.lower().endswith(".md") else f"{rel_str}.md"
        rel_no_md = rel_str[:-3] if rel_str.lower().endswith(".md") else rel_str

        conn = None
        try:
            conn = self._connect_db(folder)
            cursor = conn.cursor()
            cursor.execute("""
                SELECT s.id, s.timestamp, s.created_at, s.trigger, s.timeline_type, s.description,
                       fs.content_hash, LENGTH(fs.content_blob)
                FROM file_snapshots fs
                JOIN snapshots s ON s.id = fs.snapshot_id
                WHERE fs.file_path IN (?, ?, ?, ?) OR fs.file_name IN (?, ?, ?, ?)
                ORDER BY s.timestamp ASC
            """, (rel_with_md, rel_no_md, rel_str, file_name,
                  name_with_md, name_no_md, rel_str, file_name))
            rows = cursor.fetchall()

            result = []
            prev_hash = None
            for r in rows:
                snap_id, ts, created_at, trigger, t_type, desc, c_hash, blob_len = r
                if c_hash != prev_hash:
                    result.append({
                        "id": snap_id,
                        "timestamp": ts,
                        "createdAt": created_at,
                        "trigger": trigger,
                        "timelineType": t_type,
                        "description": desc or f"Правка {file_name}",
                        "contentHash": c_hash,
                        "fileSize": blob_len or 0
                    })
                    prev_hash = c_hash
            return result
        except Exception as e:
            print(f"[HistoryService] Ошибка получения таймлайна файла: {e}")
            return []
        finally:
            if conn:
                try:
                    conn.close()
                except Exception:
                    pass

    def get_snapshot_graph(self, folder: Path, snapshot_id: int) -> dict:
        """Возвращает распакованный граф (nodes, links) для указанного снимка"""
        if not folder or not folder.exists() or not folder.is_dir():
            return {}

        db_path = self._get_db_path(folder)
        if not db_path.exists():
            return {}

        conn = None
        try:
            conn = self._connect_db(folder)
            cursor = conn.cursor()
            cursor.execute("SELECT graph_data_blob FROM snapshots WHERE id = ?", (snapshot_id,))
            row = cursor.fetchone()
            if row and row[0]:
                decompressed = zlib.decompress(row[0]).decode("utf-8")
                return json.loads(decompressed)
        except Exception as e:
            print(f"[HistoryService] Ошибка распаковки графа снимка {snapshot_id}: {e}")
        finally:
            if conn:
                try:
                    conn.close()
                except Exception:
                    pass
        return {}

    def get_snapshot_file_content(self, folder: Path, snapshot_id: int, file_path: str) -> str:
        """Возвращает распакованный текст файла на момент снимка"""
        if not folder or not folder.exists():
            return ""

        norm_path = file_path.replace("\\", "/").strip()
        p = Path(norm_path)
        name_with_md = p.name if p.name.lower().endswith(".md") else f"{p.name}.md"
        name_no_md = p.name[:-3] if p.name.lower().endswith(".md") else p.name
        rel_with_md = norm_path if norm_path.lower().endswith(".md") else f"{norm_path}.md"
        rel_no_md = norm_path[:-3] if norm_path.lower().endswith(".md") else norm_path

        conn = None

        try:
            conn = self._connect_db(folder)
            cursor = conn.cursor()
            cursor.execute("""
                SELECT content_blob FROM file_snapshots
                WHERE snapshot_id = ? AND (
                    file_path IN (?, ?, ?, ?) OR file_name IN (?, ?, ?, ?)
                )
            """, (snapshot_id, rel_with_md, rel_no_md, norm_path, p.name,
                  name_with_md, name_no_md, norm_path, p.name))
            row = cursor.fetchone()
            if row and row[0]:
                return zlib.decompress(row[0]).decode("utf-8")
        except Exception as e:
            print(f"[HistoryService] Ошибка чтения содержимого файла из снимка: {e}")
        finally:
            if conn:
                try:
                    conn.close()
                except Exception:
                    pass
        return ""

