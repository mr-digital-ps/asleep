"""
verify.py — скрипт быстрой самодиагностики проекта.
Запуск: uv run python verify.py
Проверяет:
1. Корректность всех Python сервисов и фасада
2. Работу движка трансклюзии блоков (BlockEngine)
3. Загрузку и компиляцию всех компонентов QML
"""

import sys
from pathlib import Path

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if sys.stderr and hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

# Добавляем директорию проекта в sys.path
PROJECT_DIR = Path(__file__).parent.resolve()
if str(PROJECT_DIR) not in sys.path:
    sys.path.insert(0, str(PROJECT_DIR))

def test_services():
    print("[1/3] Проверка сервисов Python...")
    from services.block_engine import BlockEngine, parse_markdown_blocks, replace_block_in_markdown
    from services.file_service import FileService
    from services.window_manager import WindowManager
    from web import Backend

    # 1. Тест парсера блоков
    sample = "## Заголовок 1\nТело 1\n\n## Заголовок 2\nТело 2\n"
    blocks = parse_markdown_blocks(sample)
    assert len(blocks) == 2, f"Ожидалось 2 блока, получено {len(blocks)}"
    assert blocks[0]["title"] == "Заголовок 1"
    assert blocks[0]["content"] == "Тело 1"

    # 2. Тест замены блока
    updated, ok = replace_block_in_markdown(sample, "заголовок 1", "Новое тело 1")
    assert ok, "Замена не удалась"
    assert "Новое тело 1" in updated

    # 3. Тест BlockEngine и многофайловой синхронизации
    engine = BlockEngine()
    engine.index_file_content("file:///test.md", sample)
    res = engine.get_block("Заголовок 1")
    assert res["found"] and res["content"] == "Тело 1"

    # Проверка чистого обновления из второго файла без дублирования контента
    _, updated_content, should_sync = engine.sync_block_data("file:///second.md", "Заголовок 1", "Новое тело из второго файла")
    assert should_sync and updated_content == "Новое тело из второго файла", f"Ошибка слияния: {updated_content}"

    # 4. Тест ConfigService
    from services.config_service import ConfigService, extract_frontmatter, deep_merge, DEFAULT_CONFIG
    cfg_service = ConfigService()
    
    # 4.1. Парсинг Frontmatter
    sample_frontmatter = """---
editor:
  sheet_width: 920
tags:
  - тест
---
# Описание папки
"""
    data, body, ok = extract_frontmatter(sample_frontmatter)
    assert ok and data.get("editor", {}).get("sheet_width") == 920, "Ошибка извлечения frontmatter"
    assert "# Описание папки" in body

    # 4.2. Безопасность при ошибке синтаксиса YAML
    bad_yaml = "---\n: [invalid yaml\n---\n"
    bad_data, _, bad_ok = extract_frontmatter(bad_yaml)
    assert not bad_ok and bad_data == {}, "Сломанный YAML должен обрабатываться безопасно"

    # 4.3. Глубокое слияние deep_merge
    merged = deep_merge(DEFAULT_CONFIG, {"editor": {"sheet_width": 999}})
    assert merged["editor"]["sheet_width"] == 999, "sheet_width должен быть переопределен"
    assert merged["editor"]["font_size"] == DEFAULT_CONFIG["editor"]["font_size"], "font_size должен остаться из дефолтов"
    assert "hotkeys" in merged and "Ctrl+D" in merged["hotkeys"], "hotkeys должны сохраниться"

    # 4.4. Обновление отдельного параметра в файле настроек
    import tempfile
    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp_p = Path(tmp_dir)
        cfg_path = cfg_service.ensure_folder_config(tmp_p)
        assert cfg_path.exists(), "Файл конфигурации должен быть создан"
        new_mtime = cfg_service.update_folder_editor_setting(tmp_p, "sheet_width", 1120)
        assert new_mtime > 0, "Параметр должен быть обновлен"
        loaded = cfg_service.load_folder_config(tmp_p)
        assert loaded["editor"]["sheet_width"] == 1120, "Считанный sheet_width должен быть 1120"

    # 4.5. Тест парсера JSON с комментариями и завершающими запятыми
    from services.config_service import parse_json_with_comments
    json_with_comments = """
    {
        // Однострочный комментарий
        "physics": {
            /* Многострочный
               комментарий */
            "repulsion": 3600, // комментарий в конце строки
            "url": "http://example.com//not-a-comment",
        },
    }
    """
    parsed = parse_json_with_comments(json_with_comments)
    assert parsed["physics"]["repulsion"] == 3600, "Ошибка парсинга числа с комментариями"
    assert parsed["physics"]["url"] == "http://example.com//not-a-comment", "Строка с // не должна искажаться"

    # 4.6. Тест конфигурации Markdown диалекта и безопасной компиляции regex
    from services.config_service import compile_safe_regex
    md_cfg = cfg_service.get_markdown_config()
    assert "wikilinks" in md_cfg and "pattern" in md_cfg["wikilinks"], "markdown.json должен содержать секцию wikilinks"
    assert "tags" in md_cfg and "blocks" in md_cfg, "markdown.json должен содержать tags и blocks"

    # Проверка Safe Regex Fallback: сломанный regex пользователя не роняет систему
    import re
    default_re = re.compile(r"\[\[(.+)\]\]")
    safe_re = compile_safe_regex("[broken(regex", default_re)
    assert safe_re is default_re, "Сломанный regex должен безопасно откатываться на дефолт"
    valid_re = compile_safe_regex(r"@([a-zA-Z0-9_]+)", default_re)
    assert valid_re.pattern == r"@([a-zA-Z0-9_]+)", "Корректный regex должен компилироваться"
    assert "system_files" in md_cfg, "markdown.json должен содержать system_files"
    assert md_cfg["system_files"]["structure_file"] == "_Структура.md"
    assert md_cfg["system_files"]["graph_file"] == "_Граф связей.md"

    # 5. Тест MarkdownHighlighter
    from services.syntax_highlighter import MarkdownHighlighter
    from PyQt6.QtGui import QTextDocument
    test_doc = QTextDocument()
    test_doc.setPlainText("# Заголовок\n**жирный**\n`код`\n- [ ] задача")
    highlighter = MarkdownHighlighter(test_doc)
    assert highlighter is not None, "Highlighter должен инициализироваться"

    # 6. Тест HotkeyService & GlobalHotkeyFilter
    from services.hotkey_service import HotkeyService, GlobalHotkeyFilter, HotkeyMatcher
    hk_service = HotkeyService()
    hks = hk_service.get_hotkeys()
    assert "toggle_header_footer" in hks, "toggle_header_footer должен присутствовать в hotkeys"
    flat_hks = hk_service.get_flat_shortcuts()
    assert len(flat_hks) > 0, "Flat shortcuts не должен быть пустым"

    matcher = HotkeyMatcher(hks)
    from PyQt6.QtCore import Qt, QEvent
    from PyQt6.QtGui import QKeyEvent
    # 1. Проверка toggle_graph: Ctrl+G (EN), Ctrl+П (RU: scan 34 / VK 0x47), Ctrl+Г (RU: scan 22 / VK 0x55)
    ev_en_g = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_G, Qt.KeyboardModifier.ControlModifier, 34, 0x47, 0)
    ev_ru_p = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_unknown, Qt.KeyboardModifier.ControlModifier, 34, 0x47, 0)
    ev_ru_g = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_unknown, Qt.KeyboardModifier.ControlModifier, 22, 0x55, 0)
    assert matcher.match_event(ev_en_g) == "toggle_graph", "Ctrl+G должен распознаваться"
    assert matcher.match_event(ev_ru_p) == "toggle_graph", "Ctrl+П (VK 0x47 / scan 34) должен распознаваться"
    assert matcher.match_event(ev_ru_g) == "toggle_graph", "Ctrl+Г (VK 0x55 / scan 22) должен распознаваться"

    # 2. Проверка close_tab: Ctrl+W (EN scan 17), Ctrl+Ц (RU scan 17, VK 0x57), Ctrl+Q не закрывает вкладку
    ev_w = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_unknown, Qt.KeyboardModifier.ControlModifier, 17, 0x57, 0)
    assert matcher.match_event(ev_w) == "close_tab", "Ctrl+W/Ctrl+Ц должен распознаваться"
    ev_q = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_unknown, Qt.KeyboardModifier.ControlModifier, 16, 0x51, 0)
    assert matcher.match_event(ev_q) != "close_tab", "Ctrl+Q не должен быть привязан к close_tab"

    # 3. Проверка toggle_split: Ctrl+\ (scan 43, 86, VK 0xDC, 0xE2)
    ev_split_scan43 = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_Backslash, Qt.KeyboardModifier.ControlModifier, 43, 0xDC, 0)
    ev_split_scan86 = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_unknown, Qt.KeyboardModifier.ControlModifier, 86, 0xE2, 0)
    assert matcher.match_event(ev_split_scan43) == "toggle_split", "Ctrl+\\ (scan 43) должен распознаваться"
    assert matcher.match_event(ev_split_scan86) == "toggle_split", "Ctrl+\\ (scan 86) должен распознаваться"

    # 4. Проверка toggle_header_footer: F9 (scan 67) и Ctrl+Shift+H (RU 'Р', scan 35, VK 0x48)
    ev_f9 = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_F9, Qt.KeyboardModifier.NoModifier, 67, 0x78, 0)
    ev_csh = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_unknown, Qt.KeyboardModifier.ControlModifier | Qt.KeyboardModifier.ShiftModifier, 35, 0x48, 0)
    assert matcher.match_event(ev_f9) == "toggle_header_footer", "F9 должен распознаваться"
    assert matcher.match_event(ev_csh) == "toggle_header_footer", "Ctrl+Shift+H (RU: scan 35) должен распознаваться"

    # 5. Проверка save_file: Ctrl+S (RU 'Ы', scan 31, VK 0x53)
    ev_save = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_unknown, Qt.KeyboardModifier.ControlModifier, 31, 0x53, 0)
    assert matcher.match_event(ev_save) == "save_file", "Ctrl+S/Ctrl+Ы должен распознаваться"

    # 6. Проверка new_tab: Ctrl+N (RU 'Т', scan 49, VK 0x4E)
    ev_new = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_unknown, Qt.KeyboardModifier.ControlModifier, 49, 0x4E, 0)
    assert matcher.match_event(ev_new) == "new_tab", "Ctrl+N/Ctrl+Т должен распознаваться"

    ev_new_split = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_unknown, Qt.KeyboardModifier.ControlModifier | Qt.KeyboardModifier.ShiftModifier, 49, 0x4E, 0)
    assert matcher.match_event(ev_new_split) == "new_tab_split", "Ctrl+Shift+N должен распознаваться как new_tab_split"

    # 7. Проверка open_file: Ctrl+O (RU 'Щ', scan 24, VK 0x4F)
    ev_open = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_unknown, Qt.KeyboardModifier.ControlModifier, 24, 0x4F, 0)
    assert matcher.match_event(ev_open) == "open_file", "Ctrl+O/Ctrl+Щ должен распознаваться"

    ev_open_split = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_unknown, Qt.KeyboardModifier.ControlModifier | Qt.KeyboardModifier.ShiftModifier, 24, 0x4F, 0)
    assert matcher.match_event(ev_open_split) == "open_file_split", "Ctrl+Shift+O должен распознаваться как open_file_split"

    # 8. Проверка toggle_bold: Ctrl+B (RU 'И', scan 48, VK 0x42)
    ev_bold = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_unknown, Qt.KeyboardModifier.ControlModifier, 48, 0x42, 0)
    assert matcher.match_event(ev_bold) == "toggle_bold", "Ctrl+B/Ctrl+И должен распознаваться"

    # 9. Проверка toggle_italic: Ctrl+I (RU 'Ш', scan 23, VK 0x49)
    ev_italic = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_unknown, Qt.KeyboardModifier.ControlModifier, 23, 0x49, 0)
    assert matcher.match_event(ev_italic) == "toggle_italic", "Ctrl+I/Ctrl+Ш должен распознаваться"

    # 10. Проверка detach_window: Ctrl+D (RU 'В', scan 32, VK 0x44) и мнемонический Ctrl+Д (scan 38, VK 0x4C)
    ev_detach = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_unknown, Qt.KeyboardModifier.ControlModifier, 32, 0x44, 0)
    assert matcher.match_event(ev_detach) == "detach_window", "Ctrl+D/Ctrl+В должен распознаваться"
    ev_detach_de = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_unknown, Qt.KeyboardModifier.ControlModifier, 38, 0x4C, 0)
    assert matcher.match_event(ev_detach_de) == "detach_window", "Ctrl+Д (буква Д, scan 38, VK 0x4C) должен распознаваться"

    # 11. Проверка toggle_centered_mode (поддержка дефолтного Alt+W и пользовательского Alt+J)
    centered_keys = hks.get("toggle_centered_mode", {}).get("keys", [])
    if any("Alt+J" in k for k in centered_keys):
        ev_centered = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_unknown, Qt.KeyboardModifier.AltModifier, 36, 0x4A, 0)
        assert matcher.match_event(ev_centered) == "toggle_centered_mode", "Alt+J/Alt+О должен распознаваться"
    else:
        ev_centered = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_unknown, Qt.KeyboardModifier.AltModifier, 17, 0x57, 0)
        assert matcher.match_event(ev_centered) == "toggle_centered_mode", "Alt+W/Alt+Ц должен распознаваться"


    # 7. Тест GraphService
    from services.graph_service import GraphService
    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp_p = Path(tmp_dir)
        (tmp_p / "doc1.md").write_text("# ОбщийБлок\nТекст 1\nСмотри [[doc2]] и #проект\n", encoding="utf-8")
        (tmp_p / "doc2.md").write_text("# ОбщийБлок\nТекст 2\nТоже #проект\n", encoding="utf-8")
        gs = GraphService()
        gdata = gs.build_graph(tmp_p)
        assert len(gdata["nodes"]) >= 3, f"Ожидалось >= 3 узлов, получено {len(gdata['nodes'])}"
        assert len(gdata["links"]) >= 2, f"Ожидалось >= 2 связей, получено {len(gdata['links'])}"

        # Проверка get_config и каскада
        cfg = gs.get_config(tmp_p)
        assert "physics" in cfg and "visual" in cfg, "Конфигурация графа должна содержать physics и visual"
        assert cfg["physics"]["repulsion"] > 0, "repulsion должен быть положительным"
        assert cfg["physics"]["linkStrength"] > 0, "linkStrength должен быть положительным"

        # Проверка локального переопределения через _graph_settings.json
        (tmp_p / "_graph_settings.json").write_text('{"physics": {"linkStrength": 0.099}}', encoding="utf-8")
        vault_cfg = gs.get_config(tmp_p)
        assert vault_cfg["physics"]["linkStrength"] == 0.099, "Локальный _graph_settings.json должен переопределять linkStrength"
        assert vault_cfg["physics"]["repulsion"] == cfg["physics"]["repulsion"], "Неуказанные параметры должны сохраняться"

        # Проверка генерации и синхронизации _Граф связей.md
        md_content = gs.generate_graph_markdown(tmp_p)
        assert "# doc1" in md_content and "# doc2" in md_content, "Сгенерированный Markdown должен содержать H1-заголовки заметок"
        assert "##" not in md_content, "В файле связей не должно быть заголовков второго уровня (H2)"
        assert "[[doc1]]" in md_content or "[[doc2]]" in md_content, "Markdown должен содержать ссылки на заметки"

        synced_file = gs.sync_graph_markdown_file(tmp_p)
        assert synced_file.exists() and synced_file.name == "_Граф связей.md", "Файл _Граф связей.md должен быть создан на диске"

        # Проверка фиксации позиций узлов графа
        gdata_after = gs.build_graph(tmp_p)
        node_id_1 = gdata_after["nodes"][0]["id"]
        gs.save_node_positions(tmp_p, {node_id_1: {"x": 250.5, "y": 340.0}})
        saved_pos = gs.get_node_positions(tmp_p)
        assert node_id_1 in saved_pos, "Сохраненная позиция должна присутствовать в get_node_positions"
        assert saved_pos[node_id_1]["x"] == 250.5 and saved_pos[node_id_1]["y"] == 340.0, "Координаты должны совпадать"
        gdata_with_pos = gs.build_graph(tmp_p)
        matched_node = next(n for n in gdata_with_pos["nodes"] if n["id"] == node_id_1)
        assert matched_node.get("x") == 250.5 and matched_node.get("y") == 340.0, "Узел должен получать сохраненные координаты при build_graph"


    # 8. Тест Backend Facade
    backend = Backend()
    assert backend is not None
    cfg_json = backend.get_current_config()
    assert "sheet_width" in cfg_json, "get_current_config должен возвращать JSON с настройками"
    assert "toggle_header_footer" in backend.get_hotkeys(), "backend.get_hotkeys должен содержать действия"
    assert "toggle_graph" in backend.get_hotkeys(), "backend.get_hotkeys должен содержать toggle_graph"
    assert len(backend.get_flat_shortcuts()) > 0, "backend.get_flat_shortcuts должен возвращать список"
    graph_cfg = backend.get_graph_config()
    assert "physics" in graph_cfg and "visual" in graph_cfg, "backend.get_graph_config должен возвращать словарь с physics и visual"
    theme_cfg = backend.get_theme_config()
    assert "bg_app" in theme_cfg and "bg_paper" in theme_cfg, "backend.get_theme_config должен содержать bg_app и bg_paper"
    assert "scrollbar_track" in theme_cfg, "backend.get_theme_config должен содержать scrollbar_track"
    editor_cfg = backend.get_editor_config()
    assert "sheet_width" in editor_cfg and "font_size" in editor_cfg, "backend.get_editor_config должен содержать sheet_width и font_size"
    assert "show_line_dots" in editor_cfg, "backend.get_editor_config должен содержать show_line_dots"
    assert "tab_size" in editor_cfg, "backend.get_editor_config должен содержать tab_size"
    app_cfg = backend.get_app_config()
    assert "auto_save_delay_ms" in app_cfg and "supported_extensions" in app_cfg, "backend.get_app_config должен содержать auto_save_delay_ms"
    assert "target_fps" in app_cfg and "vsync" in app_cfg, "backend.get_app_config должен содержать target_fps и vsync"
    refresh_rate = backend.get_screen_refresh_rate()
    assert refresh_rate > 0, f"get_screen_refresh_rate должен быть > 0, получено {refresh_rate}"
    target_fps = backend.get_target_fps()
    assert target_fps >= 0, f"get_target_fps должен быть >= 0, получено {target_fps}"
    assert ".md" in backend.file_service.get_supported_extensions(), "FileService должен динамически считывать supported_extensions"
    assert ".git" in backend.file_service.get_ignored_directories(), "FileService должен динамически считывать ignored_directories"
    sync_res = backend.sync_graph_file()
    assert isinstance(sync_res, dict), "backend.sync_graph_file должен возвращать словарь"
    backend.save_node_positions("", {"test_node": {"x": 100, "y": 200}})
    node_pos = backend.get_node_positions("")
    assert "test_node" in node_pos and node_pos["test_node"]["x"] == 100, "backend.save_node_positions/get_node_positions должны корректно работать"

    # 8. Тест HistoryService
    from services.history_service import HistoryService
    with tempfile.TemporaryDirectory() as tmp_hist_dir:
        th_p = Path(tmp_hist_dir)
        (th_p / "note1.md").write_text("# Заметка 1\nТекст с [[note2]]", encoding="utf-8")
        (th_p / "note2.md").write_text("# Заметка 2\nОтвет", encoding="utf-8")
        hs = HistoryService(backend.file_service, backend.graph_service)
        snap1 = hs.create_snapshot(th_p, trigger="session_start", graph_data={"nodes": [{"id": "note1"}], "links": []})
        assert snap1 is not None, "Снимок истории должен создаваться"
        assert snap1["filesCount"] == 2, "Должно быть 2 файла в снимке"

        # Дедупликация
        snap_dup = hs.create_snapshot(th_p, trigger="save")
        assert snap_dup is None, "Дублирующий снимок без изменений не должен создаваться"

        # Новый снимок с изменением
        (th_p / "note3.md").write_text("# Заметка 3\nНовая", encoding="utf-8")
        snap2 = hs.create_snapshot(th_p, trigger="save", description="Добавлена заметка 3")
        assert snap2 is not None, "Снимок с новым файлом должен создаваться"

        tline = hs.get_timeline(th_p)
        assert len(tline) == 2, f"Ожидалось 2 снимка в таймлайне, получено {len(tline)}"
        g_snap = hs.get_snapshot_graph(th_p, snap1["id"])
        assert "nodes" in g_snap, "Граф снимка должен содержать nodes"
        f_content = hs.get_snapshot_file_content(th_p, snap1["id"], "note1.md")
        assert "[[note2]]" in f_content, "Содержимое файла из снимка должно восстанавливаться"

        # Тест таймлайна отдельного файла
        file_tline = hs.get_file_timeline(th_p, "note1.md")
        assert len(file_tline) >= 1, "Таймлайн note1.md должен содержать хотя бы 1 срез"
        assert file_tline[0]["id"] == snap1["id"]

        # Изменение note1.md и проверка добавления второго среза в таймлайн файла
        (th_p / "note1.md").write_text("# Заметка 1 ред.\nНовый текст", encoding="utf-8")
        snap3 = hs.create_snapshot(th_p, trigger="save", description="Правка note1")
        assert snap3 is not None
        file_tline_updated = hs.get_file_timeline(th_p, "note1.md")
        assert len(file_tline_updated) == 2, f"Ожидалось 2 среза note1.md, получено {len(file_tline_updated)}"

        # note3.md изменялся только в snap2 и не менялся в snap3
        note3_tline = hs.get_file_timeline(th_p, "note3.md")
        assert len(note3_tline) == 1, f"Ожидался 1 срез для note3.md, получено {len(note3_tline)}"

    # 9. Тест OutlineService (иерархия блоков документа и перестановка с поддеревьями)
    from services.outline_service import OutlineService
    osvc = OutlineService()
    test_doc = "# Глава 1\nТекст 1\n\n## Секция 1.1\nПодтекст 1.1\n\n# Глава 2\nТекст 2"
    parsed_blks = osvc.parse_document(test_doc)
    assert len(parsed_blks) == 3, f"Ожидалось 3 блока, получено {len(parsed_blks)}"
    assert parsed_blks[0]["heading"] == "Глава 1"
    assert parsed_blks[1]["level"] == 2
    # Перемещение Главы 2 перед Главой 1
    reordered_doc = osvc.reorder_blocks(test_doc, source_index=2, target_index=0, position="before")
    new_blks = osvc.parse_document(reordered_doc)
    assert new_blks[0]["heading"] == "Глава 2", "Глава 2 должна переместиться на первое место"
    assert new_blks[1]["heading"] == "Глава 1"
    assert new_blks[2]["heading"] == "Секция 1.1", "Секция 1.1 должна остаться с Главой 1"
    # Повышение уровня Секция 1.1: H2 -> H1
    promoted_doc = osvc.change_block_level(test_doc, block_index=1, delta=-1)
    promoted_blks = osvc.parse_document(promoted_doc)
    assert promoted_blks[1]["level"] == 1, "Уровень секции должен повыситься до H1"

    # 10. Тест работы со структурой проекта (_Структура.md)
    proj_md = "# Структура проекта\n\n- 📁 Папка 1\n    - [[Файл А]]\n    - [[Файл Б]]\n- 📁 Папка 2\n    - [[Файл В]]"
    parsed_tree = osvc.parse_project_tree_flat(proj_md)
    tree_items = parsed_tree["items"]
    assert len(tree_items) == 5, f"Ожидалось 5 элементов дерева, получено {len(tree_items)}"
    assert tree_items[0]["type"] == "folder" and tree_items[0]["label"] == "Папка 1"
    assert tree_items[1]["level"] == 1 and tree_items[1]["label"] == "Файл А"
    assert tree_items[0]["hasChildren"] is True, "Папка с вложенными файлами должна иметь hasChildren: True"
    assert tree_items[1]["hasChildren"] is False, "Файл без дочерних элементов должен иметь hasChildren: False"

    # Проверка корневых файлов после папок и секций
    mixed_proj = "# Структура проекта\n\n- 📁 Папка\n    - [[Вложенный]]\n- [[Заметка в корне]]\n\n## Секция\n- [[В секции]]"
    parsed_mixed = osvc.parse_project_tree_flat(mixed_proj)
    mixed_items = parsed_mixed["items"]
    assert mixed_items[2]["label"] == "Заметка в корне" and mixed_items[2]["level"] == 0, "Заметка в корне после папки должна иметь level: 0"
    assert mixed_items[3]["type"] == "section" and mixed_items[3]["level"] == 0, "Секция должна иметь type: section"
    assert mixed_items[4]["label"] == "В секции" and mixed_items[4]["level"] == 1, "Элемент в секции должен иметь level: 1"

    # Проверка roundtrip сериализации секций
    serialized = osvc.project_tree_flat_to_markdown(parsed_mixed["header"], mixed_items)
    assert "## Секция" in serialized, "Секции ## должны сохраняться при сериализации"

    # Перемещение Папки 2 перед Папкой 1
    reordered_proj = osvc.reorder_project_tree(proj_md, source_index=3, target_index=0, position="before")
    reordered_items = osvc.parse_project_tree_flat(reordered_proj)["items"]
    assert reordered_items[0]["label"] == "Папка 2"
    assert reordered_items[1]["label"] == "Файл В"
    assert reordered_items[2]["label"] == "Папка 1"
    # Изменение уровня отступа
    indented_proj = osvc.change_project_tree_level(proj_md, item_index=0, delta=1)
    indented_items = osvc.parse_project_tree_flat(indented_proj)["items"]
    # Проверка sync_project_structure_file с кастомным именем файла
    with tempfile.TemporaryDirectory() as tmp_struct_dir:
        tmp_s_p = Path(tmp_struct_dir)
        custom_struct = osvc.sync_project_structure_file(tmp_s_p, ["note1.md"], structure_filename="_MyStructure.md")
        assert custom_struct.exists() and custom_struct.name == "_MyStructure.md", "sync_project_structure_file должен поддерживать кастомное имя структуры"

    print("  -> Сервисы Python: OK")



def test_qml():
    print("[2/3] Проверка компонентов QML...")
    import os
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")
    from PyQt6.QtWidgets import QApplication
    from PyQt6.QtQml import QQmlApplicationEngine, QQmlComponent
    from PyQt6.QtCore import QUrl
    from web import Backend

    app = QApplication.instance() or QApplication(sys.argv)
    engine = QQmlApplicationEngine()
    backend = Backend()
    engine.rootContext().setContextProperty("backend", backend)

    # 1. Проверяем компиляцию web.qml и вынесенных компонентов
    for qml_f in [
        "components/dialogs/EditorDialogs.qml",
        "components/hotkeys/HotkeyManager.qml",
        "components/window/WindowFrame.qml",
        "components/graph/GraphView.qml",
        "components/editor/EditorCanvas.qml",
        "components/editor/EditorSheet.qml",
        "components/editor/DocumentOutliner.qml",
        "components/editor/MainBar.qml",
        "views/web.qml"
    ]:
        comp = QQmlComponent(engine, QUrl.fromLocalFile(str(PROJECT_DIR / qml_f)))
        assert comp.status() == QQmlComponent.Status.Ready, f"Ошибка в {qml_f}: {comp.errorString()}"

    # 1.1. Тест создания делегатов DocumentOutliner
    outliner_comp = QQmlComponent(engine, QUrl.fromLocalFile(str(PROJECT_DIR / "components/editor/DocumentOutliner.qml")))
    outliner_item = outliner_comp.create()
    assert outliner_item is not None, f"Не удалось создать DocumentOutliner: {outliner_comp.errorString()}"
    outliner_item.setProperty("blocksList", [{"level": 1, "label": "Тест", "content": "Контент"}])
    QApplication.processEvents()

    # 2. Проверяем загрузку window.qml и его внутреннего Loader
    qml_path = PROJECT_DIR / "views" / "window.qml"
    engine.load(QUrl.fromLocalFile(str(qml_path)))
    objects = engine.rootObjects()
    assert len(objects) > 0, "Не удалось создать корневое окно QML!"
    loader = objects[0].findChild(object, "hotLoader")
    assert loader is not None and loader.property("item") is not None, "web.qml не загрузился внутри Loader!"

    # 3. Тест клиентской логики auto-pair скобок и кавычек в JS
    from PyQt6.QtQml import QJSEngine
    js_engine = QJSEngine()
    js_code = (PROJECT_DIR / "js" / "editor" / "markdown_shortcuts.js").read_text(encoding="utf-8")
    js_engine.evaluate(js_code)
    test_js = """
    (function() {
        var mock = {
            text: '', cursorPosition: 0, selectionStart: 0, selectionEnd: 0,
            insert: function(p, s) { this.text = this.text.substring(0, p) + s + this.text.substring(p); },
            remove: function(s, e) { this.text = this.text.substring(0, s) + this.text.substring(e); }
        };
        if (!handleAutoPair(mock, '(') || mock.text !== '()' || mock.cursorPosition !== 1) return 'Err1';
        if (!handleAutoPair(mock, ')') || mock.text !== '()' || mock.cursorPosition !== 2) return 'Err2';
        mock.cursorPosition = 1;
        if (!handleAutoPairBackspace(mock) || mock.text !== '' || mock.cursorPosition !== 0) return 'Err3';
        var bPair = findMatchingBracket('(hello [world])', 1);
        if (!bPair || bPair.primary !== 0 || bPair.match !== 14) return 'ErrBracket1';
        var bPair2 = findMatchingBracket('(hello [world])', 8);
        if (!bPair2 || bPair2.primary !== 7 || bPair2.match !== 13) return 'ErrBracket2';
        return 'OK';
    })()
    """
    res = js_engine.evaluate(test_js)
    assert res.toString() == "OK", f"Ошибка JS авто-пар скобок: {res.toString()}"

    print(f"  -> QML и компоненты: OK (создано окон: {len(objects)}, интерфейс активен, JS тесты пройдены)")

def test_structure():
    print("[3/3] Проверка структуры папок...")
    required = [
        "services/block_engine.py",
        "services/file_service.py",
        "services/window_manager.py",
        "services/config_service.py",
        "services/syntax_highlighter.py",
        "services/hotkey_service.py",
        "services/graph_service.py",
        "services/reloader.py",
        "config/default/editor.json",
        "config/default/hotkeys.json",
        "config/default/graph.json",
        "config/default/theme.json",
        "config/default/app.json",
        "config/default/markdown.json",
        "config/user/editor.json",
        "config/user/hotkeys.json",
        "config/user/graph.json",
        "config/user/theme.json",
        "config/user/app.json",
        "config/user/markdown.json",
        "config/user/markdown.md",
        "js/editor/editor_keys.js",
        "js/editor/markdown_shortcuts.js",
        "js/editor/block_sync.js",
        "js/editor/mainbar_controller.js",
        "js/editor/frontmatter_service.js",
        "js/editor/gutter_renderer.js",
        "js/graph/graph_physics.js",
        "js/graph/graph_renderer.js",
        "js/graph/graph_interaction.js",
        "js/tabs/tab_model.js",
        "js/tabs/tab_split.js",
        "js/tabs/tab_sync.js",
        "js/tabs/drag_manager.js",
        "js/tabs/tabs.js",
        "js/app/action_dispatcher.js",
        "js/app/web_lifecycle.js",

        "components/editor/EditorCanvas.qml",
        "components/editor/EditorSheet.qml",
        "components/editor/MainBar.qml",
        "components/editor/DocumentHeader.qml",
        "components/editor/chrome/qmldir",
        "components/editor/canvas/qmldir",
        "components/dialogs/EditorDialogs.qml",
        "components/dialogs/qmldir",
        "components/hotkeys/HotkeyManager.qml",
        "components/hotkeys/qmldir",
        "components/window/WindowFrame.qml",
        "components/window/qmldir",
        "components/graph/GraphView.qml",
        "components/graph/qmldir",
        "components/theme/Theme.qml",
        "components/theme/qmldir",
        "views/web.qml",
        "views/window.qml",
        "web.py"
    ]
    for r in required:
        p = PROJECT_DIR / r
        assert p.exists(), f"Файл не найден: {r}"
    print("  -> Структура файлов: OK")

def main():
    print("=== Запуск самодиагностики my-text-editor ===\n")
    try:
        test_structure()
        test_services()
        test_qml()
        print("\n[УСПЕХ] Все тесты пройдены! Приложение 100% готово к работе.")
        return 0
    except Exception as e:
        print(f"\n[ОШИБКА] Диагностика провалена: {e}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    sys.exit(main())
