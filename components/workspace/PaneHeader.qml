import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme"

Item {
    id: headerRoot
    height: Theme.headerHeight

    property string fileName: ""
    property string fileUrl: ""
    property string folderUrl: ""
    property string breadcrumbTitle: ""
    property bool isActivePane: false
    property bool isEmpty: false
    property bool isPinned: false
    property bool isGraphMode: false
    property bool isLocalGraphMode: false
    property int barSize: Theme.barSize
    property real scrollY: 0
    property real contentLeftPadding: 0
    property real contentRightPadding: 0
    property string statsText: ""

    // Режим работы хедера: "title" (по умолчанию, полное имя Папка.Файл[.Блок]) | "history" (Git Graph таймлайн) | "info" (статистика)
    property string headerMode: "title"

    property alias titleField: titleField

    signal titleCommitted(string newTitle)
    signal paneActivated()
    signal pinToggled()
    signal openStructureRequested()
    signal snapshotSelected(int snapshotId)
    signal liveRequested()
    signal historySubModeChanged(string subMode)
    signal dragStarted(var mouse, var item)
    signal dragUpdated(var mouse, var item)
    signal dragFinished()

    // Стек истории режимов хедера (LIFO)
    property var modeStack: []

    function switchMode(targetMode) {
        var oldMode = headerMode
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

        if (oldMode === "history" && headerMode !== "history" && headerHistoryBar) {
            headerHistoryBar.goLive()
        }

        if (headerMode === "history" && headerHistoryBar) {
            headerHistoryBar.reloadTimeline()
        }
    }

    function toggleHistoryMode() {
        switchMode("history")
    }

    function toggleHistoryDiffMode() {
        if (headerRoot.isGraphMode) return
        if (headerMode !== "history") {
            if (headerHistoryBar) {
                headerHistoryBar.historySubMode = "diff"
            }
            switchMode("history")
            if (headerHistoryBar && !headerHistoryBar.isHistoricalMode && headerHistoryBar.daysList.length > 1) {
                headerHistoryBar.selectDay(headerHistoryBar.daysList.length - 2)
            }
        } else {
            if (headerHistoryBar) {
                headerHistoryBar.toggleDiffSubMode()
            }
        }
    }

    function toggleInfoMode() {
        switchMode("info")
    }

    property bool showOnlyFileName: false

    function effectiveTitle() {
        var rawName = stripExt(fileName) || fileName || "Новый документ"
        if (showOnlyFileName) {
            return rawName
        }
        return breadcrumbTitle ? breadcrumbTitle : rawName
    }

    function togglePathMode() {
        if (headerMode !== "title") {
            switchMode("title")
        } else {
            showOnlyFileName = !showOnlyFileName
            updateTitleFieldText()
        }
    }

    function showPathMode() {
        showOnlyFileName = false
        if (headerMode !== "title") {
            switchMode("title")
        } else {
            updateTitleFieldText()
        }
    }

    function showFileNameMode() {
        showOnlyFileName = true
        if (headerMode !== "title") {
            switchMode("title")
        } else {
            updateTitleFieldText()
        }
    }

    function updateTitleFieldText() {
        if (!titleField.activeFocus) {
            titleField.text = effectiveTitle()
        }
    }

    onShowOnlyFileNameChanged: updateTitleFieldText()

    function stripExt(name) {
        if (!name) return ""
        return name.replace(/\.txt$/i, "")
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bgHeader
        visible: headerRoot.isPinned
    }

    MouseArea {
        id: headerBgArea
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: (mouse) => {
            headerRoot.paneActivated()
            headerRoot.dragStarted(mouse, headerBgArea)
        }
        onPositionChanged: (mouse) => {
            if (pressed) {
                headerRoot.dragUpdated(mouse, headerBgArea)
            }
        }
        onReleased: headerRoot.dragFinished()
        onCanceled: headerRoot.dragFinished()
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
                onHistorySubModeChanged: headerRoot.historySubModeChanged(headerHistoryBar.historySubMode)
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
                    font.family: Theme.fontFamily
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
                readOnly: headerRoot.isGraphMode
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                horizontalAlignment: Text.AlignLeft
                leftPadding: headerRoot.contentLeftPadding
                rightPadding: headerRoot.contentRightPadding
                topPadding: 6
                bottomPadding: 6
                text: headerRoot.effectiveTitle()
                font.pixelSize: Theme.headerTitleFontSize
                font.bold: true
                color: (!headerRoot.isActivePane) ? Theme.textSecondary : Theme.textPrimary
                placeholderText: "Без названия"
                placeholderTextColor: Theme.textMuted
                selectByMouse: !headerRoot.isGraphMode
                selectionColor: Theme.selectionColor
                selectedTextColor: Theme.textSelected
                activeFocusOnTab: false
                background: null

                Connections {
                    target: headerRoot
                    function onBreadcrumbTitleChanged() {
                        headerRoot.updateTitleFieldText()
                    }
                    function onFileNameChanged() {
                        headerRoot.updateTitleFieldText()
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
                    // Если пользователь редактирует имя в строке хлебных крошек (Папка.Подпапка.Файл), извлекаем имя файла
                    let raw = text.trim()
                    let parts = raw.split(/[\.\/\\]/).filter(function(p) { return p.trim().length > 0 })
                    let clean = parts.length > 0 ? headerRoot.stripExt(parts[parts.length - 1].trim()) : "Новый документ"
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
                    ? (headerDividerMouse.containsMouse ? Theme.accentHover : Theme.accentColor)
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
