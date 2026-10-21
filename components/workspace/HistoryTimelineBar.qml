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
    property string fileName: ""
    property string mode: "project" // "project" (для графа и структуры) или "note" (для отдельного файла)
    property string statsText: ""
    property var timelineList: []
    property int currentSnapshotIndex: -1
    property bool isPlaying: false
    property bool isHistoricalMode: false

    property var daysList: TimelineCtrl.getDaysList(timelineList)
    property int currentDayIndex: TimelineCtrl.getDayIndexForSnapshot(currentSnapshotIndex, daysList, timelineList)

    // Тикер реального времени для Live режима
    property date currentNow: new Date()
    Timer {
        id: liveClockTimer
        interval: 1000
        repeat: true
        running: !historyBarRoot.isHistoricalMode
        triggeredOnStart: true
        onTriggered: {
            historyBarRoot.currentNow = new Date()
        }
    }

    // Активный снапшот или текущее время (для Live режима)
    readonly property var activeDayObj: (currentDayIndex >= 0 && currentDayIndex < daysList.length) ? daysList[currentDayIndex] : null
    readonly property string displayTimeText: {
        if (isHistoricalMode && activeDayObj) {
            return activeDayObj.timeStr || "--:--:-- --"
        }
        return TimelineCtrl.formatTime12FromDate(currentNow)
    }
    readonly property string displayDateText: {
        if (isHistoricalMode && activeDayObj) {
            return activeDayObj.dateStr || "--/--/----"
        }
        return TimelineCtrl.formatDateDMYFromDate(currentNow)
    }

    signal activated()
    signal snapshotSelected(int snapshotId)
    signal liveRequested()
    property string historySubMode: "snapshot"

    function reloadTimeline() {
        if (typeof backend === "undefined" || !backend) return
        var list = []
        var targetFile = historyBarRoot.fileUrl || historyBarRoot.fileName
        if (historyBarRoot.mode === "note" && targetFile) {
            if (typeof backend.get_file_history_timeline === "function") {
                list = backend.get_file_history_timeline(targetFile, historyBarRoot.folderUrl) || []
            }
            if (typeof backend.get_file_created_time === "function") {
                var cInfo = backend.get_file_created_time(targetFile, historyBarRoot.folderUrl)
                if (cInfo && cInfo.timestamp) {
                    var firstTs = (list.length > 0 && list[0].timestamp) ? list[0].timestamp : (Date.now() / 1000)
                    if (cInfo.timestamp < firstTs - 1) {
                        list.unshift({
                            id: (list.length > 0 ? list[0].id : 0),
                            isCreation: true,
                            timestamp: cInfo.timestamp,
                            createdAt: cInfo.createdAt || cInfo.iso,
                            description: "Создание файла: " + (cInfo.fileName || "")
                        })
                    }
                }
            }
        } else {
            if (typeof backend.get_history_timeline === "function") {
                list = backend.get_history_timeline(historyBarRoot.folderUrl) || []
            }
        }
        // Добавляем финальный узел Live (актуальное состояние)
        var nowD = new Date()
        list.push({
            id: -1,
            isLive: true,
            timestamp: nowD.getTime() / 1000,
            createdAt: nowD.toISOString(),
            description: "Текущее состояние (Live)"
        })

        historyBarRoot.timelineList = list
        if (!historyBarRoot.isHistoricalMode && list.length > 0) {
            historyBarRoot.currentSnapshotIndex = list.length - 1
        }
    }

    function selectIndex(idx) {
        if (idx < 0 || idx >= historyBarRoot.timelineList.length) return
        historyBarRoot.currentSnapshotIndex = idx
        var item = historyBarRoot.timelineList[idx]
        if (item && item.isLive) {
            historyBarRoot.goLive()
            return
        }
        historyBarRoot.isHistoricalMode = true
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
        historyBarRoot.historySubMode = "snapshot"
        if (historyBarRoot.timelineList.length > 0) {
            historyBarRoot.currentSnapshotIndex = historyBarRoot.timelineList.length - 1
        }
        historyBarRoot.liveRequested()
    }

    function toggleDiffSubMode() {
        historyBarRoot.activated()
        historyBarRoot.historySubMode = (historyBarRoot.historySubMode === "snapshot" ? "diff" : "snapshot")
        if (historyBarRoot.historySubMode === "diff" && !historyBarRoot.isHistoricalMode && historyBarRoot.daysList.length > 1) {
            historyBarRoot.selectDay(historyBarRoot.daysList.length - 2)
        }
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
    onFileNameChanged: {
        isHistoricalMode = false
        isPlaying = false
        reloadTimeline()
    }
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
    onVisibleChanged: {
        if (visible) reloadTimeline()
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

    // Горизонтальный трек в стиле Git Graph (слева направо ->)
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
            Behavior on width { NumberAnimation { duration: Theme.animDurationNormal; easing.type: Easing.OutQuad } }
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

                readonly property bool isLiveNode: nodeItem.modelData && nodeItem.modelData.isLive
                readonly property bool isCreationNode: nodeItem.modelData && nodeItem.modelData.isCreation

                // Внешний контур узла (halo / git graph node) — единообразный вид для всех, без зеленого цвета
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

                    Behavior on width { NumberAnimation { duration: Theme.animDurationFast } }
                    Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animDurationFast } }

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

    // Правый блок даты и времени (моноширинный, ровный по ширине и с одинаковым цветом шрифта)
    Column {
        id: timestampBlock
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: 92
        spacing: 2

        Text {
            id: timeLabel
            width: parent.width
            text: historyBarRoot.displayTimeText
            font.pixelSize: 11
            font.family: Theme.fontFamily
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            color: Theme.textSecondary
        }

        Text {
            id: dateLabel
            width: parent.width
            text: historyBarRoot.displayDateText
            font.pixelSize: 11
            font.family: Theme.fontFamily
            font.weight: Font.Normal
            horizontalAlignment: Text.AlignHCenter
            color: Theme.textSecondary
        }
    }
}
