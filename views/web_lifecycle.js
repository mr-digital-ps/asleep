.pragma library
.import "../components/workspace/document_controller.js" as Documents

function initialize(root, backend) {
    backend.watch_folder(root.currentFolderUrl)
    if (root.initialStateApplied || root.applyInitialState()) return

    var sess = (typeof backend !== "undefined" && backend && typeof backend.get_session_config === "function") ? backend.get_session_config() : {}
    var targetFileUrl = sess.last_file || ""
    var targetLiveMode = (sess.is_live_mode !== undefined) ? Boolean(sess.is_live_mode) : true

    // 1. Пытаемся открыть последний сохраненный файл заметки, если он принадлежит текущей рабочей папке
    var isInsideCurrentFolder = false
    if (targetFileUrl && root.currentFolderUrl) {
        var normCurFolder = root.currentFolderUrl.replace(/\\/g, "/").replace(/\/+$/, "").toLowerCase() + "/"
        var normTargetFile = targetFileUrl.replace(/\\/g, "/").toLowerCase()
        if (normTargetFile.indexOf(normCurFolder) === 0) {
            isInsideCurrentFolder = true
        }
    } else if (targetFileUrl && !root.currentFolderUrl) {
        isInsideCurrentFolder = true
    }

    if (isInsideCurrentFolder && backend && typeof backend.file_exists === "function" && backend.file_exists(targetFileUrl)) {
        var fileName = backend.get_filename(targetFileUrl)
        var panel = root.openFileFromFolder(targetFileUrl, fileName)
        if (panel && panel.pane) {
            panel.pane.isLiveMode = targetLiveMode
        }
        return
    }

    // 2. Fallback: первый не-системный файл из текущей папки
    var files = backend.get_folder_files(root.currentFolderUrl)
    for (var i = 0; i < files.length; i++) {
        if (!files[i].isSystem) {
            var panel2 = root.openFileFromFolder(files[i].fileUrl, files[i].name)
            if (panel2 && panel2.pane) {
                panel2.pane.isLiveMode = targetLiveMode
            }
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
        toggle_history_diff: "toggleHistoryDiffMode",
        toggle_timeline: "toggleTimelineMode",
        toggle_info: "toggleInfoMode",
        toggle_path: "togglePathMode",
        toggle_centered_mode: "toggleCenteredMode", toggle_scrollbar: "toggleScrollbar",
        toggle_line_dots: "toggleLineDots", toggle_live_mode: "toggleLiveMode",
        toggle_source_mode: "toggleSourceMode", toggle_fold_all: "toggleFoldAllBlocks", fold_all: "foldAllBlocks", unfold_all: "unfoldAllBlocks"
    }
    if (methods[action]) {
        if (pane) pane[methods[action]]()
        return
    }
    switch (action) {
    case "new_tab": root.createNewTab(); break
    case "open_file": root.openDialog.open(); break
    case "open_folder": root.folderDialog.open(); break
    case "save_file": Documents.savePanel(workspace, backend, workspace.activePanel); break
    case "close_tab": root.closeActiveTab(); break
    case "toggle_graph": root.toggleGraph(); break
    case "toggle_local_graph": root.toggleLocalGraph(); break
    case "toggle_metro": root.toggleMetro(); break
    case "show_text_mode": root.closeGraph(); break
    case "toggle_fullscreen":
        if (root.appWindow) {
            if (root.appWindow.visibility === 4 || root.appWindow.visibility === 5) {
                root.appWindow.showNormal()
            } else {
                root.appWindow.showMaximized()
            }
        }
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
    case "center_canvas":
        if (workspace && typeof workspace.centerActive === "function") workspace.centerActive(true)
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
