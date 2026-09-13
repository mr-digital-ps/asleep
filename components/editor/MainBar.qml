import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../js/editor/block_sync.js" as BlockSync
import "../../js/editor/mainbar_controller.js" as Controller
import "../graph"
import "../theme"

Item {
    id: mainBar

    // Свойства
    property int barSize: 36
    property string fileName: "Новый документ"
    property string fileUrl: ""
    property bool isCenteredMode: true
    property real customSheetWidth: 800
    property real minSheetWidth: 380
    property bool isCustomWidthSetByUser: false
    property bool isCustomFontSizeSetByUser: false
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

    // Свойства графа связей на листе
    property bool isGraphMode: false
    property string folderUrl: ""
    property string currentFolderName: ""
    readonly property string graphStatsText: sheetGraphView ? sheetGraphView.getGraphStats() : ""

    onIsGraphModeChanged: Controller.handleGraphModeChanged(mainBar, editorScroll, sheetGraphView, editorArea, smoothScrollAnim)

    function toggleHeaderFooter() {
        Controller.toggleHeaderFooter(mainBar, (typeof backend !== "undefined" ? backend : null))
    }

    function toggleFooterOnly() {
        Controller.toggleFooterOnly(mainBar, (typeof backend !== "undefined" ? backend : null))
    }

    function toggleHeaderOnly() {
        Controller.toggleHeaderOnly(mainBar, (typeof backend !== "undefined" ? backend : null))
    }

    readonly property string statsString: Controller.calculateStats((editorCanvas && editorCanvas.text) ? editorCanvas.text : "")

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
    property alias editorArea: editorCanvas.editorArea
    property alias editorScroll: editorScroll
    property alias text: editorCanvas.text
    property alias titleField: docHeader.titleField
    property bool isTitleFocused: docHeader ? docHeader.titleField.activeFocus : false
    readonly property real scrollY: (editorScroll && editorScroll.contentItem) ? editorScroll.contentItem.contentY : 0

    // Сигналы
    signal titleChangedByUser(string newTitle)
    signal closeRequested()
    signal paneActivated()
    signal detachRequested()
    signal saveRequested()
    signal newRequested()
    signal toggleSidebarRequested()
    signal toggleGraphRequested()
    signal openRequested()
    signal nodeSelected(string fileUrl, string label)
    signal closeGraphRequested()
    signal toggleGraphModeRequested(bool toGraph)
    signal fileDragStarted(string url, string name, real gx, real gy)
    signal fileDragMoved(real gx, real gy)
    signal fileDragEnded(string url, string name, real gx, real gy)


    readonly property bool isResizingSheet: (leftHandle && (leftHandle.containsMouse || leftHandle.pressed)) || (rightHandle && (rightHandle.containsMouse || rightHandle.pressed))

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
            if (docHeader && docHeader.titleField && docHeader.titleField.activeFocus) return
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
        Binding {
            target: editorScroll.contentItem
            property: "interactive"
            value: !mainBar.isGraphMode
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
            readonly property real lastLineTop: editorArea ? (editorCanvas.y + editorArea.topPadding + editorArea.contentHeight - singleLineHeight) : 0
            height: mainBar.isGraphMode ? mainBar.height : Math.max(mainBar.height, (editorArea && editorArea.lineCount > 1 && editorArea.contentHeight > 60)
                ? Math.max(mainBar.height, lastLineTop - (headerOffset + 16) + editorScroll.availableHeight)
                : mainBar.height)

            // Перетаскивание файла по пустому пространству вокруг документа (в режиме сплита)
            MouseArea {
                anchors.fill: parent
                z: -1
                acceptedButtons: Qt.LeftButton
                cursorShape: mainBar.isSplitMode ? Qt.OpenHandCursor : Qt.ArrowCursor
                hoverEnabled: true

                property real pressX: 0
                property real pressY: 0
                property bool isPressed: false
                property bool isDragging: false

                onPressed: (mouse) => Controller.handleBackgroundDragPressed(mouse, mainBar, this)
                onPositionChanged: (mouse) => Controller.handleBackgroundDragMoved(mouse, mainBar, scrollContentContainer, this)
                onReleased: (mouse) => Controller.handleBackgroundDragReleased(mouse, mainBar, scrollContentContainer, this)
            }


            // Экран-заглушка, если нет открытых файлов
            EditorEmptyState {
                visible: mainBar.isEmpty && !mainBar.isGraphMode
            }

            // Поле для отображения страницы (на полную или среднюю/настраиваемую ширину)
            Rectangle {
                id: paperSheet
                visible: !mainBar.isEmpty || mainBar.isGraphMode

                width: mainBar.isCenteredMode ? Math.min(parent.width, Math.max(mainBar.minSheetWidth, mainBar.customSheetWidth)) : parent.width
                height: parent.height
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top

                color: Theme.bgPaper

                opacity: (mainBar.isSplitMode && !mainBar.isActivePane) ? 0.55 : 1.0
                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }

                // Фокус-режим: затемнение неактивных строк
                EditorFocusDimmer {
                    editorArea: editorCanvas.editorArea
                    focusMode: mainBar.focusMode
                }

                // 1. Верхний контейнер заголовка (с поддержкой закрепления Sticky Header)
                EditorHeader {
                    id: docHeader
                    anchors.left: parent.left
                    anchors.right: parent.right
                    fileName: mainBar.fileName
                    fileUrl: mainBar.fileUrl
                    isSplitMode: mainBar.isSplitMode
                    isActivePane: mainBar.isActivePane
                    isEmpty: mainBar.isEmpty
                    isPinned: mainBar.isHeaderPinned
                    isGraphMode: mainBar.isGraphMode
                    folderName: mainBar.currentFolderName
                    scrollY: mainBar.scrollY
                    contentLeftPadding: editorArea.leftPadding
                    contentRightPadding: editorArea.rightPadding
                    visible: mainBar.showHeader && (!mainBar.isEmpty || mainBar.isGraphMode)

                    onTitleCommitted: (newTitle) => mainBar.titleChangedByUser(newTitle)
                    onPaneActivated: mainBar.paneActivated()
                    onPinToggled: {
                        mainBar.isHeaderPinned = !mainBar.isHeaderPinned
                        mainBar.saveHeaderPinnedState(mainBar.isHeaderPinned)
                    }
                }

                // 2. Рабочая область документа (Gutter + TextArea + шорткаты)
                EditorCanvas {
                    id: editorCanvas
                    visible: !mainBar.isGraphMode && !mainBar.isEmpty
                    anchors.top: parent.top
                    anchors.topMargin: mainBar.showHeader ? 70 : 16
                    anchors.left: parent.left
                    anchors.right: parent.right
                    availableHeight: editorScroll.availableHeight
                    barSize: mainBar.barSize
                    customFontFamily: mainBar.customFontFamily
                    hasHeader: mainBar.showHeader
                    hasFooter: mainBar.showFooter

                    onPaneActivated: mainBar.paneActivated()
                    onCursorVisibilityRequested: mainBar.requestEnsureCursorVisible()
                    onToggleHeaderFooterRequested: mainBar.toggleHeaderFooter()
                    onToggleFooterRequested: mainBar.toggleFooterOnly()
                    onToggleHeaderRequested: mainBar.toggleHeaderOnly()
                    onToggleCenteredModeRequested: mainBar.isCenteredMode = !mainBar.isCenteredMode
                    onSaveRequested: mainBar.saveRequested()
                    onOpenRequested: mainBar.openRequested()
                    onNewRequested: mainBar.newRequested()
                    onToggleSidebarRequested: mainBar.toggleSidebarRequested()
                    onToggleGraphRequested: mainBar.toggleGraphRequested()
                    onTextChangedByUser: Controller.handleTextChangedByUser(mainBar, blockSyncTimer, activeFocus)
                    onScrollRequested: (dy) => mainBar.smoothScrollBy(dy)
                    onScrollToTopRequested: {
                        if (editorScroll && editorScroll.contentItem) {
                            editorScroll.contentItem.contentY = 0
                        }
                    }
                    onFontSizeChanged: (sz) => Controller.handleFontSizeChanged(mainBar, (typeof backend !== "undefined" ? backend : null), sz)
                    onCloseRequested: mainBar.closeRequested()
                    onDetachRequested: mainBar.detachRequested()
                    onSyncNoticeRequested: (t) => mainBar.showSyncNotice(t)
                }

                // 2.1 Интерактивный граф связей на листе (In-Sheet Graph View)
                GraphView {
                    id: sheetGraphView
                    visible: mainBar.isGraphMode
                    embeddedInSheet: true
                    folderUrl: mainBar.folderUrl
                    activeFileUrl: mainBar.fileUrl
                    anchors.top: parent.top
                    anchors.topMargin: mainBar.showHeader ? 70 : 0
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: mainBar.showFooter ? 70 : 0
                    anchors.left: parent.left
                    anchors.right: parent.right

                    onNodeClicked: (fUrl, lbl, type) => {
                        mainBar.paneActivated()
                        mainBar.nodeSelected(fUrl, lbl)
                    }
                    onCloseRequested: {
                        mainBar.closeGraphRequested()
                        if (editorArea) {
                            Qt.callLater(() => editorArea.forceActiveFocus())
                        }
                    }
                }

                // 3. Нижний контейнер со статистикой и разделителем (прилипает к низу экрана)
                EditorFooter {
                    id: docFooter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 70
                    z: 20
                    isPinned: mainBar.isFooterPinned
                    isGraphMode: mainBar.isGraphMode
                    statsText: mainBar.isGraphMode ? mainBar.graphStatsText : mainBar.statsString
                    visible: mainBar.showFooter && (!mainBar.isEmpty || mainBar.isGraphMode)
                    y: Controller.calculateFooterY(mainBar, docFooter, editorCanvas, editorScroll)

                    onPinToggled: {
                        mainBar.isFooterPinned = !mainBar.isFooterPinned
                        mainBar.saveFooterPinnedState(mainBar.isFooterPinned)
                        mainBar.paneActivated()
                    }
                    onActivated: mainBar.paneActivated()
                }

                // Интерактивная граница изменения ширины листа слева
                SheetResizeHandle {
                    id: leftHandle
                    isLeft: true
                    containerItem: scrollContentContainer
                    anchors.left: parent.left
                    anchors.leftMargin: -12
                    minWidth: mainBar.minSheetWidth
                    maxWidth: scrollContentContainer.width
                    forceVisible: mainBar.isResizingSheet
                    onSheetWidthRequested: (w) => Controller.handleSheetWidthRequested(mainBar, w)
                    onSheetWidthCommitted: (w) => Controller.handleSheetWidthCommitted(mainBar, (typeof backend !== "undefined" ? backend : null), w)
                    onDoubleClickedToggle: mainBar.toggleFullWidth()
                }

                // Интерактивная граница изменения ширины листа справа
                SheetResizeHandle {
                    id: rightHandle
                    isLeft: false
                    containerItem: scrollContentContainer
                    anchors.right: parent.right
                    anchors.rightMargin: -12
                    minWidth: mainBar.minSheetWidth
                    maxWidth: scrollContentContainer.width
                    forceVisible: mainBar.isResizingSheet
                    onSheetWidthRequested: (w) => Controller.handleSheetWidthRequested(mainBar, w)
                    onSheetWidthCommitted: (w) => Controller.handleSheetWidthCommitted(mainBar, (typeof backend !== "undefined" ? backend : null), w)
                    onDoubleClickedToggle: mainBar.toggleFullWidth()
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
        barSize: 36
        onActivated: mainBar.paneActivated()
    }
}
