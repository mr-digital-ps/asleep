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

        // Преобразуем QVariant из Python в чистые нативные объекты JS,
        // иначе мутации координат (x, y) при перетаскивании не сохраняются в памяти JS!
        var pureNodes = JSON.parse(JSON.stringify(data.nodes))
        var pureLinks = JSON.parse(JSON.stringify(data.links || []))

        sim = Physics.initSimulation(pureNodes, pureLinks, canvas.width || 800, canvas.height || 600, {
            repulsion: 5500,
            linkDistance: 135,
            linkStrength: 0.035,
            gravity: 0.0008,
            damping: 0.88
        })
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
        if (sim && sim.nodes) {
            for (var i = 0; i < sim.nodes.length; i++) {
                sim.nodes[i].isFixed = false
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
                var alpha = hasHover ? (isConnectedToHover ? 0.75 : 0.08) : 0.35

                ctx.beginPath()
                ctx.moveTo(s.x, s.y)
                ctx.lineTo(t.x, t.y)

                if (isConnectedToHover) {
                    ctx.strokeStyle = "rgba(140, 140, 140, " + alpha + ")"
                    ctx.lineWidth = 1.3
                } else {
                    ctx.strokeStyle = "rgba(65, 65, 65, " + alpha + ")"
                    ctx.lineWidth = 0.8
                }
                ctx.stroke()
            }

            // 2. Отрисовка узлов
            for (var j = 0; j < nodes.length; j++) {
                var n = nodes[j]
                var isDragged = (draggedNode && draggedNode.id === n.id)
                var isHover = ((hoveredNode && hoveredNode.id === n.id) || isDragged)
                var isConnected = highlightedNodeIds[n.id] === true
                var matchesSearch = (!q || (n.label && n.label.toLowerCase().indexOf(q) !== -1))

                var nodeAlpha = 1.0
                if (q && !matchesSearch) {
                    nodeAlpha = 0.12
                } else if (hasHover && !isHover && !isConnected) {
                    nodeAlpha = 0.35
                }

                ctx.save()
                ctx.globalAlpha = nodeAlpha

                ctx.beginPath()
                ctx.arc(n.x, n.y, n.radius || 4.5, 0, 2 * Math.PI)

                var baseFill = (n.type === "block" ? "#342c44" : (n.type === "tag" ? "#3c3322" : "#282828"))
                var baseStroke = (n.type === "block" ? "#4a3e62" : (n.type === "tag" ? "#564830" : "#3c3c3c"))

                if (isDragged) {
                    ctx.fillStyle = "#555555"
                    ctx.fill()
                    ctx.strokeStyle = "#808080"
                    ctx.lineWidth = 1.8
                    ctx.stroke()
                } else if (isHover) {
                    // При наведении: просто чуть-чуть ярче, спокойный серебристый тон
                    ctx.fillStyle = (n.type === "block" ? "#4a3e64" : (n.type === "tag" ? "#55462c" : "#444444"))
                    ctx.fill()
                    ctx.strokeStyle = (n.type === "block" ? "#6d5894" : (n.type === "tag" ? "#7c663c" : "#686868"))
                    ctx.lineWidth = 1.6
                    ctx.stroke()
                } else if (isConnected) {
                    ctx.fillStyle = (n.type === "block" ? "#3c3250" : (n.type === "tag" ? "#453924" : "#363636"))
                    ctx.fill()
                    ctx.strokeStyle = "#4e4e4e"
                    ctx.lineWidth = 1.2
                    ctx.stroke()
                } else {
                    ctx.fillStyle = (n.isFixed ? "#343434" : baseFill)
                    ctx.fill()
                    ctx.strokeStyle = (n.isFixed ? "#555555" : baseStroke)
                    ctx.lineWidth = (n.isFixed ? 1.5 : 1.0)
                    ctx.stroke()
                }

                // Подпись узла
                var shouldDrawLabel = isHover || isConnected || (q && matchesSearch) || (graphRoot.zoomScale > 0.9)
                if (shouldDrawLabel && nodeAlpha > 0.25) {
                    ctx.font = (isHover ? "500 10.5px sans-serif" : "10px sans-serif")
                    ctx.fillStyle = isHover ? "#d4d4d4" : (isConnected ? "#aaaaaa" : "#666666")
                    ctx.textAlign = "center"
                    ctx.fillText(n.label || "", n.x, n.y + (n.radius || 4.5) + 11)
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
            return (screenX - (width / 2 + graphRoot.panX)) / graphRoot.zoomScale + width / 2
        }

        function toWorldY(screenY) {
            return (screenY - (height / 2 + graphRoot.panY)) / graphRoot.zoomScale + height / 2
        }

        // Надежный расчет попадания в узел (и в кружок, и в текст подписи)
        function findNodeAtScreen(screenX, screenY) {
            if (!graphRoot.sim || !graphRoot.sim.nodes) return null
            var nodes = graphRoot.sim.nodes
            var bestNode = null
            var bestDistSq = Infinity
            var w = width
            var h = height
            var zs = graphRoot.zoomScale
            var px = graphRoot.panX
            var py = graphRoot.panY

            for (var i = nodes.length - 1; i >= 0; i--) {
                var n = nodes[i]
                var sx = (n.x - w / 2) * zs + w / 2 + px
                var sy = (n.y - h / 2) * zs + h / 2 + py
                var dx = screenX - sx
                var dy = screenY - sy
                var distSq = dx * dx + dy * dy

                // 1. Попадание в сам кружок (комфортный радиус минимум 22px на экране)
                var circleRadius = Math.max(22, (n.radius || 4.5) * zs + 12)
                var hitCircle = (distSq <= circleRadius * circleRadius)

                // 2. Попадание в подпись под кружком
                var labelLen = (n.label ? n.label.length : 6)
                var labelHalfW = Math.max(26, (labelLen * 3.5 + 10) * Math.min(1.2, zs))
                var hitLabel = (Math.abs(dx) <= labelHalfW && dy >= 0 && dy <= (26 * Math.min(1.2, zs)))

                if ((hitCircle || hitLabel) && distSq < bestDistSq) {
                    bestDistSq = distSq
                    bestNode = n
                }
            }
            return bestNode
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
                if (movedDist >= 4) {
                    // Узел был передвинут — закрепляем его в новой позиции на холсте!
                    nodeRef.isFixed = true
                    nodeRef.vx = 0
                    nodeRef.vy = 0
                } else {
                    nodeRef.isFixed = false
                }
                graphRoot.draggedNode = null
                graphRoot.wakeSimulation()
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

        onDoubleClicked: (mouse) => {
            var node = findNodeAtScreen(mouse.x, mouse.y)
            if (node) {
                // Двойной клик переключает фиксацию (unpin / pin)
                node.isFixed = !node.isFixed
                graphRoot.wakeSimulation()
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
