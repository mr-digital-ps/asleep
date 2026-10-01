import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme"

Item {
    id: headerRoot
    height: 70
    z: 20

    property string fileName: ""
    property string fileUrl: ""
    property bool isSplitMode: false
    property bool isActivePane: false
    property bool isEmpty: false
    property bool isPinned: false
    property bool isGraphMode: false
    property bool isLocalGraphMode: false
    property bool isOutlineMode: false
    property int barSize: 36
    property real scrollY: 0
    property real contentLeftPadding: 0
    property real contentRightPadding: 0

    property alias titleField: titleField

    signal titleCommitted(string newTitle)
    signal paneActivated()
    signal pinToggled()
    signal toggleOutlineRequested()
    signal openStructureRequested()

    function stripExt(name) {
        if (!name) return ""
        return name.replace(/\.md$/i, "")
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bgHeader
        visible: headerRoot.isPinned
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.ArrowCursor
        onPressed: (mouse) => {
            headerRoot.paneActivated()
            let win = Window.window
            if (win && typeof win.startSystemMove === "function") {
                win.startSystemMove()
            }
        }
        onDoubleClicked: {
            let win = Window.window
            if (win) {
                if (win.visibility === Window.Maximized) {
                    win.showNormal()
                } else {
                    win.showMaximized()
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Режим 1: Обычный документ (редактор или аутлайнер)
        RowLayout {
            id: docHeaderRow
            visible: !headerRoot.isGraphMode
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.topMargin: 12
            Layout.leftMargin: headerRoot.barSize
            Layout.rightMargin: headerRoot.barSize
            Layout.preferredHeight: 44
            Layout.maximumHeight: 44
            Layout.minimumHeight: 44
            spacing: 0

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
                        if (scan === 30 || k === 1060 || k === 1092) {
                            event.accepted = true
                            titleField.selectAll()
                            return
                        }
                        if (scan === 46 || k === 1057 || k === 1089) {
                            event.accepted = true
                            titleField.copy()
                            return
                        }
                        if (scan === 47 || k === 1052 || k === 1084) {
                            event.accepted = true
                            titleField.paste()
                            return
                        }
                        if (scan === 45 || k === 1063 || k === 1095) {
                            event.accepted = true
                            titleField.cut()
                            return
                        }
                        if ((event.modifiers & Qt.ShiftModifier && (scan === 44 || k === 1071 || k === 1103)) ||
                            scan === 21 || k === 1053 || k === 1085) {
                            event.accepted = true
                            if (titleField.canRedo) titleField.redo()
                            return
                        }
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

        // Режим 2: Строка заголовка в режиме графа
        RowLayout {
            id: graphHeaderRow
            visible: headerRoot.isGraphMode
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.topMargin: 12
            Layout.leftMargin: headerRoot.barSize
            Layout.rightMargin: headerRoot.barSize
            Layout.preferredHeight: 44
            Layout.maximumHeight: 44
            Layout.minimumHeight: 44
            spacing: 8

            Text {
                text: (headerRoot.isLocalGraphMode ? "🕸 Локальный граф: " : "🕸 ") + (headerRoot.fileName ? headerRoot.stripExt(headerRoot.fileName) : "Граф связей")
                font.pixelSize: 17
                font.bold: true
                color: Theme.textPrimary
                elide: Text.ElideRight
                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                visible: headerRoot.isLocalGraphMode
                Layout.preferredHeight: 20
                Layout.preferredWidth: localBadgeText.implicitWidth + 12
                Layout.alignment: Qt.AlignVCenter
                radius: 4
                color: Theme.bgApp
                border.color: Theme.borderColor
                border.width: 1

                Text {
                    id: localBadgeText
                    anchors.centerIn: parent
                    text: "Локальный (1-hop)"
                    font.pixelSize: 10
                    color: Theme.textSecondary
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }

        // Верхняя разделительная линия (клик = закрепить/открепить)
        Item {
            id: headerDividerArea
            Layout.fillWidth: true
            Layout.preferredHeight: 14
            Layout.maximumHeight: 14
            Layout.leftMargin: 36
            Layout.rightMargin: 36

            Rectangle {
                id: headerDividerLine
                anchors.centerIn: parent
                width: parent.width
                height: 2
                radius: 1
                color: (headerRoot.isPinned || headerRoot.isGraphMode)
                    ? (headerDividerMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary)
                    : (headerDividerMouse.containsMouse ? Theme.borderFocus : Theme.borderColor)
                opacity: (headerRoot.isPinned || headerRoot.isGraphMode) ? 0.9 : 0.6
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            MouseArea {
                id: headerDividerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: headerRoot.isGraphMode ? Qt.ArrowCursor : Qt.PointingHandCursor
                onClicked: {
                    if (!headerRoot.isGraphMode) {
                        headerRoot.pinToggled()
                    }
                }
            }
        }
    }
}
