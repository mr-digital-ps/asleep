import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../editor/block_sync.js" as BlockSync
import "./pane_controller.js" as Controller
import "../editor"
import "../graph"
import "../outliner"
import "../theme"

Item {
    id: workspacePane

    // Свойства панели
    property int barSize: 36
    property string fileName: "Новый документ"
    property string fileUrl: ""
    property bool isCenteredMode: true
    property real customSheetWidth: 800
    property real minSheetWidth: 380
    property bool isSplitMode: false
    property bool isActivePane: false
    property bool isEmpty: false
    property bool isReceivingExternalSync: false
    property string customFontFamily: "Segoe UI, Inter, -apple-system, sans-serif"
    property bool typewriterMode: false
    property bool focusMode: false
    property bool isHeaderPinned: false
    property bool isFooterPinned: true
    property bool showHeader: true
    property bool showFooter: true
    property real editorLineHeightPercent: 135.0
    property bool showLineDots: true
    property int tabSize: 4
    readonly property var targetWindow: Window.window

    // Свойства графа связей
    property bool isGraphMode: false
    property string folderUrl: ""
    property string currentFolderName: ""
    property var openFileUrls: []
    readonly property string graphStatsText: paneGraphView ? paneGraphView.getGraphStats() : ""

    onIsGraphModeChanged: Controller.handleGraphModeChanged(workspacePane, editorScroll, paneGraphView, editorArea, smoothScrollAnim)

    function toggleHeaderFooter() {
        Controller.toggleHeaderFooter(workspacePane, (typeof backend !== "undefined" ? backend : null))
    }

    property string footerMode: "information"

    function toggleFooterMode() {
        if (workspacePane.footerMode === "information") {
            workspacePane.footerMode = "history"
        } else {
            workspacePane.footerMode = "information"
        }
    }

    function toggleFooterOnly() {
        Controller.toggleFooterOnly(workspacePane, (typeof backend !== "undefined" ? backend : null))
    }

    function toggleHeaderOnly() {
        Controller.toggleHeaderOnly(workspacePane, (typeof backend !== "undefined" ? backend : null))
    }

    function toggleCenteredMode() {
        workspacePane.isCenteredMode = !workspacePane.isCenteredMode
    }

    // Режим локального графа заметки
    property bool isLocalGraphMode: false
    readonly property bool isProjectTree: {
        if (typeof backend !== "undefined" && backend && typeof backend.is_project_structure_file === "function") {
            return backend.is_project_structure_file(workspacePane.fileName)
        }
        return workspacePane.fileName === "_Структура.md"
    }

    // Режим иерархии блоков документа (Outliner)
    property bool isOutlineMode: false
    property alias paneOutliner: paneOutliner
    property alias paneGraphView: paneGraphView
    property alias paneHeader: paneHeader
    property alias paneFooter: paneFooter
    property alias paperSheet: paperSheet

    // Обратная совместимость с MainBar
    property alias sheetOutliner: paneOutliner
    property alias sheetGraphView: paneGraphView
    property alias docHeader: paneHeader
    property alias docFooter: paneFooter

    function toggleOutlineMode() {
        if (workspacePane.isGraphMode) return
        workspacePane.isOutlineMode = !workspacePane.isOutlineMode
        if (workspacePane.isOutlineMode && paneOutliner) {
            paneOutliner.reload()
        }
    }

    property string statsString: "0 слов · 0 знаков"

    Timer {
        id: statsUpdateTimer
        interval: 300
        repeat: false
        onTriggered: {
            workspacePane.statsString = Controller.calculateStats((paperSheet && paperSheet.text) ? paperSheet.text : "")
        }
    }

    function saveHeaderPinnedState(pinned) {
        Controller.savePinnedState((typeof backend !== "undefined" ? backend : null), true, pinned)
    }

    function saveFooterPinnedState(pinned) {
        Controller.savePinnedState((typeof backend !== "undefined" ? backend : null), false, pinned)
    }

    // Плавный скролл с накоплением дельты
    NumberAnimation {
        id: smoothScrollAnim
        target: editorScroll ? editorScroll.contentItem : null
        property: "contentY"
        duration: 160
        easing.type: Easing.OutQuad
    }

    function smoothScrollBy(deltaY) {
        Controller.smoothScrollBy(editorScroll, smoothScrollAnim, deltaY)
    }

    property alias editorArea: paperSheet.editorArea
    property alias editorScroll: editorScroll
    property alias text: paperSheet.text
    property alias titleField: paneHeader.titleField
    readonly property real scrollY: (editorScroll && editorScroll.contentItem) ? editorScroll.contentItem.contentY : 0

    // Сигналы
    signal titleChangedByUser(string newTitle)
    signal closeRequested()
    signal paneActivated()
    signal detachRequested()
    signal saveRequested()
    signal newRequested()
    signal newSplitRequested()
    signal toggleGraphRequested()
    signal toggleLocalGraphRequested()
    signal toggleSplitRequested()
    signal openRequested()
    signal openSplitRequested()
    signal nodeSelected(string fileUrl, string label)
    signal closeGraphRequested()
    signal fileDragStarted(string url, string name, real gx, real gy)
    signal fileDragMoved(real gx, real gy)
    signal fileDragEnded(string url, string name, real gx, real gy)
    signal openStructureRequested()

    readonly property bool isResizingSheet: paperSheet ? paperSheet.isResizingSheet : false

    function stripExt(name) {
        return Controller.stripExt(name)
    }

    function updateConfigParameterInText(key, value) {
        let newTxt = Controller.updateConfigParameterInText(workspacePane.fileName, editorArea.text, key, value)
        if (newTxt !== null) {
            let curPos = editorArea.cursorPosition
            editorArea.text = newTxt
            editorArea.cursorPosition = Math.min(curPos, newTxt.length)
        }
    }

    function toggleFullWidth() {
        Controller.toggleFullWidth(workspacePane, editorScroll, (typeof backend !== "undefined" ? backend : null))
    }

    function applyConfig(cfg) {
        Controller.applyEditorConfig(workspacePane, editorArea, cfg, (typeof backend !== "undefined" ? backend : null))
    }

    Component.onCompleted: Controller.initMainBar(workspacePane, editorArea, (typeof backend !== "undefined" ? backend : null))

    onEditorLineHeightPercentChanged: Controller.handleLineHeightChanged(editorArea, workspacePane, (typeof backend !== "undefined" ? backend : null))

    onFileUrlChanged: Controller.handleFileUrlChanged(editorArea, workspacePane, (typeof backend !== "undefined" ? backend : null))

    function ensureCursorVisible() {
        Controller.ensureCursorVisible(workspacePane, editorArea, editorScroll)
    }

    function requestEnsureCursorVisible() {
        Qt.callLater(workspacePane.ensureCursorVisible)
    }

    function applyExternalBlockUpdate(headingNorm, newContent) {
        let res = BlockSync.applyExternalBlockUpdate(editorArea, headingNorm, newContent)
        if (res) {
            workspacePane.isReceivingExternalSync = true
            editorArea.text = res.text
            editorArea.cursorPosition = res.cursor
            workspacePane.isReceivingExternalSync = false
        }
    }

    Timer {
        id: blockSyncTimer
        interval: 350
        repeat: false
        onTriggered: Controller.handleBlockSyncTriggered(workspacePane, editorArea, (typeof backend !== "undefined" ? backend : null), BlockSync)
    }

    SyncNotice {
        id: syncNotice
    }

    function showSyncNotice(title) {
        syncNotice.showNotice(title)
    }

    TapHandler {
        gesturePolicy: TapHandler.WithinBounds
        onTapped: {
            if (paperSheet && paperSheet.titleField && paperSheet.titleField.activeFocus) return
            workspacePane.paneActivated()
        }
    }

    // =========================================================================
    // 1. ВЕРХНЯЯ ПАНЕЛЬ ЗАГОЛОВКА (PaneHeader)
    // =========================================================================
    PaneHeader {
        id: paneHeader
        barSize: workspacePane.barSize
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: (!workspacePane.isGraphMode && paperSheet) ? paperSheet.width : parent.width
        fileName: workspacePane.fileName
        fileUrl: workspacePane.fileUrl
        isSplitMode: workspacePane.isSplitMode
        isActivePane: workspacePane.isActivePane
        isEmpty: workspacePane.isEmpty
        isPinned: workspacePane.isHeaderPinned
        isGraphMode: workspacePane.isGraphMode
        isLocalGraphMode: workspacePane.isLocalGraphMode
        isOutlineMode: workspacePane.isOutlineMode
        contentLeftPadding: editorArea ? editorArea.leftPadding : 0
        contentRightPadding: editorArea ? editorArea.rightPadding : 0
        visible: workspacePane.showHeader && (!workspacePane.isEmpty || workspacePane.isGraphMode)

        onTitleCommitted: (newTitle) => workspacePane.titleChangedByUser(newTitle)
        onPaneActivated: workspacePane.paneActivated()
        onPinToggled: {
            workspacePane.isHeaderPinned = !workspacePane.isHeaderPinned
            workspacePane.saveHeaderPinnedState(workspacePane.isHeaderPinned)
        }
        onToggleOutlineRequested: workspacePane.toggleOutlineMode()
        onOpenStructureRequested: workspacePane.openStructureRequested()
    }

    // =========================================================================
    // 2. РАБОЧАЯ ОБЛАСТЬ ТЕКСТА (ScrollView + EditorSheet)
    // =========================================================================
    ScrollView {
        id: editorScroll
        anchors.top: (workspacePane.showHeader && !workspacePane.isEmpty) ? paneHeader.bottom : parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: (workspacePane.showFooter && !workspacePane.isEmpty) ? paneFooter.top : parent.bottom
        clip: true
        contentWidth: availableWidth
        contentHeight: scrollContentContainer.height
        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        visible: !workspacePane.isGraphMode && !workspacePane.isOutlineMode

        WheelHandler {
            target: editorScroll.contentItem
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            enabled: !workspacePane.isGraphMode && !workspacePane.isOutlineMode
            onWheel: (event) => Controller.handleWheel(workspacePane, editorArea, editorScroll, smoothScrollAnim, event, (typeof backend !== "undefined" ? backend : null))
        }

        Connections {
            target: editorScroll.contentItem
            function onContentHeightChanged() {
                if (editorArea && editorArea.activeFocus) {
                    workspacePane.requestEnsureCursorVisible()
                }
            }
        }

        Item {
            id: scrollContentContainer
            width: editorScroll.availableWidth
            readonly property real contentH: paperSheet ? paperSheet.contentNaturalHeight : 0
            readonly property real typewriterOverscroll: (editorArea && editorArea.lineCount > 1) ? Math.max(0, editorScroll.availableHeight - 100) : 0
            height: Math.max(editorScroll.availableHeight, contentH + typewriterOverscroll)

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.ArrowCursor
                hoverEnabled: true
                preventStealing: true

                onPressed: (mouse) => Controller.handleBackgroundDragPressed(mouse, workspacePane, this)
                onDoubleClicked: {
                    var win = workspacePane.targetWindow
                    if (win) {
                        if (win.visibility === Window.Maximized) {
                            win.showNormal()
                        } else {
                            win.showMaximized()
                        }
                    }
                }
            }

            EditorEmptyState {
                visible: workspacePane.isEmpty
            }

            EditorSheet {
                id: paperSheet
                barSize: workspacePane.barSize
                fileName: workspacePane.fileName
                fileUrl: workspacePane.fileUrl
                folderUrl: workspacePane.folderUrl
                isCenteredMode: workspacePane.isCenteredMode
                customSheetWidth: workspacePane.customSheetWidth
                minSheetWidth: workspacePane.minSheetWidth
                isSplitMode: workspacePane.isSplitMode
                isActivePane: workspacePane.isActivePane
                isEmpty: workspacePane.isEmpty
                customFontFamily: workspacePane.customFontFamily
                typewriterMode: workspacePane.typewriterMode
                focusMode: workspacePane.focusMode
                isHeaderPinned: workspacePane.isHeaderPinned
                showHeader: workspacePane.showHeader
                showLineDots: workspacePane.showLineDots
                tabSize: workspacePane.tabSize
                scrollY: workspacePane.scrollY
                availableHeight: editorScroll.availableHeight
                viewHeight: workspacePane.height
                containerItem: scrollContentContainer
                editorScroll: editorScroll

                onTitleChangedByUser: (t) => workspacePane.titleChangedByUser(t)
                onPaneActivated: workspacePane.paneActivated()
                onCloseRequested: workspacePane.closeRequested()
                onDetachRequested: workspacePane.detachRequested()
                onSaveRequested: workspacePane.saveRequested()
                onNewRequested: workspacePane.newRequested()
                onNewSplitRequested: workspacePane.newSplitRequested()
                onToggleGraphRequested: workspacePane.toggleGraphRequested()
                onToggleSplitRequested: workspacePane.toggleSplitRequested()
                onOpenRequested: workspacePane.openRequested()
                onOpenSplitRequested: workspacePane.openSplitRequested()
                onCursorVisibilityRequested: workspacePane.requestEnsureCursorVisible()
                onToggleHeaderFooterRequested: workspacePane.toggleHeaderFooter()
                onToggleFooterRequested: workspacePane.toggleFooterOnly()
                onToggleFooterModeRequested: workspacePane.toggleFooterMode()
                onToggleHeaderRequested: workspacePane.toggleHeaderOnly()
                onToggleCenteredModeRequested: workspacePane.isCenteredMode = !workspacePane.isCenteredMode
                onTextChangedByUser: {
                    Controller.handleTextChangedByUser(workspacePane, blockSyncTimer, activeFocus)
                    statsUpdateTimer.restart()
                }
                onScrollRequested: (dy) => workspacePane.smoothScrollBy(dy)
                onScrollToTopRequested: {
                    if (editorScroll && editorScroll.contentItem) {
                        editorScroll.contentItem.contentY = 0
                    }
                }
                onFontSizeChanged: (sz) => Controller.handleFontSizeChanged(workspacePane, (typeof backend !== "undefined" ? backend : null), sz)
                onSyncNoticeRequested: (t) => workspacePane.showSyncNotice(t)
                onSheetWidthRequested: (w) => Controller.handleSheetWidthRequested(workspacePane, w)
                onSheetWidthCommitted: (w) => Controller.handleSheetWidthCommitted(workspacePane, (typeof backend !== "undefined" ? backend : null), w)
                onToggleFullWidthRequested: workspacePane.toggleFullWidth()
                onHeaderPinToggled: (pinned) => workspacePane.saveHeaderPinnedState(pinned)
            }
        }
    }

    // =========================================================================
    // 3. ПОЛНОРАЗМЕРНЫЙ ГРАФ СВЯЗЕЙ (GraphView)
    // =========================================================================
    GraphView {
        id: paneGraphView
        visible: workspacePane.isGraphMode
        embeddedInSheet: false
        isLocalGraph: workspacePane.isLocalGraphMode
        folderUrl: workspacePane.folderUrl
        activeFileUrl: workspacePane.fileUrl
        openFileUrls: workspacePane.openFileUrls
        anchors.top: (workspacePane.showHeader && workspacePane.isGraphMode) ? paneHeader.bottom : parent.top
        anchors.bottom: (workspacePane.showFooter && workspacePane.isGraphMode) ? paneFooter.top : parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        onGraphPressed: workspacePane.paneActivated()
        onActiveFocusChanged: {
            if (activeFocus) {
                workspacePane.paneActivated()
            }
        }
        onNodeClicked: (fUrl, lbl, type) => {
            workspacePane.paneActivated()
            workspacePane.nodeSelected(fUrl, lbl)
        }
        onCloseRequested: {
            workspacePane.closeGraphRequested()
        }
    }

    // =========================================================================
    // 4. РЕЖИМ ИЕРАРХИИ БЛОКОВ / АУТЛАЙНЕР (DocumentOutliner)
    // =========================================================================
    DocumentOutliner {
        id: paneOutliner
        visible: workspacePane.isOutlineMode && !workspacePane.isGraphMode && !workspacePane.isEmpty
        fileName: workspacePane.fileName
        folderUrl: workspacePane.folderUrl
        documentText: workspacePane.text
        anchors.top: (workspacePane.showHeader && !workspacePane.isEmpty) ? paneHeader.bottom : parent.top
        anchors.bottom: (workspacePane.showFooter && !workspacePane.isEmpty) ? paneFooter.top : parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        onTextChangedByOutliner: (newText) => {
            workspacePane.text = newText
            if (workspacePane.editorArea) {
                workspacePane.editorArea.text = newText
            }
            if (workspacePane.fileUrl && typeof backend !== "undefined" && backend) {
                backend.save_file(workspacePane.fileUrl, newText)
            }
        }
        onCloseRequested: {
            workspacePane.isOutlineMode = false
        }
        onPaneActivated: workspacePane.paneActivated()
        onOpenFileRequested: (fUrl, lbl) => {
            workspacePane.isOutlineMode = false
            workspacePane.nodeSelected(fUrl, lbl)
        }
        onJumpToHeadingRequested: (heading) => {
            workspacePane.isOutlineMode = false
            workspacePane.paneActivated()
            if (!heading || !workspacePane.editorArea) return
            var txt = workspacePane.editorArea.text || ""
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
                workspacePane.editorArea.cursorPosition = Math.min(targetPos, txt.length)
                workspacePane.editorArea.forceActiveFocus()
                workspacePane.requestEnsureCursorVisible()
            }
        }
    }

    // =========================================================================
    // 5. НИЖНЯЯ ПАНЕЛЬ (PaneFooter)
    // =========================================================================
    PaneFooter {
        id: paneFooter
        barSize: workspacePane.barSize
        folderUrl: workspacePane.folderUrl
        fileUrl: workspacePane.fileUrl
        isProjectTree: workspacePane.isProjectTree
        footerMode: workspacePane.footerMode
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: (!workspacePane.isGraphMode && paperSheet) ? paperSheet.width : parent.width
        height: 70
        z: 20
        isPinned: true
        isGraphMode: workspacePane.isGraphMode
        statsText: workspacePane.isGraphMode ? workspacePane.graphStatsText : workspacePane.statsString
        visible: workspacePane.showFooter && (!workspacePane.isEmpty || workspacePane.isGraphMode)

        onActivated: workspacePane.paneActivated()
        onSnapshotSelected: (snapshotId) => {
            if (workspacePane.isGraphMode) {
                if (typeof backend !== "undefined" && backend && typeof backend.get_history_snapshot_graph === "function" && paneGraphView) {
                    var gData = backend.get_history_snapshot_graph(workspacePane.folderUrl, snapshotId)
                    paneGraphView.loadHistoricalGraph(gData)
                }
            } else if (paperSheet) {
                paperSheet.loadHistoricalSnapshot(snapshotId)
            }
        }
        onLiveRequested: {
            if (workspacePane.isGraphMode) {
                if (paneGraphView) {
                    paneGraphView.reloadGraph()
                }
            } else if (paperSheet) {
                paperSheet.restoreLive()
            }
        }
    }

    // Правая полоса со скроллбаром документа
    EditorScrollbar {
        id: editorScrollbar
        editorScroll: editorScroll
        paperSheet: paperSheet
        isEmpty: workspacePane.isEmpty || workspacePane.isGraphMode || workspacePane.isOutlineMode
        hasHeader: workspacePane.showHeader
        isHeaderPinned: workspacePane.isHeaderPinned
        barSize: workspacePane.barSize
        onActivated: workspacePane.paneActivated()
    }
}
