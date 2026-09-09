import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: mainBar

    // Свойства
    property int barSize: 36
    property string fileName: "Новый документ"
    property bool isCenteredMode: true // По умолчанию центрированный лист
    property real customSheetWidth: 800 // Пользовательская ширина листа (настраивается курсором)
    property real minSheetWidth: 380    // Минимальная ширина листа
    // Дополнительное пространство внизу листа для скролла за последнюю строку
    property real scrollBeyondSpace: (editorArea.lineCount > 1 || contentColumn.implicitHeight > editorScroll.availableHeight * 0.5)
        ? Math.max(0, editorScroll.availableHeight - 60) : 0
    property bool isSplitMode: false
    property bool isActivePane: false
    property bool showCloseButton: false
    property bool isEmpty: false

    // Доступ к редактору для внешних скриптов
    property alias editorArea: editorArea
    property alias text: editorArea.text

    // Сигналы
    signal titleChangedByUser(string newTitle)
    signal closeRequested()
    signal paneActivated()
    signal detachRequested()

    function isCloseKey(event) {
        if (!(event.modifiers & Qt.ControlModifier)) return false
        // W key: Key_W, scan code 17, or Cyrillic 'ц'
        if (event.key === Qt.Key_W || event.nativeScanCode === 17 || event.text === 'w' || event.text === 'W' || event.text === 'ц' || event.text === 'Ц' || event.key === 1062 || event.key === 1030) return true
        // Q key: Key_Q, scan code 16, or Cyrillic 'й'
        if (event.key === Qt.Key_Q || event.nativeScanCode === 16 || event.text === 'q' || event.text === 'Q' || event.text === 'й' || event.text === 'Й' || event.key === 1081 || event.key === 1049) return true
        return false
    }

    // Перехват кликов по панели для мгновенной активации нужной половины сплита
    TapHandler {
        gesturePolicy: TapHandler.WithinBounds
        onTapped: mainBar.paneActivated()
    }

    // =========================================================================
    // ХОЛСТ РЕДАКТОРА
    // =========================================================================
    ScrollView {
        id: editorScroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        WheelHandler {
            target: editorScroll.contentItem
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                let dy = -event.angleDelta.y
                let newY = editorScroll.contentItem.contentY + dy
                let maxY = Math.max(0, editorScroll.contentItem.contentHeight - editorScroll.availableHeight)
                editorScroll.contentItem.contentY = Math.max(0, Math.min(maxY, newY))
            }
        }

        // Перехват кликов на свободном фоне вокруг листа:
        // - ЛКМ (drag): перетаскивание окна
        // - Двойной клик ЛКМ: развернуть / восстановить окно
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton

            onPressed: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    Window.window.startSystemMove()
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
            height: Math.max(editorScroll.availableHeight, contentColumn.implicitHeight + mainBar.scrollBeyondSpace + 40)
            implicitHeight: height

            // Поле для отображения страницы (на полную или среднюю/настраиваемую ширину)
            Rectangle {
                id: paperSheet
                visible: !mainBar.isEmpty

                width: mainBar.isCenteredMode ? Math.min(parent.width, Math.max(mainBar.minSheetWidth, mainBar.customSheetWidth)) : parent.width
                height: Math.max(parent.height, contentColumn.implicitHeight + mainBar.scrollBeyondSpace + 40)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top

                color: "#181818"
                border.color: "transparent"
                border.width: 0

                opacity: (mainBar.isSplitMode && !mainBar.isActivePane) ? 0.55 : 1.0
                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }

                ColumnLayout {
                    id: contentColumn
                    anchors.fill: parent
                    spacing: 0

                    // 1. Верхняя панель заголовка листа (название документа)
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.topMargin: 16
                        Layout.leftMargin: 36
                        Layout.rightMargin: 36
                        Layout.preferredHeight: 38
                        Layout.maximumHeight: 38
                        Layout.minimumHeight: 38
                        spacing: 0

                        TextField {
                            id: titleField
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignLeft
                            text: mainBar.fileName
                            font.pixelSize: 18
                            font.bold: true
                            color: (mainBar.isSplitMode && !mainBar.isActivePane) ? "#888888" : "#ffffff"
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

                            Keys.onShortcutOverride: (event) => {
                                if (mainBar.isCloseKey(event)) {
                                    event.accepted = true
                                }
                            }

                            Keys.onPressed: (event) => {
                                if (mainBar.isCloseKey(event)) {
                                    mainBar.closeRequested()
                                    event.accepted = true
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
                    }

                    // 2. Тонкая разделительная линия
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.preferredHeight: 1
                        Layout.maximumHeight: 1
                        Layout.topMargin: 8
                        Layout.bottomMargin: 8
                        Layout.leftMargin: 36
                        Layout.rightMargin: 36
                        height: 1
                        color: "#282828"
                    }

                    // 3. Содержимое документа (левая полоса 36px + текст + правая полоса 36px)
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 0

                        // Левая полоса с точками строк и зоной перетаскивания (компонент EditorGutter)
                        EditorGutter {
                            barSize: 36
                            editorArea: editorArea
                            onActivated: mainBar.paneActivated()
                        }

                        // Основное текстовое поле
                        TextArea {
                            id: editorArea
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            leftPadding: 0
                            rightPadding: 0
                            topPadding: 12
                            bottomPadding: 16

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

                            Keys.onShortcutOverride: (event) => {
                                if (mainBar.isCloseKey(event)) {
                                    event.accepted = true
                                }
                            }

                            Keys.onPressed: (event) => {
                                if (mainBar.isCloseKey(event)) {
                                    mainBar.closeRequested()
                                    event.accepted = true
                                }
                            }

                            onPressed: {
                                mainBar.paneActivated()
                            }
                        }

                        // Правая полоса перетаскивания (Grip Margin)
                        Item {
                            id: rightDragMargin
                            Layout.preferredWidth: 36
                            Layout.fillHeight: true

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                cursorShape: Qt.ArrowCursor
                                onPressed: {
                                    mainBar.paneActivated()
                                    Window.window.startSystemMove()
                                }
                                onDoubleClicked: {
                                    if (Window.window.visibility === Window.Maximized) {
                                        Window.window.showNormal()
                                    } else {
                                        Window.window.showMaximized()
                                    }
                                }
                            }
                        }
                    }
                }

                // Интерактивная граница изменения ширины листа слева (Resize Handle)
                MouseArea {
                    id: leftResizeHandle
                    width: 14
                    anchors.left: parent.left
                    anchors.leftMargin: -7
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    cursorShape: Qt.SizeHorCursor
                    hoverEnabled: true
                    z: 20

                    property real startMouseX: 0
                    property real startSheetWidth: 0

                    onPressed: (mouse) => {
                        let pt = mapToItem(editorScroll, mouse.x, mouse.y)
                        startMouseX = pt.x
                        startSheetWidth = paperSheet.width
                        mainBar.isCenteredMode = true
                    }

                    onPositionChanged: (mouse) => {
                        if (pressed) {
                            let pt = mapToItem(editorScroll, mouse.x, mouse.y)
                            let dx = pt.x - startMouseX
                            let newW = startSheetWidth - dx * 2
                            mainBar.customSheetWidth = Math.max(mainBar.minSheetWidth, Math.min(editorScroll.availableWidth, newW))
                        }
                    }

                    onDoubleClicked: {
                        if (paperSheet.width >= editorScroll.availableWidth - 20) {
                            mainBar.customSheetWidth = 800
                        } else {
                            mainBar.customSheetWidth = editorScroll.availableWidth
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 2
                        height: parent.height
                        color: "#50ffffff"
                        opacity: leftResizeHandle.containsMouse || leftResizeHandle.pressed ? 1.0 : 0.0
                        Behavior on opacity {
                            NumberAnimation { duration: 120 }
                        }
                    }
                }

                // Интерактивная граница изменения ширины листа справа (Resize Handle)
                MouseArea {
                    id: rightResizeHandle
                    width: 14
                    anchors.right: parent.right
                    anchors.rightMargin: -7
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    cursorShape: Qt.SizeHorCursor
                    hoverEnabled: true
                    z: 20

                    property real startMouseX: 0
                    property real startSheetWidth: 0

                    onPressed: (mouse) => {
                        let pt = mapToItem(editorScroll, mouse.x, mouse.y)
                        startMouseX = pt.x
                        startSheetWidth = paperSheet.width
                        mainBar.isCenteredMode = true
                    }

                    onPositionChanged: (mouse) => {
                        if (pressed) {
                            let pt = mapToItem(editorScroll, mouse.x, mouse.y)
                            let dx = pt.x - startMouseX
                            let newW = startSheetWidth + dx * 2
                            mainBar.customSheetWidth = Math.max(mainBar.minSheetWidth, Math.min(editorScroll.availableWidth, newW))
                        }
                    }

                    onDoubleClicked: {
                        if (paperSheet.width >= editorScroll.availableWidth - 20) {
                            mainBar.customSheetWidth = 800
                        } else {
                            mainBar.customSheetWidth = editorScroll.availableWidth
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 2
                        height: parent.height
                        color: "#50ffffff"
                        opacity: rightResizeHandle.containsMouse || rightResizeHandle.pressed ? 1.0 : 0.0
                        Behavior on opacity {
                            NumberAnimation { duration: 120 }
                        }
                    }
                }
            }
        }
    }

    // 4. Правая фиксированная полоса со скроллбаром-точкой (компонент EditorScrollbar)
    EditorScrollbar {
        editorScroll: editorScroll
        paperSheet: paperSheet
        isEmpty: mainBar.isEmpty
        barSize: 36
        onActivated: mainBar.paneActivated()
    }
}
