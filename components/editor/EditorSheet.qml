import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: sheetRoot

    // Основные свойства и привязки
    property int barSize: 36
    property string fileName: "Новый документ"
    property string fileUrl: ""
    property string folderUrl: ""
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
    property bool showHeader: true
    property bool showLineDots: true
    property int tabSize: 4
    property real scrollY: 0
    property string statsString: "0 слов · 0 знаков"
    property real availableHeight: 600
    property real viewHeight: availableHeight
    property var containerItem: null
    property var editorScroll: null

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
    property alias leftHandle: leftHandle
    property alias rightHandle: rightHandle
    readonly property bool isResizingSheet: (leftHandle && (leftHandle.containsMouse || leftHandle.pressed)) || (rightHandle && (rightHandle.containsMouse || rightHandle.pressed))

    // Чистый модульный расчет полной естественной высоты листа (только текст)
    readonly property real contentNaturalHeight: {
        var hContent = (editorArea && editorArea.contentHeight > 0) ? editorArea.contentHeight : 0
        return hContent + 40
    }

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
    signal cursorVisibilityRequested()
    signal toggleHeaderFooterRequested()
    signal toggleFooterRequested()
    signal toggleFooterModeRequested()
    signal toggleHistoryRequested()
    signal toggleInfoRequested()
    signal toggleSearchRequested()
    signal togglePathRequested()
    signal toggleTabsRequested()
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

    visible: !isEmpty
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

    // Рабочая область документа (Gutter + TextArea + шорткаты)
    EditorCanvas {
        id: editorCanvas
        visible: !sheetRoot.isEmpty
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.right: parent.right
        availableHeight: sheetRoot.availableHeight
        barSize: sheetRoot.barSize
        showLineDots: sheetRoot.showLineDots
        tabSize: sheetRoot.tabSize
        customFontFamily: sheetRoot.customFontFamily
        hasHeader: sheetRoot.showHeader
        hasFooter: false

        onPaneActivated: sheetRoot.paneActivated()
        onCursorVisibilityRequested: sheetRoot.cursorVisibilityRequested()
        onToggleHeaderFooterRequested: sheetRoot.toggleHeaderFooterRequested()
        onToggleFooterRequested: sheetRoot.toggleFooterRequested()
        onToggleFooterModeRequested: sheetRoot.toggleFooterModeRequested()
        onToggleHistoryRequested: sheetRoot.toggleHistoryRequested()
        onToggleInfoRequested: sheetRoot.toggleInfoRequested()
        onToggleSearchRequested: sheetRoot.toggleSearchRequested()
        onTogglePathRequested: sheetRoot.togglePathRequested()
        onToggleTabsRequested: sheetRoot.toggleTabsRequested()
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

    function loadHistoricalSnapshot(snapshotId) {
        if (typeof backend === "undefined" || !backend) return

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
