import QtQuick
import QtQuick.Controls
import "../editor/block_sync.js" as BlockSync
import "./pane_controller.js" as Controller
import "../editor"
import "../graph"
import "../theme"

Item {
    id: workspacePane

    // Свойства панели (Config-First: читаются из Theme)
    property int barSize: Theme.barSize
    property string fileName: "Новый документ"
    property string fileUrl: ""
    property bool isCenteredMode: true
    property real customSheetWidth: Theme.defaultSheetWidth
    property real minSheetWidth: Theme.minSheetWidth
    property bool isActivePane: false
    property bool isEmpty: false
    property bool isReceivingExternalSync: false
    property bool typewriterMode: false
    property bool focusMode: false
    property bool isHeaderPinned: true
    property bool showHeader: true
    property bool showScrollbar: true
    property real editorLineHeightPercent: Theme.defaultLineHeightPercent
    property bool showLineDots: true
    property bool isLiveMode: true
    property int tabSize: Theme.defaultTabSize
    readonly property var targetWindow: Window.window

    // Режимы рабочей области (paneBody): "editor" | "graph"
    property bool isGraphMode: false
    readonly property string viewMode: isGraphMode ? "graph" : "editor"

    onIsGraphModeChanged: {
        Controller.handleGraphModeChanged(workspacePane, editorScroll, paneGraphView, editorArea, smoothScrollAnim)
    }

    property string folderUrl: ""
    property string currentFolderName: ""
    property var openFileUrls: []
    readonly property string graphStatsText: paneGraphView ? (paneGraphView.statsText || paneGraphView.getGraphStats()) : ""

    function toggleHistoryMode() {
        if (paneHeader) {
            paneHeader.toggleHistoryMode()
        }
    }

    function toggleHistoryDiffMode() {
        if (paneHeader) {
            paneHeader.toggleHistoryDiffMode()
        }
    }

    function toggleInfoMode() {
        if (paneHeader) {
            paneHeader.toggleInfoMode()
            if (paneHeader.headerMode === "info") {
                workspacePane.updateStats()
            }
        }
    }

    function toggleSearchMode() {
        if (paneHeader) {
            paneHeader.toggleSearchMode()
        }
    }

    function showPathMode() {
        if (paneHeader) {
            paneHeader.showPathMode()
        }
    }

    function showFileNameMode() {
        if (paneHeader) {
            paneHeader.showFileNameMode()
        }
    }

    function togglePathMode() {
        if (paneHeader) {
            paneHeader.togglePathMode()
        }
    }

    function toggleTabsMode() {
        if (paneHeader) {
            paneHeader.toggleTabsMode()
        }
    }

    function toggleHeaderOnly() {
        Controller.toggleHeaderOnly(workspacePane, (typeof backend !== "undefined" ? backend : null))
    }

    function toggleCenteredMode() {
        workspacePane.isCenteredMode = !workspacePane.isCenteredMode
        let report = "[CENTERED_MODE] Pane: " + (workspacePane.isActivePane ? "Active" : "Secondary")
                   + " | isCenteredMode: " + workspacePane.isCenteredMode
                   + " | ViewMode: " + workspacePane.viewMode
                   + " | PaneWidth: " + workspacePane.width
                   + " | SheetWidth: " + workspacePane.effectiveSheetWidth
                   + " | CustomWidth: " + workspacePane.customSheetWidth
        console.log(report)
        if (typeof backend !== "undefined" && backend && typeof backend.log_event === "function") {
            backend.log_event("CENTERED_MODE", report)
        }
    }

    function toggleScrollbar() {
        workspacePane.showScrollbar = !workspacePane.showScrollbar
        if (typeof backend !== "undefined" && backend && typeof backend.save_show_scrollbar === "function") {
            backend.save_show_scrollbar(workspacePane.showScrollbar)
        }
    }

    function toggleLineDots() {
        workspacePane.showLineDots = !workspacePane.showLineDots
        if (typeof backend !== "undefined" && backend && typeof backend.save_show_line_dots === "function") {
            backend.save_show_line_dots(workspacePane.showLineDots)
        }
    }

    function toggleLiveMode() {
        workspacePane.isLiveMode = !workspacePane.isLiveMode
    }

    function toggleSourceMode() {
        workspacePane.isLiveMode = false
    }

    // Режим локального графа заметки
    property bool isLocalGraphMode: false

    property alias paneGraphView: paneGraphView
    property alias paneHeader: paneHeader
    property alias paperSheet: paperSheet
    property alias editorCanvas: paperSheet.editorCanvas

    readonly property real canvasX: parent ? parent.x : 0
    readonly property real canvasY: parent ? parent.y : 0

    property string statsString: "0 слов · 0 знаков · ~0 мин · 0 блоков · Стр 1:1 · (0, 0)"

    function updateStats() {
        var txt = (paperSheet && paperSheet.text) ? paperSheet.text : ""
        var bCount = (paperSheet && paperSheet.editorCanvas && paperSheet.editorCanvas.blocks) ? paperSheet.editorCanvas.blocks.length : 0
        var cPos = editorArea ? editorArea.cursorPosition : 0
        workspacePane.statsString = Controller.calculateStats(txt, bCount, cPos, canvasX, canvasY)
    }

    onCanvasXChanged: {
        if (paneHeader && paneHeader.headerMode === "info") {
            updateStats()
        }
    }
    onCanvasYChanged: {
        if (paneHeader && paneHeader.headerMode === "info") {
            updateStats()
        }
    }

    Timer {
        id: statsUpdateTimer
        interval: 300
        repeat: false
        onTriggered: workspacePane.updateStats()
    }

    function saveHeaderPinnedState(pinned) {
        Controller.savePinnedState((typeof backend !== "undefined" ? backend : null), true, pinned)
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
    signal toggleGraphRequested()
    signal toggleLocalGraphRequested()
    signal openRequested()
    signal closeGraphRequested()
    signal fileDragStarted(string url, string name, real gx, real gy)
    signal fileDragMoved(real gx, real gy)
    signal fileDragEnded(string url, string name, real gx, real gy)
    signal openStructureRequested()
    signal panelDragStarted(var mouse, var item)
    signal panelDragUpdated(var mouse, var item)
    signal panelDragFinished()

    readonly property bool isResizingSheet: false

    function openDocument(url, name, content) {
        fileUrl = url
        fileName = (name || "").replace(/\.(txt|md)$/i, "")
        if (paperSheet && typeof paperSheet.resetFolding === "function") {
            paperSheet.resetFolding()
        }
        text = content
        isGraphMode = false
        if (typeof backend !== "undefined" && backend) {
            Qt.callLater(function() {
                if (typeof backend.set_editor_line_height === "function") {
                    backend.set_editor_line_height(editorArea, workspacePane.editorLineHeightPercent)
                }
                if (typeof backend.set_editor_live_mode === "function") {
                    backend.set_editor_live_mode(editorArea, workspacePane.isLiveMode)
                }
                if (editorCanvas && typeof editorCanvas.initializeLiveModeIfReady === "function") {
                    editorCanvas.initializeLiveModeIfReady()
                }
            })
        }
    }
    function getDocumentState() {
        return { fileUrl: fileUrl, fileName: fileName, text: paperSheet.getLiveText() }
    }

    function stripExt(name) {
        return Controller.stripExt(name)
    }

    function updateConfigParameterInText(key, value) {
        let newTxt = Controller.updateConfigParameterInText(workspacePane.fileName, editorArea.text, key, value)
        if (newTxt !== null) {
            let curPos = editorArea.cursorPosition
            editorArea.text = newTxt
            editorArea.cursorPosition = Math.min(curPos, newTxt.length)
            if (paperSheet && typeof paperSheet.reapplyEditorStyling === "function") {
                paperSheet.reapplyEditorStyling()
            }
        }
    }

    function toggleFullWidth() {
        Controller.toggleFullWidth(workspacePane, editorScroll, (typeof backend !== "undefined" ? backend : null))
    }

    function handleOpenLink(target, linkType) {
        if (!target) return
        if (linkType === "url") {
            Qt.openUrlExternally(target)
            return
        }
        workspacePane.saveRequested()
        if (typeof backend !== "undefined" && backend && typeof backend.open_wiki_link === "function") {
            backend.open_wiki_link(target, workspacePane.folderUrl, workspacePane.fileUrl)
        }
    }

    function applyConfig(cfg) {
        Controller.applyEditorConfig(workspacePane, editorArea, cfg, (typeof backend !== "undefined" ? backend : null))
    }

    function applySessionConfig(sess) {
        if (!sess) return
        if (typeof sess.header_pinned === "boolean") {
            workspacePane.isHeaderPinned = sess.header_pinned
        }
        if (typeof sess.header_visible === "boolean") {
            workspacePane.showHeader = sess.header_visible
        }
        if (typeof sess.show_scrollbar === "boolean") {
            workspacePane.showScrollbar = sess.show_scrollbar
        }
        if (typeof sess.show_line_dots === "boolean") {
            workspacePane.showLineDots = sess.show_line_dots
        }
        if (typeof sess.sheet_width === "number" && sess.sheet_width > 0) {
            workspacePane.customSheetWidth = sess.sheet_width
        }
        if (typeof sess.font_size === "number" && sess.font_size > 0 && editorArea && editorArea.font) {
            editorArea.font.pixelSize = sess.font_size
        }
    }

    Component.onCompleted: Controller.initMainBar(workspacePane, editorArea, (typeof backend !== "undefined" ? backend : null))

    onEditorLineHeightPercentChanged: Controller.handleLineHeightChanged(editorArea, workspacePane, (typeof backend !== "undefined" ? backend : null))

    onFileUrlChanged: Controller.handleFileUrlChanged(editorArea, workspacePane, (typeof backend !== "undefined" ? backend : null))

    onTextChanged: {
        // Реактивное обновление статистики
    }

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
            if (paperSheet && typeof paperSheet.reapplyEditorStyling === "function") {
                paperSheet.reapplyEditorStyling()
            }
        }
    }

    property string activeBlockName: _editorBlockName
    property string _editorBlockName: ""

    // Отслеживание текущего активного блока по положению курсора
    Connections {
        target: editorArea
        function onCursorPositionChanged() {
            if (workspacePane.isGraphMode) return
            var b = BlockSync.getCurrentBlockInfo(editorArea, (typeof backend !== "undefined" ? backend : null))
            var bName = (b && b.heading) ? b.heading : ""
            if (workspacePane._editorBlockName !== bName) {
                workspacePane._editorBlockName = bName
            }
            if (paneHeader && paneHeader.headerMode === "info") {
                workspacePane.updateStats()
            }
        }
    }

    readonly property string breadcrumbTitle: {
        if (workspacePane.isEmpty) return ""
        return Controller.formatBreadcrumbTitle(
            workspacePane.folderUrl,
            workspacePane.currentFolderName,
            workspacePane.fileUrl,
            workspacePane.fileName,
            workspacePane.activeBlockName
        )
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

    readonly property real effectiveSheetWidth: width

    // =========================================================================
    // 0. ФОН ПАНЕЛИ: активация и перетаскивание вкладки по холсту
    // =========================================================================
    MouseArea {
        id: paneBackgroundDrag
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor
        onPressed: (mouse) => {
            if (paneHeader && paneHeader.titleField && paneHeader.titleField.activeFocus) return
            workspacePane.paneActivated()
            workspacePane.panelDragStarted(mouse, paneBackgroundDrag)
        }
        onPositionChanged: (mouse) => {
            if (pressed) {
                workspacePane.panelDragUpdated(mouse, paneBackgroundDrag)
            }
        }
        onReleased: workspacePane.panelDragFinished()
        onCanceled: workspacePane.panelDragFinished()
    }

    // =========================================================================
    // 1. ВЕРХНЯЯ ПАНЕЛЬ ЗАГОЛОВКА (PaneHeader)
    // =========================================================================
    PaneHeader {
        id: paneHeader
        barSize: workspacePane.barSize
        anchors.horizontalCenter: parent.horizontalCenter
        width: workspacePane.effectiveSheetWidth
        fileName: workspacePane.fileName
        fileUrl: workspacePane.fileUrl
        folderUrl: workspacePane.folderUrl
        breadcrumbTitle: workspacePane.breadcrumbTitle
        isActivePane: workspacePane.isActivePane
        isEmpty: workspacePane.isEmpty
        isPinned: workspacePane.isHeaderPinned
        isGraphMode: workspacePane.isGraphMode
        scrollY: workspacePane.scrollY
        contentLeftPadding: editorArea ? editorArea.leftPadding : 0
        contentRightPadding: editorArea ? editorArea.rightPadding : 0
        statsText: workspacePane.isGraphMode ? workspacePane.graphStatsText : workspacePane.statsString
        visible: workspacePane.showHeader && (workspacePane.isGraphMode ? workspacePane.isHeaderPinned : !workspacePane.isEmpty)
        z: 10

        // Когда закреплен — y: 0.
        // Когда откреплен в редакторе — уезжает вверх со скроллом листа:
        y: workspacePane.isHeaderPinned
            ? 0
            : -Math.min(paneHeader.height, workspacePane.scrollY)

        onHeaderModeChanged: {
            if (headerMode === "info") {
                workspacePane.updateStats()
            }
        }
        onTitleCommitted: (newTitle) => workspacePane.titleChangedByUser(newTitle)
        onPaneActivated: workspacePane.paneActivated()
        onPinToggled: {
            workspacePane.isHeaderPinned = !workspacePane.isHeaderPinned
            workspacePane.saveHeaderPinnedState(workspacePane.isHeaderPinned)
        }
        onOpenStructureRequested: workspacePane.openStructureRequested()
        onSnapshotSelected: (snapshotId) => {
            if (workspacePane.isGraphMode) {
                if (typeof backend !== "undefined" && backend && typeof backend.get_history_snapshot_graph === "function" && paneGraphView) {
                    let gData = backend.get_history_snapshot_graph(workspacePane.folderUrl, snapshotId)
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
        onHistorySubModeChanged: (subMode) => {
            if (paperSheet && typeof paperSheet.setHistorySubMode === "function") {
                paperSheet.setHistorySubMode(subMode)
            }
        }
        onDragStarted: (mouse, item) => workspacePane.panelDragStarted(mouse, item)
        onDragUpdated: (mouse, item) => workspacePane.panelDragUpdated(mouse, item)
        onDragFinished: () => workspacePane.panelDragFinished()
    }

    // =========================================================================
    // 2. ЕДИНАЯ РАБОЧАЯ ОБЛАСТЬ (paneBody): переключает Editor и Graph
    // =========================================================================
    Item {
        id: paneBody
        anchors.fill: parent

        // 2.1 Текстовый редактор (ScrollView + EditorSheet)
        ScrollView {
            id: editorScroll
            anchors.fill: parent
            clip: true
            contentWidth: availableWidth
            contentHeight: paperSheet ? paperSheet.height : 0
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            visible: workspacePane.viewMode === "editor"

            WheelHandler {
                target: editorScroll.contentItem
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                enabled: workspacePane.viewMode === "editor"
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

            MouseArea {
                id: editorEmptyAreaDrag
                width: editorScroll.availableWidth
                height: paperSheet ? paperSheet.height : 0
                acceptedButtons: Qt.LeftButton
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor
                preventStealing: true

                onPressed: (mouse) => {
                    if (mouse.button === Qt.LeftButton) {
                        workspacePane.paneActivated()
                        if (workspacePane.editorArea) {
                            workspacePane.editorArea.forceActiveFocus()
                        }
                        workspacePane.panelDragStarted(mouse, editorEmptyAreaDrag)
                    }
                }
                onPositionChanged: (mouse) => {
                    if (pressed) {
                        workspacePane.panelDragUpdated(mouse, editorEmptyAreaDrag)
                    }
                }
                onReleased: workspacePane.panelDragFinished()
                onCanceled: workspacePane.panelDragFinished()
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
                isActivePane: workspacePane.isActivePane
                isEmpty: workspacePane.isEmpty
                typewriterMode: workspacePane.typewriterMode
                focusMode: workspacePane.focusMode
                isHeaderPinned: workspacePane.isHeaderPinned
                showHeader: workspacePane.showHeader
                showLineDots: workspacePane.showLineDots
                isLiveMode: workspacePane.isLiveMode
                tabSize: workspacePane.tabSize
                scrollY: workspacePane.scrollY
                availableHeight: paneBody.height
                viewHeight: paneBody.height
                editorScroll: editorScroll

                    onOpenLinkRequested: (target, linkType) => workspacePane.handleOpenLink(target, linkType)
                    onTitleChangedByUser: (t) => workspacePane.titleChangedByUser(t)
                    onPaneActivated: workspacePane.paneActivated()
                    onCloseRequested: workspacePane.closeRequested()
                    onPanelDragStarted: (mouse, item) => workspacePane.panelDragStarted(mouse, item)
                    onPanelDragUpdated: (mouse, item) => workspacePane.panelDragUpdated(mouse, item)
                    onPanelDragFinished: () => workspacePane.panelDragFinished()
                    onDetachRequested: workspacePane.detachRequested()
                    onSaveRequested: workspacePane.saveRequested()
                    onNewRequested: workspacePane.newRequested()
                    onToggleGraphRequested: workspacePane.toggleGraphRequested()
                    onOpenRequested: workspacePane.openRequested()
                    onCursorVisibilityRequested: workspacePane.requestEnsureCursorVisible()
                    onToggleHistoryRequested: workspacePane.toggleHistoryMode()
                    onToggleInfoRequested: workspacePane.toggleInfoMode()
                    onToggleSearchRequested: workspacePane.toggleSearchMode()
                    onTogglePathRequested: workspacePane.togglePathMode()
                    onShowFileNameRequested: workspacePane.showFileNameMode()
                    onToggleTabsRequested: workspacePane.toggleTabsMode()
                    onToggleHeaderRequested: workspacePane.toggleHeaderOnly()
                    onToggleCenteredModeRequested: workspacePane.isCenteredMode = !workspacePane.isCenteredMode
                    onToggleLiveModeRequested: workspacePane.isLiveMode = !workspacePane.isLiveMode
                    onToggleSourceModeRequested: workspacePane.toggleSourceMode()
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
                    onHeaderPinToggled: (pinned) => workspacePane.saveHeaderPinnedState(pinned)
                }
            }



        // 2.3 Граф связей (GraphView)
        GraphView {
            id: paneGraphView
            anchors.top: parent.top
            anchors.topMargin: (paneHeader.visible) ? paneHeader.height : 0
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: workspacePane.effectiveSheetWidth
            visible: workspacePane.viewMode === "graph"
            embeddedInSheet: false
            isLocalGraph: workspacePane.isLocalGraphMode
            folderUrl: workspacePane.folderUrl
            activeFileUrl: workspacePane.fileUrl
            openFileUrls: workspacePane.openFileUrls

            onGraphPressed: workspacePane.paneActivated()
            onActiveFocusChanged: {
                if (activeFocus) {
                    workspacePane.paneActivated()
                }
            }
            onNodeClicked: (fUrl, lbl, type) => {
                workspacePane.paneActivated()
                var target = fUrl ? (fUrl + ((type === "block" && lbl) ? ("#" + lbl) : "")) : (lbl || "")
                if (backend && typeof backend.open_wiki_link === "function") {
                    backend.open_wiki_link(target, workspacePane.folderUrl)
                }
            }
            onToggleInfoRequested: {
                workspacePane.toggleInfoMode()
            }
            onCloseRequested: {
                workspacePane.isGraphMode = false
                workspacePane.closeGraphRequested()
            }
        }
    }

    // Правая полоса со скроллбаром документа
    EditorScrollbar {
        id: editorScrollbar
        editorScroll: editorScroll
        paperSheet: paperSheet
        sheetWidth: workspacePane.width
        barSize: workspacePane.barSize
        width: workspacePane.barSize
        anchors.top: parent.top
        anchors.topMargin: (workspacePane.showHeader && workspacePane.isHeaderPinned) ? (Theme.headerHeight + 6) : Theme.sheetPadding
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.sheetPadding
        anchors.right: parent.right
        anchors.rightMargin: 4
        isEmpty: workspacePane.isEmpty || workspacePane.isGraphMode
        visible: workspacePane.showScrollbar && !isEmpty
        onActivated: workspacePane.paneActivated()
        onDragStarted: (mouse, item) => workspacePane.panelDragStarted(mouse, item)
        onDragUpdated: (mouse, item) => workspacePane.panelDragUpdated(mouse, item)
        onDragFinished: () => workspacePane.panelDragFinished()
    }
}

