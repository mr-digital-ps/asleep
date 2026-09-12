import QtQuick
import QtQuick.Layouts

Item {
    id: emptyState
    anchors.centerIn: parent
    width: 320
    height: 120

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 10

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Нет открытых файлов"
            color: "#4a4a4a"
            font.pixelSize: 16
            font.bold: true
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Выберите файл в меню слева\nили Shift + Клик для разделения экрана"
            color: "#383838"
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 1.3
        }
    }
}
