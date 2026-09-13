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
    if (typeof cfg.editor.sheet_width === "number" && cfg.editor.sheet_width > 0) {
        mainBar.customSheetWidth = cfg.editor.sheet_width
    }
    if (typeof cfg.editor.font_family === "string" && cfg.editor.font_family.length > 0) {
        mainBar.customFontFamily = cfg.editor.font_family
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
            if (typeof sess.footer_pinned === "boolean") mainBar.isFooterPinned = sess.footer_pinned
            if (typeof sess.header_visible === "boolean") mainBar.showHeader = sess.header_visible
            if (typeof sess.footer_visible === "boolean") mainBar.showFooter = sess.footer_visible
        }
    } catch(e) {}
}

function ensureCursorVisible(mainBar, editorArea, editorScroll) {
    if (!editorArea || !editorScroll || !editorScroll.contentItem) return
    if (!editorArea.activeFocus) return

    let rect = editorArea.cursorRectangle
    if (!rect || rect.height <= 0) return

    let pt = editorArea.mapToItem(editorScroll, 0, rect.y)
    let cursorTop = pt.y
    let cursorBottom = cursorTop + rect.height

    let viewH = editorScroll.availableHeight
    if (viewH <= 0) return

    let currentY = editorScroll.contentItem.contentY
    let maxY = Math.max(0, editorScroll.contentItem.contentHeight - viewH)

    // Режим печатной машинки: центрируем активную строку по вертикали
    if (mainBar.typewriterMode) {
        let cursorCenter = cursorTop + rect.height / 2
        let viewportCenter = viewH / 2
        let diff = cursorCenter - viewportCenter
        editorScroll.contentItem.contentY = Math.max(0, Math.min(maxY, currentY + diff))
        return
    }

    // Запас отступа сверху и снизу (~70-90px), чтобы курсор не прилипал к краю экрана
    let topMargin = Math.min(70, viewH * 0.2)
    let bottomMargin = Math.max(90, viewH * 0.2)

    if (cursorBottom + bottomMargin > viewH) {
        let diff = (cursorBottom + bottomMargin) - viewH
        editorScroll.contentItem.contentY = Math.max(0, Math.min(maxY, currentY + diff))
    } else if (cursorTop < topMargin) {
        let diff = topMargin - cursorTop
        let firstLineEnd = editorArea.text.indexOf("\n")
        if (editorArea.cursorPosition === 0 || (firstLineEnd !== -1 && editorArea.cursorPosition <= firstLineEnd)) {
            editorScroll.contentItem.contentY = 0
        } else {
            editorScroll.contentItem.contentY = Math.max(0, Math.min(maxY, currentY - diff))
        }
    }
}

function smoothScrollBy(editorScroll, smoothScrollAnim, deltaY) {
    if (!editorScroll || !editorScroll.contentItem) return
    let maxY = Math.max(0, editorScroll.contentItem.contentHeight - editorScroll.availableHeight)
    let cur = smoothScrollAnim.running ? smoothScrollAnim.to : editorScroll.contentItem.contentY
    let target = Math.max(0, Math.min(maxY, cur + deltaY))
    smoothScrollAnim.stop()
    smoothScrollAnim.from = editorScroll.contentItem.contentY
    smoothScrollAnim.to = target
    smoothScrollAnim.start()
}

function toggleFullWidth(mainBar, editorScroll, backend) {
    if (!editorScroll) return
    mainBar.isCustomWidthSetByUser = true
    if (mainBar.customSheetWidth >= editorScroll.availableWidth - 20) {
        mainBar.customSheetWidth = 800
    } else {
        mainBar.customSheetWidth = editorScroll.availableWidth
    }
    mainBar.isCenteredMode = true
    mainBar.updateConfigParameterInText("sheet_width", mainBar.customSheetWidth)
    if (backend && typeof backend.update_sheet_width === "function") {
        backend.update_sheet_width(mainBar.customSheetWidth)
    }
}

function toggleHeaderFooter(mainBar, backend) {
    if (mainBar.showHeader || mainBar.showFooter) {
        mainBar.showHeader = false
        mainBar.showFooter = false
    } else {
        mainBar.showHeader = true
        mainBar.showFooter = true
    }
    if (backend) {
        if (typeof backend.save_header_visible === "function") backend.save_header_visible(mainBar.showHeader)
        if (typeof backend.save_footer_visible === "function") backend.save_footer_visible(mainBar.showFooter)
    }
}

function toggleFooterOnly(mainBar, backend) {
    mainBar.showFooter = !mainBar.showFooter
    if (backend && typeof backend.save_footer_visible === "function") {
        backend.save_footer_visible(mainBar.showFooter)
    }
}

function toggleHeaderOnly(mainBar, backend) {
    mainBar.showHeader = !mainBar.showHeader
    if (backend && typeof backend.save_header_visible === "function") {
        backend.save_header_visible(mainBar.showHeader)
    }
}

function savePinnedState(backend, isHeader, pinned) {
    if (!backend) return
    if (isHeader && typeof backend.save_header_pinned === "function") {
        backend.save_header_pinned(pinned)
    } else if (!isHeader && typeof backend.save_footer_pinned === "function") {
        backend.save_footer_pinned(pinned)
    }
}
