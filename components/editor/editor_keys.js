// js/editor/editor_keys.js — Локальная обработка текста и разметки в редакторе

function isSaveKey(event) {
    if (!(event.modifiers & Qt.ControlModifier)) return false
    // S (scan 31, 'ы')
    return (event.key === Qt.Key_S || event.nativeScanCode === 31 || event.key === 1067 || event.key === 1099 || event.text === 's' || event.text === 'S' || event.text === 'ы' || event.text === 'Ы')
}

function isNewPanelKey(event) {
    if (!(event.modifiers & Qt.ControlModifier)) return false
    if (!(event.modifiers & Qt.ShiftModifier)) return false
    // N (scan 49, 'т')
    return (event.key === Qt.Key_N || event.nativeScanCode === 49 || event.key === 1058 || event.key === 1090 || event.text === 'n' || event.text === 'N' || event.text === 'т' || event.text === 'Т')
}

function isOpenPanelKey(event) {
    if (!(event.modifiers & Qt.ControlModifier)) return false
    if (!(event.modifiers & Qt.ShiftModifier)) return false
    // O (scan 24, 'щ')
    return (event.key === Qt.Key_O || event.nativeScanCode === 24 || event.key === 1065 || event.key === 1097 || event.text === 'o' || event.text === 'O' || event.text === 'щ' || event.text === 'Щ')
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

function isToggleLiveModeKey(event) {
    if (!(event.modifiers & Qt.AltModifier)) return false
    // Alt + E (scan 18, 'у')
    return (event.key === Qt.Key_E || event.nativeScanCode === 18 || event.key === 1059 || event.key === 1091 || event.text === 'e' || event.text === 'E' || event.text === 'у' || event.text === 'У')
}

function isToggleSourceModeKey(event) {
    if (!(event.modifiers & Qt.AltModifier)) return false
    // Alt + S (scan 31, 'ы')
    return (event.key === Qt.Key_S || event.nativeScanCode === 31 || event.key === 1067 || event.key === 1099 || event.text === 's' || event.text === 'S' || event.text === 'ы' || event.text === 'Ы')
}

// Перехват шорткатов на уровне ShortcutOverride сообщает Qt, что активный редактор забирает комбинацию себе (только текст и форматирование)
function handleShortcutOverride(event, canvasRoot, editorArea, Shortcuts) {
    if (isBoldKey(event) || isItalicKey(event)) {
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
function handleKeyPressed(event, canvasRoot, editorArea, Shortcuts) {
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
    if (isSaveKey(event)) {
        event.accepted = true
        canvasRoot.saveRequested()
        return true
    }
    if (isNewPanelKey(event)) {
        event.accepted = true
        canvasRoot.newRequested()
        return true
    }
    if (isOpenPanelKey(event)) {
        event.accepted = true
        canvasRoot.openRequested()
        return true
    }
    // Автозакрытие парных скобок и кавычек
    if (event.key === Qt.Key_ParenRight && Shortcuts.handleAutoPair(editorArea, ")")) {
        event.accepted = true
        return true
    }
    if (event.key === Qt.Key_BracketRight && Shortcuts.handleAutoPair(editorArea, "]")) {
        event.accepted = true
        return true
    }
    if (event.key === Qt.Key_BraceRight && Shortcuts.handleAutoPair(editorArea, "}")) {
        event.accepted = true
        return true
    }
    if ((event.key === Qt.Key_QuoteDbl || event.key === 1069) && Shortcuts.handleAutoPair(editorArea, "\"")) {
        event.accepted = true
        return true
    }
    if ((event.text === "`" || event.key === 1025 || event.key === 1105) && Shortcuts.handleAutoPair(editorArea, "`")) {
        event.accepted = true
        return true
    }
    if (event.key === Qt.Key_ParenLeft && Shortcuts.handleAutoPair(editorArea, "(")) {
        event.accepted = true
        return true
    }
    if (event.key === Qt.Key_BracketLeft && Shortcuts.handleAutoPair(editorArea, "[")) {
        event.accepted = true
        return true
    }
    if (event.key === Qt.Key_BraceLeft && Shortcuts.handleAutoPair(editorArea, "{")) {
        event.accepted = true
        return true
    }

    // Форматирование текста
    if (isBoldKey(event)) {
        event.accepted = true
        Shortcuts.toggleBold(editorArea)
        return true
    }
    if (isItalicKey(event)) {
        event.accepted = true
        Shortcuts.toggleItalic(editorArea)
        return true
    }

    // Переключение режимов Live Mode ⟷ Source Mode (Alt + E / Alt + S)
    if (isToggleLiveModeKey(event) || isToggleSourceModeKey(event)) {
        event.accepted = true
        if (canvasRoot && typeof canvasRoot.toggleLiveModeRequested === "function") {
            canvasRoot.toggleLiveModeRequested()
        }
        return true
    }

    return false
}
