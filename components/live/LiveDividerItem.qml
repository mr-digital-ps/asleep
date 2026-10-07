import QtQuick
import "../theme"

Rectangle {
    id: dividerRoot
    width: parent ? parent.width : Theme.defaultSheetWidth
    height: 16
    color: "transparent"

    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: 1
        color: Theme.borderColor
    }
}
