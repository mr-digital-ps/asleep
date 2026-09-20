import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../theme"
import "../../../js/editor/outliner_controller.js" as OutlinerCtrl

Item {
    id: itemRoot
    width: ListView.view ? ListView.view.width : 200

    property var blockData: null
    property int blockIndex: -1

    property bool isProjectTree: false
    property string highlightLabel: ""
    property bool isHidden: false
    property bool isFolderCollapsed: false
    property bool isBeingDragged: false
    property bool isDragTarget: false
    property string dragPosition: "before"

    signal activated()
    signal dragStarted(int index)
    signal dragMoved(int targetIndex, string position)
    signal dragFinished(int sourceIndex, int targetIndex, string position)
    signal dragCanceled()
    signal folderToggled(string folderKey)
    signal fileClicked(string label)
    signal headingClicked(string heading)

    visible: !isHidden
    clip: true

    readonly property string blockKey: blockData ? OutlinerCtrl.getItemKey(blockData) : ""
    readonly property int blockLevel: (blockData && typeof blockData.level === "number") ? blockData.level : 0
    readonly property int indentPx: OutlinerCtrl.calculateIndentPx(isProjectTree, blockLevel)
    readonly property bool hasChildren: Boolean(blockData && blockData.hasChildren)
    readonly property bool isFolder: Boolean(blockData && (blockData.type === "folder" || (!isProjectTree && hasChildren)))
    readonly property bool isSection: Boolean(blockData && blockData.type === "section")
    readonly property bool isFile: Boolean(isProjectTree && blockData && blockData.type === "file")
    readonly property bool isHeading: Boolean(!isProjectTree && blockData && (blockData.type === "heading" || blockLevel > 0))
    readonly property bool canCollapse: Boolean(hasChildren || isFolder || isSection)
    readonly property bool isCanvas: Boolean(blockData && (blockData.type === "canvas" || (blockData.label && blockData.label.toLowerCase().indexOf("диаграмма") >= 0)))
    readonly property bool isHighlighted: Boolean(isProjectTree && highlightLabel.length > 0 && 
        blockData && blockData.label && 
        blockData.label.toLowerCase().trim() === highlightLabel.toLowerCase().trim())
    readonly property bool hasContent: Boolean(blockData && blockData.content && blockData.content.trim().length > 0)

    // При скрытии высота строго 0, а при отображении включает 6px нижнего отступа
    height: isHidden ? 0 : (cardRect.height + 6 + (isDragTarget ? 6 : 0))

    // Индикатор места вставки при Drag-and-Drop (Drop Line)
    Rectangle {
        visible: itemRoot.isDragTarget && !itemRoot.isBeingDragged
        x: itemRoot.indentPx
        width: parent.width - itemRoot.indentPx
        anchors.top: (itemRoot.dragPosition === "before") ? parent.top : undefined
        anchors.bottom: (itemRoot.dragPosition === "after") ? (parent.bottom - 6) : undefined
        height: 2
        radius: 1
        color: Theme.accentColor
        z: 10
    }

    // Карточка блока
    Rectangle {
        id: cardRect
        x: itemRoot.indentPx
        width: parent.width - itemRoot.indentPx
        height: Math.max(itemRoot.isProjectTree ? 32 : 36, cardContent.implicitHeight + (itemRoot.hasContent ? 14 : 10))
        radius: 6

        color: itemRoot.isHighlighted
            ? Qt.rgba(1, 1, 1, 0.12)
            : (cardMouse.containsMouse
                ? Qt.rgba(1, 1, 1, 0.075)
                : Qt.rgba(1, 1, 1, 0.04))

        opacity: itemRoot.isBeingDragged ? 0.35 : 1.0

        Behavior on color { ColorAnimation { duration: 90 } }
        Behavior on opacity { NumberAnimation { duration: 90 } }

        ColumnLayout {
            id: cardContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 8
            anchors.rightMargin: 12
            anchors.topMargin: itemRoot.hasContent ? 7 : 5
            spacing: 4

            // Заголовочная строка блока
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                // Выделенная кнопка шеврона (сворачивание/разворачивание)
                Item {
                    id: chevronContainer
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    visible: itemRoot.canCollapse

                    Rectangle {
                        anchors.fill: parent
                        radius: 3
                        color: chevronMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: itemRoot.isFolderCollapsed ? "›" : "⌄"
                        font.pixelSize: 12
                        font.bold: true
                        color: chevronMouse.containsMouse ? Theme.textPrimary : Theme.textMuted
                    }

                    MouseArea {
                        id: chevronMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            itemRoot.folderToggled(itemRoot.blockKey)
                        }
                    }
                }

                // Спейсер для элементов без детей
                Item {
                    visible: !itemRoot.canCollapse
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                }

                // Название элемента / Заголовок
                Text {
                    id: labelText
                    Layout.fillWidth: true
                    text: OutlinerCtrl.getLabelText(itemRoot.isProjectTree, itemRoot.blockData)
                    font.pixelSize: 13
                    font.bold: itemRoot.isFolder || itemRoot.isSection || (itemRoot.isHeading && itemRoot.blockLevel <= 2)
                    color: (itemRoot.isHighlighted || cardMouse.containsMouse || itemRoot.isFolder || itemRoot.isSection)
                        ? Theme.textPrimary 
                        : Theme.textSecondary
                    elide: Text.ElideRight
                }

                // Метка типа CANVAS
                Text {
                    visible: itemRoot.isCanvas
                    text: "CANVAS"
                    font.pixelSize: 9
                    font.bold: true
                    color: Theme.textMuted
                    opacity: 0.6
                }
            }

            // Текстовое содержимое блока (если есть)
            Text {
                visible: itemRoot.hasContent && !itemRoot.isFolderCollapsed
                Layout.fillWidth: true
                Layout.leftMargin: 26
                text: itemRoot.hasContent ? itemRoot.blockData.content : ""
                font.pixelSize: 11
                color: Theme.textSecondary
                maximumLineCount: 3
                elide: Text.ElideRight
                wrapMode: Text.Wrap
                lineHeight: 1.25
            }
        }

        // Интерактивная зона клика и перетаскивания карточки
        MouseArea {
            id: cardMouse
            anchors.fill: parent
            anchors.leftMargin: 22 // Не перекрывает шеврон сворачивания
            hoverEnabled: true
            cursorShape: (itemRoot.isFile || itemRoot.isHeading || itemRoot.isFolder || itemRoot.isSection) ? Qt.PointingHandCursor : (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
            preventStealing: pressed

            drag.target: null

            property int startX: 0
            property int startY: 0
            property bool isDraggingActive: false

            onPressed: (mouse) => {
                itemRoot.activated()
                startX = mouse.x
                startY = mouse.y
                isDraggingActive = false
            }

            onPositionChanged: (mouse) => {
                if (pressed) {
                    var dx = Math.abs(mouse.x - startX)
                    var dy = Math.abs(mouse.y - startY)
                    if (!isDraggingActive && (dx > 5 || dy > 5)) {
                        isDraggingActive = true
                        itemRoot.dragStarted(itemRoot.blockIndex)
                    }
                    if (isDraggingActive) {
                        var view = ListView.view
                        if (view && view.contentItem) {
                            var globalPt = mapToItem(view.contentItem, mouse.x, mouse.y)
                            var targetIdx = view.indexAt(globalPt.x, globalPt.y)
                            var pos = (mouse.y < cardRect.height / 2) ? "before" : "after"
                            itemRoot.dragMoved(targetIdx, pos)
                        }
                    }
                }
            }

            onReleased: {
                if (isDraggingActive) {
                    itemRoot.dragFinished(itemRoot.blockIndex, -1, "")
                }
                isDraggingActive = false
            }

            onCanceled: {
                if (isDraggingActive) {
                    itemRoot.dragCanceled()
                }
                isDraggingActive = false
            }

            onClicked: {
                if (isDraggingActive) return
                if (itemRoot.isFile && itemRoot.blockData && itemRoot.blockData.label) {
                    itemRoot.fileClicked(itemRoot.blockData.label)
                } else if (itemRoot.isHeading) {
                    var head = itemRoot.blockData.heading || itemRoot.blockData.label || ""
                    itemRoot.headingClicked(head)
                } else if (itemRoot.canCollapse) {
                    itemRoot.folderToggled(itemRoot.blockKey)
                }
            }
        }
    }
}
