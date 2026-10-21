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
    property string currentFolderUrl: (typeof backend !== "undefined" && backend) ? backend.get_default_folder() : ""
    property string currentFolderName: (typeof backend !== "undefined" && backend && currentFolderUrl) ? backend.get_folder_name(currentFolderUrl) : ""
    property alias workspace: canvasLayout
    readonly property var editorArea: canvasLayout.activeEditorArea
    readonly property bool isGraphVisible: canvasLayout.isGraphVisible
    onIsGraphVisibleChanged: {
        if (typeof backend !== "undefined" && backend && typeof backend.set_graph_active === "function") {
            backend.set_graph_active(isGraphVisible)
        }
    }
    readonly property string currentFileUrl: canvasLayout.activePane ? canvasLayout.activePane.fileUrl : ""
    readonly property string currentFileName: canvasLayout.activePane ? canvasLayout.activePane.fileName : ""
    property bool initialStateApplied: false
    property int targetFps: (typeof backend !== "undefined" && backend && typeof backend.get_target_fps === "function") ? backend.get_target_fps() : 60
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
        if (event.key === Qt.Key_Escape) {
            if (isGraphVisible) {
                closeGraph()
                event.accepted = true
                return true
            } else if (editorArea && editorArea.activeFocus) {
                root.focus = true
                event.accepted = true
                return true
            }
        }
        return false
    }
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Space && !event.isAutoRepeat) {
            if (!editorArea || !editorArea.activeFocus) {
                canvasLayout.isSpacePanning = true
                event.accepted = true
                return
            }
        }
        handleGlobalKeyEvent(event)
    }
    Keys.onReleased: (event) => {
        if (event.key === Qt.Key_Space && !event.isAutoRepeat) {
            canvasLayout.isSpacePanning = false
            event.accepted = true
            return
        }
    }
    onActiveFocusChanged: {
        if (!activeFocus) canvasLayout.isSpacePanning = false
    }
    Component.onCompleted: Qt.callLater(function() { Lifecycle.initialize(root, backend) })

    Timer {
        id: autoSaveTimer
        interval: (typeof backend !== "undefined" && backend && typeof backend.get_app_config === "function" && backend.get_app_config()) ? (backend.get_app_config().auto_save_delay_ms || 1000) : 1000
        onTriggered: root.saveAll()
    }
    Connections {
        target: backend
        function onNoteOpened(url, block) {
            var active = canvasLayout.activePanel
            var panel = null
            if (active && active.pane && active.pane.isGraphMode) {
                panel = Documents.navigatePanel(canvasLayout, backend, active, url, backend.get_filename(url), block)
            } else {
                panel = root.openFileFromFolder(url, backend.get_filename(url))
                if (panel) {
                    panel.pane.isGraphMode = false
                    if (block) {
                        Qt.callLater(function() {
                            if (panel && panel.pane && panel.pane.editorArea) {
                                var fullText = panel.pane.text
                                var targetIdx = -1
                                var pattern = new RegExp("(^|\\n)\\s*" + block.replace(/[.*+?^${}()|[\\]\\]/g, "\\$&") + "\\s*(\\{|\\()", "m")
                                var match = fullText.match(pattern)
                                if (match) {
                                    targetIdx = match.index + (match[1] ? match[1].length : 0)
                                } else {
                                    targetIdx = fullText.indexOf(block)
                                }
                                if (targetIdx >= 0) {
                                    panel.pane.editorArea.cursorPosition = Math.min(targetIdx, panel.pane.editorArea.length)
                                    panel.pane.editorArea.forceActiveFocus()
                                    if (typeof panel.pane.requestEnsureCursorVisible === "function") {
                                        panel.pane.requestEnsureCursorVisible()
                                    }
                                }
                            }
                        })
                    } else if (panel && panel.pane && panel.pane.editorArea) {
                        panel.pane.editorArea.forceActiveFocus()
                    }
                }
            }
        }
        function onBlockUpdated(name, text, source) { canvasLayout.applyBlockUpdate(name, text, source) }
        function onConfigUpdated(json) { canvasLayout.applyConfig(JSON.parse(json)) }
        function onAppConfigChanged() {
            autoSaveTimer.interval = backend.get_app_config().auto_save_delay_ms || 1000
            root.targetFps = backend.get_target_fps()
        }
        function onSpacePanToggled(active) { canvasLayout.isSpacePanning = active }
        function onActionRequested(action) {
            var isSingle = (typeof backend !== "undefined" && backend && typeof backend.get_window_count === "function") ? (backend.get_window_count() <= 1) : true
            if (!root.appWindow || root.appWindow.active || isSingle) root.executeAction(action)
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
