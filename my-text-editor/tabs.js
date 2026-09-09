// tabs.js — чистая логика управления вкладками, сплит-режимом и меж-оконным объединением

// =============================================================================
// СИНХРОНИЗАЦИЯ МОДЕЛИ И РЕДАКТОРОВ
// =============================================================================

function syncCurrentPaneText(root) {
    if (!root.splitLayout) return

    if (root.primaryTabIndex >= 0 && root.primaryTabIndex < root.tabsModel.count) {
        root.tabsModel.setProperty(root.primaryTabIndex, "content", root.splitLayout.primaryBar.text)
    }
    if (root.isSplit && root.secondaryTabIndex >= 0 && root.secondaryTabIndex < root.tabsModel.count) {
        root.tabsModel.setProperty(root.secondaryTabIndex, "content", root.splitLayout.secondaryBar.text)
    }
}

function syncEditorsFromModel(root) {
    if (!root.splitLayout) return

    if (root.primaryTabIndex >= 0 && root.primaryTabIndex < root.tabsModel.count) {
        let pTab = root.tabsModel.get(root.primaryTabIndex)
        if (root.splitLayout.primaryBar && root.splitLayout.primaryBar.text !== pTab.content) {
            root.splitLayout.primaryBar.text = pTab.content
        }
        root.primaryFileName = pTab.title
    } else {
        root.primaryFileName = ""
        if (root.splitLayout.primaryBar) root.splitLayout.primaryBar.text = ""
    }

    if (root.isSplit && root.secondaryTabIndex >= 0 && root.secondaryTabIndex < root.tabsModel.count) {
        let sTab = root.tabsModel.get(root.secondaryTabIndex)
        if (root.splitLayout.secondaryBar && root.splitLayout.secondaryBar.text !== sTab.content) {
            root.splitLayout.secondaryBar.text = sTab.content
        }
        root.secondaryFileName = sTab.title
    } else {
        root.secondaryFileName = ""
        if (root.splitLayout.secondaryBar) root.splitLayout.secondaryBar.text = ""
    }

    let activeIdx = (root.isSplit && root.activePane === 1) ? root.secondaryTabIndex : root.primaryTabIndex
    if (activeIdx >= 0 && activeIdx < root.tabsModel.count) {
        let aTab = root.tabsModel.get(activeIdx)
        root.currentFileName = aTab.title || ""
        root.currentFileUrl = aTab.fileUrl || ""
        root.currentTabIndex = activeIdx
    } else {
        root.currentFileName = ""
        root.currentFileUrl = ""
        root.currentTabIndex = -1
    }
}

// =============================================================================
// ПЕРЕКЛЮЧЕНИЕ, СОЗДАНИЕ И ЗАКРЫТИЕ ВКЛАДОК
// =============================================================================

function switchToTab(root, index) {
    if (index < 0 || index >= root.tabsModel.count) return

    syncCurrentPaneText(root)

    if (root.isSplit) {
        if (root.activePane === 1) {
            root.secondaryTabIndex = index
        } else {
            root.primaryTabIndex = index
        }
    } else {
        root.primaryTabIndex = index
    }

    root.currentTabIndex = index
    let tab = root.tabsModel.get(index)
    root.currentFileName = tab.title
    root.currentFileUrl = tab.fileUrl
    syncEditorsFromModel(root)
}

function createNewTab(root) {
    syncCurrentPaneText(root)

    let nextNum = root.tabsModel.count + 1
    let initialTitle = "Документ " + nextNum
    let initialUrl = ""

    if (typeof backend !== "undefined" && backend && root.currentFolderUrl) {
        let res = backend.create_file_in_folder(root.currentFolderUrl, initialTitle)
        if (res && res.success) {
            initialTitle = res.fileName
            initialUrl = res.fileUrl
        }
    }

    root.tabsModel.append({
        title: initialTitle,
        fileUrl: initialUrl,
        content: ""
    })
    switchToTab(root, root.tabsModel.count - 1)
}

function closeTab(root, index) {
    if (index < 0 || index >= root.tabsModel.count) return

    // Если закрывается вкладка в режиме сплита
    if (root.isSplit) {
        if (index === root.secondaryTabIndex) {
            root.secondaryTabIndex = -1
            root.isSplit = false
            root.activePane = 0
        } else if (index === root.primaryTabIndex) {
            root.primaryTabIndex = root.secondaryTabIndex
            root.secondaryTabIndex = -1
            root.isSplit = false
            root.activePane = 0
        }
    }

    root.tabsModel.remove(index)

    // Все вкладки закрыты — оставляем Main полностью пустым!
    if (root.tabsModel.count === 0) {
        root.primaryTabIndex = -1
        root.secondaryTabIndex = -1
        root.currentTabIndex = -1
        root.primaryFileName = ""
        root.secondaryFileName = ""
        root.currentFileName = ""
        root.currentFileUrl = ""
        root.isSplit = false
        root.activePane = 0
        if (root.splitLayout) {
            if (root.splitLayout.primaryBar) root.splitLayout.primaryBar.text = ""
            if (root.splitLayout.secondaryBar) root.splitLayout.secondaryBar.text = ""
        }
        return
    }

    if (root.primaryTabIndex >= root.tabsModel.count) {
        root.primaryTabIndex = root.tabsModel.count - 1
    } else if (root.primaryTabIndex > index) {
        root.primaryTabIndex--
    }

    if (root.secondaryTabIndex >= root.tabsModel.count) {
        root.secondaryTabIndex = root.tabsModel.count - 1
    } else if (root.secondaryTabIndex > index) {
        root.secondaryTabIndex--
    }

    if (root.currentTabIndex >= root.tabsModel.count) {
        root.currentTabIndex = root.tabsModel.count - 1
    } else if (root.currentTabIndex > index) {
        root.currentTabIndex--
    }

    if (root.primaryTabIndex >= 0) {
        switchToTab(root, root.primaryTabIndex)
    } else if (root.tabsModel.count > 0) {
        switchToTab(root, 0)
    }
}

function renameTab(root, index, newTitle) {
    if (index < 0 || index >= root.tabsModel.count) return
    let tab = root.tabsModel.get(index)
    let finalTitle = newTitle

    if (typeof backend !== "undefined" && backend && tab.fileUrl) {
        let res = backend.rename_file(tab.fileUrl, newTitle)
        if (res && res.success) {
            finalTitle = res.fileName
            root.tabsModel.setProperty(index, "fileUrl", res.fileUrl)
            if (index === root.currentTabIndex) {
                root.currentFileUrl = res.fileUrl
            }
        }
    }

    root.tabsModel.setProperty(index, "title", finalTitle)

    if (index === root.primaryTabIndex) {
        root.primaryFileName = finalTitle
        if (root.activePane === 0) root.currentFileName = finalTitle
    }
    if (root.isSplit && index === root.secondaryTabIndex) {
        root.secondaryFileName = finalTitle
        if (root.activePane === 1) root.currentFileName = finalTitle
    }
}

// =============================================================================
// УПРАВЛЕНИЕ РЕЖИМОМ СПЛИТА (SPLIT VIEW)
// =============================================================================

function setActivePane(root, paneIndex) {
    root.activePane = paneIndex
    let targetIndex = (paneIndex === 1) ? root.secondaryTabIndex : root.primaryTabIndex
    root.currentTabIndex = targetIndex
    if (targetIndex >= 0 && targetIndex < root.tabsModel.count) {
        let tab = root.tabsModel.get(targetIndex)
        root.currentFileName = tab.title || ""
        root.currentFileUrl = tab.fileUrl || ""
    } else {
        root.currentFileName = ""
        root.currentFileUrl = ""
    }
}

function closeSplit(root) {
    syncCurrentPaneText(root)
    root.isSplit = false

    if (root.activePane === 1 && root.secondaryTabIndex >= 0) {
        root.primaryTabIndex = root.secondaryTabIndex
        root.currentTabIndex = root.secondaryTabIndex
    } else {
        root.currentTabIndex = root.primaryTabIndex
    }

    root.secondaryTabIndex = -1
    root.activePane = 0
    syncEditorsFromModel(root)
}

function toggleSplit(root) {
    if (root.isSplit) {
        closeSplit(root)
    } else {
        if (root.tabsModel.count === 0) {
            createNewTab(root)
            return
        }
        let curPrimary = root.primaryTabIndex
        let otherIdx = -1
        for (let i = 0; i < root.tabsModel.count; i++) {
            if (i !== curPrimary) { otherIdx = i; break; }
        }
        if (otherIdx === -1) {
            let nextNum = root.tabsModel.count + 1
            root.tabsModel.append({
                title: "Документ " + nextNum,
                fileUrl: "",
                content: ""
            })
            otherIdx = root.tabsModel.count - 1
        }
        root.isSplit = true
        root.primaryTabIndex = curPrimary
        root.secondaryTabIndex = otherIdx
        root.activePane = 1
        root.currentTabIndex = otherIdx
        syncEditorsFromModel(root)
    }
}

function handlePrimaryTextChanged(root, text) {
    if (root.primaryTabIndex >= 0 && root.primaryTabIndex < root.tabsModel.count) {
        root.tabsModel.setProperty(root.primaryTabIndex, "content", text)
    }
}

function handleSecondaryTextChanged(root, text) {
    if (root.isSplit && root.secondaryTabIndex >= 0 && root.secondaryTabIndex < root.tabsModel.count) {
        root.tabsModel.setProperty(root.secondaryTabIndex, "content", text)
    }
}

// =============================================================================
// МЕЖ-ОКОННОЕ ОБЪЕДИНЕНИЕ И ОТКРЕПЛЕНИЕ (CROSS-WINDOW DOCKING)
// =============================================================================

function openInNewWindow(root, fileUrl, fileName, wx, wy) {
    let content = ""
    for (let i = 0; i < root.tabsModel.count; i++) {
        let t = root.tabsModel.get(i)
        if (t.fileUrl === fileUrl) {
            if (i === root.primaryTabIndex && root.splitLayout && root.splitLayout.primaryBar) {
                content = root.splitLayout.primaryBar.text
            } else if (i === root.secondaryTabIndex && root.splitLayout && root.splitLayout.secondaryBar) {
                content = root.splitLayout.secondaryBar.text
            } else {
                content = t.content || ""
            }
            break
        }
    }
    if (!content && fileUrl && typeof backend !== "undefined" && backend) {
        content = backend.read_file(fileUrl)
    }

    root.spawnClonedAppWindow(fileUrl, fileName, content, wx, wy, 850, 600)
}

function pollCursorState(root, sideBar) {
    if (typeof backend !== "undefined" && backend && typeof backend.get_cursor_state === "function") {
        let state = backend.get_cursor_state()
        if (!state.leftPressed) {
            if (root.dragTrackerTimer) root.dragTrackerTimer.running = false
            handleFileDragEnded(root, root.draggingFileUrl, root.draggingFileName, state.x, state.y)
            return
        }
        handleFileDragMoved(root, state.x, state.y)
    }
}

function handleFileDragMoved(root, gx, gy) {
    let appWin = root.Window.window
    if (!appWin) return

    let sideW = root.sideBar ? (root.sideBar.isSidebarVisible ? root.sideBar.currentWidth : 0) : 180
    let isInsideCurrentWin = (gx >= appWin.x && gx <= (appWin.x + appWin.width) &&
                              gy >= appWin.y && gy <= (appWin.y + appWin.height))

    if (isInsideCurrentWin) {
        // Мышь внутри текущего окна
        if (typeof backend !== "undefined" && backend && typeof backend.clear_all_drop_zones === "function") {
            backend.clear_all_drop_zones()
        }

        let localX = gx - appWin.x
        if (localX > sideW) {
            // Мышь над рабочей областью редактора (справа от сайдбара)
            let editorW = appWin.width - sideW
            let relXInEditor = (localX - sideW) / Math.max(1, editorW)

            if (relXInEditor < 0.35) {
                root.dropZone = "left"
            } else if (relXInEditor > 0.65) {
                root.dropZone = "right"
            } else {
                root.dropZone = "center"
            }
        } else {
            root.dropZone = ""
        }
        return
    }

    // Мышь снаружи текущего окна — сбрасываем подсветку текущего окна
    root.dropZone = ""

    // Проверяем, находится ли курсор над другим окном приложения
    if (typeof backend !== "undefined" && backend && typeof backend.find_target_window_at === "function") {
        let res = backend.find_target_window_at(gx, gy, appWin)
        if (res && res.found && res.targetWin) {
            backend.set_window_drop_zone(res.targetWin, res.zone)
            return
        }
    }

    if (typeof backend !== "undefined" && backend && typeof backend.clear_all_drop_zones === "function") {
        backend.clear_all_drop_zones()
    }
}

function handleFileDragEnded(root, fileUrl, fileName, gx, gy) {
    if (root.dragTrackerTimer) {
        root.dragTrackerTimer.running = false
    }
    if (typeof backend !== "undefined" && backend && typeof backend.clear_all_drop_zones === "function") {
        backend.clear_all_drop_zones()
    }

    if (!fileUrl && root.draggingFileUrl) {
        fileUrl = root.draggingFileUrl
        fileName = root.draggingFileName
    }
    root.draggingFileUrl = ""
    root.draggingFileName = ""

    let savedZone = root.dropZone
    root.dropZone = ""

    let appWin = root.Window.window
    let sideW = root.sideBar ? (root.sideBar.isSidebarVisible ? root.sideBar.currentWidth : 0) : 180
    let isInsideCurrentWin = appWin && (gx >= appWin.x && gx <= (appWin.x + appWin.width) &&
                                         gy >= appWin.y && gy <= (appWin.y + appWin.height))

    let content = ""
    let srcIndex = -1

    for (let i = 0; i < root.tabsModel.count; i++) {
        let t = root.tabsModel.get(i)
        if (t.fileUrl === fileUrl) {
            srcIndex = i
            if (i === root.primaryTabIndex && root.splitLayout && root.splitLayout.primaryBar) {
                content = root.splitLayout.primaryBar.text
            } else if (i === root.secondaryTabIndex && root.splitLayout && root.splitLayout.secondaryBar) {
                content = root.splitLayout.secondaryBar.text
            } else {
                content = t.content || ""
            }
            break
        }
    }
    if (!content && fileUrl && typeof backend !== "undefined" && backend) {
        content = backend.read_file(fileUrl)
    }

    // 1. Сброс внутри текущего окна:
    if (isInsideCurrentWin) {
        let localX = gx - appWin.x
        if (localX > sideW) {
            dockFileInCurrentWindow(root, fileUrl, fileName, content, savedZone || "right")
        }
        return
    }

    // 2. Сброс на другое окно приложения:
    if (typeof backend !== "undefined" && backend && typeof backend.find_target_window_at === "function") {
        let res = backend.find_target_window_at(gx, gy, appWin)
        if (res && res.found && res.targetRoot) {
            res.targetRoot.dockExternalTab(fileUrl, fileName, content, res.zone)
            if (srcIndex !== -1) {
                closeTab(root, srcIndex)
            }
            return
        }
    }

    // 3. Сброс на пустой рабочий стол или второй монитор — спавним полноценное окно!
    root.spawnClonedAppWindow(fileUrl, fileName, content, Math.round(gx - 400), Math.round(gy - 30), 850, 600)
    if (srcIndex !== -1) {
        closeTab(root, srcIndex)
    }
}

// Встраивание файла в сплит-экран текущего окна
function dockFileInCurrentWindow(root, fileUrl, fileName, content, zone) {
    if (!fileUrl && !fileName) return

    // 1. Проверяем, есть ли уже этот файл в модели вкладок
    let tabIndex = -1
    for (let i = 0; i < root.tabsModel.count; i++) {
        if (root.tabsModel.get(i).fileUrl === fileUrl) {
            tabIndex = i
            break
        }
    }

    if (tabIndex === -1) {
        root.tabsModel.append({
            title: fileName,
            fileUrl: fileUrl,
            content: content || ""
        })
        tabIndex = root.tabsModel.count - 1
    }

    if (zone === "left" || zone === "right") {
        root.isSplit = true
        if (zone === "left") {
            let oldPrimary = root.primaryTabIndex
            root.primaryTabIndex = tabIndex
            root.secondaryTabIndex = (oldPrimary !== -1 && oldPrimary !== tabIndex) ? oldPrimary : getAnotherAvailableTab(root, tabIndex)
            root.activePane = 0
        } else {
            root.secondaryTabIndex = tabIndex
            root.activePane = 1
        }
        syncEditorsFromModel(root)
    } else {
        switchToTab(root, tabIndex)
    }
}

// Приём внешнего документа из другого окна
function dockExternalTab(root, fileUrl, fileName, content, zone) {
    if (zone === "left" || zone === "right") {
        // Добавляем вкладку и открываем сплит
        root.tabsModel.append({
            title: fileName,
            fileUrl: fileUrl,
            content: content
        })
        let newIdx = root.tabsModel.count - 1

        if (root.tabsModel.count <= 1) {
            root.primaryTabIndex = 0
            syncEditorsFromModel(root)
            return
        }

        root.isSplit = true
        if (zone === "left") {
            let oldPrimary = root.primaryTabIndex
            root.primaryTabIndex = newIdx
            root.secondaryTabIndex = (oldPrimary !== -1) ? oldPrimary : 0
            root.activePane = 0
        } else {
            root.secondaryTabIndex = newIdx
            root.activePane = 1
        }
        syncEditorsFromModel(root)
    } else {
        // Открытие в текущей панели (центр)
        root.tabsModel.append({
            title: fileName,
            fileUrl: fileUrl,
            content: content
        })
        switchToTab(root, root.tabsModel.count - 1)
    }
}
