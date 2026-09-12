import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQml
import "../components/sidebar"
import "../components/editor"
import "../components/dialogs"
import "../components/hotkeys"
import "../js/logic.js" as Logic
import "../js/tabs.js" as Tabs
import "../js/drag_manager.js" as DragMgr
import "../js/markdown_shortcuts.js" as Markdown
import "../js/web_lifecycle.js" as WebLifecycle

Rectangle {
    id: root
    anchors.fill: parent
    color: "#141414"

    // Ссылка на родительское ApplicationWindow
    property var appWindow: null

    // Видимость интерактивного графа связей
    property bool isGraphVisible: false

    // Переменные текущего активного файла
    property string currentFileUrl: ""
    property string currentFileName: "Новый документ"
    property int barSize: 36

    // Видимость боковой панели (сайдбара)
    property bool isSidebarVisible: true

    // Параметры для клонирования окна
    property string initialFileUrl: ""
    property string initialTitle: ""
    property string initialContent: ""
    property bool startWithSidebarHidden: false

    // Текущая рабочая папка
    property string currentFolderUrl: (typeof backend !== "undefined" && backend) ? backend.get_default_folder() : ""
    property string currentFolderName: (typeof backend !== "undefined" && backend && currentFolderUrl) ? backend.get_folder_name(currentFolderUrl) : "my-text-editor"

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

    function stripExt(name) {
        if (!name) return ""
        return name.replace(/\.md$/i, "")
    }

    property alias editorArea: splitLayout.activeEditorArea
    property alias splitLayout: splitLayout

    // =========================================================================
    // МОДЕЛЬ ВКЛАДОК, ФАЙЛОВ ПАПКИ И ОТКРЕПЛЕННЫХ ОКОН
    // =========================================================================
    property int currentTabIndex: 0
    property var externalWindowFiles: []
    property bool isFileDragging: false
    property string draggingFileUrl: ""
    property string draggingFileName: ""
    property int draggingPaneIndex: -1
    property var draggedNewWin: null

    // Таймер аппаратного отслеживания курсора во время перетаскивания (60 FPS)
    Timer {
        id: dragTrackerTimer
        interval: 16
        repeat: true
        running: false
        onTriggered: DragMgr.pollCursorState(root, sideBar, Tabs)
    }

    // Авто-сохранение изменений в файле с задержкой 1 сек после ввода
    Timer {
        id: autoSaveTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (typeof backend === "undefined" || !backend) return
            if (root.primaryTabIndex >= 0 && root.primaryTabIndex < root.tabsModel.count) {
                let pTab = root.tabsModel.get(root.primaryTabIndex)
                if (pTab && pTab.fileUrl && splitLayout && splitLayout.primaryBar) {
                    backend.save_file(pTab.fileUrl, splitLayout.primaryBar.text)
                }
            }
            if (root.isSplit && root.secondaryTabIndex >= 0 && root.secondaryTabIndex < root.tabsModel.count) {
                let sTab = root.tabsModel.get(root.secondaryTabIndex)
                if (sTab && sTab.fileUrl && splitLayout && splitLayout.secondaryBar) {
                    backend.save_file(sTab.fileUrl, splitLayout.secondaryBar.text)
                }
            }
        }
    }

    property alias tabsModel: tabsModel
    property alias folderFilesModel: folderFilesModel
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

    // Модель файлов в текущей рабочей папке
    ListModel {
        id: folderFilesModel
    }

    function reloadFolderFiles() { WebLifecycle.reloadFolderFiles(root, backend) }
    function applyFolderConfig(configJson) { WebLifecycle.applyFolderConfig(root, splitLayout, configJson) }

    Connections {
        target: (typeof backend !== "undefined") ? backend : null
        function onFolderFilesChanged() { root.reloadFolderFiles() }
        function onBlockUpdated(headingNorm, content, sourceFileUrl) {
            WebLifecycle.handleBlockUpdated(root, splitLayout, Tabs, headingNorm, content, sourceFileUrl)
        }
        function onConfigUpdated(configJson) { root.applyFolderConfig(configJson) }
    }

    function openFileFromFolder(fileUrl, fileName, isShift) {
        Tabs.openFileFromFolder(root, fileUrl, fileName, isShift)
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
    function setActivePane(paneIndex) { Tabs.setActivePane(root, paneIndex) }
    function openInNewWindow(fileUrl, fileName, wx, wy) { Tabs.openInNewWindow(root, fileUrl, fileName, wx, wy) }
    function handleFileDragMoved(gx, gy) { DragMgr.handleFileDragMoved(root, gx, gy) }
    function handleFileDragEnded(fileUrl, fileName, gx, gy) { DragMgr.handleFileDragEnded(root, fileUrl, fileName, gx, gy, Tabs) }
    function dockExternalTab(fileUrl, fileName, content, zone) { DragMgr.dockFileInCurrentWindow(root, fileUrl, fileName, content, zone, Tabs) }

    // Переключение видимости боковой панели (сайдбара)
    function toggleSidebar() {
        sideBar.toggleSidebar()
        root.isSidebarVisible = sideBar.isSidebarVisible
    }

    // Делегирование управления окнами и клонированием в модуль WebLifecycle
    function spawnClonedAppWindow(fileUrl, title, content, wx, wy, ww, wh) {
        return WebLifecycle.spawnClonedAppWindow(root, fileUrl, title, content, wx, wy, ww, wh)
    }
    function registerExternalFile(fUrl, win) { WebLifecycle.registerExternalFile(root, fUrl, win) }
    function unregisterExternalFile(fUrl) { WebLifecycle.unregisterExternalFile(root, fUrl) }
    function applyInitialState() { return WebLifecycle.applyInitialState(root, Tabs) }

    // =========================================================================
    // ДИАЛОГИ ВЫБОРА И СОХРАНЕНИЯ ФАЙЛОВ И ПАПОК
    // =========================================================================
    EditorDialogs {
        id: editorDialogs
        currentFolderUrl: root.currentFolderUrl

        onFolderAccepted: (folderUrl) => {
            root.currentFolderUrl = folderUrl
            root.currentFolderName = backend.get_folder_name(root.currentFolderUrl)
            if (typeof backend !== "undefined" && backend) {
                backend.save_last_folder(root.currentFolderUrl)
                backend.watch_folder(root.currentFolderUrl)
            }
            root.reloadFolderFiles()
        }

        onFileOpenAccepted: (selectedFile) => {
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

        onFileSaveAccepted: (selectedFile) => {
            let targetIndex = (root.isSplit && root.activePane === 1) ? root.secondaryTabIndex : root.primaryTabIndex
            backend.save_file(selectedFile, root.editorArea.text)
            root.currentFileUrl = selectedFile
            root.currentFileName = backend.get_filename(selectedFile)
            if (tabsModel.count > 0 && targetIndex >= 0 && targetIndex < tabsModel.count) {
                tabsModel.setProperty(targetIndex, "title", root.currentFileName)
                tabsModel.setProperty(targetIndex, "fileUrl", root.currentFileUrl)
                tabsModel.setProperty(targetIndex, "content", root.editorArea.text)
                Tabs.syncEditorsFromModel(root)
            }
        }
    }

    property alias folderDialog: editorDialogs.folderDialog
    property alias openDialog: editorDialogs.openDialog
    property alias saveDialog: editorDialogs.saveDialog

    Component.onCompleted: {
        WebLifecycle.initializeWorkspace(root, backend, Tabs, openDialog, saveDialog)
    }

    // =========================================================================
    // МЕНЕДЖЕР ГОРЯЧИХ КЛАВИШ
    // =========================================================================
    HotkeyManager {
        id: hotkeyManager
        onActionTriggered: (action) => root.executeAction(action)
        onCloseActiveTabRequested: root.closeActiveTab()
    }

    property alias hotkeyMapping: hotkeyManager.hotkeyMapping
    property alias flatHotkeysList: hotkeyManager.flatHotkeysList
    function reloadHotkeys() { hotkeyManager.reloadHotkeys() }
    function isCloseKey(event) { return hotkeyManager.isCloseKey(event) }

    function executeAction(action) {
        WebLifecycle.dispatchAction(root, splitLayout, openDialog, saveDialog, backend, Markdown, Tabs, Logic, action)
    }

    function closeActiveTab() { WebLifecycle.closeActiveTab(root) }

    Keys.forwardTo: (splitLayout ? [splitLayout] : [])

    Keys.onPressed: (event) => {
        if (hotkeyManager.handleKeyEvent(event)) {
            return
        }
    }

    // =========================================================================
    // РАСКЛАДКА ОКНА
    // =========================================================================
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // 1. Сайдбар со списком файлов папки и кнопкой настроек внизу
        Sidebar {
            id: sideBar
            appWindow: root.appWindow
            barSize: root.barSize
            isSidebarVisible: root.isSidebarVisible
            tabsModel: tabsModel
            filesModel: folderFilesModel
            currentTabIndex: (root.isSplit && root.activePane === 1) ? root.secondaryTabIndex : root.primaryTabIndex
            currentFolderUrl: root.currentFolderUrl
            currentFolderName: root.currentFolderName
            currentFileUrl: {
                let idx = (root.isSplit && root.activePane === 1) ? root.secondaryTabIndex : root.primaryTabIndex
                if (idx >= 0 && idx < tabsModel.count) {
                    let tab = tabsModel.get(idx)
                    if (tab && tab.fileUrl) return tab.fileUrl
                }
                return root.currentFileUrl || ""
            }
            isSplit: root.isSplit
            backgroundTabIndex: root.isSplit ? (root.activePane === 0 ? root.secondaryTabIndex : root.primaryTabIndex) : -1
            backgroundFileUrl: {
                if (!root.isSplit) return ""
                let bgIdx = (root.activePane === 0 ? root.secondaryTabIndex : root.primaryTabIndex)
                if (bgIdx >= 0 && bgIdx < root.tabsModel.count) {
                    let tab = root.tabsModel.get(bgIdx)
                    return (tab && tab.fileUrl) ? tab.fileUrl : ""
                }
                return ""
            }
            externalWindowFiles: root.externalWindowFiles

            onFolderClicked: {
                if (typeof backend !== "undefined" && backend) {
                    let res = backend.choose_folder_dialog(root.currentFolderUrl)
                    if (res && res.success) {
                        root.currentFolderUrl = res.folderUrl
                        root.currentFolderName = res.folderName
                        openDialog.currentFolder = res.folderUrl
                        saveDialog.currentFolder = res.folderUrl
                        root.reloadFolderFiles()
                    }
                } else {
                    folderDialog.open()
                }
            }
            onConfigClicked: {
                if (typeof backend !== "undefined" && backend && typeof backend.open_or_create_folder_config === "function") {
                    let res = backend.open_or_create_folder_config(root.currentFolderUrl)
                    if (res && res.success && res.fileUrl) {
                        root.openFileFromFolder(res.fileUrl, res.fileName, false)
                    }
                }
            }
            onNewClicked: root.createNewTab()
            onFileSelected: (fUrl, fName, isShift) => root.openFileFromFolder(fUrl, fName, isShift)
            onOpenInNewWindowRequested: (fUrl, fName) => root.openInNewWindow(fUrl, fName)
            onFileDeleteRequested: (fUrl) => {
                for (let i = tabsModel.count - 1; i >= 0; i--) {
                    if (tabsModel.get(i).fileUrl === fUrl) {
                        root.closeTab(i)
                    }
                }
                backend.delete_file(fUrl)
            }
            onFileRenameRequested: (fUrl, newName) => {
                let res = backend.rename_file(fUrl, newName)
                if (res && res.success) {
                    for (let i = 0; i < tabsModel.count; i++) {
                        if (tabsModel.get(i).fileUrl === fUrl) {
                            tabsModel.setProperty(i, "fileUrl", res.fileUrl)
                            tabsModel.setProperty(i, "title", res.fileName)
                            if (i === root.primaryTabIndex) root.primaryFileName = res.fileName
                            if (i === root.secondaryTabIndex) root.secondaryFileName = res.fileName
                        }
                    }
                    if (root.currentFileUrl === fUrl) {
                        root.currentFileUrl = res.fileUrl
                        root.currentFileName = res.fileName
                    }
                }
            }
            onTabDragStarted: (url, name, gx, gy) => {
                root.isFileDragging = true
                root.draggingFileUrl = url
                root.draggingFileName = name
                root.draggingPaneIndex = -1
                dragTrackerTimer.running = true
            }
            onTabDragMoved: (gx, gy) => root.handleFileDragMoved(gx, gy)
            onTabDragEnded: (fUrl, fName, gx, gy) => root.handleFileDragEnded(fUrl, fName, gx, gy)

            onGraphClicked: root.isGraphVisible = !root.isGraphVisible
            onOpenClicked: openDialog.open()
            onSaveClicked: Logic.saveFile(root, saveDialog, backend)
            onCloseClicked: (root.appWindow || Window.window).close()
            onToggleMaximizeClicked: Logic.toggleMaximize(root.appWindow || Window.window)
        }

        // 2. Главная область: Холст с поддержкой разделения экрана (Split View) и встроенным графом
        EditorSplitLayout {
            id: splitLayout
            Layout.fillWidth: true
            Layout.fillHeight: true
            barSize: root.barSize
            isSplit: root.isSplit
            activePane: root.activePane
            dropZone: root.dropZone
            primaryFileName: root.primaryFileName
            primaryFileUrl: (root.tabsModel.count > root.primaryTabIndex && root.primaryTabIndex >= 0) ? root.tabsModel.get(root.primaryTabIndex).fileUrl : ""
            secondaryFileName: root.secondaryFileName
            secondaryFileUrl: (root.tabsModel.count > root.secondaryTabIndex && root.secondaryTabIndex >= 0) ? root.tabsModel.get(root.secondaryTabIndex).fileUrl : ""

            isPrimaryEmpty: root.tabsModel.count === 0 || root.primaryTabIndex < 0

            // Передача состояния и событий графа
            isGraphVisible: root.isGraphVisible
            currentFolderUrl: root.currentFolderUrl
            onCloseGraphRequested: root.isGraphVisible = false
            onNodeSelected: (fUrl, lbl) => {
                root.openFileFromFolder(fUrl, lbl, false)
                root.isGraphVisible = false
            }

            onFileDragStarted: (paneIdx, url, name, gx, gy) => {
                root.isFileDragging = true
                root.draggingFileUrl = url
                root.draggingFileName = name
                root.draggingPaneIndex = paneIdx
                dragTrackerTimer.running = true
            }
            onFileDragMoved: (gx, gy) => root.handleFileDragMoved(gx, gy)
            onFileDragEnded: (paneIdx, fUrl, fName, gx, gy) => {
                root.draggingPaneIndex = paneIdx
                root.handleFileDragEnded(fUrl, fName, gx, gy)
            }

            onPrimaryTitleChanged: (newTitle) => Tabs.renameTab(root, root.primaryTabIndex, newTitle)
            onSecondaryTitleChanged: (newTitle) => Tabs.renameTab(root, root.secondaryTabIndex, newTitle)
            onPrimaryDetachRequested: Tabs.detachTab(root, root.primaryTabIndex)
            onSecondaryDetachRequested: Tabs.detachTab(root, root.secondaryTabIndex)
            onPrimaryTextChanged: (text) => {
                Tabs.handlePrimaryTextChanged(root, text)
                autoSaveTimer.restart()
            }
            onSecondaryTextChanged: (text) => {
                Tabs.handleSecondaryTextChanged(root, text)
                autoSaveTimer.restart()
            }
            onPrimaryCloseRequested: root.closeTab(root.primaryTabIndex)
            onSecondaryCloseRequested: root.closeTab(root.secondaryTabIndex)
            onCloseSplitRequested: () => Tabs.closeSplit(root)
            onPaneActivated: (paneIndex) => Tabs.setActivePane(root, paneIndex)
            onSaveRequested: Logic.saveFile(root, saveDialog, backend)
            onNewRequested: root.createNewTab()
            onToggleSidebarRequested: root.toggleSidebar()
        }
    }
}