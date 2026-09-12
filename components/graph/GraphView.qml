import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../js/graph_physics.js" as Physics

Rectangle {
    id: graphRoot
    anchors.fill: parent
    color: "#141414"
    clip: true

    property string folderUrl: ""
    property var sim: null
    property real zoomScale: 1.0
    property real panX: 0
    property real panY: 0
    property string searchQuery: ""

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
            repulsion: 3200,
            linkDistance: 85,
            gravity: 0.02,
            damping: 0.85
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
            var q = graphRoot.searchQuery

            // 1. Отрисовка связей (Строгий темно-серый монохром)
            for (var i = 0; i < links.length; i++) {
                var l = links[i]
                var s = l.source
                var t = l.target
                if (!s || !t) continue

                var isConnectedToHover = hasHover && (s.id === hoveredNode.id || t.id === hoveredNode.id)
                var alpha = hasHover ? (isConnectedToHover ? 0.85 : 0.08) : 0.35

                ctx.beginPath()
                ctx.moveTo(s.x, s.y)
                ctx.lineTo(t.x, t.y)

                if (isConnectedToHover) {
                    ctx.strokeStyle = "rgba(200, 200, 200, " + alpha + ")"
                    ctx.lineWidth = 1.8
                } else {
                    ctx.strokeStyle = "rgba(75, 75, 75, " + alpha + ")"
                    ctx.lineWidth = 1.0
                }
                ctx.stroke()
            }

            // 2. Отрисовка узлов
            for (var j = 0; j < nodes.length; j++) {
                var n = nodes[j]
                var isHover = (hoveredNode && hoveredNode.id === n.id)
                var isConnected = highlightedNodeIds[n.id] === true
                var matchesSearch = (!q || (n.label && n.label.toLowerCase().indexOf(q) !== -1))

                var nodeAlpha = 1.0
                if (q && !matchesSearch) {
                    nodeAlpha = 0.12
                } else if (hasHover && !isHover && !isConnected) {
                    nodeAlpha = 0.18
                }

                ctx.save()
                ctx.globalAlpha = nodeAlpha

                ctx.beginPath()
                ctx.arc(n.x, n.y, n.radius || 7, 0, 2 * Math.PI)

                if (isHover) {
                    ctx.fillStyle = "#ffffff"
                    ctx.fill()
                    ctx.strokeStyle = "rgba(255, 255, 255, 0.4)"
                    ctx.lineWidth = 4
                    ctx.stroke()
                } else if (isConnected) {
                    ctx.fillStyle = "#bbbbbb"
                    ctx.fill()
                    ctx.strokeStyle = "#444444"
                    ctx.lineWidth = 1.5
                    ctx.stroke()
                } else {
                    ctx.fillStyle = "#2e2e2e"
                    ctx.fill()
                    ctx.strokeStyle = "#404040"
                    ctx.lineWidth = 1.2
                    ctx.stroke()
                }

                // Подпись узла
                var shouldDrawLabel = isHover || isConnected || (q && matchesSearch) || (graphRoot.zoomScale > 0.85)
                if (shouldDrawLabel && nodeAlpha > 0.3) {
                    ctx.font = (isHover ? "600 11px sans-serif" : "11px sans-serif")
                    ctx.fillStyle = isHover ? "#ffffff" : (isConnected ? "#d0d0d0" : "#777777")
                    ctx.textAlign = "center"
                    ctx.fillText(n.label || "", n.x, n.y + (n.radius || 7) + 13)
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
            var newZoom = Math.max(0.25, Math.min(3.5, graphRoot.zoomScale * factor))
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

            // Одиночный клик без смещения — переход к заметке
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
