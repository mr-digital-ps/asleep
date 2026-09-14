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

    # 2. Проверка close_tab: Ctrl+W (EN scan 17), Ctrl+Ц (RU scan 17, VK 0x57), Ctrl+Q (RU scan 16, VK 0x51)
    ev_w = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_unknown, Qt.KeyboardModifier.ControlModifier, 17, 0x57, 0)
    ev_q = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_unknown, Qt.KeyboardModifier.ControlModifier, 16, 0x51, 0)
    assert matcher.match_event(ev_w) == "close_tab", "Ctrl+W/Ctrl+Ц должен распознаваться"
    assert matcher.match_event(ev_q) == "close_tab", "Ctrl+Q/Ctrl+Й должен распознаваться"

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

    # 7. Проверка open_file: Ctrl+O (RU 'Щ', scan 24, VK 0x4F)
    ev_open = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_unknown, Qt.KeyboardModifier.ControlModifier, 24, 0x4F, 0)
    assert matcher.match_event(ev_open) == "open_file", "Ctrl+O/Ctrl+Щ должен распознаваться"

    # 8. Проверка toggle_bold: Ctrl+B (RU 'И', scan 48, VK 0x42)
    ev_bold = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_unknown, Qt.KeyboardModifier.ControlModifier, 48, 0x42, 0)
    assert matcher.match_event(ev_bold) == "toggle_bold", "Ctrl+B/Ctrl+И должен распознаваться"

    # 9. Проверка toggle_italic: Ctrl+I (RU 'Ш', scan 23, VK 0x49)
    ev_italic = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_unknown, Qt.KeyboardModifier.ControlModifier, 23, 0x49, 0)
    assert matcher.match_event(ev_italic) == "toggle_italic", "Ctrl+I/Ctrl+Ш должен распознаваться"

    # 10. Проверка detach_window: Ctrl+D (RU 'В', scan 32, VK 0x44)
    ev_detach = QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_unknown, Qt.KeyboardModifier.ControlModifier, 32, 0x44, 0)
    assert matcher.match_event(ev_detach) == "detach_window", "Ctrl+D/Ctrl+В должен распознаваться"

    # 11. Проверка toggle_centered_mode: Alt+W (RU 'Ц', scan 17, VK 0x57)
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
    assert "ignored_directories" in app_cfg, "backend.get_app_config должен содержать ignored_directories"
    assert ".md" in backend.file_service.get_supported_extensions(), "FileService должен динамически считывать supported_extensions"
    assert ".git" in backend.file_service.get_ignored_directories(), "FileService должен динамически считывать ignored_directories"
    sync_res = backend.sync_graph_file()
    assert isinstance(sync_res, dict), "backend.sync_graph_file должен возвращать словарь"
    backend.save_node_positions("", {"test_node": {"x": 100, "y": 200}})
    node_pos = backend.get_node_positions("")
    assert "test_node" in node_pos and node_pos["test_node"]["x"] == 100, "backend.save_node_positions/get_node_positions должны корректно работать"
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
        "components/editor/MainBar.qml",
        "views/web.qml"
    ]:
        comp = QQmlComponent(engine, QUrl.fromLocalFile(str(PROJECT_DIR / qml_f)))
        assert comp.status() == QQmlComponent.Status.Ready, f"Ошибка в {qml_f}: {comp.errorString()}"

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
        "config/user/editor.json",
        "config/user/hotkeys.json",
        "config/user/graph.json",
        "config/user/theme.json",
        "config/user/app.json",
        "js/editor/editor_keys.js",
        "js/editor/markdown_shortcuts.js",
        "js/editor/block_sync.js",
        "js/editor/mainbar_controller.js",
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
        "js/app/logic.js",

        "components/editor/EditorCanvas.qml",
        "components/editor/MainBar.qml",
        "components/editor/DocumentHeader.qml",
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
