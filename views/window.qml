import QtQuick
import QtQuick.Controls
import "../components/theme"

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
        onLoaded: {
            if (item) {
                item.appWindow = root
                if (typeof item.applyInitialState === "function") {
                    item.applyInitialState()
                }
            }
            if (typeof backend !== "undefined" && backend && typeof backend.register_window === "function") {
                backend.register_window(root, item)
            }
        }
    }

    // Рамка приложения и визуальная граница окна (инлайновый монолит)
    Item {
        id: windowFrame
        anchors.fill: parent
        z: 9999
        visible: root.visibility !== Window.Maximized && root.visibility !== Window.FullScreen

        readonly property int resizeMargin: (typeof backend !== "undefined" && backend && backend.get_app_config().window_resize_margin) ? backend.get_app_config().window_resize_margin : 10
        readonly property int cornerMargin: (typeof backend !== "undefined" && backend && backend.get_app_config().window_corner_margin) ? backend.get_app_config().window_corner_margin : 20

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
    }

    Timer {
        id: saveGeomTimer
        interval: (typeof backend !== "undefined" && backend && backend.get_app_config().window_save_geometry_delay_ms) ? backend.get_app_config().window_save_geometry_delay_ms : 600
        repeat: false
        onTriggered: {
            if (typeof backend !== "undefined" && backend && typeof backend.save_window_geometry === "function") {
                if (root.visibility !== Window.Maximized) {
                    backend.save_window_geometry(root.x, root.y, root.width, root.height)
                }
            }
        }
    }

    onWidthChanged: saveGeomTimer.restart()
    onHeightChanged: saveGeomTimer.restart()
    onXChanged: saveGeomTimer.restart()
    onYChanged: saveGeomTimer.restart()

    Component.onCompleted: {
        if (typeof backend !== "undefined" && backend && typeof backend.get_session_config === "function") {
            try {
                var sess = backend.get_session_config()
                if (sess) {
                    if (typeof sess.win_width === "number" && sess.win_width >= root.minimumWidth) {
                        root.width = sess.win_width
                    }
                    if (typeof sess.win_height === "number" && sess.win_height >= root.minimumHeight) {
                        root.height = sess.win_height
                    }
                }
            } catch(e) {}
        }
    }

    onClosing: (close) => {
        if (hotLoader.item && !hotLoader.item.saveAll()) {
            close.accepted = false
            return
        }
        if (typeof backend !== "undefined" && backend && typeof backend.unregister_window === "function") {
            backend.unregister_window(root)
        }
    }
}
