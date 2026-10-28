// components/metro/MetroView.qml — Интерактивный компонент схемы метро сюжета (Metro Transit Map)
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "./metro_renderer.js" as Renderer
import "../theme"

Rectangle {
    id: metroRoot
    color: Theme.bgPaper
    clip: true

    property string folderUrl: ""
    property string activeFileUrl: ""
    property var metroData: null
    property var metroConfig: null

    property real panX: 60
    property real panY: 60
    property real zoomScale: 1.0

    property var hoveredStation: null
    property string hoveredTrackId: ""
    readonly property var hoveredTrackObj: {
        if (!hoveredTrackId || !metroData || !metroData.tracks) return null
        for (var i = 0; i < metroData.tracks.length; i++) {
            if (metroData.tracks[i].id === hoveredTrackId) return metroData.tracks[i]
        }
        return null
    }

    property bool _isDragging: false
    property real _lastMouseX: 0
    property real _lastMouseY: 0

    signal stationClicked(string fileUrl, string blockName)
    signal closeRequested()
    signal metroPressed()

    onFolderUrlChanged: reloadMetro()
    onActiveFileUrlChanged: reloadMetro()
    onVisibleChanged: {
        if (visible) {
            reloadMetro()
            forceActiveFocus()
        }
    }

    Component.onCompleted: {
        reloadMetro()
    }

    function reloadMetro() {
        if (typeof backend !== "undefined" && backend) {
            if (typeof backend.get_metro_config === "function") {
                metroConfig = backend.get_metro_config(folderUrl)
            }
            if (typeof backend.get_metro_data === "function") {
                metroData = backend.get_metro_data(folderUrl, activeFileUrl)
                if (metroData && metroData.bounds) {
                    fitToView()
                }
            }
        }
        if (canvas) canvas.requestPaint()
    }

    function fitToView() {
        if (!metroData || !metroData.bounds) return
        var fitted = Renderer.fitToBounds(metroData.bounds, width, height)
        panX = fitted.panX
        panY = fitted.panY
        zoomScale = fitted.zoomScale
        if (canvas) canvas.requestPaint()
    }

    // Анимация плавного панорамирования к этапу
    NumberAnimation {
        id: panAnim
        target: metroRoot
        property: "panX"
        duration: 380
        easing.type: Easing.OutCubic
        onRunningChanged: if (!running) canvas.requestPaint()
    }

    function jumpToStage(stageIdx) {
        if (!metroData || !metroData.stages || stageIdx < 0 || stageIdx >= metroData.stages.length) return
        var stg = metroData.stages[stageIdx]
        var targetX = (width / 2) - stg.x * zoomScale
        panAnim.stop()
        panAnim.from = panX
        panAnim.to = targetX
        panAnim.start()
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.Image

        onPaint: {
            var ctx = getContext("2d")
            Renderer.renderMetro(
                ctx,
                width,
                height,
                metroRoot.metroData,
                metroRoot.metroConfig,
                metroRoot.panX,
                metroRoot.panY,
                metroRoot.zoomScale,
                metroRoot.hoveredStation ? metroRoot.hoveredStation.id : "",
                metroRoot.activeFileUrl,
                metroRoot.hoveredTrackId
            )
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        cursorShape: (metroRoot.hoveredStation || metroRoot.hoveredTrackId)
            ? Qt.PointingHandCursor
            : (metroRoot._isDragging ? Qt.ClosedHandCursor : Qt.ArrowCursor)

        onPressed: (mouse) => {
            metroRoot.forceActiveFocus()
            metroRoot.metroPressed()

            var st = Renderer.findStationAt(
                metroRoot.metroData ? metroRoot.metroData.stations : [],
                mouse.x,
                mouse.y,
                metroRoot.panX,
                metroRoot.panY,
                metroRoot.zoomScale
            )

            if (st && mouse.button === Qt.LeftButton) {
                metroRoot.stationClicked(st.file_url, st.block_name)
                return
            }

            metroRoot._isDragging = true
            metroRoot._lastMouseX = mouse.x
            metroRoot._lastMouseY = mouse.y
        }

        onPositionChanged: (mouse) => {
            if (metroRoot._isDragging) {
                var dx = mouse.x - metroRoot._lastMouseX
                var dy = mouse.y - metroRoot._lastMouseY
                metroRoot.panX += dx
                metroRoot.panY += dy
                metroRoot._lastMouseX = mouse.x
                metroRoot._lastMouseY = mouse.y
                canvas.requestPaint()
                return
            }

            // 1. Проверяем попадание в станцию
            var st = Renderer.findStationAt(
                metroRoot.metroData ? metroRoot.metroData.stations : [],
                mouse.x,
                mouse.y,
                metroRoot.panX,
                metroRoot.panY,
                metroRoot.zoomScale
            )

            var trId = ""
            if (!st) {
                // 2. Если курсор не над станцией, проверяем ветки (бейджи или сплайн)
                trId = Renderer.findTrackAt(
                    metroRoot.metroData ? metroRoot.metroData.tracks : [],
                    metroRoot.metroData ? metroRoot.metroData.segments : [],
                    metroRoot.metroData ? metroRoot.metroData.stations : [],
                    mouse.x,
                    mouse.y,
                    metroRoot.panX,
                    metroRoot.panY,
                    metroRoot.zoomScale
                ) || ""
            }

            var stationChanged = (st !== metroRoot.hoveredStation)
            var trackChanged = (trId !== metroRoot.hoveredTrackId)

            if (stationChanged || trackChanged) {
                metroRoot.hoveredStation = st
                metroRoot.hoveredTrackId = trId
                canvas.requestPaint()
            }
        }

        onExited: {
            if (metroRoot.hoveredStation !== null || metroRoot.hoveredTrackId !== "") {
                metroRoot.hoveredStation = null
                metroRoot.hoveredTrackId = ""
                canvas.requestPaint()
            }
        }

        onReleased: (mouse) => {
            metroRoot._isDragging = false
        }

        onWheel: (wheel) => {
            var factor = Math.exp(wheel.angleDelta.y * 0.001)
            var newScale = Math.max(0.2, Math.min(3.0, metroRoot.zoomScale * factor))
            if (newScale !== metroRoot.zoomScale) {
                var mouseX = wheel.x
                var mouseY = wheel.y
                metroRoot.panX = mouseX - (mouseX - metroRoot.panX) * (newScale / metroRoot.zoomScale)
                metroRoot.panY = mouseY - (mouseY - metroRoot.panY) * (newScale / metroRoot.zoomScale)
                metroRoot.zoomScale = newScale
                canvas.requestPaint()
            }
        }

        onDoubleClicked: (mouse) => {
            metroRoot.fitToView()
        }
    }

    // Верхняя панель навигации по этапам (Epoch Scrubber & Controls)
    Rectangle {
        id: topNav
        visible: (metroData && metroData.stages && metroData.stages.length > 1) ? true : false
        anchors.top: parent.top
        anchors.topMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        height: 38
        radius: 19
        color: Theme.bgDialog
        border.color: Theme.borderColor
        border.width: 1
        z: 10

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 4

            Repeater {
                model: (metroData && metroData.stages) ? metroData.stages : []
                delegate: Rectangle {
                    id: stagePill
                    implicitWidth: stageLabel.implicitWidth + 14
                    implicitHeight: 26
                    radius: 13

                    readonly property real stageScreenX: (modelData.x * metroRoot.zoomScale) + metroRoot.panX
                    readonly property bool isNearCenter: Math.abs(stageScreenX - (metroRoot.width / 2)) < (220 * metroRoot.zoomScale)

                    color: isNearCenter
                        ? Theme.accentColor
                        : (stageMouse.containsMouse ? Theme.bgHover : "transparent")

                    Text {
                        id: stageLabel
                        anchors.centerIn: parent
                        text: modelData.short_title || ("Э" + (index + 1))
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: stagePill.isNearCenter
                        color: stagePill.isNearCenter ? Theme.textSelected : (stageMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary)
                    }

                    MouseArea {
                        id: stageMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            metroRoot.jumpToStage(index)
                        }
                    }

                    ToolTip.visible: stageMouse.containsMouse
                    ToolTip.text: modelData.title || ""
                    ToolTip.delay: 300
                }
            }

            Rectangle {
                width: 1
                height: 16
                color: Theme.borderColor
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 4
                Layout.rightMargin: 4
            }

            // Кнопка сброса масштаба
            Rectangle {
                implicitWidth: 26
                implicitHeight: 26
                radius: 13
                color: fitMouse.containsMouse ? Theme.bgHover : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "⤢"
                    font.pixelSize: 13
                    color: fitMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                }

                MouseArea {
                    id: fitMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: metroRoot.fitToView()
                }

                ToolTip.visible: fitMouse.containsMouse
                ToolTip.text: "Вписать схему в экран (Двойной клик)"
                ToolTip.delay: 300
            }

            // Кнопка закрытия
            Rectangle {
                implicitWidth: 26
                implicitHeight: 26
                radius: 13
                color: closeMouse.containsMouse ? Theme.bgHover : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: 11
                    color: closeMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: metroRoot.closeRequested()
                }

                ToolTip.visible: closeMouse.containsMouse
                ToolTip.text: "Закрыть схему метро (Esc)"
                ToolTip.delay: 300
            }
        }
    }

    // Всплывающая плашка наведенной линии (Track Pill)
    Rectangle {
        id: trackInfoPill
        visible: metroRoot.hoveredStation === null && metroRoot.hoveredTrackObj !== null
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        height: 38
        implicitWidth: trackPillLayout.implicitWidth + 24
        radius: 19
        color: Theme.bgDialog
        border.color: Theme.borderColor
        border.width: 1
        z: 10
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        RowLayout {
            id: trackPillLayout
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 14
            spacing: 8

            Rectangle {
                width: 10
                height: 10
                radius: 5
                color: metroRoot.hoveredTrackObj ? (metroRoot.hoveredTrackObj.color || Theme.accentColor) : "transparent"
            }

            Text {
                text: metroRoot.hoveredTrackObj ? (metroRoot.hoveredTrackObj.title || metroRoot.hoveredTrackObj.id) : ""
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.bold: true
                color: Theme.textPrimary
            }

            Text {
                text: "• " + (metroRoot.hoveredTrackObj && metroRoot.hoveredTrackObj.station_ids ? metroRoot.hoveredTrackObj.station_ids.length : 0) + " сцен"
                font.family: Theme.fontFamily
                font.pixelSize: 11
                color: Theme.textMuted
            }
        }
    }

    // Всплывающая карточка наведенной станции (Station Card)
    Rectangle {
        id: stationCard
        visible: metroRoot.hoveredStation !== null
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        width: 320
        implicitHeight: cardLayout.implicitHeight + 20
        radius: 12
        color: Theme.bgDialog
        border.color: Theme.borderColor
        border.width: 1
        z: 10
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        ColumnLayout {
            id: cardLayout
            anchors.fill: parent
            anchors.margins: 12
            spacing: 5

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: (metroRoot.hoveredStation ? (metroRoot.hoveredStation.date_str || "") : "")
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: Theme.accentColor
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: (metroRoot.hoveredStation ? (metroRoot.hoveredStation.stage_title || "") : "")
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: Theme.textMuted
                    elide: Text.ElideRight
                    Layout.maximumWidth: 150
                }
            }

            Text {
                Layout.fillWidth: true
                text: (metroRoot.hoveredStation ? metroRoot.hoveredStation.title : "")
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.bold: true
                color: Theme.textPrimary
                wrapMode: Text.Wrap
            }

            Text {
                Layout.fillWidth: true
                visible: (metroRoot.hoveredStation && metroRoot.hoveredStation.note) ? true : false
                text: (metroRoot.hoveredStation ? (metroRoot.hoveredStation.note || "") : "")
                font.family: Theme.fontFamily
                font.pixelSize: 11
                color: Theme.textSecondary
                wrapMode: Text.Wrap
            }

            Flow {
                Layout.fillWidth: true
                spacing: 4
                visible: (metroRoot.hoveredStation && metroRoot.hoveredStation.tracks && metroRoot.hoveredStation.tracks.length > 0) ? true : false

                Repeater {
                    model: (metroRoot.hoveredStation && metroRoot.hoveredStation.tracks) ? metroRoot.hoveredStation.tracks : []
                    delegate: Rectangle {
                        implicitWidth: trackText.implicitWidth + 10
                        implicitHeight: 18
                        radius: 9
                        color: Theme.bgInput
                        border.color: Theme.borderColor
                        border.width: 1

                        Text {
                            id: trackText
                            anchors.centerIn: parent
                            text: "@" + modelData.replace("_", " ")
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            color: Theme.textSecondary
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: (metroRoot.hoveredStation && metroRoot.hoveredStation.summary) ? true : false
                text: (metroRoot.hoveredStation ? (metroRoot.hoveredStation.summary || "") : "")
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: Theme.textMuted
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: "ЛКМ — перейти к тексту заметки"
                font.family: Theme.fontFamily
                font.pixelSize: 9
                font.italic: true
                color: Theme.accentColor
            }
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            metroRoot.closeRequested()
            event.accepted = true
        } else if (event.key === Qt.Key_Space) {
            metroRoot.fitToView()
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            metroRoot.panX += 100
            canvas.requestPaint()
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            metroRoot.panX -= 100
            canvas.requestPaint()
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            metroRoot.panY += 100
            canvas.requestPaint()
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            metroRoot.panY -= 100
            canvas.requestPaint()
            event.accepted = true
        } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
            metroRoot.jumpToStage(event.key - Qt.Key_1)
            event.accepted = true
        } else if (event.key === Qt.Key_0) {
            metroRoot.jumpToStage(9)
            event.accepted = true
        }
    }
}
