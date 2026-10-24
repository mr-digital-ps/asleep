# services/metro_service.py — Сервис построения схемы метро сюжета (Metro Transit Map)
import copy
import re
from pathlib import Path
from PyQt6.QtCore import QUrl

from services.storage.config_service import ConfigService
from services.storage.file_service import FileService, list_project_notes
from services.content.document_outline import parse_user_dialect

DEFAULT_METRO_PALETTE = [
    "#E5484D",  # Ruby
    "#3B82F6",  # Blue
    "#10B981",  # Emerald
    "#F59E0B",  # Amber
    "#8B5CF6",  # Violet
    "#EC4899",  # Pink
    "#06B6D4",  # Cyan
    "#84CC16",  # Lime
    "#F97316",  # Orange
    "#6366F1",  # Indigo
    "#14B8A6",  # Teal
    "#E11D48"   # Rose
]

RE_CHAPTER_NUM = re.compile(r"^(\d+)(?:[.\s_-]|$)", re.UNICODE)


def _natural_note_sort_key(file_path: Path):
    """
    Естественный порядок сортировки заметок (1. Глава, 2. Сцена, Глава 10).
    Если имя начинается с цифры, сортируем по числу.
    """
    stem = file_path.stem
    m = RE_CHAPTER_NUM.match(stem)
    if m:
        try:
            return (0, int(m.group(1)), stem.lower())
        except ValueError:
            pass
    # Проверка "Глава X" или "Chapter X"
    m_ch = re.search(r"(?:глава|сцена|серия|act|chapter)\s*(\d+)", stem, re.IGNORECASE)
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

    def build_metro(self, folder_path: Path | None = None) -> dict:
        """
        Сканирует заметки в папке и строит структуру схемы метро:
        {
            "stations": [...],
            "tracks": [...],
            "segments": [...],
            "bounds": {"min_x", "max_x", "min_y", "max_y", "width", "height"}
        }
        """
        folder = folder_path or self.project_root
        if not folder or not folder.exists() or not folder.is_dir():
            return {
                "stations": [],
                "tracks": [],
                "segments": [],
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

        # 1. Получаем заметки и сортируем в естественном порядке
        files = list_project_notes(folder, config_service=self.config_service)
        files.sort(key=_natural_note_sort_key)

        # Предварительный анализ: есть ли в папке файлы со сценами/блоками
        parsed_files = []
        has_any_blocks = False
        for f in files:
            try:
                text = f.read_text(encoding="utf-8")
                parsed = parse_user_dialect(text)
                l1 = [b for b in parsed.get("blocks", []) if b.get("level", 1) == 1]
                if l1:
                    has_any_blocks = True
                parsed_files.append((f, text, parsed, l1))
            except Exception:
                continue

        raw_stations = []
        track_names_set = set()
        station_counter = 0

        # 2. Извлекаем станции из файлов
        for f, text, parsed, level_1_blocks in parsed_files:
            file_url = QUrl.fromLocalFile(str(f.resolve())).toString()
            file_name = f.name
            file_stem = f.stem

            if level_1_blocks:
                # В файле есть именованные сцены/блоки верхнего уровня
                for b1 in level_1_blocks:
                    st_id = f"st_{station_counter}"
                    station_counter += 1
                    b1_name = b1["name"]
                    children = b1.get("children", [])

                    # Линии персонажей: вложенные блоки
                    st_tracks = list(children)

                    # Вики-ссылки внутри контента этого блока
                    b1_content = b1.get("content", "")
                    wikilinks_in_block = re.findall(r'\[\[([^\]|#]+)(?:#[^\]|]+)?(?:\|[^\]]+)?\]\]', b1_content)
                    for wl in wikilinks_in_block:
                        wl_clean = wl.strip()
                        if wl_clean and wl_clean not in st_tracks:
                            st_tracks.append(wl_clean)

                    # Теги внутри контента блока
                    tags_in_block = re.findall(r'(?<!\S)#([a-zA-Zа-яА-ЯёЁ0-9_\-]+)(?!\S)', b1_content)
                    for tg in tags_in_block:
                        tg_clean = tg.strip()
                        if tg_clean and tg_clean not in st_tracks:
                            st_tracks.append(tg_clean)

                    # Если персонажи не указаны, ветка по умолчанию — имя файла
                    if not st_tracks:
                        st_tracks = [file_stem]

                    for tr in st_tracks:
                        track_names_set.add(tr)

                    summary_lines = [l.strip() for l in b1_content.splitlines() if l.strip() and not l.strip().endswith("{") and not l.strip().startswith("}")]
                    summary = summary_lines[0] if summary_lines else ""

                    raw_stations.append({
                        "id": st_id,
                        "title": b1_name,
                        "file_url": file_url,
                        "file_name": file_name,
                        "file_path": str(f.resolve()),
                        "block_name": b1_name,
                        "start_line": b1.get("start_line", 1),
                        "tracks": st_tracks,
                        "is_interchange": len(st_tracks) > 1,
                        "summary": summary
                    })
            elif not has_any_blocks:
                # В папке вообще ни в одном файле нет блоков: каждый файл является станцией
                st_id = f"st_{station_counter}"
                station_counter += 1
                wikilinks = parsed.get("wikilinks", [])
                st_tracks = list(wikilinks)

                tags = re.findall(r'(?<!\S)#([a-zA-Zа-яА-ЯёЁ0-9_\-]+)(?!\S)', text)
                for tg in tags:
                    tg_clean = tg.strip()
                    if tg_clean and tg_clean not in st_tracks:
                        st_tracks.append(tg_clean)

                if not st_tracks:
                    st_tracks = [file_stem]

                for tr in st_tracks:
                    track_names_set.add(tr)

                summary_lines = [l.strip() for l in text.splitlines() if l.strip()]
                summary = summary_lines[0] if summary_lines else ""

                raw_stations.append({
                    "id": st_id,
                    "title": file_stem,
                    "file_url": file_url,
                    "file_name": file_name,
                    "file_path": str(f.resolve()),
                    "block_name": "",
                    "start_line": 1,
                    "tracks": st_tracks,
                    "is_interchange": len(st_tracks) > 1,
                    "summary": summary
                })

        if not raw_stations:
            return {
                "stations": [],
                "tracks": [],
                "segments": [],
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

        # 4. Расчет координат станций
        # По горизонтали: col = индекс станции по хронологии
        # По вертикали: y = среднее значение lane всех веток, проходящих через станцию
        for col_idx, st in enumerate(raw_stations):
            lanes = [track_lane_map[tr] for tr in st["tracks"] if tr in track_lane_map]
            if not lanes:
                lane_avg = 0
            else:
                lane_avg = sum(lanes) / len(lanes)

            st["col"] = col_idx
            st["lane"] = lane_avg
            st["x"] = margin + col_idx * step_x
            st["y"] = margin + lane_avg * step_y

        # 5. Генерация соединительных сегментов линий метро (Segments)
        segments = []
        for tr in tracks:
            st_ids = tr["station_ids"]
            if len(st_ids) < 2:
                continue
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

        # 6. Расчет габаритов схемы (bounds)
        xs = [st["x"] for st in raw_stations]
        ys = [st["y"] for st in raw_stations]
        min_x = max(0, min(xs) - margin) if xs else 0
        max_x = max(xs) + margin + 150 if xs else 800
        min_y = max(0, min(ys) - margin) if ys else 0
        max_y = max(ys) + margin + 100 if ys else 600

        return {
            "stations": raw_stations,
            "tracks": tracks,
            "segments": segments,
            "bounds": {
                "min_x": min_x,
                "max_x": max_x,
                "min_y": min_y,
                "max_y": max_y,
                "width": max_x - min_x,
                "height": max_y - min_y
            }
        }
