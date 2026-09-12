import json
import copy
import re
from pathlib import Path
from PyQt6.QtCore import QUrl

WIKILINK_REGEX = re.compile(r'\[\[([^\]|#]+)(?:#[^\]|]+)?(?:\|[^\]]+)?\]\]')
MD_LINK_REGEX = re.compile(r'\[([^\]]+)\]\(([^)]+\.(?:md|markdown|txt))\)', re.IGNORECASE)
TAG_REGEX = re.compile(r'(?<!\S)#([a-zA-Zа-яА-ЯёЁ0-9_\-]+)(?!\S)')
H1_REGEX = re.compile(r'^#\s+([^\n\r]+)', re.MULTILINE)

DEFAULT_GRAPH_CONFIG = {
    "physics": {
        "repulsion": 3600,
        "repulsionDistanceMax": 800,
        "linkDistance": 85,
        "linkStrength": 0.014,
        "plasticDeformation": 0.035,
        "plasticMaxDistance": 300,
        "plasticRecoveryRate": 0.0005,
        "gravity": 0.0005,
        "damping": 0.82,
        "maxVelocity": 15.0,
        "initialSpread": 0.35
    },
    "visual": {
        "nodeRadiusMin": 3.5,
        "nodeRadiusMax": 8.5,
        "nodeRadiusBase": 3.2,
        "nodeRadiusWeight": 1.3,
        "backgroundColor": "#141414",
        "nodeColorFile": "#4da6ff",
        "nodeColorBlock": "#bb9af7",
        "nodeColorTag": "#e0af68",
        "nodeHoverBrightness": 1.25,
        "linkColor": "#333333",
        "linkHoverColor": "#666666",
        "labelColor": "#888888",
        "labelHoverColor": "#e0e0e0",
        "labelFontSize": 10
    }
}

def _deep_merge(base: dict, override: dict) -> dict:
    result = copy.deepcopy(base)
    if not isinstance(override, dict):
        return result
    for k, v in override.items():
        if k in result and isinstance(result[k], dict) and isinstance(v, dict):
            result[k] = _deep_merge(result[k], v)
        else:
            result[k] = copy.deepcopy(v)
    return result

class GraphService:
    """
    Сервис сбора и построения интерактивного графа связей между заметками,
    включая вики-ссылки [[...]], общие H1-блоки, теги и настройки симуляции.
    """
    def __init__(self, block_engine=None, file_service=None):
        self.block_engine = block_engine
        self.file_service = file_service
        self.project_root = Path(__file__).resolve().parent.parent

    def get_config(self, folder_path: Path = None) -> dict:
        """
        Каскадная загрузка конфигурации графа:
        1. Встроенный дефолт (DEFAULT_GRAPH_CONFIG)
        2. Стандартный файл проекта (graph_default.json)
        3. Пользовательский файл проекта (graph_user.json)
        4. Локальный файл хранилища (_graph_settings.json)
        """
        cfg = copy.deepcopy(DEFAULT_GRAPH_CONFIG)

        # 1. Стандартный файл проекта
        default_file = self.project_root / "graph_default.json"
        if default_file.exists():
            try:
                data = json.loads(default_file.read_text(encoding="utf-8"))
                if isinstance(data, dict):
                    cfg = _deep_merge(cfg, data)
            except Exception as e:
                print(f"[GraphService] Ошибка чтения graph_default.json: {e}")

        # 2. Пользовательский файл проекта
        user_file = self.project_root / "graph_user.json"
        if user_file.exists():
            try:
                data = json.loads(user_file.read_text(encoding="utf-8"))
                if isinstance(data, dict):
                    cfg = _deep_merge(cfg, data)
            except Exception as e:
                print(f"[GraphService] Ошибка чтения graph_user.json: {e}")

        # 3. Локальные настройки текущего каталога заметок (если есть)
        if folder_path and folder_path.exists() and folder_path.is_dir():
            for v_name in ["_graph_settings.json", "graph_settings.json"]:
                vault_cfg = folder_path / v_name
                if vault_cfg.exists():
                    try:
                        data = json.loads(vault_cfg.read_text(encoding="utf-8"))
                        if isinstance(data, dict):
                            cfg = _deep_merge(cfg, data)
                        break
                    except Exception as e:
                        print(f"[GraphService] Ошибка чтения {v_name}: {e}")

        return cfg

    def build_graph(self, folder_path: Path) -> dict:
        if not folder_path or not folder_path.exists() or not folder_path.is_dir():
            return {"nodes": [], "links": []}

        nodes_map = {}
        links_set = set()

        files_data = {}  # norm_stem -> path
        file_blocks = {}  # norm_heading -> list of paths
        file_tags = {}  # tag -> list of paths

        # 1. Первый проход: собираем файлы и индексируем имена
        for p in folder_path.iterdir():
            if not p.is_file() or p.suffix.lower() not in [".md", ".markdown", ".txt"]:
                continue
            if p.name.startswith(".") or p.name.startswith("_"):
                continue

            stem_norm = p.stem.strip().lower()
            file_url = QUrl.fromLocalFile(str(p.resolve())).toString()
            clean_name = p.stem.strip()

            files_data[stem_norm] = {
                "path": p,
                "fileUrl": file_url,
                "name": clean_name
            }

            nodes_map[file_url] = {
                "id": file_url,
                "label": clean_name,
                "fileUrl": file_url,
                "type": "file",
                "color": "#4da6ff",
                "val": 1
            }

        # 2. Второй проход: анализируем контент каждого файла
        for stem_norm, f_info in files_data.items():
            p = f_info["path"]
            file_url = f_info["fileUrl"]

            try:
                content = p.read_text(encoding="utf-8", errors="replace")
            except Exception:
                continue

            # А. Поиск вики-ссылок [[Имя заметки]]
            for m in WIKILINK_REGEX.finditer(content):
                target_name = m.group(1).strip()
                target_norm = target_name.lower()
                if target_norm in files_data:
                    target_url = files_data[target_norm]["fileUrl"]
                    if target_url != file_url:
                        edge_key = tuple(sorted([file_url, target_url]))
                        links_set.add((file_url, target_url, "link"))
                        nodes_map[file_url]["val"] += 1
                        nodes_map[target_url]["val"] += 1

            # Б. Поиск стандартных Markdown ссылок [текст](файл.md)
            for m in MD_LINK_REGEX.finditer(content):
                raw_target = m.group(2).strip()
                target_stem = Path(raw_target).stem.strip().lower()
                if target_stem in files_data:
                    target_url = files_data[target_stem]["fileUrl"]
                    if target_url != file_url:
                        links_set.add((file_url, target_url, "link"))
                        nodes_map[file_url]["val"] += 1
                        nodes_map[target_url]["val"] += 1

            # В. Поиск H1-блоков (# Заголовок)
            for m in H1_REGEX.finditer(content):
                h_text = m.group(1).strip()
                h_norm = h_text.lower()
                if h_norm not in file_blocks:
                    file_blocks[h_norm] = []
                if file_url not in file_blocks[h_norm]:
                    file_blocks[h_norm].append((file_url, h_text))

            # Г. Поиск тегов (#тег)
            for m in TAG_REGEX.finditer(content):
                tag_name = m.group(1).strip()
                tag_norm = tag_name.lower()
                if tag_norm not in file_tags:
                    file_tags[tag_norm] = []
                if file_url not in file_tags[tag_norm]:
                    file_tags[tag_norm].append((file_url, tag_name))

        # 3. Добавляем связи по общим H1-блокам (трансклюзия)
        for h_norm, occurrences in file_blocks.items():
            if len(occurrences) > 1:
                # Если блок встречается в 2+ файлах, связываем эти файлы между собой
                block_id = f"block:{h_norm}"
                display_title = occurrences[0][1]
                nodes_map[block_id] = {
                    "id": block_id,
                    "label": f"#{display_title}",
                    "fileUrl": occurrences[0][0],
                    "type": "block",
                    "color": "#bb9af7",
                    "val": len(occurrences) + 1
                }
                for f_url, _ in occurrences:
                    links_set.add((f_url, block_id, "transclusion"))
                    nodes_map[f_url]["val"] += 1

        # 4. Добавляем теги, если они связывают хотя бы 2 файла
        for tag_norm, occurrences in file_tags.items():
            if len(occurrences) > 1:
                tag_id = f"tag:{tag_norm}"
                display_tag = occurrences[0][1]
                nodes_map[tag_id] = {
                    "id": tag_id,
                    "label": f"#{display_tag}",
                    "fileUrl": occurrences[0][0],
                    "type": "tag",
                    "color": "#e0af68",
                    "val": len(occurrences)
                }
                for f_url, _ in occurrences:
                    links_set.add((f_url, tag_id, "tag"))
                    nodes_map[f_url]["val"] += 1

        # 5. Преобразуем в финальный список nodes и links
        nodes_list = list(nodes_map.values())
        links_list = []
        for src, tgt, l_type in links_set:
            links_list.append({
                "source": src,
                "target": tgt,
                "type": l_type
            })

        return {
            "nodes": nodes_list,
            "links": links_list
        }
