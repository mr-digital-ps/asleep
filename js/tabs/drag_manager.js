function pollCursorState(root, Tabs) {
    if (typeof backend !== "undefined" && backend && typeof backend.get_cursor_state === "function") {
        let state = backend.get_cursor_state()
        if (!state.leftPressed) {
            if (root.dragTrackerTimer) root.dragTrackerTimer.running = false
            handleFileDragEnded(root, root.draggingFileUrl, root.draggingFileName, state.x, state.y, Tabs)
            return
        }
        handleFileDragMoved(root, state.x, state.y)
    }
}

function handleFileDragMoved(root, gx, gy) {
    let appWin = root.appWindow || (root.Window ? root.Window.window : null)
    if (!appWin) return


    let sideW = 0
    let isInsideCurrentWin = (gx >= appWin.x && gx <= (appWin.x + appWin.width) &&
                              gy >= appWin.y && gy <= (appWin.y + appWin.height))

    if (isInsideCurrentWin) {
        // Мышь внутри исходного окна:
        if (typeof backend !== "undefined" && backend && typeof backend.clear_all_drop_zones === "function") {
            backend.clear_all_drop_zones()
        }

        let localX = gx - appWin.x
        if (localX > sideW) {
            let editorW = appWin.width - sideW
            let xInEditor = localX - sideW

            if (root.isSplit) {
                let splitRatio = (root.splitLayout && typeof root.splitLayout.splitRatio === "number") ? root.splitLayout.splitRatio : 0.5
                let splitBorderX = editorW * splitRatio

                if (xInEditor < splitBorderX * 0.45) {
                    root.dropZone = "left"
                } else if (xInEditor > splitBorderX + (editorW - splitBorderX) * 0.55) {
                    root.dropZone = "right"
                } else {
                    root.dropZone = ""
                }
            } else {
                let rel = xInEditor / Math.max(1, editorW)
                if (rel < 0.18) {
                    root.dropZone = "left"
                } else if (rel > 0.82) {
                    root.dropZone = "right"
                } else {
                    root.dropZone = ""
                }
            }
        } else {
            root.dropZone = ""
        }
        return
    }

    // Курсор снаружи исходного окна:
    root.dropZone = ""

    // Проверяем, находится ли курсор над ДРУГИМ окном приложения
    if (typeof backend !== "undefined" && backend && typeof backend.find_target_window_at === "function") {
        let res = backend.find_target_window_at(gx, gy, appWin, null)
        if (res && res.found && res.targetWin) {
            backend.set_window_drop_zone(res.targetWin, res.zone)
            return
        }
    }

    // Курсор не над другим окном — снимаем подсветку со всех окон
    if (typeof backend !== "undefined" && backend && typeof backend.clear_all_drop_zones === "function") {
        backend.clear_all_drop_zones()
    }
}

function closeDetachedPane(root, draggedPaneIdx, fileUrl, Tabs) {
    if (root.isSplit) {
        if (draggedPaneIdx === 1) {
            let sIdx = root.secondaryTabIndex
            root.secondaryTabIndex = -1
            root.isSplit = false
            if (sIdx >= 0 && sIdx < root.tabsModel.count) {
                root.tabsModel.remove(sIdx)
            }
            root.primaryTabIndex = 0
            root.activePane = 0
            Tabs.syncEditorsFromModel(root)
            Tabs.setActivePane(root, 0)
        } else if (draggedPaneIdx === 0) {
            let pIdx = root.primaryTabIndex
            let sIdx = root.secondaryTabIndex
            root.primaryTabIndex = -1
            root.secondaryTabIndex = -1
            root.isSplit = false
            if (pIdx >= 0 && pIdx < root.tabsModel.count) {
                root.tabsModel.remove(pIdx)
                if (sIdx > pIdx) {
                    sIdx -= 1
                }
            }
            root.primaryTabIndex = (sIdx >= 0 && sIdx < root.tabsModel.count) ? sIdx : 0
            root.activePane = 0
            Tabs.syncEditorsFromModel(root)
            Tabs.setActivePane(root, 0)
        }
    }
}

function handleFileDragEnded(root, fileUrl, fileName, gx, gy, Tabs) {
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
    let draggedPaneIdx = (typeof root.draggingPaneIndex === "number") ? root.draggingPaneIndex : -1
    root.draggingFileUrl = ""
    root.draggingFileName = ""
    root.draggingPaneIndex = -1
    root.dropZone = ""

    let appWin = root.appWindow || (root.Window ? root.Window.window : null)
    let sideW = 0
    let isInsideCurrentWin = appWin && (gx >= appWin.x && gx <= (appWin.x + appWin.width) &&
                                         gy >= appWin.y && gy <= (appWin.y + appWin.height))

    let content = ""
    if (draggedPaneIdx === 1) {
        content = (root.splitLayout && root.splitLayout.secondaryBar) ? root.splitLayout.secondaryBar.text : Tabs.getFileContent(root, fileUrl)
        if (!fileName && root.splitLayout && root.splitLayout.secondaryBar) {
            fileName = root.splitLayout.secondaryBar.fileName
        }
    } else if (draggedPaneIdx === 0) {
        content = (root.splitLayout && root.splitLayout.primaryBar) ? root.splitLayout.primaryBar.text : Tabs.getFileContent(root, fileUrl)
        if (!fileName && root.splitLayout && root.splitLayout.primaryBar) {
            fileName = root.splitLayout.primaryBar.fileName
        }
    } else {
        content = Tabs.getFileContent(root, fileUrl)
    }

    // 1. Сброс внутри исходного окна:
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

                if (draggedPaneIdx === 0 && dropZone === "right") {
                    Tabs.swapPanes(root)
                    return
                } else if (draggedPaneIdx === 1 && dropZone === "left") {
                    Tabs.swapPanes(root)
                    return
                }
            } else {
                let rel = xInEditor / Math.max(1, editorW)
                dropZone = (rel < 0.18) ? "left" : ((rel > 0.82) ? "right" : "center")
            }
            if (draggedPaneIdx === -1) {
                dockFileInCurrentWindow(root, fileUrl, fileName, content, dropZone, Tabs)
            }
        }
        return
    }

    // 2. Сброс на ДРУГОЕ существующее окно приложения:
    if (typeof backend !== "undefined" && backend && typeof backend.find_target_window_at === "function") {
        let res = backend.find_target_window_at(gx, gy, appWin, null)
        if (res && res.found && res.targetRoot) {
            res.targetRoot.dockExternalTab(fileUrl, fileName, content, res.zone)
            closeDetachedPane(root, draggedPaneIdx, fileUrl, Tabs)
            return
        }
    }

    // 3. Сброс на пустой рабочий стол — создаем новое окно ОС!
    root.spawnClonedAppWindow(fileUrl, fileName, content, Math.round(gx - 400), Math.round(gy - 30), 850, 600)
    closeDetachedPane(root, draggedPaneIdx, fileUrl, Tabs)
}

function dockFileInCurrentWindow(root, fileUrl, fileName, content, zone, Tabs) {
    if (!fileUrl && !fileName) return

    if (root.isSplit) {
        let targetZone = (zone === "left" || (zone !== "right" && root.activePane === 0)) ? "left" : "right"
        if (targetZone === "left") {
            root.tabsModel.setProperty(root.primaryTabIndex, "title", Tabs.stripExt(fileName))
            root.tabsModel.setProperty(root.primaryTabIndex, "fileUrl", fileUrl)
            root.tabsModel.setProperty(root.primaryTabIndex, "content", content || "")
            root.activePane = 0
        } else {
            root.tabsModel.setProperty(root.secondaryTabIndex, "title", Tabs.stripExt(fileName))
            root.tabsModel.setProperty(root.secondaryTabIndex, "fileUrl", fileUrl)
            root.tabsModel.setProperty(root.secondaryTabIndex, "content", content || "")
            root.activePane = 1
        }
        Tabs.syncEditorsFromModel(root)
        Tabs.setActivePane(root, root.activePane)
        return
    }

    if (zone === "left" || zone === "right") {
        if (root.tabsModel.count === 0 || root.primaryTabIndex < 0) {
            root.tabsModel.clear()
            root.tabsModel.append({
                title: Tabs.stripExt(fileName),
                fileUrl: fileUrl,
                content: content || "",
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

        if (root.tabsModel.count === 1) {
            root.tabsModel.append({
                title: Tabs.stripExt(fileName),
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
            Tabs.syncEditorsFromModel(root)
            Tabs.setActivePane(root, root.activePane)
            return
        }
    } else {
        // "center" в одиночном режиме
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
            Tabs.syncEditorsFromModel(root)
            Tabs.setActivePane(root, 0)
            return
        }
        let activeIdx = root.primaryTabIndex
        if (activeIdx >= 0 && activeIdx < root.tabsModel.count) {
            root.tabsModel.setProperty(activeIdx, "title", Tabs.stripExt(fileName))
            root.tabsModel.setProperty(activeIdx, "fileUrl", fileUrl)
            root.tabsModel.setProperty(activeIdx, "content", content || "")
            Tabs.syncEditorsFromModel(root)
            Tabs.setActivePane(root, root.activePane)
        }
    }
}
