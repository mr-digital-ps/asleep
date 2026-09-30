// js/tabs/tab_sync.js — Синхронизация моделей вкладок, содержимого сплит-панелей и Markdown-блоков

function stripExt(name) {
    if (!name) return ""
    return name.replace(/\.md$/i, "")
}

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
