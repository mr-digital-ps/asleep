// mainbar_lifecycle.js — Вспомогательная логика, статистика и применение конфигурации редактора

function calculateStats(text) {
    var txt = text || ""
    var words = 0
    var trimmed = txt.trim()
    if (trimmed.length > 0) {
        words = trimmed.split(/\s+/).length
    }
    return words + " слов · " + txt.length + " знаков"
}

function stripExt(name) {
    if (!name) return ""
    return name.replace(/\.md$/i, "")
}

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
    if (!mainBar.isCustomWidthSetByUser && typeof cfg.editor.sheet_width === "number" && cfg.editor.sheet_width > 0) {
        mainBar.customSheetWidth = cfg.editor.sheet_width
    }
    if (typeof cfg.editor.font_family === "string" && cfg.editor.font_family.length > 0) {
        mainBar.customFontFamily = cfg.editor.font_family
    }
    if (!mainBar.isCustomFontSizeSetByUser && typeof cfg.editor.font_size === "number" && cfg.editor.font_size > 0) {
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
    if (backend && typeof backend.set_editor_line_height === "function") {
        var percent = (typeof cfg.editor.line_height === "number" && cfg.editor.line_height > 0) ? (cfg.editor.line_height * 100) : 135.0
        backend.set_editor_line_height(editorArea, percent)
    }
}
