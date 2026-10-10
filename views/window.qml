import QtQuick
import QtQuick.Controls
import "../components/theme"
import "./window_controller.js" as WindowCtrl

ApplicationWindow {
    id: root

    flags: Qt.FramelessWindowHint | Qt.Window
    visible: true
    width: (typeof backend !== "undefined" && backend && backend.get_app_config().window_default_width) ? backend.get_app_config().window_default_width : 900
    height: (typeof backend !== "undefined" && backend && backend.get_app_config().window_default_height) ? backend.get_app_config().window_default_height : 650
    minimumWidth: (typeof backend !== "undefined" && backend && backend.get_app_config().window_min_width) ? backend.get_app_config().window_min_width : 600
    minimumHeight: (typeof backend !== "undefined" && backend && backend.get_app_config().window_min_height) ? backend.get_app_config().window_min_height : 400
    color: Theme.bgApp

    // Начальные параметры для окна (передаются при клонировании)
    property string initialFileUrl: ""
    property string initialTitle: ""
    property string initialContent: ""

    Loader {
        id: hotLoader
        objectName: "hotLoader"
        width: root.width
        height: root.height
        focus: true
        Keys.forwardTo: (item ? [item] : [])
        source: "web.qml"
        onLoaded: WindowCtrl.handleLoaderLoaded(root, item, (typeof backend !== "undefined" ? backend : null))
    }

    // Рамка приложения и интерактивное изменение размера окна (инлайновый монолит)
    Item {
        id: windowFrame
        anchors.fill: parent
        z: 9999
        visible: root.visibility !== Window.Maximized

        readonly property int resizeMargin: 8
        readonly property int cornerMargin: 16

        // Визуальная граница
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: root.active ? Theme.borderHover : Theme.borderColor

            Behavior on border.color {
                ColorAnimation { duration: Theme.animDurationNormal }
            }
        }

        // Грани изменения размера
        MouseArea {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: windowFrame.cornerMargin
            anchors.rightMargin: windowFrame.cornerMargin
            height: windowFrame.resizeMargin
            cursorShape: Qt.SizeVerCursor
            acceptedButtons: Qt.LeftButton
            onPressed: root.startSystemResize(Qt.TopEdge)
        }

        MouseArea {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: windowFrame.cornerMargin
            anchors.rightMargin: windowFrame.cornerMargin
            height: windowFrame.resizeMargin
            cursorShape: Qt.SizeVerCursor
            acceptedButtons: Qt.LeftButton
            onPressed: root.startSystemResize(Qt.BottomEdge)
        }

        MouseArea {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: windowFrame.cornerMargin
            anchors.bottomMargin: windowFrame.cornerMargin
            width: windowFrame.resizeMargin
            cursorShape: Qt.SizeHorCursor
            acceptedButtons: Qt.LeftButton
            onPressed: root.startSystemResize(Qt.LeftEdge)
        }

        MouseArea {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: windowFrame.cornerMargin
            anchors.bottomMargin: windowFrame.cornerMargin
            width: windowFrame.resizeMargin
            cursorShape: Qt.SizeHorCursor
            acceptedButtons: Qt.LeftButton
            onPressed: root.startSystemResize(Qt.RightEdge)
        }

        // Углы изменения размера
        MouseArea {
            anchors.top: parent.top
            anchors.left: parent.left
            width: windowFrame.cornerMargin
            height: windowFrame.cornerMargin
            cursorShape: Qt.SizeFDiagCursor
            acceptedButtons: Qt.LeftButton
            onPressed: root.startSystemResize(Qt.TopEdge | Qt.LeftEdge)
        }

        MouseArea {
            anchors.top: parent.top
            anchors.right: parent.right
            width: windowFrame.cornerMargin
            height: windowFrame.cornerMargin
            cursorShape: Qt.SizeBDiagCursor
            acceptedButtons: Qt.LeftButton
            onPressed: root.startSystemResize(Qt.TopEdge | Qt.RightEdge)
        }

        MouseArea {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: windowFrame.cornerMargin
            height: windowFrame.cornerMargin
            cursorShape: Qt.SizeBDiagCursor
            acceptedButtons: Qt.LeftButton
            onPressed: root.startSystemResize(Qt.BottomEdge | Qt.LeftEdge)
        }

        MouseArea {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: windowFrame.cornerMargin
            height: windowFrame.cornerMargin
            cursorShape: Qt.SizeFDiagCursor
            acceptedButtons: Qt.LeftButton
            onPressed: root.startSystemResize(Qt.BottomEdge | Qt.RightEdge)
        }
    }

    Timer {
        id: saveGeomTimer
        interval: (typeof backend !== "undefined" && backend && backend.get_app_config().window_save_geometry_delay_ms) ? backend.get_app_config().window_save_geometry_delay_ms : 600
        repeat: false
        onTriggered: WindowCtrl.saveWindowGeometry(root, (typeof backend !== "undefined" ? backend : null))
    }

    onWidthChanged: saveGeomTimer.restart()
    onHeightChanged: saveGeomTimer.restart()

    Component.onCompleted: WindowCtrl.initWindow(root, (typeof backend !== "undefined" ? backend : null))

    onClosing: WindowCtrl.handleWindowClosing(root, (typeof backend !== "undefined" ? backend : null))
}
