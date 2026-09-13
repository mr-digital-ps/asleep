// web_lifecycle.js — Управление жизненным циклом рабочего пространства, окнами и внешними событиями
.import "action_dispatcher.js" as Dispatcher

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
    var appWin = (root && root.appWindow) ? root.appWindow : (root && root.Window ? root.Window.window : null)
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
        var appWin = (root && root.appWindow) ? root.appWindow : (root && root.Window ? root.Window.window : null)
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
    Dispatcher.closeActiveTab(root)
}

function dispatchAction(root, splitLayout, openDialog, saveDialog, backend, Markdown, Tabs, Logic, action) {
    Dispatcher.dispatchAction(root, splitLayout, openDialog, saveDialog, backend, Markdown, Tabs, Logic, action)
}

function handleAutoSave(root, splitLayout, backend) {
    if (!backend || !root || !root.tabsModel) return
    if (root.primaryTabIndex >= 0 && root.primaryTabIndex < root.tabsModel.count) {
        var pTab = root.tabsModel.get(root.primaryTabIndex)
        if (pTab && pTab.fileUrl && splitLayout && splitLayout.primaryBar) {
            backend.save_file(pTab.fileUrl, splitLayout.primaryBar.text)
        }
    }
    if (root.isSplit && root.secondaryTabIndex >= 0 && root.secondaryTabIndex < root.tabsModel.count) {
        var sTab = root.tabsModel.get(root.secondaryTabIndex)
        if (sTab && sTab.fileUrl && splitLayout && splitLayout.secondaryBar) {
            backend.save_file(sTab.fileUrl, splitLayout.secondaryBar.text)
        }
    }
}

function handleFolderAccepted(root, backend, folderUrl) {
    if (!root) return
    root.currentFolderUrl = folderUrl
    if (backend) {
        root.currentFolderName = backend.get_folder_name(root.currentFolderUrl)
        backend.save_last_folder(root.currentFolderUrl)
        backend.watch_folder(root.currentFolderUrl)
    }
    reloadFolderFiles(root, backend)
}

function handleFileOpenAccepted(root, backend, Tabs, selectedFile) {
    if (!root || !backend) return
    var content = backend.read_file(selectedFile)
    var name = backend.get_filename(selectedFile)

    var targetIndex = (root.isSplit && root.activePane === 1) ? root.secondaryTabIndex : root.primaryTabIndex
    var curTab = (targetIndex >= 0 && targetIndex < root.tabsModel.count) ? root.tabsModel.get(targetIndex) : null

    if (curTab && !curTab.isDetached && curTab.fileUrl === "" && root.editorArea && root.editorArea.text === "") {
        root.tabsModel.setProperty(targetIndex, "title", name)
        root.tabsModel.setProperty(targetIndex, "fileUrl", selectedFile)
        root.tabsModel.setProperty(targetIndex, "content", content)
        Tabs.syncEditorsFromModel(root)
    } else {
        root.tabsModel.append({
            title: name,
            fileUrl: selectedFile,
            content: content,
            isDetached: false
        })
        root.switchToTab(root.tabsModel.count - 1)
    }
}

function handleFileSaveAccepted(root, backend, Tabs, selectedFile) {
    if (!root || !backend) return
    var targetIndex = (root.isSplit && root.activePane === 1) ? root.secondaryTabIndex : root.primaryTabIndex
    var text = (root.editorArea ? root.editorArea.text : "")
    backend.save_file(selectedFile, text)
    root.currentFileUrl = selectedFile
    root.currentFileName = backend.get_filename(selectedFile)
    if (root.tabsModel.count > 0 && targetIndex >= 0 && targetIndex < root.tabsModel.count) {
        root.tabsModel.setProperty(targetIndex, "title", root.currentFileName)
        root.tabsModel.setProperty(targetIndex, "fileUrl", root.currentFileUrl)
        root.tabsModel.setProperty(targetIndex, "content", text)
        Tabs.syncEditorsFromModel(root)
    }
}

function handleSidebarFolderClicked(root, backend, openDialog, saveDialog, folderDialog) {
    if (backend && typeof backend.choose_folder_dialog === "function") {
        var res = backend.choose_folder_dialog(root.currentFolderUrl)
        if (res && res.success) {
            root.currentFolderUrl = res.folderUrl
            root.currentFolderName = res.folderName
            if (openDialog) openDialog.currentFolder = res.folderUrl
            if (saveDialog) saveDialog.currentFolder = res.folderUrl
            reloadFolderFiles(root, backend)
        }
    } else if (folderDialog && typeof folderDialog.open === "function") {
        folderDialog.open()
    }
}

function handleSidebarConfigClicked(root, backend) {
    if (backend && typeof backend.open_or_create_folder_config === "function") {
        var res = backend.open_or_create_folder_config(root.currentFolderUrl)
        if (res && res.success && res.fileUrl) {
            root.openFileFromFolder(res.fileUrl, res.fileName, false)
        }
    }
}

function handleFileDeleteRequested(root, backend, fUrl) {
    if (!root || !root.tabsModel) return
    for (var i = root.tabsModel.count - 1; i >= 0; i--) {
        if (root.tabsModel.get(i).fileUrl === fUrl) {
            root.closeTab(i)
        }
    }
    if (backend && typeof backend.delete_file === "function") {
        backend.delete_file(fUrl)
    }
}

function handleFileRenameRequested(root, backend, fUrl, newName) {
    if (!root || !backend) return
    var res = backend.rename_file(fUrl, newName)
    if (res && res.success) {
        for (var i = 0; i < root.tabsModel.count; i++) {
            if (root.tabsModel.get(i).fileUrl === fUrl) {
                root.tabsModel.setProperty(i, "fileUrl", res.fileUrl)
                root.tabsModel.setProperty(i, "title", res.fileName)
                if (i === root.primaryTabIndex) root.primaryFileName = res.fileName
                if (i === root.secondaryTabIndex) root.secondaryFileName = res.fileName
            }
        }
        if (root.currentFileUrl === fUrl) {
            root.currentFileUrl = res.fileUrl
            root.currentFileName = res.fileName
        }
    }
}

function handleTabDragStarted(root, dragTrackerTimer, url, name, gx, gy) {
    root.isFileDragging = true
    root.draggingFileUrl = url
    root.draggingFileName = name
    root.draggingPaneIndex = -1
    if (dragTrackerTimer) dragTrackerTimer.running = true
}

function handleToggleGraphMode(root, backend, toGraph) {
    if (!root) return
    if (toGraph) {
        root.isGraphVisible = true
    } else {
        if (backend && typeof backend.sync_graph_file === "function") {
            var res = backend.sync_graph_file(root.currentFolderUrl)
            if (res && res.fileUrl) {
                root.openFileFromFolder(res.fileUrl, res.fileName, false)
            }
        }
        root.isGraphVisible = false
    }
}

