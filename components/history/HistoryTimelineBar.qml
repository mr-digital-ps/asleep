import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "./timeline_controller.js" as TimelineCtrl

RowLayout {
    id: historyBarRoot
    spacing: 14

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
        interval: 1100
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

    // Ползунок истории проекта: только бегунок по срезам/дням
    Slider {
        id: timelineSlider
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        from: 0
        to: Math.max(0, historyBarRoot.daysList.length - 1)
        stepSize: 1
        snapMode: Slider.SnapAlways
        value: historyBarRoot.isHistoricalMode ? historyBarRoot.currentDayIndex : to

        onMoved: {
            historyBarRoot.activated()
            let targetIdx = Math.round(value)
            if (targetIdx >= to) {
                historyBarRoot.goLive()
            } else {
                historyBarRoot.selectDay(targetIdx)
            }
        }

        // Кастомная минималистичная стилизация ползунка в стиле asleep
        background: Rectangle {
            x: timelineSlider.leftPadding
            y: timelineSlider.topPadding + timelineSlider.availableHeight / 2 - height / 2
            implicitWidth: 200
            implicitHeight: 4
            width: timelineSlider.availableWidth
            height: implicitHeight
            radius: 2
            color: Theme.borderColor

            Rectangle {
                width: timelineSlider.visualPosition * parent.width
                height: parent.height
                color: Theme.accentColor
                radius: 2
            }
        }

        handle: Rectangle {
            x: timelineSlider.leftPadding + timelineSlider.visualPosition * (timelineSlider.availableWidth - width)
            y: timelineSlider.topPadding + timelineSlider.availableHeight / 2 - height / 2
            implicitWidth: 16
            implicitHeight: 16
            radius: 8
            color: timelineSlider.pressed ? Theme.textSelected : (timelineSlider.hovered ? Theme.accentHover : Theme.textPrimary)
            border.color: Theme.bgPaper
            border.width: 2

            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }
}
