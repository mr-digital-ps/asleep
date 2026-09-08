import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    visible: true
    width: 1000
    height: 700
    minimumWidth: 700
    minimumHeight: 500
    title: "Интерактивный Docking: Перетаскивание и примагничивание"
    color: "#11111b"
    flags: Qt.FramelessWindowHint | Qt.Window

    // Состояние докинга: "left", "right", "bottom", "floating"
    property string dockPosition: "left"
    // Текущая подсвечиваемая зона при перетаскивании ("none", "left", "right", "bottom")
    property string activeSnapZone: "none"
    // Флаг перетаскивания
    property bool isDraggingPanel: false

    // -------------------------------------------------------------------------
    // Главная вертикальная раскладка
    // -------------------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // 1. Шапка окна (TitleBar)
        Rectangle {
            id: titleBar
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            color: "#181825"
            border.color: "#313244"
            border.width: 1
            z: 10

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
                    color: "#89dceb"
                    Layout.leftMargin: 12
                }

                Label {
                    text: root.title
                    color: "#a6adc8"
                    font.pixelSize: 12
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

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
        // 2. РАБОЧАЯ ОБЛАСТЬ (Холст для докинга)
        // =====================================================================
        Item {
            id: workspace
            Layout.fillWidth: true
            Layout.fillHeight: true

            // -----------------------------------------------------------------
            // Центральный контент (всегда занимает свободное место)
            // -----------------------------------------------------------------
            Rectangle {
                id: mainContent
                anchors {
                    left: dockPosition === "left" && !isDraggingPanel ? dockablePanel.right : parent.left
                    right: dockPosition === "right" && !isDraggingPanel ? dockablePanel.left : parent.right
                    top: parent.top
                    bottom: dockPosition === "bottom" && !isDraggingPanel ? dockablePanel.top : parent.bottom
                }
                color: "#11111b"

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 16

                    Label {
                        text: "🎯 Drag & Drop Docking с подсветкой зон"
                        color: "#89b4fa"
                        font.pixelSize: 22
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Label {
                        text: "Попробуйте:\n1. Зажать ЛКМ за верхнюю шапку панели навигации (где написано ':: Панель')\n2. Потянуть её вправо, влево, вниз или по центру\n3. Обратите внимание на синий полупрозрачный силуэт (Drop Zone)\n4. Отпустите панель — она примагнитится к выбранной стороне!"
                        color: "#cdd6f4"
                        font.pixelSize: 14
                        lineHeight: 1.4
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 10

                        Button {
                            text: "⬅ Примагнитить влево"
                            background: Rectangle { radius: 6; color: parent.hovered ? "#89b4fa" : "#1e1e2e"; border.color: "#313244" }
                            contentItem: Text { text: parent.text; color: parent.hovered ? "#11111b" : "#cdd6f4"; font.bold: true; padding: 8 }
                            onClicked: { root.dockPosition = "left"; root.activeSnapZone = "none" }
                        }
                        Button {
                            text: "⬇ Примагнитить вниз"
                            background: Rectangle { radius: 6; color: parent.hovered ? "#89b4fa" : "#1e1e2e"; border.color: "#313244" }
                            contentItem: Text { text: parent.text; color: parent.hovered ? "#11111b" : "#cdd6f4"; font.bold: true; padding: 8 }
                            onClicked: { root.dockPosition = "bottom"; root.activeSnapZone = "none" }
                        }
                        Button {
                            text: "➡ Примагнитить вправо"
                            background: Rectangle { radius: 6; color: parent.hovered ? "#89b4fa" : "#1e1e2e"; border.color: "#313244" }
                            contentItem: Text { text: parent.text; color: parent.hovered ? "#11111b" : "#cdd6f4"; font.bold: true; padding: 8 }
                            onClicked: { root.dockPosition = "right"; root.activeSnapZone = "none" }
                        }
                    }
                }
            }

            // =================================================================
            // ПРИЗРАЧНАЯ ПОДСВЕТКА ЗОНЫ СТЫКОВКИ (Drop Zone Ghost Preview)
            // =================================================================
            Rectangle {
                id: ghostPreview
                visible: root.activeSnapZone !== "none" && root.isDraggingPanel
                color: "#3589b4fa"
                border.color: "#89b4fa"
                border.width: 2
                radius: 8
                z: 20

                // Плавная анимация появления и изменения геометрии подсказки
                Behavior on x { NumberAnimation { duration: 120 } }
                Behavior on y { NumberAnimation { duration: 120 } }
                Behavior on width { NumberAnimation { duration: 120 } }
                Behavior on height { NumberAnimation { duration: 120 } }

                // Геометрия в зависимости от активной зоны
                x: {
                    if (root.activeSnapZone === "left") return 0
                    if (root.activeSnapZone === "right") return workspace.width - 240
                    if (root.activeSnapZone === "bottom") return 0
                    return 0
                }
                y: {
                    if (root.activeSnapZone === "bottom") return workspace.height - 180
                    return 0
                }
                width: {
                    if (root.activeSnapZone === "left" || root.activeSnapZone === "right") return 240
                    if (root.activeSnapZone === "bottom") return workspace.width
                    return 0
                }
                height: {
                    if (root.activeSnapZone === "bottom") return 180
                    return workspace.height
                }

                Label {
                    anchors.centerIn: parent
                    text: "Прикрепить сюда"
                    color: "#ffffff"
                    font.bold: true
                    font.pixelSize: 14
                }
            }

            // =================================================================
            // САМА ДОКИРУЕМАЯ ПАНЕЛЬ (Dockable Panel)
            // =================================================================
            Rectangle {
                id: dockablePanel
                z: isDraggingPanel ? 50 : 5
                color: "#181825"
                border.color: isDraggingPanel ? "#89b4fa" : "#313244"
                border.width: 1
                radius: isDraggingPanel ? 8 : 0

                // Размеры и координаты в прикрепленном/плавающем состоянии
                width: {
                    if (root.dockPosition === "bottom" && !isDraggingPanel) return workspace.width
                    return 240
                }
                height: {
                    if (root.dockPosition === "bottom" && !isDraggingPanel) return 180
                    if (root.dockPosition === "floating" || isDraggingPanel) return 320
                    return workspace.height
                }

                x: {
                    if (isDraggingPanel || root.dockPosition === "floating") return dragArea.panelX
                    if (root.dockPosition === "right") return workspace.width - width
                    return 0
                }

                y: {
                    if (isDraggingPanel || root.dockPosition === "floating") return dragArea.panelY
                    if (root.dockPosition === "bottom") return workspace.height - height
                    return 0
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // ШАПКА ПАНЕЛИ (За неё мы тащим!)
                    Rectangle {
                        id: panelHeader
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        color: isDraggingPanel ? "#313244" : "#1e1e2e"
                        radius: isDraggingPanel ? 8 : 0

                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            cursorShape: Qt.SizeAllCursor

                            property real startMouseX: 0
                            property real startMouseY: 0
                            property real panelX: 50
                            property real panelY: 50

                            onPressed: (mouse) => {
                                startMouseX = mouse.x
                                startMouseY = mouse.y
                                root.isDraggingPanel = true
                                // Вычисляем координаты панели на холсте
                                panelX = dockablePanel.x
                                panelY = dockablePanel.y
                            }

                            onPositionChanged: (mouse) => {
                                if (pressed) {
                                    panelX += mouse.x - startMouseX
                                    panelY += mouse.y - startMouseY

                                    // Ограничиваем перемещение в пределах рабочей области
                                    panelX = Math.max(0, Math.min(panelX, workspace.width - dockablePanel.width))
                                    panelY = Math.max(0, Math.min(panelY, workspace.height - dockablePanel.height))

                                    // Проверяем приближение к зонам примагничивания (Snapping Logic)
                                    let globalCursorX = panelX + mouse.x
                                    let globalCursorY = panelY + mouse.y

                                    if (globalCursorX < 150) {
                                        root.activeSnapZone = "left"
                                    } else if (globalCursorX > workspace.width - 150) {
                                        root.activeSnapZone = "right"
                                    } else if (globalCursorY > workspace.height - 120) {
                                        root.activeSnapZone = "bottom"
                                    } else {
                                        root.activeSnapZone = "none"
                                    }
                                }
                            }

                            onReleased: {
                                root.isDraggingPanel = false
                                if (root.activeSnapZone !== "none") {
                                    // Примагничиваем к выбранной зоне!
                                    root.dockPosition = root.activeSnapZone
                                    root.activeSnapZone = "none"
                                } else {
                                    // Оставляем плавающей в свободном полете
                                    root.dockPosition = "floating"
                                }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8

                            Label {
                                text: "⋮⋮  Навигация / Сайдбар"
                                color: "#cdd6f4"
                                font.pixelSize: 12
                                font.bold: true
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: 50; height: 18; radius: 3
                                color: "#313244"
                                Label {
                                    anchors.centerIn: parent
                                    text: root.dockPosition.toUpperCase()
                                    color: "#a6adc8"
                                    font.pixelSize: 9
                                    font.bold: true
                                }
                            }
                        }
                    }

                    // СОДЕРЖИМОЕ ПАНЕЛИ
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.margins: 10
                        spacing: 6

                        Button {
                            text: "📁  Файловый менеджер"
                            Layout.fillWidth: true
                            implicitHeight: 34
                            background: Rectangle { radius: 6; color: parent.hovered ? "#313244" : "#1e1e2e" }
                            contentItem: Text { text: parent.text; color: "#cdd6f4"; font.pixelSize: 12; leftPadding: 8; verticalAlignment: Text.AlignVCenter }
                        }
                        Button {
                            text: "🔍  Глобальный поиск"
                            Layout.fillWidth: true
                            implicitHeight: 34
                            background: Rectangle { radius: 6; color: parent.hovered ? "#313244" : "#1e1e2e" }
                            contentItem: Text { text: parent.text; color: "#cdd6f4"; font.pixelSize: 12; leftPadding: 8; verticalAlignment: Text.AlignVCenter }
                        }
                        Button {
                            text: "⚙️  Настройки среды"
                            Layout.fillWidth: true
                            implicitHeight: 34
                            background: Rectangle { radius: 6; color: parent.hovered ? "#313244" : "#1e1e2e" }
                            contentItem: Text { text: parent.text; color: "#cdd6f4"; font.pixelSize: 12; leftPadding: 8; verticalAlignment: Text.AlignVCenter }
                        }

                        Item { Layout.fillHeight: true }

                        Label {
                            text: "💡 Зажмите шапку панели и перетащите её"
                            color: "#6c7086"
                            font.pixelSize: 10
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }
    }
}
