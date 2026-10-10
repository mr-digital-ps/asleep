// components/workspace/pane_controller.js — Контроллер рабочей области панели (скролл, режимы, конфиг, статистика)
.import "../editor/frontmatter_service.js" as Frontmatter

function calculateStats(text) {
    var txt = text || ""
    var words = 0
    var trimmed = txt.trim()
    if (trimmed.length > 0) {
        words = trimmed.split(/\s+/).length
    }
    var bytes = 0
    try {
        bytes = encodeURI(txt).split(/%..|./).length - 1
    } catch(e) {
        bytes = txt.length
    }
    return words + " слов · " + txt.length + " знаков · " + bytes + " байт"
}

function stripExt(name) {
    if (!name) return ""
    return name.replace(/\.txt$/i, "")
}

function formatBreadcrumbTitle(folderUrl, currentFolderName, fileUrl, fileName, activeBlockName) {
    var fileBase = stripExt(fileName) || "Новый документ"
    var folderBase = currentFolderName || ""

    var cleanFolder = ""
    if (folderUrl) {
        try {
            cleanFolder = decodeURIComponent(folderUrl).replace(/^file:\/\/\/?/, "").replace(/\\/g, "/")
        } catch(e) {
            cleanFolder = folderUrl.replace(/^file:\/\/\/?/, "").replace(/\\/g, "/")
        }
        if (!folderBase) {
            var folderParts = cleanFolder.split("/").filter(function(p) { return p.length > 0 })
            if (folderParts.length > 0) {
                folderBase = folderParts[folderParts.length - 1]
            }
        }
    }

    // Если есть относительный путь файла внутри папки
    var subPath = ""
    if (folderUrl && fileUrl) {
        var cleanFile = ""
        try {
            cleanFile = decodeURIComponent(fileUrl).replace(/^file:\/\/\/?/, "").replace(/\\/g, "/")
        } catch(e) {
            cleanFile = fileUrl.replace(/^file:\/\/\/?/, "").replace(/\\/g, "/")
        }
        var fRoot = cleanFolder.toLowerCase()
        var fFull = cleanFile.toLowerCase()
        if (fFull.indexOf(fRoot) === 0) {
            var rel = cleanFile.substring(cleanFolder.length).replace(/^\//, "")
            var relParts = rel.split("/").filter(function(p) { return p.length > 0 })
            if (relParts.length > 1) {
                var midDirs = relParts.slice(0, -1)
                subPath = midDirs.join(".")
            }
        }
    }

    var parts = []
    if (folderBase) parts.push(folderBase)
    if (subPath) parts.push(subPath)
    parts.push(fileBase)
    if (activeBlockName && activeBlockName.trim().length > 0) {
        parts.push(activeBlockName.trim())
    }

    return parts.join(".")
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
            if (mainBar.isActivePane) {
                sheetGraphView.forceActiveFocus()
            }
        }
    } else {
        if (mainBar.isActivePane && editorArea) {
            Qt.callLater(function() {
                if (mainBar.isActivePane && editorArea) {
                    editorArea.forceActiveFocus()
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
        return
    }

    var sourceId = mainBar.fileUrl || ("tab://" + (mainBar.fileName || "doc"))
    if (block.heading && block.content !== undefined) {
        backend.sync_block(sourceId, block.heading, block.content)
    }
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
