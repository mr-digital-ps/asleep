import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    color: "transparent"

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 16

        Label {
            text: "🏠 Главная страница"
            color: "#cdd6f4"
            font.pixelSize: 26
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        Label {
            text: "Текущий пользователь (реактивное свойство из Python):"
            color: "#a6adc8"
            font.pixelSize: 14
            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 220; height: 44
            radius: 8
            color: "#181825"
            border.color: "#89b4fa"
            border.width: 1

            Label {
                anchors.centerIn: parent
                // ПРЯМОЙ ДОСТУП К РЕАКТИВНОМУ СВОЙСТВУ PYTHON
                text: "👤 " + backend.userName
                color: "#89b4fa"
                font.pixelSize: 16
                font.bold: true
            }
        }

        Label {
            text: "Перейдите в раздел 'Типы данных' в сайдбаре слева,\nчтобы протестировать отправку и получение сложных структур данных."
            color: "#6c7086"
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
