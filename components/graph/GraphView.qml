import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../js/graph_physics.js" as Physics
import "../../js/graph_renderer.js" as Renderer

Rectangle {
    id: graphRoot
    anchors.fill: parent
    color: (graphConfig && graphConfig.visual && graphConfig.visual.backgroundColor) ? graphConfig.visual.backgroundColor : "#141414"
    clip: true

    property string folderUrl: ""
    property var sim: null
    property real zoomScale: 1.0
    property real panX: 0
    property real panY: 0
    property string searchQuery: ""

    property var graphConfig: ({})
    property var hoveredNode: null
    property var draggedNode: null
    property var highlightedNodeIds: ({})

    signal nodeClicked(string fileUrl, string label, string nodeType)
    signal closeRequested()

    function reloadGraph() {
        if (typeof backend === "undefined" || !backend || typeof backend.get_graph_data !== "function") return
        var data = backend.get_graph_data(graphRoot.folderUrl)
        if (!data || !data.nodes) return

        var config = {}
        if (typeof backend.get_graph_config === "function") {
            try {
                config = JSON.parse(JSON.stringify(backend.get_graph_config(graphRoot.folderUrl) || {}))
            } catch (e) {
                config = {}
            }
        }
        graphRoot.graphConfig = config

        // Преобразуем QVariant из Python в чистые нативные объекты JS,
        // иначе мутации координат (x, y) при перетаскивании не сохраняются в памяти JS!
        var pureNodes = JSON.parse(JSON.stringify(data.nodes))
        var pureLinks = JSON.parse(JSON.stringify(data.links || []))

        sim = Physics.initSimulation(pureNodes, pureLinks, canvas.width || 800, canvas.height || 600, config)
        wakeSimulation()
    }

    function wakeSimulation() {
        if (sim) {
            sim.isSleeping = false
            sim.totalEnergy = 15
            animTimer.running = true
            canvas.requestPaint()
        }
    }

    function resetView() {
        zoomScale = 1.0
        panX = 0
        panY = 0
        if (sim && sim.links) {
            for (var i = 0; i < sim.links.length; i++) {
                sim.links[i].distance = sim.links[i].baseDistance || 85
            }
        }
        wakeSimulation()
    }

    Component.onCompleted: {
        reloadGraph()
    }

    Connections {
        target: (typeof backend !== "undefined") ? backend : null
        function onGraphDataChanged() {
            graphRoot.reloadGraph()
        }
        function onFolderFilesChanged() {
            graphRoot.reloadGraph()
        }
    }

    onWidthChanged: if (sim) { sim.width = width; wakeSimulation(); }
    onHeightChanged: if (sim) { sim.height = height; wakeSimulation(); }

    Timer {
        id: animTimer
        interval: 16
        repeat: true
        running: false
        onTriggered: {
            if (!sim) {
                running = false
                return
            }
            var active = Physics.stepSimulation(sim)
            canvas.requestPaint()
            if (!active && !draggedNode) {
                running = false
            }
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            Renderer.renderGraph(ctx, width, height, graphRoot.sim, {
                panX: graphRoot.panX,
                panY: graphRoot.panY,
                zoomScale: graphRoot.zoomScale,
                hoveredNode: graphRoot.hoveredNode,
                draggedNode: graphRoot.draggedNode,
                highlightedNodeIds: graphRoot.highlightedNodeIds,
                searchQuery: graphRoot.searchQuery,
                graphConfig: graphRoot.graphConfig
            })
        }
    }

    // Интерактивное управление через MouseArea
    MouseArea {
        id: graphMouse
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property real lastMouseX: 0
        property real lastMouseY: 0
        property bool isPanning: false
        property real dragStartX: 0
        property real dragStartY: 0
        property real dragOffsetX: 0
        property real dragOffsetY: 0

        function toWorldX(screenX) {
            return Renderer.toWorldX(screenX, width, graphRoot.panX, graphRoot.zoomScale)
        }

        function toWorldY(screenY) {
            return Renderer.toWorldY(screenY, height, graphRoot.panY, graphRoot.zoomScale)
        }

        function findNodeAtScreen(screenX, screenY) {
            return Renderer.findNodeAtScreen(graphRoot.sim, screenX, screenY, width, height, graphRoot.zoomScale, graphRoot.panX, graphRoot.panY)
        }

        onWheel: (wheel) => {
            var factor = wheel.angleDelta.y > 0 ? 1.15 : 0.87
            var newZoom = Math.max(0.25, Math.min(3.5, graphRoot.zoomScale * factor))
            graphRoot.zoomScale = newZoom
            graphRoot.wakeSimulation()
        }

        onPositionChanged: (mouse) => {
            if (graphRoot.draggedNode) {
                var wx = toWorldX(mouse.x)
                var wy = toWorldY(mouse.y)
                graphRoot.draggedNode.x = wx + dragOffsetX
                graphRoot.draggedNode.y = wy + dragOffsetY
                graphRoot.draggedNode.vx = 0
                graphRoot.draggedNode.vy = 0
                if (graphRoot.sim) {
                    graphRoot.sim.isSleeping = false
                    graphRoot.sim.totalEnergy = 15
                }
                animTimer.running = true
                canvas.requestPaint()
                cursorShape = Qt.ClosedHandCursor
                return
            }

            if (isPanning) {
                graphRoot.panX += (mouse.x - lastMouseX)
                graphRoot.panY += (mouse.y - lastMouseY)
                lastMouseX = mouse.x
                lastMouseY = mouse.y
                canvas.requestPaint()
                cursorShape = Qt.ClosedHandCursor
                return
            }

            // Определение узла под курсором (Hover)
            var node = findNodeAtScreen(mouse.x, mouse.y)

            if (node !== graphRoot.hoveredNode) {
                graphRoot.hoveredNode = node
                var map = {}
                if (node && graphRoot.sim && graphRoot.sim.links) {
                    map[node.id] = true
                    for (var i = 0; i < graphRoot.sim.links.length; i++) {
                        var l = graphRoot.sim.links[i]
                        if (l.source.id === node.id) map[l.target.id] = true
                        if (l.target.id === node.id) map[l.source.id] = true
                    }
                }
                graphRoot.highlightedNodeIds = map
                canvas.requestPaint()
            }

            cursorShape = (node ? Qt.OpenHandCursor : Qt.ArrowCursor)
        }

        onPressed: (mouse) => {
            lastMouseX = mouse.x
            lastMouseY = mouse.y
            dragStartX = mouse.x
            dragStartY = mouse.y

            var node = findNodeAtScreen(mouse.x, mouse.y)

            if (node && mouse.button === Qt.LeftButton) {
                graphRoot.draggedNode = node
                node.isFixed = true
                node.isDragging = true
                isPanning = false
                var wx = toWorldX(mouse.x)
                var wy = toWorldY(mouse.y)
                dragOffsetX = node.x - wx
                dragOffsetY = node.y - wy
                cursorShape = Qt.ClosedHandCursor
                graphRoot.wakeSimulation()
            } else {
                graphRoot.draggedNode = null
                isPanning = true
                cursorShape = Qt.ClosedHandCursor
            }
        }

        onReleased: (mouse) => {
            var movedDist = Math.hypot(mouse.x - dragStartX, mouse.y - dragStartY)
            var wasDraggingNode = (graphRoot.draggedNode !== null)
            var nodeRef = graphRoot.draggedNode

            if (wasDraggingNode) {
                // Узел остается полностью динамическим!
                nodeRef.isFixed = false
                nodeRef.isDragging = false
                graphRoot.draggedNode = null
                if (graphRoot.sim) {
                    graphRoot.sim.isSleeping = false
                    graphRoot.sim.totalEnergy = 35
                }
                animTimer.running = true
                canvas.requestPaint()
            }

            if (isPanning) {
                isPanning = false
            }

            cursorShape = Qt.ArrowCursor

            // Если это был клик (смещение < 4px) — переходим к заметке
            if (movedDist < 4 && wasDraggingNode && nodeRef) {
                if (nodeRef.fileUrl) {
                    graphRoot.nodeClicked(nodeRef.fileUrl, nodeRef.label, nodeRef.type)
                }
            }
        }
    }

    // Лаконичная темно-серая мини-панель управления в правом верхнем углу
    Rectangle {
        id: miniControls
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 12
        height: 28
        radius: 6
        color: "#1a1a1a"
        border.color: "#282828"
        border.width: 1
        z: 100

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 6

            Text {
                text: "🔍"
                font.pixelSize: 10
                color: "#555555"
            }

            TextInput {
                id: searchInput
                width: 100
                color: "#cccccc"
                font.pixelSize: 11
                selectByMouse: true
                clip: true
                onTextChanged: {
                    graphRoot.searchQuery = text.trim().toLowerCase()
                    canvas.requestPaint()
                }

                Text {
                    anchors.fill: parent
                    text: "Поиск..."
                    color: "#444444"
                    font.pixelSize: 11
                    visible: !searchInput.text && !searchInput.activeFocus
                }
            }

            Rectangle {
                width: 1
                height: 14
                color: "#282828"
            }

            // Кнопка центрирования
            Rectangle {
                width: 20
                height: 20
                radius: 4
                color: centerHover.hovered ? "#262626" : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "⊙"
                    color: centerHover.hovered ? "#ffffff" : "#777777"
                    font.pixelSize: 12
                }
                HoverHandler { id: centerHover }
                TapHandler { onTapped: graphRoot.resetView() }
            }

            // Кнопка закрытия графа
            Rectangle {
                width: 20
                height: 20
                radius: 4
                color: closeHover.hovered ? "#262626" : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: closeHover.hovered ? "#ffffff" : "#777777"
                    font.pixelSize: 11
                }
                HoverHandler { id: closeHover }
                TapHandler { onTapped: graphRoot.closeRequested() }
            }
        }
    }
}
