import QtQuick
import QtQuick.Controls
import "../../js/graph_physics.js" as Physics

Rectangle {
    id: graphRoot
    anchors.fill: parent
    color: "#121217"
    clip: true

    property string folderUrl: ""
    property var sim: null
    property real zoomScale: 1.0
    property real panX: 0
    property real panY: 0

    property var hoveredNode: null
    property var draggedNode: null
    property var highlightedNodeIds: ({})

    signal nodeClicked(string fileUrl, string label, string nodeType)
    signal closeRequested()

    function reloadGraph() {
        if (typeof backend === "undefined" || !backend || typeof backend.get_graph_data !== "function") return
        var data = backend.get_graph_data(graphRoot.folderUrl)
        if (!data || !data.nodes) return

        sim = Physics.initSimulation(data.nodes, data.links || [], canvas.width || 800, canvas.height || 600, {
            repulsion: controls.repulsion,
            linkDistance: controls.linkDistance
        })
        wakeSimulation()
    }

    function wakeSimulation() {
        if (sim) {
            sim.isSleeping = false
            animTimer.running = true
            canvas.requestPaint()
        }
    }

    function resetView() {
        zoomScale = 1.0
        panX = 0
        panY = 0
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
            ctx.clearRect(0, 0, width, height)

            ctx.save()
            ctx.translate(width / 2 + graphRoot.panX, height / 2 + graphRoot.panY)
            ctx.scale(graphRoot.zoomScale, graphRoot.zoomScale)
            ctx.translate(-width / 2, -height / 2)

            if (!sim || !sim.nodes) {
                ctx.restore()
                return
            }

            var nodes = sim.nodes
            var links = sim.links
            var hasHover = (hoveredNode !== null)
            var searchQuery = controls.searchQuery

            // 1. Отрисовка связей (Линии)
            for (var i = 0; i < links.length; i++) {
                var l = links[i]
                var s = l.source
                var t = l.target
                if (!s || !t) continue

                var isConnectedToHover = hasHover && (s.id === hoveredNode.id || t.id === hoveredNode.id)
                var alpha = hasHover ? (isConnectedToHover ? 0.9 : 0.08) : 0.35

                ctx.beginPath()
                ctx.moveTo(s.x, s.y)
                ctx.lineTo(t.x, t.y)

                if (l.type === "transclusion") {
                    ctx.strokeStyle = "rgba(187, 154, 247, " + alpha + ")"
                    ctx.lineWidth = isConnectedToHover ? 2.5 : 1.5
                } else if (l.type === "tag") {
                    ctx.strokeStyle = "rgba(224, 175, 104, " + alpha + ")"
                    ctx.lineWidth = isConnectedToHover ? 2.0 : 1.2
                } else {
                    ctx.strokeStyle = "rgba(77, 166, 255, " + alpha + ")"
                    ctx.lineWidth = isConnectedToHover ? 2.0 : 1.0
                }
                ctx.stroke()
            }

            // 2. Отрисовка узлов (Круги и свечение)
            for (var j = 0; j < nodes.length; j++) {
                var n = nodes[j]
                var isHover = (hoveredNode && hoveredNode.id === n.id)
                var isConnected = highlightedNodeIds[n.id] === true
                var matchesSearch = (!searchQuery || (n.label && n.label.toLowerCase().indexOf(searchQuery) !== -1))

                var nodeAlpha = 1.0
                if (searchQuery && !matchesSearch) {
                    nodeAlpha = 0.15
                } else if (hasHover && !isHover && !isConnected) {
                    nodeAlpha = 0.2
                }

                ctx.save()
                ctx.globalAlpha = nodeAlpha

                // Свечение активного/выбранного узла
                if (isHover || isConnected) {
                    ctx.beginPath()
                    ctx.arc(n.x, n.y, (n.radius || 8) + 6, 0, 2 * Math.PI)
                    ctx.fillStyle = n.color || "#4da6ff"
                    ctx.globalAlpha = 0.25
                    ctx.fill()
                    ctx.globalAlpha = nodeAlpha
                }

                // Тело узла
                ctx.beginPath()
                ctx.arc(n.x, n.y, n.radius || 8, 0, 2 * Math.PI)
                ctx.fillStyle = n.color || "#4da6ff"
                ctx.fill()
                ctx.lineWidth = isHover ? 2.5 : 1.2
                ctx.strokeStyle = isHover ? "#ffffff" : "#1a1a24"
                ctx.stroke()

                // Текстовая подпись
                var shouldDrawLabel = controls.showLabels || isHover || isConnected || (searchQuery && matchesSearch)
                if (shouldDrawLabel && nodeAlpha > 0.3) {
                    ctx.font = (isHover ? "bold 12px sans-serif" : "11px sans-serif")
                    ctx.fillStyle = isHover ? "#ffffff" : (isConnected ? "#c0caf5" : "#a9b1d6")
                    ctx.textAlign = "center"
                    ctx.fillText(n.label || "", n.x, n.y + (n.radius || 8) + 14)
                }

                ctx.restore()
            }

            ctx.restore()
        }
    }

    // Интерактивное управление через MouseArea
    MouseArea {
        id: graphMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property real lastMouseX: 0
        property real lastMouseY: 0
        property bool isPanning: false
        property real dragStartX: 0
        property real dragStartY: 0

        function toWorldX(screenX) {
            return (screenX - (width / 2 + graphRoot.panX)) / graphRoot.zoomScale + width / 2
        }

        function toWorldY(screenY) {
            return (screenY - (height / 2 + graphRoot.panY)) / graphRoot.zoomScale + height / 2
        }

        onWheel: (wheel) => {
            var factor = wheel.angleDelta.y > 0 ? 1.15 : 0.87
            var newZoom = Math.max(0.2, Math.min(4.0, graphRoot.zoomScale * factor))
            graphRoot.zoomScale = newZoom
            graphRoot.wakeSimulation()
        }

        onPositionChanged: (mouse) => {
            if (isPanning) {
                graphRoot.panX += (mouse.x - lastMouseX)
                graphRoot.panY += (mouse.y - lastMouseY)
                lastMouseX = mouse.x
                lastMouseY = mouse.y
                canvas.requestPaint()
                return
            }

            if (graphRoot.draggedNode) {
                var wx = toWorldX(mouse.x)
                var wy = toWorldY(mouse.y)
                graphRoot.draggedNode.x = wx
                graphRoot.draggedNode.y = wy
                graphRoot.draggedNode.vx = 0
                graphRoot.draggedNode.vy = 0
                graphRoot.wakeSimulation()
                return
            }

            // Определение узла под курсором (Hover)
            var curWx = toWorldX(mouse.x)
            var curWy = toWorldY(mouse.y)
            var node = Physics.findNodeAt(graphRoot.sim, curWx, curWy, 6)

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

            cursorShape = (node ? Qt.PointingHandCursor : (isPanning ? Qt.ClosedHandCursor : Qt.ArrowCursor))
        }

        onPressed: (mouse) => {
            lastMouseX = mouse.x
            lastMouseY = mouse.y
            dragStartX = mouse.x
            dragStartY = mouse.y

            var wx = toWorldX(mouse.x)
            var wy = toWorldY(mouse.y)
            var node = Physics.findNodeAt(graphRoot.sim, wx, wy, 8)

            if (node && mouse.button === Qt.LeftButton) {
                graphRoot.draggedNode = node
                node.isFixed = true
                graphRoot.wakeSimulation()
            } else {
                isPanning = true
                cursorShape = Qt.ClosedHandCursor
            }
        }

        onReleased: (mouse) => {
            if (graphRoot.draggedNode) {
                graphRoot.draggedNode.isFixed = false
                graphRoot.draggedNode = null
                graphRoot.wakeSimulation()
            }
            if (isPanning) {
                isPanning = false
                cursorShape = Qt.ArrowCursor
            }

            // Обработка одиночного клика без смещения (открытие документа)
            var movedDist = Math.hypot(mouse.x - dragStartX, mouse.y - dragStartY)
            if (movedDist < 5) {
                var wx = toWorldX(mouse.x)
                var wy = toWorldY(mouse.y)
                var clickedNode = Physics.findNodeAt(graphRoot.sim, wx, wy, 8)
                if (clickedNode && clickedNode.fileUrl) {
                    graphRoot.nodeClicked(clickedNode.fileUrl, clickedNode.label, clickedNode.type)
                }
            }
        }
    }

    // Парящая панель управления графом (HUD)
    GraphControls {
        id: controls
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 16
        z: 100

        onResetViewRequested: graphRoot.resetView()
        onCloseRequested: graphRoot.closeRequested()
        onForceParamChanged: {
            if (graphRoot.sim) {
                graphRoot.sim.repulsion = controls.repulsion
                graphRoot.sim.linkDistance = controls.linkDistance
                graphRoot.wakeSimulation()
            }
        }
    }
}
