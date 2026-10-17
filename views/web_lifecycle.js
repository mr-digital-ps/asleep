.pragma library
.import "../components/workspace/document_controller.js" as Documents

function initialize(root, backend) {
    backend.watch_folder(root.currentFolderUrl)
    if (root.initialStateApplied || root.applyInitialState()) return
    var files = backend.get_folder_files(root.currentFolderUrl)
    for (var i = 0; i < files.length; i++) {
        if (!files[i].isSystem) {
            root.openFileFromFolder(files[i].fileUrl, files[i].name)
            return
        }
    }
    root.createNewTab()
}

function dispatchAction(root, backend, action) {
    var workspace = root.workspace
    var pane = workspace.activePane
    var methods = {
        toggle_header: "toggleHeaderOnly", toggle_history: "toggleHistoryMode",
        toggle_info: "toggleInfoMode", toggle_search: "toggleSearchMode",
        toggle_path: "togglePathMode", toggle_tabs: "toggleTabsMode",
        toggle_centered_mode: "toggleCenteredMode", toggle_scrollbar: "toggleScrollbar",
        toggle_line_dots: "toggleLineDots", toggle_live_mode: "toggleLiveMode",
        toggle_source_mode: "toggleSourceMode"
    }
    if (methods[action]) {
        if (pane) pane[methods[action]]()
        return
    }
    switch (action) {
    case "new_tab": root.createNewTab(); break
    case "open_file": root.openDialog.open(); break
    case "save_file": Documents.savePanel(workspace, backend, workspace.activePanel); break
    case "close_tab": root.closeActiveTab(); break
    case "toggle_graph": root.toggleGraph(); break
    case "toggle_local_graph": root.toggleLocalGraph(); break
    case "show_text_mode": root.closeGraph(); break
    case "toggle_fullscreen":
        if (root.appWindow) {
            if (root.appWindow.visibility === 5) root.appWindow.showNormal()
            else root.appWindow.showMaximized()
        }
        break
    case "tile_active_panel":
        if (workspace && typeof workspace.tileActivePanel === "function") workspace.tileActivePanel()
        break
    case "tile_left":
        if (workspace && typeof workspace.tileLeft === "function") workspace.tileLeft()
        break
    case "tile_right":
        if (workspace && typeof workspace.tileRight === "function") workspace.tileRight()
        break
    case "tile_maximize":
        if (workspace && typeof workspace.tileMaximize === "function") workspace.tileMaximize()
        break
    case "tile_restore":
        if (workspace && typeof workspace.tileRestore === "function") workspace.tileRestore()
        break
    case "tile_workspace":
        if (workspace && typeof workspace.tileWorkspace === "function") workspace.tileWorkspace()
        break
    case "open_structure":
        var document = backend.sync_project_structure_file(root.currentFolderUrl)
        if (document && document.fileUrl) root.openFileFromFolder(document.fileUrl, document.fileName)
        break
    case "navigate_pane_left":
    case "navigate_pane_right":
        var index = workspace.panels.indexOf(workspace.activePanel)
        var next = index + (action === "navigate_pane_left" ? -1 : 1)
        if (workspace.panels[next]) workspace.activate(workspace.panels[next], true)
        break
    }
}
