// tabs.js — логика управления вкладками и плавающими окнами

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

// 1.1 Обработка сброса плавающего окна при перетаскивании за его заголовок
function handleDetachedWindowDrop(root, index, gx, gy, content, title) {
    let appWin = root.Window.window
    if (!appWin) return

    let sideW = root.sideBar ? root.sideBar.currentWidth : 280
    let isInsideApp = (gx >= appWin.x && gx <= (appWin.x + appWin.width) &&
                       gy >= appWin.y && gy <= (appWin.y + appWin.height))

    if (isInsideApp) {
        let inSidebar = (gx <= (appWin.x + sideW))
        if (inSidebar) {
            // Бросили в Sidebar: просто как бы закрывается (встраивается без переключения редактора)
            reattachTab(root, index, content, title, false)
        } else {
            // Бросили в TextArea: заменяет его с собой (встраивается и сразу открывается в редакторе)
            reattachTab(root, index, content, title, true)
        }
    }
}

// 2. Движение мыши: как только курсор вышел за пределы окна — открываем и двигаем окно
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
        // Курсор вышел за пределы приложения
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
                let curContent = (index === root.currentTabIndex) ? root.editorArea.text : tabData.content
                let curTitle = (index === root.currentTabIndex) ? root.currentFileName : tabData.title

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

                if (index === root.currentTabIndex) {
                    switchToNextAvailableTab(root)
                }
            }
        }

        // Плавное следование за курсором
        if (root.activeDraggingWindow) {
            root.activeDraggingWindow.x = Math.round(gx - root.activeDraggingWindow.width / 2)
            root.activeDraggingWindow.y = Math.round(gy - 18)
        }
    } else {
        // Курсор внутри приложения
        if (root.activeDraggingWindow) {
            let idx = root.activeDraggingIndex
            let win = root.activeDraggingWindow
            root.activeDraggingWindow = null

            // Проверяем: попадает в Sidebar или в TextArea?
            let inSidebar = (gx <= (appWin.x + sideW))
            if (inSidebar) {
                // Если попадает в sidebar: просто как бы закрывается (встраивается без переключения редактора)
                reattachTab(root, idx, win.mainBarText, win.fileName, false)
            } else {
                // Если попадает в TextArea: заменяет его с собой (встраивается и сразу открывается в редакторе)
                reattachTab(root, idx, win.mainBarText, win.fileName, true)
            }
        }
    }
}

// 3. Завершение перетаскивания
function handleDragEnded(root, index, gx, gy) {
    if (root.dragTrackerTimer && root.dragTrackerTimer.running) {
        root.dragTrackerTimer.running = false
    }

    if (root.activeDraggingWindow) {
        let appWin = root.Window.window
        let sideW = root.sideBar ? root.sideBar.currentWidth : 280
        let isInsideApp = appWin && (gx >= appWin.x && gx <= (appWin.x + appWin.width) &&
                                     gy >= appWin.y && gy <= (appWin.y + appWin.height))

        let win = root.activeDraggingWindow
        let idx = root.activeDraggingIndex
        root.activeDraggingWindow = null
        root.activeDraggingIndex = -1

        if (isInsideApp) {
            let inSidebar = (gx <= (appWin.x + sideW))
            if (inSidebar) {
                reattachTab(root, idx, win.mainBarText, win.fileName, false)
            } else {
                reattachTab(root, idx, win.mainBarText, win.fileName, true)
            }
        } else {
            win.isDraggingMode = false
            win.show()
            win.raise()
            win.requestActivate()

            root.tabsModel.setProperty(idx, "isDetached", true)
            root.tabsModel.setProperty(idx, "content", win.mainBarText)
            root.tabsModel.setProperty(idx, "title", win.fileName)
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

// 5. Встроить вкладку назад в главное окно
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

    // Если activateInEditor !== false: заменяем открытый документ в TextArea на этот
    // Если false: просто закрываем окно и возвращаем в сайдбар
    if (activateInEditor !== false) {
        switchToTab(root, index)
    }
}

// 6. Программный отрыв вкладки
function detachTab(root, index, spawnX, spawnY) {
    if (index < 0 || index >= root.tabsModel.count) return

    if (root.detachedWindows[index]) {
        root.detachedWindows[index].raise()
        root.detachedWindows[index].requestActivate()
        return
    }

    if (index === root.currentTabIndex) {
        root.tabsModel.setProperty(index, "content", root.editorArea.text)
    }

    let tabData = root.tabsModel.get(index)
    root.tabsModel.setProperty(index, "isDetached", true)

    let posX = (spawnX !== undefined) ? Math.round(spawnX - 375) : (root.Window.window.x + 60 + (index * 25))
    let posY = (spawnY !== undefined) ? Math.round(spawnY - 18) : (root.Window.window.y + 60 + (index * 25))

    let win = root.detachedWinComponent.createObject(root, {
        tabIndex: index,
        fileName: tabData.title,
        initialText: tabData.content,
        fileUrl: tabData.fileUrl,
        width: 750,
        height: 550,
        x: posX,
        y: posY,
        visible: true
    })

    root.detachedWindows[index] = win

    if (index === root.currentTabIndex) {
        switchToNextAvailableTab(root)
    }
}

// 7. Обновление контента открепленного окна
function updateDetachedContent(root, index, content) {
    if (index >= 0 && index < root.tabsModel.count) {
        root.tabsModel.setProperty(index, "content", content)
    }
}

// 8. Обновление заголовка открепленного окна
function updateDetachedTitle(root, index, title) {
    if (index >= 0 && index < root.tabsModel.count) {
        root.tabsModel.setProperty(index, "title", title)
    }
}

// 9. Переключение на следующую доступную вкладку
function switchToNextAvailableTab(root) {
    for (let i = 0; i < root.tabsModel.count; i++) {
        if (!root.tabsModel.get(i).isDetached) {
            switchToTab(root, i)
            return
        }
    }
    createNewTab(root)
}

// 10. Переключение вкладки
function switchToTab(root, index) {
    if (index < 0 || index >= root.tabsModel.count) return

    if (root.tabsModel.get(index).isDetached) {
        if (root.detachedWindows[index]) {
            root.detachedWindows[index].raise()
            root.detachedWindows[index].requestActivate()
        }
        return
    }

    if (root.currentTabIndex >= 0 && root.currentTabIndex < root.tabsModel.count && !root.tabsModel.get(root.currentTabIndex).isDetached) {
        root.tabsModel.setProperty(root.currentTabIndex, "content", root.editorArea.text)
    }

    root.currentTabIndex = index

    let tab = root.tabsModel.get(index)
    root.currentFileName = tab.title
    root.currentFileUrl = tab.fileUrl
    root.editorArea.text = tab.content
}

// 11. Создание новой вкладки
function createNewTab(root) {
    if (root.tabsModel.count > 0 && root.currentTabIndex < root.tabsModel.count && !root.tabsModel.get(root.currentTabIndex).isDetached) {
        root.tabsModel.setProperty(root.currentTabIndex, "content", root.editorArea.text)
    }

    let nextNum = root.tabsModel.count + 1
    root.tabsModel.append({
        title: "Документ " + nextNum,
        fileUrl: "",
        content: "",
        isDetached: false
    })
    switchToTab(root, root.tabsModel.count - 1)
}

// 12. Закрытие вкладки
function closeTab(root, index) {
    if (root.detachedWindows[index]) {
        let win = root.detachedWindows[index]
        delete root.detachedWindows[index]
        win.destroy()
    }

    if (root.tabsModel.count <= 1) {
        root.tabsModel.setProperty(0, "title", "Новый документ")
        root.tabsModel.setProperty(0, "fileUrl", "")
        root.tabsModel.setProperty(0, "content", "")
        root.tabsModel.setProperty(0, "isDetached", false)
        root.currentFileName = "Новый документ"
        root.currentFileUrl = ""
        root.editorArea.text = ""
        return
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

    if (root.currentTabIndex >= root.tabsModel.count) {
        root.currentTabIndex = root.tabsModel.count - 1
    } else if (root.currentTabIndex > index) {
        root.currentTabIndex--
    }

    switchToNextAvailableTab(root)
}

// 13. Переименование вкладки
function renameTab(root, index, newTitle) {
    if (index < 0 || index >= root.tabsModel.count) return
    root.tabsModel.setProperty(index, "title", newTitle)
    if (index === root.currentTabIndex) {
        root.currentFileName = newTitle
    }
    if (root.detachedWindows[index]) {
        root.detachedWindows[index].fileName = newTitle
    }
}
