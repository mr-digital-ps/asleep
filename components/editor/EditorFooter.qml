import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "../history"

Item {
    id: footerRoot
    height: 70

    property bool isPinned: false
    property bool isGraphMode: false
    property string statsText: ""
    property bool showBackground: true
    property int barSize: 36
    property string folderUrl: ""

    property string fileUrl: ""
    property bool isProjectTree: false
    readonly property string timelineMode: (isGraphMode || isProjectTree) ? "project" : "note"

    // Свойства таймлайна истории проекта (проксируются в HistoryTimelineBar)
    property alias timelineList: historyBar.timelineList
    property alias currentSnapshotIndex: historyBar.currentSnapshotIndex
    property alias isPlaying: historyBar.isPlaying
    property alias isHistoricalMode: historyBar.isHistoricalMode

    signal pinToggled()
    signal activated()
    signal snapshotSelected(int snapshotId)
    signal liveRequested()

    focus: true
    Keys.onSpacePressed: (event) => {
        historyBar.togglePlay()
        event.accepted = true
    }
    Keys.onLeftPressed: (event) => {
        historyBar.stepPrev()
        event.accepted = true
    }
    Keys.onRightPressed: (event) => {
        historyBar.stepNext()
        event.accepted = true
    }

    function togglePlay() { historyBar.togglePlay() }
    function stepPrev() { historyBar.stepPrev() }
    function stepNext() { historyBar.stepNext() }
    function goLive() { historyBar.goLive() }
    function reloadTimeline() { historyBar.reloadTimeline() }

    Rectangle {
        anchors.fill: parent
        color: Theme.bgFooter
        visible: footerRoot.showBackground
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.ArrowCursor
        onPressed: (mouse) => {
            footerRoot.activated()
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

        // Разделительная линия
        Item {
            id: footerDividerArea
            Layout.fillWidth: true
            Layout.preferredHeight: 14
            Layout.maximumHeight: 14
            Layout.leftMargin: footerRoot.barSize
            Layout.rightMargin: footerRoot.barSize

            Rectangle {
                id: footerDividerLine
                anchors.centerIn: parent
                width: parent.width
                height: 2
                radius: 1
                color: (footerRoot.isPinned || footerRoot.isGraphMode)
                    ? (footerDividerMouse.containsMouse ? Theme.textSecondary : Theme.textMuted)
                    : (footerDividerMouse.containsMouse ? Theme.borderHover : Theme.borderColor)
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            MouseArea {
                id: footerDividerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    footerRoot.pinToggled()
                    footerRoot.activated()
                }
            }
        }

        // Шкала истории (всегда активна: для графа, структуры или заметки)
        HistoryTimelineBar {
            id: historyBar
            visible: true
            folderUrl: footerRoot.folderUrl
            fileUrl: footerRoot.fileUrl
            mode: footerRoot.timelineMode
            statsText: footerRoot.statsText
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: footerRoot.barSize
            Layout.rightMargin: footerRoot.barSize
            Layout.bottomMargin: 10

            onActivated: footerRoot.activated()
            onSnapshotSelected: (snapshotId) => footerRoot.snapshotSelected(snapshotId)
            onLiveRequested: footerRoot.liveRequested()
        }
    }
}
