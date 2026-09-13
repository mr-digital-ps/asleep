// js/editor/mainbar_controller.js — Контроллер рабочей области редактора (скролл, лист, конфиг, статистика)

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

function handleSheetWidthRequested(mainBar, w) {
    mainBar.isCenteredMode = true
    mainBar.isCustomWidthSetByUser = true
    mainBar.customSheetWidth = w
    mainBar.updateConfigParameterInText("sheet_width", w)
}

function handleSheetWidthCommitted(mainBar, backend, w) {
    mainBar.isCustomWidthSetByUser = true
    mainBar.updateConfigParameterInText("sheet_width", w)
    if (backend && typeof backend.update_sheet_width === "function") {
        backend.update_sheet_width(w)
    }
}

function handleWheelZoomFont(event, editorArea, mainBar, backend) {
    mainBar.isCustomFontSizeSetByUser = true
    if (event.angleDelta.y > 0) {
        editorArea.font.pixelSize = Math.min(36, editorArea.font.pixelSize + 1)
    } else if (event.angleDelta.y < 0) {
        editorArea.font.pixelSize = Math.max(10, editorArea.font.pixelSize - 1)
    }
    mainBar.updateConfigParameterInText("font_size", editorArea.font.pixelSize)
    if (backend && typeof backend.update_font_size === "function") {
        backend.update_font_size(editorArea.font.pixelSize)
    }
}

function handleGraphModeChanged(mainBar, editorScroll, sheetGraphView, editorArea) {
    if (mainBar.isGraphMode) {
        if (editorScroll && editorScroll.contentItem) {
            editorScroll.contentItem.contentY = 0
        }
        if (sheetGraphView) {
            sheetGraphView.activeFileUrl = mainBar.fileUrl
            sheetGraphView.reloadGraph()
            Qt.callLater(function() {
                sheetGraphView.centerOnNode(mainBar.fileUrl)
                if (typeof sheetGraphView.wakeSimulation === "function") {
                    sheetGraphView.wakeSimulation()
                }
                sheetGraphView.forceActiveFocus()
            })
        }
    } else {
        if (editorArea) {
            Qt.callLater(function() {
                editorArea.forceActiveFocus()
            })
        }
    }
}

function handleWheel(mainBar, editorArea, editorScroll, smoothScrollAnim, event, backend) {
    if (mainBar.isGraphMode) {
        event.accepted = false
        return
    }
    if (event.modifiers & Qt.ControlModifier) {
        handleWheelZoomFont(event, editorArea, mainBar, backend)
        event.accepted = true
        return
    }
    var dy = -event.angleDelta.y
    smoothScrollBy(editorScroll, smoothScrollAnim, dy)
    event.accepted = true
}

function handleBlockSyncTriggered(mainBar, editorArea, backend, BlockSync) {
    if (!mainBar || mainBar.isReceivingExternalSync) return
    if (!backend) return
    var block = BlockSync.getCurrentBlockInfo(editorArea, backend)
    if (!block) return

    if (block.shouldAutoFill && block.autoFillContent) {
        mainBar.isReceivingExternalSync = true
        var insertText = "\n" + block.autoFillContent + "\n\n"
        var before = editorArea.text.substring(0, block.contentStart)
        var after = editorArea.text.substring(block.contentEnd)
        editorArea.text = before + insertText + after
        editorArea.cursorPosition = block.contentStart + insertText.length
        mainBar.isReceivingExternalSync = false
        mainBar.showSyncNotice(block.heading)
        return
    }

    var sourceId = mainBar.fileUrl || ("tab://" + (mainBar.fileName || "doc"))
    if (block.heading && block.content !== undefined) {
        backend.sync_block(sourceId, block.heading, block.content)
    }
}

function handleBackgroundDragPressed(mouse, mainBar, state) {
    if (mouse.button === Qt.LeftButton) {
        mainBar.paneActivated()
        if (mainBar.isSplitMode) {
            state.pressX = mouse.x
            state.pressY = mouse.y
            state.isPressed = true
            state.isDragging = false
        }
    }
}

function handleBackgroundDragMoved(mouse, mainBar, containerItem, state) {
    if (!state.isPressed || !mainBar.isSplitMode) return
    var dx = mouse.x - state.pressX
    var dy = mouse.y - state.pressY
    var dist = Math.hypot(dx, dy)
    var globalP = containerItem.mapToGlobal(mouse.x, mouse.y)

    if (!state.isDragging) {
        if (dist > 8 && !mainBar.isEmpty) {
            state.isDragging = true
            mainBar.fileDragStarted(mainBar.fileUrl, mainBar.fileName, globalP.x, globalP.y)
        }
    } else {
        mainBar.fileDragMoved(globalP.x, globalP.y)
    }
}

function handleBackgroundDragReleased(mouse, mainBar, containerItem, state) {
    if (mouse.button === Qt.LeftButton) {
        state.isPressed = false
        if (state.isDragging && mainBar.isSplitMode) {
            state.isDragging = false
            var globalP = containerItem.mapToGlobal(mouse.x, mouse.y)
            mainBar.fileDragEnded(mainBar.fileUrl, mainBar.fileName, globalP.x, globalP.y)
        }
    }
}

function calculateFooterY(mainBar, docFooter, editorCanvas, editorScroll) {
    if (mainBar.isGraphMode) {
        return docFooter.parent.height - docFooter.height
    }
    var naturalY = editorCanvas.y + editorCanvas.height + 4
    var screenBottomY = (editorScroll && editorScroll.contentItem)
        ? (editorScroll.contentItem.contentY + editorScroll.availableHeight - docFooter.height)
        : naturalY
    if (mainBar.isFooterPinned) {
        return screenBottomY
    }
    return Math.max(naturalY, screenBottomY)
}

function initMainBar(mainBar, editorArea, backend) {
    if (backend && typeof backend.get_current_config === "function") {
        try {
            var cfgStr = backend.get_current_config()
            if (cfgStr) {
                mainBar.applyConfig(JSON.parse(cfgStr))
            }
        } catch(e) {}
    }
    initSessionConfig(mainBar, backend)
    if (backend) {
        if (typeof backend.set_editor_line_height === "function") {
            backend.set_editor_line_height(editorArea, mainBar.editorLineHeightPercent)
        }
        if (typeof backend.attach_highlighter === "function") {
            backend.attach_highlighter(editorArea)
        }
    }
}

function handleLineHeightChanged(editorArea, mainBar, backend) {
    if (backend && typeof backend.set_editor_line_height === "function") {
        backend.set_editor_line_height(editorArea, mainBar.editorLineHeightPercent)
    }
}

function handleFileUrlChanged(editorArea, mainBar, backend) {
    if (backend) {
        if (typeof backend.set_editor_line_height === "function") {
            Qt.callLater(function() { backend.set_editor_line_height(editorArea, mainBar.editorLineHeightPercent) })
        }
        if (typeof backend.attach_highlighter === "function") {
            Qt.callLater(function() { backend.attach_highlighter(editorArea) })
        }
    }
}

function handleTextChangedByUser(mainBar, blockSyncTimer, activeFocus) {
    if (!mainBar.isReceivingExternalSync && activeFocus) {
        blockSyncTimer.restart()
    }
    if (activeFocus) {
        mainBar.requestEnsureCursorVisible()
    }
}

function handleFontSizeChanged(mainBar, backend, sz) {
    mainBar.isCustomFontSizeSetByUser = true
    mainBar.updateConfigParameterInText("font_size", sz)
    if (backend && typeof backend.update_font_size === "function") {
        backend.update_font_size(sz)
    }
}

function drawGutterDots(canvas, editorArea, width, height, activeColor, textColor) {
    if (!canvas || typeof canvas.getContext !== "function") return
    var ctx = canvas.getContext("2d")
    ctx.clearRect(0, 0, width, height)
    if (!editorArea) return
    var txt = editorArea.text
    if (txt === undefined || txt === null) return

    var lines = txt.split("\n")
    var pos = 0
    var curPos = editorArea.cursorPosition
    var centerX = width / 2

    var fontSize = (editorArea.font && editorArea.font.pixelSize) ? editorArea.font.pixelSize : 15
    var scale = Math.max(0.6, Math.min(2.5, fontSize / 15.0))

    for (var i = 0; i < lines.length; i++) {
        var lineLen = lines[i].length
        var isCurrentLine = (curPos >= pos && curPos <= pos + lineLen)
        var r = editorArea.positionToRectangle(pos)
        var dotY = r.y + (r.height / 2)

        ctx.beginPath()
        var radius = (isCurrentLine ? 3.2 : 2.2) * scale
        ctx.arc(centerX, dotY, radius, 0, 2 * Math.PI)
        ctx.fillStyle = isCurrentLine ? activeColor : textColor
        ctx.fill()

        pos += lineLen + 1
    }
}


