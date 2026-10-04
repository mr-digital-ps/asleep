import QtQuick
import QtQml
import "./hotkey_matcher.js" as HotkeyMatcher

Item {
    id: hotkeyRoot

    property var hotkeyMapping: ({})
    property var flatHotkeysList: []

    signal actionTriggered(string action)
    signal closeActiveTabRequested()

    function reloadHotkeys() {
        if (typeof backend !== "undefined" && backend) {
            if (typeof backend.get_hotkeys === "function") {
                hotkeyRoot.hotkeyMapping = backend.get_hotkeys()
            }
            if (typeof backend.get_flat_shortcuts === "function") {
                hotkeyRoot.flatHotkeysList = backend.get_flat_shortcuts()
            }
        }
    }

    Component.onCompleted: {
        reloadHotkeys()
    }

    Connections {
        target: (typeof backend !== "undefined") ? backend : null
        function onHotkeysChanged() {
            hotkeyRoot.reloadHotkeys()
        }
    }

    function handleKeyEvent(event) {
        // 1. Декларативный поиск совпадения по конфигу hotkeys.json
        var matchedAction = HotkeyMatcher.matchAction(event, hotkeyRoot.flatHotkeysList)
        if (matchedAction) {
            if (matchedAction === "close_tab") {
                hotkeyRoot.closeActiveTabRequested()
            } else {
                hotkeyRoot.actionTriggered(matchedAction)
            }
            event.accepted = true
            return true
        }

        return false
    }
}
