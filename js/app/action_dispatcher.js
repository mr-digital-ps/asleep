// action_dispatcher.js — Диспетчеризация действий интерфейса и хоткеев

function closeActiveTab(root) {
    if (root && root.isGraphVisible) {
        root.isGraphVisible = false
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

function dispatchAction(root, splitLayout, openDialog, saveDialog, backend, Markdown, Tabs, Logic, action) {
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
                root.createNewTab()
            }
            break
        case "open_file":
            if (openDialog && typeof openDialog.open === "function") {
                openDialog.open()
            }
            break
        case "save_file":
            if (Logic && typeof Logic.saveFile === "function") {
                Logic.saveFile(root, saveDialog, backend)
            }
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
                root.isGraphVisible = !root.isGraphVisible
            }
            break
    }
}
