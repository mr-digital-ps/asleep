// js/tabs/tab_model.js — Модель и операции над вкладками (CRUD, файлы, открепление, переименование)

function stripExt(name) {
    if (!name) return ""
    return name.replace(/\.md$/i, "")
}

function findTabIndex(root, fileUrl) {
    if (!fileUrl) return -1
    for (let i = 0; i < root.tabsModel.count; i++) {
        let t = root.tabsModel.get(i)
        if (t && t.fileUrl === fileUrl) {
            return i
        }
    }
    return -1
}

function findOtherTabIndex(root, excludeIdx) {
    for (let i = 0; i < root.tabsModel.count; i++) {
        if (i !== excludeIdx) return i
    }
    let nextNum = root.tabsModel.count + 1
    root.tabsModel.append({
        title: "Документ " + nextNum,
        fileUrl: "",
        content: "",
        isDetached: false
    })
    return root.tabsModel.count - 1
}

function getFileContent(root, fileUrl) {
    if (!fileUrl) {
        let bar = (root.isSplit && root.activePane === 1) ? (root.splitLayout && root.splitLayout.secondaryBar) : (root.splitLayout && root.splitLayout.primaryBar)
        return bar ? bar.text : ""
    }
    for (let i = 0; i < root.tabsModel.count; i++) {
        let t = root.tabsModel.get(i)
        if (t && t.fileUrl === fileUrl) {
            if (i === root.primaryTabIndex && root.splitLayout && root.splitLayout.primaryBar) {
                return root.splitLayout.primaryBar.text
            } else if (i === root.secondaryTabIndex && root.splitLayout && root.splitLayout.secondaryBar) {
                return root.splitLayout.secondaryBar.text
            } else {
                return t.content || ""
            }
        }
    }
    if (typeof backend !== "undefined" && backend && typeof backend.read_file === "function") {
        return backend.read_file(fileUrl)
    }
    return ""
}

function createNewTab(root, isShift, syncCurrentPaneText, syncEditorsFromModel, setActivePane, switchToTab) {
    if (syncCurrentPaneText) syncCurrentPaneText(root)

    let folderUrl = root.currentFolderUrl
    if (!folderUrl && typeof backend !== "undefined" && backend && typeof backend.get_default_folder === "function") {
        folderUrl = backend.get_default_folder()
        root.currentFolderUrl = folderUrl
        if (typeof backend.get_folder_name === "function") {
            root.currentFolderName = backend.get_folder_name(folderUrl)
        }
    }

    let fileUrl = ""
    let fileName = "Новый документ"

    if (typeof backend !== "undefined" && backend && folderUrl) {
        let res = backend.create_file_in_folder(folderUrl, "Новый документ")
        if (res && res.success) {
            fileUrl = res.fileUrl
            fileName = res.fileName
        }
    }

    let cleanName = stripExt(fileName)

    if (root.tabsModel.count === 0 || root.primaryTabIndex < 0) {
        root.tabsModel.clear()
        root.tabsModel.append({
            title: cleanName,
            fileUrl: fileUrl,
            content: "",
            isDetached: false
        })
        root.primaryTabIndex = 0
        root.secondaryTabIndex = -1
        root.isSplit = false
        root.activePane = 0
        if (syncEditorsFromModel) syncEditorsFromModel(root)
        if (setActivePane) setActivePane(root, 0)
        if (typeof root.reloadFolderFiles === "function") root.reloadFolderFiles()
        return
    }

    if (!isShift && root.tabsModel.count === 1) {
        let first = root.tabsModel.get(0)
        let curText = (root.splitLayout && root.splitLayout.primaryBar) ? root.splitLayout.primaryBar.text : ""
        if ((!first.fileUrl || first.fileUrl === "") && (!curText || curText.trim() === "")) {
            root.tabsModel.setProperty(0, "title", cleanName)
            root.tabsModel.setProperty(0, "fileUrl", fileUrl)
            root.tabsModel.setProperty(0, "content", "")
            root.currentFileName = cleanName
            root.currentFileUrl = fileUrl
            root.primaryFileName = cleanName
            if (syncEditorsFromModel) syncEditorsFromModel(root)
            if (setActivePane) setActivePane(root, 0)
            if (typeof root.reloadFolderFiles === "function") root.reloadFolderFiles()
            return
        }
    }

    root.tabsModel.append({
        title: cleanName,
        fileUrl: fileUrl,
        content: "",
        isDetached: false
    })
    let newIdx = root.tabsModel.count - 1

    if (isShift) {
        root.secondaryTabIndex = newIdx
        root.isSplit = true
        root.activePane = 1
        root.currentTabIndex = newIdx
        if (syncEditorsFromModel) syncEditorsFromModel(root)
        if (setActivePane) setActivePane(root, 1)
    } else if (root.isSplit) {
        if (root.activePane === 1) {
            root.secondaryTabIndex = newIdx
        } else {
            root.primaryTabIndex = newIdx
        }
        root.currentTabIndex = newIdx
        if (syncEditorsFromModel) syncEditorsFromModel(root)
        if (setActivePane) setActivePane(root, root.activePane)
    } else {
        if (switchToTab) switchToTab(root, newIdx)
    }

    if (typeof root.reloadFolderFiles === "function") root.reloadFolderFiles()
}

function closeTab(root, index, syncCurrentPaneText, syncEditorsFromModel, setActivePane, closeSplit) {
    if (index < 0 || index >= root.tabsModel.count) return

    if (syncCurrentPaneText) syncCurrentPaneText(root)

    let isClosingPrimary = (index === root.primaryTabIndex)
    let isClosingSecondary = (root.isSplit && index === root.secondaryTabIndex)

    root.tabsModel.remove(index)

    if (root.tabsModel.count === 0) {
        root.primaryTabIndex = -1
        root.secondaryTabIndex = -1
        root.currentTabIndex = -1
        root.isSplit = false
        root.activePane = 0
        root.primaryFileName = ""
        root.secondaryFileName = ""
        root.currentFileName = ""
        root.currentFileUrl = ""
        if (root.splitLayout && root.splitLayout.primaryBar) root.splitLayout.primaryBar.text = ""
        if (root.splitLayout && root.splitLayout.secondaryBar) root.splitLayout.secondaryBar.text = ""
        return
    }

    if (root.isSplit) {
        if (isClosingSecondary) {
            root.secondaryTabIndex = -1
            root.isSplit = false
            root.activePane = 0
            if (root.primaryTabIndex > index) root.primaryTabIndex -= 1
            root.currentTabIndex = root.primaryTabIndex
            if (syncEditorsFromModel) syncEditorsFromModel(root)
            if (setActivePane) setActivePane(root, 0)
            return
        }
        if (isClosingPrimary) {
            root.primaryTabIndex = (root.secondaryTabIndex > index) ? (root.secondaryTabIndex - 1) : root.secondaryTabIndex
            root.secondaryTabIndex = -1
            root.isSplit = false
            root.activePane = 0
            root.currentTabIndex = root.primaryTabIndex
            if (syncEditorsFromModel) syncEditorsFromModel(root)
            if (setActivePane) setActivePane(root, 0)
            return
        }
        if (root.primaryTabIndex > index) root.primaryTabIndex -= 1
        if (root.secondaryTabIndex > index) root.secondaryTabIndex -= 1
        if (syncEditorsFromModel) syncEditorsFromModel(root)
        return
    }

    let nextActive = Math.max(0, index - 1)
    root.primaryTabIndex = nextActive
    root.secondaryTabIndex = -1
    root.currentTabIndex = nextActive
    root.activePane = 0
    if (syncEditorsFromModel) syncEditorsFromModel(root)
}

function renameTab(root, index, newTitle) {
    if (index < 0 || index >= root.tabsModel.count) return

    let finalTitle = stripExt(newTitle.trim())
    if (!finalTitle) finalTitle = "Новый документ"

    let tab = root.tabsModel.get(index)
    if (tab && tab.fileUrl && typeof backend !== "undefined" && backend) {
        let res = backend.rename_file(tab.fileUrl, finalTitle)
        if (res && res.success) {
            root.tabsModel.setProperty(index, "fileUrl", res.fileUrl)
            finalTitle = stripExt(res.fileName)
        }
    } else if (tab && (!tab.fileUrl || tab.fileUrl === "") && typeof backend !== "undefined" && backend && root.currentFolderUrl) {
        let res = backend.create_file_in_folder(root.currentFolderUrl, finalTitle)
        if (res && res.success) {
            root.tabsModel.setProperty(index, "fileUrl", res.fileUrl)
            finalTitle = stripExt(res.fileName)
            if (typeof root.reloadFolderFiles === "function") root.reloadFolderFiles()
        }
    }

    root.tabsModel.setProperty(index, "title", finalTitle)

    let updatedUrl = (root.tabsModel.get(index) && root.tabsModel.get(index).fileUrl) ? root.tabsModel.get(index).fileUrl : ""
    if (index === root.primaryTabIndex) {
        root.primaryFileName = finalTitle
        if (root.activePane === 0) {
            root.currentFileName = finalTitle
            root.currentFileUrl = updatedUrl
        }
    }
    if (root.isSplit && index === root.secondaryTabIndex) {
        root.secondaryFileName = finalTitle
        if (root.activePane === 1) {
            root.currentFileName = finalTitle
            root.currentFileUrl = updatedUrl
        }
    }
}

function detachTab(root, tabIndex, closeTab) {
    let tab = root.tabsModel.get(tabIndex)
    if (!tab) return
    let content = (tabIndex === root.primaryTabIndex && root.splitLayout && root.splitLayout.primaryBar)
        ? root.splitLayout.primaryBar.text
        : ((tabIndex === root.secondaryTabIndex && root.splitLayout && root.splitLayout.secondaryBar)
            ? root.splitLayout.secondaryBar.text : tab.content)
    let appWin = root.appWindow || (root.Window ? root.Window.window : null)
    let wx = appWin ? appWin.x + 50 : 100
    let wy = appWin ? appWin.y + 50 : 100
    root.spawnClonedAppWindow(tab.fileUrl, tab.title, content, wx, wy, 850, 600)
    if (closeTab) closeTab(root, tabIndex)
}

function openInNewWindow(root, fileUrl, fileName, wx, wy) {
    let content = (typeof backend !== "undefined" && backend && fileUrl) ? backend.read_file(fileUrl) : ""
    let appWin = root.appWindow || (root.Window ? root.Window.window : null)
    let targetX = wx || (appWin ? appWin.x + 50 : 100)
    let targetY = wy || (appWin ? appWin.y + 50 : 100)
    return root.spawnClonedAppWindow(fileUrl, fileName, content, targetX, targetY, 850, 600)
}


function openFileFromFolder(root, fileUrl, fileName, isShift, syncCurrentPaneText, syncEditorsFromModel, setActivePane, switchToTab) {
    if (typeof backend === "undefined" || !backend || !fileUrl) return

    let cleanName = stripExt(fileName)
    let content = backend.read_file(fileUrl)

    if (root.tabsModel.count === 0 || root.primaryTabIndex < 0) {
        root.tabsModel.clear()
        root.tabsModel.append({
            title: cleanName,
            fileUrl: fileUrl,
            content: content,
            isDetached: false
        })
        root.primaryTabIndex = 0
        root.secondaryTabIndex = -1
        root.isSplit = false
        root.activePane = 0
        if (syncEditorsFromModel) syncEditorsFromModel(root)
        if (setActivePane) setActivePane(root, 0)
        return
    }

    if (isShift) {
        if (syncCurrentPaneText) syncCurrentPaneText(root)
        if (!root.isSplit) {
            root.tabsModel.append({
                title: cleanName,
                fileUrl: fileUrl,
                content: content,
                isDetached: false
            })
            root.secondaryTabIndex = root.tabsModel.count - 1
            root.isSplit = true
            root.activePane = 1
        } else {
            let targetIdx = (root.activePane === 0) ? root.secondaryTabIndex : root.primaryTabIndex
            if (targetIdx >= 0 && targetIdx < root.tabsModel.count) {
                root.tabsModel.setProperty(targetIdx, "title", cleanName)
                root.tabsModel.setProperty(targetIdx, "fileUrl", fileUrl)
                root.tabsModel.setProperty(targetIdx, "content", content)
            }
            root.activePane = (root.activePane === 0) ? 1 : 0
        }
        if (syncEditorsFromModel) syncEditorsFromModel(root)
        if (setActivePane) setActivePane(root, root.activePane)
        return
    }

    if (root.primaryTabIndex >= 0 && root.primaryTabIndex < root.tabsModel.count) {
        let pTab = root.tabsModel.get(root.primaryTabIndex)
        if (pTab && pTab.fileUrl === fileUrl) {
            if (setActivePane) setActivePane(root, 0)
            return
        }
    }
    if (root.isSplit && root.secondaryTabIndex >= 0 && root.secondaryTabIndex < root.tabsModel.count) {
        let sTab = root.tabsModel.get(root.secondaryTabIndex)
        if (sTab && sTab.fileUrl === fileUrl) {
            if (setActivePane) setActivePane(root, 1)
            return
        }
    }

    if (syncCurrentPaneText) syncCurrentPaneText(root)

    let activeIdx = (root.isSplit && root.activePane === 1) ? root.secondaryTabIndex : root.primaryTabIndex
    if (activeIdx >= 0 && activeIdx < root.tabsModel.count) {
        root.tabsModel.setProperty(activeIdx, "title", cleanName)
        root.tabsModel.setProperty(activeIdx, "fileUrl", fileUrl)
        root.tabsModel.setProperty(activeIdx, "content", content)
        if (syncEditorsFromModel) syncEditorsFromModel(root)
        if (setActivePane) setActivePane(root, root.activePane)
    } else {
        root.tabsModel.append({
            title: cleanName,
            fileUrl: fileUrl,
            content: content,
            isDetached: false
        })
        if (switchToTab) switchToTab(root, root.tabsModel.count - 1)
    }
}
