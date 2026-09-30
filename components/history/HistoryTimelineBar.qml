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

    // Кнопка воспроизведения: Play / Pause
    Rectangle {
        id: playBtn
        Layout.preferredWidth: 28
        Layout.preferredHeight: 28
        Layout.alignment: Qt.AlignVCenter
        radius: 6
        color: playMouse.containsMouse ? Theme.borderHover : Theme.bgPaper
        border.color: Theme.borderColor
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: historyBarRoot.isPlaying ? "⏸" : "▶"
            font.pixelSize: 11
            color: playMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
        }

        MouseArea {
            id: playMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                historyBarRoot.activated()
                historyBarRoot.togglePlay()
            }
        }
    }

    // Метка месяца и года
    Text {
        id: monthYearText
        Layout.alignment: Qt.AlignVCenter
        font.pixelSize: 12
        font.bold: true
        color: Theme.textPrimary
        text: TimelineCtrl.getMonthYearContext(historyBarRoot.currentSnapshotIndex, historyBarRoot.timelineList)
        visible: text.length > 0
    }

    // Тонкий разделитель
    Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: 16
        Layout.alignment: Qt.AlignVCenter
        color: Theme.borderColor
        visible: monthYearText.visible
    }

    // Сегментированный таймлайн
    ColumnLayout {
        id: segmentedTimeline
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 4

        // Верхняя информационная строка
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                id: stepTitleText
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.pixelSize: 11
                font.bold: true
                color: Theme.textPrimary
                text: TimelineCtrl.getStepTitleText(historyBarRoot.daysList, historyBarRoot.isHistoricalMode, historyBarRoot.currentDayIndex)
            }

            Text {
                id: docStatsLabel
                visible: historyBarRoot.statsText !== ""
                font.pixelSize: 11
                color: Theme.textMuted
                text: historyBarRoot.statsText
            }

            Text {
                id: statsCountText
                font.pixelSize: 11
                color: Theme.textSecondary
                text: TimelineCtrl.getStatsCountText(historyBarRoot.timelineList, historyBarRoot.currentSnapshotIndex)
            }

            // Кнопка возврата к актуальному состоянию
            Rectangle {
                visible: historyBarRoot.isHistoricalMode
                Layout.preferredHeight: 18
                Layout.preferredWidth: liveBtnText.implicitWidth + 12
                radius: 9
                color: liveMouse.containsMouse ? Theme.borderHover : Theme.bgPaper
                border.color: Theme.borderColor
                border.width: 1

                Text {
                    id: liveBtnText
                    anchors.centerIn: parent
                    text: "↺ Сейчас"
                    font.pixelSize: 10
                    color: liveMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
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
        }

        // Нижняя сегментированная полоса
        RowLayout {
            id: segmentsRow
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            spacing: 4

            Repeater {
                model: historyBarRoot.daysList

                Rectangle {
                    id: segRect
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.preferredHeight: 18
                    radius: 3

                    property bool isCurrent: historyBarRoot.isHistoricalMode && (historyBarRoot.currentDayIndex === index)
                    property bool isPassed: historyBarRoot.isHistoricalMode ? (index <= historyBarRoot.currentDayIndex) : true
                    property bool isHovered: segMouse.containsMouse

                    color: isPassed
                        ? (isCurrent ? Theme.textPrimary : Theme.textSecondary)
                        : (isHovered ? Theme.borderHover : Theme.bgPaper)

                    border.color: isCurrent
                        ? Theme.textPrimary
                        : (isPassed ? Theme.textSecondary : (isHovered ? Theme.textSecondary : Theme.borderColor))
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: segRect.modelData.dayNum
                        font.pixelSize: 10
                        font.bold: segRect.isCurrent
                        color: segRect.isPassed
                            ? Theme.bgApp
                            : (segRect.isHovered ? Theme.textPrimary : Theme.textMuted)
                    }

                    MouseArea {
                        id: segMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            historyBarRoot.activated()
                            historyBarRoot.selectDay(segRect.index)
                        }
                    }
                }
            }
        }
    }
}
