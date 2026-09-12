// editor_keys.js — Кроссплатформенная обработка горячих клавиш и скан-кодов редактора

function isCloseKey(event) {
    if (!(event.modifiers & Qt.ControlModifier)) return false
    if (event.key === Qt.Key_W || event.nativeScanCode === 17 || event.text === 'w' || event.text === 'W' || event.text === 'ц' || event.text === 'Ц' || event.key === 1062 || event.key === 1030) return true
    if (event.key === Qt.Key_Q || event.nativeScanCode === 16 || event.text === 'q' || event.text === 'Q' || event.text === 'й' || event.text === 'Й' || event.key === 1081 || event.key === 1049) return true
    return false
}

function isSaveKey(event) {
    if (!(event.modifiers & Qt.ControlModifier)) return false
    return (event.key === Qt.Key_S || event.nativeScanCode === 31 || event.text === 's' || event.text === 'S' || event.text === 'ы' || event.text === 'Ы')
}

function isNewKey(event) {
    if (!(event.modifiers & Qt.ControlModifier)) return false
    return (event.key === Qt.Key_N || event.nativeScanCode === 49 || event.text === 'n' || event.text === 'N' || event.text === 'т' || event.text === 'Т')
}

function isToggleSidebarKey(event) {
    var isB = event.key === Qt.Key_B || event.nativeScanCode === 48 || event.text === 'b' || event.text === 'B' || event.text === 'и' || event.text === 'И'
    if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier) && isB) return true
    var isS = event.key === Qt.Key_S || event.nativeScanCode === 31 || event.text === 's' || event.text === 'S' || event.text === 'ы' || event.text === 'Ы'
    if ((event.modifiers & Qt.AltModifier) && isS) return true
    return false
}

function isToggleHeaderFooterKey(event) {
    if (event.key === Qt.Key_F9) return true
    var isH = event.key === Qt.Key_H || event.nativeScanCode === 35 || event.text === 'h' || event.text === 'H' || event.text === 'р' || event.text === 'Р'
    if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier) && isH) return true
    if ((event.modifiers & Qt.AltModifier) && isH) return true
    return false
}

function isToggleFooterKey(event) {
    var isF = event.key === Qt.Key_F || event.nativeScanCode === 33 || event.text === 'f' || event.text === 'F' || event.text === 'а' || event.text === 'А'
    if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier) && isF) return true
    if ((event.modifiers & Qt.AltModifier) && isF) return true
    return false
}

function isToggleHeaderKey(event) {
    var isU = event.key === Qt.Key_U || event.nativeScanCode === 22 || event.text === 'u' || event.text === 'U' || event.text === 'г' || event.text === 'Г'
    if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier) && isU) return true
    if ((event.modifiers & Qt.AltModifier) && isU) return true
    return false
}

function isCenteredModeKey(event) {
    var isW = event.key === Qt.Key_W || event.nativeScanCode === 17 || event.text === 'w' || event.text === 'W' || event.text === 'ц' || event.text === 'Ц'
    if ((event.modifiers & Qt.AltModifier) && isW) return true
    if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier) && isW) return true
    return false
}

function handleShortcutOverride(event, canvasRoot, editorArea, Markdown) {
    if (isCloseKey(event)) {
        event.accepted = true
        canvasRoot.closeRequested()
        return true
    }
    if (isToggleHeaderFooterKey(event)) {
        event.accepted = true
        canvasRoot.toggleHeaderFooterRequested()
        return true
    }
    if (isToggleFooterKey(event)) {
        event.accepted = true
        canvasRoot.toggleFooterRequested()
        return true
    }
    if (isToggleHeaderKey(event)) {
        event.accepted = true
        canvasRoot.toggleHeaderRequested()
        return true
    }
    if (isCenteredModeKey(event)) {
        event.accepted = true
        canvasRoot.toggleCenteredModeRequested()
        return true
    }
    if (isSaveKey(event)) {
        event.accepted = true
        canvasRoot.saveRequested()
        return true
    }
    if (isNewKey(event)) {
        event.accepted = true
        canvasRoot.newRequested()
        return true
    }
    if (isToggleSidebarKey(event)) {
        event.accepted = true
        canvasRoot.toggleSidebarRequested()
        return true
    }

    if (event.modifiers & Qt.ControlModifier) {
        var isD = event.key === Qt.Key_D || event.nativeScanCode === 32 || event.text === 'd' || event.text === 'D' || event.text === 'в' || event.text === 'В'
        if (isD) {
            event.accepted = true
            canvasRoot.detachRequested()
            return true
        }
        var isB = event.key === Qt.Key_B || event.nativeScanCode === 48 || event.text === 'b' || event.text === 'B' || event.text === 'и' || event.text === 'И'
        if (isB) {
            event.accepted = true
            Markdown.toggleBold(editorArea)
            return true
        }
        var isI = event.key === Qt.Key_I || event.nativeScanCode === 23 || event.text === 'i' || event.text === 'I' || event.text === 'ш' || event.text === 'Ш'
        if (isI) {
            event.accepted = true
            Markdown.toggleItalic(editorArea)
            return true
        }
        if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Tab) {
            event.accepted = true
            Markdown.handleTab(editorArea, true)
            return true
        }
    }
    return false
}

function handleKeyPressed(event, canvasRoot, editorArea, Markdown) {
    if (isCloseKey(event)) {
        event.accepted = true
        canvasRoot.closeRequested()
        return true
    }
    if (isToggleHeaderFooterKey(event)) {
        event.accepted = true
        canvasRoot.toggleHeaderFooterRequested()
        return true
    }
    if (isToggleFooterKey(event)) {
        event.accepted = true
        canvasRoot.toggleFooterRequested()
        return true
    }
    if (isToggleHeaderKey(event)) {
        event.accepted = true
        canvasRoot.toggleHeaderRequested()
        return true
    }
    if (isCenteredModeKey(event)) {
        event.accepted = true
        canvasRoot.toggleCenteredModeRequested()
        return true
    }
    if (isSaveKey(event)) {
        event.accepted = true
        canvasRoot.saveRequested()
        return true
    }
    if (isNewKey(event)) {
        event.accepted = true
        canvasRoot.newRequested()
        return true
    }
    if (isToggleSidebarKey(event)) {
        event.accepted = true
        canvasRoot.toggleSidebarRequested()
        return true
    }

    // Автозакрытие скобок и кавычек
    if (event.key === Qt.Key_ParenRight && Markdown.handleAutoPair(editorArea, ")")) {
        event.accepted = true
        return true
    }
    if (event.key === Qt.Key_BracketRight && Markdown.handleAutoPair(editorArea, "]")) {
        event.accepted = true
        return true
    }
    if (event.key === Qt.Key_BraceRight && Markdown.handleAutoPair(editorArea, "}")) {
        event.accepted = true
        return true
    }
    if ((event.key === Qt.Key_QuoteDbl || event.key === 1069) && Markdown.handleAutoPair(editorArea, "\"")) {
        event.accepted = true
        return true
    }
    if ((event.text === "`" || event.key === 1025 || event.key === 1105) && Markdown.handleAutoPair(editorArea, "`")) {
        event.accepted = true
        return true
    }
    if (event.key === Qt.Key_ParenLeft && Markdown.handleAutoPair(editorArea, "(")) {
        event.accepted = true
        return true
    }
    if (event.key === Qt.Key_BracketLeft && Markdown.handleAutoPair(editorArea, "[")) {
        event.accepted = true
        return true
    }
    if (event.key === Qt.Key_BraceLeft && Markdown.handleAutoPair(editorArea, "{")) {
        event.accepted = true
        return true
    }

    if (event.modifiers & Qt.ControlModifier) {
        if (event.key === Qt.Key_B) {
            event.accepted = true
            Markdown.toggleBold(editorArea)
            return true
        }
        if (event.key === Qt.Key_I) {
            event.accepted = true
            Markdown.toggleItalic(editorArea)
            return true
        }
    }

    return false
}
