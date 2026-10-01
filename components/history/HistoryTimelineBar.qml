import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "./timeline_controller.js" as TimelineCtrl

RowLayout {
    id: historyBarRoot
    spacing: 12

    property string folderUrl: ""
    property string fileUrl: ""
    property string mode: "project" // "project" (для графа и структуры) или "note" (для отдельного файла)
    property string statsText: ""
    property var timelineList: []
    property int currentSnapshotIndex: -1
    property bool isPlaying: false
    property bool isHistoricalMode: false

    property var daysList: TimelineCtrl.getDaysList(timelineList)
    property int currentDayIndex: TimelineCtrl.getDayIndexForSnapshot(currentSnapshotIndex, daysList, timelineList)

    // Активный снапшот или текущее время (для Live режима)
    readonly property var activeDayObj: (currentDayIndex >= 0 && currentDayIndex < daysList.length) ? daysList[currentDayIndex] : null
    readonly property string displayTimeText: {
        if (isHistoricalMode && activeDayObj) {
            return activeDayObj.timeStr || "--:--:-- --"
        }
        if (daysList.length > 0) {
            return daysList[daysList.length - 1].timeStr || "--:--:-- --"
        }
        return "--:--:-- --"
    }
    readonly property string displayDateText: {
        if (isHistoricalMode && activeDayObj) {
            return activeDayObj.dateStr || "--/--/----"
        }
        if (daysList.length > 0) {
            return daysList[daysList.length - 1].dateStr || "--/--/----"
        }
        return "--/--/----"
    }

    signal activated()
    signal snapshotSelected(int snapshotId)
    signal liveRequested()

    function reloadTimeline() {
        if (typeof backend === "undefined" || !backend) return
        var list = []
        if (historyBarRoot.mode === "note" && historyBarRoot.fileUrl) {
            if (typeof backend.get_file_history_timeline === "function") {
                list = backend.get_file_history_timeline(historyBarRoot.fileUrl, historyBarRoot.folderUrl) || []
            }
        } else {
            if (typeof backend.get_history_timeline === "function") {
                list = backend.get_history_timeline(historyBarRoot.folderUrl) || []
            }
        }
        historyBarRoot.timelineList = list
        if (!historyBarRoot.isHistoricalMode && list.length > 0) {
            historyBarRoot.currentSnapshotIndex = list.length - 1
        }
    }

    function selectIndex(idx) {
        if (idx < 0 || idx >= historyBarRoot.timelineList.length) return
        historyBarRoot.currentSnapshotIndex = idx
        historyBarRoot.isHistoricalMode = true
        var item = historyBarRoot.timelineList[idx]
        if (item && typeof item.id === "number") {
            historyBarRoot.snapshotSelected(item.id)
        }
    }

    function selectDay(dayIdx) {
        var days = historyBarRoot.daysList
        if (dayIdx < 0 || dayIdx >= days.length) return
        var targetSnapIdx = days[dayIdx].snapshotIndex
        historyBarRoot.selectIndex(targetSnapIdx)
    }

    function goLive() {
        historyBarRoot.isPlaying = false
        historyBarRoot.isHistoricalMode = false
        if (historyBarRoot.timelineList.length > 0) {
            historyBarRoot.currentSnapshotIndex = historyBarRoot.timelineList.length - 1
        }
        historyBarRoot.liveRequested()
    }

    function stepPrev() {
        historyBarRoot.activated()
        if (historyBarRoot.currentDayIndex > 0) {
            historyBarRoot.selectDay(historyBarRoot.currentDayIndex - 1)
        }
    }

    function stepNext() {
        historyBarRoot.activated()
        if (historyBarRoot.currentDayIndex < historyBarRoot.daysList.length - 1) {
            historyBarRoot.selectDay(historyBarRoot.currentDayIndex + 1)
        } else {
            historyBarRoot.goLive()
        }
    }

    function togglePlay() {
        historyBarRoot.activated()
        if (historyBarRoot.isPlaying) {
            historyBarRoot.isPlaying = false
        } else {
            if (historyBarRoot.currentDayIndex >= historyBarRoot.daysList.length - 1) {
                historyBarRoot.selectDay(0)
            }
            historyBarRoot.isPlaying = true
        }
    }

    onFolderUrlChanged: reloadTimeline()
    onFileUrlChanged: {
        isHistoricalMode = false
        isPlaying = false
        reloadTimeline()
    }
    onModeChanged: {
        isHistoricalMode = false
        isPlaying = false
        reloadTimeline()
    }

    Connections {
        target: (typeof backend !== "undefined") ? backend : null
        ignoreUnknownSignals: true
        function onHistoryUpdated() {
            historyBarRoot.reloadTimeline()
        }
    }

    Timer {
        id: playTimer
        interval: 1200
        repeat: true
        running: historyBarRoot.isPlaying
        onTriggered: {
            var days = historyBarRoot.daysList
            if (days.length <= 1) {
                historyBarRoot.isPlaying = false
                return
            }
            var curDay = historyBarRoot.currentDayIndex
            if (curDay < days.length - 1) {
                historyBarRoot.selectDay(curDay + 1)
            } else {
                historyBarRoot.goLive()
            }
        }
    }

    // 1. Кнопка шага назад "‹"
    Rectangle {
        Layout.preferredWidth: 24
        Layout.preferredHeight: 24
        Layout.alignment: Qt.AlignVCenter
        radius: 4
        color: prevMouse.containsMouse ? Theme.bgHover : "transparent"
        border.color: prevMouse.containsMouse ? Theme.borderHover : Theme.borderColor
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: "‹"
            font.pixelSize: 15
            font.bold: true
            color: historyBarRoot.currentDayIndex > 0 ? Theme.textPrimary : Theme.textMuted
        }

        MouseArea {
            id: prevMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: historyBarRoot.currentDayIndex > 0
            onClicked: historyBarRoot.stepPrev()
        }
    }

    // 2. Горизонтальный трек в стиле Git Graph (слева направо ->)
    Item {
        id: gitGraphTrack
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        Layout.alignment: Qt.AlignVCenter
        clip: true

        // Базовая направляющая линия ветки git graph
        Rectangle {
            id: baseTrackLine
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 2
            radius: 1
            color: Theme.borderColor
        }

        // Подсвеченная линия пройденного прогресса ветки (до текущей ревизии)
        Rectangle {
            id: activeProgressLine
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 12
            height: 2
            radius: 1
            color: Theme.textSecondary
            visible: historyBarRoot.daysList.length > 1
            width: {
                if (historyBarRoot.daysList.length <= 1) return 0
                var totalW = baseTrackLine.width
                var progressRatio = !historyBarRoot.isHistoricalMode
                    ? 1.0
                    : (historyBarRoot.currentDayIndex / (historyBarRoot.daysList.length - 1))
                return Math.max(0, Math.min(totalW, totalW * progressRatio))
            }
            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
        }

        // Узлы (коммиты/срезы) на горизонтальном таймлайне
        Repeater {
            model: historyBarRoot.daysList

            Item {
                id: nodeItem
                required property var modelData
                required property int index

                readonly property int totalNodes: historyBarRoot.daysList.length
                readonly property real posX: {
                    if (totalNodes <= 1) return gitGraphTrack.width / 2
                    var usableW = gitGraphTrack.width - 24
                    return 12 + (index / (totalNodes - 1)) * usableW
                }

                x: posX - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 22

                readonly property bool isCurrent: historyBarRoot.isHistoricalMode && (historyBarRoot.currentDayIndex === index)
                readonly property bool isLiveCurrent: !historyBarRoot.isHistoricalMode && (index === totalNodes - 1)
                readonly property bool isHighlighted: isCurrent || isLiveCurrent
                readonly property bool isHovered: nodeMouse.containsMouse

                // Внешний контур узла (halo / git graph node)
                Rectangle {
                    anchors.centerIn: parent
                    width: nodeItem.isHighlighted ? 18 : (nodeItem.isHovered ? 14 : 10)
                    height: width
                    radius: width / 2
                    color: nodeItem.isHighlighted
                        ? Theme.textPrimary
                        : (nodeItem.isHovered ? Theme.accentColor : Theme.bgPaper)
                    border.color: nodeItem.isHighlighted
                        ? Theme.textPrimary
                        : (nodeItem.isHovered ? Theme.accentColor : Theme.textSecondary)
                    border.width: nodeItem.isHighlighted ? 2 : 1

                    Behavior on width { NumberAnimation { duration: 100 } }
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on border.color { ColorAnimation { duration: 100 } }

                    // Внутренняя точка для активного узла git graph
                    Rectangle {
                        anchors.centerIn: parent
                        width: nodeItem.isHighlighted ? 6 : 0
                        height: width
                        radius: width / 2
                        color: Theme.bgApp
                        visible: nodeItem.isHighlighted
                    }
                }

                MouseArea {
                    id: nodeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        historyBarRoot.activated()
                        historyBarRoot.selectDay(nodeItem.index)
                    }
                }

                // Всплывающая подсказка при наведении на коммит
                ToolTip.visible: nodeMouse.containsMouse
                ToolTip.delay: 200
                ToolTip.text: {
                    var desc = (nodeItem.modelData.snapshot && nodeItem.modelData.snapshot.description) ? nodeItem.modelData.snapshot.description : ""
                    return nodeItem.modelData.timeStr + "  " + nodeItem.modelData.dateStr + (desc ? "\n" + desc : "")
                }
            }
        }
    }

    // 3. Кнопка шага вперед "›"
    Rectangle {
        Layout.preferredWidth: 24
        Layout.preferredHeight: 24
        Layout.alignment: Qt.AlignVCenter
        radius: 4
        color: nextMouse.containsMouse ? Theme.bgHover : "transparent"
        border.color: nextMouse.containsMouse ? Theme.borderHover : Theme.borderColor
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: "›"
            font.pixelSize: 15
            font.bold: true
            color: (historyBarRoot.isHistoricalMode && historyBarRoot.currentDayIndex < historyBarRoot.daysList.length - 1) ? Theme.textPrimary : Theme.textMuted
        }

        MouseArea {
            id: nextMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: historyBarRoot.isHistoricalMode
            onClicked: historyBarRoot.stepNext()
        }
    }

    // 4. Акцентная кнопка "Live"
    Rectangle {
        id: liveBtn
        Layout.preferredHeight: 24
        Layout.preferredWidth: liveContent.implicitWidth + 14
        Layout.alignment: Qt.AlignVCenter
        radius: 4

        readonly property bool isLiveActive: !historyBarRoot.isHistoricalMode
        readonly property bool isHovered: liveMouse.containsMouse

        color: isLiveActive
            ? Theme.bgHover
            : (isHovered ? Theme.bgHover : "transparent")

        border.color: isLiveActive
            ? Theme.borderHover
            : (isHovered ? Theme.borderHover : Theme.borderColor)
        border.width: 1

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        RowLayout {
            id: liveContent
            anchors.centerIn: parent
            spacing: 5

            Rectangle {
                width: 6
                height: 6
                radius: 3
                color: liveBtn.isLiveActive ? "#4ade80" : Theme.textMuted
            }

            Text {
                text: "Live"
                font.pixelSize: 11
                font.bold: true
                color: liveBtn.isLiveActive ? Theme.textPrimary : Theme.textSecondary
            }
        }

        MouseArea {
            id: liveMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                historyBarRoot.activated()
                historyBarRoot.goLive()
            }
        }
    }

    // 5. Правый блок даты и времени (строго одинаковая ширина строк, как на референсе)
    // Верх: HH:MM:SS am/pm (12:07:22 pm)
    // Низ:  DD/MM/YYYY    (01/10/2026)
    Column {
        id: timestampBlock
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: 84
        spacing: 1

        Text {
            id: timeLabel
            width: parent.width
            text: historyBarRoot.displayTimeText
            font.pixelSize: 11
            font.family: "Consolas, 'Courier New', monospace"
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            color: Theme.textPrimary
        }

        Text {
            id: dateLabel
            width: parent.width
            text: historyBarRoot.displayDateText
            font.pixelSize: 11
            font.family: "Consolas, 'Courier New', monospace"
            font.weight: Font.Normal
            horizontalAlignment: Text.AlignHCenter
            color: Theme.textSecondary
        }
    }
}
