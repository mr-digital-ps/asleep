import QtQuick
import "../theme"

Rectangle {
    id: canvasWorkspaceRoot
    color: Theme.bgApp
    clip: true
    property real panX: 0
    property real panY: 0
    property real zoomScale: 1
    property var panels: []
    property var activePanel: null
    property int nextId: 0
    property int nextZ: 1
    property string errorMessage: ""
    property string currentFolderUrl: ""
    property string currentFolderName: ""
    readonly property int panelCount: panels.length
    readonly property var activePane: activePanel ? activePanel.pane : null
    readonly property var activeEditorArea: activePane ? activePane.editorArea : null
    readonly property bool isGraphVisible: activePane ? activePane.isGraphMode : false
    readonly property var openFileUrls: panels.map(function(panel) { return panel.pane.fileUrl })
    signal actionRequested(string action)
    signal closeRequested(var panel)
    signal renameRequested(var panel, string title)
    signal contentChanged()

    function addDocument(url, title, text) {
        var x = activePanel ? activePanel.x + activePanel.width + Theme.canvasPanelGap : -Theme.canvasPanelWidth / 2
        var y = activePanel ? activePanel.y : -Theme.canvasPanelHeight / 2
        var panel = panelComponent.createObject(worldLayer, {
            paneId: "document_" + (++nextId), x: x, y: y,
            width: Theme.canvasPanelWidth, height: Theme.canvasPanelHeight,
            savedText: text
        })
        if (!panel) { errorMessage = "Не удалось создать панель"; return null }
        panel.pane.openDocument(url, title, text)
        panels = panels.concat([panel])
        activate(panel, true)
        return panel
    }
    function activate(panel, reveal) {
        if (!panel) return
        activePanel = panel
        panel.z = ++nextZ
        panel.pane.editorArea.forceActiveFocus()
    }
    function removePanel(panel) {
        var index = panels.indexOf(panel)
        panels = panels.filter(function(item) { return item !== panel })
        if (activePanel === panel) {
            activePanel = null
            if (panels.length) activate(panels[Math.min(index, panels.length - 1)], true)
        }
        panel.destroy()
    }
    function getOtherPanes(id) {
        return panels.filter(function(p) { return p.paneId !== id }).map(function(p) {
            return {id: p.paneId, x: p.x, y: p.y, width: p.width, height: p.height}
        })
    }
    function toggleGraph(local) {
        if (!activePane) return
        if (activePane.isGraphMode && activePane.isLocalGraphMode === Boolean(local)) {
            activePane.isGraphMode = false
        } else {
            activePane.isLocalGraphMode = Boolean(local)
            activePane.isGraphMode = true
        }
    }
    function closeGraph() { if (activePane) activePane.isGraphMode = false }
    function centerActive() { activate(activePanel, true) }
    function applyConfig(config) { panels.forEach(function(p) { p.pane.applyConfig(config) }) }
    function applyBlockUpdate(name, text, source) {
        panels.forEach(function(p) {
            if (p.pane.fileUrl !== source && !p.pane.editorArea.readOnly)
                p.pane.applyExternalBlockUpdate(name, text)
        })
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
                var factor = event.angleDelta.y > 0 ? Theme.canvasZoomStep : 1 / Theme.canvasZoomStep
                var newZoom = Math.max(Theme.canvasMinZoom, Math.min(Theme.canvasMaxZoom, oldZoom * factor))
                canvasWorkspaceRoot.zoomScale = newZoom
                event.accepted = true
            } else if (event.buttons & Qt.MiddleButton) {
                canvasWorkspaceRoot.panY += event.angleDelta.y
                canvasWorkspaceRoot.panX += event.angleDelta.x
                event.accepted = true
            }
        }
    }

    // Фоновая сетка холста: точечная матрица (Dot Grid), привязанная к координатам мира
    Canvas {
        id: gridCanvas
        anchors.fill: parent
        z: 0

        Connections {
            target: canvasWorkspaceRoot
            function onPanXChanged() { gridCanvas.requestPaint() }
            function onPanYChanged() { gridCanvas.requestPaint() }
            function onZoomScaleChanged() { gridCanvas.requestPaint() }
            function onWidthChanged() { gridCanvas.requestPaint() }
            function onHeightChanged() { gridCanvas.requestPaint() }
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var step = Theme.canvasGridStep * canvasWorkspaceRoot.zoomScale
            if (step < 12) return // Слишком мелкий шаг при сильном удалении

            // Смещение с учётом panX, panY и центра окна
            var offsetX = (width / 2 + canvasWorkspaceRoot.panX) % step
            if (offsetX < 0) offsetX += step
            var offsetY = (height / 2 + canvasWorkspaceRoot.panY) % step
            if (offsetY < 0) offsetY += step

            ctx.fillStyle = Theme.borderHover
            var dotSize = Math.max(1.8, Math.min(3.5, 2.2 * canvasWorkspaceRoot.zoomScale))

            for (var x = offsetX; x < width; x += step) {
                for (var y = offsetY; y < height; y += step) {
                    ctx.beginPath()
                    ctx.arc(x, y, dotSize / 2, 0, Math.PI * 2)
                    ctx.fill()
                }
            }
        }
    }

    Item {
        id: worldLayer
        x: canvasWorkspaceRoot.width / 2 + canvasWorkspaceRoot.panX
        y: canvasWorkspaceRoot.height / 2 + canvasWorkspaceRoot.panY
        scale: canvasWorkspaceRoot.zoomScale
        transformOrigin: Item.TopLeft
        z: 1
        SnapGuideOverlay { id: snapGuideOverlay; z: canvasWorkspaceRoot.nextZ + 1 }
    }
    Component {
        id: panelComponent
        CanvasPaneContainer {
            id: documentPanel
            otherPanesProvider: (id) => canvasWorkspaceRoot.getOtherPanes(id)
            pane.folderUrl: canvasWorkspaceRoot.currentFolderUrl
            pane.currentFolderName: canvasWorkspaceRoot.currentFolderName
            pane.openFileUrls: canvasWorkspaceRoot.openFileUrls
            pane.isActivePane: canvasWorkspaceRoot.activePanel === documentPanel
            onPaneActivated: canvasWorkspaceRoot.activate(documentPanel, false)
            onCloseRequested: canvasWorkspaceRoot.closeRequested(documentPanel)
            onActionRequested: (action) => {
                canvasWorkspaceRoot.activate(documentPanel, false)
                canvasWorkspaceRoot.actionRequested(action)
            }
            onRenameRequested: (title) => canvasWorkspaceRoot.renameRequested(documentPanel, title)
            onContentChanged: canvasWorkspaceRoot.contentChanged()
            onSnapMoved: (guidelines) => snapGuideOverlay.activeGuides = guidelines || []
            onSnapEnded: snapGuideOverlay.activeGuides = []
        }
    }
}
