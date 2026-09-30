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

    // Разделительная линия
    Item {
        id: footerDividerArea
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: footerRoot.barSize
        anchors.rightMargin: footerRoot.barSize
        height: 14

        Rectangle {
            id: footerDividerLine
            anchors.centerIn: parent
            width: parent.width
            height: 2
            radius: 1
            color: Theme.textSecondary
            opacity: 0.9
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
        anchors.top: footerDividerArea.bottom
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: footerRoot.barSize
        anchors.rightMargin: footerRoot.barSize

        onActivated: footerRoot.activated()
        onSnapshotSelected: (snapshotId) => footerRoot.snapshotSelected(snapshotId)
        onLiveRequested: footerRoot.liveRequested()
    }
}
