// tabs.js — чистая, надежная архитектура управления вкладками и сплит-режимом

// =============================================================================
// ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ МОДЕЛИ
// =============================================================================

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

function replaceBlockInString(text, headingNorm, newContent) {
    if (!text) return text
    let headingRegex = /^[ \t]*(#{1,6})\s+(.+)$/gm
    let match
    let matches = []
    while ((match = headingRegex.exec(text)) !== null) {
        matches.push({
            start: match.index,
            end: match.index + match[0].length,
            title: match[2].trim()
        })
    }

    let updatedText = text
    for (let i = matches.length - 1; i >= 0; i--) {
        let m = matches[i]
        if (m.title.toLowerCase() === headingNorm.toLowerCase()) {
            let contentStart = m.end
            let contentEnd = (i + 1 < matches.length) ? matches[i + 1].start : text.length
            let oldContent = text.substring(contentStart, contentEnd)
            let cleanOld = oldContent.replace(/^\r?\n/, "").replace(/\r?\n$/, "")
            let cleanNew = newContent.replace(/^\r?\n/, "").replace(/\r?\n$/, "")
            if (cleanOld === cleanNew) continue

            let formattedNew = "\n" + cleanNew + (i + 1 < matches.length ? "\n\n" : "\n")
            let before = updatedText.substring(0, contentStart)
            let after = updatedText.substring(contentEnd)
            updatedText = before + formattedNew + after
        }
    }
    return updatedText
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
        root.primaryFileName = stripExt(pTab.title || "Без названия")
    } else {
        root.primaryFileName = ""
        if (root.splitLayout.primaryBar) root.splitLayout.primaryBar.text = ""
    }

    if (root.isSplit && root.secondaryTabIndex >= 0 && root.secondaryTabIndex < root.tabsModel.count) {
        let sTab = root.tabsModel.get(root.secondaryTabIndex)
        if (root.splitLayout.secondaryBar && root.splitLayout.secondaryBar.text !== sTab.content) {
            root.splitLayout.secondaryBar.text = sTab.content
        }
        root.secondaryFileName = stripExt(sTab.title || "Без названия")
    } else {
        root.secondaryFileName = ""
        if (root.splitLayout.secondaryBar) root.splitLayout.secondaryBar.text = ""
    }

    let activeIdx = (root.isSplit && root.activePane === 1) ? root.secondaryTabIndex : root.primaryTabIndex
    if (activeIdx >= 0 && activeIdx < root.tabsModel.count) {
        let aTab = root.tabsModel.get(activeIdx)
        root.currentFileName = stripExt(aTab.title || "")
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
        root.currentFileName = stripExt(tab.title || "")
        root.currentFileUrl = tab.fileUrl || ""
    } else {
        root.currentFileName = ""
        root.currentFileUrl = ""
    }
}

function switchToTab(root, index) {
    if (index < 0 || index >= root.tabsModel.count) return

    syncCurrentPaneText(root)

    if (root.isSplit) {
        if (root.activePane === 0) {
            if (index === root.secondaryTabIndex) {
                swapPanes(root)
                return
            }
            root.primaryTabIndex = index
        } else {
            if (index === root.primaryTabIndex) {
                swapPanes(root)
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
    syncEditorsFromModel(root)
}

function openFileInTab(root, fileUrl, fileName, isShift) {
    if (!fileUrl) return

    syncCurrentPaneText(root)

    let existingIdx = findTabIndex(root, fileUrl)
    let content = (typeof backend !== "undefined" && backend) ? backend.read_file(fileUrl) : ""
    let cleanName = stripExt(fileName)

    if (isShift) {
        if (!root.isSplit) {
            root.isSplit = true
            let targetIdx = existingIdx
            if (targetIdx === -1) {
                root.tabsModel.append({
                    title: cleanName,
                    fileUrl: fileUrl,
                    content: content,
                    isDetached: false
                })
                targetIdx = root.tabsModel.count - 1
            }
            root.secondaryTabIndex = targetIdx
            root.activePane = 1
            root.currentTabIndex = targetIdx
            syncEditorsFromModel(root)
            setActivePane(root, 1)
        } else {
            let targetIdx = existingIdx
            if (targetIdx === -1) {
                root.tabsModel.append({
                    title: cleanName,
                    fileUrl: fileUrl,
                    content: content,
                    isDetached: false
                })
                targetIdx = root.tabsModel.count - 1
            }
            if (root.activePane === 0) {
                root.primaryTabIndex = targetIdx
            } else {
                root.secondaryTabIndex = targetIdx
            }
            root.currentTabIndex = targetIdx
            syncEditorsFromModel(root)
            setActivePane(root, root.activePane)
        }
        return
    }

    if (existingIdx !== -1) {
        switchToTab(root, existingIdx)
        return
    }

    root.tabsModel.append({
        title: cleanName,
        fileUrl: fileUrl,
        content: content,
        isDetached: false
    })
    let newIdx = root.tabsModel.count - 1
    switchToTab(root, newIdx)
}

function createNewTab(root) {
    syncCurrentPaneText(root)

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

    // Если экран был пуст или нет открытых вкладок
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
        syncEditorsFromModel(root)
        setActivePane(root, 0)
        if (typeof root.reloadFolderFiles === "function") {
            root.reloadFolderFiles()
        }
        return
    }

    // Если текущая единственная вкладка полностью пустая и не привязана к файлу на диске
    if (root.tabsModel.count === 1) {
        let first = root.tabsModel.get(0)
        let curText = (root.splitLayout && root.splitLayout.primaryBar) ? root.splitLayout.primaryBar.text : ""
        if ((!first.fileUrl || first.fileUrl === "") && (!curText || curText.trim() === "")) {
            root.tabsModel.setProperty(0, "title", cleanName)
            root.tabsModel.setProperty(0, "fileUrl", fileUrl)
            root.tabsModel.setProperty(0, "content", "")
            root.currentFileName = cleanName
            root.currentFileUrl = fileUrl
            root.primaryFileName = cleanName
            syncEditorsFromModel(root)
            setActivePane(root, 0)
            if (typeof root.reloadFolderFiles === "function") {
                root.reloadFolderFiles()
            }
            return
        }
    }

    // Добавляем новую вкладку с созданным файлом
    root.tabsModel.append({
        title: cleanName,
        fileUrl: fileUrl,
        content: "",
        isDetached: false
    })
    let newIdx = root.tabsModel.count - 1

    if (root.isSplit) {
        if (root.activePane === 1) {
            root.secondaryTabIndex = newIdx
        } else {
            root.primaryTabIndex = newIdx
        }
        root.currentTabIndex = newIdx
        syncEditorsFromModel(root)
        setActivePane(root, root.activePane)
    } else {
        switchToTab(root, newIdx)
    }

    if (typeof root.reloadFolderFiles === "function") {
        root.reloadFolderFiles()
    }
}

function closeTab(root, index) {
    if (index < 0 || index >= root.tabsModel.count) return

    syncCurrentPaneText(root)

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
            closeSplit(root)
            return
        }
        if (isClosingPrimary) {
            root.primaryTabIndex = (root.secondaryTabIndex > index) ? (root.secondaryTabIndex - 1) : root.secondaryTabIndex
            root.secondaryTabIndex = -1
            root.isSplit = false
            root.activePane = 0
            root.currentTabIndex = root.primaryTabIndex
            syncEditorsFromModel(root)
            setActivePane(root, 0)
            return
        }
        if (root.primaryTabIndex > index) root.primaryTabIndex -= 1
        if (root.secondaryTabIndex > index) root.secondaryTabIndex -= 1
        syncEditorsFromModel(root)
        return
    }

    let nextActive = Math.max(0, index - 1)
    root.primaryTabIndex = nextActive
    root.secondaryTabIndex = -1
    root.currentTabIndex = nextActive
    root.activePane = 0
    syncEditorsFromModel(root)
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
            if (typeof root.reloadFolderFiles === "function") {
                root.reloadFolderFiles()
            }
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

function swapPanes(root) {
    if (!root.isSplit) return
    let temp = root.primaryTabIndex
    root.primaryTabIndex = root.secondaryTabIndex
    root.secondaryTabIndex = temp
    syncEditorsFromModel(root)
    setActivePane(root, root.activePane === 0 ? 1 : 0)
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

function detachTab(root, tabIndex) {
    let tab = root.tabsModel.get(tabIndex)
    if (!tab) return
    let content = (tabIndex === root.primaryTabIndex && root.splitLayout && root.splitLayout.primaryBar)
        ? root.splitLayout.primaryBar.text
        : ((tabIndex === root.secondaryTabIndex && root.splitLayout && root.splitLayout.secondaryBar)
            ? root.splitLayout.secondaryBar.text : tab.content)
    let appWin = root.appWindow || root.Window.window
    let wx = appWin ? appWin.x + 50 : 100
    let wy = appWin ? appWin.y + 50 : 100
    root.spawnClonedAppWindow(tab.fileUrl, tab.title, content, wx, wy, 850, 600)
    closeTab(root, tabIndex)
}

function openFileFromFolder(root, fileUrl, fileName, isShift) {
    if (typeof backend === "undefined" || !backend || !fileUrl) return

    let cleanName = stripExt(fileName)
    let content = backend.read_file(fileUrl)

    // Если экран был пуст (все вкладки закрыты)
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
        syncEditorsFromModel(root)
        setActivePane(root, 0)
        return
    }

    // Если зажат Shift: открываем сплитом рядом (справа)
    if (isShift) {
        syncCurrentPaneText(root)
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
        syncEditorsFromModel(root)
        setActivePane(root, root.activePane)
        return
    }

    // Если файл уже открыт в одной из панелей — просто активируем её
    if (root.primaryTabIndex >= 0 && root.primaryTabIndex < root.tabsModel.count) {
        let pTab = root.tabsModel.get(root.primaryTabIndex)
        if (pTab && pTab.fileUrl === fileUrl) {
            setActivePane(root, 0)
            return
        }
    }
    if (root.isSplit && root.secondaryTabIndex >= 0 && root.secondaryTabIndex < root.tabsModel.count) {
        let sTab = root.tabsModel.get(root.secondaryTabIndex)
        if (sTab && sTab.fileUrl === fileUrl) {
            setActivePane(root, 1)
            return
        }
    }

    // Сохраняем текущий текст перед открытием нового файла
    syncCurrentPaneText(root)

    // Прямое открытие в текущей активной панели
    let activeIdx = (root.isSplit && root.activePane === 1) ? root.secondaryTabIndex : root.primaryTabIndex
    if (activeIdx >= 0 && activeIdx < root.tabsModel.count) {
        root.tabsModel.setProperty(activeIdx, "title", cleanName)
        root.tabsModel.setProperty(activeIdx, "fileUrl", fileUrl)
        root.tabsModel.setProperty(activeIdx, "content", content)
        syncEditorsFromModel(root)
        setActivePane(root, root.activePane)
    } else {
        root.tabsModel.append({
            title: cleanName,
            fileUrl: fileUrl,
            content: content,
            isDetached: false
        })
        switchToTab(root, root.tabsModel.count - 1)
    }
}

