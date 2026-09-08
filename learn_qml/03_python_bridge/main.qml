import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    visible: true
    width: 500
    height: 420
    title: "03. Мост между Python и QML"
    color: "#1e1e2e"

    property string lastNumber: "—"
    property string statusText: "Готов к работе"

    // Connections слушает сигналы от зарегистрированного объекта 'bridge'
    Connections {
        target: bridge

        // Обработчик сигнала statusChanged (префикс on + ЗаглавнаяБуква)
        function onStatusChanged(msg) {
            root.statusText = msg
        }

        // Обработчик сигнала numberGenerated
        function onNumberGenerated(num) {
            root.lastNumber = num.toString()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        Text {
            text: "🔌 Двусторонняя связь Python ⇄ QML"
            color: "#cba6f7"
            font.pixelSize: 18
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        // Блок 1: Вызов Python-слота с параметром и получением возвращаемого значения
        Rectangle {
            Layout.fillWidth: true
            height: 120
            radius: 12
            color: "#313244"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    TextField {
                        id: inputField
                        Layout.fillWidth: true
                        placeholderText: "Введите слово для реверса в Python..."
                        color: "#cdd6f4"
                    }
                    Button {
                        text: "Перевернуть в Python"
                        onClicked: {
                            // Прямой вызов Python метода bridge.process_text(...)
                            var result = bridge.process_text(inputField.text)
                            outputLabel.text = "Результат от Python: " + result
                        }
                    }
                }

                Text {
                    id: outputLabel
                    text: "Результат появится здесь"
                    color: "#a6e3a1"
                    font.pixelSize: 14
                }
            }
        }

        // Блок 2: Python генерирует событие (сигнал)
        Rectangle {
            Layout.fillWidth: true
            height: 90
            radius: 12
            color: "#313244"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12

                Button {
                    text: "🎲 Сгенерировать число в Python"
                    onClicked: {
                        bridge.generate_random()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Число от Python: " + root.lastNumber
                    color: "#f9e2af"
                    font.pixelSize: 16
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Строка статуса (получает текст из pyqtSignal)
        Rectangle {
            Layout.fillWidth: true
            height: 36
            radius: 6
            color: "#181825"
            border.color: "#45475a"

            Text {
                anchors.centerIn: parent
                text: "Статус: " + root.statusText
                color: "#9399b2"
                font.pixelSize: 12
            }
        }
    }
}
