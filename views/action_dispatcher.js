// action_dispatcher.js — Диспетчеризация действий интерфейса и хоткеев

function closeActiveTab(root) {
    if (root && root.isGraphVisible) {
        if (typeof root.closeGraph === "function") {
            root.closeGraph()
        }
        return
    }
    if (!root || !root.tabsModel || root.tabsModel.count === 0) return
    var targetIdx = (root.isSplit && root.activePane === 1) ? root.secondaryTabIndex : root.primaryTabIndex
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
    var targetIndex = (root.isSplit && root.activePane === 1) ? root.secondaryTabIndex : root.primaryTabIndex
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

function dispatchAction(root, splitLayout, openDialog, saveDialog, backend, Markdown, Tabs, action) {
    switch (action) {
        case "toggle_header_footer":
            if (splitLayout && splitLayout.primaryBar && typeof splitLayout.primaryBar.toggleHeaderFooter === "function") {
                splitLayout.primaryBar.toggleHeaderFooter()
            }
            if (splitLayout && splitLayout.isSplit && splitLayout.secondaryBar && typeof splitLayout.secondaryBar.toggleHeaderFooter === "function") {
                splitLayout.secondaryBar.toggleHeaderFooter()
            }
            break
        case "toggle_footer":
            if (splitLayout && splitLayout.primaryBar && typeof splitLayout.primaryBar.toggleFooterOnly === "function") {
                splitLayout.primaryBar.toggleFooterOnly()
            }
            if (splitLayout && splitLayout.isSplit && splitLayout.secondaryBar && typeof splitLayout.secondaryBar.toggleFooterOnly === "function") {
                splitLayout.secondaryBar.toggleFooterOnly()
            }
            break
        case "toggle_header":
            if (splitLayout && splitLayout.primaryBar && typeof splitLayout.primaryBar.toggleHeaderOnly === "function") {
                splitLayout.primaryBar.toggleHeaderOnly()
            }
            if (splitLayout && splitLayout.isSplit && splitLayout.secondaryBar && typeof splitLayout.secondaryBar.toggleHeaderOnly === "function") {
                splitLayout.secondaryBar.toggleHeaderOnly()
            }
            break
        case "toggle_search":
            if (root && typeof root.toggleSearch === "function") {
                root.toggleSearch()
            } else if (splitLayout && typeof splitLayout.toggleSearch === "function") {
                splitLayout.toggleSearch()
            }
            break
        case "toggle_split":
            if (root && typeof root.toggleSplit === "function") {
                root.toggleSplit()
            }
            break
        case "toggle_sidebar":
            if (root && typeof root.toggleSidebar === "function") {
                root.toggleSidebar()
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
        case "detach_window":
            var targetIdx = (root.isSplit && root.activePane === 1) ? root.secondaryTabIndex : root.primaryTabIndex
            if (Tabs && typeof Tabs.detachTab === "function") {
                Tabs.detachTab(root, targetIdx >= 0 ? targetIdx : 0)
            }
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
            if (root) {
                if (typeof root.toggleGraph === "function") {
                    root.toggleGraph()
                }
            }
            break
        case "toggle_local_graph":
            if (splitLayout) {
                var activeBarG = (splitLayout.isSplit && splitLayout.activePane === 1) ? splitLayout.secondaryBar : splitLayout.primaryBar
                if (activeBarG) {
                    activeBarG.isOutlineMode = false
                }
            }
            if (root) {
                if (typeof root.toggleLocalGraph === "function") {
                    root.toggleLocalGraph()
                }
            }
            break
        case "show_text_mode":
            if (root && typeof root.closeGraph === "function") {
                root.closeGraph()
            }
            if (splitLayout) {
                var targetBarText = (splitLayout.isSplit && splitLayout.activePane === 1) ? splitLayout.secondaryBar : splitLayout.primaryBar
                if (targetBarText) {
                    targetBarText.isOutlineMode = false
                    if (typeof targetBarText.showTextMode === "function") {
                        targetBarText.showTextMode()
                    }
                }
            }
            break
        case "toggle_outline":
            if (root && typeof root.closeGraph === "function") {
                root.closeGraph()
            }
            if (splitLayout) {
                var targetBar = (splitLayout.isSplit && splitLayout.activePane === 1) ? splitLayout.secondaryBar : splitLayout.primaryBar
                if (targetBar && typeof targetBar.toggleOutlineMode === "function") {
                    targetBar.toggleOutlineMode()
                }
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
            if (splitLayout) {
                var targetBarH = (splitLayout.isSplit && splitLayout.activePane === 1) ? splitLayout.secondaryBar : splitLayout.primaryBar
                if (targetBarH && typeof targetBarH.toggleHistoryMode === "function") {
                    targetBarH.toggleHistoryMode()
                }
            }
            break
        case "toggle_history_playback":
            if (splitLayout) {
                var targetBarP = (splitLayout.isSplit && splitLayout.activePane === 1) ? splitLayout.secondaryBar : splitLayout.primaryBar
                if (targetBarP && typeof targetBarP.toggleHistoryPlayback === "function") {
                    targetBarP.toggleHistoryPlayback(false)
                }
            }
            break
        case "play_history_from_start":
            if (splitLayout) {
                var targetBarS = (splitLayout.isSplit && splitLayout.activePane === 1) ? splitLayout.secondaryBar : splitLayout.primaryBar
                if (targetBarS && typeof targetBarS.toggleHistoryPlayback === "function") {
                    targetBarS.toggleHistoryPlayback(true)
                }
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
            if (splitLayout) {
                var targetBarSrc = (splitLayout.isSplit && root && root.activePane === 1) ? splitLayout.secondaryBar : splitLayout.primaryBar
                if (targetBarSrc && typeof targetBarSrc.showTextMode === "function") {
                    targetBarSrc.showTextMode()
                }
            }
            break
        case "show_hierarchy_view":
            if (splitLayout) {
                var targetBarHier = (splitLayout.isSplit && root && root.activePane === 1) ? splitLayout.secondaryBar : splitLayout.primaryBar
                if (targetBarHier && typeof targetBarHier.showHierarchyMode === "function") {
                    targetBarHier.showHierarchyMode()
                }
            }
            break
        case "show_graph_view":
            if (splitLayout) {
                var targetBarG = (splitLayout.isSplit && root && root.activePane === 1) ? splitLayout.secondaryBar : splitLayout.primaryBar
                if (targetBarG && typeof targetBarG.showGraphMode === "function") {
                    targetBarG.showGraphMode()
                }
            }
            break
    }
}


