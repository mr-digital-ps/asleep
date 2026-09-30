// js/tabs/tab_split.js — Управление разбивкой экрана на панели (Split View) и навигацией

function stripExt(name) {
    if (!name) return ""
    return name.replace(/\.md$/i, "")
}

function setActivePane(root, paneIndex) {
    root.activePane = paneIndex

    let targetIndex = (paneIndex === 1) ? root.secondaryTabIndex : root.primaryTabIndex
    root.currentTabIndex = targetIndex
    if (targetIndex >= 0 && targetIndex < root.tabsModel.count) {
        let tab = root.tabsModel.get(targetIndex)
        root.currentFileName = stripExt(tab.title || "")
        root.currentFileUrl = tab.fileUrl || ""
    } else {
        root.currentFileName = ""
        root.currentFileUrl = ""
    }
}

function switchToTab(root, index, syncCurrentPaneText, syncEditorsFromModel) {
    if (index < 0 || index >= root.tabsModel.count) return

    if (syncCurrentPaneText) syncCurrentPaneText(root)

    if (root.isSplit) {
        if (root.activePane === 0) {
            if (index === root.secondaryTabIndex) {
                swapPanes(root, syncEditorsFromModel)
                return
            }
            root.primaryTabIndex = index
        } else {
            if (index === root.primaryTabIndex) {
                swapPanes(root, syncEditorsFromModel)
                return
            }
            root.secondaryTabIndex = index
        }
    } else {
        root.primaryTabIndex = index
        root.secondaryTabIndex = -1
        root.activePane = 0
    }

    root.currentTabIndex = index
    if (syncEditorsFromModel) syncEditorsFromModel(root)
}

function closeSplit(root, syncCurrentPaneText, syncEditorsFromModel) {
    if (syncCurrentPaneText) syncCurrentPaneText(root)
    root.isSplit = false

    if (root.activePane === 1 && root.secondaryTabIndex >= 0) {
        root.primaryTabIndex = root.secondaryTabIndex
        root.currentTabIndex = root.secondaryTabIndex
    } else {
        root.currentTabIndex = root.primaryTabIndex
    }

    root.secondaryTabIndex = -1
    root.activePane = 0
    if (syncEditorsFromModel) syncEditorsFromModel(root)
    setActivePane(root, 0)
}

function toggleSplit(root, syncCurrentPaneText, syncEditorsFromModel, createNewTab, findOtherTabIndex) {
    if (root.isSplit) {
        closeSplit(root, syncCurrentPaneText, syncEditorsFromModel)
    } else {
        if (root.tabsModel.count === 0) {
            if (createNewTab) createNewTab(root)
            return
        }
        let curPrimary = root.primaryTabIndex
        let otherIdx = findOtherTabIndex ? findOtherTabIndex(root, curPrimary) : -1

        root.isSplit = true
        root.primaryTabIndex = curPrimary
        root.secondaryTabIndex = otherIdx
        root.activePane = 1
        root.currentTabIndex = otherIdx
        if (syncEditorsFromModel) syncEditorsFromModel(root)
        setActivePane(root, 1)
    }
}

function swapPanes(root, syncEditorsFromModel) {
    if (!root.isSplit) return
    let temp = root.primaryTabIndex
    root.primaryTabIndex = root.secondaryTabIndex
    root.secondaryTabIndex = temp
    if (syncEditorsFromModel) syncEditorsFromModel(root)
    setActivePane(root, root.activePane === 0 ? 1 : 0)
}
