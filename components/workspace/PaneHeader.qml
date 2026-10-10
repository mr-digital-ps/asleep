import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme"
import "../history"

Item {
    id: headerRoot
    height: Theme.headerHeight

    property string fileName: ""
    property string fileUrl: ""
    property string folderUrl: ""
    property string breadcrumbTitle: ""
    property bool isSplitMode: false
    property bool isActivePane: false
    property bool isEmpty: false
    property bool isPinned: false
    property bool isGraphMode: false
    property bool isLocalGraphMode: false
    property int barSize: 36
    property real scrollY: 0
    property real contentLeftPadding: 0
    property real contentRightPadding: 0
    property string statsText: ""

    // Режим работы хедера: "title" (по умолчанию, полное имя Папка.Файл[.Блок]) | "history" (Git Graph таймлайн) | "info" (статистика) | "search" | "tabs"
    property string headerMode: "title"

    property alias titleField: titleField

    signal titleCommitted(string newTitle)
    signal paneActivated()
    signal pinToggled()
    signal openStructureRequested()
    signal snapshotSelected(int snapshotId)
    signal liveRequested()

    // Стек истории режимов хедера (LIFO)
    property var modeStack: []

    function switchMode(targetMode) {
        if (headerMode === targetMode) {
            // Если нажат хоткей своего же режима:
            // Достаём из стека последний открытый предыдущий режим (отличный от текущего)
            let prev = "title"
            while (modeStack.length > 0) {
                let candidate = modeStack.pop()
                if (candidate && candidate !== targetMode) {
                    prev = candidate
                    break
                }
            }
            headerMode = prev
        } else {
            // Переход в другой режим: сохраняем текущий в стек
            if (headerMode) {
                modeStack.push(headerMode)
            }
            headerMode = targetMode
        }

        if (headerMode === "history" && headerHistoryBar) {
            headerHistoryBar.reloadTimeline()
        }
    }

    function toggleHistoryMode() {
        switchMode("history")
    }

    function toggleInfoMode() {
        switchMode("info")
    }

    function toggleSearchMode() {
        switchMode("search")
    }

    function togglePathMode() {
        switchMode("title")
    }

    function showPathMode() {
        if (headerMode !== "title") {
            switchMode("title")
        }
    }

    function showFileNameMode() {
        if (headerMode !== "title") {
            switchMode("title")
        }
    }

    function toggleTabsMode() {
        switchMode("tabs")
    }

    function stripExt(name) {
        if (!name) return ""
        return name.replace(/\.(txt|md|markdown)$/i, "")
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

        // =====================================================================
        // Единый контентный ряд: заменяет заголовок на Timeline, Info, Path и т.д.
        // =====================================================================
        RowLayout {
            id: mainHeaderRow
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.leftMargin: headerRoot.barSize
            Layout.rightMargin: headerRoot.barSize
            Layout.preferredHeight: 44
            Layout.maximumHeight: 44
            Layout.minimumHeight: 44
            spacing: 8

            // 1. РЕЖИМ HISTORY: заменяет название файла таймлайном
            HistoryTimelineBar {
                id: headerHistoryBar
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: headerRoot.headerMode === "history"
                folderUrl: headerRoot.folderUrl
                fileUrl: headerRoot.fileUrl
                fileName: headerRoot.fileName
                mode: headerRoot.isGraphMode ? "project" : "note"
                statsText: headerRoot.statsText

                onActivated: headerRoot.paneActivated()
                onSnapshotSelected: (snapshotId) => headerRoot.snapshotSelected(snapshotId)
                onLiveRequested: headerRoot.liveRequested()
            }

            // 2. РЕЖИМ INFO: заменяет название файла статистикой
            RowLayout {
                id: headerInfoBar
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: headerRoot.headerMode === "info"
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: headerRoot.statsText
                    font.pixelSize: 13
                    color: Theme.textSecondary
                    elide: Text.ElideRight
                }
            }

            // 3. РЕЖИМ TITLE (по умолчанию)
            // Текстовый заголовок документа (редактируемый)
            TextField {
                id: titleField
                visible: headerRoot.headerMode === "title"
                objectName: "titleField"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                horizontalAlignment: Text.AlignLeft
                leftPadding: headerRoot.contentLeftPadding
                rightPadding: headerRoot.contentRightPadding
                topPadding: 6
                bottomPadding: 6
                text: headerRoot.breadcrumbTitle ? headerRoot.breadcrumbTitle : headerRoot.stripExt(headerRoot.fileName)
                font.pixelSize: Theme.headerTitleFontSize
                font.bold: true
                color: (headerRoot.isSplitMode && !headerRoot.isActivePane) ? Theme.textSecondary : Theme.textPrimary
                placeholderText: "Без названия"
                placeholderTextColor: Theme.textMuted
                selectByMouse: true
                selectionColor: Theme.selectionColor
                selectedTextColor: Theme.textSelected
                activeFocusOnTab: false
                background: null

                Connections {
                    target: headerRoot
                    function onBreadcrumbTitleChanged() {
                        if (!titleField.activeFocus) {
                            titleField.text = headerRoot.breadcrumbTitle ? headerRoot.breadcrumbTitle : headerRoot.stripExt(headerRoot.fileName)
                        }
                    }
                    function onFileNameChanged() {
                        if (!titleField.activeFocus) {
                            titleField.text = headerRoot.breadcrumbTitle ? headerRoot.breadcrumbTitle : headerRoot.stripExt(headerRoot.fileName)
                        }
                    }
                }

                property string originalText: ""
                property bool isUserEdited: false

                Timer {
                    id: titleDebounceTimer
                    interval: 800
                    repeat: false
                    onTriggered: titleField.commitTitle()
                }

                onTextEdited: {
                    titleField.isUserEdited = true
                    titleDebounceTimer.restart()
                }

                function commitTitle() {
                    titleDebounceTimer.stop()
                    if (!titleField.isUserEdited) return
                    titleField.isUserEdited = false
                    // Если пользователь редактирует имя в строке хлебных крошек, извлекаем имя файла
                    let raw = text.trim()
                    let parts = raw.split(".").filter(function(p) { return p.length > 0 })
                    let clean = parts.length > 0 ? headerRoot.stripExt(parts[parts.length - 1]) : "Новый документ"
                    if (!clean) clean = "Новый документ"
                    if (clean !== headerRoot.stripExt(headerRoot.fileName)) {
                        headerRoot.titleCommitted(clean)
                    }
                }

                onActiveFocusChanged: {
                    if (activeFocus) {
                        isUserEdited = false
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

        // =====================================================================
        // Разделительная нижняя линия (клик = закрепить/открепить)
        // =====================================================================
        Item {
            id: headerDividerArea
            Layout.fillWidth: true
            Layout.preferredHeight: 14
            Layout.maximumHeight: 14
            Layout.leftMargin: headerRoot.barSize
            Layout.rightMargin: headerRoot.barSize

            Rectangle {
                id: headerDividerLine
                anchors.centerIn: parent
                width: parent.width
                height: 2
                radius: 1
                color: headerRoot.isPinned
                    ? (headerDividerMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary)
                    : (headerDividerMouse.containsMouse ? Theme.borderFocus : Theme.borderColor)
                opacity: headerRoot.isPinned ? 0.9 : 0.6
                Behavior on color { ColorAnimation { duration: Theme.animDurationNormal } }
                Behavior on opacity { NumberAnimation { duration: Theme.animDurationNormal } }
            }

            MouseArea {
                id: headerDividerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    headerRoot.pinToggled()
                }
            }
        }
    }
}
