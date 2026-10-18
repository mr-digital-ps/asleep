import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "./editor_shortcuts.js" as Shortcuts
import "./editor_keys.js" as EditorKeys
import "./block_scanner.js" as BlockScanner
import "./transclusion_engine.js" as TransclusionEngine
import "../theme"


RowLayout {
    id: canvasRoot
    spacing: 0

    property int barSize: Theme.barSize
    property bool showLineDots: true
    property int tabSize: Theme.defaultTabSize
    property real availableHeight: 600
    property bool hasHeader: true
    property bool hasFooter: true

    property bool isLiveMode: true
    property var blocks: []
    property var collapsedBlocks: ({})
    onCollapsedBlocksChanged: {
        if (editorGutter) {
            editorGutter.collapsedBlocks = collapsedBlocks
        }
    }
    property var activeTransclusions: ({})
    property var blockFoldState: ({})
    property bool hasInitializedLiveMode: false

    property alias editorArea: editorArea
    property alias text: editorArea.text

    signal paneActivated()
    signal cursorVisibilityRequested()
    signal textChangedByUser()
    signal scrollRequested(real dy)
    signal scrollToTopRequested()
    signal fontSizeChanged(int newSize)
    signal closeRequested()
    signal detachRequested()
    signal syncNoticeRequested(string title)
    signal toggleHistoryRequested()
    signal toggleInfoRequested()
    signal toggleSearchRequested()
    signal togglePathRequested()
    signal showFileNameRequested()
    signal toggleTabsRequested()
    signal toggleHeaderRequested()
    signal toggleCenteredModeRequested()
    signal toggleLiveModeRequested()
    signal toggleSourceModeRequested()
    signal saveRequested()
    signal openRequested()
    signal newRequested()
    signal toggleGraphRequested()
    signal panelDragStarted(var mouse, var item)
    signal panelDragUpdated(var mouse, var item)
    signal panelDragFinished()


    onIsLiveModeChanged: {
        if (isLiveMode) {
            expandTransclusions()
            if (!hasInitializedLiveMode) {
                if (activeTransclusions) {
                    var newFoldState = Object.assign({}, blockFoldState)
                    for (var tKey in activeTransclusions) {
                        if (newFoldState[tKey] === undefined) {
                            newFoldState[tKey] = true
                        }
                    }
                    blockFoldState = newFoldState
                }
                hasInitializedLiveMode = true
            }
            applyBlockFoldState()
        } else {
            unfoldAllBlocks()
            collapseTransclusions()
        }
        updateBlocks()
        if (editorGutter) editorGutter.isLiveMode = isLiveMode
        if (typeof backend !== "undefined" && backend && typeof backend.set_editor_live_mode === "function") {
            backend.set_editor_live_mode(editorArea, isLiveMode)
        }
    }

    function initializeLiveModeIfReady() {
        if (!isLiveMode || hasInitializedLiveMode) return
        expandTransclusions()
        if (activeTransclusions) {
            var newFoldState = Object.assign({}, blockFoldState)
            for (var tKey in activeTransclusions) {
                if (newFoldState[tKey] === undefined) {
                    newFoldState[tKey] = true
                }
            }
            blockFoldState = newFoldState
        }
        hasInitializedLiveMode = true
        applyBlockFoldState()
    }

    function applyBlockFoldState() {
        if (!isLiveMode || !editorArea || !editorArea.text) return
        var currentBlocks = BlockScanner.scanBlocks(editorArea.text)
        if (!currentBlocks || currentBlocks.length === 0) return

        var toCollapse = []
        for (var b = 0; b < currentBlocks.length; b++) {
            var blk = currentBlocks[b]
            if (blockFoldState && blockFoldState[blk.name] === true) {
                if (!collapsedBlocks || !collapsedBlocks[blk.id]) {
                    toCollapse.push(blk)
                }
            }
        }
        if (toCollapse.length === 0) return

        // Сворачиваем блоки снизу вверх, чтобы не нарушать индексы строк
        toCollapse.sort(function(a, b) { return b.startLine - a.startLine })

        var lines = editorArea.text.split("\n")
        var newCollapsed = Object.assign({}, collapsedBlocks || {})

        for (var i = 0; i < toCollapse.length; i++) {
            var cBlk = toCollapse[i]
            var sL = cBlk.startLine
            var eL = cBlk.endLine
            if (sL >= 0 && eL < lines.length && sL < eL) {
                var blockLines = lines.slice(sL, eL + 1)
                var matchIndent = lines[sL].match(/^(\s*)/)
                var indent = matchIndent ? matchIndent[1] : ""
                var headerLine = indent + cBlk.name + " ...."

                newCollapsed[cBlk.id] = {
                    id: cBlk.id,
                    name: cBlk.name,
                    headerLine: sL,
                    lines: blockLines
                }
                lines = lines.slice(0, sL).concat([headerLine]).concat(lines.slice(eL + 1))
            }
        }

        collapsedBlocks = newCollapsed
        if (editorGutter) editorGutter.collapsedBlocks = newCollapsed

        var curPos = editorArea.cursorPosition
        editorArea.text = lines.join("\n")
        editorArea.cursorPosition = Math.min(curPos, editorArea.text.length)
        updateBlocks()
    }

    function unfoldAllBlocks() {
        if (!editorArea || !editorArea.text) {
            collapsedBlocks = ({})
            if (editorGutter) editorGutter.collapsedBlocks = ({})
            return
        }
        var currentText = editorArea.text
        var lines = currentText.split("\n")
        var changed = false

        if (collapsedBlocks && Object.keys(collapsedBlocks).length > 0) {
            var remaining = Object.assign({}, collapsedBlocks)
            for (var i = lines.length - 1; i >= 0; i--) {
                var lineTrimmed = lines[i].trim()
                for (var cId in remaining) {
                    var cBlk = remaining[cId]
                    if (cBlk && cBlk.name + " ...." === lineTrimmed) {
                        lines = lines.slice(0, i).concat(cBlk.lines).concat(lines.slice(i + 1))
                        delete remaining[cId]
                        changed = true
                        break
                    }
                }
            }
        }

        collapsedBlocks = ({})
        if (editorGutter) editorGutter.collapsedBlocks = ({})

        if (changed) {
            var curPos = editorArea.cursorPosition
            editorArea.text = lines.join("\n")
            editorArea.cursorPosition = Math.min(curPos, editorArea.text.length)
        }
    }

    function resetFolding() {
        unfoldAllBlocks()
        activeTransclusions = ({})
        blockFoldState = ({})
        hasInitializedLiveMode = false
    }

    function expandTransclusions() {
        if (!isLiveMode || !editorArea || !editorArea.text || typeof backend === "undefined" || !backend) return
        var res = TransclusionEngine.expandTransclusions(editorArea.text, backend, activeTransclusions)
        if (res.changed) {
            var curPos = editorArea.cursorPosition
            activeTransclusions = res.map
            editorArea.text = res.text
            editorArea.cursorPosition = Math.min(curPos, res.text.length)
            updateBlocks()
            if (typeof backend !== "undefined" && backend && typeof backend.set_editor_line_height === "function") {
                Qt.callLater(function() {
                    var lh = (typeof workspacePane !== "undefined" && workspacePane && workspacePane.editorLineHeightPercent) ? workspacePane.editorLineHeightPercent : 135.0
                    backend.set_editor_line_height(editorArea, lh)
                })
            }
        }
    }

    function collapseTransclusions() {
        if (!editorArea || !editorArea.text) return
        var res = TransclusionEngine.collapseTransclusions(editorArea.text, activeTransclusions)
        if (res.changed) {
            var curPos = editorArea.cursorPosition
            activeTransclusions = ({})
            editorArea.text = res.text
            editorArea.cursorPosition = Math.min(curPos, res.text.length)
            updateBlocks()
            if (typeof backend !== "undefined" && backend && typeof backend.set_editor_line_height === "function") {
                Qt.callLater(function() {
                    var lh = (typeof workspacePane !== "undefined" && workspacePane && workspacePane.editorLineHeightPercent) ? workspacePane.editorLineHeightPercent : 135.0
                    backend.set_editor_line_height(editorArea, lh)
                })
            }
        }
    }

    function updateBlocks() {
        if (!editorArea || !editorArea.text || !isLiveMode) {
            blocks = []
        } else {
            blocks = BlockScanner.scanBlocks(editorArea.text)
        }
        if (editorGutter) {
            editorGutter.blocks = blocks
        }
    }

    function toggleBlockFold(block, lineIndex) {
        if (!isLiveMode) return // Сворачивание и разворачивание работает ТОЛЬКО в Live Mode!
        if (!editorArea || !editorArea.text) return
        var lines = editorArea.text.split("\n")

        if (collapsedBlocks && collapsedBlocks[block.id]) {
            // Развертывание блока
            var saved = collapsedBlocks[block.id]
            var targetL = lineIndex
            var targetHeader = saved.name + " ...."
            if (targetL < 0 || targetL >= lines.length || lines[targetL].trim() !== targetHeader) {
                targetL = -1
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].trim() === targetHeader) {
                        targetL = i
                        break
                    }
                }
            }
            if (targetL >= 0 && targetL < lines.length) {
                var newLines = lines.slice(0, targetL).concat(saved.lines).concat(lines.slice(targetL + 1))
                var newMap = Object.assign({}, collapsedBlocks)
                delete newMap[block.id]
                collapsedBlocks = newMap
                if (editorGutter) editorGutter.collapsedBlocks = newMap

                var newFoldState = Object.assign({}, blockFoldState)
                newFoldState[saved.name] = false
                blockFoldState = newFoldState

                editorArea.text = newLines.join("\n")
            }
        } else {
            // Сворачивание блока
            var startL = block.startLine
            var endL = block.endLine
            if (startL < 0 || endL >= lines.length || startL >= endL) return

            var blockLines = lines.slice(startL, endL + 1)
            var matchIndent = lines[startL].match(/^(\s*)/)
            var indent = matchIndent ? matchIndent[1] : ""
            var collapsedHeader = indent + block.name + " ...."

            var newMap = Object.assign({}, collapsedBlocks)
            newMap[block.id] = {
                id: block.id,
                name: block.name,
                headerLine: startL,
                lines: blockLines
            }
            collapsedBlocks = newMap
            if (editorGutter) editorGutter.collapsedBlocks = newMap

            var newFoldState = Object.assign({}, blockFoldState)
            newFoldState[block.name] = true
            blockFoldState = newFoldState

            var newLines = lines.slice(0, startL).concat([collapsedHeader]).concat(lines.slice(endL + 1))
            editorArea.text = newLines.join("\n")
        }
        updateBlocks()
        if (typeof backend !== "undefined" && backend && typeof backend.set_editor_line_height === "function") {
            Qt.callLater(function() {
                var lh = (typeof workspacePane !== "undefined" && workspacePane && workspacePane.editorLineHeightPercent) ? workspacePane.editorLineHeightPercent : 135.0
                backend.set_editor_line_height(editorArea, lh)
            })
        }
    }

    function getFullTextWithoutFolding() {
        if (!editorArea || !editorArea.text) return ""
        var currentText = editorArea.text
        var lines = currentText.split("\n")

        // 1. Восстановление свернутых блоков Имя ....
        if (collapsedBlocks && Object.keys(collapsedBlocks).length > 0) {
            var remaining = Object.assign({}, collapsedBlocks)
            for (var i = lines.length - 1; i >= 0; i--) {
                var lineTrimmed = lines[i].trim()
                for (var cId in remaining) {
                    var cBlk = remaining[cId]
                    if (cBlk && cBlk.name + " ...." === lineTrimmed) {
                        lines = lines.slice(0, i).concat(cBlk.lines).concat(lines.slice(i + 1))
                        delete remaining[cId]
                        break
                    }
                }
            }
        }

        // 2. Сворачивание развернутых трансклюзий к каноническому виду вызовов Файл.Блок() / Блок()
        var textUnfolded = lines.join("\n")
        if (activeTransclusions && Object.keys(activeTransclusions).length > 0) {
            var res = TransclusionEngine.collapseTransclusions(textUnfolded, activeTransclusions)
            return res.text
        }
        return textUnfolded
    }

    function updateBracketHighlights() {
        if (bracketHighlightOverlay) {
            bracketHighlightOverlay.updateBracketHighlights()
        }
    }

    Layout.preferredHeight: editorArea.contentHeight

    // Левая полоса 36px для нумерации строк и фокуса
    EditorGutter {
        id: editorGutter
        barSize: canvasRoot.barSize
        showDots: canvasRoot.showLineDots
        editorArea: editorArea
        isLiveMode: canvasRoot.isLiveMode
        blocks: canvasRoot.blocks
        collapsedBlocks: canvasRoot.collapsedBlocks
        Layout.preferredWidth: barSize
        Layout.fillHeight: true
        onActivated: canvasRoot.paneActivated()
        onDragStarted: (mouse, item) => canvasRoot.panelDragStarted(mouse, item)
        onDragUpdated: (mouse, item) => canvasRoot.panelDragUpdated(mouse, item)
        onDragFinished: () => canvasRoot.panelDragFinished()
        onToggleBlockFoldRequested: (block, lineIndex) => canvasRoot.toggleBlockFold(block, lineIndex)
    }

    // Текстовое поле документа
    TextArea {
        id: editorArea
        Layout.fillWidth: true
        Layout.fillHeight: true
        leftPadding: 0
        rightPadding: 0
        topPadding: 6
        bottomPadding: 0

        font.pixelSize: Theme.defaultFontSize
        font.family: Theme.fontFamily
        wrapMode: TextArea.Wrap
        selectByMouse: true
        color: Theme.textPrimary
        selectionColor: "transparent"
        selectedTextColor: Theme.textPrimary
        placeholderText: "Начните вводить текст..."
        placeholderTextColor: Theme.textMuted

        cursorDelegate: Item {
            id: cursorWrapper
            visible: editorArea.activeFocus
            Rectangle {
                id: customCursor
                width: 2
                height: parent.height
                anchors.centerIn: parent
                color: Theme.cursorColor
            }
        }

        // Оверлей скрытия фигурных скобок в Live Mode
        BlockSyntaxConcealOverlay {
            id: blockSyntaxConcealOverlay
            editorArea: editorArea
            isLiveMode: canvasRoot.isLiveMode
            blocks: canvasRoot.blocks
        }

        background: Item {
            // Эстетичный оверлей скруглённого блочного выделения (как в современных IDE)
            SelectionHighlightOverlay {
                id: selectionHighlightOverlay
                editorArea: editorArea
            }


            // Оверлей подсветки парных скобок
            BracketHighlightOverlay {
                id: bracketHighlightOverlay
                editorArea: editorArea
            }

            // Оверлей разделительных горизонтальных линий (---)
            HorizontalRuleOverlay {
                id: horizontalRuleOverlay
                objectName: "horizontalRuleOverlay"
                editorArea: editorArea
                isLiveMode: canvasRoot.isLiveMode
            }
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                if (event.modifiers & Qt.ControlModifier) {
                    if (event.angleDelta.y > 0) {
                        editorArea.font.pixelSize = Math.min(36, editorArea.font.pixelSize + 1)
                    } else if (event.angleDelta.y < 0) {
                        editorArea.font.pixelSize = Math.max(10, editorArea.font.pixelSize - 1)
                    }
                    canvasRoot.fontSizeChanged(editorArea.font.pixelSize)
                    event.accepted = true
                } else {
                    let dy = -event.angleDelta.y
                    canvasRoot.scrollRequested(dy)
                    event.accepted = true
                }
            }
        }

        onActiveFocusChanged: {
            if (activeFocus) {
                canvasRoot.paneActivated()
                canvasRoot.cursorVisibilityRequested()
            }
            bracketHighlightOverlay.updateBracketHighlights()
        }

        onCursorPositionChanged: {
            if (activeFocus) {
                canvasRoot.cursorVisibilityRequested()
            }
            bracketHighlightOverlay.updateBracketHighlights()
        }

        onSelectionStartChanged: bracketHighlightOverlay.updateBracketHighlights()
        onSelectionEndChanged: bracketHighlightOverlay.updateBracketHighlights()

        Keys.onShortcutOverride: (event) => {
            EditorKeys.handleShortcutOverride(event, canvasRoot, editorArea, Shortcuts)
        }

        Keys.onTabPressed: (event) => {
            Shortcuts.handleTab(editorArea, false, canvasRoot.tabSize)
            event.accepted = true
        }
        Keys.onBacktabPressed: (event) => {
            Shortcuts.handleTab(editorArea, true, canvasRoot.tabSize)
            event.accepted = true
        }

        Keys.onBackPressed: (event) => {
            if (Shortcuts.handleSmartBackspace(editorArea)) {
                event.accepted = true
                return
            }
            event.accepted = false
        }

        Keys.onDeletePressed: (event) => {
            if (Shortcuts.handleSmartDelete(editorArea)) {
                event.accepted = true
                return
            }
            event.accepted = false
        }

        Keys.onSpacePressed: (event) => {
            if (Shortcuts.handleAutoPair(editorArea, " ")) {
                event.accepted = true
                return
            }
            event.accepted = false
        }

        Keys.onPressed: (event) => {
            EditorKeys.handleKeyPressed(event, canvasRoot, editorArea, Shortcuts)
        }

        Keys.onReleased: (event) => {
            if (event.modifiers & Qt.ControlModifier) {
                if (event.key === Qt.Key_B || event.key === Qt.Key_I) {
                    event.accepted = true
                    return
                }
            }
        }

        Keys.onReturnPressed: (event) => {
            event.accepted = Shortcuts.handleSmartEnter(editorArea, (typeof backend !== "undefined" ? backend : null), (t) => canvasRoot.syncNoticeRequested(t))
        }
        Keys.onEnterPressed: (event) => {
            event.accepted = Shortcuts.handleSmartEnter(editorArea, (typeof backend !== "undefined" ? backend : null), (t) => canvasRoot.syncNoticeRequested(t))
        }

        Keys.onUpPressed: (event) => {
            let firstLineEnd = text.indexOf("\n")
            let isFirstLine = (firstLineEnd === -1) ? true : (cursorPosition <= firstLineEnd)
            if (cursorPosition === 0 || isFirstLine) {
                canvasRoot.scrollToTopRequested()
            }
            event.accepted = false
        }

        onTextChanged: {
            canvasRoot.textChangedByUser()
            canvasRoot.updateBlocks()
            bracketHighlightOverlay.updateBracketHighlights()
        }

        onPressed: canvasRoot.paneActivated()

        Component.onCompleted: {
            if (typeof backend !== "undefined" && backend && typeof backend.set_editor_live_mode === "function") {
                Qt.callLater(function() {
                    backend.set_editor_live_mode(editorArea, canvasRoot.isLiveMode)
                    canvasRoot.initializeLiveModeIfReady()
                })
            }
        }
    }

    // Правая полоса 36px для скроллбара (предотвращает наложение на текст)
    Item {
        id: rightGutterSpacer
        Layout.preferredWidth: canvasRoot.barSize
        Layout.fillHeight: true
    }
}
