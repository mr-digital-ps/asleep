import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "logic.js" as Logic
import "tabs.js" as Tabs

Rectangle {
    id: root
    anchors.fill: parent
    color: "#141414"

    // Переменные текущего активного файла
    property string currentFileUrl: ""
    property string currentFileName: "Новый документ"
    property int barSize: 36

    // =========================================================================
    // РЕЖИМ СПЛИТА (SPLIT VIEW)
    // =========================================================================
    property bool isSplit: false
    property int primaryTabIndex: 0
    property int secondaryTabIndex: -1
    property int activePane: 0 // 0: primary, 1: secondary
    property string dropZone: "" // "left" | "right" | "center" | "sidebar" | ""
    property string primaryFileName: "Новый документ"
    property string secondaryFileName: "Новый документ"

    property alias editorArea: splitLayout.activeEditorArea
    property alias splitLayout: splitLayout

    // =========================================================================
    // МОДЕЛЬ ВКЛАДОК И ОТКРЕПЛЕННЫХ ОКОН
    // =========================================================================
    property int currentTabIndex: 0
    property var detachedWindows: ({})

    // Состояние интерактивного перетаскивания вкладки в отдельное окно
    property var activeDraggingWindow: null
    property int activeDraggingIndex: -1
    property bool isNewlyCreatedForDrag: false

    property alias tabsModel: tabsModel
    property alias detachedWinComponent: detachedWinComponent
    property alias dragTrackerTimer: dragTrackerTimer
    property alias sideBar: sideBar

    ListModel {
        id: tabsModel
        ListElement {
            title: "Новый документ"
            fileUrl: ""
            content: ""
            isDetached: false
        }
    }

    // Компонент плавающего окна для открепленного документа
    Component {
        id: detachedWinComponent
        DetachedWindow {
            onReattachRequested: (index, content, title) => Tabs.reattachTab(root, index, content, title, true)
            onDropRequested: (index, gx, gy, content, title) => Tabs.handleDetachedWindowDrop(root, index, gx, gy, content, title)
            onDragMoved: (index, gx, gy) => Tabs.handleWindowDragMoved(root, index, gx, gy)
            onDragEnded: () => Tabs.handleWindowDragEnded(root)
            onTextChanged: (index, content) => Tabs.updateDetachedContent(root, index, content)
            onTitleChanged: (index, title) => Tabs.updateDetachedTitle(root, index, title)
        }
    }

    // Таймер отслеживания курсора во время перетаскивания (60 FPS)
    Timer {
        id: dragTrackerTimer
        interval: 16
        repeat: true
        running: false
        onTriggered: Tabs.pollCursorState(root, sideBar)
    }

    // Делегированные методы управления вкладками и сплитом
    function createNewTab() { Tabs.createNewTab(root) }
    function switchToTab(index) { Tabs.switchToTab(root, index) }
    function closeTab(index) { Tabs.closeTab(root, index) }
    function renameTab(index, newTitle) { Tabs.renameTab(root, index, newTitle) }
    function detachTab(index, spawnX, spawnY) { Tabs.detachTab(root, index, spawnX, spawnY) }
    function reattachTab(index, content, title) { Tabs.reattachTab(root, index, content, title) }
    function toggleSplit() { Tabs.toggleSplit(root) }
    function closeSplit() { Tabs.closeSplit(root) }
    function handleTabDragStarted(index, gx, gy) { Tabs.handleDragStarted(root, index, gx, gy) }
    function handleTabDragMoved(index, gx, gy) { Tabs.handleDragMoved(root, index, gx, gy, sideBar) }
    function handleTabDragEnded(index, gx, gy) { Tabs.handleDragEnded(root, index, gx, gy) }

    // =========================================================================
    // ДИАЛОГИ И ШОРТКАТЫ
    // =========================================================================
    FileDialog {
        id: openDialog
        title: "Открыть файл"
        fileMode: FileDialog.OpenFile
        onAccepted: {
            let content = backend.read_file(selectedFile)
            let name = backend.get_filename(selectedFile)

            let targetIndex = (root.isSplit && root.activePane === 1) ? root.secondaryTabIndex : root.primaryTabIndex
            let curTab = (targetIndex >= 0 && targetIndex < tabsModel.count) ? tabsModel.get(targetIndex) : null

            if (curTab && !curTab.isDetached && curTab.fileUrl === "" && root.editorArea.text === "") {
                tabsModel.setProperty(targetIndex, "title", name)
                tabsModel.setProperty(targetIndex, "fileUrl", selectedFile)
                tabsModel.setProperty(targetIndex, "content", content)
                Tabs.syncEditorsFromModel(root)
            } else {
                tabsModel.append({
                    title: name,
                    fileUrl: selectedFile,
                    content: content,
                    isDetached: false
                })
                root.switchToTab(tabsModel.count - 1)
            }
        }
    }

    FileDialog {
        id: saveDialog
        title: "Сохранить файл как..."
        fileMode: FileDialog.SaveFile
        onAccepted: {
            let targetIndex = (root.isSplit && root.activePane === 1) ? root.secondaryTabIndex : root.primaryTabIndex
            backend.save_file(selectedFile, root.editorArea.text)
            currentFileUrl = selectedFile
            currentFileName = backend.get_filename(selectedFile)
            if (tabsModel.count > 0 && targetIndex >= 0 && targetIndex < tabsModel.count) {
                tabsModel.setProperty(targetIndex, "title", currentFileName)
                tabsModel.setProperty(targetIndex, "fileUrl", currentFileUrl)
                tabsModel.setProperty(targetIndex, "content", root.editorArea.text)
                Tabs.syncEditorsFromModel(root)
            }
        }
    }

    Shortcut {
        sequences: [StandardKey.Save]
        onActivated: Logic.saveFile(root, saveDialog, backend)
    }

    Shortcut {
        sequences: [StandardKey.Open]
        onActivated: openDialog.open()
    }

    Shortcut {
        sequences: [StandardKey.New]
        onActivated: root.createNewTab()
    }

    Shortcut {
        sequence: "Ctrl+\\"
        onActivated: root.toggleSplit()
    }

    // =========================================================================
    // РАСКЛАДКА ОКНА
    // =========================================================================
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // 1. Сайдбар со списком вкладок и кнопкой настроек внизу
        Sidebar {
            id: sideBar
            barSize: root.barSize
            tabsModel: tabsModel
            currentTabIndex: root.currentTabIndex
            isSplit: root.isSplit
            backgroundTabIndex: root.isSplit ? (root.activePane === 0 ? root.secondaryTabIndex : root.primaryTabIndex) : -1

            onNewClicked: root.createNewTab()
            onTabSelected: (index) => root.switchToTab(index)
            onTabClosed: (index) => root.closeTab(index)
            onTabRenamed: (index, newTitle) => root.renameTab(index, newTitle)
            onTabDragStarted: (index, gx, gy) => root.handleTabDragStarted(index, gx, gy)
            onTabDragMoved: (index, gx, gy) => root.handleTabDragMoved(index, gx, gy)
            onTabDragEnded: (index, gx, gy) => root.handleTabDragEnded(index, gx, gy)

            onOpenClicked: openDialog.open()
            onSaveClicked: Logic.saveFile(root, saveDialog, backend)
            onCloseClicked: Window.window.close()
            onToggleMaximizeClicked: Logic.toggleMaximize(Window.window)
        }

        // 2. Главная область: Холст с поддержкой разделения экрана (Split View)
        EditorSplitLayout {
            id: splitLayout
            Layout.fillWidth: true
            Layout.fillHeight: true
            barSize: root.barSize
            isSplit: root.isSplit
            activePane: root.activePane
            dropZone: root.dropZone
            primaryFileName: root.primaryFileName
            secondaryFileName: root.secondaryFileName

            onPrimaryTitleChanged: (newTitle) => Tabs.renameTab(root, root.primaryTabIndex, newTitle)
            onSecondaryTitleChanged: (newTitle) => Tabs.renameTab(root, root.secondaryTabIndex, newTitle)
            onPrimaryTextChanged: (text) => Tabs.handlePrimaryTextChanged(root, text)
            onSecondaryTextChanged: (text) => Tabs.handleSecondaryTextChanged(root, text)
            onCloseSplitRequested: () => Tabs.closeSplit(root)
            onPaneActivated: (paneIndex) => Tabs.setActivePane(root, paneIndex)
        }
    }
}