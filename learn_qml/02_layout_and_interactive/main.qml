import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    visible: true
    width: 480
    height: 400
    title: "02. Лейауты, Кнопки и Свойства"
    color: "#181825"

    // Пользовательское свойство (переменная состояния)
    property int counter: 0

    // ColumnLayout выстраивает дочерние элементы вертикально
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        // Заголовок
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Счетчик кликов: " + root.counter
            color: root.counter > 5 ? "#a6e3a1" : "#cdd6f4"
            font.pixelSize: 22
            font.bold: true

            // Плавная анимация изменения масштаба при клике
            scale: 1.0
            Behavior on scale {
                NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
            }
        }

        // Поле ввода текста
        TextField {
            id: customInput
            Layout.fillWidth: true
            placeholderText: "Введите ваше имя..."
            color: "#cdd6f4"
            font.pixelSize: 14
            background: Rectangle {
                radius: 8
                color: "#313244"
                border.color: customInput.activeFocus ? "#cba6f7" : "#45475a"
                border.width: 1
            }
        }

        // Приветствие, зависящее от ввода
        Text {
            Layout.fillWidth: true
            text: customInput.text ? "Привет, " + customInput.text + "!" : "Здесь появится приветствие"
            color: "#a6adc8"
            font.italic: true
            horizontalAlignment: Text.AlignHCenter
        }

        // Разделитель (пружина), толкающий кнопки вниз
        Item {
            Layout.fillHeight: true
        }

        // RowLayout выстраивает кнопки в строку горизонтально
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Button {
                Layout.fillWidth: true
                text: "➕ Увеличить"
                onClicked: {
                    root.counter++
                }
            }

            Button {
                Layout.fillWidth: true
                text: "➖ Уменьшить"
                onClicked: {
                    if (root.counter > 0) root.counter--
                }
            }

            Button {
                Layout.fillWidth: true
                text: "🔄 Сброс"
                onClicked: {
                    root.counter = 0
                    customInput.text = ""
                }
            }
        }
    }
}
