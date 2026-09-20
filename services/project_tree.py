# services/project_tree.py — Парсинг и манипуляция структурой заметок проекта (_Структура.md)
import re
from pathlib import Path
from typing import Any


class ProjectTreeManager:
    """
    Отвечает за парсинг и манипуляцию файлом _Структура.md:
    древовидное представление проекта, перемещение веток, отступы и автоматическую синхронизацию.
    """

    def parse_project_tree(self, text: str) -> list[dict[str, Any]]:
        """
        Разбирает текстовую иерархию проекта из _Структура.md в древовидный список элементов.
        Строки с отступами (табы или пробелы) интерпретируются как дочерние элементы.
        """
        if not text:
            return []

        lines = text.splitlines()
        root_items: list[dict[str, Any]] = []
        stack: list[tuple[int, dict[str, Any]]] = []

        for line in lines:
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue

            indent_spaces = len(line) - len(line.lstrip(" "))
            indent_tabs = len(line) - len(line.lstrip("\t"))
            level = max(indent_tabs, indent_spaces // 4)

            content = stripped.lstrip("-* \t").strip()
            if not content:
                continue

            is_folder = content.startswith("📁") or content.endswith("/")
            clean_label = content.replace("📁", "").rstrip("/").strip()

            wiki_match = re.search(r'\[\[([^\]]+)\]\]', clean_label)
            if wiki_match:
                item_type = "file"
                label = wiki_match.group(1).strip()
            elif is_folder:
                item_type = "folder"
                label = clean_label
            else:
                item_type = "file"
                label = clean_label

            node = {
                "label": label,
                "type": item_type,
                "level": level,
                "children": []
            }

            while stack and stack[-1][0] >= level:
                stack.pop()

            if stack:
                stack[-1][1]["children"].append(node)
            else:
                root_items.append(node)

            stack.append((level, node))

        return root_items

    def parse_project_tree_flat(self, text: str) -> dict[str, Any]:
        """
        Разбирает текстовую структуру _Структура.md на плоский упорядоченный список элементов
        с уровнями вложенности и преамбулу (заголовок/описание файла).
        """
        if not text:
            return {"header": "", "items": []}

        lines = text.splitlines()
        header_lines: list[str] = []
        items: list[dict[str, Any]] = []
        in_header = True
        idx = 0

        # Шаг отступа пробелами (2 или 4)
        space_step = 4
        for l in lines:
            stripped_l = l.strip()
            if stripped_l.startswith(("-", "*")):
                sp = len(l) - len(l.lstrip(" "))
                if sp in (2, 6, 10):
                    space_step = 2
                    break

        current_subheading_level = 0
        current_folder_level = -1

        for line in lines:
            stripped = line.strip()
            is_list_item = stripped.startswith(("-", "*"))
            is_subheading = stripped.startswith("##")

            if in_header and not is_list_item and not is_subheading:
                header_lines.append(line)
                continue

            in_header = False

            if not stripped:
                continue

            if is_subheading:
                label = stripped.lstrip("#").strip()
                current_subheading_level = 1
                items.append({
                    "id": f"tree_node_{idx}",
                    "key": f"section:{label}",
                    "index": idx,
                    "level": 0,
                    "type": "section",
                    "label": label,
                })
                idx += 1
                continue

            if stripped.startswith("#"):
                current_subheading_level = 0
                continue

            if is_list_item:
                content = stripped.lstrip("-* \t").strip()
                if not content:
                    continue

                wiki_match = re.search(r'\[\[([^\]]+)\]\]', content)
                is_folder = content.startswith("📁") or content.endswith("/") or (not wiki_match and not content.endswith(".md"))
                clean_label = content.replace("📁", "").replace("📄", "").rstrip("/").strip()

                if wiki_match:
                    item_type = "file"
                    label = wiki_match.group(1).strip()
                elif is_folder:
                    item_type = "folder"
                    label = clean_label
                else:
                    item_type = "file"
                    label = clean_label

                indent_spaces = len(line) - len(line.lstrip(" "))
                indent_tabs = len(line) - len(line.lstrip("\t"))
                if indent_tabs > 0:
                    level = indent_tabs + current_subheading_level
                elif indent_spaces > 0:
                    level = max(1, indent_spaces // space_step) + current_subheading_level
                elif current_subheading_level > 0:
                    level = current_subheading_level
                else:
                    level = 0

                items.append({
                    "id": f"tree_node_{idx}",
                    "key": f"{item_type}:{label}" if label else f"node_{idx}",
                    "index": idx,
                    "level": level,
                    "type": item_type,
                    "label": label,
                })
                idx += 1

        # Вычисляем наличие дочерних элементов для каждого узла
        for i in range(len(items)):
            it_level = items[i].get("level", 0)
            items[i]["hasChildren"] = (i + 1 < len(items) and items[i + 1].get("level", 0) > it_level)

        return {
            "header": "\n".join(header_lines).strip(),
            "items": items
        }

    def project_tree_flat_to_markdown(self, header: str, items: list[dict[str, Any]]) -> str:
        """
        Преобразует заголовок и плоский список элементов обратно в чистый Markdown текст.
        """
        lines = []
        if header and header.strip():
            lines.append(header.strip())
            lines.append("")

        for it in items:
            level = max(0, it.get("level", 0))
            itype = it.get("type", "file")
            label = it.get("label", "").strip()
            if itype == "section":
                if lines and lines[-1] != "":
                    lines.append("")
                lines.append(f"## {label}")
            elif itype == "folder":
                indent = "    " * level
                lines.append(f"{indent}- 📁 {label}")
            else:
                indent = "    " * level
                lines.append(f"{indent}- [[{label}]]")

        return "\n".join(lines).strip() + ("\n" if lines else "")

    def get_project_tree_subtree(self, items: list[dict[str, Any]], start_index: int) -> list[int]:
        """
        Возвращает индексы узла и всех его дочерних элементов в плоском списке дерева.
        """
        if start_index < 0 or start_index >= len(items):
            return []
        indices = [start_index]
        base_level = items[start_index]["level"]

        for i in range(start_index + 1, len(items)):
            if items[i]["level"] > base_level:
                indices.append(i)
            else:
                break
        return indices

    def reorder_project_tree(self, text: str, source_index: int, target_index: int, position: str = "before") -> str:
        """
        Перемещает элемент дерева (вместе со всеми его дочерними узлами!)
        до или после target_index, автоматически адаптируя уровень вложенности.
        """
        parsed = self.parse_project_tree_flat(text)
        items = parsed["items"]
        header = parsed["header"]

        if not items or source_index < 0 or source_index >= len(items):
            return text
        if target_index < 0 or target_index >= len(items) or source_index == target_index:
            return text

        moving_indices = set(self.get_project_tree_subtree(items, source_index))
        if target_index in moving_indices:
            return text

        moving_items = [items[i] for i in sorted(moving_indices)]
        remaining_items = [items[i] for i in range(len(items)) if i not in moving_indices]

        target_id = items[target_index]["id"]
        target_item = items[target_index]
        new_target_idx = 0
        for idx, it in enumerate(remaining_items):
            if it["id"] == target_id:
                new_target_idx = idx
                break

        target_level = target_item.get("level", 0)
        target_type = target_item.get("type", "file")
        if target_type == "folder" and position == "after":
            new_base_level = target_level + 1
        else:
            new_base_level = target_level

        level_delta = new_base_level - moving_items[0].get("level", 0)
        if level_delta != 0:
            for it in moving_items:
                it["level"] = max(0, min(8, it.get("level", 0) + level_delta))

        insert_idx = new_target_idx if position == "before" else new_target_idx + 1
        result_items = remaining_items[:insert_idx] + moving_items + remaining_items[insert_idx:]

        return self.project_tree_flat_to_markdown(header, result_items)

    def change_project_tree_level(self, text: str, item_index: int, delta: int) -> str:
        """
        Изменяет уровень отступа элемента (и всех его вложенных элементов на ту же величину).
        """
        parsed = self.parse_project_tree_flat(text)
        items = parsed["items"]
        header = parsed["header"]

        if not items or item_index < 0 or item_index >= len(items):
            return text

        subtree_indices = self.get_project_tree_subtree(items, item_index)
        cur_level = items[item_index]["level"]
        new_level = max(0, min(8, cur_level + delta))
        actual_delta = new_level - cur_level

        if actual_delta == 0:
            return text

        for idx in subtree_indices:
            items[idx]["level"] = max(0, min(8, items[idx]["level"] + actual_delta))

        return self.project_tree_flat_to_markdown(header, items)

    def add_project_tree_item(self, text: str, label: str, item_type: str = "file", target_index: int = -1) -> str:
        """
        Добавляет новый элемент (папку или файл) в структуру проекта.
        """
        parsed = self.parse_project_tree_flat(text)
        items = parsed["items"]
        header = parsed["header"]

        clean_label = label.strip()
        if not clean_label:
            return text

        if 0 <= target_index < len(items):
            new_level = items[target_index]["level"]
            new_item = {
                "id": "tree_node_new",
                "index": len(items),
                "level": new_level,
                "type": item_type,
                "label": clean_label
            }
            items.insert(target_index + 1, new_item)
        else:
            new_item = {
                "id": "tree_node_new",
                "index": len(items),
                "level": 0,
                "type": item_type,
                "label": clean_label
            }
            items.append(new_item)

        return self.project_tree_flat_to_markdown(header, items)

    def generate_default_project_structure(self, files: list[str]) -> str:
        """
        Генерирует начальную разметку _Структура.md по списку файлов.
        """
        lines = [
            "# Структура проекта",
            "",
            "> Редактируйте этот файл как текст или переключайтесь в визуальное дерево!",
            ""
        ]
        for f in sorted(files):
            if f.startswith(".") or f.startswith("_"):
                continue
            stem = Path(f).stem
            lines.append(f"- [[{stem}]]")
        return "\n".join(lines) + "\n"

    def sync_project_structure_file(self, folder_path: Path, files: list[str], structure_filename: str = "_Структура.md", ignore_prefixes: tuple[str, ...] | list[str] = (".", "_")) -> Path:
        """
        Гарантирует существование файла структуры в рабочей папке
        и аккуратно синхронизирует недостающие заметки.
        """
        fpath = folder_path / structure_filename
        pfx = tuple(ignore_prefixes) if isinstance(ignore_prefixes, (list, tuple)) else (".", "_")
        if not fpath.exists():
            content = self.generate_default_project_structure(files)
            fpath.write_text(content, encoding="utf-8")
        else:
            try:
                existing_text = fpath.read_text(encoding="utf-8")
                missing: list[str] = []
                for f in sorted(files):
                    if f.startswith(pfx):
                        continue
                    stem = Path(f).stem
                    if f"[[{stem}]]" not in existing_text and stem not in existing_text:
                        missing.append(stem)
                if missing:
                    append_parts = []
                    if "## Неотсортированное" not in existing_text:
                        append_parts.append("\n\n## Неотсортированное\n")
                    else:
                        append_parts.append("\n")
                    for m in missing:
                        append_parts.append(f"- [[{m}]]\n")
                    new_text = existing_text.rstrip() + "".join(append_parts)
                    fpath.write_text(new_text, encoding="utf-8")
            except Exception:
                pass
        return fpath
