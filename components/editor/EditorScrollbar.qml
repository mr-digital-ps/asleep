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
    property bool isFooterPinned: false
    property real topMargin: 76
    property real bottomMargin: isFooterPinned ? 48 : 24

    anchors.top: parent ? parent.top : undefined
    anchors.topMargin: topMargin
    anchors.bottom: parent ? parent.bottom : undefined
    anchors.bottomMargin: bottomMargin
    x: paperSheet ? Math.round(paperSheet.x + paperSheet.width - barSize) : 0
    z: 10
    readonly property real totalHeight: (editorScroll && editorScroll.contentItem && editorScroll.contentItem.contentHeight > 0)
        ? editorScroll.contentItem.contentHeight
        : ((editorScroll && editorScroll.contentHeight > 0) ? editorScroll.contentHeight : 0)
    readonly property real viewHeight: editorScroll ? editorScroll.availableHeight : 1
    readonly property real scrollY: (editorScroll && editorScroll.contentItem) ? editorScroll.contentItem.contentY : 0

    visible: !isEmpty && (totalHeight > viewHeight)

    // Зона перетаскивания окна по правой полосе
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.ArrowCursor
        onPressed: (mouse) => {
            scrollbarOverlay.activated()
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
            color: customVBar.pressed ? "#ffffff" : (customVBar.hovered ? "#cccccc" : "#666666")
            anchors.horizontalCenter: parent.horizontalCenter

            Behavior on implicitWidth { NumberAnimation { duration: 100 } }
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        background: Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 4
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            width: 4
            radius: 2
            color: "#18ffffff"
        }
    }
}
