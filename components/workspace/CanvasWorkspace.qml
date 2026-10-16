import QtQuick
import "./snap_engine.js" as SnapEngine
import "../theme"

// components/workspace/CanvasWorkspace.qml — Бесконечный координатный холст с плавающими и магнитящимися листами
Rectangle {
    id: canvasWorkspaceRoot
    anchors.fill: parent
    color: Theme.bgApp
    clip: true

    // Состояние камеры холста
    property real panX: 0
    property real panY: 0
    property real zoomScale: 1.0
    property int activePaneIndex: 0

    // Проброс базовых свойств
    property string currentFolderUrl: ""
    property string currentFolderName: ""
    property var openFileUrls: []
    property alias primaryBar: primaryContainer.pane
    property alias secondaryBar: secondaryContainer.pane
    property alias activeEditorArea: primaryContainer.pane.editorArea

    signal saveRequested()
    signal openRequested()
    signal openSplitRequested()
    signal newRequested()
    signal newSplitRequested()
    signal toggleGraphRequested()
    signal toggleLocalGraphRequested()
    signal toggleSplitRequested()
    signal closeGraphRequested()
    signal openStructureRequested()

    // Провайдер прямоугольников других панелей для SnapEngine
    function getOtherPanes(excludeId) {
        var list = []
        if (excludeId !== "pane_1" && primaryContainer.visible) {
            list.push({
                id: "pane_1",
                x: primaryContainer.x,
                y: primaryContainer.y,
                width: primaryContainer.width,
                height: primaryContainer.height
            })
        }
        if (excludeId !== "pane_2" && secondaryContainer.visible) {
            list.push({
                id: "pane_2",
                x: secondaryContainer.x,
                y: secondaryContainer.y,
                width: secondaryContainer.width,
                height: secondaryContainer.height
            })
        }
        return list
    }

    // 1. Управление камерой холста (Панорамирование средней кнопкой или Drag по фону)
    MouseArea {
        id: canvasBackgroundDrag
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton | Qt.RightButton
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor

        property real lastMouseX: 0
        property real lastMouseY: 0

        onPressed: (mouse) => {
            lastMouseX = mouse.x
            lastMouseY = mouse.y
        }

        onPositionChanged: (mouse) => {
            if (pressed) {
                var dx = mouse.x - lastMouseX
                var dy = mouse.y - lastMouseY
                canvasWorkspaceRoot.panX += dx
                canvasWorkspaceRoot.panY += dy
                lastMouseX = mouse.x
                lastMouseY = mouse.y
            }
        }
    }

    // Зум холста колесом мыши
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            if (event.modifiers & Qt.ControlModifier) {
                var oldZoom = canvasWorkspaceRoot.zoomScale
                var factor = event.angleDelta.y > 0 ? 1.1 : 0.9
                var newZoom = Math.max(0.3, Math.min(2.5, oldZoom * factor))
                canvasWorkspaceRoot.zoomScale = newZoom
                event.accepted = true
            } else if (event.buttons & Qt.MiddleButton) {
                canvasWorkspaceRoot.panY += event.angleDelta.y
                canvasWorkspaceRoot.panX += event.angleDelta.x
                event.accepted = true
            }
        }
    }

    // 2. Виртуальный слой мира (подвержен panX, panY, zoomScale)
    Item {
        id: worldLayer
        x: canvasWorkspaceRoot.width / 2 + canvasWorkspaceRoot.panX
        y: canvasWorkspaceRoot.height / 2 + canvasWorkspaceRoot.panY
        scale: canvasWorkspaceRoot.zoomScale
        transformOrigin: Item.Center

        // Фоновая сетка холста (деликатные точки)
        Canvas {
            id: gridCanvas
            anchors.centerIn: parent
            width: 8000
            height: 8000
            opacity: 0.18
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.fillStyle = Theme.borderHover
                var step = 32
                for (var gx = 0; gx < width; gx += step) {
                    for (var gy = 0; gy < height; gy += step) {
                        ctx.fillRect(gx, gy, 1.5, 1.5)
                    }
                }
            }
        }

        // =====================================================================
        // ПАНЕЛЬ 1 (Основной лист)
        // =====================================================================
        CanvasPaneContainer {
            id: primaryContainer
            paneId: "pane_1"
            x: -420
            y: -360
            width: 800
            height: 720
            otherPanesProvider: (id) => canvasWorkspaceRoot.getOtherPanes(id)

            onSnapMoved: (guidelines, dockSide, dockTargetId) => {
                snapGuideOverlay.activeGuides = guidelines || []
            }
            onSnapEnded: {
                snapGuideOverlay.activeGuides = []
            }
            onPaneActivated: {
                canvasWorkspaceRoot.activePaneIndex = 0
            }
        }

        // =====================================================================
        // ПАНЕЛЬ 2 (Вторичный лист)
        // =====================================================================
        CanvasPaneContainer {
            id: secondaryContainer
            paneId: "pane_2"
            x: 420
            y: -360
            width: 800
            height: 720
            otherPanesProvider: (id) => canvasWorkspaceRoot.getOtherPanes(id)

            onSnapMoved: (guidelines, dockSide, dockTargetId) => {
                snapGuideOverlay.activeGuides = guidelines || []
            }
            onSnapEnded: {
                snapGuideOverlay.activeGuides = []
            }
            onPaneActivated: {
                canvasWorkspaceRoot.activePaneIndex = 1
            }
        }

        // Оверлей линий магнита
        SnapGuideOverlay {
            id: snapGuideOverlay
        }
    }
}
