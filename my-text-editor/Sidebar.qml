import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: sideBar

    // Размеры
    property int barSize: 36
    property int currentWidth: 280
    property bool isDragging: false
    readonly property bool expanded: currentWidth > barSize

    // Модель вкладок и активный индекс
    property var tabsModel: null
    property int currentTabIndex: 0
    property bool isSplit: false
    property int backgroundTabIndex: -1

    // Сигналы для вкладок
    signal newClicked()
    signal tabSelected(int index)
    signal tabClosed(int index)
    signal tabRenamed(int index, string newTitle)
    signal tabDragStarted(int index, real globalX, real globalY)
    signal tabDragMoved(int index, real globalX, real globalY)
    signal tabDragEnded(int index, real globalX, real globalY)

    // Сигналы для действий
    signal openClicked()
    signal saveClicked()
    signal closeClicked()
    signal toggleMaximizeClicked()

    Layout.fillHeight: true
    Layout.preferredWidth: currentWidth
    clip: true
    color: "#202020"

    // Плавная анимация при кликах, отключена во время ручного ресайза мышкой
    Behavior on Layout.preferredWidth {
        enabled: !sideBar.isDragging
        NumberAnimation {
            duration: 200
            easing.type: Easing.InOutQuad
        }
    }

    // Перетаскивание окна за пустой фон сайдбара
    MouseArea {
        anchors.fill: parent
        z: 0
        onPressed: Window.window.startSystemMove()
        onDoubleClicked: sideBar.toggleMaximizeClicked()
    }

    // =========================================================================
    // ПЕРЕИСПОЛЬЗУЕМАЯ КНОПКА САЙДБАРА
    // =========================================================================
    component SidebarButton: Button {
        id: btn
        property string iconText: ""
        property string titleText: ""

        width: parent ? parent.width : sideBar.width
        height: sideBar.barSize
        padding: 0

        background: Rectangle {
            color: btn.down ? "#333333" : (btn.hovered ? "#2a2a2a" : "transparent")
        }

        contentItem: Row {
            spacing: 6

            // Иконка строго 36x36
            Text {
                width: sideBar.barSize
                height: sideBar.barSize
                text: btn.iconText
                color: btn.down ? "#aaaaaa" : (btn.hovered ? "#ffffff" : "#cccccc")
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 14
            }

            // Текст кнопки
            Text {
                visible: sideBar.expanded
                height: sideBar.barSize
                text: btn.titleText
                color: btn.down ? "#aaaaaa" : (btn.hovered ? "#ffffff" : "#dddddd")
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                font.pixelSize: 13
            }
        }

        ToolTip.visible: hovered && !sideBar.expanded
        ToolTip.text: titleText
    }

    // =========================================================================
    // ГЛАВНАЯ РАСКЛАДКА САЙДБАРА
    // =========================================================================
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        z: 1

        // 1. ВЕРХНЯЯ КНОПКА: Новый документ
        SidebarButton {
            Layout.fillWidth: true
            iconText: "➕"
            titleText: "Новый документ"
            onClicked: sideBar.newClicked()
        }

        // 2. СПИСОК ВКЛАДОК (Занимает все свободное место)
        ScrollView {
            id: tabsScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth

            ListView {
                id: tabsListView
                width: tabsScroll.availableWidth
                model: sideBar.tabsModel
                spacing: 1
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: tabItem
                    width: tabsListView.width
                    height: sideBar.barSize
                    
                    readonly property bool isActive: index === sideBar.currentTabIndex
                    readonly property bool isBackgroundOpen: sideBar.isSplit && (index === sideBar.backgroundTabIndex)
                    property bool isEditing: false

                    color: isActive ? "#2c2c2c" : (isBackgroundOpen ? "#1e1e1e" : (tabHover.hovered ? "#262626" : "transparent"))
                    opacity: tabHover.isDraggingTab ? 0.45 : 1.0

                    // Полоска акцента слева (яркая для активной, блекло-серая для фоновой)
                    Rectangle {
                        width: 3
                        height: parent.height
                        color: tabItem.isActive ? "#ffffff" : "#666666"
                        visible: tabItem.isActive || tabItem.isBackgroundOpen
                    }

                    // ЛКМ — выбор, ПКМ — закрыть, Зажатие ЛКМ и перетаскивание — оторвать/вернуть окно
                    MouseArea {
                        id: tabHover
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        visible: !tabItem.isEditing
                        preventStealing: true

                        property real pressX: 0
                        property real pressY: 0
                        property bool isLeftPressed: false
                        property bool isDraggingTab: false
                        property bool wasDragged: false

                        onPressed: (mouse) => {
                            if (mouse.button === Qt.LeftButton) {
                                pressX = mouse.x
                                pressY = mouse.y
                                isLeftPressed = true
                                isDraggingTab = false
                                wasDragged = false
                            } else {
                                isLeftPressed = false
                            }
                        }

                        onPositionChanged: (mouse) => {
                            if (!isLeftPressed) return

                            let deltaX = mouse.x - pressX
                            let deltaY = mouse.y - pressY
                            let dist = Math.sqrt(deltaX * deltaX + deltaY * deltaY)
                            let globalPoint = tabHover.mapToGlobal(mouse.x, mouse.y)

                            if (!isDraggingTab) {
                                // Порог начала перетаскивания: 15px
                                if (dist > 15) {
                                    isDraggingTab = true
                                    wasDragged = true
                                    sideBar.tabDragStarted(index, globalPoint.x, globalPoint.y)
                                }
                            } else {
                                sideBar.tabDragMoved(index, globalPoint.x, globalPoint.y)
                            }
                        }

                        onReleased: (mouse) => {
                            if (mouse.button === Qt.LeftButton) {
                                isLeftPressed = false
                                if (isDraggingTab) {
                                    isDraggingTab = false
                                    let globalPoint = tabHover.mapToGlobal(mouse.x, mouse.y)
                                    sideBar.tabDragEnded(index, globalPoint.x, globalPoint.y)
                                }
                            }
                        }

                        onCanceled: {
                            if (typeof backend !== "undefined" && backend && typeof backend.get_cursor_state === "function") {
                                let state = backend.get_cursor_state()
                                if (state.leftPressed) {
                                    return
                                }
                            }
                            isLeftPressed = false
                            if (isDraggingTab) {
                                isDraggingTab = false
                                let globalPoint = tabHover.mapToGlobal(0, 0)
                                sideBar.tabDragEnded(index, globalPoint.x, globalPoint.y)
                            }
                        }

                        onClicked: (mouse) => {
                            if (mouse.button === Qt.LeftButton) {
                                if (!wasDragged) {
                                    sideBar.tabSelected(index)
                                }
                            } else if (mouse.button === Qt.RightButton) {
                                // ПКМ СТРОГО закрывает вкладку!
                                sideBar.tabClosed(index)
                            }
                        }

                        onDoubleClicked: (mouse) => {
                            if (mouse.button === Qt.LeftButton && sideBar.expanded && !wasDragged) {
                                tabItem.isEditing = true
                                renameInput.isCancelled = false
                                renameInput.text = model.title
                                renameInput.forceActiveFocus()
                                renameInput.selectAll()
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        // Номер вкладки (1, 2, 3...) вместо иконки
                        Text {
                            Layout.preferredWidth: sideBar.barSize
                            Layout.fillHeight: true
                            text: (index + 1).toString()
                            color: tabItem.isActive ? "#ffffff" : (tabItem.isBackgroundOpen ? "#888888" : "#555555")
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.family: "Consolas, 'Cascadia Code', monospace"
                            font.pixelSize: 13
                            font.bold: tabItem.isActive
                        }

                        // Имя файла вкладки (в обычном режиме, при пустом имени показывает плейсхолдер)
                        Text {
                            visible: sideBar.expanded && !tabItem.isEditing
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.rightMargin: 12
                            text: (typeof model !== "undefined" && model && model.title !== undefined && model.title !== "") ? model.title : "Без названия"
                            color: (typeof model !== "undefined" && model && model.title === "") ? "#555555" : (tabItem.isActive ? "#ffffff" : (tabItem.isBackgroundOpen ? "#aaaaaa" : "#666666"))
                            font.italic: typeof model !== "undefined" && model && model.title === ""
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            font.pixelSize: 13
                        }

                        // Поле ввода для переименования (появляется по двойному клику)
                        TextField {
                            id: renameInput
                            visible: sideBar.expanded && tabItem.isEditing
                            Layout.fillWidth: true
                            Layout.preferredHeight: 26
                            Layout.rightMargin: 12
                            font.pixelSize: 12
                            color: "#ffffff"
                            selectByMouse: true
                            placeholderText: "Без названия"
                            placeholderTextColor: "#555555"

                            property bool isCancelled: false

                            background: Rectangle {
                                color: "#1a1a1a"
                                border.color: "#ffffff"
                                radius: 2
                            }

                            // Нажатие Escape отменяет изменение
                            Keys.onEscapePressed: {
                                isCancelled = true
                                tabItem.isEditing = false
                            }

                            onAccepted: {
                                if (!isCancelled) {
                                    tabItem.isEditing = false
                                    sideBar.tabRenamed(index, text)
                                }
                                isCancelled = false
                            }

                            onActiveFocusChanged: {
                                if (!activeFocus && tabItem.isEditing) {
                                    tabItem.isEditing = false
                                    if (!isCancelled) {
                                        sideBar.tabRenamed(index, text)
                                    }
                                    isCancelled = false
                                }
                            }
                        }
                    }

                    ToolTip.visible: Boolean(tabHover && tabHover.hovered && !sideBar.expanded)
                    ToolTip.text: (typeof model !== "undefined" && model && model.title === "") ? `${index + 1}. Без названия` : `${index + 1}. ${model ? model.title : ""}`
                }
            }
        }

        // 3. ФУТЕР (Кнопка настроек и кнопка сворачивания)
        SidebarButton {
            id: settingsBtn
            Layout.fillWidth: true
            iconText: "⚙️"
            titleText: "Настройки"
            onClicked: settingsMenu.popup(settingsBtn, settingsBtn.width, 0)
        }

        SidebarButton {
            Layout.fillWidth: true
            iconText: sideBar.expanded ? "◀" : "▶"
            titleText: "Свернуть"
            onClicked: {
                if (sideBar.expanded) {
                    sideBar.currentWidth = sideBar.barSize
                } else {
                    sideBar.currentWidth = 180
                }
            }
        }
    }

    // =========================================================================
    // ВСплывающее МЕНЮ НАСТРОЕК (⚙️)
    // =========================================================================
    Menu {
        id: settingsMenu

        MenuItem {
            text: "📂  Открыть файл...  (Ctrl+O)"
            onTriggered: sideBar.openClicked()
        }

        MenuItem {
            text: "💾  Сохранить  (Ctrl+S)"
            onTriggered: sideBar.saveClicked()
        }

        MenuSeparator {}

        MenuItem {
            text: Window.window?.visibility === Window.Maximized ? "❐  Восстановить окно" : "🗖  Развернуть окно"
            onTriggered: sideBar.toggleMaximizeClicked()
        }

        MenuItem {
            text: "✕  Закрыть приложение"
            onTriggered: sideBar.closeClicked()
        }
    }

    // =========================================================================
    // НЕВИДИМАЯ ЗОНА ИЗМЕНЕНИЯ РАЗМЕРА НА ПРАВОЙ ГРАНИЦЕ
    // =========================================================================
    MouseArea {
        id: dragArea
        width: 8
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.rightMargin: -4
        z: 100
        hoverEnabled: true
        cursorShape: Qt.SizeHorCursor

        onPressed: {
            sideBar.isDragging = true
        }

        onPositionChanged: (mouse) => {
            if (pressed) {
                let pos = dragArea.mapToItem(sideBar, mouse.x, 0)
                let newWidth = Math.round(pos.x)

                if (newWidth < 70) {
                    sideBar.currentWidth = sideBar.barSize
                } else {
                    sideBar.currentWidth = Math.min(400, Math.max(80, newWidth))
                }
            }
        }

        onReleased: {
            sideBar.isDragging = false
        }

        onCanceled: {
            sideBar.isDragging = false
        }

        onDoubleClicked: {
            if (sideBar.expanded) {
                sideBar.currentWidth = sideBar.barSize
            } else {
                sideBar.currentWidth = 180
            }
        }
    }
}
