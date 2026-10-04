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

    // Чистый модульный расчет полной естественной высоты листа (Header + Content + Overscroll)
    // Расчет от обратного: при максимальном скролле внизу экрана всегда видна хотя бы 1 строка
    readonly property real singleLineHeight: (editorArea && editorArea.font.pixelSize > 0) ? (editorArea.font.pixelSize * 1.35) : 24
    readonly property real overscrollPadding: {
        let reservedTop = (sheetRoot.showHeader && !sheetRoot.isHeaderPinned) ? 70 : 16
        let minVisibleSpace = Theme.minVisibleLinesAtBottom * singleLineHeight
        return Math.max(0, sheetRoot.viewHeight - reservedTop - minVisibleSpace)
    }
    readonly property real contentNaturalHeight: {
        var hHeader = (sheetRoot.showHeader && !sheetRoot.isHeaderPinned) ? 70 : 16
        var hContent = (editorCanvas && editorCanvas.implicitHeight > 0) 
            ? editorCanvas.implicitHeight 
            : ((editorArea && editorArea.implicitHeight > 0) ? editorArea.implicitHeight : 0)
        return hHeader + hContent + 40 + overscrollPadding
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

    visible: !isEmpty
    width: isCenteredMode ? Math.min(parent.width, Math.max(minSheetWidth, customSheetWidth)) : parent.width
    height: contentNaturalHeight
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
        anchors.topMargin: (sheetRoot.showHeader && !sheetRoot.isHeaderPinned) ? 70 : 16
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
        onToggleHistoryRequested: sheetRoot.toggleHistoryRequested()
        onToggleInfoRequested: sheetRoot.toggleInfoRequested()
        onToggleSearchRequested: sheetRoot.toggleSearchRequested()
        onTogglePathRequested: sheetRoot.togglePathRequested()
        onShowFileNameRequested: sheetRoot.showFileNameRequested()
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
}
