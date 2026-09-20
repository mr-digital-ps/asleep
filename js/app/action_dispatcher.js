// action_dispatcher.js — Диспетчеризация действий интерфейса и хоткеев

function closeActiveTab(root) {
    if (root && root.isGraphVisible) {
        if (typeof root.closeGraph === "function") {
            root.closeGraph()
        }
        return
    }
    if (!root || !root.tabsModel || root.tabsModel.count === 0) return
    var targetIdx = (root.isSplit && root.activePane === 1) ? root.secondaryTabIndex : root.primaryTabIndex
    if (targetIdx >= 0 && targetIdx < root.tabsModel.count) {
        root.closeTab(targetIdx)
    } else if (root.currentTabIndex >= 0 && root.currentTabIndex < root.tabsModel.count) {
        root.closeTab(root.currentTabIndex)
    } else {
        root.closeTab(root.tabsModel.count - 1)
    }
}

function saveFile(root, saveDialog, backend) {
    if (!root) return
    var targetIndex = (root.isSplit && root.activePane === 1) ? root.secondaryTabIndex : root.primaryTabIndex
    var tab = (root.tabsModel && targetIndex >= 0 && targetIndex < root.tabsModel.count) ? root.tabsModel.get(targetIndex) : null
    var fileUrl = tab ? (tab.fileUrl || "") : (root.currentFileUrl || "")

    if (!fileUrl) {
        if (saveDialog && typeof saveDialog.open === "function") {
            saveDialog.open()
        }
    } else {
        var text = (root.editorArea ? root.editorArea.text : "")
        if (backend) {
            backend.save_file(fileUrl, text)
        }
        if (tab) {
            tab.content = text
        }
    }
}

function dispatchAction(root, splitLayout, openDialog, saveDialog, backend, Markdown, Tabs, action) {
    switch (action) {
        case "toggle_header_footer":
            if (splitLayout && splitLayout.primaryBar && typeof splitLayout.primaryBar.toggleHeaderFooter === "function") {
                splitLayout.primaryBar.toggleHeaderFooter()
            }
            if (splitLayout && splitLayout.isSplit && splitLayout.secondaryBar && typeof splitLayout.secondaryBar.toggleHeaderFooter === "function") {
                splitLayout.secondaryBar.toggleHeaderFooter()
            }
            break
        case "toggle_footer":
            if (splitLayout && splitLayout.primaryBar && typeof splitLayout.primaryBar.toggleFooterOnly === "function") {
                splitLayout.primaryBar.toggleFooterOnly()
            }
            if (splitLayout && splitLayout.isSplit && splitLayout.secondaryBar && typeof splitLayout.secondaryBar.toggleFooterOnly === "function") {
                splitLayout.secondaryBar.toggleFooterOnly()
            }
            break
        case "toggle_header":
            if (splitLayout && splitLayout.primaryBar && typeof splitLayout.primaryBar.toggleHeaderOnly === "function") {
                splitLayout.primaryBar.toggleHeaderOnly()
            }
            if (splitLayout && splitLayout.isSplit && splitLayout.secondaryBar && typeof splitLayout.secondaryBar.toggleHeaderOnly === "function") {
                splitLayout.secondaryBar.toggleHeaderOnly()
            }
            break
        case "toggle_split":
            if (root && typeof root.toggleSplit === "function") {
                root.toggleSplit()
            }
            break
        case "toggle_centered_mode":
            if (splitLayout && splitLayout.primaryBar) {
                splitLayout.primaryBar.isCenteredMode = !splitLayout.primaryBar.isCenteredMode
            }
            if (splitLayout && splitLayout.isSplit && splitLayout.secondaryBar && splitLayout.primaryBar) {
                splitLayout.secondaryBar.isCenteredMode = splitLayout.primaryBar.isCenteredMode
            }
            break
        case "close_tab":
            closeActiveTab(root)
            break
        case "new_tab":
            if (root && typeof root.createNewTab === "function") {
                root.createNewTab(false)
            }
            break
        case "new_tab_split":
            if (root && typeof root.createNewTab === "function") {
                root.createNewTab(true)
            }
            break
        case "open_file":
            if (root) root.openFileInSplit = false
            if (openDialog && typeof openDialog.open === "function") {
                openDialog.open()
            }
            break
        case "open_file_split":
            if (root) root.openFileInSplit = true
            if (openDialog && typeof openDialog.open === "function") {
                openDialog.open()
            }
            break
        case "save_file":
            saveFile(root, saveDialog, backend)
            break
        case "detach_window":
            var targetIdx = (root.isSplit && root.activePane === 1) ? root.secondaryTabIndex : root.primaryTabIndex
            if (Tabs && typeof Tabs.detachTab === "function") {
                Tabs.detachTab(root, targetIdx >= 0 ? targetIdx : 0)
            }
            break
        case "toggle_bold":
            if (splitLayout && splitLayout.activeEditorArea && Markdown) {
                Markdown.toggleBold(splitLayout.activeEditorArea)
            }
            break
        case "toggle_italic":
            if (splitLayout && splitLayout.activeEditorArea && Markdown) {
                Markdown.toggleItalic(splitLayout.activeEditorArea)
            }
            break
        case "toggle_graph":
            if (root) {
                if (typeof root.toggleGraph === "function") {
                    root.toggleGraph()
                }
            }
            break
        case "toggle_local_graph":
            if (root) {
                if (typeof root.toggleLocalGraph === "function") {
                    root.toggleLocalGraph()
                }
            }
            break
        case "toggle_outline":
            if (splitLayout) {
                var targetBar = (splitLayout.isSplit && splitLayout.activePane === 1) ? splitLayout.secondaryBar : splitLayout.primaryBar
                if (targetBar && typeof targetBar.toggleOutlineMode === "function") {
                    targetBar.toggleOutlineMode()
                }
            }
            break
        case "open_structure":
            if (root && typeof root.toggleProjectStructure === "function") {
                root.toggleProjectStructure()
            }
            break
    }
}


