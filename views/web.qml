import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components/editor"
import "../components/dialogs"
import "../components/hotkeys"
import "../components/theme"
import "../js/tabs/tabs.js" as Tabs
import "../js/tabs/drag_manager.js" as DragMgr
import "../js/editor/markdown_shortcuts.js" as Markdown
import "../js/app/web_lifecycle.js" as WebLifecycle

Rectangle {
    id: root
    anchors.fill: parent
    color: Theme.bgApp
    focus: true

    // Ссылка на родительское ApplicationWindow
    property var appWindow: null
    readonly property url windowComponentUrl: Qt.resolvedUrl("window.qml")

    // Видимость интерактивного графа связей
    readonly property bool isGraphVisible: splitLayout ? splitLayout.isGraphVisible : false
    function toggleGraph() { if (splitLayout) splitLayout.toggleGraph() }
    function toggleLocalGraph() { if (splitLayout) splitLayout.toggleLocalGraph() }
    function closeGraph() { if (splitLayout) splitLayout.closeGraph() }
    function closeAllGraphs() { if (splitLayout) splitLayout.closeAllGraphs() }

    // Переменные текущего активного файла
    property string currentFileUrl: ""
    property string currentFileName: "Новый документ"
    property int barSize: 36

    // Текущая рабочая папка
    property string currentFolderUrl: (typeof backend !== "undefined" && backend) ? backend.get_default_folder() : ""
    property string currentFolderName: (typeof backend !== "undefined" && backend && currentFolderUrl) ? backend.get_folder_name(currentFolderUrl) : "my-text-editor"
    property bool openFileInSplit: false

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
        return WebLifecycle.stripExt ? WebLifecycle.stripExt(name) : (name ? name.replace(/\.md$/i, "") : "")
    }

    property alias editorArea: splitLayout.activeEditorArea
    property alias splitLayout: splitLayout

    // Список открытых в данный момент файлов для подсветки в графе связей
    readonly property var openFileUrls: {
        let list = []
        if (tabsModel) {
            for (let i = 0; i < tabsModel.count; i++) {
                let item = tabsModel.get(i)
                let u = item ? item.fileUrl : ""
                if (u && list.indexOf(u) === -1) list.push(u)
            }
        }
        let pUrl = (tabsModel && tabsModel.count > primaryTabIndex && primaryTabIndex >= 0) ? tabsModel.get(primaryTabIndex).fileUrl : ""
        let sUrl = (isSplit && tabsModel && tabsModel.count > secondaryTabIndex && secondaryTabIndex >= 0) ? tabsModel.get(secondaryTabIndex).fileUrl : ""
        if (pUrl && list.indexOf(pUrl) === -1) list.push(pUrl)
        if (sUrl && list.indexOf(sUrl) === -1) list.push(sUrl)
        return list
    }

    // =========================================================================
    // МОДЕЛЬ ВКЛАДОК, ФАЙЛОВ ПАПКИ И ОТКРЕПЛЕННЫХ ОКОН
    // =========================================================================
    property int currentTabIndex: 0
    property var externalWindowFiles: []
    property bool isFileDragging: false
    property string draggingFileUrl: ""
    property string draggingFileName: ""
    property int draggingPaneIndex: -1

    // Целевая частота кадров (FPS) и интервал таймеров интерфейса
    property int targetFps: (typeof backend !== "undefined" && backend && typeof backend.get_target_fps === "function") ? backend.get_target_fps() : 60
    readonly property int animIntervalMs: targetFps <= 0 ? 1 : Math.max(1, Math.round(1000 / targetFps))

    // Таймер аппаратного отслеживания курсора во время перетаскивания (адаптируется под герцовку монитора)
    Timer {
        id: dragTrackerTimer
        interval: root.animIntervalMs
        repeat: true
        running: false
        onTriggered: DragMgr.pollCursorState(root, Tabs)
    }

    // Авто-сохранение изменений в файле с задержкой 1 сек после ввода
    Timer {
        id: autoSaveTimer
        interval: 1000
        repeat: false
        onTriggered: WebLifecycle.handleAutoSave(root, splitLayout, (typeof backend !== "undefined" ? backend : null))
    }


    property alias tabsModel: tabsModel
    property alias folderFilesModel: folderFilesModel
    property alias dragTrackerTimer: dragTrackerTimer

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
    function reloadAppConfig() {
        if (typeof backend !== "undefined" && backend && typeof backend.get_app_config === "function") {
            try {
                let appCfg = backend.get_app_config()
                if (appCfg && typeof appCfg.auto_save_delay_ms === "number" && appCfg.auto_save_delay_ms > 0) {
                    autoSaveTimer.interval = appCfg.auto_save_delay_ms
                }
                if (typeof backend.get_target_fps === "function") {
                    root.targetFps = backend.get_target_fps()
                }
            } catch(e) {}
        }
    }

    Connections {
        target: (typeof backend !== "undefined") ? backend : null
        function onFolderFilesChanged() { root.reloadFolderFiles() }
        function onBlockUpdated(headingNorm, content, sourceFileUrl) {
            WebLifecycle.handleBlockUpdated(root, splitLayout, Tabs, headingNorm, content, sourceFileUrl)
        }
        function onConfigUpdated(configJson) { root.applyFolderConfig(configJson) }
        function onAppConfigChanged() { root.reloadAppConfig() }
    }

    function openFileFromFolder(fileUrl, fileName, isShift) {
        root.closeGraph()
        Tabs.openFileFromFolder(root, fileUrl, fileName, isShift)
    }

    property string previousFileUrlBeforeStructure: ""
    property string previousFileNameBeforeStructure: ""
    property string highlightStructureItem: ""

    function toggleProjectStructure() {
        if (typeof backend === "undefined" || !backend) return

        var activeBar = (root.isSplit && root.activePane === 1) ? splitLayout.secondaryBar : splitLayout.primaryBar
        var curName = activeBar ? activeBar.fileName : ""
        var curUrl = activeBar ? activeBar.fileUrl : ""

        // Если сейчас уже открыта структура проекта (_Структура.md) — возвращаемся назад к предыдущему файлу
        if (curName && curName.indexOf("_Структура") !== -1) {
            if (activeBar) {
                activeBar.isOutlineMode = false
            }
            if (root.previousFileUrlBeforeStructure) {
                root.openFileFromFolder(root.previousFileUrlBeforeStructure, root.previousFileNameBeforeStructure, false)
            } else if (root.tabsModel.count > 1) {
                for (var t = 0; t < root.tabsModel.count; t++) {
                    var tabItem = root.tabsModel.get(t)
                    if (tabItem && tabItem.fileUrl && tabItem.fileUrl !== curUrl) {
                        root.openFileFromFolder(tabItem.fileUrl, tabItem.title, false)
                        break
                    }
                }
            }
            Qt.callLater(() => {
                var targetBar = (root.isSplit && root.activePane === 1) ? splitLayout.secondaryBar : splitLayout.primaryBar
                if (targetBar) {
                    targetBar.isOutlineMode = false
                }
            })
            return
        }

        // Сохраняем состояние текущего текста перед открытием структуры
        Tabs.syncCurrentPaneText(root)

        // Если мы в обычной заметке — запоминаем ее и открываем визуальную структуру
        root.previousFileUrlBeforeStructure = curUrl
        root.previousFileNameBeforeStructure = curName
        root.highlightStructureItem = root.stripExt(curName)

        var info = backend.sync_project_structure_file(root.currentFolderUrl)
        if (info && info.fileUrl) {
            root.openFileFromFolder(info.fileUrl, info.fileName, false)

            // Сразу переключаем в визуальный режим дерева (Outliner) и позиционируем на файл
            Qt.callLater(() => {
                var targetBar = (root.isSplit && root.activePane === 1) ? splitLayout.secondaryBar : splitLayout.primaryBar
                if (targetBar) {
                    targetBar.isOutlineMode = true
                    if (targetBar.sheetOutliner) {
                        targetBar.sheetOutliner.reload()
                        targetBar.sheetOutliner.highlightLabel = root.highlightStructureItem
                        targetBar.sheetOutliner.scrollToHighlight()
                    }
                }
            })
        }
    }

    // Делегированные методы управления вкладками и сплитом
    function createNewTab(isShift) {
        root.closeGraph()
        Tabs.createNewTab(root, isShift)
    }
    function switchToTab(index) {
        root.closeGraph()
        Tabs.switchToTab(root, index)
    }

    function closeTab(index) { Tabs.closeTab(root, index) }
    function renameTab(index, newTitle) { Tabs.renameTab(root, index, newTitle) }
    function detachTab(index, spawnX, spawnY) { Tabs.detachTab(root, index, spawnX, spawnY) }
    function toggleSplit() { Tabs.toggleSplit(root) }
    function closeSplit() { Tabs.closeSplit(root) }
    function setActivePane(paneIndex) { Tabs.setActivePane(root, paneIndex) }
    function openInNewWindow(fileUrl, fileName, wx, wy) { Tabs.openInNewWindow(root, fileUrl, fileName, wx, wy) }
    function handleFileDragMoved(gx, gy) { DragMgr.handleFileDragMoved(root, gx, gy) }
    function handleFileDragEnded(fileUrl, fileName, gx, gy) { DragMgr.handleFileDragEnded(root, fileUrl, fileName, gx, gy, Tabs) }
    function dockExternalTab(fileUrl, fileName, content, zone) { DragMgr.dockFileInCurrentWindow(root, fileUrl, fileName, content, zone, Tabs) }

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

        onFolderAccepted: (folderUrl) => WebLifecycle.handleFolderAccepted(root, (typeof backend !== "undefined" ? backend : null), folderUrl)
        onFileOpenAccepted: (selectedFile) => WebLifecycle.handleFileOpenAccepted(root, (typeof backend !== "undefined" ? backend : null), Tabs, selectedFile)
        onFileSaveAccepted: (selectedFile) => WebLifecycle.handleFileSaveAccepted(root, (typeof backend !== "undefined" ? backend : null), Tabs, selectedFile)
    }


    property alias folderDialog: editorDialogs.folderDialog
    property alias openDialog: editorDialogs.openDialog
    property alias saveDialog: editorDialogs.saveDialog

    Component.onCompleted: {
        root.reloadAppConfig()
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

    Connections {
        target: (typeof backend !== "undefined") ? backend : null
        ignoreUnknownSignals: true
        function onActionRequested(action) {
            var win = root.appWindow || (root.Window ? root.Window.window : null)
            var count = (backend && typeof backend.get_window_count === "function") ? backend.get_window_count() : 1
            if (count > 1 && win && !win.active) {
                return
            }
            root.executeAction(action)
        }
    }

    property alias hotkeyMapping: hotkeyManager.hotkeyMapping
    property alias flatHotkeysList: hotkeyManager.flatHotkeysList
    function reloadHotkeys() { hotkeyManager.reloadHotkeys() }

    function executeAction(action) {
        WebLifecycle.dispatchAction(root, splitLayout, openDialog, saveDialog, backend, Markdown, Tabs, action)
    }

    function closeActiveTab() { WebLifecycle.closeActiveTab(root) }

    function handleGlobalKeyEvent(event) {
        if (hotkeyManager.handleKeyEvent(event)) {
            return true
        }
        if (event.key === Qt.Key_Escape && root.isGraphVisible) {
            root.closeGraph()
            event.accepted = true
            return true
        }
        return false
    }

    Keys.forwardTo: (splitLayout ? [splitLayout] : [])

    Keys.onPressed: (event) => {
        if (handleGlobalKeyEvent(event)) {
            return
        }
    }

    // =========================================================================
    // ГЛАВНАЯ ОБЛАСТЬ РЕДАКТОРА
    // =========================================================================
    EditorSplitLayout {
        id: splitLayout
        anchors.fill: parent
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
        openFileUrls: root.openFileUrls
        currentFolderUrl: root.currentFolderUrl
        currentFolderName: root.currentFolderName
        onCloseGraphRequested: root.closeGraph()

        onNodeSelected: (fUrl, lbl) => {
            var targetBar = (root.isSplit && root.activePane === 1) ? splitLayout.secondaryBar : splitLayout.primaryBar
            if (targetBar) {
                targetBar.isOutlineMode = false
            }
            root.openFileFromFolder(fUrl, lbl, false)
            Qt.callLater(() => {
                var tBar = (root.isSplit && root.activePane === 1) ? splitLayout.secondaryBar : splitLayout.primaryBar
                if (tBar) {
                    tBar.isOutlineMode = false
                }
            })
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
        onPrimaryTextChanged: autoSaveTimer.restart()
        onSecondaryTextChanged: autoSaveTimer.restart()
        onPrimaryCloseRequested: root.closeTab(root.primaryTabIndex)
        onSecondaryCloseRequested: root.closeTab(root.secondaryTabIndex)
        onPaneActivated: (paneIndex) => Tabs.setActivePane(root, paneIndex)
        onSaveRequested: root.executeAction("save_file")
        onOpenRequested: root.executeAction("open_file")
        onOpenSplitRequested: root.executeAction("open_file_split")
        onNewRequested: root.createNewTab(false)
        onNewSplitRequested: root.executeAction("new_tab_split")
        onToggleGraphRequested: root.executeAction("toggle_graph")
        onToggleSplitRequested: root.toggleSplit()
        onOpenStructureRequested: root.executeAction("open_structure")
    }
}