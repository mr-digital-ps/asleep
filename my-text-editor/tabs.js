// tabs.js — логика управления вкладками, плавающими окнами и сплит-режимом (Split View)

// =============================================================================
// ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ И ОПРЕДЕЛЕНИЕ ЗОН СБРОСА (DOCK ZONES)
// =============================================================================

function calculateDropZone(root, gx, gy) {
    let appWin = root.Window.window
    if (!appWin) return ""

    let isInsideApp = (gx >= appWin.x && gx <= (appWin.x + appWin.width) &&
                       gy >= appWin.y && gy <= (appWin.y + appWin.height))
    if (!isInsideApp) return ""

    let sideW = root.sideBar ? root.sideBar.currentWidth : 280
    if (gx <= (appWin.x + sideW)) {
        return "sidebar"
    }

    let editorLeft = appWin.x + sideW
    let editorWidth = appWin.width - sideW
    if (editorWidth <= 0) return "center"

    let relX = (gx - editorLeft) / editorWidth

    if (relX < 0.28) {
        return "left"
    } else if (relX > 0.72) {
        return "right"
    } else {
        return "center"
    }
}

function getAnotherAvailableTab(root, excludeIndex) {
    for (let i = 0; i < root.tabsModel.count; i++) {
        if (i !== excludeIndex && !root.tabsModel.get(i).isDetached) {
            return i
        }
    }
    return -1
}

function syncCurrentPaneText(root) {
    if (root.splitLayout) {
        if (root.primaryTabIndex >= 0 && root.primaryTabIndex < root.tabsModel.count) {
            if (!root.tabsModel.get(root.primaryTabIndex).isDetached) {
                root.tabsModel.setProperty(root.primaryTabIndex, "content", root.splitLayout.primaryBar.text)
            }
        }
        if (root.isSplit && root.secondaryTabIndex >= 0 && root.secondaryTabIndex < root.tabsModel.count) {
            if (!root.tabsModel.get(root.secondaryTabIndex).isDetached) {
                root.tabsModel.setProperty(root.secondaryTabIndex, "content", root.splitLayout.secondaryBar.text)
            }
        }
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
// ПЕРЕТАСКИВАНИЕ И ПЛАВАЮЩИЕ ОКНА
// =============================================================================

// 1. Начало перетаскивания вкладки в сайдбаре
function handleDragStarted(root, index, gx, gy) {
    if (index < 0 || index >= root.tabsModel.count) return
    root.activeDraggingIndex = index

    if (root.detachedWindows[index]) {
        root.activeDraggingWindow = root.detachedWindows[index]
        root.isNewlyCreatedForDrag = false
        root.activeDraggingWindow.isDraggingMode = true
        root.activeDraggingWindow.visible = true
        root.activeDraggingWindow.raise()
    } else {
        root.activeDraggingWindow = null
        root.isNewlyCreatedForDrag = true
    }

    if (typeof backend !== "undefined" && backend && typeof backend.get_cursor_state === "function") {
        if (root.dragTrackerTimer) root.dragTrackerTimer.running = true
    }
}

// 1.1 Интерактивное перемещение плавающего окна за его заголовок
function handleWindowDragMoved(root, index, gx, gy) {
    root.dropZone = calculateDropZone(root, gx, gy)
}

function handleWindowDragEnded(root) {
    root.dropZone = ""
}

// 1.2 Сброс плавающего окна при отпускании заголовка
function handleDetachedWindowDrop(root, index, gx, gy, content, title) {
    let zone = calculateDropZone(root, gx, gy)
    root.dropZone = ""

    if (zone === "sidebar") {
        reattachTab(root, index, content, title, false)
    } else if (zone === "left") {
        splitDock(root, index, content, title, "left")
    } else if (zone === "right") {
        splitDock(root, index, content, title, "right")
    } else if (zone === "center") {
        reattachTab(root, index, content, title, true)
    }
}

// 2. Движение мыши при перетаскивании вкладки из сайдбара
function handleDragMoved(root, index, gx, gy, sideBar) {
    let appWin = root.Window.window
    if (!appWin) return

    let isMax = (appWin.visibility === 4) // Window.Maximized
    let sideW = sideBar ? sideBar.currentWidth : 280

    let isOutsideApp = false
    if (isMax) {
        isOutsideApp = (gx < appWin.x || gx > (appWin.x + appWin.width) ||
                        gy < appWin.y || gy > (appWin.y + appWin.height) ||
                        gx > (appWin.x + sideW + 100))
    } else {
        isOutsideApp = (gx < appWin.x || gx > (appWin.x + appWin.width) ||
                        gy < appWin.y || gy > (appWin.y + appWin.height))
    }

    if (isOutsideApp) {
        root.dropZone = ""
        // Курсор вышел за пределы приложения — создаем или перемещаем плавающее окно
        if (!root.activeDraggingWindow) {
            if (root.detachedWindows[index]) {
                root.activeDraggingWindow = root.detachedWindows[index]
                root.activeDraggingIndex = index
                root.isNewlyCreatedForDrag = false
                root.activeDraggingWindow.isDraggingMode = true
                root.activeDraggingWindow.visible = true
                root.activeDraggingWindow.raise()
            } else {
                let tabData = root.tabsModel.get(index)
                let curContent = tabData.content
                if (index === root.primaryTabIndex && root.splitLayout) {
                    curContent = root.splitLayout.primaryBar.text
                } else if (root.isSplit && index === root.secondaryTabIndex && root.splitLayout) {
                    curContent = root.splitLayout.secondaryBar.text
                }
                let curTitle = tabData.title

                let win = root.detachedWinComponent.createObject(root, {
                    tabIndex: index,
                    fileName: curTitle,
                    initialText: curContent,
                    fileUrl: tabData.fileUrl,
                    width: 750,
                    height: 550,
                    x: Math.round(gx - 375),
                    y: Math.round(gy - 18),
                    isDraggingMode: true,
                    visible: true
                })

                root.activeDraggingWindow = win
                root.activeDraggingIndex = index
                root.isNewlyCreatedForDrag = true
                root.detachedWindows[index] = win

                root.tabsModel.setProperty(index, "isDetached", true)
                root.tabsModel.setProperty(index, "content", curContent)
                root.tabsModel.setProperty(index, "title", curTitle)

                // Если оторвали вкладку, открытую в сплите
                if (root.isSplit) {
                    if (index === root.secondaryTabIndex) {
                        closeSplit(root)
                    } else if (index === root.primaryTabIndex) {
                        root.primaryTabIndex = root.secondaryTabIndex
                        root.secondaryTabIndex = -1
                        root.isSplit = false
                        root.activePane = 0
                        syncEditorsFromModel(root)
                    }
                } else if (index === root.currentTabIndex) {
                    switchToNextAvailableTab(root)
                }
            }
        }

        if (root.activeDraggingWindow) {
            root.activeDraggingWindow.x = Math.round(gx - root.activeDraggingWindow.width / 2)
            root.activeDraggingWindow.y = Math.round(gy - 18)
        }
    } else {
        // Курсор внутри приложения
        root.dropZone = calculateDropZone(root, gx, gy)
        if (root.activeDraggingWindow) {
            let idx = root.activeDraggingIndex
            let win = root.activeDraggingWindow
            root.activeDraggingWindow = null

            let zone = root.dropZone
            root.dropZone = ""

            if (zone === "sidebar") {
                reattachTab(root, idx, win.mainBarText, win.fileName, false)
            } else if (zone === "left") {
                splitDock(root, idx, win.mainBarText, win.fileName, "left")
            } else if (zone === "right") {
                splitDock(root, idx, win.mainBarText, win.fileName, "right")
            } else {
                reattachTab(root, idx, win.mainBarText, win.fileName, true)
            }
        }
    }
}

// 3. Завершение перетаскивания вкладки из сайдбара
function handleDragEnded(root, index, gx, gy) {
    if (root.dragTrackerTimer && root.dragTrackerTimer.running) {
        root.dragTrackerTimer.running = false
    }

    let zone = calculateDropZone(root, gx, gy)
    root.dropZone = ""

    if (root.activeDraggingWindow) {
        let appWin = root.Window.window
        let isInsideApp = appWin && (gx >= appWin.x && gx <= (appWin.x + appWin.width) &&
                                     gy >= appWin.y && gy <= (appWin.y + appWin.height))

        let win = root.activeDraggingWindow
        let idx = root.activeDraggingIndex
        root.activeDraggingWindow = null
        root.activeDraggingIndex = -1

        if (isInsideApp) {
            if (zone === "sidebar") {
                reattachTab(root, idx, win.mainBarText, win.fileName, false)
            } else if (zone === "left") {
                splitDock(root, idx, win.mainBarText, win.fileName, "left")
            } else if (zone === "right") {
                splitDock(root, idx, win.mainBarText, win.fileName, "right")
            } else {
                reattachTab(root, idx, win.mainBarText, win.fileName, true)
            }
        } else {
            // Сброс за пределами окна: закрываем временный драг-прокси и открываем полноценное окно приложения
            let fUrl = win.fileUrl
            let fTitle = win.fileName
            let fContent = win.mainBarText
            let wx = win.x
            let wy = win.y
            let ww = win.width
            let wh = win.height

            win.destroy()
            if (root.detachedWindows) {
                delete root.detachedWindows[idx]
            }

            root.spawnClonedAppWindow(fUrl, fTitle, fContent, wx, wy, ww, wh)

            if (root.tabsModel.count <= 1) {
                root.tabsModel.setProperty(0, "title", "Новый документ")
                root.tabsModel.setProperty(0, "fileUrl", "")
                root.tabsModel.setProperty(0, "content", "")
                root.tabsModel.setProperty(0, "isDetached", false)
                root.currentFileName = "Новый документ"
                root.currentFileUrl = ""
                root.primaryFileName = "Новый документ"
                syncEditorsFromModel(root)
            } else {
                closeTab(root, idx)
            }
        }
    } else {
        root.activeDraggingIndex = -1
    }
}

// 4. Опрос аппаратного состояния курсора таймером (60 FPS)
function pollCursorState(root, sideBar) {
    if (typeof backend !== "undefined" && backend && typeof backend.get_cursor_state === "function") {
        let state = backend.get_cursor_state()
        if (!state.leftPressed) {
            if (root.dragTrackerTimer) root.dragTrackerTimer.running = false
            handleDragEnded(root, root.activeDraggingIndex, state.x, state.y)
            return
        }
        handleDragMoved(root, root.activeDraggingIndex, state.x, state.y, sideBar)
    }
}

// =============================================================================
// ВСТРАИВАНИЕ (DOCKING) И СПЛИТ-РЕЖИМ (SPLIT VIEW)
// =============================================================================

// Встроить вкладку назад в главное окно (обычный режим замены)
function reattachTab(root, index, content, title, activateInEditor) {
    if (index < 0 || index >= root.tabsModel.count) return

    if (content !== undefined) root.tabsModel.setProperty(index, "content", content)
    if (title !== undefined) root.tabsModel.setProperty(index, "title", title)
    root.tabsModel.setProperty(index, "isDetached", false)

    if (root.detachedWindows[index]) {
        let win = root.detachedWindows[index]
        delete root.detachedWindows[index]
        win.destroy()
    }

    if (activateInEditor !== false) {
        switchToTab(root, index)
    }
}

// Встроить вкладку в разделенный экран (Split View: слева или справа)
function splitDock(root, index, content, title, side) {
    if (index < 0 || index >= root.tabsModel.count) return

    if (content !== undefined) root.tabsModel.setProperty(index, "content", content)
    if (title !== undefined) root.tabsModel.setProperty(index, "title", title)
    root.tabsModel.setProperty(index, "isDetached", false)

    if (root.detachedWindows[index]) {
        let win = root.detachedWindows[index]
        delete root.detachedWindows[index]
        win.destroy()
    }

    syncCurrentPaneText(root)

    root.isSplit = true
    if (side === "left") {
        let oldPrimary = root.primaryTabIndex
        root.primaryTabIndex = index
        root.secondaryTabIndex = (oldPrimary !== index) ? oldPrimary : getAnotherAvailableTab(root, index)
        root.activePane = 0
    } else {
        let oldPrimary = root.primaryTabIndex
        if (oldPrimary === index) {
            let other = getAnotherAvailableTab(root, index)
            if (other !== -1) {
                root.primaryTabIndex = other
            }
        }
        root.secondaryTabIndex = index
        root.activePane = 1
    }

    root.currentTabIndex = (root.activePane === 0) ? root.primaryTabIndex : root.secondaryTabIndex
    syncEditorsFromModel(root)
}

// Закрыть сплит-режим и вернуться к одной панели
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

// Переключить сплит-режим (шорткат Ctrl+\)
function toggleSplit(root) {
    if (root.isSplit) {
        closeSplit(root)
    } else {
        if (root.tabsModel.count === 0) {
            createNewTab(root)
            return
        }
        let curPrimary = root.primaryTabIndex
        let otherIdx = getAnotherAvailableTab(root, curPrimary)
        if (otherIdx === -1) {
            let nextNum = root.tabsModel.count + 1
            root.tabsModel.append({
                title: "Документ " + nextNum,
                fileUrl: "",
                content: "",
                isDetached: false
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

// Установить активную панель фокуса (0: левая, 1: правая)
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

// Синхронизация ввода текста в реальном времени
function handlePrimaryTextChanged(root, text) {
    if (root.primaryTabIndex >= 0 && root.primaryTabIndex < root.tabsModel.count) {
        if (!root.tabsModel.get(root.primaryTabIndex).isDetached) {
            root.tabsModel.setProperty(root.primaryTabIndex, "content", text)
        }
    }
}

function handleSecondaryTextChanged(root, text) {
    if (root.isSplit && root.secondaryTabIndex >= 0 && root.secondaryTabIndex < root.tabsModel.count) {
        if (!root.tabsModel.get(root.secondaryTabIndex).isDetached) {
            root.tabsModel.setProperty(root.secondaryTabIndex, "content", text)
        }
    }
}

// =============================================================================
// ЖИЗНЕННЫЙ ЦИКЛ ВКЛАДОК
// =============================================================================

// Программный отрыв вкладки
function detachTab(root, index, spawnX, spawnY) {
    if (index < 0 || index >= root.tabsModel.count) return

    syncCurrentPaneText(root)

    let tabData = root.tabsModel.get(index)
    let curContent = tabData.content
    if (index === root.primaryTabIndex && root.splitLayout) {
        curContent = root.splitLayout.primaryBar.text
    } else if (root.isSplit && index === root.secondaryTabIndex && root.splitLayout) {
        curContent = root.splitLayout.secondaryBar.text
    }
    let curTitle = tabData.title
    let curFileUrl = tabData.fileUrl

    let appWin = root.Window.window
    let posX = (spawnX !== undefined) ? Math.round(spawnX - 425) : (appWin ? (appWin.x + 60 + (index * 25)) : 120)
    let posY = (spawnY !== undefined) ? Math.round(spawnY - 20) : (appWin ? (appWin.y + 60 + (index * 25)) : 120)

    // Создаем полноценное клонированное окно со скрытым сайдбаром
    root.spawnClonedAppWindow(curFileUrl, curTitle, curContent, posX, posY, 850, 600)

    if (root.tabsModel.count <= 1) {
        root.tabsModel.setProperty(0, "title", "Новый документ")
        root.tabsModel.setProperty(0, "fileUrl", "")
        root.tabsModel.setProperty(0, "content", "")
        root.tabsModel.setProperty(0, "isDetached", false)
        root.currentFileName = "Новый документ"
        root.currentFileUrl = ""
        root.primaryFileName = "Новый документ"
        syncEditorsFromModel(root)
    } else {
        closeTab(root, index)
    }
}

function updateDetachedContent(root, index, content) {
    if (index >= 0 && index < root.tabsModel.count) {
        root.tabsModel.setProperty(index, "content", content)
    }
}

function updateDetachedTitle(root, index, title) {
    if (index >= 0 && index < root.tabsModel.count) {
        root.tabsModel.setProperty(index, "title", title)
    }
}

function switchToNextAvailableTab(root) {
    for (let i = 0; i < root.tabsModel.count; i++) {
        if (!root.tabsModel.get(i).isDetached) {
            switchToTab(root, i)
            return
        }
    }
    // Если вкладок не осталось — оставляем Main полностью пустым!
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

function switchToTab(root, index) {
    if (index < 0 || index >= root.tabsModel.count) return

    if (root.tabsModel.get(index).isDetached) {
        if (root.detachedWindows[index]) {
            root.detachedWindows[index].raise()
            root.detachedWindows[index].requestActivate()
        }
        return
    }

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
        content: "",
        isDetached: false
    })
    switchToTab(root, root.tabsModel.count - 1)
}

function closeTab(root, index) {
    if (index < 0 || index >= root.tabsModel.count) return

    if (root.detachedWindows[index]) {
        let win = root.detachedWindows[index]
        delete root.detachedWindows[index]
        win.destroy()
    }

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

    let newWindows = {}
    for (let k in root.detachedWindows) {
        let i = parseInt(k)
        if (i < index) {
            newWindows[i] = root.detachedWindows[i]
        } else if (i > index) {
            newWindows[i - 1] = root.detachedWindows[i]
            newWindows[i - 1].tabIndex = i - 1
        }
    }
    root.detachedWindows = newWindows

    if (root.tabsModel.count === 0) {
        // Все вкладки закрыты — оставляем Main полностью пустым!
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

    switchToNextAvailableTab(root)
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
    if (root.detachedWindows[index]) {
        root.detachedWindows[index].fileName = finalTitle
    }
}

function turnDetachedIntoAppWindow(root, index, fileUrl, title, content, gx, gy, gw, gh) {
    // 1. Уничтожаем открепленное окно
    if (root.detachedWindows && root.detachedWindows[index]) {
        let win = root.detachedWindows[index]
        delete root.detachedWindows[index]
        win.destroy()
    }

    // 2. Спавним полноценное окно приложения со скрытым сайдбаром
    root.spawnClonedAppWindow(fileUrl, title, content, gx, gy, gw, gh)

    // 3. Удаляем вкладку из родительского окна
    if (root.tabsModel.count <= 1) {
        root.tabsModel.setProperty(0, "title", "Новый документ")
        root.tabsModel.setProperty(0, "fileUrl", "")
        root.tabsModel.setProperty(0, "content", "")
        root.tabsModel.setProperty(0, "isDetached", false)
        root.currentFileName = "Новый документ"
        root.currentFileUrl = ""
        root.primaryFileName = "Новый документ"
        syncEditorsFromModel(root)
    } else {
        closeTab(root, index)
    }
}

