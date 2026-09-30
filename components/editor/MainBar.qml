import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "./block_sync.js" as BlockSync
import "./mainbar_controller.js" as Controller
import "../theme"

Item {
    id: mainBar

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

    // Свойства графа связей на листе
    property bool isGraphMode: false
    property string folderUrl: ""
    property string currentFolderName: ""
    property var openFileUrls: []
    readonly property string graphStatsText: paperSheet ? paperSheet.graphStatsText : ""

    onIsGraphModeChanged: Controller.handleGraphModeChanged(mainBar, editorScroll, paperSheet.sheetGraphView, editorArea, smoothScrollAnim)

    function toggleHeaderFooter() {
        Controller.toggleHeaderFooter(mainBar, (typeof backend !== "undefined" ? backend : null))
    }

    function toggleFooterOnly() {
        Controller.toggleFooterOnly(mainBar, (typeof backend !== "undefined" ? backend : null))
    }

    function toggleHeaderOnly() {
        Controller.toggleHeaderOnly(mainBar, (typeof backend !== "undefined" ? backend : null))
    }

    function toggleCenteredMode() {
        mainBar.isCenteredMode = !mainBar.isCenteredMode
    }

    // Режим локального графа заметки
    property bool isLocalGraphMode: false

    // Режим иерархии блоков документа (Outliner)
    property bool isOutlineMode: false
    property alias sheetOutliner: paperSheet.sheetOutliner
    property alias sheetGraphView: paperSheet.sheetGraphView
    property alias docHeader: paperSheet.docHeader
    property alias docFooter: paperSheet.docFooter
    property alias paperSheet: paperSheet

    function toggleOutlineMode() {
        if (mainBar.isGraphMode) return
        mainBar.isOutlineMode = !mainBar.isOutlineMode
        if (mainBar.isOutlineMode && paperSheet.sheetOutliner) {
            paperSheet.sheetOutliner.reload()
        }
    }

    property string statsString: "0 слов · 0 знаков"

    Timer {
        id: statsUpdateTimer
        interval: 300
        repeat: false
        onTriggered: {
            mainBar.statsString = Controller.calculateStats((paperSheet && paperSheet.text) ? paperSheet.text : "")
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

    // Доступ к редактору и заголовку для внешних скриптов (обратная совместимость)
    property alias editorArea: paperSheet.editorArea
    property alias editorScroll: editorScroll
    property alias text: paperSheet.text
    property alias titleField: paperSheet.titleField
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
        let newTxt = Controller.updateConfigParameterInText(mainBar.fileName, editorArea.text, key, value)
        if (newTxt !== null) {
            let curPos = editorArea.cursorPosition
            editorArea.text = newTxt
            editorArea.cursorPosition = Math.min(curPos, newTxt.length)
        }
    }

    function toggleFullWidth() {
        Controller.toggleFullWidth(mainBar, editorScroll, (typeof backend !== "undefined" ? backend : null))
    }

    function applyConfig(cfg) {
        Controller.applyEditorConfig(mainBar, editorArea, cfg, (typeof backend !== "undefined" ? backend : null))
    }

    Component.onCompleted: Controller.initMainBar(mainBar, editorArea, (typeof backend !== "undefined" ? backend : null))

    onEditorLineHeightPercentChanged: Controller.handleLineHeightChanged(editorArea, mainBar, (typeof backend !== "undefined" ? backend : null))

    onFileUrlChanged: Controller.handleFileUrlChanged(editorArea, mainBar, (typeof backend !== "undefined" ? backend : null))

    // Автоматическая прокрутка для удержания текстового курсора "|" в поле зрения
    function ensureCursorVisible() {
        Controller.ensureCursorVisible(mainBar, editorArea, editorScroll)
    }

    function requestEnsureCursorVisible() {
        Qt.callLater(mainBar.ensureCursorVisible)
    }

    // Применение внешнего обновления блока от другого окна или сплит-панели
    function applyExternalBlockUpdate(headingNorm, newContent) {
        let res = BlockSync.applyExternalBlockUpdate(editorArea, headingNorm, newContent)
        if (res) {
            mainBar.isReceivingExternalSync = true
            editorArea.text = res.text
            editorArea.cursorPosition = res.cursor
            mainBar.isReceivingExternalSync = false
        }
    }

    // Таймер дебаунса для синхронизации редактируемого блока с бэкендом
    Timer {
        id: blockSyncTimer
        interval: 350
        repeat: false
        onTriggered: Controller.handleBlockSyncTriggered(mainBar, editorArea, (typeof backend !== "undefined" ? backend : null), BlockSync)
    }

    // Всплывающее уведомление о синхронизации блока
    SyncNotice {
        id: syncNotice
    }

    function showSyncNotice(title) {
        syncNotice.showNotice(title)
    }

    // Перехват кликов по панели для мгновенной активации нужной половины сплита
    TapHandler {
        gesturePolicy: TapHandler.WithinBounds
        onTapped: {
            if (paperSheet && paperSheet.titleField && paperSheet.titleField.activeFocus) return
            mainBar.paneActivated()
        }
    }

    // =========================================================================
    // ХОЛСТ РЕДАКТОРА
    // =========================================================================
    ScrollView {
        id: editorScroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        contentHeight: scrollContentContainer.height
        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        Binding {
            target: editorScroll.contentItem
            property: "interactive"
            value: !mainBar.isGraphMode
        }
        Binding {
            target: editorScroll.contentItem
            property: "contentY"
            value: 0
            when: mainBar.isGraphMode
        }

        WheelHandler {
            target: editorScroll.contentItem
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            enabled: !mainBar.isGraphMode
            onWheel: (event) => Controller.handleWheel(mainBar, editorArea, editorScroll, smoothScrollAnim, event, (typeof backend !== "undefined" ? backend : null))
        }

        Connections {
            target: editorScroll.contentItem
            function onContentHeightChanged() {
                if (editorArea && editorArea.activeFocus) {
                    mainBar.requestEnsureCursorVisible()
                }
            }
        }

        Item {
            id: scrollContentContainer
            width: editorScroll.availableWidth
            readonly property real singleLineHeight: (editorArea && editorArea.cursorRectangle.height > 0) ? editorArea.cursorRectangle.height : 24
            readonly property real headerOffset: (mainBar.showHeader && mainBar.isHeaderPinned) ? 70 : 0
            readonly property real lastLineTop: editorArea ? (paperSheet.editorCanvas.y + editorArea.topPadding + editorArea.contentHeight - singleLineHeight) : 0
            height: mainBar.isGraphMode ? mainBar.height : Math.max(mainBar.height, (editorArea && editorArea.lineCount > 1 && editorArea.contentHeight > 60)
                ? Math.max(mainBar.height, lastLineTop - (headerOffset + 16) + editorScroll.availableHeight)
                : mainBar.height)

            // Перетаскивание окна по пустому пространству вокруг документа (фона)
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.ArrowCursor
                hoverEnabled: true
                preventStealing: true

                onPressed: (mouse) => Controller.handleBackgroundDragPressed(mouse, mainBar, this)
                onDoubleClicked: {
                    var win = mainBar.targetWindow
                    if (win) {
                        if (win.visibility === Window.Maximized) {
                            win.showNormal()
                        } else {
                            win.showMaximized()
                        }
                    }
                }
            }

            // Экран-заглушка, если нет открытых файлов
            EditorEmptyState {
                visible: mainBar.isEmpty && !mainBar.isGraphMode
            }

            // Лист документа (EditorSheet)
            EditorSheet {
                id: paperSheet
                barSize: mainBar.barSize
                fileName: mainBar.fileName
                fileUrl: mainBar.fileUrl
                folderUrl: mainBar.folderUrl
                openFileUrls: mainBar.openFileUrls
                isCenteredMode: mainBar.isCenteredMode
                customSheetWidth: mainBar.customSheetWidth
                minSheetWidth: mainBar.minSheetWidth
                isSplitMode: mainBar.isSplitMode
                isActivePane: mainBar.isActivePane
                isEmpty: mainBar.isEmpty
                customFontFamily: mainBar.customFontFamily
                typewriterMode: mainBar.typewriterMode
                focusMode: mainBar.focusMode
                isHeaderPinned: mainBar.isHeaderPinned
                isFooterPinned: mainBar.isFooterPinned
                showHeader: mainBar.showHeader
                showFooter: mainBar.showFooter
                showLineDots: mainBar.showLineDots
                tabSize: mainBar.tabSize
                scrollY: mainBar.scrollY
                statsString: mainBar.statsString
                availableHeight: editorScroll.availableHeight
                viewHeight: mainBar.height
                containerItem: scrollContentContainer
                editorScroll: editorScroll
                isGraphMode: mainBar.isGraphMode
                isLocalGraphMode: mainBar.isLocalGraphMode
                isOutlineMode: mainBar.isOutlineMode

                onTitleChangedByUser: (t) => mainBar.titleChangedByUser(t)
                onPaneActivated: mainBar.paneActivated()
                onCloseRequested: mainBar.closeRequested()
                onDetachRequested: mainBar.detachRequested()
                onSaveRequested: mainBar.saveRequested()
                onNewRequested: mainBar.newRequested()
                onNewSplitRequested: mainBar.newSplitRequested()
                onToggleGraphRequested: mainBar.toggleGraphRequested()
                onToggleSplitRequested: mainBar.toggleSplitRequested()
                onOpenRequested: mainBar.openRequested()
                onOpenSplitRequested: mainBar.openSplitRequested()
                onNodeSelected: (u, l) => mainBar.nodeSelected(u, l)
                onCloseGraphRequested: mainBar.closeGraphRequested()
                onOpenStructureRequested: mainBar.openStructureRequested()
                onCursorVisibilityRequested: mainBar.requestEnsureCursorVisible()
                onToggleHeaderFooterRequested: mainBar.toggleHeaderFooter()
                onToggleFooterRequested: mainBar.toggleFooterOnly()
                onToggleHeaderRequested: mainBar.toggleHeaderOnly()
                onToggleCenteredModeRequested: mainBar.isCenteredMode = !mainBar.isCenteredMode
                onTextChangedByUser: {
                    Controller.handleTextChangedByUser(mainBar, blockSyncTimer, activeFocus)
                    statsUpdateTimer.restart()
                }
                onScrollRequested: (dy) => mainBar.smoothScrollBy(dy)
                onScrollToTopRequested: {
                    if (editorScroll && editorScroll.contentItem) {
                        editorScroll.contentItem.contentY = 0
                    }
                }
                onFontSizeChanged: (sz) => Controller.handleFontSizeChanged(mainBar, (typeof backend !== "undefined" ? backend : null), sz)
                onSyncNoticeRequested: (t) => mainBar.showSyncNotice(t)
                onSheetWidthRequested: (w) => Controller.handleSheetWidthRequested(mainBar, w)
                onSheetWidthCommitted: (w) => Controller.handleSheetWidthCommitted(mainBar, (typeof backend !== "undefined" ? backend : null), w)
                onToggleFullWidthRequested: mainBar.toggleFullWidth()
                onHeaderPinToggled: (pinned) => mainBar.saveHeaderPinnedState(pinned)
                onFooterPinToggled: (pinned) => mainBar.saveFooterPinnedState(pinned)
                onOutlineModeToggled: mainBar.toggleOutlineMode()
                onTextChangedByOutliner: (newText) => {
                    mainBar.text = newText
                    if (mainBar.editorArea) {
                        mainBar.editorArea.text = newText
                    }
                    if (mainBar.fileUrl && typeof backend !== "undefined" && backend) {
                        backend.save_file(mainBar.fileUrl, newText)
                    }
                }
                onSnapshotSelected: (snapshotId) => {
                    // Делегировано в paperSheet.loadHistoricalSnapshot
                }
                onLiveRequested: {
                    // Делегировано в paperSheet.restoreLive
                }
            }
        }
    }

    // Правая полоса со скроллбаром документа
    EditorScrollbar {
        id: editorScrollbar
        editorScroll: editorScroll
        paperSheet: paperSheet
        isEmpty: mainBar.isEmpty || mainBar.isGraphMode
        hasHeader: mainBar.showHeader
        hasFooter: mainBar.showFooter
        barSize: mainBar.barSize
        onActivated: mainBar.paneActivated()
    }
}
