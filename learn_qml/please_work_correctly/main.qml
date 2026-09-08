import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    visible: true
    width: 800
    height: 600
    title: "Sidebar и Hotbar"
    color: "#11111b" // Темный фон всего окна

    // Главный невидимый контейнер, делящий окно на "Лево" и "Право"
    RowLayout {
        anchors.fill: parent // Говорим: "растянись на всё окно"
        spacing: 0 // Убираем щели между зонами

        // ==========================================
        // 1. САЙДБАР (Левая панель)
        // ==========================================
        Rectangle {
            Layout.fillHeight: true // Тянется на всю высоту
            Layout.preferredWidth: 200 // Жестко задаем ширину 200
            color: "#1e1e2e" // Цвет сайдбара
            
            // Внутри сайдбара кнопки идут сверху вниз
            ColumnLayout {
                anchors.fill: parent // Растягиваем колонку на весь сайдбар
                anchors.margins: 15

                Button { text: "Профиль"; Layout.fillWidth: true }
                Button { text: "Настройки"; Layout.fillWidth: true }
                Button { text: "Сообщения"; Layout.fillWidth: true }

                // ---> ВОТ ОНА ПРУЖИНА <---
                // Это просто невидимая пустышка (Item).
                // Свойство Layout.fillHeight: true говорит ей: 
                // "Забери всё свободное место, которое осталось!"
                // Из-за этого она раздувается и выталкивает верхние кнопки вверх, 
                // а нижнюю кнопку "Выход" — прижимает к низу.
                Item {
                    Layout.fillHeight: true
                }

                Button { text: "Выход"; Layout.fillWidth: true }
            }
        }

        // ==========================================
        // 2. ПРАВАЯ ЧАСТЬ (Hotbar + Контент)
        // ==========================================
        ColumnLayout {
            Layout.fillWidth: true  // Забирает всю оставшуюся ширину окна
            Layout.fillHeight: true // Забирает всю высоту
            spacing: 0

            // 2.1 HOTBAR (Верхняя панель)
            Rectangle {
                Layout.fillWidth: true // Растягивается на всю ширину правой зоны
                Layout.preferredHeight: 60 // Жесткая высота 60
                color: "#313244"

                // Элементы верхней панели идут слева направо
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10

                    Label { 
                        text: "Главная страница"
                        color: "white"
                        font.pixelSize: 18
                        font.bold: true
                    }

                    // ---> ЕЩЕ ОДНА ПРУЖИНА (теперь по горизонтали) <---
                    // Она раздувается в ширину и расталкивает текст налево, а поиск - направо
                    Item { Layout.fillWidth: true }

                    TextField { 
                        placeholderText: "Поиск..." 
                        Layout.preferredWidth: 200
                    }
                }
            }

            // 2.2 ОСНОВНОЙ КОНТЕНТ
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true // Пружинит, заполняя всё место под Hotbar'ом
                color: "transparent" // Прозрачный (видно цвет окна)

                Label {
                    anchors.centerIn: parent // Якорем прибиваем ровно по центру
                    text: "Здесь будет ваш контент\n\nПопробуйте изменить размер окна!"
                    color: "#cdd6f4"
                    font.pixelSize: 24
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}