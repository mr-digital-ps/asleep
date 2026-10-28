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


    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.Image

        onPaint: {
            var ctx = getContext("2d")
            try {
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
            } catch (err) {
                console.error("[MetroView] Error in renderMetro:", err)
            }
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
        }
    }
}
