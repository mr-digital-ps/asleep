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
    from services.content.block_parser import BlockEngine, parse_syntax_blocks, replace_syntax_block
    from services.storage.file_service import FileService
    from services.system.window_manager import WindowManager
    from web import Backend

    # 1. Тест парсера блоков пользовательского диалекта
    sample = "Заголовок 1 {\n    Тело 1\n}\n\nЗаголовок 2 {\n    Тело 2\n}\n"
    blocks = parse_syntax_blocks(sample)
    assert len(blocks) == 2, f"Ожидалось 2 блока, получено {len(blocks)}"
    assert blocks[0]["title"] == "Заголовок 1"
    assert blocks[0]["content"] == "Тело 1"

    # 2. Тест замены блока
    updated, ok = replace_syntax_block(sample, "заголовок 1", "Новое тело 1")
    assert ok, "Замена не удалась"
    assert "Новое тело 1" in updated

    # 3. Тест BlockEngine и многофайловой синхронизации
    engine = BlockEngine()
    engine.index_file_content("file:///test.txt", sample)
    res = engine.get_block("Заголовок 1")
    assert res["found"] and res["content"] == "Тело 1"

    # Проверка чистого обновления из второго файла без дублирования контента
    _, updated_content, should_sync = engine.sync_block_data("file:///second.txt", "Заголовок 1", "Новое тело из второго файла")
    assert should_sync and updated_content == "Новое тело из второго файла", f"Ошибка слияния: {updated_content}"

    # 4. Тест ConfigService
    from services.storage.config_service import ConfigService, extract_frontmatter, deep_merge, DEFAULT_CONFIG
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
        new_mtime = cfg_service.update_folder_editor_setting(tmp_p, "sheet_width", 1120)
        assert new_mtime >= 0, "Параметр должен быть обработан"


    # 4.5. Тест парсера JSON с комментариями и завершающими запятыми
    from services.storage.config_service import parse_json_with_comments
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

    # 4.6. Тест конфигурации синтаксиса и безопасной компиляции regex
    from services.storage.config_service import compile_safe_regex
    md_cfg = cfg_service.get_syntax_config()
    assert "wikilinks" in md_cfg and "pattern" in md_cfg["wikilinks"], "syntax.json должен содержать секцию wikilinks"
    assert "tags" in md_cfg and "blocks" in md_cfg, "syntax.json должен содержать tags и blocks"

    # Проверка Safe Regex Fallback: сломанный regex пользователя не роняет систему
    import re
    default_re = re.compile(r"\[\[(.+)\]\]")
    safe_re = compile_safe_regex("[broken(regex", default_re)
    assert safe_re is default_re, "Сломанный regex должен безопасно откатываться на дефолт"
    valid_re = compile_safe_regex(r"@([a-zA-Z0-9_]+)", default_re)
    assert valid_re.pattern == r"@([a-zA-Z0-9_]+)", "Корректный regex должен компилироваться"


    # 5. Тест HotkeyService & GlobalHotkeyFilter
    from services.system.hotkey_service import HotkeyService, GlobalHotkeyFilter, HotkeyMatcher
    hk_service = HotkeyService()
    hks = hk_service.get_hotkeys()
    assert "toggle_header" in hks, "toggle_header должен присутствовать в hotkeys"
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

    # 1.1. Проверка toggle_local_graph: Alt+G (EN), Alt+П (RU: scan 34 / VK 0x47)
    ev_en_alt_g = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_G, Qt.KeyboardModifier.AltModifier, 34, 0x47, 0)
    ev_ru_alt_p = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_unknown, Qt.KeyboardModifier.AltModifier, 34, 0x47, 0)
    assert matcher.match_event(ev_en_alt_g) == "toggle_local_graph", "Alt+G должен распознаваться"
    assert matcher.match_event(ev_ru_alt_p) == "toggle_local_graph", "Alt+П (VK 0x47 / scan 34) должен распознаваться"

    # 2. Проверка close_tab: Ctrl+W (EN scan 17), Ctrl+Ц (RU scan 17, VK 0x57), Ctrl+Q не закрывает вкладку
    ev_w = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_unknown, Qt.KeyboardModifier.ControlModifier, 17, 0x57, 0)
    assert matcher.match_event(ev_w) == "close_tab", "Ctrl+W/Ctrl+Ц должен распознаваться"
    ev_q = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_unknown, Qt.KeyboardModifier.ControlModifier, 16, 0x51, 0)
    assert matcher.match_event(ev_q) != "close_tab", "Ctrl+Q не должен быть привязан к close_tab"

    # 3. Проверка toggle_canvas: Alt+S (scan 31, VK 0x53), Alt+C (scan 46, VK 0x43)
    ev_canvas_s = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_S, Qt.KeyboardModifier.AltModifier, 31, 0x53, 0)
    ev_canvas_c = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_C, Qt.KeyboardModifier.AltModifier, 46, 0x43, 0)
    assert matcher.match_event(ev_canvas_s) == "toggle_canvas", "Alt+S должен переключать canvas"
    assert matcher.match_event(ev_canvas_c) == "toggle_canvas", "Alt+C должен переключать canvas"

    # 4. Проверка toggle_header: F9 (scan 67) и Alt+U
    ev_f9 = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_F9, Qt.KeyboardModifier.NoModifier, 67, 0x78, 0)
    assert matcher.match_event(ev_f9) == "toggle_header", "F9 должен распознаваться как toggle_header"
    ev_alt_u = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_U, Qt.KeyboardModifier.AltModifier, 22, 0x55, 0)
    assert matcher.match_event(ev_alt_u) == "toggle_header", "Alt+U должен распознаваться как toggle_header"

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

    # 12. Проверка toggle_scrollbar: Alt+K (RU 'Л', scan 37, VK 0x4B)
    assert "toggle_scrollbar" in hks, "toggle_scrollbar должен присутствовать в hotkeys"
    ev_scrollbar = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_unknown, Qt.KeyboardModifier.AltModifier, 37, 0x4B, 0)
    assert matcher.match_event(ev_scrollbar) == "toggle_scrollbar", "Alt+K/Alt+Л должен распознаваться как toggle_scrollbar"

    # 13. Проверка toggle_line_dots: Alt+L (RU 'Д', scan 38, VK 0x4C)
    assert "toggle_line_dots" in hks, "toggle_line_dots должен присутствовать в hotkeys"
    ev_line_dots = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_unknown, Qt.KeyboardModifier.AltModifier, 38, 0x4C, 0)
    assert matcher.match_event(ev_line_dots) == "toggle_line_dots", "Alt+L/Alt+Д должен распознаваться как toggle_line_dots"

    # 7. Тест GraphService
    from services.graph_service import GraphService
    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp_p = Path(tmp_dir)
        (tmp_p / "doc1.txt").write_text("# ОбщийБлок\nТекст 1\nСмотри [[doc2]] и #проект\n", encoding="utf-8")
        (tmp_p / "doc2.txt").write_text("# ОбщийБлок\nТекст 2\nТоже #проект\n", encoding="utf-8")
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
    assert "toggle_header" in backend.get_hotkeys(), "backend.get_hotkeys должен содержать toggle_header"
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
    assert ".txt" in backend.file_service.get_supported_extensions(), "FileService должен динамически считывать supported_extensions"
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
        (th_p / "note1.txt").write_text("# Заметка 1\nТекст с [[note2]]", encoding="utf-8")
        (th_p / "note2.txt").write_text("# Заметка 2\nОтвет", encoding="utf-8")
        hs = HistoryService(backend.file_service, backend.graph_service)
        snap1 = hs.create_snapshot(th_p, trigger="session_start", graph_data={"nodes": [{"id": "note1"}], "links": []})
        assert snap1 is not None, "Снимок истории должен создаваться"
        assert snap1["filesCount"] == 2, "Должно быть 2 файла в снимке"

        # Дедупликация
        snap_dup = hs.create_snapshot(th_p, trigger="save")
        assert snap_dup is None, "Дублирующий снимок без изменений не должен создаваться"

        # Новый снимок с изменением
        (th_p / "note3.txt").write_text("# Заметка 3\nНовая", encoding="utf-8")
        snap2 = hs.create_snapshot(th_p, trigger="save", description="Добавлена заметка 3")
        assert snap2 is not None, "Снимок с новым файлом должен создаваться"

        tline = hs.get_timeline(th_p)
        assert len(tline) == 2, f"Ожидалось 2 снимка в таймлайне, получено {len(tline)}"
        g_snap = hs.get_snapshot_graph(th_p, snap1["id"])
        assert "nodes" in g_snap, "Граф снимка должен содержать nodes"
        f_content = hs.get_snapshot_file_content(th_p, snap1["id"], "note1.txt")
        assert "[[note2]]" in f_content, "Содержимое файла из снимка должно восстанавливаться"

        # Тест таймлайна отдельного файла
        file_tline = hs.get_file_timeline(th_p, "note1.txt")
        assert len(file_tline) >= 1, "Таймлайн note1.txt должен содержать хотя бы 1 срез"
        assert file_tline[0]["id"] == snap1["id"]

        # Изменение note1.txt и проверка добавления второго среза в таймлайн файла
        (th_p / "note1.txt").write_text("# Заметка 1 ред.\nНовый текст", encoding="utf-8")
        snap3 = hs.create_snapshot(th_p, trigger="save", description="Правка note1")
        assert snap3 is not None
        file_tline_updated = hs.get_file_timeline(th_p, "note1.txt")
        assert len(file_tline_updated) == 2, f"Ожидалось 2 среза note1.txt, получено {len(file_tline_updated)}"

        # note3.txt изменялся только в snap2 и не менялся в snap3
        note3_tline = hs.get_file_timeline(th_p, "note3.txt")
        assert len(note3_tline) == 1, f"Ожидался 1 срез для note3.txt, получено {len(note3_tline)}"

    # 9. Тест OutlineService и DocumentSession (блочная модель { ... }, reorder, undo/redo, cursor offsets)
    from services.content.outline_service import OutlineService
    from services.content.document_session import DocumentSession
    osvc = OutlineService()
    test_doc = "Блок 1 {\n    Текст 1\n}\n\nБлок 2 {\n    Текст 2\n}\n\nБлок 3 {\n    Текст 3\n}"
    parsed_blks = osvc.parse_document(test_doc)
    assert len(parsed_blks) == 3, f"Ожидалось 3 блока, получено {len(parsed_blks)}"
    assert parsed_blks[0]["heading"] == "Блок 1"
    assert parsed_blks[1]["heading"] == "Блок 2"
    assert parsed_blks[2]["heading"] == "Блок 3"
    assert parsed_blks[0]["level"] == 0

    # Перемещение Блока 3 перед Блоком 1
    reordered_doc = osvc.reorder_blocks(test_doc, source_index=2, target_index=0, position="before")
    new_blks = osvc.parse_document(reordered_doc)
    assert new_blks[0]["heading"] == "Блок 3", "Блок 3 должен переместиться на первое место"
    assert new_blks[1]["heading"] == "Блок 1"
    assert new_blks[2]["heading"] == "Блок 2"

    # Тест DocumentSession: Single Source of Truth и Undo/Redo стека
    session = DocumentSession(test_doc)
    assert session.can_undo is False
    assert session.can_redo is False
    session.set_text(reordered_doc)
    assert session.can_undo is True
    assert session.get_text() == reordered_doc
    # Undo
    assert session.undo() is not None
    assert session.get_text() == test_doc
    # Redo
    assert session.redo() is not None
    assert session.get_text() == reordered_doc

    # Тест проекции курсора и смещений блоков
    offsets = session.parse_blocks_offsets()
    assert len(offsets) == 3
    b_idx = session.get_block_at_offset(offsets[1]["start"] + 2)
    assert b_idx == 1
    off = session.get_block_offset(1)
    assert off == offsets[1]["start"]

    # 10. Тест работы со структурой проекта (_notes.txt) через единый DocumentOutlineManager
    proj_md = "# Структура проекта\n\n## Папка 1\n- [[Файл А]]\n- [[Файл Б]]\n\n## Папка 2\n- [[Файл В]]"
    parsed_tree = osvc.parse_document(proj_md)
    assert len(parsed_tree) == 6, f"Ожидалось 6 элементов (H1, H2, 2 файла, H2, 1 файл), получено {len(parsed_tree)}"
    assert parsed_tree[0]["level"] == 1 and parsed_tree[0]["heading"] == "Структура проекта"
    assert parsed_tree[1]["level"] == 2 and parsed_tree[1]["heading"] == "Папка 1"
    assert parsed_tree[2]["heading"] == "Файл А" and parsed_tree[2]["type"] == "file"
    assert parsed_tree[3]["heading"] == "Файл Б" and parsed_tree[3]["type"] == "file"
    assert parsed_tree[4]["level"] == 2 and parsed_tree[4]["heading"] == "Папка 2"
    assert parsed_tree[5]["heading"] == "Файл В" and parsed_tree[5]["type"] == "file"

    # Перемещение Папки 2 перед Папкой 1
    reordered_proj = osvc.reorder_blocks(proj_md, source_index=4, target_index=1, position="before")
    reordered_items = osvc.parse_document(reordered_proj)
    assert reordered_items[1]["heading"] == "Папка 2"
    assert reordered_items[3]["heading"] == "Папка 1"

    # Проверка sync_project_structure_file с кастомным именем файла
    with tempfile.TemporaryDirectory() as tmp_struct_dir:
        tmp_s_p = Path(tmp_struct_dir)
        custom_struct = osvc.sync_project_structure_file(tmp_s_p, ["note1.txt"], structure_filename="_MyStructure.txt")
        assert custom_struct.exists() and custom_struct.name == "_MyStructure.txt", "sync_project_structure_file должен поддерживать кастомное имя структуры"
        content = custom_struct.read_text(encoding="utf-8")
        assert "[[note1]]" in content, "Созданный файл структуры должен содержать вики-ссылку на note1"

        # 10.1. Тест неограниченной вложенности через табы (\t) в Python-стиле
        (tmp_s_p / "sub1" / "sub2" / "sub3").mkdir(parents=True, exist_ok=True)
        (tmp_s_p / "sub1" / "sub2" / "sub3" / "deep_note.txt").write_text("# Deep", encoding="utf-8")
        (tmp_s_p / "root_note.txt").write_text("# Root", encoding="utf-8")

        tree_path = osvc.sync_project_structure_file(tmp_s_p, structure_filename="_notes.txt")
        tree_text = tree_path.read_text(encoding="utf-8")
        assert "- sub1" in tree_text
        assert "\t- sub2" in tree_text
        assert "\t\t- sub3" in tree_text
        assert "\t\t\t- [[deep_note]]" in tree_text
        assert "- [[root_note]]" in tree_text

        # 10.2. Тест парсинга дерева с уровнями глубже 6
        tree_blocks = osvc.parse_document(tree_text)
        deep_blocks = [b for b in tree_blocks if b.get("heading") == "deep_note"]
        assert len(deep_blocks) == 1, "Глубокая заметка должна быть распарсена"
        assert deep_blocks[0]["type"] == "file"
        assert deep_blocks[0]["level"] == 5, f"Ожидался level 5, получено {deep_blocks[0]['level']}"

        # 10.3. Тест обратной сериализации в текст
        roundtrip_txt = osvc.blocks_to_text(tree_blocks)
        assert "\t\t\t- [[deep_note]]" in roundtrip_txt

        # 10.4. Тест включения списков в контент заголовка в обычном документе (parse_list_items=False)
        doc_with_lists = "### Обзор аналогов\n- Obsidian: граф\n- Notion: базы\n- Logseq: блоки\n\n## Следующая секция\nТекст"
        doc_blks = osvc.parse_document(doc_with_lists, parse_list_items=False)
        assert len(doc_blks) == 2, f"Ожидалось 2 блока заголовков, получено {len(doc_blks)}"
        assert doc_blks[0]["heading"] == "Обзор аналогов"
        assert "- Obsidian: граф" in doc_blks[0]["content"]
        assert "- Logseq: блоки" in doc_blks[0]["content"]
        assert doc_blks[1]["heading"] == "Следующая секция"

    print("  -> Сервисы Python: OK")

def test_qml():
    print("[2/3] Проверка компонентов QML...")
    import os
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")
    from PyQt6.QtWidgets import QApplication
    from PyQt6.QtQml import QQmlApplicationEngine, QQmlComponent
    from PyQt6.QtCore import QUrl, QObject
    from web import Backend

    app = QApplication.instance() or QApplication(sys.argv)
    engine = QQmlApplicationEngine()
    backend = Backend()
    engine.rootContext().setContextProperty("backend", backend)

    # 1. Проверяем компиляцию web.qml и вынесенных компонентов
    for qml_f in [
        "components/editor/EditorDialogs.qml",
        "components/hotkeys/HotkeyManager.qml",
        "components/theme/Theme.qml",
        "components/workspace/WorkspaceSplit.qml",
        "components/workspace/WorkspacePane.qml",
        "components/workspace/PaneHeader.qml",
        "components/workspace/HistoryTimelineBar.qml",
        "components/editor/EditorSheet.qml",
        "components/editor/EditorCanvas.qml",
        "components/editor/EditorScrollbar.qml",
        "components/graph/GraphView.qml",
        "views/web.qml"
    ]:
        comp = QQmlComponent(engine, QUrl.fromLocalFile(str(PROJECT_DIR / qml_f)))
        assert comp.status() == QQmlComponent.Status.Ready, f"Ошибка в {qml_f}: {comp.errorString()}"

    # 2. Проверяем загрузку window.qml и его внутреннего Loader
    qml_path = PROJECT_DIR / "views" / "window.qml"
    engine.load(QUrl.fromLocalFile(str(qml_path)))
    objects = engine.rootObjects()
    assert len(objects) > 0, "Не удалось создать корневое окно QML!"
    loader = objects[0].findChild(QObject, "hotLoader")
    assert loader is not None and loader.property("item") is not None, "web.qml не загрузился внутри Loader!"
    web_item = loader.property("item")

    # 2.1. Проверка toggle_centered_mode
    split = web_item.property("splitLayout")
    primary_bar = split.property("primaryBar")
    init_mode = primary_bar.property("isCenteredMode")
    assert init_mode is True, "isCenteredMode по умолчанию должен быть True"
    primary_bar.toggleCenteredMode()
    assert primary_bar.property("isCenteredMode") is False, "toggleCenteredMode должен переключать в False"
    primary_bar.toggleCenteredMode()
    assert primary_bar.property("isCenteredMode") is True, "toggleCenteredMode должен переключать обратно в True"

    # 2.2. Проверка toggleCanvasMode
    assert web_item.property("isCanvasMode") is False, "isCanvasMode по умолчанию должен быть выключен"
    web_item.toggleCanvasMode()
    assert web_item.property("isCanvasMode") is True, "toggleCanvasMode должен включать холст"
    web_item.toggleCanvasMode()
    assert web_item.property("isCanvasMode") is False, "toggleCanvasMode должен выключать холст"

    # 2.3. Проверка интерактивного графа связей (Фаза 5)
    assert web_item.property("isGraphVisible") is False, "Граф по умолчанию скрыт"
    web_item.toggleGraph()
    assert web_item.property("isGraphVisible") is True, "toggleGraph должен активировать отображение графа связей"
    assert primary_bar.property("isGraphMode") is True, "primaryBar должен переключиться в isGraphMode"
    web_item.closeGraph()
    assert web_item.property("isGraphVisible") is False, "closeGraph должен закрывать граф связей"
    assert primary_bar.property("isGraphMode") is False, "primaryBar должен вернуться из isGraphMode в режим текста"

    # 3. Тест клиентской логики auto-pair скобок и кавычек в JS
    from PyQt6.QtQml import QJSEngine
    js_engine = QJSEngine()
    js_code = (PROJECT_DIR / "components" / "editor" / "editor_shortcuts.js").read_text(encoding="utf-8")
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

    # 4. Тест контроллера таймлайна (getDaysList)
    import json
    timeline_js = (PROJECT_DIR / "components" / "workspace" / "timeline_controller.js").read_text(encoding="utf-8")
    clean_timeline_js = timeline_js.replace(".pragma library", "")
    js_engine.evaluate(clean_timeline_js)
    f = backend.get_default_folder()
    tl_p = backend.get_history_timeline(f)
    js_engine.evaluate('var test_tl = ' + json.dumps(tl_p))
    days_res = js_engine.evaluate('getDaysList(test_tl)')
    assert days_res.property('length').toInt() >= 1, "Таймлайн должен формировать список дней"

    # 5. Тест математического движка магнетизма (snap_engine.js)
    snap_js = (PROJECT_DIR / "components" / "workspace" / "snap_engine.js").read_text(encoding="utf-8")
    clean_snap_js = snap_js.replace(".pragma library", "")
    js_engine.evaluate(clean_snap_js)
    snap_test = """
    (function() {
        var dragged = { id: "p1", x: 195, y: 100, width: 200, height: 300 };
        var others = [{ id: "p2", x: 0, y: 100, width: 200, height: 300 }];
        var res = calculateSnap(dragged, others, 18);
        if (!res.isSnappedX || res.snappedX !== 200) return "SnapX_Failed: " + res.snappedX;
        if (!res.isSnappedY || res.snappedY !== 100) return "SnapY_Failed: " + res.snappedY;
        if (res.dockSide !== "right") return "DockSide_Failed: " + res.dockSide;
        return "OK";
    })()
    """
    snap_res = js_engine.evaluate(snap_test)
    assert snap_res.toString() == "OK", f"Ошибка SnapEngine: {snap_res.toString()}"

    print(f"  -> QML и компоненты: OK (создано окон: {len(objects)}, интерфейс активен, JS тесты пройдены)")

def test_structure():
    print("[3/3] Проверка структуры папок...")
    required = [
        "services/content/document_session.py",
        "services/storage/file_service.py",
        "services/storage/config_service.py",
        "services/content/block_parser.py",
        "services/content/document_outline.py",
        "services/content/outline_service.py",
        "services/history_service.py",
        "services/graph_service.py",
        "services/system/window_manager.py",
        "services/system/hotkey_service.py",
        "services/system/reloader.py",
        "services/system/key_mapper.py",
        "config/default/editor.json",
        "config/default/hotkeys.json",
        "config/default/graph.json",
        "config/default/theme.json",
        "config/default/app.json",
        "config/default/syntax.json",
        # JS-контроллеры и логика фич (Feature-based)
        "views/web_lifecycle.js",
        "components/editor/editor_shortcuts.js",
        "components/workspace/timeline_controller.js",
        "components/graph/graph_physics.js",
        "components/graph/graph_renderer.js",
        "components/graph/graph_interaction.js",

        # QML компоненты
        "components/editor/EditorDialogs.qml",
        "components/hotkeys/HotkeyManager.qml",
        "components/hotkeys/qmldir",
        "components/theme/Theme.qml",
        "components/theme/qmldir",
        "components/editor/EditorSheet.qml",
        "components/editor/EditorCanvas.qml",
        "components/editor/EditorScrollbar.qml",
        "components/editor/EditorEmptyState.qml",
        "components/editor/qmldir",
        "components/workspace/WorkspaceSplit.qml",
        "components/workspace/WorkspacePane.qml",
        "components/workspace/PaneHeader.qml",
        "components/workspace/HistoryTimelineBar.qml",
        "components/workspace/pane_controller.js",
        "components/workspace/qmldir",
        "components/graph/GraphView.qml",
        "components/graph/qmldir",
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
        import unittest
        suite = unittest.defaultTestLoader.discover(str(PROJECT_DIR / "tests"), pattern="test_project_architecture.py")
        assert unittest.TextTestRunner(verbosity=2).run(suite).wasSuccessful(), "Architecture regression tests failed"
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
