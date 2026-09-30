import QtQuick
import QtQuick.Controls
import "../components/window"
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

    // Рамка приложения и интерактивное изменение размера окна
    WindowFrame {
        id: windowFrame
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
