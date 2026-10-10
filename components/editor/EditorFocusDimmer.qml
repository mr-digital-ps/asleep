import QtQuick
import "../theme"

Item {
    id: focusOverlay
    anchors.fill: parent

    property var editorArea: null
    property bool focusMode: false

    visible: focusMode && editorArea && editorArea.activeFocus
    opacity: (focusMode && editorArea && editorArea.activeFocus) ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: Theme.animDurationNormal } }
    z: 5
    enabled: false

    Rectangle {
        id: focusTopDim
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        readonly property real targetH: {
            if (!editorArea || !editorArea.activeFocus) return 0
            let p = editorArea.mapToItem(focusOverlay, 0, editorArea.cursorRectangle.y)
            return Math.max(0, p.y - 8)
        }
        height: targetH
        color: Qt.rgba(Theme.bgPaper.r, Theme.bgPaper.g, Theme.bgPaper.b, 0.8)
        Behavior on height { NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutQuad } }
    }

    Rectangle {
        id: focusBottomDim
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        readonly property real targetY: {
            if (!editorArea || !editorArea.activeFocus) return parent.height
            let p = editorArea.mapToItem(focusOverlay, 0, editorArea.cursorRectangle.y + editorArea.cursorRectangle.height)
            return p.y + 8
        }
        y: targetY
        height: Math.max(0, parent.height - targetY)
        color: Qt.rgba(Theme.bgPaper.r, Theme.bgPaper.g, Theme.bgPaper.b, 0.8)
        Behavior on y { NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutQuad } }
        Behavior on height { NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutQuad } }
    }
}
