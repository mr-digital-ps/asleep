import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../js/editor/mainbar_controller.js" as Controller
import "../graph"
import "../theme"
import "canvas"
import "chrome"

Rectangle {
    id: sheetRoot

    // Основные свойства и привязки
    property int barSize: 36
    property string fileName: "Новый документ"
    property string fileUrl: ""
    property string folderUrl: ""
    property var openFileUrls: []
    property bool isCenteredMode: true
    property real customSheetWidth: 800
    property real minSheetWidth: 380
    property bool isSplitMode: false
    property bool isActivePane: false
    property bool isEmpty: false
    property string customFontFamily: "Segoe UI, Inter, -apple-system, sans-serif"
    property bool typewriterMode: false
    property bool focusMode: false
    property bool isHeaderPinned: false
    property bool isFooterPinned: true
    property bool showHeader: true
    property bool showFooter: true
    property bool showLineDots: true
    property int tabSize: 4
    property real scrollY: 0
    property string statsString: "0 слов · 0 знаков"
    property real availableHeight: 600
    property real viewHeight: availableHeight
    property var containerItem: null
    property var editorScroll: null

    // Режимы графа и аутлайнера
    property bool isGraphMode: false
    property bool isLocalGraphMode: false
    property bool isOutlineMode: false
    readonly property string graphStatsText: sheetGraphView ? sheetGraphView.getGraphStats() : ""
    readonly property bool isProjectTree: {
        if (typeof backend !== "undefined" && backend && typeof backend.is_project_structure_file === "function") {
            return backend.is_project_structure_file(sheetRoot.fileName)
        }
        return sheetRoot.fileName === "_Структура.md"
    }
    property var _liveDraftText: undefined

    onFileUrlChanged: {
        _liveDraftText = undefined
        if (editorArea) editorArea.readOnly = false
    }

    // Экспорт внутренних компонентов наружу
    property alias editorCanvas: editorCanvas
    property alias editorArea: editorCanvas.editorArea
    property alias text: editorCanvas.text
    property alias titleField: docHeader.titleField
    property alias docHeader: docHeader
    property alias docFooter: docFooter
    property alias sheetGraphView: sheetGraphView
    property alias sheetOutliner: sheetOutliner
    property alias leftHandle: leftHandle
    property alias rightHandle: rightHandle
    readonly property bool isResizingSheet: (leftHandle && (leftHandle.containsMouse || leftHandle.pressed)) || (rightHandle && (rightHandle.containsMouse || rightHandle.pressed))

    // Сигналы
    signal paneActivated()
    signal titleChangedByUser(string newTitle)
    signal closeRequested()
    signal detachRequested()
    signal saveRequested()
    signal newRequested()
    signal newSplitRequested()
    signal toggleGraphRequested()
    signal toggleSplitRequested()
    signal openRequested()
    signal openSplitRequested()
    signal nodeSelected(string fileUrl, string label)
    signal closeGraphRequested()
    signal openStructureRequested()
    signal cursorVisibilityRequested()
    signal toggleHeaderFooterRequested()
    signal toggleFooterRequested()
    signal toggleHeaderRequested()
    signal toggleCenteredModeRequested()
    signal textChangedByUser()
    signal scrollRequested(real dy)
    signal scrollToTopRequested()
    signal fontSizeChanged(int newSize)
    signal syncNoticeRequested(string title)
    signal sheetWidthRequested(real newWidth)
    signal sheetWidthCommitted(real finalWidth)
    signal toggleFullWidthRequested()
    signal headerPinToggled(bool pinned)
    signal footerPinToggled(bool pinned)
    signal outlineModeToggled()
    signal textChangedByOutliner(string newText)
    signal snapshotSelected(string snapshotId)
    signal liveRequested()

    visible: !isEmpty || isGraphMode
    width: isCenteredMode ? Math.min(parent.width, Math.max(minSheetWidth, customSheetWidth)) : parent.width
    height: parent ? parent.height : availableHeight
    y: 0
    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
    anchors.top: parent ? parent.top : undefined

    color: Theme.bgPaper

    opacity: (isSplitMode && !isActivePane) ? 0.55 : 1.0
    Behavior on opacity {
        NumberAnimation { duration: 150 }
    }

    // Фокус-режим: затемнение неактивных строк
    EditorFocusDimmer {
        editorArea: editorCanvas.editorArea
        focusMode: sheetRoot.focusMode
    }

    // 1. Верхний контейнер заголовка (с поддержкой закрепления Sticky Header)
    EditorHeader {
        id: docHeader
        barSize: sheetRoot.barSize
        anchors.left: parent.left
        anchors.right: parent.right
        fileName: sheetRoot.fileName
        fileUrl: sheetRoot.fileUrl
        isSplitMode: sheetRoot.isSplitMode
        isActivePane: sheetRoot.isActivePane
        isEmpty: sheetRoot.isEmpty
        isPinned: sheetRoot.isHeaderPinned
        isGraphMode: sheetRoot.isGraphMode
        isLocalGraphMode: sheetRoot.isLocalGraphMode
        isOutlineMode: sheetRoot.isOutlineMode
        scrollY: sheetRoot.scrollY
        contentLeftPadding: editorArea.leftPadding
        contentRightPadding: editorArea.rightPadding
        visible: sheetRoot.showHeader && (!sheetRoot.isEmpty || sheetRoot.isGraphMode)

        onTitleCommitted: (newTitle) => sheetRoot.titleChangedByUser(newTitle)
        onPaneActivated: sheetRoot.paneActivated()
        onPinToggled: {
            sheetRoot.isHeaderPinned = !sheetRoot.isHeaderPinned
            sheetRoot.headerPinToggled(sheetRoot.isHeaderPinned)
        }
        onToggleOutlineRequested: sheetRoot.outlineModeToggled()
        onOpenStructureRequested: sheetRoot.openStructureRequested()
    }

    // 2. Рабочая область документа (Gutter + TextArea + шорткаты)
    EditorCanvas {
        id: editorCanvas
        visible: !sheetRoot.isGraphMode && !sheetRoot.isEmpty && !sheetRoot.isOutlineMode
        anchors.top: parent.top
        anchors.topMargin: sheetRoot.showHeader ? 70 : 16
        anchors.left: parent.left
        anchors.right: parent.right
        availableHeight: sheetRoot.availableHeight
        barSize: sheetRoot.barSize
        showLineDots: sheetRoot.showLineDots
        tabSize: sheetRoot.tabSize
        customFontFamily: sheetRoot.customFontFamily
        hasHeader: sheetRoot.showHeader
        hasFooter: sheetRoot.showFooter

        onPaneActivated: sheetRoot.paneActivated()
        onCursorVisibilityRequested: sheetRoot.cursorVisibilityRequested()
        onToggleHeaderFooterRequested: sheetRoot.toggleHeaderFooterRequested()
        onToggleFooterRequested: sheetRoot.toggleFooterRequested()
        onToggleHeaderRequested: sheetRoot.toggleHeaderRequested()
        onToggleCenteredModeRequested: sheetRoot.toggleCenteredModeRequested()
        onSaveRequested: sheetRoot.saveRequested()
        onOpenRequested: sheetRoot.openRequested()
        onOpenSplitRequested: sheetRoot.openSplitRequested()
        onNewRequested: sheetRoot.newRequested()
        onNewSplitRequested: sheetRoot.newSplitRequested()
        onToggleGraphRequested: sheetRoot.toggleGraphRequested()
        onToggleSplitRequested: sheetRoot.toggleSplitRequested()
        onTextChangedByUser: sheetRoot.textChangedByUser()
        onScrollRequested: (dy) => sheetRoot.scrollRequested(dy)
        onScrollToTopRequested: sheetRoot.scrollToTopRequested()
        onFontSizeChanged: (sz) => sheetRoot.fontSizeChanged(sz)
        onCloseRequested: sheetRoot.closeRequested()
        onDetachRequested: sheetRoot.detachRequested()
        onSyncNoticeRequested: (t) => sheetRoot.syncNoticeRequested(t)
    }

    // 2.1 Интерактивный граф связей на листе (In-Sheet Graph View)
    GraphView {
        id: sheetGraphView
        visible: sheetRoot.isGraphMode
        embeddedInSheet: true
        isLocalGraph: sheetRoot.isLocalGraphMode
        folderUrl: sheetRoot.folderUrl
        activeFileUrl: sheetRoot.fileUrl
        openFileUrls: sheetRoot.openFileUrls
        anchors.top: parent.top
        anchors.topMargin: sheetRoot.showHeader ? 70 : 0
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.max(100, sheetRoot.viewHeight - (sheetRoot.showHeader ? 70 : 0) - (sheetRoot.showFooter ? 70 : 0))

        onGraphPressed: sheetRoot.paneActivated()
        onActiveFocusChanged: {
            if (activeFocus) {
                sheetRoot.paneActivated()
            }
        }

        onNodeClicked: (fUrl, lbl, type) => {
            sheetRoot.paneActivated()
            sheetRoot.nodeSelected(fUrl, lbl)
        }
        onCloseRequested: {
            sheetRoot.closeGraphRequested()
        }
    }

    // 2.2 Режим иерархии блоков документа (Outliner)
    DocumentOutliner {
        id: sheetOutliner
        visible: sheetRoot.isOutlineMode && !sheetRoot.isGraphMode && !sheetRoot.isEmpty
        fileName: sheetRoot.fileName
        folderUrl: sheetRoot.folderUrl
        documentText: sheetRoot.text
        anchors.top: parent.top
        anchors.topMargin: sheetRoot.showHeader ? 70 : 0
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.max(100, sheetRoot.viewHeight - (sheetRoot.showHeader ? 70 : 0) - (sheetRoot.showFooter ? 70 : 0))

        onTextChangedByOutliner: (newText) => sheetRoot.textChangedByOutliner(newText)
        onCloseRequested: {
            sheetRoot.isOutlineMode = false
        }
        onPaneActivated: sheetRoot.paneActivated()
        onOpenFileRequested: (fUrl, lbl) => {
            sheetRoot.isOutlineMode = false
            sheetRoot.nodeSelected(fUrl, lbl)
        }
        onJumpToHeadingRequested: (heading) => {
            sheetRoot.isOutlineMode = false
            sheetRoot.paneActivated()
            if (!heading || !sheetRoot.editorArea) return
            var txt = sheetRoot.editorArea.text || ""
            var lines = txt.split("\n")
            var targetPos = 0
            var found = false
            var cleanHeading = heading.trim().toLowerCase()
            for (var i = 0; i < lines.length; i++) {
                var l = lines[i].trim()
                var match = l.match(/^(#{1,6})\s+(.+)$/)
                if (match && match[2].trim().toLowerCase() === cleanHeading) {
                    found = true
                    break
                }
                targetPos += lines[i].length + 1
            }
            if (found) {
                sheetRoot.editorArea.cursorPosition = Math.min(targetPos, txt.length)
                sheetRoot.editorArea.forceActiveFocus()
                sheetRoot.cursorVisibilityRequested()
            }
        }
    }

    function loadHistoricalSnapshot(snapshotId) {
        if (typeof backend === "undefined" || !backend) return
        if (isGraphMode) {
            if (typeof backend.get_history_snapshot_graph === "function" && sheetGraphView) {
                var gData = backend.get_history_snapshot_graph(folderUrl, snapshotId)
                sheetGraphView.loadHistoricalGraph(gData)
            }
            return
        }

        if (typeof _liveDraftText === "undefined" && editorArea) {
            _liveDraftText = editorArea.text
        }
        if (typeof backend.get_history_file_content === "function") {
            var targetPath = fileUrl ? fileUrl : fileName
            var snapText = backend.get_history_file_content(folderUrl, snapshotId, targetPath)
            if (typeof snapText === "string" && editorArea) {
                editorArea.text = snapText
                editorArea.readOnly = true
            }
        }
    }

    function restoreLive() {
        if (isGraphMode) {
            if (sheetGraphView) {
                sheetGraphView.reloadGraph()
            }
            return
        }
        if (typeof _liveDraftText === "string") {
            if (editorArea) {
                editorArea.text = _liveDraftText
                editorArea.readOnly = false
            }
            _liveDraftText = undefined
        } else if (fileUrl && typeof backend !== "undefined" && backend) {
            var liveText = backend.read_file(fileUrl)
            if (editorArea && typeof liveText === "string") {
                editorArea.text = liveText
                editorArea.readOnly = false
            }
        } else if (editorArea) {
            editorArea.readOnly = false
        }
    }

    Keys.onEscapePressed: (event) => {
        if (docFooter && docFooter.isHistoricalMode) {
            docFooter.goLive()
            event.accepted = true
        }
    }

    // 3. Нижний контейнер со шкалой истории и статистикой
    EditorFooter {
        id: docFooter
        barSize: sheetRoot.barSize
        folderUrl: sheetRoot.folderUrl
        fileUrl: sheetRoot.fileUrl
        isProjectTree: sheetRoot.isProjectTree
        anchors.left: parent.left
        anchors.right: parent.right
        height: 70
        z: 20
        isPinned: sheetRoot.isFooterPinned
        isGraphMode: sheetRoot.isGraphMode
        statsText: sheetRoot.isGraphMode ? sheetRoot.graphStatsText : sheetRoot.statsString
        visible: sheetRoot.showFooter && (!sheetRoot.isEmpty || sheetRoot.isGraphMode)
        y: Controller.calculateFooterY(sheetRoot, docFooter, editorCanvas, editorScroll)

        onPinToggled: {
            sheetRoot.isFooterPinned = !sheetRoot.isFooterPinned
            sheetRoot.footerPinToggled(sheetRoot.isFooterPinned)
            sheetRoot.paneActivated()
        }
        onActivated: sheetRoot.paneActivated()
        onSnapshotSelected: (snapshotId) => {
            sheetRoot.loadHistoricalSnapshot(snapshotId)
            sheetRoot.snapshotSelected(snapshotId)
        }
        onLiveRequested: {
            sheetRoot.restoreLive()
            sheetRoot.liveRequested()
        }
    }

    // Интерактивная граница изменения ширины листа слева
    SheetResizeHandle {
        id: leftHandle
        isLeft: true
        containerItem: sheetRoot.containerItem ? sheetRoot.containerItem : (parent ? parent : null)
        anchors.left: parent.left
        anchors.leftMargin: -12
        minWidth: sheetRoot.minSheetWidth
        maxWidth: (sheetRoot.containerItem ? sheetRoot.containerItem.width : (parent ? parent.width : 2000))
        forceVisible: sheetRoot.isResizingSheet
        onSheetWidthRequested: (w) => sheetRoot.sheetWidthRequested(w)
        onSheetWidthCommitted: (w) => sheetRoot.sheetWidthCommitted(w)
        onDoubleClickedToggle: sheetRoot.toggleFullWidthRequested()
    }

    // Интерактивная граница изменения ширины листа справа
    SheetResizeHandle {
        id: rightHandle
        isLeft: false
        containerItem: sheetRoot.containerItem ? sheetRoot.containerItem : (parent ? parent : null)
        anchors.right: parent.right
        anchors.rightMargin: -12
        minWidth: sheetRoot.minSheetWidth
        maxWidth: (sheetRoot.containerItem ? sheetRoot.containerItem.width : (parent ? parent.width : 2000))
        forceVisible: sheetRoot.isResizingSheet
        onSheetWidthRequested: (w) => sheetRoot.sheetWidthRequested(w)
        onSheetWidthCommitted: (w) => sheetRoot.sheetWidthCommitted(w)
        onDoubleClickedToggle: sheetRoot.toggleFullWidthRequested()
    }
}
