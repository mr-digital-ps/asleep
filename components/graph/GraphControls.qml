import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: controlsRoot

    property string searchQuery: ""
    property bool showLabels: true
    property real repulsion: 3000
    property real linkDistance: 80
    property bool isForcesExpanded: false

    signal resetViewRequested()
    signal closeRequested()
    signal forceParamChanged()

    width: 240
    implicitHeight: mainCol.implicitHeight + 20
    radius: 10
    color: "#1e1e24"
    border.color: "#32323f"
    border.width: 1

    ColumnLayout {
        id: mainCol
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // Заголовок и кнопка закрытия
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Граф связей"
                font.bold: true
                font.pixelSize: 13
                color: "#e0e0e0"
                Layout.fillWidth: true
            }

            Rectangle {
                width: 22
                height: 22
                radius: 4
                color: closeHover.hovered ? "#3a3a4c" : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: "#888899"
                    font.pixelSize: 11
                }

                HoverHandler { id: closeHover }
                TapHandler { onTapped: controlsRoot.closeRequested() }
            }
        }

        // Поле поиска узлов
        Rectangle {
            Layout.fillWidth: true
            height: 28
            radius: 6
            color: "#16161c"
            border.color: searchInput.activeFocus ? "#7aa2f7" : "#2a2a38"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 6

                Text {
                    text: "🔍"
                    font.pixelSize: 11
                    color: "#666677"
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    color: "#dcdcaa"
                    font.pixelSize: 12
                    selectByMouse: true
                    clip: true
                    onTextChanged: controlsRoot.searchQuery = text.trim().toLowerCase()

                    Text {
                        anchors.fill: parent
                        text: "Поиск узлов..."
                        color: "#555566"
                        font.pixelSize: 12
                        visible: !searchInput.text && !searchInput.activeFocus
                    }
                }

                Text {
                    visible: searchInput.text.length > 0
                    text: "✕"
                    color: "#888899"
                    font.pixelSize: 11
                    TapHandler { onTapped: searchInput.text = "" }
                }
            }
        }

        // Быстрые кнопки управления
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                height: 26
                radius: 5
                color: btnCenterHover.hovered ? "#2e2e3e" : "#242430"
                border.color: "#3a3a4c"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "⊙ Центр"
                    color: "#c0caf5"
                    font.pixelSize: 11
                }
                HoverHandler { id: btnCenterHover }
                TapHandler { onTapped: controlsRoot.resetViewRequested() }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 26
                radius: 5
                color: controlsRoot.showLabels ? (btnLblHover.hovered ? "#3d59a1" : "#2b3b6b") : (btnLblHover.hovered ? "#2e2e3e" : "#242430")
                border.color: controlsRoot.showLabels ? "#7aa2f7" : "#3a3a4c"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "Текст: " + (controlsRoot.showLabels ? "Вкл" : "Выкл")
                    color: controlsRoot.showLabels ? "#7aa2f7" : "#888899"
                    font.pixelSize: 11
                }
                HoverHandler { id: btnLblHover }
                TapHandler { onTapped: controlsRoot.showLabels = !controlsRoot.showLabels }
            }
        }

        // Разворачиваемый блок физики
        Rectangle {
            Layout.fillWidth: true
            height: 24
            radius: 4
            color: forcesHover.hovered ? "#262634" : "transparent"

            RowLayout {
                anchors.fill: parent
                spacing: 6

                Text {
                    text: controlsRoot.isForcesExpanded ? "▼ Физика графа" : "▶ Физика графа"
                    color: "#9aa5ce"
                    font.pixelSize: 11
                    Layout.fillWidth: true
                }
            }
            HoverHandler { id: forcesHover }
            TapHandler { onTapped: controlsRoot.isForcesExpanded = !controlsRoot.isForcesExpanded }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: controlsRoot.isForcesExpanded
            spacing: 8

            Text {
                text: "Сила отталкивания: " + Math.round(controlsRoot.repulsion)
                color: "#787c99"
                font.pixelSize: 10
            }

            Slider {
                Layout.fillWidth: true
                from: 500
                to: 8000
                value: controlsRoot.repulsion
                onMoved: {
                    controlsRoot.repulsion = value
                    controlsRoot.forceParamChanged()
                }
            }

            Text {
                text: "Длина связей: " + Math.round(controlsRoot.linkDistance)
                color: "#787c99"
                font.pixelSize: 10
            }

            Slider {
                Layout.fillWidth: true
                from: 30
                to: 200
                value: controlsRoot.linkDistance
                onMoved: {
                    controlsRoot.linkDistance = value
                    controlsRoot.forceParamChanged()
                }
            }
        }

        // Легенда цветов
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            RowLayout {
                spacing: 4
                Rectangle { width: 8; height: 8; radius: 4; color: "#4da6ff" }
                Text { text: "Файл"; color: "#787c99"; font.pixelSize: 10 }
            }
            RowLayout {
                spacing: 4
                Rectangle { width: 8; height: 8; radius: 4; color: "#bb9af7" }
                Text { text: "Блок H1"; color: "#787c99"; font.pixelSize: 10 }
            }
            RowLayout {
                spacing: 4
                Rectangle { width: 8; height: 8; radius: 4; color: "#e0af68" }
                Text { text: "Тег"; color: "#787c99"; font.pixelSize: 10 }
            }
        }
    }
}
