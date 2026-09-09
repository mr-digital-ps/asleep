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
        // objectName нужен, чтобы Python мог найти этот компонент по имени
        objectName: "hotLoader"
        anchors.fill: parent
        // Загружаем наш интерфейс
        source: "web.qml"
        onLoaded: {
            if (item && typeof item.applyInitialState === "function") {
                item.applyInitialState()
            }
        }
    }
}
