import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

RowLayout {
    id: headerRoot
    Layout.fillWidth: true
    Layout.fillHeight: false
    Layout.topMargin: 12
    Layout.leftMargin: 36
    Layout.rightMargin: 36
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

        Keys.onEscapePressed: {
            titleDebounceTimer.stop()
            text = originalText
            focus = false
        }
    }
}
