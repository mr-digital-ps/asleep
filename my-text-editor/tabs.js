// tabs.js — чистая, надежная архитектура управления вкладками, сплит-режимом и окнами

// =============================================================================
// ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ МОДЕЛИ
// =============================================================================

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
    if (!fileUrl) return ""
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
        root.primaryFileName = pTab.title || "Без названия"
    } else {
        root.primaryFileName = ""
        if (root.splitLayout.primaryBar) root.splitLayout.primaryBar.text = ""
    }

    if (root.isSplit && root.secondaryTabIndex >= 0 && root.secondaryTabIndex < root.tabsModel.count) {
        let sTab = root.tabsModel.get(root.secondaryTabIndex)
        if (root.splitLayout.secondaryBar && root.splitLayout.secondaryBar.text !== sTab.content) {
            root.splitLayout.secondaryBar.text = sTab.content
        }
        root.secondaryFileName = sTab.title || "Без названия"
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

    // Фокусируем активный редактор для мгновенного ввода и индикации
    if (root.splitLayout && typeof root.splitLayout.focusPane === "function") {
        root.splitLayout.focusPane(paneIndex)
    }
}

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
    root.currentFileName = tab.title || ""
    root.currentFileUrl = tab.fileUrl || ""
    syncEditorsFromModel(root)
    setActivePane(root, root.activePane)
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

    if (root.tabsModel.count === 0 || root.primaryTabIndex < 0) {
        root.tabsModel.clear()
        root.tabsModel.append({
            title: initialTitle,
            fileUrl: initialUrl,
            content: "",
            isDetached: false
        })
        root.primaryTabIndex = 0
        root.secondaryTabIndex = -1
        root.isSplit = false
        root.activePane = 0
    } else {
        let activeIdx = (root.isSplit && root.activePane === 1) ? root.secondaryTabIndex : root.primaryTabIndex
        if (activeIdx >= 0 && activeIdx < root.tabsModel.count) {
            root.tabsModel.setProperty(activeIdx, "title", initialTitle)
            root.tabsModel.setProperty(activeIdx, "fileUrl", initialUrl)
            root.tabsModel.setProperty(activeIdx, "content", "")
        }
    }
    syncEditorsFromModel(root)
    setActivePane(root, root.activePane)
}

function closeTab(root, index) {
    if (root.tabsModel.count === 0) return

    // 1. Если закрывается вкладка в режиме сплита:
    if (root.isSplit) {
        if (index === root.secondaryTabIndex || root.activePane === 1) {
            // Закрываем правую/вторичную панель: возвращаемся к одиночной левой
            if (root.secondaryTabIndex >= 0 && root.secondaryTabIndex < root.tabsModel.count) {
                root.tabsModel.remove(root.secondaryTabIndex)
            }
            root.secondaryTabIndex = -1
            root.isSplit = false
            root.primaryTabIndex = 0
            root.activePane = 0
            syncEditorsFromModel(root)
            setActivePane(root, 0)
            return
        } else {
            // Закрываем левую/основную панель: вторичная панель становится основной
            if (root.primaryTabIndex >= 0 && root.primaryTabIndex < root.tabsModel.count) {
                root.tabsModel.remove(root.primaryTabIndex)
            }
            root.primaryTabIndex = 0
            root.secondaryTabIndex = -1
            root.isSplit = false
            root.activePane = 0
            syncEditorsFromModel(root)
            setActivePane(root, 0)
            return
        }
    }

    // 2. Если режим не сплит (одиночный редактор):
    // Закрываем текущий открытый документ и оставляем экран ПОЛНОСТЬЮ ПУСТЫМ (без «матрёшки»)!
    root.tabsModel.clear()
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
    setActivePane(root, 0)
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
        let otherIdx = findOtherTabIndex(root, curPrimary)

        root.isSplit = true
        root.primaryTabIndex = curPrimary
        root.secondaryTabIndex = otherIdx
        root.activePane = 1
        root.currentTabIndex = otherIdx
        syncEditorsFromModel(root)
        setActivePane(root, 1)
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
// МЕЖ-ОКОННОЕ ОБЪЕДИНЕНИЕ И ОТКРЕПЛЕНИЕ (CROSS-WINDOW DOCKING & DETACH)
// =============================================================================

function openInNewWindow(root, fileUrl, fileName, wx, wy) {
    let content = getFileContent(root, fileUrl)
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
    let appWin = root.appWindow || root.Window.window
    if (!appWin) return

    let sideW = (root.sideBar && root.sideBar.isSidebarVisible) ? root.sideBar.currentWidth : 0
    let isInsideCurrentWin = (gx >= appWin.x && gx <= (appWin.x + appWin.width) &&
                              gy >= appWin.y && gy <= (appWin.y + appWin.height))

    if (isInsideCurrentWin) {
        // Мышь внутри текущего окна
        if (typeof backend !== "undefined" && backend && typeof backend.clear_all_drop_zones === "function") {
            backend.clear_all_drop_zones()
        }

        let localX = gx - appWin.x
        if (localX > sideW) {
            let editorW = appWin.width - sideW
            let xInEditor = localX - sideW

            if (root.isSplit) {
                // В режиме сплита: курсор над левой половиной = "left", над правой = "right"
                let splitRatio = (root.splitLayout && typeof root.splitLayout.splitRatio === "number") ? root.splitLayout.splitRatio : 0.5
                let splitBorderX = editorW * splitRatio

                if (xInEditor < splitBorderX) {
                    root.dropZone = "left"
                } else {
                    root.dropZone = "right"
                }
            } else {
                // В одиночном режиме: левая треть (сплит слева), правая треть (сплит справа), центр (замена)
                let rel = xInEditor / Math.max(1, editorW)
                if (rel < 0.28) {
                    root.dropZone = "left"
                } else if (rel > 0.72) {
                    root.dropZone = "right"
                } else {
                    root.dropZone = "center"
                }
            }
        } else {
            root.dropZone = ""
        }
        return
    }

    // Курсор снаружи текущего окна
    root.dropZone = ""

    // 1. Проверяем, находится ли курсор над другим окном приложения
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

    // 2. Курсор на пустом рабочем столе или втором мониторе:
    // МГНОВЕННО создаем новое приложение с отделившимся файлом прямо под курсором!
    if (!root.draggedNewWin && root.draggingFileUrl) {
        let fUrl = root.draggingFileUrl
        let fName = root.draggingFileName
        let content = getFileContent(root, fUrl)

        let newWin = root.spawnClonedAppWindow(
            fUrl,
            fName,
            content,
            Math.round(gx - 400),
            Math.round(gy - 30),
            850,
            600
        )
        root.draggedNewWin = newWin

        let srcIndex = findTabIndex(root, fUrl)
        if (srcIndex !== -1) {
            closeTab(root, srcIndex)
        }
    } else if (root.draggedNewWin) {
        // Окно уже создано — перемещаем его за курсором до отпускания мыши
        root.draggedNewWin.x = Math.round(gx - 400)
        root.draggedNewWin.y = Math.round(gy - 30)
    }
}

function handleFileDragEnded(root, fileUrl, fileName, gx, gy) {
    if (!root.isFileDragging && !root.draggingFileUrl) {
        return
    }
    root.isFileDragging = false

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

    // Если новое окно уже было создано во время перемещения
    if (root.draggedNewWin) {
        root.draggedNewWin = null
        root.dropZone = ""
        return
    }

    root.dropZone = ""

    let appWin = root.appWindow || root.Window.window
    let sideW = (root.sideBar && root.sideBar.isSidebarVisible) ? root.sideBar.currentWidth : 0
    let isInsideCurrentWin = appWin && (gx >= appWin.x && gx <= (appWin.x + appWin.width) &&
                                         gy >= appWin.y && gy <= (appWin.y + appWin.height))

    let content = getFileContent(root, fileUrl)
    let srcIndex = findTabIndex(root, fileUrl)

    // 1. Сброс внутри текущего окна:
    if (isInsideCurrentWin) {
        let localX = gx - appWin.x
        if (localX > sideW) {
            let editorW = appWin.width - sideW
            let xInEditor = localX - sideW
            let dropZone = ""
            if (root.isSplit) {
                let splitRatio = (root.splitLayout && typeof root.splitLayout.splitRatio === "number") ? root.splitLayout.splitRatio : 0.5
                let splitBorderX = editorW * splitRatio
                dropZone = (xInEditor < splitBorderX) ? "left" : "right"
            } else {
                let rel = xInEditor / Math.max(1, editorW)
                dropZone = (rel < 0.28) ? "left" : ((rel > 0.72) ? "right" : "center")
            }
            dockFileInCurrentWindow(root, fileUrl, fileName, content, dropZone)
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

    // 3. Сброс на рабочий стол:
    root.spawnClonedAppWindow(fileUrl, fileName, content, Math.round(gx - 400), Math.round(gy - 30), 850, 600)
    if (srcIndex !== -1) {
        closeTab(root, srcIndex)
    }
}

// Встраивание файла в сплит-экран текущего окна
function dockFileInCurrentWindow(root, fileUrl, fileName, content, zone) {
    if (!fileUrl && !fileName) return

    if (root.isSplit) {
        // В сплите допустимы только левая или правая панель
        let targetZone = (zone === "left" || (zone !== "right" && root.activePane === 0)) ? "left" : "right"
        if (targetZone === "left") {
            root.tabsModel.setProperty(root.primaryTabIndex, "title", fileName)
            root.tabsModel.setProperty(root.primaryTabIndex, "fileUrl", fileUrl)
            root.tabsModel.setProperty(root.primaryTabIndex, "content", content || "")
            root.activePane = 0
        } else {
            root.tabsModel.setProperty(root.secondaryTabIndex, "title", fileName)
            root.tabsModel.setProperty(root.secondaryTabIndex, "fileUrl", fileUrl)
            root.tabsModel.setProperty(root.secondaryTabIndex, "content", content || "")
            root.activePane = 1
        }
        syncEditorsFromModel(root)
        setActivePane(root, root.activePane)
        return
    }

    if (zone === "left" || zone === "right") {
        if (root.tabsModel.count === 0 || root.primaryTabIndex < 0) {
            root.tabsModel.clear()
            root.tabsModel.append({
                title: fileName,
                fileUrl: fileUrl,
                content: content || "",
                isDetached: false
            })
            root.primaryTabIndex = 0
            root.secondaryTabIndex = -1
            root.isSplit = false
            root.activePane = 0
            syncEditorsFromModel(root)
            setActivePane(root, 0)
            return
        }

        if (root.tabsModel.count === 1) {
            root.tabsModel.append({
                title: fileName,
                fileUrl: fileUrl,
                content: content || "",
                isDetached: false
            })
            root.isSplit = true
            if (zone === "left") {
                root.primaryTabIndex = 1
                root.secondaryTabIndex = 0
                root.activePane = 0
            } else {
                root.primaryTabIndex = 0
                root.secondaryTabIndex = 1
                root.activePane = 1
            }
            syncEditorsFromModel(root)
            setActivePane(root, root.activePane)
            return
        }
    } else {
        // "center" в одиночном режиме (заменяет открытый документ)
        if (root.tabsModel.count === 0 || root.primaryTabIndex < 0) {
            root.tabsModel.clear()
            root.tabsModel.append({
                title: fileName,
                fileUrl: fileUrl,
                content: content || "",
                isDetached: false
            })
            root.primaryTabIndex = 0
            root.secondaryTabIndex = -1
            root.isSplit = false
            root.activePane = 0
            syncEditorsFromModel(root)
            setActivePane(root, 0)
            return
        }
        let activeIdx = root.primaryTabIndex
        if (activeIdx >= 0 && activeIdx < root.tabsModel.count) {
            root.tabsModel.setProperty(activeIdx, "title", fileName)
            root.tabsModel.setProperty(activeIdx, "fileUrl", fileUrl)
            root.tabsModel.setProperty(activeIdx, "content", content || "")
            syncEditorsFromModel(root)
            setActivePane(root, root.activePane)
        }
    }
}

// Приём внешнего документа из другого окна
function dockExternalTab(root, fileUrl, fileName, content, zone) {
    dockFileInCurrentWindow(root, fileUrl, fileName, content, zone)
}
