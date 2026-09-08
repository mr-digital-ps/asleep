import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "pages" // Подключаем папку со страницами!

ApplicationWindow {
    id: root
    visible: true
    width: 980
    height: 680
    minimumWidth: 720
    minimumHeight: 480
    title: "Архитектура MVVM: Навигация и Передача типов данных"
    color: "#11111b"
    flags: Qt.FramelessWindowHint | Qt.Window

    // Текущий индекс активной страницы (0: Home, 1: Types, 2: Settings)
    property int currentPageIndex: 0

    // -------------------------------------------------------------------------
    // Переиспользуемая кнопка навигации
    // -------------------------------------------------------------------------
    component NavTabButton: Button {
        id: btn
        property int targetIndex: 0
        property bool isActive: root.currentPageIndex === targetIndex

        Layout.fillWidth: true
        implicitHeight: 40

        HoverHandler { cursorShape: Qt.PointingHandCursor }

        background: Rectangle {
            radius: 8
            color: btn.isActive ? "#89b4fa" : (btn.hovered ? "#313244" : "transparent")
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        contentItem: Text {
            text: btn.text
            color: btn.isActive ? "#11111b" : (btn.hovered ? "#ffffff" : "#cdd6f4")
            font.pixelSize: 13
            font.bold: btn.isActive
            horizontalAlignment: Text.AlignLeft
            leftPadding: 14
            verticalAlignment: Text.AlignVCenter
        }

        onClicked: root.currentPageIndex = targetIndex
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // =====================================================================
        // 1. ШАПКА ОКНА (TitleBar)
        // =====================================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            color: "#181825"
            border.color: "#313244"
            border.width: 1

            MouseArea {
                anchors.fill: parent
                onDoubleClicked: {
                    if (root.visibility === Window.Maximized) root.showNormal()
                    else root.showMaximized()
                }
                onPressed: root.startSystemMove()
            }

            RowLayout {
                anchors.fill: parent
                spacing: 8

                Rectangle {
                    width: 12; height: 12; radius: 6
                    color: "#cba6f7"
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
                    background: Rectangle { color: parent.hovered ? "#313244" : "transparent" }
                    contentItem: Text { text: parent.text; color: "#cdd6f4"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: root.showMinimized()
                }
                Button {
                    text: root.visibility === Window.Maximized ? "❐" : "▢"
                    implicitWidth: 42; implicitHeight: 38
                    background: Rectangle { color: parent.hovered ? "#313244" : "transparent" }
                    contentItem: Text { text: parent.text; color: "#cdd6f4"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
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
                    onClicked: root.close()
                }
            }
        }

        // =====================================================================
        // 2. ОСНОВНАЯ ОБЛАСТЬ: Сайдбар + Страницы
        // =====================================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // САЙДБАР (Навигация)
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 220
                color: "#181825"
                border.color: "#313244"
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Label {
                        text: "РАЗДЕЛЫ"
                        color: "#6c7086"
                        font.pixelSize: 11
                        font.bold: true
                        Layout.leftMargin: 4
                    }

                    // Кнопки переключения страниц
                    NavTabButton { text: "🏠  Главная"; targetIndex: 0 }
                    NavTabButton { text: "🧪  Типы данных"; targetIndex: 1 }
                    NavTabButton { text: "⚙️  Настройки"; targetIndex: 2 }

                    Item { Layout.fillHeight: true }

                    // Виджет текущего пользователя (с реактивным свойством)
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 46
                        radius: 8
                        color: "#11111b"
                        border.color: "#313244"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Rectangle {
                                width: 28; height: 28; radius: 14
                                color: "#89b4fa"
                                Label {
                                    anchors.centerIn: parent
                                    text: backend.userName.charAt(0).toUpperCase()
                                    color: "#11111b"
                                    font.bold: true
                                }
                            }

                            ColumnLayout {
                                spacing: 2
                                Label {
                                    text: backend.userName // Реактивно обновляется!
                                    color: "#cdd6f4"
                                    font.bold: true
                                    font.pixelSize: 12
                                }
                                Label {
                                    text: "В сети"
                                    color: "#a6e3a1"
                                    font.pixelSize: 10
                                }
                            }
                        }
                    }
                }
            }

            // =================================================================
            // ПРАВАЯ ОБЛАСТЬ: Менеджер страниц (StackLayout)
            // =================================================================
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#11111b"

                // StackLayout отображает ровно ту страницу, чей индекс равен currentIndex!
                StackLayout {
                    anchors.fill: parent
                    currentIndex: root.currentPageIndex

                    // Страница 0
                    HomePage {}

                    // Страница 1
                    TypesDemoPage {}

                    // Страница 2
                    SettingsPage {}
                }
            }
        }
    }
}
