import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    visible: true
    width: 960
    height: 650
    minimumWidth: 600
    minimumHeight: 400
    title: "Модульность: Открепляемые и прикрепляемые панели (Docking)"
    color: "#11111b"
    flags: Qt.FramelessWindowHint | Qt.Window

    // Состояние: откреплен ли сайдбар в отдельное плавающее окно
    property bool isSidebarDetached: false

    // =========================================================================
    // ПЛАВАЮЩЕЕ ОКНО ДЛЯ ОТКРЕПЛЕННОГО САЙДБАРА
    // =========================================================================
    Window {
        id: detachedWindow
        title: "Плавающая панель: Навигация"
        width: 260
        height: 520
        minimumWidth: 180
        minimumHeight: 300
        visible: root.isSidebarDetached
        color: "#181825"
        flags: Qt.FramelessWindowHint | Qt.Window

        // Размещаем окно рядом с основным при первом откреплении
        x: root.x + root.width + 12
        y: root.y

        // При закрытии окна — возвращаем сайдбар назад в главное окно
        onClosing: {
            root.isSidebarDetached = false
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Шапка плавающего окна
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                color: "#11111b"

                MouseArea {
                    anchors.fill: parent
                    onPressed: detachedWindow.startSystemMove()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8

                    Label {
                        text: "🗖  Плавающая панель"
                        color: "#a6adc8"
                        font.pixelSize: 11
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }

                    // Кнопка прикрепить назад
                    Button {
                        text: "↙ Встроить"
                        implicitHeight: 22
                        background: Rectangle {
                            radius: 3
                            color: parent.hovered ? "#89b4fa" : "#313244"
                        }
                        contentItem: Text {
                            text: parent.text
                            color: parent.hovered ? "#11111b" : "#cdd6f4"
                            font.pixelSize: 11
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: root.isSidebarDetached = false
                    }
                }
            }

            // Сам контент сайдбара внутри плавающего окна
            SidebarContent {
                Layout.fillWidth: true
                Layout.fillHeight: true
                isDetached: true
                onToggleDockRequested: root.isSidebarDetached = false
            }
        }
    }

    // =========================================================================
    // ГЛАВНОЕ ОКНО
    // =========================================================================
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // 1. Главная шапка приложения (TitleBar)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            color: "#181825"
            border.color: "#313244"
            border.width: 1

            MouseArea {
                anchors.fill: parent
                onDoubleClicked: {
                    if (root.visibility === Window.Maximized)
                        root.showNormal()
                    else
                        root.showMaximized()
                }
                onPressed: root.startSystemMove()
            }

            RowLayout {
                anchors.fill: parent
                spacing: 8

                Rectangle {
                    width: 12; height: 12; radius: 6
                    color: "#fab387"
                    Layout.leftMargin: 12
                }

                Label {
                    text: root.title
                    color: "#a6adc8"
                    font.pixelSize: 12
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                // Системные кнопки
                Button {
                    text: "—"
                    implicitWidth: 42; implicitHeight: 38
                    
                    background: Rectangle {
                        color: parent.hovered ? "#313244" : "transparent"    
                    }
                    
                    contentItem: Text {
                        text: parent.text;
                        color: "#cdd6f4";
                        horizontalAlignment: Text.AlignHCenter;
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: root.showMinimized()
                }

                Button {
                    text: root.visibility === Window.Maximized ? "❐" : "▢"
                    implicitWidth: 42;
                    implicitHeight: 38
                    background: Rectangle {
                        color: parent.hovered ? "#313244" : "transparent"
                    }
                    contentItem: Text {
                        text: parent.text;
                        color: "#cdd6f4";
                        horizontalAlignment: Text.AlignHCenter;
                        verticalAlignment: Text.AlignVCenter 
                    }
                    onClicked: {
                        if (root.visibility === Window.Maximized) root.showNormal()
                        else root.showMaximized()
                    }
                }
                Button {
                    text: "✕"
                    implicitWidth: 46; implicitHeight: 38
                    background: Rectangle { color: parent.hovered ? "#e78284" : "transparent" }
                    contentItem: Text { text: parent.text; color: parent.hovered ? "#11111b" : "#cdd6f4"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: {
                        detachedWindow.close()
                        root.close()
                    }
                }
            }
        }

        // 2. Рабочая область со сплиттером
        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Horizontal

            handle: Rectangle {
                implicitWidth: root.isSidebarDetached ? 0 : 4
                color: SplitHandle.pressed ? "#89b4fa" : (SplitHandle.hovered ? "#585b70" : "#181825")
            }

            // -----------------------------------------------------------------
            // ЛЕВАЯ ПАНЕЛЬ: Встроенный Сайдбар
            // -----------------------------------------------------------------
            Rectangle {
                id: sidebarContainer
                SplitView.preferredWidth: 220
                SplitView.minimumWidth: 160
                SplitView.maximumWidth: 350
                // Если откреплено — скрываем эту панель в основном окне
                visible: !root.isSidebarDetached
                color: "#181825"

                // Тот самый модульный компонент!
                SidebarContent {
                    anchors.fill: parent
                    isDetached: false
                    onToggleDockRequested: root.isSidebarDetached = true
                }
            }

            // -----------------------------------------------------------------
            // ПРАВАЯ ПАНЕЛЬ: Контентная часть
            // -----------------------------------------------------------------
            Rectangle {
                SplitView.fillWidth: true
                color: "#11111b"

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Хотбар
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56
                        color: "#1e1e2e"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            // Кнопка быстрого возврата сайдбара, если он откреплен
                            Button {
                                visible: root.isSidebarDetached
                                text: "📥 Вернуть панель навигации"
                                background: Rectangle {
                                    radius: 6
                                    color: parent.hovered ? "#a6e3a1" : "#313244"
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: parent.hovered ? "#11111b" : "#a6e3a1"
                                    font.bold: true
                                    font.pixelSize: 12
                                    leftPadding: 8; rightPadding: 8
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: root.isSidebarDetached = false
                            }

                            Label {
                                text: "Рабочая панель"
                                color: "#cdd6f4"
                                font.pixelSize: 16
                                font.bold: true
                            }

                            Item { Layout.fillWidth: true }

                            TextField {
                                placeholderText: "🔍 Поиск..."
                                Layout.preferredWidth: 200
                                Layout.preferredHeight: 32
                                color: "#cdd6f4"
                                background: Rectangle {
                                    radius: 6
                                    color: "#181825"
                                    border.color: "#313244"
                                }
                            }
                        }
                    }

                    // Центральный контент
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "transparent"

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 14

                            Label {
                                text: "🧩 Модульная архитектура (Docking)"
                                color: "#fab387"
                                font.pixelSize: 22
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Label {
                                text: "Нажмите на стрелочку ↗ в шапке сайдбара (или кнопку ниже),\nчтобы превратить его в независимое плавающее окно!\n\nВы можете перетаскивать плавающее окно на второй монитор,\nа затем вернуть обратно по кнопке ↙."
                                color: "#a6adc8"
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Button {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.isSidebarDetached ? "🔒 Прикрепить сайдбар назад" : "↗ Открепить сайдбар в плавающее окно"
                                implicitWidth: 260
                                implicitHeight: 40

                                HoverHandler { cursorShape: Qt.PointingHandCursor }

                                background: Rectangle {
                                    radius: 8
                                    color: parent.down ? "#89b4fa" : (parent.hovered ? "#b4befe" : "#313244")
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: parent.hovered ? "#11111b" : "#cdd6f4"
                                    font.bold: true
                                    font.pixelSize: 13
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: root.isSidebarDetached = !root.isSidebarDetached
                            }
                        }
                    }
                }
            }
        }
    }
}
