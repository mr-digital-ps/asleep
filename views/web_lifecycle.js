// web_lifecycle.js — Управление жизненным циклом рабочего пространства, окнами и внешними событиями
.import "action_dispatcher.js" as Dispatcher

function stripExt(name) {
    if (!name) return ""
    return name.replace(/\.md$/i, "")
}

function toggleGraph(splitLayout) {
    if (splitLayout && typeof splitLayout.toggleGraph === "function") {
        splitLayout.toggleGraph()
    }
}

function toggleLocalGraph(splitLayout) {
    if (splitLayout && typeof splitLayout.toggleLocalGraph === "function") {
        splitLayout.toggleLocalGraph()
    }
}

function closeGraph(splitLayout) {
    if (splitLayout && typeof splitLayout.closeGraph === "function") {
        splitLayout.closeGraph()
    }
}

function closeAllGraphs(splitLayout) {
    if (splitLayout && typeof splitLayout.closeAllGraphs === "function") {
        splitLayout.closeAllGraphs()
    }
}

function toggleSearch(splitLayout) {
    if (splitLayout && typeof splitLayout.toggleSearch === "function") {
        splitLayout.toggleSearch()
    }
}

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

function initWebRoot(root, backend, Tabs, openDialog, saveDialog) {
    if (!root) return
    reloadAppConfig(root, root.autoSaveTimer, backend)
    initializeWorkspace(root, backend, Tabs, openDialog, saveDialog)
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
    var comp = Qt.createComponent(root && root.windowComponentUrl ? root.windowComponentUrl : "../../views/window.qml")
    if (comp.status === 1) {
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
            initialContent: content || ""
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

function saveFile(root, saveDialog, backend) {
    Dispatcher.saveFile(root, saveDialog, backend)
}

function dispatchAction(root, splitLayout, openDialog, saveDialog, backend, Markdown, Tabs, action) {
    Dispatcher.dispatchAction(root, splitLayout, openDialog, saveDialog, backend, Markdown, Tabs, action)
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
    var cleanName = (root && typeof root.stripExt === "function") ? root.stripExt(name) : name

    if (root.openFileInSplit) {
        root.openFileInSplit = false
        if (root.tabsModel.count === 0 || root.primaryTabIndex < 0) {
            root.tabsModel.clear()
            root.tabsModel.append({
                title: cleanName,
                fileUrl: selectedFile,
                content: content,
                isDetached: false
            })
            root.primaryTabIndex = 0
            root.secondaryTabIndex = -1
            root.isSplit = false
            root.activePane = 0
            Tabs.syncEditorsFromModel(root)
            Tabs.setActivePane(root, 0)
            return
        }

        root.tabsModel.append({
            title: cleanName,
            fileUrl: selectedFile,
            content: content,
            isDetached: false
        })
        root.secondaryTabIndex = root.tabsModel.count - 1
        root.isSplit = true
        root.activePane = 1
        root.currentTabIndex = root.secondaryTabIndex
        Tabs.syncEditorsFromModel(root)
        Tabs.setActivePane(root, 1)
        return
    }

    var targetIndex = (root.isSplit && root.activePane === 1) ? root.secondaryTabIndex : root.primaryTabIndex
    var curTab = (targetIndex >= 0 && targetIndex < root.tabsModel.count) ? root.tabsModel.get(targetIndex) : null

    if (curTab && !curTab.isDetached && curTab.fileUrl === "" && root.editorArea && root.editorArea.text === "") {
        root.tabsModel.setProperty(targetIndex, "title", cleanName)
        root.tabsModel.setProperty(targetIndex, "fileUrl", selectedFile)
        root.tabsModel.setProperty(targetIndex, "content", content)
        Tabs.syncEditorsFromModel(root)
    } else {
        root.tabsModel.append({
            title: cleanName,
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

function getOpenFileUrls(tabsModel, primaryTabIndex, secondaryTabIndex, isSplit) {
    var list = []
    if (tabsModel) {
        for (var i = 0; i < tabsModel.count; i++) {
            var item = tabsModel.get(i)
            var u = item ? item.fileUrl : ""
            if (u && list.indexOf(u) === -1) list.push(u)
        }
    }
    var pUrl = (tabsModel && tabsModel.count > primaryTabIndex && primaryTabIndex >= 0) ? tabsModel.get(primaryTabIndex).fileUrl : ""
    var sUrl = (isSplit && tabsModel && tabsModel.count > secondaryTabIndex && secondaryTabIndex >= 0) ? tabsModel.get(secondaryTabIndex).fileUrl : ""
    if (pUrl && list.indexOf(pUrl) === -1) list.push(pUrl)
    if (sUrl && list.indexOf(sUrl) === -1) list.push(sUrl)
    return list
}

function reloadAppConfig(root, autoSaveTimer, backend) {
    if (!backend || typeof backend.get_app_config !== "function") return
    try {
        var appCfg = backend.get_app_config()
        if (appCfg && typeof appCfg.auto_save_delay_ms === "number" && appCfg.auto_save_delay_ms > 0 && autoSaveTimer) {
            autoSaveTimer.interval = appCfg.auto_save_delay_ms
        }
        if (typeof backend.get_target_fps === "function" && root) {
            root.targetFps = backend.get_target_fps()
        }
    } catch(e) {}
}

function toggleProjectStructure(root, splitLayout, backend, Tabs) {
    if (!root || !backend) return

    var activeBar = (root.isSplit && root.activePane === 1) ? splitLayout.secondaryBar : splitLayout.primaryBar
    var curName = activeBar ? activeBar.fileName : ""
    var curUrl = activeBar ? activeBar.fileUrl : ""

    var isStructOpen = (typeof backend.is_project_structure_file === "function") && backend.is_project_structure_file(curName)
    if (isStructOpen) {
        if (activeBar && activeBar.isOutlineMode) {
            activeBar.showTextMode()
            return
        }
        if (activeBar) {
            activeBar.isOutlineMode = false
        }
        if (root.previousFileUrlBeforeStructure) {
            root.openFileFromFolder(root.previousFileUrlBeforeStructure, root.previousFileNameBeforeStructure, false)
        } else if (root.tabsModel.count > 1) {
            for (var t = 0; t < root.tabsModel.count; t++) {
                var tabItem = root.tabsModel.get(t)
                if (tabItem && tabItem.fileUrl && tabItem.fileUrl !== curUrl) {
                    root.openFileFromFolder(tabItem.fileUrl, tabItem.title, false)
                    break
                }
            }
        }
        return
    }

    if (Tabs && typeof Tabs.syncCurrentPaneText === "function") {
        Tabs.syncCurrentPaneText(root)
    }

    root.previousFileUrlBeforeStructure = curUrl
    root.previousFileNameBeforeStructure = curName
    root.highlightStructureItem = stripExt(curName)

    var info = backend.sync_project_structure_file(root.currentFolderUrl)
    if (info && info.fileUrl) {
        root.openFileFromFolder(info.fileUrl, info.fileName, false)
    }
}

function handleActionRequested(root, backend, action) {
    if (!root) return
    var win = root.appWindow || (root.Window ? root.Window.window : null)
    var count = (backend && typeof backend.get_window_count === "function") ? backend.get_window_count() : 1
    if (count > 1 && win) {
        var isWinActive = Boolean(win.active) || (typeof Qt !== "undefined" && Qt.application && Qt.application.activeWindow && win === Qt.application.activeWindow)
        if (!isWinActive) {
            return
        }
    }
    root.executeAction(action)
}

function handleGlobalKeyEvent(root, splitLayout, hotkeyManager, backend, event) {
    if (hotkeyManager && hotkeyManager.handleKeyEvent(event)) {
        return true
    }
    var activeBar = (root.isSplit && root.activePane === 1) ? splitLayout.secondaryBar : splitLayout.primaryBar
    if (event.key === 32) { // Qt.Key_Space
        var isAlt = Boolean(event.modifiers & 0x08000000) // Qt.AltModifier
        var inHistory = activeBar && (activeBar.isHistoricalMode || activeBar.isHistoryMode)
        if (isAlt || inHistory) {
            if (activeBar && typeof activeBar.toggleHistoryPlayback === "function") {
                var fromStart = Boolean(event.modifiers & 0x02000000) || Boolean(event.modifiers & 0x04000000) // ShiftModifier | ControlModifier
                activeBar.toggleHistoryPlayback(fromStart)
                event.accepted = true
                return true
            }
        }
    }
    if (event.key === 16777216) { // Qt.Key_Escape
        var curName = activeBar ? activeBar.fileName : ""
        if (activeBar && activeBar.isSearchMode) {
            activeBar.closeSearch()
            event.accepted = true
            return true
        }
        var isStructEsc = (backend && typeof backend.is_project_structure_file === "function") && backend.is_project_structure_file(curName)
        if (isStructEsc) {
            root.toggleProjectStructure()
            event.accepted = true
            return true
        }
        if (root.isGraphVisible) {
            root.closeGraph()
            event.accepted = true
            return true
        }
        if (activeBar && activeBar.isOutlineMode) {
            activeBar.showTextMode()
            event.accepted = true
            return true
        }
    }
    return false
}

function handleNodeSelected(root, splitLayout, fUrl, lbl) {
    if (!root || !splitLayout) return
    var targetBar = (root.isSplit && root.activePane === 1) ? splitLayout.secondaryBar : splitLayout.primaryBar
    if (targetBar) {
        targetBar.isOutlineMode = false
    }
    root.openFileFromFolder(fUrl, lbl, false)
}

function handleFileDragStarted(root, dragTrackerTimer, paneIdx, url, name, gx, gy) {
    if (!root) return
    root.isFileDragging = true
    root.draggingFileUrl = url
    root.draggingFileName = name
    root.draggingPaneIndex = paneIdx
    if (dragTrackerTimer) dragTrackerTimer.running = true
}

function openFileFromFolder(root, Tabs, fileUrl, fileName, isShift) {
    if (!root) return
    root.closeGraph()
    if (Tabs && typeof Tabs.openFileFromFolder === "function") {
        Tabs.openFileFromFolder(root, fileUrl, fileName, isShift)
    }
}

function createNewTab(root, Tabs, isShift) {
    if (!root) return
    root.closeGraph()
    if (Tabs && typeof Tabs.createNewTab === "function") {
        Tabs.createNewTab(root, isShift)
    }
}

function switchToTab(root, Tabs, index) {
    if (!root) return
    root.closeGraph()
    if (Tabs && typeof Tabs.switchToTab === "function") {
        Tabs.switchToTab(root, index)
    }
}

