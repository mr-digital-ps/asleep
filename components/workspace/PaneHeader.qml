import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme"
import "../history"

Item {
    id: headerRoot
    height: effectiveHeight
    z: 20

    property string fileName: ""
    property string fileUrl: ""
    property string folderUrl: ""
    property bool isProjectTree: false
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
    property string statsText: ""

    // Режим работы хедера: "title" (по умолчанию, компактный) | "history" (Git Graph таймлайн) | "info" (статистика) | "search" | "path" | "tabs"
    property string headerMode: "title"
    property bool showPath: false

    // Безопасные размеры с дефолтными значениями, если Theme еще не инициализирован
    readonly property int compactHeight: (typeof Theme !== "undefined" && Theme && Theme.headerCompactHeight) ? Theme.headerCompactHeight : 40
    readonly property int expandedHeight: (typeof Theme !== "undefined" && Theme && Theme.headerExpandedHeight) ? Theme.headerExpandedHeight : 76
    readonly property int targetHeight: (headerMode === "title") ? compactHeight : expandedHeight
    property int effectiveHeight: targetHeight

    Behavior on effectiveHeight {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    property alias titleField: titleField

    signal titleCommitted(string newTitle)
    signal paneActivated()
    signal pinToggled()
    signal toggleOutlineRequested()
    signal openStructureRequested()
    signal snapshotSelected(int snapshotId)
    signal liveRequested()

    function setMode(mode) {
        if (headerMode === mode) {
            headerMode = "title"
        } else {
            headerMode = mode
        }
    }

    function toggleHistoryMode() {
        setMode("history")
    }

    function toggleInfoMode() {
        setMode("info")
    }

    function toggleSearchMode() {
        setMode("search")
    }

    function togglePathMode() {
        showPath = !showPath
    }

    function toggleTabsMode() {
        setMode("tabs")
    }

    function stripExt(name) {
        if (!name) return ""
        return name.replace(/\.md$/i, "")
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bgHeader
        visible: true
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

        // =====================================================================
        // 1. Верхний ряд: заголовок документа или графа
        // =====================================================================
        RowLayout {
            id: mainHeaderRow
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            Layout.minimumHeight: 38
            Layout.maximumHeight: 38
            Layout.leftMargin: headerRoot.barSize
            Layout.rightMargin: headerRoot.barSize
            spacing: 8

            // 1.1 Текстовый заголовок документа
            TextField {
                id: titleField
                visible: !headerRoot.isGraphMode
                objectName: "titleField"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                horizontalAlignment: Text.AlignLeft
                leftPadding: headerRoot.contentLeftPadding
                rightPadding: headerRoot.contentRightPadding
                topPadding: 4
                bottomPadding: 4
                text: headerRoot.stripExt(headerRoot.fileName)
                font.pixelSize: 17
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

            // 1.2 Заголовок графа связей
            RowLayout {
                id: graphTitleArea
                visible: headerRoot.isGraphMode
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                Text {
                    text: (headerRoot.isLocalGraphMode ? "🕸 Локальный граф: " : "🕸 ") + (headerRoot.fileName ? headerRoot.stripExt(headerRoot.fileName) : "Граф связей")
                    font.pixelSize: 16
                    font.bold: true
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                    Layout.alignment: Qt.AlignVCenter
                }

                Rectangle {
                    visible: headerRoot.isLocalGraphMode
                    Layout.preferredHeight: 18
                    Layout.preferredWidth: localBadgeText.implicitWidth + 10
                    Layout.alignment: Qt.AlignVCenter
                    radius: 3
                    color: Theme.bgApp
                    border.color: Theme.borderColor
                    border.width: 1

                    Text {
                        id: localBadgeText
                        anchors.centerIn: parent
                        text: "1-hop"
                        font.pixelSize: 10
                        color: Theme.textSecondary
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // Путь к файлу при включенном режиме showPath
            Text {
                visible: !headerRoot.isGraphMode && headerRoot.showPath && headerRoot.fileUrl !== ""
                Layout.alignment: Qt.AlignVCenter
                text: headerRoot.fileUrl.replace(/^file:\/\/\/?/, "")
                font.pixelSize: 11
                color: Theme.textMuted
                elide: Text.ElideLeft
                Layout.maximumWidth: 280
            }
        }

        // =====================================================================
        // 2. Раскрывающийся контекстный контейнер (Drawer): History или Info
        // =====================================================================
        Item {
            id: headerDrawerArea
            Layout.fillWidth: true
            Layout.preferredHeight: (headerRoot.headerMode !== "title") ? 34 : 0
            Layout.maximumHeight: (headerRoot.headerMode !== "title") ? 34 : 0
            Layout.leftMargin: headerRoot.barSize
            Layout.rightMargin: headerRoot.barSize
            clip: true
            visible: headerRoot.headerMode !== "title"

            // Режим "history": Git Graph таймлайн ревизий
            HistoryTimelineBar {
                id: headerHistoryBar
                anchors.fill: parent
                visible: headerRoot.headerMode === "history"
                folderUrl: headerRoot.folderUrl
                fileUrl: headerRoot.fileUrl
                mode: (headerRoot.isGraphMode || headerRoot.isProjectTree) ? "project" : "note"
                statsText: headerRoot.statsText

                onActivated: headerRoot.paneActivated()
                onSnapshotSelected: (snapshotId) => headerRoot.snapshotSelected(snapshotId)
                onLiveRequested: headerRoot.liveRequested()
            }

            // Режим "info": Статистика документа/графа
            RowLayout {
                id: headerInfoBar
                anchors.fill: parent
                visible: headerRoot.headerMode === "info"
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: headerRoot.statsText
                    font.pixelSize: 12
                    color: Theme.textSecondary
                    elide: Text.ElideRight
                }
            }
        }

        // =====================================================================
        // 3. Разделительная нижняя линия (клик = закрепить/открепить)
        // =====================================================================
        Item {
            id: headerDividerArea
            Layout.fillWidth: true
            Layout.preferredHeight: 4
            Layout.maximumHeight: 4
            Layout.leftMargin: headerRoot.barSize
            Layout.rightMargin: headerRoot.barSize

            Rectangle {
                id: headerDividerLine
                anchors.centerIn: parent
                width: parent.width
                height: 1
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
