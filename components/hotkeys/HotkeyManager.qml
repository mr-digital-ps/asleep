import QtQuick
import QtQml

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



    function isCloseKey(event) {
        if (!(event.modifiers & Qt.ControlModifier)) return false
        // W key: Key_W, scan code 17, or Cyrillic 'ц'
        if (event.key === Qt.Key_W || event.nativeScanCode === 17 || event.text === 'w' || event.text === 'W' || event.text === 'ц' || event.text === 'Ц' || event.key === 1062 || event.key === 1030) return true
        // Q key: Key_Q, scan code 16, or Cyrillic 'й'
        if (event.key === Qt.Key_Q || event.nativeScanCode === 16 || event.text === 'q' || event.text === 'Q' || event.text === 'й' || event.text === 'Й' || event.key === 1081 || event.key === 1049) return true
        return false
    }

    function handleKeyEvent(event) {
        if (isCloseKey(event)) {
            hotkeyRoot.closeActiveTabRequested()
            event.accepted = true
            return true
        }
        if (event.modifiers & Qt.ControlModifier) {
            // G key: Key_G (34, 'g', 'п'), or Russian letter 'Г' (Key_U / 22, 'г')
            var isG = (event.key === Qt.Key_G || event.nativeScanCode === 34 || event.text === 'g' || event.text === 'G' || event.text === 'п' || event.text === 'П' || event.key === 1087 || event.key === 1055)
            var isRuGe = (event.key === Qt.Key_U || event.nativeScanCode === 22 || event.text === 'г' || event.text === 'Г' || event.key === 1075 || event.key === 1043)
            if (isG || isRuGe) {
                hotkeyRoot.actionTriggered("toggle_graph")
                event.accepted = true
                return true
            }
        }
        if (event.key === Qt.Key_F9) {
            hotkeyRoot.actionTriggered("toggle_header_footer")
            event.accepted = true
            return true
        }
        return false
    }
}
