import QtQuick
import "../theme"

MouseArea {
    id: handleRoot
    width: 24
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    cursorShape: Qt.SizeHorCursor
    hoverEnabled: true
    preventStealing: true
    z: 20

    property bool isLeft: true
    property var containerItem: null
    property real minWidth: Theme.minSheetWidth
    property real maxWidth: 2000
    property bool forceVisible: false
    property bool isDragging: false

    signal sheetWidthRequested(real newWidth)
    signal sheetWidthCommitted(real finalWidth)
    signal doubleClickedToggle()

    onPressed: (mouse) => {
        if (mouse.button === Qt.LeftButton) {
            handleRoot.isDragging = true
        }
    }

    onPositionChanged: (mouse) => {
        if (handleRoot.isDragging || pressed) {
            let container = containerItem ? containerItem : (parent ? parent : null)
            if (!container || container.width <= 0) return
            let pt = mapToItem(container, mouse.x, mouse.y)
            let centerX = container.width / 2.0
            let distFromCenter = isLeft ? (centerX - pt.x) : (pt.x - centerX)
            let desiredWidth = Math.round(distFromCenter * 2.0)
            let effectiveMax = (maxWidth > minWidth) ? maxWidth : (container.width > minWidth ? container.width : 2000)
            let clamped = Math.max(minWidth, Math.min(effectiveMax, desiredWidth))
            handleRoot.sheetWidthRequested(clamped)
        }
    }

    onReleased: (mouse) => {
        handleRoot.isDragging = false
        if (containerItem) {
            handleRoot.sheetWidthCommitted(clampedWidth(containerItem))
        }
    }

    onCanceled: {
        handleRoot.isDragging = false
        if (containerItem) {
            handleRoot.sheetWidthCommitted(clampedWidth(containerItem))
        }
    }

    function clampedWidth(container) {
        return Math.max(minWidth, Math.min(container.width, maxWidth))
    }

    onDoubleClicked: {
        handleRoot.doubleClickedToggle()
    }

    // Визуальная линия границы листа
    Rectangle {
        anchors.centerIn: parent
        width: 2
        height: parent.height
        color: (handleRoot.isDragging || handleRoot.pressed) ? Theme.textSelected : Theme.borderHover
        opacity: (handleRoot.forceVisible || handleRoot.containsMouse || handleRoot.isDragging || handleRoot.pressed) ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 100 }
        }
    }
}
