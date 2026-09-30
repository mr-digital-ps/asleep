// js/editor/outliner_controller.js — Расчет отступов, скрытия и навигации аутлайнера
.pragma library

function findHighlightIndex(highlightLabel, blocksList) {
    if (!highlightLabel || !blocksList || blocksList.length === 0) return -1
    var targetLower = highlightLabel.toLowerCase().trim()
    for (var i = 0; i < blocksList.length; i++) {
        var it = blocksList[i]
        var lbl = (it.label || it.heading || "").toLowerCase().trim()
        if (lbl === targetLower) {
            return i
        }
    }
    return -1
}

function getItemKey(item) {
    if (!item) return ""
    return item.key || item.id || item.label || item.heading || ""
}

function toggleFolder(collapsedFolders, folderKey) {
    if (!folderKey) return collapsedFolders || {}
    var copy = Object.assign({}, collapsedFolders || {})
    if (copy[folderKey]) {
        delete copy[folderKey]
    } else {
        copy[folderKey] = true
    }
    return copy
}

function isFolderCollapsed(collapsedFolders, folderKey) {
    if (!collapsedFolders || !folderKey) return false
    return Boolean(collapsedFolders[folderKey])
}

// Универсальное скрытие элементов (как для дерева проекта, так и для оглавления заметки)
function isItemHidden(itemIdx, blocksList, collapsedFolders) {
    if (!blocksList || itemIdx < 0 || itemIdx >= blocksList.length) return false
    var currentItem = blocksList[itemIdx]
    if (!currentItem) return false
    var curLevel = (typeof currentItem.level === "number") ? currentItem.level : 0

    // Идем вверх по иерархии: если любой вышестоящий предок свернут, текущий элемент скрыт
    for (var i = itemIdx - 1; i >= 0; i--) {
        var prev = blocksList[i]
        if (!prev) continue
        var prevLevel = (typeof prev.level === "number") ? prev.level : 0
        if (prevLevel < curLevel) {
            var k = prev.key || prev.id || prev.label || prev.heading
            if (collapsedFolders && k && collapsedFolders[k]) {
                return true
            }
            curLevel = prevLevel
            if (curLevel === 0) break
        }
    }
    return false
}

function collapseAll(blocksList) {
    var result = {}
    if (!blocksList) return result
    for (var i = 0; i < blocksList.length; i++) {
        var it = blocksList[i]
        if (it && it.hasChildren) {
            var k = it.key || it.id || it.label || it.heading
            if (k) result[k] = true
        }
    }
    return result
}

function expandAll() {
    return {}
}

function countVisible(blocksList, collapsedFolders) {
    if (!blocksList) return 0
    var count = 0
    for (var i = 0; i < blocksList.length; i++) {
        if (!isItemHidden(i, blocksList, collapsedFolders)) {
            count++
        }
    }
    return count
}

function calculateIndentPx(isProjectTree, blockLevel) {
    var lvl = Math.max(0, blockLevel || 0)
    if (isProjectTree) {
        return lvl * 18
    }
    return Math.max(0, (lvl > 0 ? (lvl - 1) : 0) * 18)
}

function getLabelText(isProjectTree, modelData) {
    if (!modelData) return ""
    if (modelData.label) return modelData.label
    if (modelData.heading) return modelData.heading
    if (modelData.level === 0 && modelData.content) return "Введение"
    return "(Без заголовка)"
}

