import QtQuick
import QtQuick.Controls

Item {
    id: scrollbarOverlay

    property var editorScroll: null
    property var paperSheet: null
    property bool isEmpty: false
    property int barSize: 36
    signal activated()

    width: barSize
    anchors.top: parent ? parent.top : undefined
    anchors.topMargin: 16
    anchors.bottom: parent ? parent.bottom : undefined
    anchors.bottomMargin: 16
    x: paperSheet ? Math.round(paperSheet.x + paperSheet.width - barSize) : 0
    z: 10
    visible: !isEmpty && editorScroll && (editorScroll.contentItem.contentHeight > editorScroll.availableHeight)

    // Зона перетаскивания окна по правой полосе
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.ArrowCursor
        onPressed: {
            scrollbarOverlay.activated()
            Window.window.startSystemMove()
        }
        onDoubleClicked: {
            if (Window.window.visibility === Window.Maximized) {
                Window.window.showNormal()
            } else {
                Window.window.showMaximized()
            }
        }
    }

    // Скроллбар документа
    ScrollBar {
        id: customVBar
        anchors.horizontalCenter: parent.horizontalCenter
        width: 14
        height: parent.height
        size: (editorScroll && editorScroll.contentItem && editorScroll.contentItem.contentHeight > 0)
            ? Math.min(1.0, Math.max(0.04, editorScroll.availableHeight / editorScroll.contentItem.contentHeight)) : 1.0
        position: (editorScroll && editorScroll.contentItem && editorScroll.contentItem.contentHeight > editorScroll.availableHeight)
            ? Math.max(0.0, Math.min(1.0 - size, editorScroll.contentItem.contentY / editorScroll.contentItem.contentHeight)) : 0.0
        active: true
        orientation: Qt.Vertical

        onPositionChanged: {
            if (pressed && editorScroll && editorScroll.contentItem) {
                let maxScroll = editorScroll.contentItem.contentHeight - editorScroll.availableHeight
                if (maxScroll > 0 && (1.0 - size) > 0) {
                    editorScroll.contentItem.contentY = (position / (1.0 - size)) * maxScroll
                }
            }
        }

        contentItem: Rectangle {
            implicitWidth: customVBar.hovered || customVBar.pressed ? 8 : 6
            implicitHeight: 32
            radius: 4
            color: customVBar.pressed ? "#ffffff" : (customVBar.hovered ? "#cccccc" : "#666666")
            anchors.horizontalCenter: parent.horizontalCenter

            Behavior on implicitWidth { NumberAnimation { duration: 100 } }
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        background: Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 4
            height: parent.height
            radius: 2
            color: "#18ffffff"
        }
    }
}
