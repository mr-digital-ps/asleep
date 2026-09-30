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
        return false
    }

    function isKeyG(event) {
        // G (scan 34, Russian 'п')
        return event.key === Qt.Key_G || event.nativeScanCode === 34 || event.text === 'g' || event.text === 'G' || event.text === 'п' || event.text === 'П' || event.key === 1087 || event.key === 1055
    }

    function isKeyU(event) {
        // U (scan 22, Russian 'г')
        return event.key === Qt.Key_U || event.nativeScanCode === 22 || event.text === 'u' || event.text === 'U' || event.text === 'г' || event.text === 'Г' || event.key === 1075 || event.key === 1043
    }

    function isKeyP(event) {
        return event.key === Qt.Key_P || event.nativeScanCode === 25 || event.text === 'p' || event.text === 'P' || event.text === 'з' || event.text === 'З' || event.key === 1079 || event.key === 1047
    }

    function isKeyE(event) {
        return event.key === Qt.Key_E || event.nativeScanCode === 18 || event.text === 'e' || event.text === 'E' || event.text === 'у' || event.text === 'У' || event.key === 1091 || event.key === 1059
    }

    function handleKeyEvent(event) {
        if (isCloseKey(event)) {
            hotkeyRoot.closeActiveTabRequested()
            event.accepted = true
            return true
        }

        // Локальные: Alt + G (Локальный граф), Alt + P (Локальная иерархия / Outliner)
        if (event.modifiers & Qt.AltModifier) {
            if (isKeyG(event)) {
                hotkeyRoot.actionTriggered("toggle_local_graph")
                event.accepted = true
                return true
            }
            if (isKeyP(event)) {
                hotkeyRoot.actionTriggered("toggle_outline")
                event.accepted = true
                return true
            }
            if (isKeyU(event)) {
                hotkeyRoot.actionTriggered("toggle_header")
                event.accepted = true
                return true
            }
        }

        // Глобальные: Ctrl + G (Глобальный граф), Ctrl + P (Глобальная структура)
        if (event.modifiers & Qt.ControlModifier) {
            if (isKeyG(event)) {
                hotkeyRoot.actionTriggered("toggle_graph")
                event.accepted = true
                return true
            }
            if (isKeyP(event)) {
                hotkeyRoot.actionTriggered("open_structure")
                event.accepted = true
                return true
            }
            if (isKeyE(event)) {
                hotkeyRoot.actionTriggered("toggle_outline")
                event.accepted = true
                return true
            }

            // D key: Key_D (32, 'd', 'в'), or Russian letter 'Д' (Key_L / 38, 'д')
            var isD = (event.key === Qt.Key_D || event.nativeScanCode === 32 || event.text === 'd' || event.text === 'D' || event.text === 'в' || event.text === 'В' || event.key === 1074 || event.key === 1042)
            var isRuDe = (event.key === Qt.Key_L || event.nativeScanCode === 38 || event.text === 'д' || event.text === 'Д' || event.key === 1076 || event.key === 1044)
            if (isD || isRuDe) {
                hotkeyRoot.actionTriggered("detach_window")
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
