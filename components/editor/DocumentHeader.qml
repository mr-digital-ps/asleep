import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

RowLayout {
    id: headerRoot
    Layout.fillWidth: true
    Layout.fillHeight: false
    property int barSize: 36
    Layout.topMargin: 12
    Layout.leftMargin: headerRoot.barSize
    Layout.rightMargin: headerRoot.barSize
    Layout.preferredHeight: 44
    Layout.maximumHeight: 44
    Layout.minimumHeight: 44
    spacing: 0

    property string fileName: "Новый документ"
    property string fileUrl: ""
    property bool isSplitMode: false
    property bool isActivePane: false
    property bool isEmpty: false

    property real contentLeftPadding: 0
    property real contentRightPadding: 0

    property alias titleField: titleField

    signal titleCommitted(string newTitle)
    signal paneActivated()

    function stripExt(name) {
        if (!name) return ""
        return name.replace(/\.md$/i, "")
    }

    TextField {
        id: titleField
        objectName: "titleField"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignVCenter
        horizontalAlignment: Text.AlignLeft
        leftPadding: headerRoot.contentLeftPadding
        rightPadding: headerRoot.contentRightPadding
        topPadding: 6
        bottomPadding: 6
        text: headerRoot.stripExt(headerRoot.fileName)
        font.pixelSize: 18
        font.bold: true
        color: (headerRoot.isSplitMode && !headerRoot.isActivePane) ? Theme.textSecondary : Theme.textPrimary
        placeholderText: "Без названия"
        placeholderTextColor: Theme.textMuted
        selectByMouse: true
        selectionColor: Theme.selectionColor
        selectedTextColor: Theme.textSelected
        activeFocusOnTab: false
        background: null

        property string originalText: ""

        Timer {
            id: titleDebounceTimer
            interval: 800
            repeat: false
            onTriggered: titleField.commitTitle()
        }

        onTextEdited: {
            titleDebounceTimer.restart()
        }

        Binding {
            target: titleField
            property: "text"
            value: headerRoot.stripExt(headerRoot.fileName)
            when: !titleField.activeFocus
        }

        function commitTitle() {
            titleDebounceTimer.stop()
            let clean = headerRoot.stripExt(text.trim())
            if (!clean) {
                clean = "Новый документ"
                text = clean
            }
            if (clean !== headerRoot.stripExt(headerRoot.fileName)) {
                headerRoot.titleCommitted(clean)
            }
        }

        onActiveFocusChanged: {
            if (activeFocus) {
                originalText = text
                headerRoot.paneActivated()
                if (text === "Новый документ") {
                    titleField.selectAll()
                }
            } else {
                commitTitle()
            }
        }

        Keys.onReturnPressed: (event) => {
            titleDebounceTimer.stop()
            commitTitle()
            focus = false
            event.accepted = true
        }

        Keys.onEnterPressed: (event) => {
            titleDebounceTimer.stop()
            commitTitle()
            focus = false
            event.accepted = true
        }

        Keys.onShortcutOverride: (event) => {
            if (event.modifiers & Qt.ControlModifier) {
                var scan = event.nativeScanCode
                var k = event.key
                // A (30), C (46), V (47), X (45), Z (44), Y (21)
                if (scan === 30 || scan === 46 || scan === 47 || scan === 45 || scan === 44 || scan === 21 ||
                    k === 1060 || k === 1092 || k === 1057 || k === 1089 || k === 1052 || k === 1084 ||
                    k === 1063 || k === 1095 || k === 1071 || k === 1103 || k === 1053 || k === 1085) {
                    event.accepted = true
                }
            }
        }

        Keys.onPressed: (event) => {
            if (event.modifiers & Qt.ControlModifier) {
                var scan = event.nativeScanCode
                var k = event.key
                // Ctrl+A (Ф)
                if (scan === 30 || k === 1060 || k === 1092) {
                    event.accepted = true
                    titleField.selectAll()
                    return
                }
                // Ctrl+C (С)
                if (scan === 46 || k === 1057 || k === 1089) {
                    event.accepted = true
                    titleField.copy()
                    return
                }
                // Ctrl+V (М)
                if (scan === 47 || k === 1052 || k === 1084) {
                    event.accepted = true
                    titleField.paste()
                    return
                }
                // Ctrl+X (Ч)
                if (scan === 45 || k === 1063 || k === 1095) {
                    event.accepted = true
                    titleField.cut()
                    return
                }
                // Ctrl+Shift+Z or Ctrl+Y (Н) - Redo
                if ((event.modifiers & Qt.ShiftModifier && (scan === 44 || k === 1071 || k === 1103)) ||
                    scan === 21 || k === 1053 || k === 1085) {
                    event.accepted = true
                    if (titleField.canRedo) titleField.redo()
                    return
                }
                // Ctrl+Z (Я) - Undo
                if (scan === 44 || k === 1071 || k === 1103) {
                    event.accepted = true
                    if (titleField.canUndo) titleField.undo()
                    return
                }
            }
        }

        Keys.onEscapePressed: {
            titleDebounceTimer.stop()
            text = originalText
            focus = false
        }
    }
}
