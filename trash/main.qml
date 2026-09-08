import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    visible: true
    width: 600
    height: 400
    title: "Мое первое QML Приложение"
    
    // Темный цвет фона окна (используем HEX, как в CSS)
    color: "#1e1e2e" 

    // Выравниваем элементы по центру окна
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 30

        Text {
            text: "Добро пожаловать в QML!"
            color: "#cdd6f4"
            font.pixelSize: 28
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        // Наша крутая анимированная кнопка без капли QSS/CSS!
        Rectangle {
            id: myButton
            width: 200
            height: 50
            radius: 25 // Идеально круглые края
            
            // Логика цвета: если нажата -> один цвет, если наведена мышь -> другой, иначе -> третий
            color: mouseArea.pressed ? "#b4befe" : (mouseArea.containsMouse ? "#89b4fa" : "#89dceb")
            Layout.alignment: Qt.AlignHCenter
            
            // Плавная анимация изменения цвета (длится 200мс)
            Behavior on color {
                ColorAnimation { duration: 200 }
            }
            
            // Эффект пружинки: при нажатии кнопка чуть уменьшается
            scale: mouseArea.pressed ? 0.95 : 1.0
            Behavior on scale {
                NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
            }

            Text {
                text: "Наведи и нажми"
                anchors.centerIn: parent
                color: "#11111b"
                font.bold: true
                font.pixelSize: 16
            }

            // Невидимая зона, которая ловит клики и движение мыши
            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true // Включаем реакцию на наведение
                onClicked: {
                    console.log("Клик сработал в QML!") // Выведет в консоль
                }
            }
        }
    }
}
