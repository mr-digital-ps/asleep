import QtQuick

Item {
    id: focusOverlay
    anchors.fill: parent

    property var editorArea: null
    property bool focusMode: false

    visible: focusMode && editorArea && editorArea.activeFocus
    opacity: (focusMode && editorArea && editorArea.activeFocus) ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 200 } }
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
        color: "#cc181818"
        Behavior on height { NumberAnimation { duration: 70; easing.type: Easing.OutQuad } }
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
        color: "#cc181818"
        Behavior on y { NumberAnimation { duration: 70; easing.type: Easing.OutQuad } }
        Behavior on height { NumberAnimation { duration: 70; easing.type: Easing.OutQuad } }
    }
}
