import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    color: "transparent"

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 16
        width: 380

        Label {
            text: "⚙️ Настройки и Реактивность"
            color: "#cdd6f4"
            font.pixelSize: 24
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        Label {
            text: "Смените имя пользователя в поле ниже — оно автоматически обновится на всех страницах и в шапке, потому что это pyqtProperty!"
            color: "#a6adc8"
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            TextField {
                id: tfNewName
                placeholderText: "Новое имя..."
                text: backend.userName
                Layout.fillWidth: true
                color: "#cdd6f4"
            }

            Button {
                text: "Сохранить"
                background: Rectangle { radius: 6; color: parent.hovered ? "#89b4fa" : "#313244" }
                contentItem: Text { text: parent.text; color: parent.hovered ? "#11111b" : "#cdd6f4"; font.bold: true; padding: 6 }
                onClicked: {
                    if (tfNewName.text.trim() !== "") {
                        backend.update_user_name(tfNewName.text.trim())
                    }
                }
            }
        }
    }
}
