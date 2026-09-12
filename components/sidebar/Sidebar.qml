import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: sideBar

    // Свойства сайдбара
    property var appWindow: null
    property int barSize: 36
    property real currentWidth: 180
    property bool isSidebarVisible: true
    property bool isDragging: false
    readonly property bool expanded: currentWidth > (barSize + 10)

    // Модели и текущие состояния файлов
    property var tabsModel: null
    property var filesModel: null
    property int currentTabIndex: 0
    property string currentFolderUrl: ""
    property string currentFolderName: ""
    property string currentFileUrl: ""
    property bool isSplit: false
    property int backgroundTabIndex: -1
    property string backgroundFileUrl: ""
    property var externalWindowFiles: []

    // Сигналы событий сайдбара
    signal newClicked()
    signal folderClicked()
    signal configClicked()
    signal graphClicked()
    signal openClicked()
    signal saveClicked()
    signal closeClicked()
    signal toggleMaximizeClicked()
    signal fileSelected(string fileUrl, string fileName, bool isShift)
    signal fileRenameRequested(string fileUrl, string newName)
    signal fileDeleteRequested(string fileUrl)
    signal openInNewWindowRequested(string fileUrl, string fileName)
    signal tabDragStarted(string fileUrl, string fileName, real gx, real gy)
    signal tabDragMoved(real gx, real gy)
    signal tabDragEnded(string fileUrl, string fileName, real gx, real gy)

    function toggleSidebar() {
        if (!isSidebarVisible) {
            isSidebarVisible = true
            currentWidth = 180
        } else {
            isSidebarVisible = false
            currentWidth = 0
        }
    }

    Layout.preferredWidth: isSidebarVisible ? currentWidth : 0
    Layout.fillHeight: true
    clip: true
    color: (themeConfig && themeConfig.bg_sidebar) ? themeConfig.bg_sidebar : "#181818"

    property var themeConfig: ({})

    function loadTheme() {
        if (typeof backend !== "undefined" && backend && typeof backend.get_theme_config === "function") {
            try {
                let tc = backend.get_theme_config()
                if (tc) {
                    sideBar.themeConfig = tc
                    if (typeof tc.sidebar_width === "number" && tc.sidebar_width >= 36 && !sideBar.isDragging) {
                        sideBar.currentWidth = tc.sidebar_width
                    }
                }
            } catch(e) {}
        }
    }

    Connections {
        target: (typeof backend !== "undefined") ? backend : null
        function onThemeConfigChanged() {
            sideBar.loadTheme()
        }
    }

    Component.onCompleted: {
        loadTheme()
        if (typeof backend !== "undefined" && backend && typeof backend.get_session_config === "function") {
            try {
                let sess = backend.get_session_config()
                if (sess && typeof sess.sidebar_width === "number" && sess.sidebar_width >= 36) {
                    sideBar.currentWidth = sess.sidebar_width
                }
            } catch(e) {}
        }
    }

    Behavior on currentWidth {
        enabled: !sideBar.isDragging
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    // Компонент переиспользуемой кнопки сайдбара
    component SidebarButton: Button {
        id: btn
        property string iconText: ""
        property string titleText: ""

        Layout.fillWidth: true
        Layout.preferredHeight: sideBar.barSize
        padding: 0
        hoverEnabled: true

        background: Rectangle {
            color: btn.down ? "#222222" : (btn.hovered ? "#222222" : "transparent")
            border.color: btn.hovered ? "#2e2e2e" : "transparent"
            border.width: 1
        }

        contentItem: Row {
            spacing: 6

            Text {
                width: sideBar.barSize
                height: sideBar.barSize
                text: btn.iconText
                color: btn.down ? "#aaaaaa" : (btn.hovered ? "#ffffff" : "#cccccc")
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 14
            }

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

    MouseArea {
        anchors.fill: parent
        z: 0
        acceptedButtons: Qt.LeftButton
        onPressed: (mouse) => {
            if (mouse.button === Qt.LeftButton && sideBar.appWindow) {
                sideBar.appWindow.startSystemMove()
            }
        }
        onDoubleClicked: sideBar.toggleMaximizeClicked()
    }

    // Главная колонка сайдбара
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        z: 1

        // 0. Шапка рабочей папки
        SidebarHeader {
            appWindow: sideBar.appWindow
            barSize: sideBar.barSize
            expanded: sideBar.expanded
            currentFolderUrl: sideBar.currentFolderUrl
            currentFolderName: sideBar.currentFolderName
            onFolderClicked: sideBar.folderClicked()
            onConfigClicked: sideBar.configClicked()
            onGraphClicked: sideBar.graphClicked()
        }

        // 1. Кнопка «Новый документ»
        SidebarButton {
            Layout.fillWidth: true
            iconText: "➕"
            titleText: "Новый документ"
            onClicked: sideBar.newClicked()
        }

        // 2. Список файлов папки
        SidebarFileList {
            id: fileListComp
            appWindow: sideBar.appWindow
            Layout.fillWidth: true
            Layout.fillHeight: true
            filesModel: sideBar.filesModel
            barSize: sideBar.barSize
            expanded: sideBar.expanded
            currentFileUrl: sideBar.currentFileUrl
            backgroundFileUrl: sideBar.backgroundFileUrl
            isSplit: sideBar.isSplit
            tabsModel: sideBar.tabsModel
            externalWindowFiles: sideBar.externalWindowFiles

            onFileSelected: (url, name, isShift) => sideBar.fileSelected(url, name, isShift)
            onFileRenameRequested: (url, newName) => sideBar.fileRenameRequested(url, newName)
            onOpenInNewWindowRequested: (url, name) => sideBar.openInNewWindowRequested(url, name)
            onFileDeleteRequested: (url) => sideBar.fileDeleteRequested(url)
            onToggleMaximizeClicked: sideBar.toggleMaximizeClicked()
            onFileDragStarted: (url, name, gx, gy) => sideBar.tabDragStarted(url, name, gx, gy)
            onFileDragMoved: (gx, gy) => sideBar.tabDragMoved(gx, gy)
            onFileDragEnded: (url, name, gx, gy) => sideBar.tabDragEnded(url, name, gx, gy)
        }

        // 3. Футер: Настройки и сворачивание
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

    // Всплывающее меню настроек
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

    // 1px правая разделительная рамка сайдбара с плавной микро-подсветкой
    Rectangle {
        width: 1
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        color: sideBar.isDragging ? "#555555" : (dragArea.containsMouse ? "#3c3c3c" : "#242424")
        z: 90

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    // Зона изменения ширины сайдбара на правой границе
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

        onPressed: sideBar.isDragging = true
        onPositionChanged: (mouse) => {
            if (pressed) {
                let targetContainer = sideBar.parent ? sideBar.parent : sideBar
                let pos = dragArea.mapToItem(targetContainer, mouse.x, 0)
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
            if (typeof backend !== "undefined" && backend && typeof backend.save_sidebar_width === "function") {
                backend.save_sidebar_width(sideBar.currentWidth)
            }
        }
        onCanceled: sideBar.isDragging = false
        onDoubleClicked: {
            if (sideBar.expanded) {
                sideBar.currentWidth = sideBar.barSize
            } else {
                sideBar.currentWidth = 180
            }
            if (typeof backend !== "undefined" && backend && typeof backend.save_sidebar_width === "function") {
                backend.save_sidebar_width(sideBar.currentWidth)
            }
        }
    }
}
