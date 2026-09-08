import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ScrollView {
    clip: true
    contentWidth: parent.width

    ColumnLayout {
        width: parent.width
        anchors.margins: 24
        spacing: 20

        Label {
            text: "🧪 Интерактивный тест передачи типов данных"
            color: "#cdd6f4"
            font.pixelSize: 22
            font.bold: true
        }

        // =====================================================================
        // КАРТОЧКА 1: Простые типы (str, int, float, bool)
        // =====================================================================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: primCol.implicitHeight + 24
            color: "#181825"
            radius: 8
            border.color: "#313244"

            ColumnLayout {
                id: primCol
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                Label {
                    text: "1. Простые типы (str, int, float, bool)"
                    color: "#89b4fa"
                    font.bold: true
                    font.pixelSize: 14
                }

                RowLayout {
                    spacing: 10
                    TextField { id: tfProduct; text: "Кофе"; placeholderText: "Товар (str)"; Layout.preferredWidth: 120 }
                    TextField { id: tfCount; text: "3"; placeholderText: "Кол-во (int)"; Layout.preferredWidth: 80 }
                    TextField { id: tfPrice; text: "150.50"; placeholderText: "Цена (float)"; Layout.preferredWidth: 90 }
                    CheckBox { id: cbActive; text: "Активен (bool)"; checked: true }

                    Button {
                        text: "Отправить в Python"
                        background: Rectangle { radius: 6; color: parent.hovered ? "#89b4fa" : "#313244" }
                        contentItem: Text { text: parent.text; color: parent.hovered ? "#11111b" : "#cdd6f4"; font.bold: true; padding: 6 }
                        onClicked: {
                            let result = backend.send_primitives(
                                tfProduct.text,
                                parseInt(tfCount.text) || 0,
                                parseFloat(tfPrice.text) || 0.0,
                                cbActive.checked
                            )
                            lblPrimResult.text = result
                        }
                    }
                }

                Label {
                    id: lblPrimResult
                    text: "Ожидание отправки..."
                    color: "#a6e3a1"
                    font.pixelSize: 13
                }
            }
        }

        // =====================================================================
        // КАРТОЧКА 2: Списки (JS Array <-> Python list)
        // =====================================================================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: listCol.implicitHeight + 24
            color: "#181825"
            radius: 8
            border.color: "#313244"

            ColumnLayout {
                id: listCol
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                Label {
                    text: "2. Списки (JS Array ⇄ Python list)"
                    color: "#fab387"
                    font.bold: true
                    font.pixelSize: 14
                }

                RowLayout {
                    spacing: 10
                    Button {
                        text: "Передать массив ['React', 'Vue', 'QML'] в Python"
                        background: Rectangle { radius: 6; color: parent.hovered ? "#fab387" : "#313244" }
                        contentItem: Text { text: parent.text; color: parent.hovered ? "#11111b" : "#cdd6f4"; font.bold: true; padding: 6 }
                        onClicked: {
                            let jsArray = ["React", "Vue", "QML"]
                            let returnedList = backend.process_list(jsArray)
                            lblListResult.text = "Python вернул список:\n• " + returnedList.join("\n• ")
                        }
                    }
                }

                Label {
                    id: lblListResult
                    text: "Нажмите кнопку, чтобы обработать массив на Python"
                    color: "#f9e2af"
                    font.pixelSize: 13
                }
            }
        }

        // =====================================================================
        // КАРТОЧКА 3: Словари / JSON (JS Object <-> Python dict / QVariant)
        // =====================================================================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: dictCol.implicitHeight + 24
            color: "#181825"
            radius: 8
            border.color: "#313244"

            ColumnLayout {
                id: dictCol
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                Label {
                    text: "3. Словари / JSON (JS Object ⇄ Python dict)"
                    color: "#a6e3a1"
                    font.bold: true
                    font.pixelSize: 14
                }

                RowLayout {
                    spacing: 10
                    Button {
                        text: "Отправить JSON-объект профиля"
                        background: Rectangle { radius: 6; color: parent.hovered ? "#a6e3a1" : "#313244" }
                        contentItem: Text { text: parent.text; color: parent.hovered ? "#11111b" : "#cdd6f4"; font.bold: true; padding: 6 }
                        onClicked: {
                            let jsObject = {
                                "id": 101,
                                "name": backend.userName,
                                "level": "Pro"
                            }
                            let responseDict = backend.process_dictionary(jsObject)
                            lblDictResult.text = JSON.stringify(responseDict, null, 2)
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: lblDictResult.implicitHeight + 16
                    color: "#11111b"
                    radius: 4

                    Text {
                        id: lblDictResult
                        anchors.fill: parent
                        anchors.margins: 8
                        text: "{\n  \"message\": \"Здесь появится ответ от Python в формате JSON\"\n}"
                        color: "#94e2d5"
                        font.family: "Consolas, monospace"
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
