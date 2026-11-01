import QtQuick
import "../theme"

Rectangle {
    id: canvasWorkspaceRoot
    color: Theme.bgApp
    clip: true
    property real panX: 0
    property real panY: 0
    property real zoomScale: 1
    property real savedZoomScale: 1
    property real savedPanX: 0
    property real savedPanY: 0
    property bool isTileFocusActive: false
    property bool isSpacePanning: false

    ParallelAnimation {
        id: cameraAnim
        NumberAnimation { id: camZoomAnim; target: canvasWorkspaceRoot; property: "zoomScale"; duration: Theme.animDurationNormal; easing.type: Easing.OutCubic }
        NumberAnimation { id: camPanXAnim; target: canvasWorkspaceRoot; property: "panX"; duration: Theme.animDurationNormal; easing.type: Easing.OutCubic }
        NumberAnimation { id: camPanYAnim; target: canvasWorkspaceRoot; property: "panY"; duration: Theme.animDurationNormal; easing.type: Easing.OutCubic }
    }
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
    readonly property bool isMetroVisible: activePane ? activePane.isMetroMode : false
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
        if (panel && panel.pane && panel.pane.fileUrl) {
            if (typeof backend !== "undefined" && backend && typeof backend.save_last_file === "function") {
                backend.save_last_file(panel.pane.fileUrl)
            }
        }
        if (panel.pane.isGraphMode) {
            if (panel.pane.paneGraphView) panel.pane.paneGraphView.forceActiveFocus()
        } else if (panel.pane.isMetroMode) {
            if (panel.pane.paneMetroView) panel.pane.paneMetroView.forceActiveFocus()
        } else {
            if (panel.pane.editorArea) panel.pane.editorArea.forceActiveFocus()
        }
    }
    function removePanel(panel) {
        var index = panels.indexOf(panel)
        panels = panels.filter(function(item) { return item !== panel })
        var hasOtherTiled = panels.some(function(p) { return p.tileState !== "none" })
        if (!hasOtherTiled) exitTileFocus()
        if (activePanel === panel) {
            activePanel = null
            if (panels.length) activate(panels[Math.min(index, panels.length - 1)], true)
        }
        panel.destroy()
    }
    function enterTileFocus() {
        if (!isTileFocusActive) {
            savedZoomScale = canvasWorkspaceRoot.zoomScale
            savedPanX = canvasWorkspaceRoot.panX
            savedPanY = canvasWorkspaceRoot.panY
            isTileFocusActive = true
        }
        if (Math.abs(canvasWorkspaceRoot.zoomScale - 1.0) > 0.001) {
            camZoomAnim.to = 1.0
            camPanXAnim.to = canvasWorkspaceRoot.panX
            camPanYAnim.to = canvasWorkspaceRoot.panY
            cameraAnim.start()
        }
    }
    function exitTileFocus() {
        if (!isTileFocusActive) return
        if (Math.abs(savedZoomScale - 1.0) > 0.001) {
            camZoomAnim.to = savedZoomScale
            camPanXAnim.to = savedPanX
            camPanYAnim.to = savedPanY
            cameraAnim.start()
        }
        isTileFocusActive = false
    }
    function getViewportRect() {
        var scale = isTileFocusActive ? 1.0 : (canvasWorkspaceRoot.zoomScale || 1.0)
        var px = (isTileFocusActive && camPanXAnim.running) ? camPanXAnim.to : canvasWorkspaceRoot.panX
        var py = (isTileFocusActive && camPanYAnim.running) ? camPanYAnim.to : canvasWorkspaceRoot.panY
        var originX = canvasWorkspaceRoot.width / 2 + px
        var originY = canvasWorkspaceRoot.height / 2 + py
        var vx = (0 - originX) / scale
        var vy = (0 - originY) / scale
        var vw = canvasWorkspaceRoot.width / scale
        var vh = canvasWorkspaceRoot.height / scale
        return { x: vx, y: vy, width: vw, height: vh }
    }
    function getOtherPanes(id) {
        var vp = getViewportRect()
        var list = panels.filter(function(p) { return p.paneId !== id }).map(function(p) {
            return {id: p.paneId, x: p.x, y: p.y, width: p.width, height: p.height}
        })
        list.push({id: "__viewport__", x: vp.x, y: vp.y, width: vp.width, height: vp.height})
        return list
    }
    function tileMaximize() {
        if (!activePanel) return
        enterTileFocus()
        var vp = getViewportRect()
        if (activePanel.tileState === "none") {
            activePanel.floatingBounds = {
                x: activePanel.x,
                y: activePanel.y,
                width: activePanel.width,
                height: activePanel.height
            }
        }
        activePanel.tileState = "full"
        activePanel.setBoundsAnimated(vp.x, vp.y, vp.width, vp.height)
    }
    function tileLeft() {
        if (!activePanel) return
        enterTileFocus()
        var vp = getViewportRect()
        if (activePanel.tileState === "none") {
            activePanel.floatingBounds = {
                x: activePanel.x,
                y: activePanel.y,
                width: activePanel.width,
                height: activePanel.height
            }
        }
        activePanel.tileState = "left"
        activePanel.setBoundsAnimated(vp.x, vp.y, vp.width / 2, vp.height)
    }
    function tileRight() {
        if (!activePanel) return
        enterTileFocus()
        var vp = getViewportRect()
        if (activePanel.tileState === "none") {
            activePanel.floatingBounds = {
                x: activePanel.x,
                y: activePanel.y,
                width: activePanel.width,
                height: activePanel.height
            }
        }
        activePanel.tileState = "right"
        activePanel.setBoundsAnimated(vp.x + vp.width / 2, vp.y, vp.width / 2, vp.height)
    }
    function tileRestore() {
        if (!activePanel) return
        var fb = activePanel.floatingBounds
        activePanel.tileState = "none"
        activePanel.floatingBounds = null

        var hasOtherTiled = panels.some(function(p) { return p !== activePanel && p.tileState !== "none" })
        if (!hasOtherTiled) {
            exitTileFocus()
        }

        if (fb) {
            activePanel.setBoundsAnimated(fb.x, fb.y, fb.width, fb.height)
        } else {
            var vp = getViewportRect()
            activePanel.setBoundsAnimated(vp.x + (vp.width - Theme.canvasPanelWidth) / 2,
                                         vp.y + (vp.height - Theme.canvasPanelHeight) / 2,
                                         Theme.canvasPanelWidth, Theme.canvasPanelHeight)
        }
    }
    function tileActivePanel() {
        if (!activePanel) return
        var curState = activePanel.tileState || "none"
        if (curState === "none") {
            tileMaximize()
        } else if (curState === "full") {
            tileLeft()
        } else if (curState === "left") {
            tileRight()
        } else {
            tileRestore()
        }
    }
    function tileWorkspace() {
        if (!panels || panels.length === 0) return
        var allTiled = panels.every(function(p) { return p.tileState === "workspace" })

        if (allTiled) {
            exitTileFocus()
            panels.forEach(function(p) {
                p.tileState = "none"
                if (p.floatingBounds) {
                    var fb = p.floatingBounds
                    p.setBoundsAnimated(fb.x, fb.y, fb.width, fb.height)
                    p.floatingBounds = null
                }
            })
            return
        }

        enterTileFocus()
        var vp = getViewportRect()
        var count = panels.length
        var colW = vp.width / count
        for (var i = 0; i < count; i++) {
            var p = panels[i]
            if (p.tileState === "none") {
                p.floatingBounds = { x: p.x, y: p.y, width: p.width, height: p.height }
            }
            p.tileState = "workspace"
            p.setBoundsAnimated(vp.x + i * colW, vp.y, colW, vp.height)
        }
    }
    function toggleGraph(local) {
        if (!activePane) return
        if (activePane.isGraphMode && activePane.isLocalGraphMode === Boolean(local)) {
            activePane.isGraphMode = false
            if (activePane.editorArea) activePane.editorArea.forceActiveFocus()
        } else {
            activePane.isMetroMode = false
            activePane.isLocalGraphMode = Boolean(local)
            activePane.isGraphMode = true
            if (activePane.paneGraphView) activePane.paneGraphView.forceActiveFocus()
        }
    }
    function toggleMetro() {
        if (!activePane) return
        if (activePane.isMetroMode) {
            activePane.isMetroMode = false
            if (activePane.editorArea) activePane.editorArea.forceActiveFocus()
        } else {
            activePane.isGraphMode = false
            activePane.isMetroMode = true
            if (activePane.paneMetroView) activePane.paneMetroView.forceActiveFocus()
        }
    }
    function closeGraph() {
        if (activePane) {
            activePane.isGraphMode = false
            activePane.isMetroMode = false
            if (activePane.editorArea) activePane.editorArea.forceActiveFocus()
        }
    }
    function navigatePanel(panel, url, title, block) {
        return Documents.navigatePanel(canvasWorkspaceRoot, backend, panel, url, title, block)
    }
    function centerActive(animated) {
        if (!activePanel) {
            if (animated) {
                camPanXAnim.to = 0; camPanXAnim.restart()
                camPanYAnim.to = 0; camPanYAnim.restart()
            } else {
                canvasWorkspaceRoot.panX = 0
                canvasWorkspaceRoot.panY = 0
            }
            return
        }
        var cx = activePanel.x + activePanel.width / 2
        var cy = activePanel.y + activePanel.height / 2
        if (animated) {
            camPanXAnim.to = -cx; camPanXAnim.restart()
            camPanYAnim.to = -cy; camPanYAnim.restart()
        } else {
            canvasWorkspaceRoot.panX = -cx
            canvasWorkspaceRoot.panY = -cy
        }
    }
    function applyConfig(config) { panels.forEach(function(p) { p.pane.applyConfig(config) }) }
    function applySessionConfig(sess) {
        panels.forEach(function(p) {
            if (p.pane && typeof p.pane.applySessionConfig === "function") p.pane.applySessionConfig(sess)
        })
    }
    function applyBlockUpdate(name, text, source) {
        panels.forEach(function(p) {
            if (p.pane.fileUrl !== source && !p.pane.editorArea.readOnly)
                p.pane.applyExternalBlockUpdate(name, text)
        })
    }

    // 1. Управление камерой холста (Панорамирование ЛКМ по свободному фону, средней кнопкой или правой кнопкой)
    MouseArea {
        id: canvasBackgroundDrag
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: pressed ? Qt.ClosedHandCursor : (canvasWorkspaceRoot.isSpacePanning ? Qt.OpenHandCursor : Qt.ArrowCursor)

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

    // 1.1 Режим «Рука» (Space + Drag): глобальный прозрачный оверлей панорамирования поверх всех панелей
    MouseArea {
        id: spacePanOverlay
        anchors.fill: parent
        z: canvasWorkspaceRoot.nextZ + 1000
        visible: canvasWorkspaceRoot.isSpacePanning
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

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
                if (canvasWorkspaceRoot.isTileFocusActive) canvasWorkspaceRoot.isTileFocusActive = false
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
            var half = dotSize / 2

            // Пакетная быстрая отрисовка всех точек единым графическим вызовом (Batch Draw)
            ctx.beginPath()
            for (var x = offsetX; x < width; x += step) {
                for (var y = offsetY; y < height; y += step) {
                    ctx.rect(x - half, y - half, dotSize, dotSize)
                }
            }
            ctx.fill()
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
            onTileCancelled: {
                var hasOtherTiled = canvasWorkspaceRoot.panels.some(function(p) { return p.tileState !== "none" })
                if (!hasOtherTiled) canvasWorkspaceRoot.exitTileFocus()
            }
        }
    }
}
