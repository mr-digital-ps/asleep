import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "./outliner"
import "../../js/editor/outliner_controller.js" as OutlinerCtrl

Item {
    id: outlinerRoot

    property string documentText: ""
    property string fileName: ""
    property string folderUrl: ""
    property string highlightLabel: ""
    property var blocksList: []
    property int draggingIndex: -1
    property int dragOverIndex: -1
    property string dragPosition: "before"
    property var collapsedFolders: ({})

    readonly property bool isProjectTree: {
        if (typeof backend !== "undefined" && backend && typeof backend.is_project_structure_file === "function") {
            if (backend.is_project_structure_file(fileName)) return true
        }
        var fnLower = (fileName || "").toLowerCase()
        return fnLower.indexOf("_структура") !== -1 || fnLower.indexOf("structure") !== -1 ||
               (outlinerRoot.documentText && outlinerRoot.documentText.trim().toLowerCase().startsWith("# структура проекта"))
    }

    signal textChangedByOutliner(string newText)
    signal closeRequested()
    signal paneActivated()
    signal openFileRequested(string fileUrl, string label)
    signal jumpToHeadingRequested(string heading)

    function scrollToHighlight() {
        var idx = OutlinerCtrl.findHighlightIndex(highlightLabel, blocksList)
        if (idx >= 0) {
            blocksListView.currentIndex = idx
            blocksListView.positionViewAtIndex(idx, ListView.Center)
        }
    }

    onBlocksListChanged: {
        if (highlightLabel) Qt.callLater(scrollToHighlight)
    }
    onHighlightLabelChanged: {
        if (highlightLabel) Qt.callLater(scrollToHighlight)
    }

    function toggleFolder(folderKey) {
        collapsedFolders = OutlinerCtrl.toggleFolder(collapsedFolders, folderKey)
    }

    function isFolderCollapsed(folderKey) {
        return OutlinerCtrl.isFolderCollapsed(collapsedFolders, folderKey)
    }

    function isItemHidden(itemIdx) {
        return OutlinerCtrl.isItemHidden(itemIdx, blocksList, collapsedFolders)
    }

    function collapseAll() {
        collapsedFolders = OutlinerCtrl.collapseAll(blocksList)
    }

    function expandAll() {
        collapsedFolders = OutlinerCtrl.expandAll()
    }

    readonly property int visibleCount: OutlinerCtrl.countVisible(blocksList, collapsedFolders)

    function reload() {
        if (typeof backend === "undefined" || !backend) return
        if (isProjectTree) {
            if (typeof backend.get_project_tree_flat === "function") {
                var res = backend.get_project_tree_flat(outlinerRoot.documentText)
                outlinerRoot.blocksList = (res && res.items) ? res.items : []
            }
        } else {
            if (typeof backend.get_document_outline === "function") {
                outlinerRoot.blocksList = backend.get_document_outline(outlinerRoot.documentText) || []
            }
        }
    }

    Component.onCompleted: reload()
    onVisibleChanged: { if (visible) reload() }
    onDocumentTextChanged: reload()
    onFileNameChanged: reload()

    function moveBlock(sourceIdx, targetIdx, position) {
        if (typeof backend === "undefined" || !backend) return
        if (sourceIdx < 0 || targetIdx < 0 || sourceIdx === targetIdx) return
        var newText = ""
        if (isProjectTree) {
            newText = backend.reorder_project_tree(outlinerRoot.documentText, sourceIdx, targetIdx, position)
        } else {
            newText = backend.reorder_document_outline(outlinerRoot.documentText, sourceIdx, targetIdx, position)
        }
        if (newText && newText !== outlinerRoot.documentText) {
            outlinerRoot.textChangedByOutliner(newText)
        }
    }

    function changeLevel(blockIdx, delta) {
        if (typeof backend === "undefined" || !backend) return
        if (blockIdx < 0) return
        var newText = ""
        if (isProjectTree) {
            newText = backend.change_project_tree_level(outlinerRoot.documentText, blockIdx, delta)
        } else {
            newText = backend.change_outline_level(outlinerRoot.documentText, blockIdx, delta)
        }
        if (newText && newText !== outlinerRoot.documentText) {
            outlinerRoot.textChangedByOutliner(newText)
        }
    }

    function addTreeItem(itemType) {
        if (typeof backend === "undefined" || !backend) return
        var defaultName = (itemType === "folder") ? "Новая папка" : "Новая заметка"
        var newText = backend.add_project_tree_item(outlinerRoot.documentText, defaultName, itemType, -1)
        if (newText && newText !== outlinerRoot.documentText) {
            outlinerRoot.textChangedByOutliner(newText)
        }
    }

    function openNote(noteLabel) {
        if (!noteLabel) return
        if (typeof backend !== "undefined" && backend && typeof backend.get_note_file_url === "function") {
            var fUrl = backend.get_note_file_url(noteLabel, outlinerRoot.folderUrl)
            if (fUrl) {
                outlinerRoot.openFileRequested(fUrl, noteLabel)
            }
        }
    }

    // Фоновая подложка листа
    Rectangle {
        anchors.fill: parent
        color: Theme.bgPaper
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 48
        anchors.topMargin: 12
        anchors.bottomMargin: 16
        spacing: 10

        // Верхняя панель заголовка аутлайнера (чистая типографика)
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            spacing: 8

            Text {
                text: outlinerRoot.isProjectTree ? "Структура проекта" : "Оглавление"
                font.pixelSize: 13
                font.bold: true
                color: Theme.textPrimary
            }

            Item { Layout.fillWidth: true }
        }

        // Содержимое: Список элементов (spacing: 0 исключает пустые дыры при скрытии)
        ListView {
            id: blocksListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 0
            interactive: outlinerRoot.draggingIndex < 0
            boundsBehavior: Flickable.StopAtBounds
            model: outlinerRoot.blocksList

            delegate: OutlinerTreeItem {
                id: itemDelegate
                blockIndex: index
                blockData: modelData

                isProjectTree: outlinerRoot.isProjectTree
                highlightLabel: outlinerRoot.highlightLabel
                isHidden: outlinerRoot.isItemHidden(itemDelegate.blockIndex)
                isFolderCollapsed: outlinerRoot.isFolderCollapsed(itemDelegate.blockKey)
                isBeingDragged: outlinerRoot.draggingIndex === itemDelegate.blockIndex
                isDragTarget: outlinerRoot.dragOverIndex === itemDelegate.blockIndex
                dragPosition: outlinerRoot.dragPosition

                onActivated: outlinerRoot.paneActivated()
                onDragStarted: (idx) => {
                    outlinerRoot.draggingIndex = idx
                }
                onDragMoved: (targetIdx, pos) => {
                    if (targetIdx >= 0 && targetIdx < outlinerRoot.blocksList.length) {
                        outlinerRoot.dragOverIndex = targetIdx
                        outlinerRoot.dragPosition = pos
                    }
                }
                onDragFinished: {
                    if (outlinerRoot.draggingIndex >= 0 && outlinerRoot.dragOverIndex >= 0 &&
                        outlinerRoot.draggingIndex !== outlinerRoot.dragOverIndex) {
                        outlinerRoot.moveBlock(outlinerRoot.draggingIndex, outlinerRoot.dragOverIndex, outlinerRoot.dragPosition)
                    }
                    outlinerRoot.draggingIndex = -1
                    outlinerRoot.dragOverIndex = -1
                }
                onDragCanceled: {
                    outlinerRoot.draggingIndex = -1
                    outlinerRoot.dragOverIndex = -1
                }
                onFolderToggled: (key) => outlinerRoot.toggleFolder(key)
                onFileClicked: (lbl) => outlinerRoot.openNote(lbl)
                onHeadingClicked: (heading) => outlinerRoot.jumpToHeadingRequested(heading)
            }
        }

        // Состояние, если в документе пока нет элементов
        Item {
            visible: outlinerRoot.blocksList.length === 0
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: outlinerRoot.isProjectTree ? "Структура проекта пуста" : "В документе нет заголовков"
                    font.pixelSize: 13
                    color: Theme.textSecondary
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: outlinerRoot.isProjectTree 
                        ? "Добавьте папки и заметки в файл структуры"
                        : "Добавьте заголовки # или ## в текст заметки"
                    font.pixelSize: 11
                    color: Theme.textMuted
                }
            }
        }
    }
}
