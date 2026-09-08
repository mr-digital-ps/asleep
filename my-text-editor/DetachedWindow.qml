import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Window {
    id: detachedWin

    // Свойства документа
    property int tabIndex: -1
    property string fileName: "Документ"
    property string fileUrl: ""
    property string initialText: ""
    property alias mainBarItem: mainBar
    property alias mainBarText: mainBar.text

    // Сигналы для связи с главным окном
    signal reattachRequested(int index, string content, string title)
    signal dropRequested(int index, real globalX, real globalY, string content, string title)
    signal textChanged(int index, string content)
    signal titleChanged(int index, string title)
    signal windowClosed(int index, string content, string title)

    title: (fileName === "" ? "Без названия" : fileName) + " — Редактор"
    width: 750
    height: 550
    minimumWidth: 420
    minimumHeight: 300
    color: "#141414"
    property bool isDraggingMode: false
    flags: isDraggingMode ? (Qt.Window | Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus) : (Qt.Window | Qt.FramelessWindowHint)
    visible: true

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // =====================================================================
        // ВЕРХНЯЯ ШАПКА ПЛАВАЮЩЕГО ОКНА
        // =====================================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: "#202020"
            z: 10

            // Перемещение окна за шапку с проверкой причаливания к главному окну
            MouseArea {
                id: headerDragArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                preventStealing: true

                property real pressGlobalX: 0
                property real pressGlobalY: 0
                property real startWinX: 0
                property real startWinY: 0
                property bool isDragging: false

                onPressed: (mouse) => {
                    if (mouse.button === Qt.LeftButton) {
                        let p = headerDragArea.mapToGlobal(mouse.x, mouse.y)
                        pressGlobalX = p.x
                        pressGlobalY = p.y
                        startWinX = detachedWin.x
                        startWinY = detachedWin.y
                        isDragging = false
                    }
                }

                onPositionChanged: (mouse) => {
                    if (!pressed) return
                    let p = headerDragArea.mapToGlobal(mouse.x, mouse.y)
                    let dx = p.x - pressGlobalX
                    let dy = p.y - pressGlobalY

                    if (!isDragging) {
                        if (Math.sqrt(dx * dx + dy * dy) > 8) {
                            isDragging = true
                            if (detachedWin.visibility === Window.Maximized) {
                                detachedWin.showNormal()
                            }
                        }
                    }

                    if (isDragging) {
                        detachedWin.x = Math.round(startWinX + dx)
                        detachedWin.y = Math.round(startWinY + dy)
                    }
                }

                onReleased: (mouse) => {
                    if (isDragging) {
                        isDragging = false
                        let p = headerDragArea.mapToGlobal(mouse.x, mouse.y)
                        detachedWin.dropRequested(detachedWin.tabIndex, p.x, p.y, mainBar.text, detachedWin.fileName)
                    }
                }

                onDoubleClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton) {
                        if (detachedWin.visibility === Window.Maximized) {
                            detachedWin.showNormal()
                        } else {
                            detachedWin.showMaximized()
                        }
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                spacing: 8

                // Иконка плавающего окна
                Text {
                    text: "🗖"
                    color: "#888888"
                    font.pixelSize: 12
                }

                // Имя документа
                Label {
                    text: detachedWin.fileName === "" ? "Без названия" : detachedWin.fileName
                    color: "#cccccc"
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.maximumWidth: 300
                }

                // Пружина
                Item { Layout.fillWidth: true }

                // Кнопка: Встроить назад в главное окно (↙)
                Button {
                    id: reattachBtn
                    implicitWidth: 32
                    implicitHeight: 28
                    hoverEnabled: true
                    ToolTip.visible: hovered
                    ToolTip.text: "Встроить назад в главное окно"

                    background: Rectangle {
                        radius: 3
                        color: reattachBtn.down ? "#333333" : (reattachBtn.hovered ? "#2a2a2a" : "transparent")
                    }

                    contentItem: Text {
                        text: "↙"
                        color: reattachBtn.hovered ? "#ffffff" : "#aaaaaa"
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        detachedWin.reattachRequested(detachedWin.tabIndex, mainBar.text, detachedWin.fileName)
                    }
                }

                // Кнопка: Свернуть (—)
                Button {
                    id: minBtn
                    implicitWidth: 32
                    implicitHeight: 28
                    hoverEnabled: true

                    background: Rectangle {
                        radius: 3
                        color: minBtn.down ? "#333333" : (minBtn.hovered ? "#2a2a2a" : "transparent")
                    }

                    contentItem: Text {
                        text: "—"
                        color: minBtn.hovered ? "#ffffff" : "#aaaaaa"
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: detachedWin.showMinimized()
                }

                // Кнопка: Развернуть / Восстановить (🗖 / ❐)
                Button {
                    id: maxBtn
                    implicitWidth: 32
                    implicitHeight: 28
                    hoverEnabled: true

                    readonly property bool isMax: detachedWin.visibility === Window.Maximized

                    background: Rectangle {
                        radius: 3
                        color: maxBtn.down ? "#333333" : (maxBtn.hovered ? "#2a2a2a" : "transparent")
                    }

                    contentItem: Text {
                        text: maxBtn.isMax ? "❐" : "🗖"
                        color: maxBtn.hovered ? "#ffffff" : "#aaaaaa"
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        if (detachedWin.visibility === Window.Maximized) {
                            detachedWin.showNormal()
                        } else {
                            detachedWin.showMaximized()
                        }
                    }
                }

                // Кнопка: Закрыть (✕)
                Button {
                    id: closeBtn
                    implicitWidth: 32
                    implicitHeight: 28
                    hoverEnabled: true

                    background: Rectangle {
                        radius: 3
                        color: closeBtn.down ? "#444444" : (closeBtn.hovered ? "#333333" : "transparent")
                    }

                    contentItem: Text {
                        text: "✕"
                        color: closeBtn.hovered ? "#ffffff" : "#aaaaaa"
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        detachedWin.reattachRequested(detachedWin.tabIndex, mainBar.text, detachedWin.fileName)
                    }
                }
            }
        }

        // =====================================================================
        // РЕДАКТОР ДОКУМЕНТА (MainBar)
        // =========================================================================
        MainBar {
            id: mainBar
            Layout.fillWidth: true
            Layout.fillHeight: true
            fileName: detachedWin.fileName

            Component.onCompleted: {
                editorArea.text = detachedWin.initialText
            }

            onTitleChangedByUser: (newTitle) => {
                detachedWin.fileName = newTitle
                detachedWin.titleChanged(detachedWin.tabIndex, newTitle)
            }
        }
    }

    // Передаем изменения текста в реальном времени
    Connections {
        target: mainBar.editorArea
        function onTextChanged() {
            detachedWin.textChanged(detachedWin.tabIndex, mainBar.text)
        }
    }

    // При закрытии окна системой возвращаем данные
    onClosing: {
        detachedWin.reattachRequested(detachedWin.tabIndex, mainBar.text, detachedWin.fileName)
    }
}
