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

    // Минималистичный скроллбар-точка (5px шириной, строго по центру ячейки)
    ScrollBar {
        id: customVBar
        anchors.horizontalCenter: parent.horizontalCenter
        width: 14
        height: parent.height
        size: (editorScroll && editorScroll.contentItem)
            ? Math.min(1.0, editorScroll.availableHeight / Math.max(1, editorScroll.contentItem.contentHeight)) : 1.0
        position: (editorScroll && editorScroll.contentItem)
            ? Math.max(0.0, Math.min(1.0 - size, editorScroll.contentItem.contentY / Math.max(1, editorScroll.contentItem.contentHeight))) : 0.0
        active: true
        orientation: Qt.Vertical

        onPositionChanged: {
            if (pressed && editorScroll && editorScroll.contentItem) {
                let maxScroll = editorScroll.contentItem.contentHeight - editorScroll.availableHeight
                if (maxScroll > 0) {
                    editorScroll.contentItem.contentY = (position / (1.0 - size)) * maxScroll
                }
            }
        }

        contentItem: Rectangle {
            implicitWidth: 5
            implicitHeight: 24
            radius: 2.5
            color: customVBar.pressed ? "#ffffff" : (customVBar.hovered ? "#888888" : "#444444")
            anchors.horizontalCenter: parent.horizontalCenter
            width: 5

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
        }

        background: null
    }
}
