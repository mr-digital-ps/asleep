import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: mainBar

    // Свойства
    property int barSize: 36
    property string fileName: "Новый документ"
    property bool isCenteredMode: true // По умолчанию центрированный лист
    property bool isSplitMode: false
    property bool isActivePane: false
    property bool showCloseButton: false

    // Доступ к редактору для внешних скриптов
    property alias editorArea: editorArea
    property alias text: editorArea.text

    // Сигналы
    signal titleChangedByUser(string newTitle)
    signal closeRequested()
    signal paneActivated()

    // =========================================================================
    // ХОЛСТ РЕДАКТОРА С УМНЫМИ ЗОНАМИ ПЕРЕМЕЩЕНИЯ ОКНА
    // =========================================================================
    ScrollView {
        id: editorScroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth

        // Перехват кликов на свободном фоне вокруг листа:
        // - ЛКМ (drag): перетаскивание окна
        // - Двойной клик ЛКМ: развернуть / восстановить окно
        // - ПКМ: переключить ширину (полная / средняя)
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onPressed: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    Window.window.startSystemMove()
                }
            }

            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    mainBar.isCenteredMode = !mainBar.isCenteredMode
                }
            }

            onDoubleClicked: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    if (Window.window.visibility === Window.Maximized) {
                        Window.window.showNormal()
                    } else {
                        Window.window.showMaximized()
                    }
                }
            }
        }

        Item {
            width: editorScroll.availableWidth
            implicitHeight: Math.max(editorScroll.availableHeight, contentColumn.implicitHeight)

            // Поле для отображения страницы (на полную или среднюю ширину)
            Rectangle {
                id: paperSheet

                // Средняя ширина (800px) по центру либо на полную ширину
                width: mainBar.isCenteredMode ? Math.min(800, parent.width) : parent.width
                height: Math.max(parent.height, contentColumn.implicitHeight)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top

                color: "#181818"
                border.color: (mainBar.isSplitMode && mainBar.isActivePane) ? "#333333" : "transparent"
                border.width: 1

                ColumnLayout {
                    id: contentColumn
                    anchors.fill: parent
                    spacing: 0

                    // Верхняя панель заголовка листа (название + кнопка закрытия для сплита)
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 12
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        Layout.preferredHeight: 38
                        spacing: 8

                        TextField {
                            id: titleField
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: mainBar.fileName
                            font.pixelSize: 18
                            font.bold: true
                            color: "#ffffff"
                            placeholderText: "Без названия"
                            placeholderTextColor: "#444444"
                            selectByMouse: true
                            background: null

                            property string originalText: ""

                            onActiveFocusChanged: {
                                if (activeFocus) {
                                    originalText = text
                                    mainBar.paneActivated()
                                }
                            }

                            Keys.onEscapePressed: {
                                text = originalText
                                mainBar.titleChangedByUser(originalText)
                                focus = false
                            }

                            onTextEdited: {
                                mainBar.titleChangedByUser(text)
                            }
                        }

                        // Кнопка закрытия панели (видна только в режиме сплита для закрываемой панели)
                        Button {
                            id: closePaneBtn
                            visible: mainBar.showCloseButton
                            implicitWidth: 28
                            implicitHeight: 28
                            hoverEnabled: true

                            background: Rectangle {
                                radius: 4
                                color: closePaneBtn.down ? "#333333" : (closePaneBtn.hovered ? "#262626" : "transparent")
                            }

                            contentItem: Text {
                                text: "✕"
                                color: closePaneBtn.hovered ? "#ffffff" : "#666666"
                                font.pixelSize: 13
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: mainBar.closeRequested()
                        }
                    }

                    // Тонкая разделительная линия
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        height: 1
                        color: "#262626"
                    }

                    // Основное текстовое поле
                    TextArea {
                        id: editorArea
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        padding: 16

                        font.family: "Consolas, Courier New, monospace"
                        font.pixelSize: 15
                        wrapMode: TextArea.Wrap
                        selectByMouse: true
                        placeholderText: "Начните вводить текст..."
                        placeholderTextColor: "#666666"

                        background: null

                        onActiveFocusChanged: {
                            if (activeFocus) {
                                mainBar.paneActivated()
                            }
                        }

                        // Клик ПКМ по тексту переключает ширину (полная / средняя)
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton
                            cursorShape: Qt.IBeamCursor
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    mainBar.isCenteredMode = !mainBar.isCenteredMode
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
