// web_lifecycle.js — Управление жизненным циклом рабочего пространства, окнами и внешними событиями

function reloadFolderFiles(root, backend) {
    if (!backend || !root.currentFolderUrl) return
    var files = backend.get_folder_files(root.currentFolderUrl)
    root.folderFilesModel.clear()
    for (var i = 0; i < files.length; i++) {
        root.folderFilesModel.append(files[i])
    }
}

function applyFolderConfig(root, splitLayout, configJson) {
    if (!configJson) return
    try {
        var cfg = JSON.parse(configJson)
        if (cfg && cfg.editor && splitLayout) {
            if (splitLayout.primaryBar && typeof splitLayout.primaryBar.applyConfig === "function") {
                splitLayout.primaryBar.applyConfig(cfg)
            }
            if (splitLayout.isSplit && splitLayout.secondaryBar && typeof splitLayout.secondaryBar.applyConfig === "function") {
                splitLayout.secondaryBar.applyConfig(cfg)
            }
        }
    } catch(e) {
        console.warn("[QML] Ошибка применения конфигурации:", e)
    }
}

function handleBlockUpdated(root, splitLayout, Tabs, headingNorm, content, sourceFileUrl) {
    var primarySource = splitLayout && splitLayout.primaryBar ? (splitLayout.primaryBar.fileUrl || ("tab://" + (splitLayout.primaryBar.fileName || "doc"))) : ""
    var secondarySource = (root.isSplit && splitLayout && splitLayout.secondaryBar) ? (splitLayout.secondaryBar.fileUrl || ("tab://" + (splitLayout.secondaryBar.fileName || "doc"))) : ""

    if (splitLayout && splitLayout.primaryBar && primarySource !== sourceFileUrl) {
        splitLayout.primaryBar.applyExternalBlockUpdate(headingNorm, content)
    }
    if (root.isSplit && splitLayout && splitLayout.secondaryBar && secondarySource !== sourceFileUrl) {
        splitLayout.secondaryBar.applyExternalBlockUpdate(headingNorm, content)
    }
    for (var i = 0; i < root.tabsModel.count; i++) {
        var tab = root.tabsModel.get(i)
        var tabSource = tab ? (tab.fileUrl || ("tab://" + (tab.title || "doc"))) : ""
        if (tab && tabSource !== sourceFileUrl) {
            var isDisplayed = (i === root.primaryTabIndex || (root.isSplit && i === root.secondaryTabIndex))
            if (!isDisplayed && tab.content) {
                var replaced = Tabs.replaceBlockInString(tab.content, headingNorm, content)
                if (replaced !== tab.content) {
                    tab.content = replaced
                }
            }
        }
    }
}

function applyInitialState(root, Tabs) {
    var appWin = root.Window.window
    var initUrl = (appWin && appWin.initialFileUrl) ? appWin.initialFileUrl : root.initialFileUrl
    var initTitle = (appWin && appWin.initialTitle) ? appWin.initialTitle : root.initialTitle
    var initContent = (appWin && appWin.initialContent) ? appWin.initialContent : root.initialContent
    var hideSidebar = (appWin && appWin.startWithSidebarHidden) || root.startWithSidebarHidden

    if (hideSidebar) {
        root.isSidebarVisible = false
        if (root.sideBar) {
            root.sideBar.isSidebarVisible = false
            root.sideBar.currentWidth = 0
        }
    }

    if (initUrl || initTitle) {
        var cleanInit = root.stripExt(initTitle || "Документ")
        root.tabsModel.setProperty(0, "title", cleanInit)
        root.tabsModel.setProperty(0, "fileUrl", initUrl || "")
        root.tabsModel.setProperty(0, "content", initContent || "")
        root.currentFileName = cleanInit
        root.currentFileUrl = initUrl || ""
        root.primaryFileName = cleanInit
        Tabs.syncEditorsFromModel(root)
        return true
    }
    return false
}

function initializeWorkspace(root, backend, Tabs, openDialog, saveDialog) {
    var hasInitialDoc = applyInitialState(root, Tabs)

    if (backend) {
        root.currentFolderUrl = backend.get_default_folder()
        root.currentFolderName = backend.get_folder_name(root.currentFolderUrl)
        if (openDialog) openDialog.currentFolder = root.currentFolderUrl
        if (saveDialog) saveDialog.currentFolder = root.currentFolderUrl

        backend.watch_folder(root.currentFolderUrl)
        reloadFolderFiles(root, backend)

        if (!hasInitialDoc) {
            if (root.folderFilesModel.count > 0) {
                var firstFile = null
                for (var i = 0; i < root.folderFilesModel.count; ++i) {
                    var candidate = root.folderFilesModel.get(i)
                    if (candidate && !candidate.name.startsWith("_") && !candidate.isSystem) {
                        firstFile = candidate
                        break
                    }
                }
                if (!firstFile) firstFile = root.folderFilesModel.get(0)

                var content = backend.read_file(firstFile.fileUrl)
                var cleanFirst = root.stripExt(firstFile.name)
                root.tabsModel.setProperty(0, "title", cleanFirst)
                root.tabsModel.setProperty(0, "fileUrl", firstFile.fileUrl)
                root.tabsModel.setProperty(0, "content", content)
                root.currentFileName = cleanFirst
                root.currentFileUrl = firstFile.fileUrl
                root.primaryFileName = cleanFirst
                Tabs.syncEditorsFromModel(root)
            } else {
                var res = backend.create_file_in_folder(root.currentFolderUrl, "Новый документ")
                if (res && res.success) {
                    var cleanNew = root.stripExt(res.fileName)
                    root.tabsModel.setProperty(0, "title", cleanNew)
                    root.tabsModel.setProperty(0, "fileUrl", res.fileUrl)
                    root.currentFileName = cleanNew
                    root.currentFileUrl = res.fileUrl
                    root.primaryFileName = cleanNew
                    reloadFolderFiles(root, backend)
                }
            }
        }
        root.reloadHotkeys()
    }
}

function spawnClonedAppWindow(root, fileUrl, title, content, wx, wy, ww, wh) {
    var comp = Qt.createComponent("window.qml")
    if (comp.status === Component.Ready) {
        var winW = Math.max(750, ww || 850)
        var winH = Math.max(550, wh || 600)
        var appWin = root.Window.window
        var newWin = comp.createObject(null, {
            x: wx || (appWin ? (appWin.x + 50) : 100),
            y: wy || (appWin ? (appWin.y + 50) : 100),
            width: winW,
            height: winH,
            initialFileUrl: fileUrl || "",
            initialTitle: title || "Документ",
            initialContent: content || "",
            startWithSidebarHidden: true
        })
        if (newWin && fileUrl) {
            registerExternalFile(root, fileUrl, newWin)
        }
        return newWin
    } else {
        console.log("[QML] Ошибка создания нового окна приложения:", comp.errorString())
        return null
    }
}

function registerExternalFile(root, fUrl, win) {
    if (!fUrl) return
    var list = (root.externalWindowFiles || []).slice()
    if (list.indexOf(fUrl) === -1) {
        list.push(fUrl)
        root.externalWindowFiles = list
    }
    if (win && win.closing) {
        win.closing.connect(function() {
            unregisterExternalFile(root, fUrl)
        })
    }
}

function unregisterExternalFile(root, fUrl) {
    var list = (root.externalWindowFiles || []).slice()
    var idx = list.indexOf(fUrl)
    if (idx !== -1) {
        list.splice(idx, 1)
        root.externalWindowFiles = list
    }
}

function closeActiveTab(root) {
    if (root.tabsModel.count === 0) return
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
            if (splitLayout.primaryBar && typeof splitLayout.primaryBar.toggleHeaderFooter === "function") {
                splitLayout.primaryBar.toggleHeaderFooter()
            }
            if (splitLayout.isSplit && splitLayout.secondaryBar && typeof splitLayout.secondaryBar.toggleHeaderFooter === "function") {
                splitLayout.secondaryBar.toggleHeaderFooter()
            }
            break
        case "toggle_footer":
            if (splitLayout.primaryBar && typeof splitLayout.primaryBar.toggleFooterOnly === "function") {
                splitLayout.primaryBar.toggleFooterOnly()
            }
            if (splitLayout.isSplit && splitLayout.secondaryBar && typeof splitLayout.secondaryBar.toggleFooterOnly === "function") {
                splitLayout.secondaryBar.toggleFooterOnly()
            }
            break
        case "toggle_header":
            if (splitLayout.primaryBar && typeof splitLayout.primaryBar.toggleHeaderOnly === "function") {
                splitLayout.primaryBar.toggleHeaderOnly()
            }
            if (splitLayout.isSplit && splitLayout.secondaryBar && typeof splitLayout.secondaryBar.toggleHeaderOnly === "function") {
                splitLayout.secondaryBar.toggleHeaderOnly()
            }
            break
        case "toggle_sidebar":
            root.toggleSidebar()
            break
        case "toggle_split":
            root.toggleSplit()
            break
        case "toggle_centered_mode":
            if (splitLayout.primaryBar) {
                splitLayout.primaryBar.isCenteredMode = !splitLayout.primaryBar.isCenteredMode
            }
            if (splitLayout.isSplit && splitLayout.secondaryBar) {
                splitLayout.secondaryBar.isCenteredMode = splitLayout.primaryBar.isCenteredMode
            }
            break
        case "close_tab":
            closeActiveTab(root)
            break
        case "new_tab":
            root.createNewTab()
            break
        case "open_file":
            openDialog.open()
            break
        case "save_file":
            Logic.saveFile(root, saveDialog, backend)
            break
        case "detach_window":
            var targetIdx = (root.isSplit && root.activePane === 1) ? root.secondaryTabIndex : root.primaryTabIndex
            Tabs.detachTab(root, targetIdx >= 0 ? targetIdx : 0)
            break
        case "toggle_bold":
            if (splitLayout && splitLayout.activeEditorArea) {
                Markdown.toggleBold(splitLayout.activeEditorArea)
            }
            break
        case "toggle_italic":
            if (splitLayout && splitLayout.activeEditorArea) {
                Markdown.toggleItalic(splitLayout.activeEditorArea)
            }
            break
        case "toggle_graph":
            root.isGraphVisible = !root.isGraphVisible
            break
    }
}
