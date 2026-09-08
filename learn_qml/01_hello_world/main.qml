import QtQuick
import QtQuick.Controls // Обязательно для Button
import QtQuick.Layouts  // Обязательно для Layouts

ApplicationWindow {
    visible: true
    width: 400
    height: 300
    color: "#1e1e2e"

    // RowLayout выстроит элементы в строку и будет управлять их шириной
    RowLayout {
        anchors.fill: parent // Layout заполняет всё окно
        anchors.margins: 20  // Отступы от краев окна

        Button {
            text: "Кнопка слева"
            // Запрещаем кнопке растягиваться
            Layout.fillWidth: false 
        }

        // Пустой элемент, который работает как пружина, 
        // выталкивая правую кнопку вправо
        Item {
            Layout.fillWidth: true 
        }

        Button {
            text: "Кнопка справа"
            Layout.fillWidth: false
        }
    }
}
