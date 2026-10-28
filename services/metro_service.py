# services/metro_service.py — Сервис построения схемы метро сюжета (Metro Transit Map)
import copy
import re
from pathlib import Path
from PyQt6.QtCore import QUrl

from services.storage.config_service import ConfigService
from services.storage.file_service import FileService, list_project_notes
from services.content.document_outline import parse_user_dialect

DEFAULT_METRO_PALETTE = [
    "#E5484D",  # Ruby / Османская империя
    "#3B82F6",  # Sapphire / Франция
    "#F59E0B",  # Imperial Gold / Габсбурги Империя
    "#10B981",  # Emerald / Венеция
    "#8B5CF6",  # Amethyst / Папский престол
    "#EC4899",  # Rose / Англия
    "#06B6D4",  # Cyan / Шотландия / Ирландия
    "#84CC16",  # Lime / Нидерланды / Бургундия
    "#F97316",  # Amber Orange / Кастилия и Арагон / Испания Габсбургов
    "#6366F1",  # Indigo / Италия Сфорца / Милан
    "#14B8A6",  # Teal / Флоренция Медичи
    "#D946EF",  # Magenta / Польша и Литва
    "#64748B",  # Slate / Тевтонский орден / Пруссия
    "#A855F7",  # Purple / Ливония
    "#E11D48",  # Crimson / Дания и Норвегия
    "#0EA5E9",  # Sky / Швеция
    "#F43F5E",  # Coral / Россия
    "#EAB308",  # Yellow / Венгрия
    "#22C55E",  # Green / Молдавия и Валахия
    "#A1A1AA",  # Zinc / Швейцарский союз
    "#78716C",  # Stone / Крым и казачество
    "#059669",  # Dark Emerald / Португалия
    "#D97706",  # Bronze / Богемия
    "#4F46E5",  # Deep Indigo / Генуя
    "#DC2626",  # Red / Персия
    "#475569"   # Steel / Развязки
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

    def _build_multi_stage_metro(self, folder: Path, project_files: list[Path], cfg: dict) -> dict | None:
        """
        Строит сквозную многоэтапную схему метро для проектов с несколькими заметками (например, эпохи 1453-1648):
        - Каждая заметка с блоками формирует этапную колонку (Stage Column) вдоль оси X.
        - Станции — блоки внутри заметок с годами и аннотациями.
        - Ветки (Tracks) — сквозные династические/сюжетные актеры (@Актер), непрерывно идущие через эпохи.
        - Станции с 2+ актерами являются пересадочными узлами (Interchange).
        """
        re_block = re.compile(r"^([a-zA-Zа-яА-ЯёЁ0-9_]+)\s*\{([^}]*)\}", re.MULTILINE)
        re_year = re.compile(r"^\s*(\d{4}(?:[-–]\d{4})?)(?:\s*//\s*(.*))?", re.MULTILINE)
        re_actors = re.compile(r"@([a-zA-Zа-яА-ЯёЁ0-9_]+)")

        stages = []
        for pf in project_files:
            try:
                txt = pf.read_text(encoding="utf-8")
                blks = list(re_block.finditer(txt))
                if blks:
                    stages.append((pf, txt, blks))
            except Exception:
                pass

        # Если файлов с блоками меньше двух, проект не является многоэтапным
        if len(stages) < 2:
            return None

        layout_cfg = cfg.get("layout", {})
        palette = cfg.get("palette", DEFAULT_METRO_PALETTE) or DEFAULT_METRO_PALETTE
        stage_step_x = layout_cfg.get("stageStepX", 420)
        lane_step = layout_cfg.get("stepY", 44)
        margin_x = 180
        top_margin = 120

        raw_stations = []
        station_counter = 0
        all_actors_order = []
        actor_set = set()

        for s_idx, (pf, txt, blks) in enumerate(stages):
            pf_url = QUrl.fromLocalFile(str(pf.resolve())).toString()
            stage_title = pf.stem
            m_stg = re.match(r"^(.*?)(?:\s*-\s*(.*))?$", pf.stem)
            short_stage_title = m_stg.group(1).strip() if m_stg else pf.stem

            lines_offsets = [0]
            for line_str in txt.splitlines(keepends=True):
                lines_offsets.append(lines_offsets[-1] + len(line_str))

            for m in blks:
                b_name = m.group(1).strip()
                body = m.group(2)
                start_char = m.start()

                line_no = 1
                for idx_l, off in enumerate(lines_offsets):
                    if off > start_char:
                        line_no = max(1, idx_l)
                        break

                m_y = re_year.search(body)
                date_str = m_y.group(1).replace("–", "-").strip() if m_y else ""
                note = m_y.group(2).strip() if (m_y and m_y.group(2)) else ""
                year_num = 0
                if date_str:
                    m_dig = re.search(r"\d{4}", date_str)
                    if m_dig:
                        year_num = int(m_dig.group(0))

                actors = re_actors.findall(body)
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

                st_tracks = actors if actors else [short_stage_title]
                st_id = f"st_{station_counter}"
                station_counter += 1

                raw_stations.append({
                    "id": st_id,
                    "title": b_name.replace("_", " "),
                    "name": b_name,
                    "file_url": pf_url,
                    "file_name": pf.name,
                    "file_path": str(pf.resolve()),
                    "block_name": b_name,
                    "start_line": line_no,
                    "tracks": st_tracks,
                    "actors": actors,
                    "is_interchange": len(st_tracks) > 1,
                    "stage_idx": s_idx,
                    "stage_title": short_stage_title,
                    "full_stage_title": stage_title,
                    "breadcrumbs": [short_stage_title],
                    "date_str": date_str,
                    "year": year_num,
                    "note": note,
                    "summary": summary
                })

        if not raw_stations:
            return None

        track_names = all_actors_order if all_actors_order else sorted(list(actor_set))
        if not track_names:
            track_names = [stg[0].stem for stg in stages]

        tracks = []
        track_lane_map = {}
        for idx, t_name in enumerate(track_names):
            color = palette[idx % len(palette)]
            t_title = t_name.replace("_", " ")
            tracks.append({
                "id": t_name,
                "title": t_title,
                "color": color,
                "lane": idx,
                "station_ids": []
            })
            track_lane_map[t_name] = idx

        # Расчет координат X и Y станций по этапам
        stage_stations_map = {}
        for st in raw_stations:
            stage_stations_map.setdefault(st["stage_idx"], []).append(st)

        for s_idx, s_stations in stage_stations_map.items():
            stage_left_x = margin_x + s_idx * stage_step_x

            # Извлекаем годы этапа для точного пропорционального позиционирования станций по стреле времени
            stage_years = [st["year"] for st in s_stations if st.get("year", 0) > 0]
            min_y = min(stage_years) if stage_years else 0
            max_y = max(stage_years) if stage_years else 0
            year_span = max(1, max_y - min_y)

            for st in s_stations:
                lanes = [track_lane_map[t] for t in st["tracks"] if t in track_lane_map]
                lane_avg = sum(lanes) / len(lanes) if lanes else s_idx
                st["lane"] = lane_avg
                st["target_y"] = top_margin + lane_avg * lane_step

            # Сортируем станции по году и целевой высоте
            s_stations.sort(key=lambda s: (s["year"] if s["year"] > 0 else 9999, s["target_y"]))

            # Распределение X пропорционально году события внутри эпохи
            avail_w = stage_step_x - 240
            for i, st in enumerate(s_stations):
                if year_span > 0 and st["year"] > 0:
                    y_prog = (st["year"] - min_y) / year_span
                    base_x = stage_left_x + 120 + y_prog * avail_w
                else:
                    base_x = stage_left_x + 120 + (i / max(1, len(s_stations) - 1)) * avail_w

                st["x"] = base_x
                st["col"] = s_idx

            # Разрешаем горизонтальные наложения для станций одного года
            for i in range(1, len(s_stations)):
                if abs(s_stations[i]["x"] - s_stations[i - 1]["x"]) < 50:
                    s_stations[i]["x"] = s_stations[i - 1]["x"] + 60

            # Разрешаем вертикальные наложения для станций на близких X
            s_stations.sort(key=lambda s: (s["x"], s["target_y"]))
            for i in range(len(s_stations)):
                st = s_stations[i]
                y_val = st["target_y"]
                for j in range(max(0, i - 4), i):
                    prev = s_stations[j]
                    if abs(st["x"] - prev["x"]) < 100 and abs(y_val - prev["y"]) < 52:
                        y_val = prev["y"] + 52
                st["y"] = y_val

        # Привязка станций к веткам
        station_dict = {st["id"]: st for st in raw_stations}
        for st in raw_stations:
            for t_name in st["tracks"]:
                if t_name in track_lane_map:
                    tracks[track_lane_map[t_name]]["station_ids"].append(st["id"])

        # Генерация сквозных соединительных сегментов линий метро
        segments = []
        for tr in tracks:
            st_ids = tr["station_ids"]
            if not st_ids:
                continue

            first_st = station_dict[st_ids[0]]
            last_st = station_dict[st_ids[-1]]
            lane_y = top_margin + tr["lane"] * lane_step

            entry_x = first_st["x"] - 75 - (tr["lane"] % 4) * 20
            tr["badge_x"] = entry_x - 16
            tr["badge_y"] = lane_y
            segments.append({
                "track_id": tr["id"],
                "track_title": tr["title"],
                "color": tr["color"],
                "from_id": f"entry_{tr['id']}",
                "to_id": first_st["id"],
                "from_x": entry_x,
                "from_y": lane_y,
                "to_x": first_st["x"],
                "to_y": first_st["y"],
                "is_entry": True
            })

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
                    "to_y": to_st["y"]
                })

            exit_x = last_st["x"] + 75 + (tr["lane"] % 4) * 20
            tr["exit_x"] = exit_x
            tr["exit_y"] = lane_y
            segments.append({
                "track_id": tr["id"],
                "track_title": tr["title"],
                "color": tr["color"],
                "from_id": last_st["id"],
                "to_id": f"exit_{tr['id']}",
                "from_x": last_st["x"],
                "from_y": last_st["y"],
                "to_x": exit_x,
                "to_y": lane_y,
                "is_exit": True
            })

        # Формирование верхних групп этапов (Stage Brackets) и этапов для топбара
        groups = []
        stages_out = []
        for s_idx, (pf, _, _) in enumerate(stages):
            from_x = margin_x + s_idx * stage_step_x + 30
            to_x = from_x + stage_step_x - 60
            center_x = (from_x + to_x) / 2
            stage_title = pf.stem
            groups.append({
                "id": f"stage_{s_idx}",
                "depth": 0,
                "title": stage_title,
                "from_x": from_x,
                "to_x": to_x,
                "y": 45,
                "station_count": len(stage_stations_map.get(s_idx, []))
            })
            stages_out.append({
                "index": s_idx,
                "title": stage_title,
                "short_title": f"Э{s_idx + 1}",
                "x": center_x,
                "station_count": len(stage_stations_map.get(s_idx, []))
            })

        xs = [st["x"] for st in raw_stations]
        ys = [st["y"] for st in raw_stations]
        for tr in tracks:
            if "badge_x" in tr:
                xs.append(tr["badge_x"] - 60)
            if "exit_x" in tr:
                xs.append(tr["exit_x"] + 40)
            if "badge_y" in tr:
                ys.append(tr["badge_y"])

        min_x = max(0, min(xs) - margin_x) if xs else 0
        max_x = max(xs) + margin_x + 100 if xs else 1200
        min_y = max(0, min(ys) - 60) if ys else 0
        max_y = max(ys) + 120 if ys else 800

        return {
            "stations": raw_stations,
            "tracks": tracks,
            "segments": segments,
            "groups": groups,
            "stages": stages_out,
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
        Строит схему метро сюжета:
        - Если в папке несколько файлов с блоками (например, Европа 1453-1648) — строит сквозную многоэтапную схему.
        - Если один файл — строит локальную схему по иерархии блоков (Том -> Акт -> Глава -> Сцена).
        """
        folder = folder_path or self.project_root
        if isinstance(folder, str):
            folder = Path(folder)
        if not folder or not folder.exists() or not folder.is_dir():
            return {
                "stations": [],
                "tracks": [],
                "segments": [],
                "groups": [],
                "stages": [],
                "bounds": {"min_x": 0, "max_x": 800, "min_y": 0, "max_y": 600, "width": 800, "height": 600}
            }

        cfg = self.get_config(folder)
        layout_cfg = cfg.get("layout", {})
        step_x = layout_cfg.get("stepX", 200)
        step_y = layout_cfg.get("stepY", 70)
        margin = layout_cfg.get("margin", 100)
        palette = cfg.get("palette", DEFAULT_METRO_PALETTE)
        if not palette:
            palette = DEFAULT_METRO_PALETTE

        project_files = list_project_notes(folder, config_service=self.config_service)
        project_files.sort(key=_natural_note_sort_key)

        # 1. Проверяем, является ли папка многоэтапным проектом
        multi_stage = self._build_multi_stage_metro(folder, project_files, cfg)
        if multi_stage:
            return multi_stage

        # 2. Разрешаем целевой файл для локальной схемы одного документа
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
                "stations": [],
                "tracks": [],
                "segments": [],
                "groups": [],
                "stages": [],
                "bounds": {"min_x": 0, "max_x": 800, "min_y": 0, "max_y": 600, "width": 800, "height": 600}
            }

        # Словарь известных сущностей/персонажей проекта по именам файлов
        known_notes = {f.stem.lower(): f.stem for f in project_files}

        # 2. Парсим блоки активного файла
        raw_stations = []
        track_names_set = set()
        station_counter = 0

        try:
            text = target_file.read_text(encoding="utf-8")
            parsed = parse_user_dialect(text)
            blocks = parsed.get("blocks", [])
        except Exception:
            blocks = []

        target_file_url = QUrl.fromLocalFile(str(target_file.resolve())).toString()
        target_file_stem = target_file.stem

        if blocks:
            children_map = {b["name"]: b.get("children", []) for b in blocks}
            parent_map = {b["name"]: b.get("parent_name", "") for b in blocks if b.get("parent_name")}

            for b in blocks:
                children = b.get("children", [])
                # Если блок является персонажем внутри родительского блока-сцены, он не отдельная станция, а участник сцены
                if b.get("parent_name") and b["name"].lower() in known_notes:
                    continue

                # Блок считается станцией, если у него нет детей, либо все его дети — персонажи
                is_character_container = bool(children) and all(ch.lower() in known_notes for ch in children)
                is_leaf = len(children) == 0

                if is_leaf or is_character_container:
                    b_content = b.get("content", "")

                    # Проверяем, не является ли блок списком вызовов внешних сцен (например, в файле персонажа: Сцены { Сюжет.Встреча() })
                    valid_ext_calls = []
                    for line_c in b_content.splitlines():
                        m_call = re.match(r'^\s*([a-zA-Zа-яА-ЯёЁ0-9_\-]+)\.([a-zA-Zа-яА-ЯёЁ0-9_\-\s]+)\(\)', line_c)
                        if m_call:
                            valid_ext_calls.append((m_call.group(1).strip(), m_call.group(2).strip()))

                    if len(valid_ext_calls) >= 1 and (b["name"].lower() in ("сцены", "хронология", "линия", "timeline", "scenes") or len(valid_ext_calls) >= 2):
                        for f_stem, scene_name in valid_ext_calls:
                            st_id = f"st_{station_counter}"
                            station_counter += 1
                            st_tracks = [target_file_stem]
                            track_names_set.add(target_file_stem)
                            raw_stations.append({
                                "id": st_id,
                                "title": scene_name,
                                "file_url": target_file_url,
                                "file_name": target_file.name,
                                "file_path": str(target_file.resolve()),
                                "block_name": scene_name,
                                "start_line": b.get("start_line", 1),
                                "tracks": st_tracks,
                                "is_interchange": False,
                                "breadcrumbs": [b["name"]],
                                "summary": f"{f_stem}.{scene_name}()"
                            })
                        continue

                    # Стандартный листовой блок сцены
                    st_id = f"st_{station_counter}"
                    station_counter += 1

                    # Хлебные крошки родителей произвольной глубины
                    crumbs = []
                    p = b.get("parent_name")
                    while p:
                        crumbs.append(p)
                        p = parent_map.get(p)
                    crumbs.reverse()

                    # В локальном метро ровно одна линия — сам текущий файл
                    st_tracks = [target_file_stem]
                    track_names_set.add(target_file_stem)

                    summary_lines = [l.strip() for l in b_content.splitlines() if l.strip() and not l.strip().endswith("{") and not l.strip().startswith("}")]
                    summary = summary_lines[0] if summary_lines else ""

                    raw_stations.append({
                        "id": st_id,
                        "title": b["name"],
                        "file_url": target_file_url,
                        "file_name": target_file.name,
                        "file_path": str(target_file.resolve()),
                        "block_name": b["name"],
                        "start_line": b.get("start_line", 1),
                        "tracks": st_tracks,
                        "is_interchange": len(st_tracks) > 1,
                        "breadcrumbs": crumbs,
                        "summary": summary
                    })
        elif project_files:
            # Если в файле вообще нет блоков: фоллбэк на список заметок
            for note_f in project_files:
                st_id = f"st_{station_counter}"
                station_counter += 1
                n_url = QUrl.fromLocalFile(str(note_f.resolve())).toString()
                raw_stations.append({
                    "id": st_id,
                    "title": note_f.stem,
                    "file_url": n_url,
                    "file_name": note_f.name,
                    "file_path": str(note_f.resolve()),
                    "block_name": "",
                    "start_line": 1,
                    "tracks": [note_f.stem],
                    "is_interchange": False,
                    "breadcrumbs": [],
                    "summary": ""
                })
                track_names_set.add(note_f.stem)

        if not raw_stations:
            return {
                "stations": [],
                "tracks": [],
                "segments": [],
                "groups": [],
                "bounds": {"min_x": 0, "max_x": 800, "min_y": 0, "max_y": 600, "width": 800, "height": 600}
            }

        # 3. Формируем упорядоченный список веток (Tracks)
        track_names = sorted(list(track_names_set))
        tracks = []
        track_lane_map = {}
        for idx, t_name in enumerate(track_names):
            color = palette[idx % len(palette)]
            t_obj = {
                "id": t_name,
                "title": t_name,
                "color": color,
                "lane": idx,
                "station_ids": []
            }
            tracks.append(t_obj)
            track_lane_map[t_name] = idx

        # Привязываем станции к линиям
        station_dict = {st["id"]: st for st in raw_stations}
        for st in raw_stations:
            for tr_name in st["tracks"]:
                for tr in tracks:
                    if tr["id"] == tr_name:
                        tr["station_ids"].append(st["id"])
                        break

        # 4. Расчет координат станций и группировка по иерархии хлебных крошек (Том -> Акт -> Глава)
        max_depth = max((len(st.get("breadcrumbs", [])) for st in raw_stations), default=0)
        group_header_height = 26
        base_top_offset = 35 + max_depth * group_header_height if max_depth > 0 else 0
        effective_margin_y = margin + base_top_offset

        for col_idx, st in enumerate(raw_stations):
            lanes = [track_lane_map[tr] for tr in st["tracks"] if tr in track_lane_map]
            if not lanes:
                lane_avg = 0
            else:
                lane_avg = sum(lanes) / len(lanes)

            st["col"] = col_idx
            st["lane"] = lane_avg
            st["x"] = margin + col_idx * step_x
            st["y"] = effective_margin_y + lane_avg * step_y

        # Извлечение групп (группирующих скобок) для каждого уровня глубины
        groups = []
        group_pad = min(50, step_x * 0.25)
        for d in range(max_depth):
            current_path = None
            current_stations = []

            for st in raw_stations:
                crumbs = st.get("breadcrumbs", [])
                st_path = tuple(crumbs[:d+1]) if len(crumbs) > d else None

                if st_path == current_path and current_path is not None:
                    current_stations.append(st)
                else:
                    if current_path is not None and current_stations:
                        title = current_stations[0]["breadcrumbs"][d]
                        from_x = current_stations[0]["x"] - group_pad
                        to_x = current_stations[-1]["x"] + group_pad
                        g_y = margin + 15 + d * group_header_height
                        groups.append({
                            "id": f"group_{d}_{len(groups)}",
                            "depth": d,
                            "title": title,
                            "from_x": from_x,
                            "to_x": to_x,
                            "y": g_y,
                            "station_count": len(current_stations)
                        })
                    current_path = st_path
                    current_stations = [st] if st_path is not None else []

            if current_path is not None and current_stations:
                title = current_stations[0]["breadcrumbs"][d]
                from_x = current_stations[0]["x"] - group_pad
                to_x = current_stations[-1]["x"] + group_pad
                g_y = margin + 15 + d * group_header_height
                groups.append({
                    "id": f"group_{d}_{len(groups)}",
                    "depth": d,
                    "title": title,
                    "from_x": from_x,
                    "to_x": to_x,
                    "y": g_y,
                    "station_count": len(current_stations)
                })

        # 5. Генерация соединительных сегментов линий метро (Segments)
        segments = []
        for tr in tracks:
            st_ids = tr["station_ids"]
            if not st_ids:
                continue

            lane_y = effective_margin_y + tr["lane"] * step_y
            first_st = station_dict.get(st_ids[0])
            last_st = station_dict.get(st_ids[-1])

            # 5a. Входная ветка: начинается раньше первой станции со смещением по X и Y
            if first_st:
                entry_x = first_st["x"] - 65 - (tr["lane"] % 3) * 20
                entry_y = lane_y
                tr["badge_x"] = entry_x - 16
                tr["badge_y"] = entry_y
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

            # 5b. Межстанционные сегменты
            for i in range(len(st_ids) - 1):
                from_st = station_dict.get(st_ids[i])
                to_st = station_dict.get(st_ids[i + 1])
                if not from_st or not to_st:
                    continue

                segments.append({
                    "track_id": tr["id"],
                    "track_title": tr["title"],
                    "color": tr["color"],
                    "from_id": from_st["id"],
                    "to_id": to_st["id"],
                    "from_x": from_st["x"],
                    "from_y": from_st["y"],
                    "to_x": to_st["x"],
                    "to_y": to_st["y"]
                })

            # 5c. Выходная ветка: выходит из последней станции и завершается тупиком
            if last_st:
                exit_x = last_st["x"] + 65 + (tr["lane"] % 3) * 20
                exit_y = lane_y
                tr["exit_x"] = exit_x
                tr["exit_y"] = exit_y
                segments.append({
                    "track_id": tr["id"],
                    "track_title": tr["title"],
                    "color": tr["color"],
                    "from_id": last_st["id"],
                    "to_id": f"exit_{tr['id']}",
                    "from_x": last_st["x"],
                    "from_y": last_st["y"],
                    "to_x": exit_x,
                    "to_y": exit_y,
                    "is_exit": True
                })

        # 6. Расчет габаритов схемы (bounds)
        xs = [st["x"] for st in raw_stations]
        ys = [st["y"] for st in raw_stations]
        for tr in tracks:
            if "badge_x" in tr:
                xs.append(tr["badge_x"] - 60)
            if "exit_x" in tr:
                xs.append(tr["exit_x"] + 30)
            if "badge_y" in tr:
                ys.append(tr["badge_y"])
        for g in groups:
            xs.append(g["from_x"])
            xs.append(g["to_x"])
            ys.append(g["y"] - 15)

        min_x = max(0, min(xs) - margin) if xs else 0
        max_x = max(xs) + margin + 150 if xs else 800
        min_y = max(0, min(ys) - margin) if ys else 0
        max_y = max(ys) + margin + 100 if ys else 600

        return {
            "stations": raw_stations,
            "tracks": tracks,
            "segments": segments,
            "groups": groups,
            "bounds": {
                "min_x": min_x,
                "max_x": max_x,
                "min_y": min_y,
                "max_y": max_y,
                "width": max_x - min_x,
                "height": max_y - min_y
            }
        }

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

