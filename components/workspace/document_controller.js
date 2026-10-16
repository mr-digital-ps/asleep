.pragma library

function normalizeUrl(url) {
    return decodeURIComponent(String(url)).replace(/\\/g, "/").toLowerCase()
}

function createDocument(workspace, backend, folder) {
    var result = backend.create_file_in_folder(folder, "Новый документ")
    if (!result || !result.success) {
        workspace.errorMessage = "Не удалось создать файл"
        return null
    }
    return workspace.addDocument(result.fileUrl, result.fileName, "")
}

function openDocument(workspace, backend, url, title) {
    for (var i = 0; i < workspace.panels.length; i++) {
        var panel = workspace.panels[i]
        if (normalizeUrl(panel.pane.fileUrl) === normalizeUrl(url)) {
            panel.pane.isGraphMode = false
            workspace.activate(panel, true)
            return panel
        }
    }
    return workspace.addDocument(String(url), title || backend.get_filename(url), backend.read_file(url))
}

function savePanel(workspace, backend, panel) {
    if (!panel) return true
    var state = panel.pane.getDocumentState()
    if (state.text === panel.savedText) return true
    if (!state.fileUrl || !backend.save_file(state.fileUrl, state.text)) {
        workspace.errorMessage = "Не удалось сохранить «" + state.fileName + "». Панель оставлена открытой."
        return false
    }
    panel.savedText = state.text
    workspace.errorMessage = ""
    return true
}

function saveAll(workspace, backend) {
    var success = true
    var error = ""
    for (var i = 0; i < workspace.panels.length; i++) {
        if (!savePanel(workspace, backend, workspace.panels[i])) {
            success = false
            error = workspace.errorMessage
        }
    }
    if (!success) workspace.errorMessage = error
    return success
}

function closePanel(workspace, backend, panel) {
    if (!panel || !savePanel(workspace, backend, panel)) return false
    workspace.removePanel(panel)
    return true
}

function renamePanel(workspace, backend, panel, title) {
    if (!panel || !savePanel(workspace, backend, panel)) return
    var result = backend.rename_file(panel.pane.fileUrl, title)
    if (!result || !result.success) {
        workspace.errorMessage = "Не удалось переименовать файл"
        return
    }
    panel.pane.fileUrl = result.fileUrl
    panel.pane.fileName = result.fileName.replace(/\.(txt|md)$/i, "")
    workspace.errorMessage = ""
}

function navigatePanel(workspace, backend, panel, url, title, block) {
    if (!panel) return null
    if (!savePanel(workspace, backend, panel)) return null

    var targetUrl = String(url)
    var targetTitle = title || backend.get_filename(url)

    // Если этот файл уже открыт в другой панели на холсте — переключаемся на неё
    for (var i = 0; i < workspace.panels.length; i++) {
        var other = workspace.panels[i]
        if (other !== panel && normalizeUrl(other.pane.fileUrl) === normalizeUrl(targetUrl)) {
            panel.pane.isGraphMode = false
            other.pane.isGraphMode = false
            workspace.activate(other, true)
            if (block && other.pane.editorArea) {
                var idx = other.pane.text.indexOf(block)
                if (idx >= 0) other.pane.editorArea.cursorPosition = idx
            }
            return other
        }
    }

    // Иначе открываем файл прямо в текущей панели
    var content = backend.read_file(targetUrl)
    panel.pane.openDocument(targetUrl, targetTitle, content)
    panel.savedText = content
    panel.pane.isGraphMode = false
    workspace.activate(panel, true)
    if (block && panel.pane.editorArea) {
        var index = panel.pane.text.indexOf(block)
        if (index >= 0) panel.pane.editorArea.cursorPosition = index
    }
    return panel
}

