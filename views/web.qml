import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components/editor"
import "../components/workspace"
import "../components/dialogs"
import "../components/hotkeys"
import "../components/theme"
import "./web_lifecycle.js" as WebLifecycle
import "../components/editor/markdown_shortcuts.js" as Markdown

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
    function toggleSearch() { if (splitLayout) splitLayout.toggleSearch() }

    // Переменные текущего активного файла
    property string currentFileUrl: ""
    property string currentFileName: "Новый документ"
    property int barSize: (Theme && typeof Theme.barSize === "number") ? Theme.barSize : 36

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

    function stripExt(name) { return WebLifecycle.stripExt(name) }

    property alias editorArea: splitLayout.activeEditorArea
    property alias splitLayout: splitLayout

    // Список открытых в данный момент файлов для подсветки в графе связей
    readonly property var openFileUrls: WebLifecycle.getOpenFileUrls(tabsModel, primaryTabIndex, secondaryTabIndex, isSplit)

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

    // Авто-сохранение изменений в файле с задержкой 1 сек после ввода
    Timer {
        id: autoSaveTimer
        interval: 1000
        repeat: false
        onTriggered: WebLifecycle.handleAutoSave(root, splitLayout, (typeof backend !== "undefined" ? backend : null))
    }

    property alias tabsModel: tabsModel
    property alias folderFilesModel: folderFilesModel

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
    function reloadAppConfig() { WebLifecycle.reloadAppConfig(root, autoSaveTimer, backend) }

    Connections {
        target: (typeof backend !== "undefined") ? backend : null
        function onFolderFilesChanged() { root.reloadFolderFiles() }
        function onBlockUpdated(headingNorm, content, sourceFileUrl) {
            WebLifecycle.handleBlockUpdated(root, splitLayout, headingNorm, content, sourceFileUrl)
        }
        function onConfigUpdated(configJson) { root.applyFolderConfig(configJson) }
        function onAppConfigChanged() { root.reloadAppConfig() }
    }

    function openFileFromFolder(fileUrl, fileName, isShift) {
        WebLifecycle.openFileFromFolder(root, fileUrl, fileName, isShift)
    }

    property string previousFileUrlBeforeStructure: ""
    property string previousFileNameBeforeStructure: ""
    property string highlightStructureItem: ""

    function toggleProjectStructure() {
        WebLifecycle.toggleProjectStructure(root, splitLayout, backend)
    }

    // Делегированные методы управления вкладками и сплитом
    function createNewTab(isShift) { WebLifecycle.createNewTab(root, isShift) }
    function switchToTab(index) { WebLifecycle.switchToTab(root, index) }

    function closeTab(index) { WebLifecycle.closeTab(root, index) }
    function renameTab(index, newTitle) { WebLifecycle.renameTab(root, index, newTitle) }
    function toggleSplit() { WebLifecycle.toggleSplit(root) }
    function closeSplit() { WebLifecycle.closeSplit(root) }
    function setActivePane(paneIndex) { WebLifecycle.setActivePane(root, paneIndex) }
    function applyInitialState() { return WebLifecycle.applyInitialState(root) }

    // =========================================================================
    // ДИАЛОГИ ВЫБОРА И СОХРАНЕНИЯ ФАЙЛОВ И ПАПОК
    // =========================================================================
    EditorDialogs {
        id: editorDialogs
        currentFolderUrl: root.currentFolderUrl

        onFolderAccepted: (folderUrl) => WebLifecycle.handleFolderAccepted(root, (typeof backend !== "undefined" ? backend : null), folderUrl)
        onFileOpenAccepted: (selectedFile) => WebLifecycle.handleFileOpenAccepted(root, (typeof backend !== "undefined" ? backend : null), selectedFile)
        onFileSaveAccepted: (selectedFile) => WebLifecycle.handleFileSaveAccepted(root, (typeof backend !== "undefined" ? backend : null), selectedFile)
    }

    property alias folderDialog: editorDialogs.folderDialog
    property alias openDialog: editorDialogs.openDialog
    property alias saveDialog: editorDialogs.saveDialog

    Component.onCompleted: WebLifecycle.initWebRoot(root, (typeof backend !== "undefined" ? backend : null))

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
        function onActionRequested(action) { WebLifecycle.handleActionRequested(root, backend, action) }
    }

    property alias hotkeyMapping: hotkeyManager.hotkeyMapping
    property alias flatHotkeysList: hotkeyManager.flatHotkeysList
    function reloadHotkeys() { hotkeyManager.reloadHotkeys() }

    function executeAction(action) {
        WebLifecycle.dispatchAction(root, splitLayout, openDialog, saveDialog, backend, Markdown, action)
    }

    function closeActiveTab() { WebLifecycle.closeActiveTab(root) }

    function handleGlobalKeyEvent(event) {
        return WebLifecycle.handleGlobalKeyEvent(root, splitLayout, hotkeyManager, backend, event)
    }

    Keys.forwardTo: (splitLayout ? [splitLayout] : [])

    Keys.onPressed: (event) => handleGlobalKeyEvent(event)

    // =========================================================================
    // ГЛАВНАЯ ОБЛАСТЬ РЕДАКТОРА (ЧИСТЫЙ МОНОЛИТ)
    // =========================================================================
    WorkspaceSplit {
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

        onNodeSelected: (fUrl, lbl) => WebLifecycle.handleNodeSelected(root, splitLayout, fUrl, lbl)

        onPrimaryTitleChanged: (newTitle) => root.renameTab(root.primaryTabIndex, newTitle)
        onSecondaryTitleChanged: (newTitle) => root.renameTab(root.secondaryTabIndex, newTitle)
        onPrimaryTextChanged: autoSaveTimer.restart()
        onSecondaryTextChanged: autoSaveTimer.restart()
        onPrimaryCloseRequested: root.closeTab(root.primaryTabIndex)
        onSecondaryCloseRequested: root.closeTab(root.secondaryTabIndex)
        onPaneActivated: (paneIndex) => root.setActivePane(paneIndex)
        onSaveRequested: root.executeAction("save_file")
        onOpenRequested: root.executeAction("open_file")
        onOpenSplitRequested: root.executeAction("open_file_split")
        onNewRequested: root.createNewTab(false)
        onNewSplitRequested: root.executeAction("new_tab_split")
        onToggleGraphRequested: root.executeAction("toggle_graph")
        onToggleLocalGraphRequested: root.executeAction("toggle_local_graph")
        onToggleSplitRequested: root.toggleSplit()
        onOpenStructureRequested: root.executeAction("open_structure")
    }
}