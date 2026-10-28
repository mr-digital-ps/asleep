// components/workspace/pane_controller.js — Контроллер рабочей области панели (скролл, режимы, конфиг, статистика)
.import "../editor/frontmatter_service.js" as Frontmatter

function pluralize(n, one, few, many) {
    var abs = Math.abs(n) % 100
    var rem = abs % 10
    if (abs > 10 && abs < 20) return many
    if (rem > 1 && rem < 5) return few
    if (rem === 1) return one
    return many
}

function formatNumber(num) {
    return String(num).replace(/\B(?=(\d{3})+(?!\d))/g, " ")
}

function calculateStats(text, blockCount, cursorPos, canvasX, canvasY) {
    var txt = text || ""
    var words = 0
    var trimmed = txt.trim()
    if (trimmed.length > 0) {
        words = trimmed.split(/\s+/).length
    }
    var chars = txt.length
    var readMin = Math.max(1, Math.round(words / 200))
    if (words === 0) readMin = 0
    var bCount = (typeof blockCount === "number") ? blockCount : 0

    // Позиция курсора (Стр:Кол)
    var line = 1
    var col = 1
    var pos = (typeof cursorPos === "number") ? Math.min(cursorPos, txt.length) : 0
    if (pos > 0 && txt.length > 0) {
        var textBefore = txt.substring(0, pos)
        var lastNewline = textBefore.lastIndexOf("\n")
        var lines = textBefore.split("\n")
        line = lines.length
        col = (lastNewline === -1) ? (pos + 1) : (pos - lastNewline)
    }

    var cx = (typeof canvasX === "number") ? Math.round(canvasX) : 0
    var cy = (typeof canvasY === "number") ? Math.round(canvasY) : 0

    var parts = [
        formatNumber(words) + " " + pluralize(words, "слово", "слова", "слов"),
        formatNumber(chars) + " " + pluralize(chars, "знак", "знака", "знаков"),
        "~" + readMin + " мин",
        bCount + " " + pluralize(bCount, "блок", "блока", "блоков"),
        "Стр " + line + ":" + col,
        "(" + cx + ", " + cy + ")"
    ]

    return parts.join(" · ")
}

function stripExt(name) {
    if (!name) return ""
    return name.replace(/\.txt$/i, "")
}

function formatBreadcrumbTitle(folderUrl, currentFolderName, fileUrl, fileName, activeBlockName) {
    if (activeBlockName && activeBlockName.trim().length > 0) {
        return activeBlockName.trim()
    }
    return stripExt(fileName) || "Новый документ"
}


function updateConfigParameterInText(fileName, text, key, value) {
    return Frontmatter.updateConfigParameterInText(fileName, text, key, value)
}

function applyEditorConfig(mainBar, editorArea, cfg, backend) {
    return Frontmatter.applyEditorConfig(mainBar, editorArea, cfg, backend)
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

    if (mainBar.typewriterMode) {
        let cursorCenter = cursorTop + rect.height / 2
        let viewportCenter = viewH / 2
        let diff = cursorCenter - viewportCenter
        editorScroll.contentItem.contentY = Math.max(0, Math.min(maxY, currentY + diff))
        return
    }

    let topMargin = 20
    let bottomMargin = 40

    if (cursorBottom + bottomMargin > viewH) {
        let diff = (cursorBottom + bottomMargin) - viewH
        editorScroll.contentItem.contentY = Math.max(0, Math.min(maxY, currentY + diff))
    } else if (cursorTop < topMargin) {
        let diff = topMargin - cursorTop
        if (editorArea.cursorPosition === 0) {
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



function toggleHeaderOnly(mainBar, backend) {
    mainBar.showHeader = !mainBar.showHeader
    if (backend && typeof backend.save_header_visible === "function") {
        backend.save_header_visible(mainBar.showHeader)
    }
}

function savePinnedState(backend, isHeader, pinned) {
    return Frontmatter.savePinnedState(backend, isHeader, pinned)
}

function handleSheetWidthRequested(mainBar, w) {
    mainBar.isCenteredMode = true
    mainBar.customSheetWidth = w
    mainBar.updateConfigParameterInText("sheet_width", w)
}

function handleSheetWidthCommitted(mainBar, backend, w) {
    mainBar.updateConfigParameterInText("sheet_width", w)
    if (backend && typeof backend.update_sheet_width === "function") {
        backend.update_sheet_width(w)
    }
}

function handleWheelZoomFont(event, editorArea, mainBar, backend) {
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

function handleGraphModeChanged(mainBar, editorScroll, sheetGraphView, editorArea, smoothScrollAnim) {
    if (mainBar.isGraphMode) {
        if (smoothScrollAnim && smoothScrollAnim.running) {
            smoothScrollAnim.stop()
        }
        if (editorScroll && editorScroll.contentItem) {
            editorScroll.contentItem.contentY = 0
        }
        if (sheetGraphView) {
            sheetGraphView.activeFileUrl = mainBar.fileUrl
            if (sheetGraphView.sim && sheetGraphView.sim.nodes && sheetGraphView.sim.nodes.length > 0) {
                if (mainBar.fileUrl && !sheetGraphView.centerOnNode(mainBar.fileUrl)) {
                    Qt.callLater(function() {
                        if (sheetGraphView && mainBar.isGraphMode && mainBar.fileUrl) {
                            sheetGraphView.centerOnNode(mainBar.fileUrl)
                        }
                    })
                }
                if (typeof sheetGraphView.wakeSimulation === "function") {
                    sheetGraphView.wakeSimulation()
                } else if (sheetGraphView.canvas) {
                    sheetGraphView.canvas.requestPaint()
                }
            } else {
                sheetGraphView.reloadGraph()
                if (mainBar.fileUrl && !sheetGraphView.centerOnNode(mainBar.fileUrl)) {
                    Qt.callLater(function() {
                        if (sheetGraphView && mainBar.isGraphMode && mainBar.fileUrl) {
                            sheetGraphView.centerOnNode(mainBar.fileUrl)
                        }
                    })
                }
            }
            sheetGraphView.forceActiveFocus()
        }
    } else {
        if (editorArea) {
            Qt.callLater(function() {
                if (editorArea) {
                    editorArea.forceActiveFocus()
                }
                if (mainBar.paperSheet) {
                    if (typeof mainBar.paperSheet.reapplyEditorStyling === "function") {
                        mainBar.paperSheet.reapplyEditorStyling()
                    }
                    if (mainBar.paperSheet.editorCanvas) {
                        var ec = mainBar.paperSheet.editorCanvas
                        if (typeof ec.updateBlocks === "function") ec.updateBlocks()
                        if (typeof ec.initializeLiveModeIfReady === "function") ec.initializeLiveModeIfReady()
                        if (ec.horizontalRuleOverlay && typeof ec.horizontalRuleOverlay.updateRules === "function") {
                            ec.horizontalRuleOverlay.updateRules()
                        }
                        if (ec.editorGutter && typeof ec.editorGutter.updateBlocks === "function") {
                            ec.editorGutter.updateBlocks()
                        }
                    }
                }
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
        if (mainBar.paperSheet && typeof mainBar.paperSheet.reapplyEditorStyling === "function") {
            mainBar.paperSheet.reapplyEditorStyling()
        }
        return
    }

    var sourceId = mainBar.fileUrl || ("tab://" + (mainBar.fileName || "doc"))
    if (block.heading && block.content !== undefined) {
        backend.sync_block(sourceId, block.heading, block.content)
    }
}


function initMainBar(mainBar, editorArea, backend) {
    if (backend && typeof backend.get_session_config === "function") {
        try {
            var sess = backend.get_session_config()
            if (sess && typeof mainBar.applySessionConfig === "function") {
                mainBar.applySessionConfig(sess)
            }
        } catch(e) {}
    }
    if (backend && typeof backend.get_current_config === "function") {
        try {
            var cfgStr = backend.get_current_config()
            if (cfgStr) {
                mainBar.applyConfig(JSON.parse(cfgStr))
            }
        } catch(e) {}
    }
    if (backend) {
        if (typeof backend.set_editor_line_height === "function") {
            backend.set_editor_line_height(editorArea, mainBar.editorLineHeightPercent)
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
    mainBar.updateConfigParameterInText("font_size", sz)
    if (backend && typeof backend.update_font_size === "function") {
        backend.update_font_size(sz)
    }
}
