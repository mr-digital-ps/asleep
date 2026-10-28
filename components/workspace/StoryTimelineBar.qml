// components/workspace/StoryTimelineBar.qml — Хронологический ползунок таймлайна в PaneHeader (Timeline Scrub Bar)
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme"

RowLayout {
    id: root
    spacing: 10

    property string folderUrl: ""
    property string fileUrl: ""
    property var timelineData: null
    property int currentIndex: -1

    readonly property var stationsList: (timelineData && timelineData.stations) ? timelineData.stations : []
    readonly property int totalStations: stationsList.length
    readonly property var activeStation: (currentIndex >= 0 && currentIndex < totalStations) ? stationsList[currentIndex] : null

    signal activated()
    signal stationSelected(string fileUrl, string blockName, int line)

    onFolderUrlChanged: reload()
    onFileUrlChanged: reload()
    onVisibleChanged: {
        if (visible) reload()
    }

    function reload() {
        if (typeof backend === "undefined" || !backend) return
        if (typeof backend.get_story_timeline === "function") {
            timelineData = backend.get_story_timeline(folderUrl, fileUrl)
            if (stationsList.length > 0 && currentIndex < 0) {
                var foundIdx = 0
                if (fileUrl) {
                    for (var i = 0; i < stationsList.length; i++) {
                        if (stationsList[i].file_url === fileUrl) {
                            foundIdx = i
                            break
                        }
                    }
                }
                selectStation(foundIdx, false)
            }
        }
    }

    function selectStation(idx, notify) {
        if (typeof notify === "undefined") notify = true
        if (idx < 0 || idx >= totalStations) return
        currentIndex = idx
        var st = stationsList[idx]
        if (st && notify) {
            root.activated()
            root.stationSelected(st.file_url, st.block_name, st.line)
            if (typeof backend !== "undefined" && backend) {
                var target = st.file_url + "#" + st.block_name
                backend.open_wiki_link(target)
            }
        }
    }

    function stepPrev() {
        if (currentIndex > 0) {
            selectStation(currentIndex - 1)
        }
    }

    function stepNext() {
        if (currentIndex < totalStations - 1) {
            selectStation(currentIndex + 1)
        }
    }

    // 1. Кнопка "Назад" ◀
    Item {
        Layout.preferredWidth: 20
        Layout.preferredHeight: 20
        Layout.alignment: Qt.AlignVCenter
        opacity: (root.currentIndex > 0) ? 1.0 : 0.3

        Text {
            anchors.centerIn: parent
            text: "◀"
            font.pixelSize: 10
            color: prevMouse.containsMouse ? Theme.accentHover : Theme.textSecondary
        }

        MouseArea {
            id: prevMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: (root.currentIndex > 0) ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.stepPrev()
        }
    }

    // 2. Начальный год (метка)
    Text {
        Layout.alignment: Qt.AlignVCenter
        text: (root.timelineData && root.timelineData.min_year) ? ("" + root.timelineData.min_year) : ""
        font.family: Theme.fontFamily
        font.pixelSize: 11
        font.bold: true
        color: Theme.textMuted
        visible: text.length > 0
    }

    // 3. Интерактивная полоса таймлайна (Track & Scrubber Thumb)
    Item {
        id: trackContainer
        Layout.fillWidth: true
        Layout.preferredHeight: 28
        Layout.alignment: Qt.AlignVCenter
        Layout.minimumWidth: 120

        // Фоновая направляющая линия
        Rectangle {
            id: baseLine
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            height: 2
            radius: 1
            color: Theme.borderColor
        }

        // Заполненная линия пройденного прогресса
        Rectangle {
            id: progressLine
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: baseLine.left
            height: 2
            radius: 1
            color: Theme.textSecondary
            visible: root.totalStations > 1
            width: {
                if (root.totalStations <= 1) return 0
                var ratio = root.currentIndex / (root.totalStations - 1)
                return Math.max(0, Math.min(baseLine.width, baseLine.width * ratio))
            }
        }

        // Интерактивный ползунок (Scrubber Knob)
        Rectangle {
            id: knob
            readonly property real posX: {
                if (root.totalStations <= 1) return baseLine.x + baseLine.width / 2
                var ratio = root.currentIndex / (root.totalStations - 1)
                return baseLine.x + ratio * baseLine.width
            }
            x: posX - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: trackMouse.pressed ? 12 : (trackMouse.containsMouse ? 10 : 8)
            height: width
            radius: width / 2
            color: Theme.textPrimary
            border.color: Theme.bgApp
            border.width: 1

            Behavior on width { NumberAnimation { duration: 100 } }
        }

        MouseArea {
            id: trackMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            function updateFromMouseX(mouseX) {
                if (root.totalStations <= 1) return
                var clampedX = Math.max(baseLine.x, Math.min(baseLine.x + baseLine.width, mouseX))
                var ratio = (clampedX - baseLine.x) / baseLine.width
                var targetIdx = Math.round(ratio * (root.totalStations - 1))
                root.selectStation(targetIdx)
            }

            onPressed: (mouse) => updateFromMouseX(mouse.x)
            onPositionChanged: (mouse) => {
                if (pressed) {
                    updateFromMouseX(mouse.x)
                }
            }
            onWheel: (wheel) => {
                if (wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0) {
                    root.stepPrev()
                } else if (wheel.angleDelta.y < 0 || wheel.angleDelta.x < 0) {
                    root.stepNext()
                }
            }
        }
    }

    // 4. Финальный год (метка)
    Text {
        Layout.alignment: Qt.AlignVCenter
        text: (root.timelineData && root.timelineData.max_year) ? ("" + root.timelineData.max_year) : ""
        font.family: Theme.fontFamily
        font.pixelSize: 11
        font.bold: true
        color: Theme.textMuted
        visible: text.length > 0
    }

    // 5. Кнопка "Вперед" ▶
    Item {
        Layout.preferredWidth: 20
        Layout.preferredHeight: 20
        Layout.alignment: Qt.AlignVCenter
        opacity: (root.currentIndex < root.totalStations - 1) ? 1.0 : 0.3

        Text {
            anchors.centerIn: parent
            text: "▶"
            font.pixelSize: 10
            color: nextMouse.containsMouse ? Theme.accentHover : Theme.textSecondary
        }

        MouseArea {
            id: nextMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: (root.currentIndex < root.totalStations - 1) ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.stepNext()
        }
    }

    // 6. Индикатор активной станции: Год · Название [ @Актеры ]
    RowLayout {
        Layout.alignment: Qt.AlignVCenter
        Layout.maximumWidth: 380
        spacing: 6
        visible: root.activeStation !== null

        // Год/дата станции
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            height: 18
            radius: 3
            color: Theme.bgActive
            border.color: Theme.borderColor
            border.width: 1
            visible: dateText.text.length > 0
            implicitWidth: dateText.implicitWidth + 8

            Text {
                id: dateText
                anchors.centerIn: parent
                text: root.activeStation ? (root.activeStation.date_str || ("" + root.activeStation.year)) : ""
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.bold: true
                color: Theme.textPrimary
            }
        }

        // Название станции
        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: root.activeStation ? root.activeStation.title : ""
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.bold: true
            color: Theme.textPrimary
            elide: Text.ElideRight
        }

        // Список основных участников @актеров (первые 2 бейджа)
        Repeater {
            model: root.activeStation ? (root.activeStation.actors || []).slice(0, 2) : []

            Rectangle {
                required property var modelData
                Layout.alignment: Qt.AlignVCenter
                height: 16
                radius: 3
                color: Theme.bgHover
                border.color: Theme.borderColor
                border.width: 1
                implicitWidth: actorLabel.implicitWidth + 8

                Text {
                    id: actorLabel
                    anchors.centerIn: parent
                    text: modelData
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    color: Theme.textSecondary
                }
            }
        }
    }
}
