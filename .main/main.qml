import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: appWindow
    visible: true
    width: 1100
    height: 750
    title: "PyQt6 QML Редактор кода"
    color: "#1e1e1e"

    SplitView {
        anchors.fill: parent
        orientation: Qt.Horizontal

        // 1. Компонент Сайдбара (Проводник файлов)
        Sidebar {
            id: sidebar
            SplitView.preferredWidth: 280
            SplitView.minimumWidth: 180
            SplitView.maximumWidth: 500

            // При выборе файла в сайдбаре передаем его в редактор
            onFileSelected: function(filePath, fileName) {
                editor.loadFile(filePath, fileName)
            }
        }

        // 2. Компонент Редактора Кода
        CodeEditor {
            id: editor
            SplitView.fillWidth: true
        }
    }
}
