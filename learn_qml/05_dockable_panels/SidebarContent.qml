import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Отдельный независимый компонент Сайдбара
Rectangle {
    id: root
    color: "#181825"
    
    // Свойство: откреплена ли панель сейчас
    property bool isDetached: false
    
    // Сигналы, которые сайдбар шлет наружу
    signal toggleDockRequested()

    // -------------------------------------------------------------------------
    // Переиспользуемая кнопка
    // -------------------------------------------------------------------------
    component NavButton: Button {
        id: btn
        Layout.fillWidth: true
        implicitHeight: 36

        HoverHandler { cursorShape: Qt.PointingHandCursor }

        background: Rectangle {
            radius: 6
            color: btn.down ? "#45475a" : (btn.hovered ? "#313244" : "#1e1e2e")
            border.color: btn.hovered ? "#89b4fa" : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        contentItem: Text {
            text: btn.text
            color: btn.hovered ? "#ffffff" : "#cdd6f4"
            font.pixelSize: 13
            horizontalAlignment: Text.AlignLeft
            leftPadding: 12
            verticalAlignment: Text.AlignVCenter
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        // Мини-шапка сайдбара с кнопкой открепления
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 4

            Label {
                text: "НАВИГАЦИЯ"
                color: "#6c7086"
                font.pixelSize: 11
                font.bold: true
                Layout.leftMargin: 4
            }

            Item { Layout.fillWidth: true }

            // Кнопка: Открепить в отдельное окно / Прикрепить назад
            Button {
                id: dockBtn
                implicitWidth: 28
                implicitHeight: 28
                hoverEnabled: true
                ToolTip.visible: hovered
                ToolTip.text: root.isDetached ? "Прикрепить назад" : "Открепить в отдельное окно"

                HoverHandler { cursorShape: Qt.PointingHandCursor }

                background: Rectangle {
                    radius: 4
                    color: dockBtn.hovered ? "#313244" : "transparent"
                    border.color: dockBtn.hovered ? "#89b4fa" : "#313244"
                }

                contentItem: Text {
                    // Символ: ↗ (открепить) или ↙ (прикрепить)
                    text: root.isDetached ? "↙" : "↗"
                    color: dockBtn.hovered ? "#89b4fa" : "#a6adc8"
                    font.pixelSize: 15
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: root.toggleDockRequested()
            }
        }

        // Список разделов
        NavButton { text: "👤  Профиль" }
        NavButton { text: "📁  Проекты" }
        NavButton { text: "⚙️  Параметры" }
        NavButton { text: "💬  Чат и комьюнити" }
        NavButton { text: "📊  Статистика" }

        // Пружина
        Item { Layout.fillHeight: true }

        // Информация о режиме
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 30
            radius: 4
            color: root.isDetached ? "#313244" : "#11111b"

            Label {
                anchors.centerIn: parent
                text: root.isDetached ? "🟢 Плавающее окно" : "🔒 Закреплено"
                color: root.isDetached ? "#a6e3a1" : "#6c7086"
                font.pixelSize: 11
            }
        }
    }
}
