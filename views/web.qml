import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components/editor"
import "../components/workspace"
import "../components/hotkeys"
import "../components/theme"
import "../components/workspace/document_controller.js" as Documents
import "web_lifecycle.js" as Lifecycle

Rectangle {
    id: root
    anchors.fill: parent
    color: Theme.bgApp
    focus: true
    property var appWindow: null
    property string dropZone: ""
    property string currentFolderUrl: backend.get_default_folder()
    property string currentFolderName: backend.get_folder_name(currentFolderUrl)
    property alias workspace: canvasLayout
    readonly property var editorArea: canvasLayout.activeEditorArea
    readonly property bool isGraphVisible: canvasLayout.isGraphVisible
    readonly property string currentFileUrl: canvasLayout.activePane ? canvasLayout.activePane.fileUrl : ""
    readonly property string currentFileName: canvasLayout.activePane ? canvasLayout.activePane.fileName : ""
    property bool initialStateApplied: false
    property int targetFps: backend.get_target_fps()
    readonly property int animIntervalMs: targetFps <= 0 ? 1 : Math.max(1, Math.round(1000 / targetFps))

    function createNewTab() { return Documents.createDocument(canvasLayout, backend, currentFolderUrl) }
    function openFileFromFolder(url, name) { return Documents.openDocument(canvasLayout, backend, url, name) }
    function closeActiveTab() {
        if (canvasLayout.isGraphVisible) canvasLayout.closeGraph()
        else Documents.closePanel(canvasLayout, backend, canvasLayout.activePanel)
    }
    function saveAll() { return Documents.saveAll(canvasLayout, backend) }
    function toggleGraph() { canvasLayout.toggleGraph(false) }
    function toggleLocalGraph() { canvasLayout.toggleGraph(true) }
    function closeGraph() { canvasLayout.closeGraph() }
    function executeAction(action) { Lifecycle.dispatchAction(root, backend, action) }
    function applyInitialState() {
        if (initialStateApplied || !appWindow || !appWindow.initialFileUrl) return false
        initialStateApplied = true
        openFileFromFolder(appWindow.initialFileUrl, appWindow.initialTitle)
        if (appWindow.initialContent) canvasLayout.activePane.text = appWindow.initialContent
        return true
    }
    function handleGlobalKeyEvent(event) {
        if (hotkeys.handleKeyEvent(event)) return true
        if (event.key === Qt.Key_Escape && isGraphVisible) {
            closeGraph()
            event.accepted = true
            return true
        }
        return false
    }
    Keys.onPressed: (event) => handleGlobalKeyEvent(event)
    Component.onCompleted: Qt.callLater(function() { Lifecycle.initialize(root, backend) })

    Timer {
        id: autoSaveTimer
        interval: backend.get_app_config().auto_save_delay_ms || 1000
        onTriggered: root.saveAll()
    }
    Connections {
        target: backend
        function onNoteOpened(url, block) {
            var panel = root.openFileFromFolder(url, backend.get_filename(url))
            if (panel && block) {
                var index = panel.pane.text.indexOf(block)
                if (index >= 0) panel.pane.editorArea.cursorPosition = index
            }
        }
        function onBlockUpdated(name, text, source) { canvasLayout.applyBlockUpdate(name, text, source) }
        function onConfigUpdated(json) { canvasLayout.applyConfig(JSON.parse(json)) }
        function onAppConfigChanged() {
            autoSaveTimer.interval = backend.get_app_config().auto_save_delay_ms || 1000
            root.targetFps = backend.get_target_fps()
        }
        function onActionRequested(action) {
            if (!root.appWindow || root.appWindow.active) root.executeAction(action)
        }
    }
    HotkeyManager {
        id: hotkeys
        onActionTriggered: (action) => root.executeAction(action)
        onCloseActiveTabRequested: root.closeActiveTab()
    }
    EditorDialogs {
        id: dialogs
        currentFolderUrl: root.currentFolderUrl
        onFileOpenAccepted: (url) => root.openFileFromFolder(url, backend.get_filename(url))
        onFolderAccepted: (url) => {
            if (!root.saveAll()) return
            canvasLayout.panels.slice().forEach(function(panel) { canvasLayout.removePanel(panel) })
            root.currentFolderUrl = url
            root.currentFolderName = backend.get_folder_name(url)
            backend.save_last_folder(url)
            backend.watch_folder(url)
            root.initialStateApplied = false
            Lifecycle.initialize(root, backend)
        }
    }
    property alias openDialog: dialogs.openDialog
    property alias folderDialog: dialogs.folderDialog

    CanvasWorkspace {
        id: canvasLayout
        anchors.fill: parent
        currentFolderUrl: root.currentFolderUrl
        currentFolderName: root.currentFolderName
        onContentChanged: autoSaveTimer.restart()
        onActionRequested: (action) => root.executeAction(action)
        onCloseRequested: (panel) => Documents.closePanel(canvasLayout, backend, panel)
        onRenameRequested: (panel, title) => Documents.renamePanel(canvasLayout, backend, panel, title)
    }
}
