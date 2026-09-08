import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    visible: true
    width: 700
    height: 500
    title: "⚡ QML Hot Reload (Live Server для Desktop)"
    color: "#11111b"

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 20

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 80; height: 80; radius: 40
            color: "#fab387"

            Label {
                anchors.centerIn: parent
                text: "⚡"
                font.pixelSize: 40
            }
        }

        Label {
            text: "🔥 Live Reload / Hot Reload активен!"
            color: "#a6e3a1"
            font.pixelSize: 24
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        Label {
            text: "Откройте этот файл в VS Code, измените цвет фона или текст,\nнажмите Ctrl + S — и окно обновится МГНОВЕННО без перезапуска!"
            color: "#cdd6f4"
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
        }

        // Попробуйте изменить цвет этой кнопки прямо сейчас!
        Button {
            Layout.alignment: Qt.AlignHCenter
            text: "🚀 Попробуй изменить меня в коде!"
            implicitHeight: 45
            implicitWidth: 280

            background: Rectangle {
                radius: 10
                color: "#89b4fa" // Попробуйте поменять на "#f38ba8" (розовый) или "#a6e3a1" (зеленый)
            }

            contentItem: Text {
                text: parent.text
                color: "#11111b"
                font.bold: true
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
