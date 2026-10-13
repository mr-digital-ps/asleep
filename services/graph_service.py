import copy
import json
import re
from pathlib import Path
from PyQt6.QtCore import QUrl
from services.storage.config_service import parse_json_with_comments, compile_safe_regex, ConfigService
from services.content.document_outline import parse_user_dialect

DEFAULT_WIKILINK_REGEX = re.compile(r'\[\[([^\]|#]+)(?:#[^\]|]+)?(?:\|[^\]]+)?\]\]')
DEFAULT_TXT_LINK_REGEX = re.compile(r'\[([^\]]+)\]\(([^)]+\.txt)\)', re.IGNORECASE)
DEFAULT_TAG_REGEX = re.compile(r'(?<!\S)#([a-zA-Zа-яА-ЯёЁ0-9_\-]+)(?!\S)')
DEFAULT_H1_REGEX = re.compile(r'^#\s+([^\n\r]+)', re.MULTILINE)

WIKILINK_REGEX = DEFAULT_WIKILINK_REGEX
TXT_LINK_REGEX = DEFAULT_TXT_LINK_REGEX
TAG_REGEX = DEFAULT_TAG_REGEX
H1_REGEX = DEFAULT_H1_REGEX

def load_default_graph_config(project_root: Path | None = None) -> dict:
    """Динамически загружает эталонные дефолты из config/default/graph.json."""
    if project_root is None:
        this_p = Path(__file__).resolve()
        if (this_p.parent.parent / "config").exists():
            project_root = this_p.parent.parent
        else:
            project_root = this_p.parent.parent.parent
    f = project_root / "config" / "default" / "graph.json"
    if f.exists():
        try:
            data = parse_json_with_comments(f.read_text(encoding="utf-8"))
            if isinstance(data, dict):
                return data
        except Exception as e:
            print(f"[GraphService] Ошибка чтения {f.name}: {e}")
    return {"physics": {}, "visual": {}}

DEFAULT_GRAPH_CONFIG = load_default_graph_config()

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
    def __init__(self, block_engine=None, file_service=None, config_service=None):
        self.block_engine = block_engine
        self.file_service = file_service
        self.config_service = config_service
        this_p = Path(__file__).resolve()
        if (this_p.parent.parent / "config").exists():
            self.project_root = this_p.parent.parent
        else:
            self.project_root = this_p.parent.parent.parent
        self._graph_cache = {}
        self._config_cache = {}
        self._node_positions = {}

    def get_syntax_rules(self, folder_path: Path | None = None) -> dict:
        """Загружает правила разбора синтаксиса с защитой от сломанных regex пользователя"""
        cs = self.config_service or ConfigService()
        cfg = cs.get_syntax_config(folder_path) or {}

        wl_cfg = cfg.get("wikilinks", {})
        wl_regex = compile_safe_regex(wl_cfg.get("pattern"), DEFAULT_WIKILINK_REGEX)
        txt_regex = compile_safe_regex(wl_cfg.get("link_pattern") or wl_cfg.get("txt_link_pattern"), DEFAULT_TXT_LINK_REGEX, re.IGNORECASE)

        tag_cfg = cfg.get("tags", {})
        tag_regex = compile_safe_regex(tag_cfg.get("pattern"), DEFAULT_TAG_REGEX)
        try:
            tag_min = max(1, int(tag_cfg.get("min_occurrences_for_graph", 2)))
        except (ValueError, TypeError):
            tag_min = 2

        blk_cfg = cfg.get("blocks", {})
        h_lvl = blk_cfg.get("graph_transclusion_level", 1)
        if h_lvl == 1:
            h_regex = compile_safe_regex(blk_cfg.get("heading_h1_pattern"), DEFAULT_H1_REGEX, re.MULTILINE)
        else:
            dyn_pat = rf'^(#{{{h_lvl}}})\s+([^\n\r]+)'
            h_regex = compile_safe_regex(dyn_pat, DEFAULT_H1_REGEX, re.MULTILINE)
        try:
            blk_min = max(1, int(blk_cfg.get("min_occurrences_for_graph", 2)))
        except (ValueError, TypeError):
            blk_min = 2

        sys_cfg = cfg.get("system_files", {})
        ignore_prefixes = sys_cfg.get("ignore_prefixes", ["_", "."])
        if not isinstance(ignore_prefixes, (list, tuple)):
            ignore_prefixes = ["_", "."]

        return {
            "wikilink_regex": wl_regex,
            "txt_link_regex": txt_regex,
            "tag_regex": tag_regex,
            "tag_min": tag_min,
            "h_regex": h_regex,
            "block_min": blk_min,
            "ignore_prefixes": tuple(ignore_prefixes)
        }

    def _get_folder_key(self, folder_path: Path | str | None) -> str:
        if not folder_path:
            return "global"
        try:
            p = Path(folder_path) if isinstance(folder_path, str) else folder_path
            s = str(p).strip()
            if not s or s == ".":
                return "global"
            return str(p.resolve())
        except Exception:
            return "global"

    def save_node_positions(self, folder_path: Path | str | None, positions: dict):
        """Сохраняет фиксированные физические координаты узлов графа"""
        if not isinstance(positions, dict):
            return
        folder_key = self._get_folder_key(folder_path)
        if folder_key not in self._node_positions:
            self._node_positions[folder_key] = {}
        for nid, pos in positions.items():
            if isinstance(pos, dict) and "x" in pos and "y" in pos:
                try:
                    self._node_positions[folder_key][str(nid)] = {
                        "x": float(pos["x"]),
                        "y": float(pos["y"])
                    }
                except (ValueError, TypeError):
                    pass

        # Синхронизируем обновленные координаты в закешированном графе
        if folder_key in self._graph_cache and isinstance(self._graph_cache[folder_key], dict):
            for n in self._graph_cache[folder_key].get("nodes", []):
                nid = n.get("id")
                if nid in self._node_positions[folder_key]:
                    n["x"] = self._node_positions[folder_key][nid]["x"]
                    n["y"] = self._node_positions[folder_key][nid]["y"]

        # Сохраняем на диск в .asleep/graph_positions.json для персистентности между перезапусками
        try:
            p = Path(folder_path) if isinstance(folder_path, str) else folder_path
            if p and p.exists() and p.is_dir():
                asleep_dir = p / ".asleep"
                asleep_dir.mkdir(parents=True, exist_ok=True)
                f_pos = asleep_dir / "graph_positions.json"
                f_pos.write_text(json.dumps(self._node_positions[folder_key], ensure_ascii=False, indent=2), encoding="utf-8")
        except Exception:
            pass

    def get_node_positions(self, folder_path: Path | str | None) -> dict:
        """Возвращает сохраненные координаты узлов для папки (из памяти или с диска)"""
        folder_key = self._get_folder_key(folder_path)
        if folder_key not in self._node_positions or not self._node_positions[folder_key]:
            try:
                p = Path(folder_path) if isinstance(folder_path, str) else folder_path
                if p and p.exists() and p.is_dir():
                    f_pos = p / ".asleep" / "graph_positions.json"
                    if not f_pos.exists():
                        f_pos = p / "_graph_positions.json"
                    if f_pos.exists():
                        data = json.loads(f_pos.read_text(encoding="utf-8"))
                        if isinstance(data, dict):
                            self._node_positions[folder_key] = data
            except Exception:
                pass
        return copy.deepcopy(self._node_positions.get(folder_key, {}))

    def invalidate_cache(self, folder_path: Path | None = None):
        """Инвалидирует кеш графа для указанной папки или всего сервиса"""
        if folder_path:
            k = str(folder_path.resolve())
            self._graph_cache.pop(k, None)
            self._config_cache.pop(k, None)
        else:
            self._graph_cache.clear()
            self._config_cache.clear()

    def get_config(self, folder_path: Path | None = None) -> dict:
        """
        Каскадная загрузка конфигурации графа:
        1. config/default/graph.json
        2. config/user/graph.json
        3. folder_path/_graph_settings.json
        """
        cfg = load_default_graph_config(self.project_root)

        user_file = self.project_root / "config" / "user" / "graph.json"
        if user_file.exists():
            try:
                data = parse_json_with_comments(user_file.read_text(encoding="utf-8"))
                if isinstance(data, dict):
                    cfg = _deep_merge(cfg, data)
            except Exception as e:
                print(f"[GraphService] Ошибка чтения {user_file.name}: {e}")

        # Локальные настройки текущего каталога заметок (если есть)
        if folder_path and folder_path.exists() and folder_path.is_dir():
            for v_name in ["_graph_settings.json", "graph_settings.json"]:
                vault_cfg = folder_path / v_name
                if vault_cfg.exists():
                    try:
                        data = parse_json_with_comments(vault_cfg.read_text(encoding="utf-8"))
                        if isinstance(data, dict):
                            cfg = _deep_merge(cfg, data)
                        break
                    except Exception as e:
                        print(f"[GraphService] Ошибка чтения {v_name}: {e}")

        return cfg

    def save_graph_visual_layers(self, layers: dict):
        """Сохраняет пользовательские фильтры слоев (B, T, L и их рёбра) в config/user/graph.json"""
        user_file = self.project_root / "config" / "user" / "graph.json"
        user_cfg = {}
        if user_file.exists():
            try:
                data = parse_json_with_comments(user_file.read_text(encoding="utf-8"))
                if isinstance(data, dict):
                    user_cfg = data
            except Exception:
                user_cfg = {}
        if "visual" not in user_cfg or not isinstance(user_cfg["visual"], dict):
            user_cfg["visual"] = {}
        user_cfg["visual"].update(layers)
        try:
            user_file.parent.mkdir(parents=True, exist_ok=True)
            user_file.write_text(json.dumps(user_cfg, ensure_ascii=False, indent=2), encoding="utf-8")
        except Exception as e:
            print(f"[GraphService] Ошибка сохранения {user_file.name}: {e}")

    def build_graph(self, folder_path: Path) -> dict:
        if not folder_path or not folder_path.exists() or not folder_path.is_dir():
            return {"nodes": [], "links": []}

        folder_key = str(folder_path.resolve())
        if folder_key in self._graph_cache:
            return copy.deepcopy(self._graph_cache[folder_key])

        nodes_map = {}
        links_set = set()

        files_data = {}  # norm_stem -> path
        file_blocks = {}  # norm_heading -> list of paths
        file_tags = {}  # tag -> list of paths

        # 1. Первый проход: собираем файлы и индексируем имена
        rules = self.get_syntax_rules(folder_path)
        ignore_prefixes = rules["ignore_prefixes"]
        wl_regex = rules["wikilink_regex"]
        txt_regex = rules["txt_link_regex"]
        h_regex = rules["h_regex"]
        tag_regex = rules["tag_regex"]
        block_min = rules["block_min"]
        tag_min = rules["tag_min"]

        supported_exts = self.file_service.get_supported_extensions(folder_path) if self.file_service else {".txt"}
        for p in folder_path.iterdir():
            if not p.is_file() or p.suffix.lower() not in supported_exts:
                continue
            if any(p.name.startswith(pre) for pre in ignore_prefixes):
                continue

            stem_norm = p.stem.strip().lower()
            file_url = QUrl.fromLocalFile(str(p.resolve())).toString()
            clean_name = p.stem.strip()
            # Полный путь от корня проекта (Папка/.../Файл без .txt)
            try:
                rel_path = p.relative_to(folder_path).with_suffix("").as_posix()
                full_label = f"{folder_path.name}/{rel_path}"
            except Exception:
                full_label = f"{folder_path.name}/{clean_name}"

            files_data[stem_norm] = {
                "path": p,
                "fileUrl": file_url,
                "name": full_label
            }

            nodes_map[file_url] = {
                "id": file_url,
                "label": full_label,
                "fileUrl": file_url,
                "type": "file",
                "color": "#383838",
                "val": 1
            }

        # 2. Второй проход: анализируем контент каждого файла через диалект
        all_blocks_defs = {}  # (file_norm, block_norm) -> {"id": block_node_id, "name": b["name"], "fileUrl": file_url}
        transclusion_calls = []  # (source_file_url, target_file_norm, target_block_norm)

        for stem_norm, f_info in files_data.items():
            p = f_info["path"]
            file_url = f_info["fileUrl"]

            try:
                content = p.read_text(encoding="utf-8", errors="replace")
            except Exception:
                continue

            # Разбор диалекта (блоки, трансклюзии, вики-ссылки)
            parsed = parse_user_dialect(content)

            # А. Вики-ссылки [[Имя заметки]] из диалекта
            for target_name in parsed["wikilinks"]:
                target_norm = target_name.strip().lower()
                if target_norm in files_data:
                    target_url = files_data[target_norm]["fileUrl"]
                    if target_url != file_url:
                        links_set.add((file_url, target_url, "link"))
                        nodes_map[file_url]["val"] += 1
                        nodes_map[target_url]["val"] += 1

            # Б. Ссылки [текст](файл.txt) как fallback
            for m in txt_regex.finditer(content):
                raw_target = m.group(2).strip()
                target_stem = Path(raw_target).stem.strip().lower()
                if target_stem in files_data:
                    target_url = files_data[target_stem]["fileUrl"]
                    if target_url != file_url:
                        links_set.add((file_url, target_url, "link"))
                        nodes_map[file_url]["val"] += 1
                        nodes_map[target_url]["val"] += 1

            # В. Определение именованных блоков файла: Имя { ... }
            for b in parsed["blocks"]:
                b_name = b["name"]
                b_norm = b["name_norm"]
                block_id = f"block:{stem_norm}:{b_norm}"
                all_blocks_defs[(stem_norm, b_norm)] = {
                    "id": block_id,
                    "name": b_name,
                    "fileUrl": file_url,
                    "stem_norm": stem_norm
                }

            # Г. Локальные вызовы Блок() в пределах этого файла
            for lc in parsed["local_calls"]:
                t_b_norm = lc["target_block"].strip().lower()
                transclusion_calls.append((file_url, stem_norm, t_b_norm))

            # Д. Внешние вызовы Файл.Блок()
            for ec in parsed["external_calls"]:
                t_f_norm = ec["target_file"].strip().lower()
                t_b_norm = ec["target_block"].strip().lower()
                transclusion_calls.append((file_url, t_f_norm, t_b_norm))

            # Е. Поиск тегов (#тег)
            for m in tag_regex.finditer(content):
                tag_name = m.group(1).strip()
                tag_norm = tag_name.lower()
                if tag_norm not in file_tags:
                    file_tags[tag_norm] = []
                if file_url not in file_tags[tag_norm]:
                    file_tags[tag_norm].append((file_url, tag_name))

        # 3. Добавляем блоки и связи трансклюзии (пунктирные)
        # Все именованные блоки файлов отображаются в графе как узлы-блоки (пентагоны), связанные со своим файлом
        for b_key, b_info in all_blocks_defs.items():
            b_id = b_info["id"]
            owner_url = b_info["fileUrl"]

            if b_id not in nodes_map:
                nodes_map[b_id] = {
                    "id": b_id,
                    "label": b_info["name"],
                    "fileUrl": owner_url,
                    "sourceFileUrl": owner_url,
                    "type": "block",
                    "color": "#424242",
                    "val": 2
                }
                # Структурная связь от файла-владельца к блоку
                links_set.add((owner_url, b_id, "block"))
                nodes_map[owner_url]["val"] += 1

        # Создаем направленные трансклюзии вызовов
        for src_url, t_f_norm, t_b_norm in transclusion_calls:
            b_key = (t_f_norm, t_b_norm)
            if b_key in all_blocks_defs:
                b_info = all_blocks_defs[b_key]
                b_id = b_info["id"]
                links_set.add((src_url, b_id, "transclusion"))
                nodes_map[src_url]["val"] += 1
                nodes_map[b_id]["val"] += 1
                nodes_map[b_id]["val"] += 1

        # 4. Добавляем теги, если они связывают хотя бы tag_min файлов (хабы)
        for tag_norm, occurrences in file_tags.items():
            if len(occurrences) >= tag_min:
                tag_id = f"tag:{tag_norm}"
                display_tag = occurrences[0][1]
                nodes_map[tag_id] = {
                    "id": tag_id,
                    "label": f"#{display_tag}",
                    "fileUrl": "",
                    "type": "tag",
                    "color": "#4c4c4c",
                    "val": len(occurrences)
                }
                for f_url, _ in occurrences:
                    links_set.add((f_url, tag_id, "tag"))
                    nodes_map[f_url]["val"] += 1

        # 5. Преобразуем в финальный список nodes и links
        nodes_list = list(nodes_map.values())
        saved_positions = self.get_node_positions(folder_path)
        if saved_positions:
            for n in nodes_list:
                nid = n.get("id")
                if nid in saved_positions:
                    n["x"] = saved_positions[nid]["x"]
                    n["y"] = saved_positions[nid]["y"]

        links_list = []
        for src, tgt, l_type in links_set:
            links_list.append({
                "source": src,
                "target": tgt,
                "type": l_type
            })

        result = {
            "nodes": nodes_list,
            "links": links_list
        }
        self._graph_cache[folder_key] = result
        return copy.deepcopy(result)

    def generate_graph_text(self, folder_path: Path, graph_data: dict | None = None) -> str:
        """
        Генерирует человекочитаемый документ со структурой всех связей папки.
        Каждая заметка представлена заголовком с вики-ссылкой [[Имя заметки]],
        а её ребра (соседние заметки, общие блоки, теги) — элементами списка.
        """
        if not folder_path or not folder_path.exists() or not folder_path.is_dir():
            return "# Граф связей\n\n> Папка не найдена.\n"

        if graph_data is None:
            graph_data = self.build_graph(folder_path)

        nodes = graph_data.get("nodes", [])
        links = graph_data.get("links", [])

        # Индексируем узлы по типам
        file_nodes = {n["id"]: n for n in nodes if n.get("type") == "file"}
        block_nodes = {n["id"]: n for n in nodes if n.get("type") == "block"}
        tag_nodes = {n["id"]: n for n in nodes if n.get("type") == "tag"}

        # connections: file_id -> set of (label_text, sort_order, sort_name)
        connections = {f_id: set() for f_id in file_nodes}

        for l in links:
            src = l["source"]
            tgt = l["target"]

            if src in file_nodes and tgt in file_nodes:
                connections[src].add((f"[[{file_nodes[tgt]['label']}]]", 0, file_nodes[tgt]['label']))
                connections[tgt].add((f"[[{file_nodes[src]['label']}]]", 0, file_nodes[src]['label']))
            elif src in file_nodes and tgt in block_nodes:
                connections[src].add((f"{block_nodes[tgt]['label']}", 1, block_nodes[tgt]['label']))
            elif tgt in file_nodes and src in block_nodes:
                connections[tgt].add((f"{block_nodes[src]['label']}", 1, block_nodes[src]['label']))
            elif src in file_nodes and tgt in tag_nodes:
                connections[src].add((f"{tag_nodes[tgt]['label']}", 2, tag_nodes[tgt]['label']))
            elif tgt in file_nodes and src in tag_nodes:
                connections[tgt].add((f"{tag_nodes[src]['label']}", 2, tag_nodes[src]['label']))

        lines = []

        if not file_nodes:
            return "# Граф связей\n_(В этой папке пока нет заметок)_\n"

        # Сортируем заметки по алфавиту
        sorted_files = sorted(file_nodes.values(), key=lambda x: x["label"].lower())

        for f_node in sorted_files:
            f_id = f_node["id"]
            f_label = f_node["label"]
            lines.append(f"# {f_label}")

            targets = connections.get(f_id, set())
            if targets:
                sorted_targets = sorted(targets, key=lambda x: (x[1], x[2].lower()))
                for label_text, _, _ in sorted_targets:
                    lines.append(label_text)

            lines.append("")

        return "\n".join(lines).strip() + "\n"

    def sync_graph_file(self, folder_path: Path, graph_data: dict | None = None) -> Path | None:
        """Служебные файлы проекции графа на диске отключены."""
        return None


