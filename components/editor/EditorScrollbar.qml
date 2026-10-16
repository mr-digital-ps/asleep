import QtQuick
import QtQuick.Controls.Basic
import "../theme"

Item {
    id: scrollbarOverlay

    property var editorScroll: null
    property var paperSheet: null
    property bool isEmpty: false
    property int barSize: Theme.barSize
    property real sheetWidth: Theme.defaultSheetWidth
    signal activated()
    signal dragStarted(var mouse, var item)
    signal dragUpdated(var mouse, var item)
    signal dragFinished()

    z: 30
    readonly property real totalHeight: (editorScroll && editorScroll.contentItem) ? editorScroll.contentItem.contentHeight : 0
    readonly property real viewHeight: editorScroll ? editorScroll.availableHeight : 1
    readonly property real scrollY: (editorScroll && editorScroll.contentItem) ? editorScroll.contentItem.contentY : 0

    visible: !isEmpty && (totalHeight > viewHeight)

    MouseArea {
        id: scrollbarBgArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: (mouse) => {
            scrollbarOverlay.activated()
            scrollbarOverlay.dragStarted(mouse, scrollbarBgArea)
        }
        onPositionChanged: (mouse) => {
            if (pressed) {
                scrollbarOverlay.dragUpdated(mouse, scrollbarBgArea)
            }
        }
        onReleased: scrollbarOverlay.dragFinished()
        onCanceled: scrollbarOverlay.dragFinished()
    }

    // Скроллбар документа
    ScrollBar {
        id: customVBar
        anchors.horizontalCenter: parent.horizontalCenter
        width: 14
        height: parent.height
        padding: 0
        topPadding: 0
        bottomPadding: 0

        size: {
            if (totalHeight <= 0 || viewHeight >= totalHeight) return 1.0
            return Math.max(0.04, Math.min(1.0, viewHeight / totalHeight))
        }
        position: {
            let maxScroll = totalHeight - viewHeight
            if (maxScroll <= 0) return 0.0
            let ratio = Math.max(0.0, Math.min(1.0, scrollY / maxScroll))
            return ratio * (1.0 - size)
        }
        active: true
        orientation: Qt.Vertical

        onPositionChanged: {
            if (pressed && editorScroll && editorScroll.contentItem) {
                let maxScroll = totalHeight - viewHeight
                if (maxScroll > 0 && (1.0 - size) > 0) {
                    let ratio = Math.max(0.0, Math.min(1.0, position / (1.0 - size)))
                    editorScroll.contentItem.contentY = ratio * maxScroll
                }
            }
        }

        contentItem: Rectangle {
            implicitWidth: customVBar.hovered || customVBar.pressed ? 8 : 6
            implicitHeight: 32
            radius: 4
            color: customVBar.pressed ? Theme.textSelected : (customVBar.hovered ? Theme.scrollbarHover : Theme.scrollbarThumb)
            anchors.horizontalCenter: parent.horizontalCenter

            Behavior on implicitWidth { NumberAnimation { duration: Theme.animDurationFast } }
            Behavior on color { ColorAnimation { duration: Theme.animDurationNormal } }
        }

        background: Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 4
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            width: 4
            radius: 2
            color: Theme.scrollbarTrack
        }
    }
}
