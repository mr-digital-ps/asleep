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

    Loader {
        id: hotLoader
        // objectName нужен, чтобы Python мог найти этот компонент по имени
        objectName: "hotLoader"
        anchors.fill: parent
        // Загружаем наш интерфейс
        source: "web.qml"
    }


}
