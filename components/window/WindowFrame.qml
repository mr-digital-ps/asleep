import QtQuick

Item {
    id: frame
    anchors.fill: parent
    z: 9999

    property var targetWindow: Window.window
    property int borderWidth: 1
    property color activeColor: "#3c3c3c"
    property color inactiveColor: "#262626"
    property int resizeMargin: 8
    property int cornerMargin: 16

    readonly property bool isMaximized: targetWindow ? (targetWindow.visibility === Window.Maximized) : false
    visible: !isMaximized

    // 1. Визуальная рамка по периметру окна
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: frame.borderWidth
        border.color: (targetWindow && targetWindow.active) ? frame.activeColor : frame.inactiveColor

        Behavior on border.color {
            ColorAnimation { duration: 150 }
        }
    }

    // 2. Интерактивные зоны изменения размера окна (Resize Handles)
    // Верхняя грань
    MouseArea {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: frame.cornerMargin
        anchors.rightMargin: frame.cornerMargin
        height: frame.resizeMargin
        cursorShape: Qt.SizeVerCursor
        acceptedButtons: Qt.LeftButton
        onPressed: if (targetWindow) targetWindow.startSystemResize(Qt.TopEdge)
    }

    // Нижняя грань
    MouseArea {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: frame.cornerMargin
        anchors.rightMargin: frame.cornerMargin
        height: frame.resizeMargin
        cursorShape: Qt.SizeVerCursor
        acceptedButtons: Qt.LeftButton
        onPressed: if (targetWindow) targetWindow.startSystemResize(Qt.BottomEdge)
    }

    // Левая грань
    MouseArea {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: frame.cornerMargin
        anchors.bottomMargin: frame.cornerMargin
        width: frame.resizeMargin
        cursorShape: Qt.SizeHorCursor
        acceptedButtons: Qt.LeftButton
        onPressed: if (targetWindow) targetWindow.startSystemResize(Qt.LeftEdge)
    }

    // Правая грань
    MouseArea {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: frame.cornerMargin
        anchors.bottomMargin: frame.cornerMargin
        width: frame.resizeMargin
        cursorShape: Qt.SizeHorCursor
        acceptedButtons: Qt.LeftButton
        onPressed: if (targetWindow) targetWindow.startSystemResize(Qt.RightEdge)
    }

    // Углы (Corners)
    // Верхний левый
    MouseArea {
        anchors.top: parent.top
        anchors.left: parent.left
        width: frame.cornerMargin
        height: frame.cornerMargin
        cursorShape: Qt.SizeFDiagCursor
        acceptedButtons: Qt.LeftButton
        onPressed: if (targetWindow) targetWindow.startSystemResize(Qt.TopEdge | Qt.LeftEdge)
    }

    // Верхний правый
    MouseArea {
        anchors.top: parent.top
        anchors.right: parent.right
        width: frame.cornerMargin
        height: frame.cornerMargin
        cursorShape: Qt.SizeBDiagCursor
        acceptedButtons: Qt.LeftButton
        onPressed: if (targetWindow) targetWindow.startSystemResize(Qt.TopEdge | Qt.RightEdge)
    }

    // Нижний левый
    MouseArea {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: frame.cornerMargin
        height: frame.cornerMargin
        cursorShape: Qt.SizeBDiagCursor
        acceptedButtons: Qt.LeftButton
        onPressed: if (targetWindow) targetWindow.startSystemResize(Qt.BottomEdge | Qt.LeftEdge)
    }

    // Нижний правый
    MouseArea {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: frame.cornerMargin
        height: frame.cornerMargin
        cursorShape: Qt.SizeFDiagCursor
        acceptedButtons: Qt.LeftButton
        onPressed: if (targetWindow) targetWindow.startSystemResize(Qt.BottomEdge | Qt.RightEdge)
    }
}
