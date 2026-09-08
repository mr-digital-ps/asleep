import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    color: "#141414"

    // 1. ВЕРХНЯЯ ПАНЕЛЬ (Header / TitleBar)
    Rectangle {
        id: titleBar
        height: 40
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        color: "#202020"

        // Зона перетаскивания окна мышкой (только за шапку!)
        MouseArea {
            anchors.fill: parent
            onPressed: Window.window.startSystemMove()
        }

        // Текст СЛЕВА
        Label {
            text: "Hello world"
            color: "white"
            anchors.left: parent.left
            anchors.leftMargin: 15
            anchors.verticalCenter: parent.verticalCenter
        }

        // Кнопки СПРАВА
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Button { 
                text: "—";
                height: titleBar.height
                width: titleBar.height

                onClicked: Window.window.showMinimized()
            }

            Button { 
                text: "✕";
                onClicked: Window.window.close() 
                height: titleBar.height
                width: titleBar.height
            }
        }
    }

    // 2. ОСНОВНОЙ КОНТЕНТ (ниже шапки)
    Rectangle {
        anchors.top: titleBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: "transparent"

        Label {
            text: "Основная область окна"
            color: "#888888"
            anchors.centerIn: parent
        }
    }
}
