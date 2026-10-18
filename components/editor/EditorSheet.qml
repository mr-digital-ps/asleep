import QtQuick
import "../theme"

Rectangle {
    id: sheetRoot

    // Основные свойства и привязки
    property int barSize: Theme.barSize
    property string fileName: "Новый документ"
    property string fileUrl: ""
    property string folderUrl: ""
    property bool isCenteredMode: true
    property real customSheetWidth: Theme.defaultSheetWidth
    property real minSheetWidth: Theme.minSheetWidth
    property bool isActivePane: false
    property bool isEmpty: false
    property bool typewriterMode: false
    property bool focusMode: false
    property bool isHeaderPinned: false
    property bool showHeader: true
    property bool showLineDots: true
    property bool isLiveMode: true
    property int tabSize: Theme.defaultTabSize
    property real scrollY: 0
    property string statsString: "0 слов · 0 знаков"
    property real availableHeight: 600
    property real viewHeight: availableHeight
    property var editorScroll: null

    property var _liveDraftText: undefined

    onFileUrlChanged: {
        _liveDraftText = undefined
        if (editorArea) editorArea.readOnly = false
        if (editorCanvas && typeof editorCanvas.resetFolding === "function") editorCanvas.resetFolding()
    }

    // Экспорт внутренних компонентов наружу
    property alias editorCanvas: editorCanvas
    property alias editorArea: editorCanvas.editorArea
    property alias text: editorCanvas.text

    function resetFolding() {
        if (editorCanvas && typeof editorCanvas.resetFolding === "function") {
            editorCanvas.resetFolding()
        }
    }

    signal toggleLiveModeRequested()
    signal toggleSourceModeRequested()

    // Естественная высота текста документа
    readonly property real contentTopMargin: sheetRoot.showHeader ? Theme.headerHeight : Theme.sheetPadding
    readonly property real docContentHeight: (editorArea && editorArea.contentHeight > 0) ? editorArea.contentHeight : 0
    readonly property real contentNaturalHeight: docContentHeight + contentTopMargin + Theme.sheetPadding

    // Сигналы
    signal paneActivated()
    signal titleChangedByUser(string newTitle)
    signal closeRequested()
    signal detachRequested()
    signal saveRequested()
    signal newRequested()
    signal toggleGraphRequested()
    signal openRequested()
    signal cursorVisibilityRequested()
    signal toggleHistoryRequested()
    signal toggleInfoRequested()
    signal toggleSearchRequested()
    signal togglePathRequested()
    signal showFileNameRequested()
    signal toggleTabsRequested()
    signal toggleHeaderRequested()
    signal toggleCenteredModeRequested()
    signal textChangedByUser()
    signal scrollRequested(real dy)
    signal scrollToTopRequested()
    signal fontSizeChanged(int newSize)
    signal syncNoticeRequested(string title)
    signal headerPinToggled(bool pinned)
    signal panelDragStarted(var mouse, var item)
    signal panelDragUpdated(var mouse, var item)
    signal panelDragFinished()

    visible: !isEmpty
    width: parent ? parent.width : minSheetWidth
    height: Math.max(sheetRoot.viewHeight, contentNaturalHeight)
    y: 0
    anchors.left: parent ? parent.left : undefined
    anchors.right: parent ? parent.right : undefined
    anchors.top: parent ? parent.top : undefined

    color: Theme.bgPaper

    opacity: 1.0
    Behavior on opacity {
        NumberAnimation { duration: Theme.animDurationNormal }
    }

    // Фокус-режим: затемнение неактивных строк
    EditorFocusDimmer {
        editorArea: editorCanvas.editorArea
        focusMode: sheetRoot.focusMode
    }

    // Рабочая область документа (Gutter + TextArea + шорткаты)
    EditorCanvas {
        id: editorCanvas
        visible: !sheetRoot.isEmpty
        anchors.top: parent.top
        anchors.topMargin: sheetRoot.contentTopMargin
        anchors.left: parent.left
        anchors.right: parent.right
        availableHeight: sheetRoot.availableHeight
        barSize: sheetRoot.barSize
        showLineDots: sheetRoot.showLineDots
        isLiveMode: sheetRoot.isLiveMode
        tabSize: sheetRoot.tabSize
        hasHeader: sheetRoot.showHeader
        hasFooter: false

        onPaneActivated: sheetRoot.paneActivated()
        onPanelDragStarted: (mouse, item) => sheetRoot.panelDragStarted(mouse, item)
        onPanelDragUpdated: (mouse, item) => sheetRoot.panelDragUpdated(mouse, item)
        onPanelDragFinished: () => sheetRoot.panelDragFinished()
        onCursorVisibilityRequested: sheetRoot.cursorVisibilityRequested()
        onToggleHistoryRequested: sheetRoot.toggleHistoryRequested()
        onToggleInfoRequested: sheetRoot.toggleInfoRequested()
        onToggleSearchRequested: sheetRoot.toggleSearchRequested()
        onTogglePathRequested: sheetRoot.togglePathRequested()
        onShowFileNameRequested: sheetRoot.showFileNameRequested()
        onToggleTabsRequested: sheetRoot.toggleTabsRequested()
        onToggleHeaderRequested: sheetRoot.toggleHeaderRequested()
        onToggleCenteredModeRequested: sheetRoot.toggleCenteredModeRequested()
        onToggleLiveModeRequested: sheetRoot.toggleLiveModeRequested()
        onToggleSourceModeRequested: sheetRoot.toggleSourceModeRequested()
        onSaveRequested: sheetRoot.saveRequested()
        onOpenRequested: sheetRoot.openRequested()
        onNewRequested: sheetRoot.newRequested()
        onToggleGraphRequested: sheetRoot.toggleGraphRequested()
        onTextChangedByUser: sheetRoot.textChangedByUser()
        onScrollRequested: (dy) => sheetRoot.scrollRequested(dy)
        onScrollToTopRequested: sheetRoot.scrollToTopRequested()
        onFontSizeChanged: (sz) => sheetRoot.fontSizeChanged(sz)
        onCloseRequested: sheetRoot.closeRequested()
        onDetachRequested: sheetRoot.detachRequested()
        onSyncNoticeRequested: (t) => sheetRoot.syncNoticeRequested(t)
    }

    function getLiveText() {
        if (typeof _liveDraftText === "string") return _liveDraftText
        if (editorCanvas && typeof editorCanvas.getFullTextWithoutFolding === "function") {
            return editorCanvas.getFullTextWithoutFolding()
        }
        return editorArea.text
    }

    function loadHistoricalSnapshot(snapshotId) {
        if (typeof backend === "undefined" || !backend) return

        if (typeof _liveDraftText === "undefined" && editorArea) {
            _liveDraftText = editorArea.text
        }
        if (typeof backend.get_history_file_content === "function") {
            let targetPath = sheetRoot.fileUrl ? sheetRoot.fileUrl : sheetRoot.fileName
            let snapText = backend.get_history_file_content(sheetRoot.folderUrl, snapshotId, targetPath)
            if (typeof snapText === "string" && editorArea) {
                editorArea.text = snapText
                editorArea.readOnly = true
            }
        }
    }

    function restoreLive() {
        if (typeof _liveDraftText === "string") {
            if (editorArea) {
                editorArea.text = _liveDraftText
                editorArea.readOnly = false
            }
            _liveDraftText = undefined
        } else if (sheetRoot.fileUrl && typeof backend !== "undefined" && backend) {
            let liveText = backend.read_file(sheetRoot.fileUrl)
            if (editorArea && typeof liveText === "string") {
                editorArea.text = liveText
                editorArea.readOnly = false
            }
        } else if (editorArea) {
            editorArea.readOnly = false
        }
    }
}
