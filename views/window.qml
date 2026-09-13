import QtQuick
import QtQuick.Controls
import "../components/window"
import "../components/theme"

ApplicationWindow {
    id: root

    flags: Qt.FramelessWindowHint | Qt.Window
    visible: true
    width: 900
    height: 650
    minimumWidth: 600
    minimumHeight: 400
    color: Theme.bgApp

    // Начальные параметры для окна (передаются при клонировании)
    property string initialFileUrl: ""
    property string initialTitle: ""
    property string initialContent: ""
    property bool startWithSidebarHidden: false

    Keys.forwardTo: (hotLoader && hotLoader.item) ? [hotLoader.item] : []

    Keys.onPressed: (event) => {
        if (hotLoader && hotLoader.item && typeof hotLoader.item.handleGlobalKeyEvent === "function") {
            if (hotLoader.item.handleGlobalKeyEvent(event)) {
                return
            }
        }
    }

    Loader {
        id: hotLoader
        objectName: "hotLoader"
        anchors.fill: parent
        focus: true
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

    // Рамка приложения и интерактивное изменение размера окна
    WindowFrame {
        id: windowFrame
    }

    Timer {
        id: saveGeomTimer
        interval: 600
        repeat: false
        onTriggered: {
            if (root.visibility !== Window.Maximized && typeof backend !== "undefined" && backend && typeof backend.save_window_geometry === "function") {
                backend.save_window_geometry(root.x, root.y, root.width, root.height)
            }
        }
    }

    onWidthChanged: saveGeomTimer.restart()
    onHeightChanged: saveGeomTimer.restart()

    Component.onCompleted: {
        if (typeof backend !== "undefined" && backend && typeof backend.get_session_config === "function") {
            try {
                let sess = backend.get_session_config()
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

    onClosing: {
        if (typeof backend !== "undefined" && backend && typeof backend.unregister_window === "function") {
            backend.unregister_window(root)
        }
    }
}
