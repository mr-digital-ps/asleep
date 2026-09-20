import QtQuick
import QtQuick.Layouts
import "../../theme"

Rectangle {
    id: noticeRoot
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    anchors.margins: 20
    height: 32
    radius: 16
    color: Theme.bgDialog
    border.color: Theme.borderColor
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
            color: Theme.accentColor
        }

        Text {
            text: noticeRoot.noticeText
            font.pixelSize: 12
            font.bold: true
            color: Theme.textPrimary
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
