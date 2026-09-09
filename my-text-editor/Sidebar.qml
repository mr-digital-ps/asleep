import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: sideBar

    // Размеры и видимость
    property int barSize: 36
    property int currentWidth: 280
    property int savedWidth: 280
    property bool isSidebarVisible: true
    property bool isDragging: false
    readonly property bool expanded: isSidebarVisible && (currentWidth > barSize)

    // Модель вкладок, файлов и активный индекс
    property var tabsModel: null
    property var filesModel: null
    property string currentFileUrl: ""
    property int currentTabIndex: 0
    property bool isSplit: false
    property int backgroundTabIndex: -1
    property string backgroundFileUrl: ""
    property var externalWindowFiles: []

    // Текущая рабочая папка
    property string currentFolderUrl: ""
    property string currentFolderName: "my-text-editor"

    // Сигналы для файлов и папки
    signal newClicked()
    signal folderClicked()
    signal fileSelected(string fileUrl, string fileName)
    signal openInNewWindowRequested(string fileUrl, string fileName)
    signal fileDeleteRequested(string fileUrl)
    signal fileRenameRequested(string fileUrl, string newName)

    // Сигналы для вкладок
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

    function toggleSidebar() {
        if (isSidebarVisible) {
            savedWidth = currentWidth > 0 ? currentWidth : 280
            isSidebarVisible = false
        } else {
            isSidebarVisible = true
            currentWidth = savedWidth > 0 ? savedWidth : 280
        }
    }

    Layout.fillHeight: true
    Layout.preferredWidth: isSidebarVisible ? currentWidth : 0
    visible: isSidebarVisible || (Layout.preferredWidth > 0)
    clip: true
    color: "#181818"

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
            color: btn.down ? "#282828" : (btn.hovered ? "#222222" : "transparent")
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

        // 0. ВЕРХНЯЯ ПЛАШКА: Текущая рабочая папка
        Button {
            id: folderBtn
            Layout.fillWidth: true
            Layout.preferredHeight: sideBar.barSize
            padding: 0
            hoverEnabled: true

            background: Rectangle {
                color: folderBtn.down ? "#222222" : (folderBtn.hovered ? "#222222" : "#181818")
                border.color: folderBtn.hovered ? "#2e2e2e" : "transparent"
                border.width: 1
            }

            contentItem: RowLayout {
                anchors.fill: parent
                spacing: 0

                // Иконка папки строго по центру в узком сайдбаре
                Text {
                    Layout.preferredWidth: sideBar.barSize
                    Layout.fillHeight: true
                    text: "📁"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                // Название текущей папки
                Text {
                    visible: sideBar.expanded
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: sideBar.currentFolderName || "Выбрать папку"
                    color: folderBtn.hovered ? "#ffffff" : "#e0e0e0"
                    font.pixelSize: 12
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                // Индикатор смены
                Text {
                    visible: sideBar.expanded
                    Layout.preferredWidth: 20
                    Layout.fillHeight: true
                    Layout.rightMargin: 6
                    text: "▾"
                    color: folderBtn.hovered ? "#cccccc" : "#777777"
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            onClicked: sideBar.folderClicked()

            ToolTip.visible: hovered
            ToolTip.text: sideBar.currentFolderUrl ? `Рабочая папка: ${decodeURIComponent(sideBar.currentFolderUrl).replace("file:///", "")}\n(Нажмите для смены)` : "Нажмите для выбора рабочей папки"
        }

        // 1. КНОПКА: Новый документ
        SidebarButton {
            Layout.fillWidth: true
            iconText: "➕"
            titleText: "Новый документ"
            onClicked: sideBar.newClicked()
        }

        // 2. СПИСОК ФАЙЛОВ ПАПКИ
        ScrollView {
            id: filesScroll
            Layout.fillWidth: true
            Layout.fillHeight: filesListView.contentHeight > (sideBar.height - 180)
            Layout.preferredHeight: Math.min(filesListView.contentHeight, Math.max(0, sideBar.height - 180))
            clip: true
            contentWidth: availableWidth

            ListView {
                id: filesListView
                width: filesScroll.availableWidth
                model: sideBar.filesModel
                spacing: 1
                boundsBehavior: Flickable.StopAtBounds

                // Фоновое перемещение окна внутри ListView на свободном месте
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onPressed: Window.window.startSystemMove()
                    onDoubleClicked: sideBar.toggleMaximizeClicked()
                }

                delegate: Rectangle {
                    id: fileItem
                    width: filesListView.width
                    height: sideBar.barSize

                    readonly property bool isActive: (typeof model !== "undefined" && model && model.fileUrl && sideBar.currentFileUrl) ? (model.fileUrl === sideBar.currentFileUrl) : false
                    readonly property bool isBackgroundOpen: {
                        if (typeof model === "undefined" || !model || !model.fileUrl) return false
                        if (fileItem.isActive) return false

                        // 1. Файл открыт во второй панели сплита (в том же окне)
                        if (sideBar.isSplit && sideBar.backgroundFileUrl && model.fileUrl === sideBar.backgroundFileUrl) {
                            return true
                        }

                        // 2. Файл оторван в плавающее окно или вынесен на второй монитор
                        if (sideBar.tabsModel) {
                            for (let i = 0; i < sideBar.tabsModel.count; i++) {
                                let t = sideBar.tabsModel.get(i)
                                if (t && t.fileUrl === model.fileUrl && t.isDetached) {
                                    return true
                                }
                            }
                        }

                        // 3. Файл открыт в отдельном окне приложения (на втором мониторе)
                        if (sideBar.externalWindowFiles && sideBar.externalWindowFiles.indexOf(model.fileUrl) !== -1) {
                            return true
                        }

                        return false
                    }
                    property bool isEditing: false

                    color: isActive ? "#282828" : (isBackgroundOpen ? "#202020" : (fileHover.hovered ? "#242424" : "transparent"))
                    opacity: fileHover.isDraggingFile ? 0.45 : 1.0

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }

                    // Контекстное меню файла по ПКМ
                    Menu {
                        id: fileMenu
                        MenuItem {
                            text: "✏️  Переименовать"
                            onTriggered: {
                                if (sideBar.expanded) {
                                    fileItem.isEditing = true
                                    fileRenameInput.isCancelled = false
                                    fileRenameInput.text = model.name
                                    fileRenameInput.forceActiveFocus()
                                    fileRenameInput.selectAll()
                                }
                            }
                        }
                        MenuItem {
                            text: "🗖  Открыть в новом окне"
                            onTriggered: sideBar.openInNewWindowRequested(model.fileUrl, model.name)
                        }
                        MenuItem {
                            text: "🗑️  Удалить файл"
                            onTriggered: sideBar.fileDeleteRequested(model.fileUrl)
                        }
                    }

                    MouseArea {
                        id: fileHover
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        visible: !fileItem.isEditing
                        preventStealing: true

                        property real pressX: 0
                        property real pressY: 0
                        property bool isLeftPressed: false
                        property bool isDraggingFile: false
                        property bool wasDragged: false

                        onPressed: (mouse) => {
                            if (mouse.button === Qt.LeftButton) {
                                pressX = mouse.x
                                pressY = mouse.y
                                isLeftPressed = true
                                isDraggingFile = false
                                wasDragged = false
                            } else {
                                isLeftPressed = false
                            }
                        }

                        onPositionChanged: (mouse) => {
                            if (!isLeftPressed) return

                            let deltaX = mouse.x - pressX
                            let deltaY = mouse.y - pressY
                            let dist = Math.hypot(deltaX, deltaY)
                            let globalPoint = fileHover.mapToGlobal(mouse.x, mouse.y)

                            if (!isDraggingFile) {
                                if (dist > 15) {
                                    isDraggingFile = true
                                    wasDragged = true
                                    // Открываем файл и начинаем открепление
                                    sideBar.fileSelected(model.fileUrl, model.name)
                                    sideBar.tabDragStarted(sideBar.currentTabIndex, globalPoint.x, globalPoint.y)
                                }
                            } else {
                                sideBar.tabDragMoved(sideBar.currentTabIndex, globalPoint.x, globalPoint.y)
                            }
                        }

                        onReleased: (mouse) => {
                            if (mouse.button === Qt.LeftButton) {
                                isLeftPressed = false
                                if (isDraggingFile) {
                                    isDraggingFile = false
                                    let globalPoint = fileHover.mapToGlobal(mouse.x, mouse.y)
                                    sideBar.tabDragEnded(sideBar.currentTabIndex, globalPoint.x, globalPoint.y)
                                }
                            }
                        }

                        onClicked: (mouse) => {
                            if (mouse.button === Qt.LeftButton) {
                                if (!wasDragged) {
                                    sideBar.fileSelected(model.fileUrl, model.name)
                                }
                            } else if (mouse.button === Qt.RightButton) {
                                fileMenu.popup()
                            }
                        }

                        onDoubleClicked: (mouse) => {
                            if (mouse.button === Qt.LeftButton && sideBar.expanded && !wasDragged) {
                                fileItem.isEditing = true
                                fileRenameInput.isCancelled = false
                                fileRenameInput.text = model.name
                                fileRenameInput.forceActiveFocus()
                                fileRenameInput.selectAll()
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        // Порядковый номер файла (вместо эмодзи)
                        Text {
                            Layout.preferredWidth: sideBar.barSize
                            Layout.fillHeight: true
                            text: (index + 1 < 10 ? "0" : "") + (index + 1)
                            color: fileItem.isActive ? "#ffffff" : (fileItem.isBackgroundOpen ? "#888888" : "#444444")
                            Behavior on color { ColorAnimation { duration: 120 } }
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.family: "Consolas, Courier New, monospace"
                            font.bold: fileItem.isActive
                            font.pixelSize: 12
                        }

                        // Имя файла
                        Text {
                            visible: sideBar.expanded && !fileItem.isEditing
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.rightMargin: 12
                            text: (typeof model !== "undefined" && model && model.name) ? model.name : ""
                            color: fileItem.isActive ? "#ffffff" : (fileItem.isBackgroundOpen ? "#bbbbbb" : (fileHover.hovered ? "#dddddd" : "#777777"))
                            Behavior on color { ColorAnimation { duration: 120 } }
                            font.bold: fileItem.isActive
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            font.pixelSize: 13
                        }

                        // Поле ввода для переименования
                        TextField {
                            id: fileRenameInput
                            visible: sideBar.expanded && fileItem.isEditing
                            Layout.fillWidth: true
                            Layout.preferredHeight: 26
                            Layout.rightMargin: 12
                            font.pixelSize: 12
                            color: "#ffffff"
                            selectByMouse: true
                            property bool isCancelled: false

                            background: Rectangle {
                                color: "#1a1a1a"
                                border.color: "#ffffff"
                                radius: 2
                            }

                            Keys.onEscapePressed: {
                                isCancelled = true
                                fileItem.isEditing = false
                            }

                            onAccepted: {
                                if (!isCancelled && text.trim() !== "") {
                                    fileItem.isEditing = false
                                    sideBar.fileRenameRequested(model.fileUrl, text.trim())
                                }
                                isCancelled = false
                            }

                            onActiveFocusChanged: {
                                if (!activeFocus && fileItem.isEditing) {
                                    fileItem.isEditing = false
                                    if (!isCancelled && text.trim() !== "") {
                                        sideBar.fileRenameRequested(model.fileUrl, text.trim())
                                    }
                                    isCancelled = false
                                }
                            }
                        }
                    }

                    ToolTip.visible: Boolean(fileHover && fileHover.hovered && !sideBar.expanded)
                    ToolTip.text: (typeof model !== "undefined" && model && model.name) ? model.name : ""
                }
            }
        }

        // 3. ПУСТОЕ ПРОСТРАНСТВО САЙДБАРА (Растягивается на всё свободное место)
        // Клик в любом месте этой области перетаскивает окно приложения!
        Item {
            id: emptySpacer
            Layout.fillWidth: true
            Layout.fillHeight: true

            MouseArea {
                anchors.fill: parent
                onPressed: Window.window.startSystemMove()
                onDoubleClicked: sideBar.toggleMaximizeClicked()
            }
        }

        // 4. ФУТЕР (Кнопка настроек и кнопка сворачивания)
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

        MenuItem {
            text: "◫  Скрыть боковую панель  (Ctrl+B)"
            onTriggered: sideBar.toggleSidebar()
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
