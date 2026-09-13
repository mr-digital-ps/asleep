// js/tabs/tabs.js — Фасад управления вкладками (объединяет tab_model, tab_split, tab_sync)
.import "tab_model.js" as Model
.import "tab_split.js" as Split
.import "tab_sync.js" as Sync

function stripExt(name) {
    return Model.stripExt(name)
}

function findTabIndex(root, fileUrl) {
    return Model.findTabIndex(root, fileUrl)
}

function findOtherTabIndex(root, excludeIdx) {
    return Model.findOtherTabIndex(root, excludeIdx)
}

function getFileContent(root, fileUrl) {
    return Model.getFileContent(root, fileUrl)
}

function replaceBlockInString(text, headingNorm, newContent) {
    return Sync.replaceBlockInString(text, headingNorm, newContent)
}

function syncCurrentPaneText(root) {
    return Sync.syncCurrentPaneText(root)
}

function syncEditorsFromModel(root) {
    return Sync.syncEditorsFromModel(root)
}

function setActivePane(root, paneIndex) {
    return Split.setActivePane(root, paneIndex)
}

function switchToTab(root, index) {
    return Split.switchToTab(root, index, Sync.syncCurrentPaneText, Sync.syncEditorsFromModel)
}

function createNewTab(root) {
    return Model.createNewTab(root, Sync.syncCurrentPaneText, Sync.syncEditorsFromModel, Split.setActivePane, function(r, i) {
        Split.switchToTab(r, i, Sync.syncCurrentPaneText, Sync.syncEditorsFromModel)
    })
}

function closeTab(root, index) {
    return Model.closeTab(root, index, Sync.syncCurrentPaneText, Sync.syncEditorsFromModel, Split.setActivePane, function(r) {
        Split.closeSplit(r, Sync.syncCurrentPaneText, Sync.syncEditorsFromModel)
    })
}

function renameTab(root, index, newTitle) {
    return Model.renameTab(root, index, newTitle)
}

function closeSplit(root) {
    return Split.closeSplit(root, Sync.syncCurrentPaneText, Sync.syncEditorsFromModel)
}

function toggleSplit(root) {
    return Split.toggleSplit(root, Sync.syncCurrentPaneText, Sync.syncEditorsFromModel, function(r) {
        createNewTab(r)
    }, Model.findOtherTabIndex)
}

function swapPanes(root) {
    return Split.swapPanes(root, Sync.syncEditorsFromModel)
}

function handlePrimaryTextChanged(root, text) {
    return Sync.handlePrimaryTextChanged(root, text)
}

function handleSecondaryTextChanged(root, text) {
    return Sync.handleSecondaryTextChanged(root, text)
}

function detachTab(root, tabIndex) {
    return Model.detachTab(root, tabIndex, function(r, i) {
        closeTab(r, i)
    })
}

function openInNewWindow(root, fileUrl, fileName, wx, wy) {
    return Model.openInNewWindow(root, fileUrl, fileName, wx, wy)
}


function openFileFromFolder(root, fileUrl, fileName, isShift) {
    return Model.openFileFromFolder(root, fileUrl, fileName, isShift, Sync.syncCurrentPaneText, Sync.syncEditorsFromModel, Split.setActivePane, function(r, i) {
        Split.switchToTab(r, i, Sync.syncCurrentPaneText, Sync.syncEditorsFromModel)
    })
}
