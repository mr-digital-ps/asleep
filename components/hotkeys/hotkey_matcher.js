// components/hotkeys/hotkey_matcher.js — Сопоставление горячих клавиш с действиями
.pragma library

function matchAction(event, flatHotkeysList) {
    if (!flatHotkeysList || !flatHotkeysList.length) return null
    for (var i = 0; i < flatHotkeysList.length; i++) {
        var item = flatHotkeysList[i]
        if (!item || !item.action) continue
        var matches = false
        if (typeof item.scanCode === "number" && item.scanCode > 0 && typeof event.nativeScanCode === "number") {
            if (event.nativeScanCode === item.scanCode && (event.modifiers === item.modifiers || ((event.modifiers & item.modifiers) === item.modifiers))) {
                matches = true
            }
        }
        if (!matches && typeof item.key === "number" && item.key > 0) {
            if (event.key === item.key && (event.modifiers === item.modifiers || ((event.modifiers & item.modifiers) === item.modifiers))) {
                matches = true
            }
        }
        if (matches) return item.action
    }
    return null
}
