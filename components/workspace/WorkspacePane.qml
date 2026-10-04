import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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
    property bool isSplitMode: false
    property bool isActivePane: false
    property bool isEmpty: false
    property bool isReceivingExternalSync: false
    property string customFontFamily: Theme.defaultFontFamily
    property bool typewriterMode: false
    property bool focusMode: false
    property bool isHeaderPinned: false
    property bool showHeader: true
    property real editorLineHeightPercent: Theme.defaultLineHeightPercent
    property bool showLineDots: true
    property int tabSize: Theme.defaultTabSize
    readonly property var targetWindow: Window.window

    // Режимы рабочей области (paneBody): "editor" | "graph"
    // isGraphMode приходит снаружи из WorkspaceSplit через reactive binding.
    // Прямое присвоение запрещено (HOTKEYS.md, Причина 1 и 5), иначе разрушается связь.
    property bool isGraphMode: false
    readonly property string viewMode: isGraphMode ? "graph" : "editor"

    onIsGraphModeChanged: {
        Controller.handleGraphModeChanged(workspacePane, editorScroll, paneGraphView, editorArea, smoothScrollAnim)
    }

    property string folderUrl: ""
    property string currentFolderName: ""
    property var openFileUrls: []
    readonly property string graphStatsText: paneGraphView ? paneGraphView.getGraphStats() : ""

    function toggleHistoryMode() {
        if (paneHeader) {
            paneHeader.toggleHistoryMode()
        }
    }

    function toggleInfoMode() {
        if (paneHeader) {
            paneHeader.toggleInfoMode()
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
    }

    // Режим локального графа заметки
    property bool isLocalGraphMode: false
    readonly property bool isProjectTree: {
        if (typeof backend !== "undefined" && backend && typeof backend.is_project_structure_file === "function") {
            return backend.is_project_structure_file(workspacePane.fileName)
        }
        return workspacePane.fileName === "_Структура.md"
    }

    property alias paneGraphView: paneGraphView
    property alias paneHeader: paneHeader
    property alias paperSheet: paperSheet

    // Обратная совместимость с MainBar
    property alias sheetGraphView: paneGraphView
    property alias docHeader: paneHeader

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

    readonly property bool isResizingSheet: (leftHandle && (leftHandle.containsMouse || leftHandle.isDragging)) || (rightHandle && (rightHandle.containsMouse || rightHandle.isDragging))

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

    readonly property real effectiveSheetWidth: isCenteredMode ? Math.min(width, Math.max(minSheetWidth, customSheetWidth)) : width

    // =========================================================================
    // 0. ФОН ПАНЕЛИ: активация и перетаскивание окна за пустые места в ЛЮБОМ режиме
    // =========================================================================
    MouseArea {
        id: paneBackgroundDrag
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onPressed: (mouse) => {
            if (paperSheet && paperSheet.titleField && paperSheet.titleField.activeFocus) return
            workspacePane.paneActivated()
            var win = workspacePane.targetWindow
            if (win && typeof win.startSystemMove === "function") {
                win.startSystemMove()
            }
        }
        onDoubleClicked: {
            var win = workspacePane.targetWindow
            if (win) {
                if (win.visibility === Window.Maximized) win.showNormal()
                else win.showMaximized()
            }
        }
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
        isProjectTree: workspacePane.isProjectTree
        isSplitMode: workspacePane.isSplitMode
        isActivePane: workspacePane.isActivePane
        isEmpty: workspacePane.isEmpty
        isPinned: workspacePane.isHeaderPinned
        isGraphMode: workspacePane.isGraphMode
        isLocalGraphMode: workspacePane.isLocalGraphMode
        scrollY: workspacePane.scrollY
        contentLeftPadding: editorArea ? editorArea.leftPadding : 0
        contentRightPadding: editorArea ? editorArea.rightPadding : 0
        statsText: workspacePane.isGraphMode ? workspacePane.graphStatsText : workspacePane.statsString
        visible: workspacePane.showHeader && (!workspacePane.isEmpty || workspacePane.isGraphMode)

        // Закрепление: когда закреплен (isPinned) или в режиме графа — прибит к верху (y = 0).
        // Когда откреплен (!isPinned) — уезжает вверх вместе со скроллом листа (y = -scrollY) и скрывается.
        y: (workspacePane.isHeaderPinned || workspacePane.isGraphMode)
            ? 0
            : -Math.min(paneHeader.height, workspacePane.scrollY)

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

    // =========================================================================
    // 2. ЕДИНАЯ РАБОЧАЯ ОБЛАСТЬ (paneBody): переключает Editor и Graph
    // =========================================================================
    Item {
        id: paneBody
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.top: (workspacePane.showHeader && (workspacePane.isHeaderPinned || workspacePane.viewMode === "graph") && !workspacePane.isEmpty)
            ? paneHeader.bottom
            : parent.top

        // 2.1 Текстовый редактор (ScrollView + EditorSheet)
        ScrollView {
            id: editorScroll
            anchors.fill: parent
            clip: true
            contentWidth: availableWidth
            contentHeight: scrollContentContainer.height
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

            Item {
                id: scrollContentContainer
                width: editorScroll.availableWidth
                readonly property real contentH: paperSheet ? paperSheet.contentNaturalHeight : 0
                readonly property real typewriterOverscroll: (editorArea && editorArea.lineCount > 1) ? Math.max(0, paneBody.height - 100) : 0
                height: Math.max(paneBody.height, contentH + typewriterOverscroll)

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.ArrowCursor
                    hoverEnabled: true
                    preventStealing: true

                    onPressed: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            workspacePane.paneActivated()
                            var win = workspacePane.targetWindow
                            if (win && typeof win.startSystemMove === "function") {
                                win.startSystemMove()
                            }
                        }
                    }
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
                    onToggleHistoryRequested: workspacePane.toggleHistoryMode()
                    onToggleInfoRequested: workspacePane.toggleInfoMode()
                    onToggleSearchRequested: workspacePane.toggleSearchMode()
                    onTogglePathRequested: workspacePane.togglePathMode()
                    onShowFileNameRequested: workspacePane.showFileNameMode()
                    onToggleTabsRequested: workspacePane.toggleTabsMode()
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
                    onHeaderPinToggled: (pinned) => workspacePane.saveHeaderPinnedState(pinned)
                }
            }
        }

        // 2.2 Граф связей (GraphView)
        GraphView {
            id: paneGraphView
            anchors.top: parent.top
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
                workspacePane.nodeSelected(fUrl, lbl)
            }
            onCloseRequested: {
                workspacePane.closeGraphRequested()
            }
        }
    }

    // =========================================================================
    // 3. Интерактивные границы изменения ширины листа на ВСЮ высоту панели
    // =========================================================================
    SheetResizeHandle {
        id: leftHandle
        isLeft: true
        containerItem: workspacePane
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        x: (workspacePane.width - workspacePane.effectiveSheetWidth) / 2.0 - width / 2.0
        visible: workspacePane.isCenteredMode && !workspacePane.isEmpty && workspacePane.width > workspacePane.minSheetWidth
        forceVisible: workspacePane.isResizingSheet
        minWidth: workspacePane.minSheetWidth
        maxWidth: workspacePane.width
        onSheetWidthRequested: (w) => Controller.handleSheetWidthRequested(workspacePane, w)
        onSheetWidthCommitted: (w) => Controller.handleSheetWidthCommitted(workspacePane, (typeof backend !== "undefined" ? backend : null), w)
        onDoubleClickedToggle: workspacePane.toggleFullWidth()
    }

    SheetResizeHandle {
        id: rightHandle
        isLeft: false
        containerItem: workspacePane
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        x: (workspacePane.width + workspacePane.effectiveSheetWidth) / 2.0 - width / 2.0
        visible: workspacePane.isCenteredMode && !workspacePane.isEmpty && workspacePane.width > workspacePane.minSheetWidth
        forceVisible: workspacePane.isResizingSheet
        minWidth: workspacePane.minSheetWidth
        maxWidth: workspacePane.width
        onSheetWidthRequested: (w) => Controller.handleSheetWidthRequested(workspacePane, w)
        onSheetWidthCommitted: (w) => Controller.handleSheetWidthCommitted(workspacePane, (typeof backend !== "undefined" ? backend : null), w)
        onDoubleClickedToggle: workspacePane.toggleFullWidth()
    }

    // Правая полоса со скроллбаром документа
    EditorScrollbar {
        id: editorScrollbar
        editorScroll: editorScroll
        paperSheet: paperSheet
        sheetWidth: workspacePane.effectiveSheetWidth
        isEmpty: workspacePane.isEmpty || workspacePane.isGraphMode
        hasHeader: workspacePane.showHeader
        isHeaderPinned: workspacePane.isHeaderPinned
        barSize: workspacePane.barSize
        onActivated: workspacePane.paneActivated()
    }
}
 