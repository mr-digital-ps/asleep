import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: root

    flags: Qt.FramelessWindowHint | Qt.Window
    visible: true
    width: 900
    height: 650
    minimumWidth: 600
    minimumHeight: 400
    color: "#1e1e1e"

    // Начальные параметры для окна (передаются при клонировании)
    property string initialFileUrl: ""
    property string initialTitle: ""
    property string initialContent: ""
    property bool startWithSidebarHidden: false

    Loader {
        id: hotLoader
        objectName: "hotLoader"
        anchors.fill: parent
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

    onClosing: {
        if (typeof backend !== "undefined" && backend && typeof backend.unregister_window === "function") {
            backend.unregister_window(root)
        }
    }
}
