// js/editor/frontmatter_service.js — Утилиты для работы с YAML frontmatter документов и конфигурациями редактора

function updateConfigParameterInText(fileName, text, key, value) {
    if (!fileName || (!fileName.startsWith("_Настройка каталога") && !fileName.startsWith("Настройка каталога"))) return null
    var regex = new RegExp("^(\\s*" + key + "\\s*:\\s*)[^\\s#]+", "m")
    if (regex.test(text)) {
        return text.replace(regex, "$1" + value)
    }
    return null
}

function applyEditorConfig(mainBar, editorArea, cfg, backend) {
    if (!cfg || !cfg.editor) return
    if (typeof cfg.editor.sheet_width === "number" && cfg.editor.sheet_width > 0) {
        mainBar.customSheetWidth = cfg.editor.sheet_width
    }
    if (typeof cfg.editor.font_size === "number" && cfg.editor.font_size > 0) {
        editorArea.font.pixelSize = cfg.editor.font_size
    }
    if (typeof cfg.editor.padding_left === "number") {
        editorArea.leftPadding = cfg.editor.padding_left
    }
    if (typeof cfg.editor.padding_right === "number") {
        editorArea.rightPadding = cfg.editor.padding_right
    }
    if (typeof cfg.editor.padding_top === "number") {
        editorArea.topPadding = cfg.editor.padding_top
    }
    if (typeof cfg.editor.padding_bottom === "number") {
        editorArea.bottomPadding = cfg.editor.padding_bottom
    }
    if (typeof cfg.editor.typewriter_mode === "boolean") {
        mainBar.typewriterMode = cfg.editor.typewriter_mode
    }
    if (typeof cfg.editor.focus_mode === "boolean") {
        mainBar.focusMode = cfg.editor.focus_mode
    }
    if (typeof cfg.editor.show_line_dots === "boolean") {
        mainBar.showLineDots = cfg.editor.show_line_dots
    }
    if (typeof cfg.editor.tab_size === "number" && cfg.editor.tab_size > 0) {
        mainBar.tabSize = cfg.editor.tab_size
    }
    var percent = (typeof cfg.editor.line_height === "number" && cfg.editor.line_height > 0) ? (cfg.editor.line_height * 100) : 135.0
    mainBar.editorLineHeightPercent = percent
    if (backend && typeof backend.set_editor_line_height === "function") {
        backend.set_editor_line_height(editorArea, percent)
    }
}

function initSessionConfig(mainBar, backend) {
    if (!backend || typeof backend.get_session_config !== "function") return
    try {
        let sess = backend.get_session_config()
        if (sess) {
            if (typeof sess.header_pinned === "boolean") mainBar.isHeaderPinned = sess.header_pinned
            if (typeof sess.header_visible === "boolean") mainBar.showHeader = sess.header_visible
            if (typeof sess.header_height === "number" && sess.header_height >= 40 && sess.header_height <= 400) mainBar.headerHeight = sess.header_height
            if (typeof sess.show_scrollbar === "boolean") mainBar.showScrollbar = sess.show_scrollbar
            if (typeof sess.show_line_dots === "boolean") mainBar.showLineDots = sess.show_line_dots
        }
    } catch(e) {}
}

function savePinnedState(backend, isHeader, pinned) {
    if (!backend) return
    if (isHeader && typeof backend.save_header_pinned === "function") {
        backend.save_header_pinned(pinned)
    }
}
