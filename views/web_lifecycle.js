// web_lifecycle.js — Чистый контроллер жизненного цикла рабочей области и синхронизации сплита
.pragma library

function stripExt(name) {
    if (!name) return ""
    return name.replace(/\.md$/i, "")
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

// Хелперы для устранения повторяющихся паттернов выбора активной панели
function getActiveBar(root, splitLayout) {
    if (!splitLayout) return null
    return (root && root.isSplit && root.activePane === 1) ? splitLayout.secondaryBar : splitLayout.primaryBar
}

function getActiveTabIndex(root) {
    return (root && root.isSplit && root.activePane === 1) ? root.secondaryTabIndex : root.primaryTabIndex
}

function applyToBothBars(splitLayout, method) {
    if (!splitLayout) return
    if (splitLayout.primaryBar && typeof splitLayout.primaryBar[method] === "function") {
        splitLayout.primaryBar[method]()
    }
    if (splitLayout.isSplit && splitLayout.secondaryBar && typeof splitLayout.secondaryBar[method] === "function") {
        splitLayout.secondaryBar[method]()
    }
}

// =========================================================================
// Синхронизация модели и двух панелей (Split View)
// =========================================================================
function syncCurrentPaneText(root) {
    if (!root || !root.splitLayout || !root.tabsModel) return
    if (root.primaryTabIndex >= 0 && root.primaryTabIndex < root.tabsModel.count) {
        root.tabsModel.setProperty(root.primaryTabIndex, "content", root.splitLayout.primaryBar.text)
    }
    if (root.isSplit && root.secondaryTabIndex >= 0 && root.secondaryTabIndex < root.tabsModel.count) {
        root.tabsModel.setProperty(root.secondaryTabIndex, "content", root.splitLayout.secondaryBar.text)
    }
}

function syncEditorsFromModel(root) {
    if (!root || !root.splitLayout || !root.tabsModel) return

    if (root.primaryTabIndex >= 0 && root.primaryTabIndex < root.tabsModel.count) {
        var pTab = root.tabsModel.get(root.primaryTabIndex)
        if (root.splitLayout.primaryBar && root.splitLayout.primaryBar.text !== pTab.content) {
            root.splitLayout.primaryBar.text = pTab.content
        }
        root.primaryFileName = stripExt(pTab.title || "Без названия")
    } else {
        root.primaryFileName = ""
        if (root.splitLayout.primaryBar) root.splitLayout.primaryBar.text = ""
    }

    if (root.isSplit && root.secondaryTabIndex >= 0 && root.secondaryTabIndex < root.tabsModel.count) {
        var sTab = root.tabsModel.get(root.secondaryTabIndex)
        if (root.splitLayout.secondaryBar && root.splitLayout.secondaryBar.text !== sTab.content) {
            root.splitLayout.secondaryBar.text = sTab.content
        }
        root.secondaryFileName = stripExt(sTab.title || "Без названия")
    } else {
        root.secondaryFileName = ""
        if (root.splitLayout.secondaryBar) root.splitLayout.secondaryBar.text = ""
    }

    var activeIdx = (root.isSplit && root.activePane === 1) ? root.secondaryTabIndex : root.primaryTabIndex
    if (activeIdx >= 0 && activeIdx < root.tabsModel.count) {
        var aTab = root.tabsModel.get(activeIdx)
        root.currentFileName = stripExt(aTab.title || "")
        root.currentFileUrl = aTab.fileUrl || ""
        root.currentTabIndex = activeIdx
    } else {
        root.currentFileName = ""
        root.currentFileUrl = ""
        root.currentTabIndex = -1
    }
}

function setActivePane(root, paneIndex) {
    if (!root) return
    root.activePane = paneIndex
    var targetIndex = (paneIndex === 1) ? root.secondaryTabIndex : root.primaryTabIndex
    root.currentTabIndex = targetIndex
    if (root.tabsModel && targetIndex >= 0 && targetIndex < root.tabsModel.count) {
        var tab = root.tabsModel.get(targetIndex)
        root.currentFileName = stripExt(tab.title || "")
        root.currentFileUrl = tab.fileUrl || ""
    } else {
        root.currentFileName = ""
        root.currentFileUrl = ""
    }
}

function swapPanes(root) {
    if (!root || !root.isSplit) return
    var temp = root.primaryTabIndex
    root.primaryTabIndex = root.secondaryTabIndex
    root.secondaryTabIndex = temp
    syncEditorsFromModel(root)
    setActivePane(root, root.activePane === 0 ? 1 : 0)
}

function switchToTab(root, index) {
    if (!root || !root.tabsModel || index < 0 || index >= root.tabsModel.count) return
    if (root.splitLayout && typeof root.splitLayout.closeGraph === "function") {
        root.splitLayout.closeGraph()
    }
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

function createNewTab(root, isShift) {
    if (!root) return
    if (root.splitLayout && typeof root.splitLayout.closeGraph === "function") {
        root.splitLayout.closeGraph()
    }
    syncCurrentPaneText(root)

    var folderUrl = root.currentFolderUrl
    if (!folderUrl && typeof backend !== "undefined" && backend && typeof backend.get_default_folder === "function") {
        folderUrl = backend.get_default_folder()
        root.currentFolderUrl = folderUrl
        if (typeof backend.get_folder_name === "function") {
            root.currentFolderName = backend.get_folder_name(folderUrl)
        }
    }

    var fileUrl = ""
    var fileName = "Новый документ"

    if (typeof backend !== "undefined" && backend && folderUrl) {
        var res = backend.create_file_in_folder(folderUrl, "Новый документ")
        if (res && res.success) {
            fileUrl = res.fileUrl
            fileName = res.fileName
        }
    }

    var cleanName = stripExt(fileName)

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
        root.reloadFolderFiles()
        return
    }

    if (!isShift && root.tabsModel.count === 1) {
        var first = root.tabsModel.get(0)
        var curText = (root.splitLayout && root.splitLayout.primaryBar) ? root.splitLayout.primaryBar.text : ""
        if ((!first.fileUrl || first.fileUrl === "") && (!curText || curText.trim() === "")) {
            root.tabsModel.setProperty(0, "title", cleanName)
            root.tabsModel.setProperty(0, "fileUrl", fileUrl)
            root.tabsModel.setProperty(0, "content", "")
            root.currentFileName = cleanName
            root.currentFileUrl = fileUrl
            root.primaryFileName = cleanName
            syncEditorsFromModel(root)
            setActivePane(root, 0)
            root.reloadFolderFiles()
            return
        }
    }

    root.tabsModel.append({
        title: cleanName,
        fileUrl: fileUrl,
        content: "",
        isDetached: false
    })
    var newIdx = root.tabsModel.count - 1

    if (isShift) {
        root.secondaryTabIndex = newIdx
        root.isSplit = true
        root.activePane = 1
        root.currentTabIndex = newIdx
        syncEditorsFromModel(root)
        setActivePane(root, 1)
    } else if (root.isSplit) {
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

    root.reloadFolderFiles()
}

function closeTab(root, index) {
    if (!root || !root.tabsModel || index < 0 || index >= root.tabsModel.count) return
    syncCurrentPaneText(root)

    var isClosingPrimary = (index === root.primaryTabIndex)
    var isClosingSecondary = (root.isSplit && index === root.secondaryTabIndex)

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
            syncEditorsFromModel(root)
            setActivePane(root, 0)
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

    var nextActive = Math.max(0, index - 1)
    root.primaryTabIndex = nextActive
    root.secondaryTabIndex = -1
    root.currentTabIndex = nextActive
    root.activePane = 0
    syncEditorsFromModel(root)
}

function renameTab(root, index, newTitle) {
    if (!root || !root.tabsModel || index < 0 || index >= root.tabsModel.count) return

    var finalTitle = stripExt((newTitle || "").trim())
    if (!finalTitle) finalTitle = "Новый документ"

    var tab = root.tabsModel.get(index)
    if (tab && tab.fileUrl && typeof backend !== "undefined" && backend) {
        var res = backend.rename_file(tab.fileUrl, finalTitle)
        if (res && res.success) {
            root.tabsModel.setProperty(index, "fileUrl", res.fileUrl)
            finalTitle = stripExt(res.fileName)
        }
    } else if (tab && (!tab.fileUrl || tab.fileUrl === "") && typeof backend !== "undefined" && backend && root.currentFolderUrl) {
        var resCreate = backend.create_file_in_folder(root.currentFolderUrl, finalTitle)
        if (resCreate && resCreate.success) {
            root.tabsModel.setProperty(index, "fileUrl", resCreate.fileUrl)
            finalTitle = stripExt(resCreate.fileName)
            root.reloadFolderFiles()
        }
    }

    root.tabsModel.setProperty(index, "title", finalTitle)

    var updatedUrl = (root.tabsModel.get(index) && root.tabsModel.get(index).fileUrl) ? root.tabsModel.get(index).fileUrl : ""
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

function closeSplit(root) {
    if (!root) return
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
    if (!root) return
    if (root.isSplit) {
        closeSplit(root)
    } else {
        if (root.tabsModel.count === 0) {
            createNewTab(root, false)
            return
        }
        var curPrimary = root.primaryTabIndex
        var otherIdx = -1
        for (var i = 0; i < root.tabsModel.count; i++) {
            if (i !== curPrimary) {
                otherIdx = i
                break
            }
        }
        if (otherIdx === -1) {
            root.tabsModel.append({
                title: "Документ " + (root.tabsModel.count + 1),
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
        setActivePane(root, 1)
    }
}

function openFileFromFolder(root, fileUrl, fileName, isShift) {
    if (!root || typeof backend === "undefined" || !backend || !fileUrl) return
    if (root.splitLayout && typeof root.splitLayout.closeGraph === "function") {
        root.splitLayout.closeGraph()
    }

    var cleanName = stripExt(fileName)
    var content = backend.read_file(fileUrl)

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
            var targetIdx = (root.activePane === 0) ? root.secondaryTabIndex : root.primaryTabIndex
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

    if (root.primaryTabIndex >= 0 && root.primaryTabIndex < root.tabsModel.count) {
        var pTab = root.tabsModel.get(root.primaryTabIndex)
        if (pTab && pTab.fileUrl === fileUrl) {
            setActivePane(root, 0)
            return
        }
    }
    if (root.isSplit && root.secondaryTabIndex >= 0 && root.secondaryTabIndex < root.tabsModel.count) {
        var sTab = root.tabsModel.get(root.secondaryTabIndex)
        if (sTab && sTab.fileUrl === fileUrl) {
            setActivePane(root, 1)
            return
        }
    }

    syncCurrentPaneText(root)

    var activeIdx = (root.isSplit && root.activePane === 1) ? root.secondaryTabIndex : root.primaryTabIndex
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

function replaceBlockInString(text, headingNorm, newContent) {
    if (!text) return text
    var headingRegex = /^[ \t]*(#{1,6})\s+(.+)$/gm
    var match
    var matches = []
    while ((match = headingRegex.exec(text)) !== null) {
        matches.push({
            start: match.index,
            end: match.index + match[0].length,
            title: match[2].trim()
        })
    }

    var updatedText = text
    for (var i = matches.length - 1; i >= 0; i--) {
        var m = matches[i]
        if (m.title.toLowerCase() === headingNorm.toLowerCase()) {
            var contentStart = m.end
            var contentEnd = (i + 1 < matches.length) ? matches[i + 1].start : text.length
            var oldContent = text.substring(contentStart, contentEnd)
            var cleanOld = oldContent.replace(/^\r?\n/, "").replace(/\r?\n$/, "")
            var cleanNew = newContent.replace(/^\r?\n/, "").replace(/\r?\n$/, "")
            if (cleanOld === cleanNew) continue

            var formattedNew = "\n" + cleanNew + (i + 1 < matches.length ? "\n\n" : "\n")
            var before = updatedText.substring(0, contentStart)
            var after = updatedText.substring(contentEnd)
            updatedText = before + formattedNew + after
        }
    }
    return updatedText
}

// =========================================================================
// Файлы папки и конфигурация
// =========================================================================
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
    } catch(e) {}
}

function handleBlockUpdated(root, splitLayout, headingNorm, content, sourceFileUrl) {
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
                var replaced = replaceBlockInString(tab.content, headingNorm, content)
                if (replaced !== tab.content) {
                    tab.content = replaced
                }
            }
        }
    }
}

function applyInitialState(root) {
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
        syncEditorsFromModel(root)
        return true
    }
    return false
}

function initWebRoot(root, backend) {
    if (!root) return
    reloadAppConfig(root, root.autoSaveTimer, backend)
    initializeWorkspace(root, backend)
}

function initializeWorkspace(root, backend) {
    var hasInitialDoc = applyInitialState(root)

    if (backend) {
        root.currentFolderUrl = backend.get_default_folder()
        root.currentFolderName = backend.get_folder_name(root.currentFolderUrl)

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
                syncEditorsFromModel(root)
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

// =========================================================================
// Диспетчеризация действий (Actions) и сохранение
// =========================================================================
function closeActiveTab(root) {
    if (root && root.isGraphVisible) {
        if (root.splitLayout && typeof root.splitLayout.closeGraph === "function") {
            root.splitLayout.closeGraph()
        }
        return
    }
    if (!root || !root.tabsModel || root.tabsModel.count === 0) return
    var targetIdx = getActiveTabIndex(root)
    if (targetIdx >= 0 && targetIdx < root.tabsModel.count) {
        root.closeTab(targetIdx)
    } else if (root.currentTabIndex >= 0 && root.currentTabIndex < root.tabsModel.count) {
        root.closeTab(root.currentTabIndex)
    } else {
        root.closeTab(root.tabsModel.count - 1)
    }
}

function saveFile(root, saveDialog, backend) {
    if (!root) return
    var targetIndex = getActiveTabIndex(root)
    var tab = (root.tabsModel && targetIndex >= 0 && targetIndex < root.tabsModel.count) ? root.tabsModel.get(targetIndex) : null
    var fileUrl = tab ? (tab.fileUrl || "") : (root.currentFileUrl || "")

    if (!fileUrl) {
        if (saveDialog && typeof saveDialog.open === "function") {
            saveDialog.open()
        }
    } else {
        var text = (root.editorArea ? root.editorArea.text : "")
        if (backend) {
            backend.save_file(fileUrl, text)
        }
        if (tab) {
            tab.content = text
        }
    }
}

function dispatchAction(root, splitLayout, openDialog, saveDialog, backend, Markdown, action) {
    switch (action) {
        case "toggle_header_footer":
            applyToBothBars(splitLayout, "toggleHeaderFooter")
            break
        case "toggle_footer":
            applyToBothBars(splitLayout, "toggleFooterOnly")
            break
        case "toggle_header":
            applyToBothBars(splitLayout, "toggleHeaderOnly")
            break
        case "toggle_search":
            if (splitLayout && typeof splitLayout.toggleSearch === "function") {
                splitLayout.toggleSearch()
            }
            break
        case "toggle_split":
            if (root && typeof root.toggleSplit === "function") {
                root.toggleSplit()
            }
            break
        case "toggle_centered_mode":
            if (splitLayout && splitLayout.primaryBar) {
                if (typeof splitLayout.primaryBar.toggleCenteredMode === "function") {
                    splitLayout.primaryBar.toggleCenteredMode()
                } else {
                    splitLayout.primaryBar.isCenteredMode = !splitLayout.primaryBar.isCenteredMode
                }
            }
            if (splitLayout && splitLayout.isSplit && splitLayout.secondaryBar && splitLayout.primaryBar) {
                if (typeof splitLayout.secondaryBar.toggleCenteredMode === "function") {
                    splitLayout.secondaryBar.isCenteredMode = splitLayout.primaryBar.isCenteredMode
                } else {
                    splitLayout.secondaryBar.isCenteredMode = splitLayout.primaryBar.isCenteredMode
                }
            }
            break
        case "close_tab":
            closeActiveTab(root)
            break
        case "new_tab":
            if (root && typeof root.createNewTab === "function") {
                root.createNewTab(false)
            }
            break
        case "new_tab_split":
            if (root && typeof root.createNewTab === "function") {
                root.createNewTab(true)
            }
            break
        case "open_file":
            if (root) root.openFileInSplit = false
            if (openDialog && typeof openDialog.open === "function") {
                openDialog.open()
            }
            break
        case "open_file_split":
            if (root) root.openFileInSplit = true
            if (openDialog && typeof openDialog.open === "function") {
                openDialog.open()
            }
            break
        case "save_file":
            saveFile(root, saveDialog, backend)
            break
        case "toggle_bold":
            if (splitLayout && splitLayout.activeEditorArea && Markdown) {
                Markdown.toggleBold(splitLayout.activeEditorArea)
            }
            break
        case "toggle_italic":
            if (splitLayout && splitLayout.activeEditorArea && Markdown) {
                Markdown.toggleItalic(splitLayout.activeEditorArea)
            }
            break
        case "toggle_graph":
            if (splitLayout && typeof splitLayout.toggleGraph === "function") {
                splitLayout.toggleGraph()
            }
            break
        case "toggle_local_graph":
            if (splitLayout) {
                var activeBarG = getActiveBar(root, splitLayout)
                if (activeBarG) activeBarG.isOutlineMode = false
                if (typeof splitLayout.toggleLocalGraph === "function") {
                    splitLayout.toggleLocalGraph()
                }
            }
            break
        case "show_text_mode":
            if (splitLayout && typeof splitLayout.closeGraph === "function") {
                splitLayout.closeGraph()
            }
            var barText = getActiveBar(root, splitLayout)
            if (barText) {
                barText.isOutlineMode = false
                if (typeof barText.showTextMode === "function") barText.showTextMode()
            }
            break
        case "toggle_outline":
            if (splitLayout && typeof splitLayout.closeGraph === "function") {
                splitLayout.closeGraph()
            }
            var barOutline = getActiveBar(root, splitLayout)
            if (barOutline && typeof barOutline.toggleOutlineMode === "function") {
                barOutline.toggleOutlineMode()
            }
            break
        case "toggle_live_preview":
            if (backend && typeof backend.toggle_live_preview === "function") {
                var activeArea = splitLayout ? splitLayout.activeEditorArea : null
                backend.toggle_live_preview(activeArea)
            }
            break
        case "open_structure":
            if (root && typeof root.toggleProjectStructure === "function") {
                root.toggleProjectStructure()
            }
            break
        case "toggle_history":
            var barHist = getActiveBar(root, splitLayout)
            if (barHist && typeof barHist.toggleHistoryMode === "function") {
                barHist.toggleHistoryMode()
            }
            break
        case "toggle_history_playback":
            var barPlay = getActiveBar(root, splitLayout)
            if (barPlay && typeof barPlay.toggleHistoryPlayback === "function") {
                barPlay.toggleHistoryPlayback(false)
            }
            break
        case "play_history_from_start":
            var barStart = getActiveBar(root, splitLayout)
            if (barStart && typeof barStart.toggleHistoryPlayback === "function") {
                barStart.toggleHistoryPlayback(true)
            }
            break
        case "navigate_pane_left":
            if (splitLayout && typeof splitLayout.navigateLeft === "function") {
                splitLayout.navigateLeft()
            } else if (root && root.isSplit) {
                root.activePane = 0
            }
            break
        case "navigate_pane_right":
            if (splitLayout && typeof splitLayout.navigateRight === "function") {
                splitLayout.navigateRight()
            } else if (root && root.isSplit) {
                root.activePane = 1
            }
            break
        case "show_source_view":
            var barSrc = getActiveBar(root, splitLayout)
            if (barSrc && typeof barSrc.showTextMode === "function") barSrc.showTextMode()
            break
        case "show_hierarchy_view":
            var barHier = getActiveBar(root, splitLayout)
            if (barHier && typeof barHier.showHierarchyMode === "function") barHier.showHierarchyMode()
            break
        case "show_graph_view":
            var barGraph = getActiveBar(root, splitLayout)
            if (barGraph && typeof barGraph.showGraphMode === "function") barGraph.showGraphMode()
            break
    }
}

// =========================================================================
// Автосохранение и обработчики диалогов
// =========================================================================
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

function handleFileOpenAccepted(root, backend, selectedFile) {
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
            syncEditorsFromModel(root)
            setActivePane(root, 0)
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
        syncEditorsFromModel(root)
        setActivePane(root, 1)
        return
    }

    var targetIndex = getActiveTabIndex(root)
    var curTab = (targetIndex >= 0 && targetIndex < root.tabsModel.count) ? root.tabsModel.get(targetIndex) : null

    if (curTab && !curTab.isDetached && curTab.fileUrl === "" && root.editorArea && root.editorArea.text === "") {
        root.tabsModel.setProperty(targetIndex, "title", cleanName)
        root.tabsModel.setProperty(targetIndex, "fileUrl", selectedFile)
        root.tabsModel.setProperty(targetIndex, "content", content)
        syncEditorsFromModel(root)
    } else {
        root.tabsModel.append({
            title: cleanName,
            fileUrl: selectedFile,
            content: content,
            isDetached: false
        })
        switchToTab(root, root.tabsModel.count - 1)
    }
}

function handleFileSaveAccepted(root, backend, selectedFile) {
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
        syncEditorsFromModel(root)
    }
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

function toggleProjectStructure(root, splitLayout, backend) {
    if (!root || !backend) return

    var activeBar = getActiveBar(root, splitLayout)
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
            openFileFromFolder(root, root.previousFileUrlBeforeStructure, root.previousFileNameBeforeStructure, false)
        } else if (root.tabsModel.count > 1) {
            for (var t = 0; t < root.tabsModel.count; t++) {
                var tabItem = root.tabsModel.get(t)
                if (tabItem && tabItem.fileUrl && tabItem.fileUrl !== curUrl) {
                    openFileFromFolder(root, tabItem.fileUrl, tabItem.title, false)
                    break
                }
            }
        }
        return
    }

    syncCurrentPaneText(root)

    root.previousFileUrlBeforeStructure = curUrl
    root.previousFileNameBeforeStructure = curName
    root.highlightStructureItem = stripExt(curName)

    var info = backend.sync_project_structure_file(root.currentFolderUrl)
    if (info && info.fileUrl) {
        openFileFromFolder(root, info.fileUrl, info.fileName, false)
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
    var activeBar = getActiveBar(root, splitLayout)
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
            toggleProjectStructure(root, splitLayout, backend)
            event.accepted = true
            return true
        }
        if (splitLayout && splitLayout.isGraphVisible && typeof splitLayout.closeGraph === "function") {
            splitLayout.closeGraph()
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
    var targetBar = getActiveBar(root, splitLayout)
    if (targetBar) {
        targetBar.isOutlineMode = false
    }
    openFileFromFolder(root, fUrl, lbl, false)
}
