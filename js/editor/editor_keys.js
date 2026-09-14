// js/editor/editor_keys.js — Кроссплатформенная обработка горячих клавиш и скан-кодов редактора

function isCloseKey(event) {
    if (!(event.modifiers & Qt.ControlModifier)) return false
    // W (scan 17, 'ц')
    if (event.key === Qt.Key_W || event.nativeScanCode === 17 || event.key === 1062 || event.key === 1094 || event.text === 'w' || event.text === 'W' || event.text === 'ц' || event.text === 'Ц' || event.key === 1030) return true
    // Q (scan 16, 'й')
    if (event.key === Qt.Key_Q || event.nativeScanCode === 16 || event.key === 1049 || event.key === 1081 || event.text === 'q' || event.text === 'Q' || event.text === 'й' || event.text === 'Й') return true
    return false
}

function isSaveKey(event) {
    if (!(event.modifiers & Qt.ControlModifier)) return false
    // S (scan 31, 'ы')
    return (event.key === Qt.Key_S || event.nativeScanCode === 31 || event.key === 1067 || event.key === 1099 || event.text === 's' || event.text === 'S' || event.text === 'ы' || event.text === 'Ы')
}

function isNewKey(event) {
    if (!(event.modifiers & Qt.ControlModifier)) return false
    // N (scan 49, 'т')
    return (event.key === Qt.Key_N || event.nativeScanCode === 49 || event.key === 1058 || event.key === 1090 || event.text === 'n' || event.text === 'N' || event.text === 'т' || event.text === 'Т')
}

function isOpenKey(event) {
    if (!(event.modifiers & Qt.ControlModifier)) return false
    // O (scan 24, 'щ')
    return (event.key === Qt.Key_O || event.nativeScanCode === 24 || event.key === 1065 || event.key === 1097 || event.text === 'o' || event.text === 'O' || event.text === 'щ' || event.text === 'Щ')
}

function isToggleSplitKey(event) {
    if (!(event.modifiers & Qt.ControlModifier)) return false
    // Backslash (scan 43, 86, '\', '/')
    return (event.key === Qt.Key_Backslash || event.nativeScanCode === 43 || event.nativeScanCode === 86 || event.key === 92 || event.text === '\\' || event.text === '/')
}

function isToggleGraphKey(event) {
    if (!(event.modifiers & Qt.ControlModifier)) return false
    // G (scan 34, 'п')
    var isG = (event.key === Qt.Key_G || event.nativeScanCode === 34 || event.key === 1055 || event.key === 1087 || event.text === 'g' || event.text === 'G' || event.text === 'п' || event.text === 'П')
    // U (mnemonic Г, scan 22, 'г')
    var isRuGe = (event.key === Qt.Key_U || event.nativeScanCode === 22 || event.key === 1043 || event.key === 1075 || event.text === 'u' || event.text === 'U' || event.text === 'г' || event.text === 'Г')
    return isG || isRuGe
}

function isDetachKey(event) {
    // D (scan 32, 'в')
    var isD = (event.key === Qt.Key_D || event.nativeScanCode === 32 || event.key === 1042 || event.key === 1074 || event.text === 'd' || event.text === 'D' || event.text === 'в' || event.text === 'В')
    return isD && ((event.modifiers & Qt.ControlModifier) || (event.modifiers & Qt.AltModifier))
}

function isBoldKey(event) {
    if (!(event.modifiers & Qt.ControlModifier)) return false
    // B (scan 48, 'и')
    return (event.key === Qt.Key_B || event.nativeScanCode === 48 || event.key === 1048 || event.key === 1080 || event.text === 'b' || event.text === 'B' || event.text === 'и' || event.text === 'И')
}

function isItalicKey(event) {
    if (!(event.modifiers & Qt.ControlModifier)) return false
    // I (scan 23, 'ш')
    return (event.key === Qt.Key_I || event.nativeScanCode === 23 || event.key === 1064 || event.key === 1096 || event.text === 'i' || event.text === 'I' || event.text === 'ш' || event.text === 'Ш')
}

function isCenteredModeKey(event) {
    // W (scan 17, 'ц')
    var isW = (event.key === Qt.Key_W || event.nativeScanCode === 17 || event.key === 1062 || event.key === 1094 || event.text === 'w' || event.text === 'W' || event.text === 'ц' || event.text === 'Ц')
    if ((event.modifiers & Qt.AltModifier) && isW) return true
    if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier) && isW) return true
    return false
}

function isToggleHeaderFooterKey(event) {
    if (event.key === Qt.Key_F9 || event.nativeScanCode === 67) return true
    // H (scan 35, 'р')
    var isH = (event.key === Qt.Key_H || event.nativeScanCode === 35 || event.key === 1056 || event.key === 1088 || event.text === 'h' || event.text === 'H' || event.text === 'р' || event.text === 'Р')
    if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier) && isH) return true
    if ((event.modifiers & Qt.AltModifier) && isH) return true
    return false
}

function isToggleFooterKey(event) {
    // F (scan 33, 'а')
    var isF = (event.key === Qt.Key_F || event.nativeScanCode === 33 || event.key === 1040 || event.key === 1072 || event.text === 'f' || event.text === 'F' || event.text === 'а' || event.text === 'А')
    if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier) && isF) return true
    if ((event.modifiers & Qt.AltModifier) && isF) return true
    return false
}

function isToggleHeaderKey(event) {
    // U (scan 22, 'г')
    var isU = (event.key === Qt.Key_U || event.nativeScanCode === 22 || event.key === 1043 || event.key === 1075 || event.text === 'u' || event.text === 'U' || event.text === 'г' || event.text === 'Г')
    if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier) && isU) return true
    if ((event.modifiers & Qt.AltModifier) && isU) return true
    return false
}

// Перехват шорткатов на уровне ShortcutOverride сообщает Qt, что активный редактор забирает комбинацию себе
function handleShortcutOverride(event, canvasRoot, editorArea, Markdown) {
    if (isCloseKey(event) ||
        isToggleHeaderFooterKey(event) ||
        isToggleFooterKey(event) ||
        isToggleHeaderKey(event) ||
        isCenteredModeKey(event) ||
        isSaveKey(event) ||
        isNewKey(event) ||
        isOpenKey(event) ||
        isToggleSplitKey(event) ||
        isDetachKey(event) ||
        isToggleGraphKey(event) ||
        isBoldKey(event) ||
        isItalicKey(event)) {
        event.accepted = true
        return true
    }

    // Системные клавиши редактирования (Ctrl+A, Ctrl+C, Ctrl+V, Ctrl+X, Ctrl+Z, Ctrl+Y)
    if (event.modifiers & Qt.ControlModifier) {
        var scan = event.nativeScanCode
        var k = event.key
        // A (30, Ф), C (46, С), V (47, М), X (45, Ч), Z (44, Я), Y (21, Н)
        if (scan === 30 || scan === 46 || scan === 47 || scan === 45 || scan === 44 || scan === 21 ||
            k === 1060 || k === 1092 || k === 1057 || k === 1089 || k === 1052 || k === 1084 ||
            k === 1063 || k === 1095 || k === 1071 || k === 1103 || k === 1053 || k === 1085) {
            event.accepted = true
            return true
        }
    }

    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
        event.accepted = true
        return true
    }

    return false
}

// Непосредственное выполнение действий при нажатии клавиши (Keys.onPressed)
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
    if (isOpenKey(event)) {
        event.accepted = true
        canvasRoot.openRequested()
        return true
    }
    if (isToggleSplitKey(event)) {
        event.accepted = true
        canvasRoot.toggleSplitRequested()
        return true
    }
    if (isDetachKey(event)) {
        event.accepted = true
        canvasRoot.detachRequested()
        return true
    }
    if (isToggleGraphKey(event)) {
        event.accepted = true
        canvasRoot.toggleGraphRequested()
        return true
    }

    // Поддержка системного редактирования для русской раскладки (Ctrl+A, Ctrl+C, Ctrl+V, Ctrl+X, Ctrl+Z, Ctrl+Y)
    if (event.modifiers & Qt.ControlModifier) {
        var scan = event.nativeScanCode
        var k = event.key
        // Ctrl+A (Ф)
        if (scan === 30 || k === 1060 || k === 1092) {
            event.accepted = true
            editorArea.selectAll()
            return true
        }
        // Ctrl+C (С)
        if (scan === 46 || k === 1057 || k === 1089) {
            event.accepted = true
            editorArea.copy()
            return true
        }
        // Ctrl+V (М)
        if (scan === 47 || k === 1052 || k === 1084) {
            event.accepted = true
            editorArea.paste()
            return true
        }
        // Ctrl+X (Ч)
        if (scan === 45 || k === 1063 || k === 1095) {
            event.accepted = true
            editorArea.cut()
            return true
        }
        // Ctrl+Z (Я)
        if (scan === 44 || k === 1071 || k === 1103) {
            event.accepted = true
            if (event.modifiers & Qt.ShiftModifier) {
                editorArea.redo()
            } else {
                editorArea.undo()
            }
            return true
        }
        // Ctrl+Y (Н)
        if (scan === 21 || k === 1053 || k === 1085) {
            event.accepted = true
            editorArea.redo()
            return true
        }
    }

    // Автозакрытие парных скобок и кавычек
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

    // Форматирование Markdown
    if (isBoldKey(event)) {
        event.accepted = true
        Markdown.toggleBold(editorArea)
        return true
    }
    if (isItalicKey(event)) {
        event.accepted = true
        Markdown.toggleItalic(editorArea)
        return true
    }

    return false
}
