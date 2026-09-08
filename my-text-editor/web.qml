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
    property alias editorArea: mainBar.editorArea
    property int barSize: 36

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

    // Делегированные методы управления вкладками (реализованы в tabs.js)
    function createNewTab() { Tabs.createNewTab(root) }
    function switchToTab(index) { Tabs.switchToTab(root, index) }
    function closeTab(index) { Tabs.closeTab(root, index) }
    function renameTab(index, newTitle) { Tabs.renameTab(root, index, newTitle) }
    function detachTab(index, spawnX, spawnY) { Tabs.detachTab(root, index, spawnX, spawnY) }
    function reattachTab(index, content, title) { Tabs.reattachTab(root, index, content, title) }
    function handleTabDragStarted(index, gx, gy) { Tabs.handleDragStarted(root, index, gx, gy) }
    function handleTabDragMoved(index, gx, gy) { Tabs.handleDragMoved(root, index, gx, gy, sideBar) }
    function handleTabDragEnded(index, gx, gy) { Tabs.handleDragEnded(root, index, gx, gy) }

    // Сохранение в реальном времени при вводе текста в главном окне
    Connections {
        target: editorArea
        function onTextChanged() {
            if (tabsModel.count > 0 && currentTabIndex < tabsModel.count && !tabsModel.get(currentTabIndex).isDetached) {
                tabsModel.setProperty(currentTabIndex, "content", editorArea.text)
            }
        }
    }

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

            // Если текущая вкладка пустая — открываем в ней
            let curTab = tabsModel.get(currentTabIndex)
            if (curTab && !curTab.isDetached && curTab.fileUrl === "" && editorArea.text === "") {
                tabsModel.setProperty(currentTabIndex, "title", name)
                tabsModel.setProperty(currentTabIndex, "fileUrl", selectedFile)
                tabsModel.setProperty(currentTabIndex, "content", content)
                currentFileName = name
                currentFileUrl = selectedFile
                editorArea.text = content
            } else {
                // Иначе создаем новую вкладку с открытым файлом
                tabsModel.append({
                    title: name,
                    fileUrl: selectedFile,
                    content: content,
                    isDetached: false
                })
                switchToTab(tabsModel.count - 1)
            }
        }
    }

    FileDialog {
        id: saveDialog
        title: "Сохранить файл как..."
        fileMode: FileDialog.SaveFile
        onAccepted: {
            backend.save_file(selectedFile, editorArea.text)
            currentFileUrl = selectedFile
            currentFileName = backend.get_filename(selectedFile)
            if (tabsModel.count > 0 && currentTabIndex < tabsModel.count) {
                tabsModel.setProperty(currentTabIndex, "title", currentFileName)
                tabsModel.setProperty(currentTabIndex, "fileUrl", currentFileUrl)
                tabsModel.setProperty(currentTabIndex, "content", editorArea.text)
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

        // 2. Главная область: Холст с листом документа
        MainBar {
            id: mainBar
            Layout.fillWidth: true
            Layout.fillHeight: true
            barSize: root.barSize
            fileName: root.currentFileName
            onTitleChangedByUser: (newTitle) => root.renameTab(root.currentTabIndex, newTitle)
        }
    }
}