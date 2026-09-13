import QtQuick
import QtQuick.Layouts
import "../theme"

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
            color: Theme.textSecondary
            font.pixelSize: 16
            font.bold: true
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Выберите файл в меню слева\nили Shift + Клик для разделения экрана"
            color: Theme.textMuted
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 1.3
        }
    }
}
