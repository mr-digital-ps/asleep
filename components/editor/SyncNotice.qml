import QtQuick
import QtQuick.Layouts

Rectangle {
    id: noticeRoot
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    anchors.margins: 20
    height: 32
    radius: 16
    color: "#222222"
    border.color: "#383838"
    border.width: 1
    opacity: 0.0
    z: 100

    property string noticeText: ""

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 6

        Text {
            text: "⚡"
            font.pixelSize: 12
            color: "#64b5f6"
        }

        Text {
            text: noticeRoot.noticeText
            font.pixelSize: 12
            font.bold: true
            color: "#e0e0e0"
        }
    }

    Behavior on opacity {
        NumberAnimation { duration: 180 }
    }

    Timer {
        id: hideTimer
        interval: 2200
        repeat: false
        onTriggered: noticeRoot.opacity = 0.0
    }

    function showNotice(title) {
        noticeText = "Синхронизирован блок: " + title
        opacity = 1.0
        hideTimer.restart()
    }
}
