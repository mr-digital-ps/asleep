# services/metro_service.py — Сервис построения схемы метро сюжета (Metro Transit Map)
import copy
import re
from pathlib import Path
from PyQt6.QtCore import QUrl

from services.storage.config_service import ConfigService
from services.storage.file_service import FileService, list_project_notes
from services.content.document_outline import parse_user_dialect

DEFAULT_METRO_PALETTE = [
    "#525252",
    "#666666",
    "#737373",
    "#808080",
    "#8C8C8C",
    "#999999",
    "#A6A6A6",
    "#B3B3B3",
    "#404040",
    "#595959",
    "#4D4D4D",
    "#707070",
]

RE_CHAPTER_NUM = re.compile(r"^(\d+)(?:[.\s_-]|$)", re.UNICODE)


def _natural_note_sort_key(file_path: Path):
    """
    Естественный порядок сортировки заметок (1. Глава, 2. Сцена, Глава 10, Эпоха 1... Эпоха 10).
    Если имя начинается с цифры, сортируем по числу.
    """
    stem = file_path.stem
    m = RE_CHAPTER_NUM.match(stem)
    if m:
        try:
            return (0, int(m.group(1)), stem.lower())
        except ValueError:
            pass
    # Проверка "Глава X", "Эпоха X", "Этап X", "Stage X", "Chapter X", "Том X"
    m_ch = re.search(r"(?:глава|сцена|серия|эпоха|этап|stage|epoch|act|chapter|том|часть)\s*(\d+)", stem, re.IGNORECASE)
    if m_ch:
        try:
            return (1, int(m_ch.group(1)), stem.lower())
        except ValueError:
            pass
    return (2, 0, stem.lower())


class MetroService:
    """
    Сервис извлечения хронологии сюжета и построения топологии линий метро (Metro Map).
    Станции: главы, сцены (блоки верхнего уровня level 1).
    Ветки/линии: персонажи/фракции (вложенные блоки level 2 или вики-ссылки/теги).
    Пересадочные станции: сцены, где пересекаются 2+ персонажей.
    """

    def __init__(self, file_service: FileService | None = None, config_service: ConfigService | None = None):
        self.config_service = config_service or ConfigService()
        self.file_service = file_service or FileService(self.config_service)
        self.project_root = self.config_service.project_root

    def get_config(self, folder_path: Path | None = None) -> dict:
        """Загружает настройки metro.json (Layout, Visual, Palette) с учетом каскада"""
        cfg = self.config_service.load_category_config("metro", folder_path)
        if not cfg or not isinstance(cfg, dict):
            cfg = {}
        return cfg

    def _build_single_file_metro(self, target_file: Path, cfg: dict) -> dict:
        """
        Строит локальную схему метро для одного файла (заметки/эпохи) на основе топологического порядка (DAG):
        - Станции — блоки верхнего уровня внутри файла (сцены/главы).
        - Ветки (Tracks) — персонажи/актеры (@Актер, [[Вики]], #тег или вложенные блоки-актеры).
        - Координаты X станций определяются топологическим порядком (col):
          Если сцена делит персонажа с предыдущей сценой, она ОБЯЗАНА быть в следующей колонке (col_next > col_prev).
          Параллельные сцены без общих персонажей стоят в одной колонке.
        - Это гарантирует:
          1) Ни одна линия никогда не идет назад (to_x >= from_x + step_x).
          2) Ни одна линия не имеет резких вертикальных перепадов.
        """
        re_block = re.compile(r"^([a-zA-Zа-яА-ЯёЁ0-9_]+)\s*\{([^}]*)\}", re.MULTILINE)
        re_year = re.compile(r"^\s*(\d{4}(?:[-–]\d{4})?)(?:\s*//\s*(.*))?", re.MULTILINE)
        re_actors = re.compile(r"@([a-zA-Zа-яА-ЯёЁ0-9_]+)")
        re_wiki = re.compile(r"\[\[([^\]|]+)(?:\|[^\]]+)?\]\]")
        re_tags = re.compile(r"(?<!\w)#([a-zA-Zа-яА-ЯёЁ0-9_]+)")

        layout_cfg = cfg.get("layout", {})
        palette = cfg.get("palette", DEFAULT_METRO_PALETTE) or DEFAULT_METRO_PALETTE
        step_x = layout_cfg.get("stepX", 380)
        lane_step = layout_cfg.get("stepY", 48)
        margin_x = layout_cfg.get("margin", 260)
        top_margin = 120

        try:
            txt = target_file.read_text(encoding="utf-8")
        except Exception:
            txt = ""

        if not txt:
            return {
                "stations": [], "tracks": [], "segments": [], "groups": [], "stages": [],
                "bounds": {"min_x": 0, "max_x": 800, "min_y": 0, "max_y": 600, "width": 800, "height": 600}
            }

        target_file_url = QUrl.fromLocalFile(str(target_file.resolve())).toString()
        target_file_stem = target_file.stem

        lines_offsets = [0]
        for line_str in txt.splitlines(keepends=True):
            lines_offsets.append(lines_offsets[-1] + len(line_str))

        raw_stations = []
        station_counter = 0
        all_actors_order = []
        actor_set = set()

        parsed = parse_user_dialect(txt)
        l1_blocks = [b for b in parsed.get("blocks", []) if b.get("level", 1) == 1]

        extracted_blocks = []
        if l1_blocks:
            for b in l1_blocks:
                extracted_blocks.append({
                    "name": b["name"],
                    "body": b.get("content", ""),
                    "line_no": b.get("start_line", 1),
                    "children": b.get("children", [])
                })
        else:
            for m in re_block.finditer(txt):
                start_char = m.start()
                line_no = 1
                for idx_l, off in enumerate(lines_offsets):
                    if off > start_char:
                        line_no = max(1, idx_l)
                        break
                extracted_blocks.append({
                    "name": m.group(1).strip(),
                    "body": m.group(2),
                    "line_no": line_no,
                    "children": []
                })

        for eb in extracted_blocks:
            b_name = eb["name"]
            body = eb["body"]
            line_no = eb["line_no"]

            m_y = re_year.search(body)
            date_str = m_y.group(1).replace("–", "-").strip() if m_y else ""
            note = m_y.group(2).strip() if (m_y and m_y.group(2)) else ""
            year_num = 0
            if date_str:
                m_dig = re.search(r"\d{4}", date_str)
                if m_dig:
                    year_num = int(m_dig.group(0))

            actors = list(eb.get("children", []))
            for a in re_actors.findall(body):
                if a not in actors:
                    actors.append(a)
            if not actors:
                for a in re_wiki.findall(body):
                    if a not in actors:
                        actors.append(a)
            if not actors:
                raw_tags = re_tags.findall(body)
                for t in raw_tags:
                    if t.lower() not in ("история", "европа", "сцена", "глава", "note") and t not in actors:
                        actors.append(t)

            for a in actors:
                if a not in actor_set:
                    actor_set.add(a)
                    all_actors_order.append(a)

            body_lines = [l.strip() for l in body.splitlines() if l.strip()]
            clean_lines = [
                l for l in body_lines
                if not l.startswith("@") and not re_year.match(l) and not l.startswith("Ключевые")
                and not l.startswith("-") and not l.startswith("Интрига") and not l.startswith(">")
            ]
            summary = clean_lines[0] if clean_lines else ""

            st_tracks = actors if actors else [target_file_stem]
            st_id = f"st_{station_counter}"
            station_counter += 1

            raw_stations.append({
                "id": st_id,
                "title": b_name.replace("_", " "),
                "name": b_name,
                "file_url": target_file_url,
                "file_name": target_file.name,
                "file_path": str(target_file.resolve()),
                "block_name": b_name,
                "start_line": line_no,
                "tracks": st_tracks,
                "actors": actors,
                "is_interchange": len(st_tracks) > 1,
                "breadcrumbs": [target_file_stem],
                "date_str": date_str,
                "year": year_num,
                "note": note,
                "summary": summary
            })

        if not raw_stations:
            return {
                "stations": [], "tracks": [], "segments": [], "groups": [], "stages": [],
                "bounds": {"min_x": 0, "max_x": 800, "min_y": 0, "max_y": 600, "width": 800, "height": 600}
            }

        track_names = all_actors_order if all_actors_order else sorted(list(actor_set))
        if not track_names:
            track_names = [target_file_stem]

        tracks = []
        track_lane_map = {}
        for idx, t_name in enumerate(track_names):
            color = palette[idx % len(palette)]
            tracks.append({
                "id": t_name,
                "name": t_name,
                "title": t_name.replace("_", " "),
                "color": color,
                "lane": idx,
                "station_ids": []
            })
            track_lane_map[t_name] = idx

        # Топологический расчет колонок станций (DAG Layout)
        cols = {}
        for i, st in enumerate(raw_stations):
            shared_cols = []
            for prev_idx in range(i):
                prev_st = raw_stations[prev_idx]
                if any(t in prev_st["tracks"] for t in st["tracks"]):
                    shared_cols.append(cols[prev_idx])
            col = (max(shared_cols) + 1) if shared_cols else 0
            cols[i] = col
            st["col"] = col

        # Умный расчет координат X колонок с учетом входящих новых линий
        seen_tracks = set()
        cols_with_new_entries = set()
        for st in raw_stations:
            for t in st["tracks"]:
                if t not in seen_tracks:
                    seen_tracks.add(t)
                    if st["col"] > 0:
                        cols_with_new_entries.add(st["col"])

        max_c = max(cols.values()) if cols else 0
        col_x = {}
        cur_x = margin_x
        for c in range(max_c + 1):
            if c == 0:
                col_x[c] = margin_x
            else:
                entry_extra = 70 if c in cols_with_new_entries else 0
                cur_x += (step_x + entry_extra)
                col_x[c] = cur_x

        for st in raw_stations:
            st["x"] = col_x.get(st["col"], margin_x + st["col"] * step_x)

        col_groups = {}
        for st in raw_stations:
            c = st["col"]
            if c not in col_groups:
                col_groups[c] = []
            col_groups[c].append(st)

        # Барицентрическая укладка станций по Y (Barycentric Anti-Tangle Ordering)
        # Обрабатываем колонки строго слева направо для минимизации перекрестков
        sorted_cols = sorted(col_groups.keys())
        min_station_gap = 160
        placed_stations = {}

        for c in sorted_cols:
            st_list = col_groups[c]
            if c == 0:
                st_list.sort(key=lambda s: s.get("start_line", 0))
                for idx, st in enumerate(st_list):
                    st["y"] = top_margin + idx * min_station_gap
                    placed_stations[st["id"]] = st
            else:
                for st in st_list:
                    incoming_ys = []
                    for prev_id, prev_st in placed_stations.items():
                        if any(t in prev_st["tracks"] for t in st["tracks"]):
                            incoming_ys.append(prev_st["y"])
                    if incoming_ys:
                        st["target_y"] = sum(incoming_ys) / len(incoming_ys)
                    else:
                        st["target_y"] = top_margin + st_list.index(st) * min_station_gap

                # Сортируем станции по барицентру входящих веток (исключает перекрестки крест-накрест)
                st_list.sort(key=lambda s: s["target_y"])

                if len(st_list) == 1:
                    st_list[0]["y"] = st_list[0]["target_y"]
                    placed_stations[st_list[0]["id"]] = st_list[0]
                else:
                    total_span = (len(st_list) - 1) * min_station_gap
                    avg_target = sum(s["target_y"] for s in st_list) / len(st_list)
                    cluster_start = max(top_margin, avg_target - total_span / 2.0)
                    for idx, cur in enumerate(st_list):
                        if idx == 0:
                            cur["y"] = cluster_start
                        else:
                            cur["y"] = st_list[idx - 1]["y"] + min_station_gap
                        placed_stations[cur["id"]] = cur

        station_dict = {st["id"]: st for st in raw_stations}
        for st in raw_stations:
            for t_name in st["tracks"]:
                if t_name in track_lane_map:
                    tracks[track_lane_map[t_name]]["station_ids"].append(st["id"])

        # Собираем ветки, берущие начало на каждой станции
        starting_tracks_by_station = {}
        for tr in tracks:
            st_ids = tr["station_ids"]
            if not st_ids:
                continue
            st_ids.sort(key=lambda sid: station_dict[sid]["x"])
            first_sid = st_ids[0]
            if first_sid not in starting_tracks_by_station:
                starting_tracks_by_station[first_sid] = []
            starting_tracks_by_station[first_sid].append(tr)

        segments = []
        for first_sid, tr_list in starting_tracks_by_station.items():
            first_st = station_dict[first_sid]
            is_initial_col = (first_st.get("col", 0) == 0)
            n_start = len(tr_list)

            if is_initial_col:
                # На стартовых сценах (col == 0) нет входящего трафика: симметричный горизонтальный веер
                for sub_idx, tr in enumerate(tr_list):
                    offset_y = (sub_idx - (n_start - 1) / 2.0) * 18
                    lead_len = 50 + (sub_idx % 4) * 16
                    entry_x = first_st["x"] - lead_len
                    entry_y = first_st["y"] + offset_y

                    tr["badge_x"] = entry_x
                    tr["badge_y"] = entry_y
                    tr["badge_title"] = tr["title"]

                    segments.append({
                        "track_id": tr["id"],
                        "track_title": tr["title"],
                        "color": tr["color"],
                        "from_id": f"entry_{tr['id']}",
                        "to_id": first_st["id"],
                        "from_x": entry_x,
                        "from_y": entry_y,
                        "to_x": first_st["x"],
                        "to_y": first_st["y"],
                        "is_entry": True
                    })
            else:
                # На промежуточных сценах (col > 0): умный выбор между входом СВЕРХУ и СНИЗУ
                # 1. Если ветка дальше идет вверх (next_y < cur_y) -> входит снизу (плавный восходящий поток).
                # 2. Если ветка дальше идет вниз (next_y > cur_y) -> входит сверху (плавный нисходящий поток).
                # 3. Если идет прямо -> балансируем между сторонами для симметричного ромбовидного захода.
                col_stations = col_groups.get(first_st.get("col", 0), [first_st])
                st_idx = col_stations.index(first_st) if first_st in col_stations else 0
                n_col = len(col_stations)

                above_tracks = []
                below_tracks = []

                for tr in tr_list:
                    st_ids = tr["station_ids"]
                    future_delta = 0
                    if len(st_ids) > 1:
                        second_st = station_dict[st_ids[1]]
                        future_delta = second_st["y"] - first_st["y"]

                    if future_delta > 15:
                        above_tracks.append(tr)
                    elif future_delta < -15:
                        below_tracks.append(tr)
                    else:
                        # Почти прямо: балансируем верх/низ
                        if len(above_tracks) <= len(below_tracks):
                            if st_idx <= (n_col - 1) / 2.0:
                                above_tracks.append(tr)
                            else:
                                below_tracks.append(tr)
                        else:
                            below_tracks.append(tr)

                for idx, tr in enumerate(above_tracks):
                    entry_y = first_st["y"] - (36 + idx * 22)
                    entry_x = first_st["x"] - (55 + idx * 18)
                    tr["badge_x"] = entry_x
                    tr["badge_y"] = entry_y
                    tr["badge_title"] = tr["title"]
                    segments.append({
                        "track_id": tr["id"],
                        "track_title": tr["title"],
                        "color": tr["color"],
                        "from_id": f"entry_{tr['id']}",
                        "to_id": first_st["id"],
                        "from_x": entry_x,
                        "from_y": entry_y,
                        "to_x": first_st["x"],
                        "to_y": first_st["y"],
                        "is_entry": True
                    })

                for idx, tr in enumerate(below_tracks):
                    entry_y = first_st["y"] + (48 + idx * 22)
                    entry_x = first_st["x"] - (55 + idx * 18)
                    tr["badge_x"] = entry_x
                    tr["badge_y"] = entry_y
                    tr["badge_title"] = tr["title"]
                    segments.append({
                        "track_id": tr["id"],
                        "track_title": tr["title"],
                        "color": tr["color"],
                        "from_id": f"entry_{tr['id']}",
                        "to_id": first_st["id"],
                        "from_x": entry_x,
                        "from_y": entry_y,
                        "to_x": first_st["x"],
                        "to_y": first_st["y"],
                        "is_entry": True
                    })

        for tr in tracks:
            st_ids = tr["station_ids"]
            if not st_ids:
                continue
            for i in range(len(st_ids) - 1):
                from_st = station_dict[st_ids[i]]
                to_st = station_dict[st_ids[i + 1]]
                segments.append({
                    "track_id": tr["id"],
                    "track_title": tr["title"],
                    "color": tr["color"],
                    "from_id": from_st["id"],
                    "to_id": to_st["id"],
                    "from_x": from_st["x"],
                    "from_y": from_st["y"],
                    "to_x": to_st["x"],
                    "to_y": to_st["y"],
                    "is_entry": False
                })

        # Группы скобок отключены по запросу пользователя для максимальной чистоты схемы
        groups = []

        xs = [st["x"] for st in raw_stations]
        ys = [st["y"] for st in raw_stations]
        for tr in tracks:
            if "badge_x" in tr:
                xs.append(tr["badge_x"] - 100)
            if "badge_y" in tr:
                ys.append(tr["badge_y"])

        min_x = max(0, min(xs) - margin_x) if xs else 0
        max_x = max(xs) + margin_x + 80 if xs else 1200
        min_y = max(0, min(ys) - 60) if ys else 0
        max_y = max(ys) + 120 if ys else 800

        return {
            "stations": raw_stations,
            "tracks": tracks,
            "segments": segments,
            "groups": groups,
            "stages": [],
            "bounds": {
                "min_x": min_x,
                "max_x": max_x,
                "min_y": min_y,
                "max_y": max_y,
                "width": max_x - min_x,
                "height": max_y - min_y
            }
        }

    def build_metro(self, folder_path: Path | None = None, active_file: Path | str | None = None) -> dict:
        """
        Строит локальную схему метро сюжета для активного файла (заметки/эпохи).
        Принцип: «Один файл — одно метро».
        """
        folder = folder_path or self.project_root
        if isinstance(folder, str):
            folder = Path(folder)

        cfg = self.get_config(folder if folder and folder.is_dir() else self.project_root)

        project_files = list_project_notes(folder, config_service=self.config_service) if (folder and folder.is_dir()) else []
        project_files.sort(key=_natural_note_sort_key)

        target_file = None
        if active_file:
            if isinstance(active_file, str):
                if active_file.startswith("file://"):
                    target_file = Path(QUrl(active_file).toLocalFile())
                else:
                    target_file = Path(active_file)
            else:
                target_file = active_file
            if not target_file or not target_file.exists() or not target_file.is_file():
                target_file = None

        if not target_file and project_files:
            target_file = project_files[0]

        if not target_file or not target_file.exists() or not target_file.is_file():
            return {
                "stations": [], "tracks": [], "segments": [], "groups": [], "stages": [],
                "bounds": {"min_x": 0, "max_x": 800, "min_y": 0, "max_y": 600, "width": 800, "height": 600}
            }

        return self._build_single_file_metro(target_file, cfg)


    def get_story_timeline(self, folder_path: Path | None = None, active_file: Path | str | None = None) -> dict:
        """
        Извлекает хронологическую последовательность станций (блоков) для таймлайна в хедере:
        - Сканирует все заметки папки в естественном порядке
        - Извлекает блоки Имя { ... }, годы/даты, участников @актеров и аннотации
        - Возвращает структурированный словарь с массивом станций, min_year и max_year
        """
        folder = folder_path
        if not folder and active_file:
            af_path = Path(QUrl(active_file).toLocalFile()) if isinstance(active_file, str) and active_file.startswith("file://") else Path(active_file)
            if af_path.exists():
                folder = af_path.parent if af_path.is_file() else af_path

        folder = folder or self.project_root
        if isinstance(folder, str):
            folder = Path(QUrl(folder).toLocalFile()) if folder.startswith("file://") else Path(folder)

        if not folder or not folder.exists() or not folder.is_dir():
            return {"stations": [], "min_year": 0, "max_year": 0, "total": 0}

        project_files = list_project_notes(folder, config_service=self.config_service)
        project_files.sort(key=_natural_note_sort_key)

        re_block = re.compile(r"^([a-zA-Zа-яА-ЯёЁ0-9_]+)\s*\{([^}]*)\}", re.MULTILINE)
        re_year = re.compile(r"^\s*(\d{4}(?:[-–]\d{4})?)(?:\s*//\s*(.*))?", re.MULTILINE)
        re_actors = re.compile(r"@[a-zA-Zа-яА-ЯёЁ0-9_]+")

        stations = []
        station_idx = 0
        all_years = []

        for f in project_files:
            try:
                text = f.read_text(encoding="utf-8")
            except Exception:
                continue

            file_url = QUrl.fromLocalFile(str(f.resolve())).toString()

            # Вычисление номеров строк для каждого совпадения
            lines_offsets = [0]
            for line_str in text.splitlines(keepends=True):
                lines_offsets.append(lines_offsets[-1] + len(line_str))

            for m in re_block.finditer(text):
                block_name = m.group(1).strip()
                body = m.group(2)
                start_char = m.start()
                
                # Приблизительный номер строки
                line_no = 1
                for idx_l, off in enumerate(lines_offsets):
                    if off > start_char:
                        line_no = max(1, idx_l)
                        break

                # Парсинг года и подписи
                m_y = re_year.search(body)
                date_str = m_y.group(1).replace("–", "-").strip() if m_y else ""
                note = m_y.group(2).strip() if (m_y and m_y.group(2)) else ""

                year_num = 0
                if date_str:
                    m_dig = re.search(r"\d{4}", date_str)
                    if m_dig:
                        year_num = int(m_dig.group(0))
                        all_years.append(year_num)

                # Парсинг участников @актеров
                actors = re_actors.findall(body)

                # Краткое описание (первые строки без служебных маркеров)
                body_lines = [l.strip() for l in body.splitlines() if l.strip()]
                clean_lines = [l for l in body_lines if not l.startswith("@") and not re_year.match(l) and not l.startswith("Ключевые") and not l.startswith("-") and not l.startswith("Интрига") and not l.startswith(">")]
                summary = clean_lines[0] if clean_lines else ""

                st_obj = {
                    "id": f"st_{station_idx}",
                    "index": station_idx,
                    "name": block_name,
                    "title": block_name.replace("_", " "),
                    "year": year_num,
                    "date_str": date_str if date_str else (str(year_num) if year_num else ""),
                    "note": note,
                    "actors": actors,
                    "summary": summary,
                    "file_url": file_url,
                    "file_name": f.name,
                    "block_name": block_name,
                    "line": line_no
                }
                stations.append(st_obj)
                station_idx += 1

        min_y = min(all_years) if all_years else 0
        max_y = max(all_years) if all_years else 0

        return {
            "stations": stations,
            "min_year": min_y,
            "max_year": max_y,
            "total": len(stations)
        }

