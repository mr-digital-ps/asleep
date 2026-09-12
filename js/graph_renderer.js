// graph_renderer.js — Отрисовка Canvas и экранная проекция для интерактивного графа связей

function toWorldX(screenX, width, panX, zoomScale) {
    return (screenX - (width / 2 + panX)) / zoomScale + width / 2
}

function toWorldY(screenY, height, panY, zoomScale) {
    return (screenY - (height / 2 + panY)) / zoomScale + height / 2
}

function findNodeAtScreen(sim, screenX, screenY, width, height, zoomScale, panX, panY) {
    if (!sim || !sim.nodes) return null
    var nodes = sim.nodes
    var bestNode = null
    var bestDistSq = Infinity
    var w = width
    var h = height
    var zs = zoomScale
    var px = panX
    var py = panY

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

function renderGraph(ctx, width, height, sim, state) {
    ctx.clearRect(0, 0, width, height)
    if (!sim || !sim.nodes) return

    var panX = state.panX || 0
    var panY = state.panY || 0
    var zoomScale = state.zoomScale || 1.0
    var hoveredNode = state.hoveredNode
    var draggedNode = state.draggedNode
    var highlightedNodeIds = state.highlightedNodeIds || {}
    var q = state.searchQuery || ""
    var graphConfig = state.graphConfig || {}

    ctx.save()
    ctx.translate(width / 2 + panX, height / 2 + panY)
    ctx.scale(zoomScale, zoomScale)
    ctx.translate(-width / 2, -height / 2)

    var nodes = sim.nodes
    var links = sim.links
    var hasHover = (hoveredNode !== null)

    var vis = (graphConfig && graphConfig.visual) ? graphConfig.visual : {}
    var linkCol = vis.linkColor || "rgba(65, 65, 65, 0.35)"
    var linkHoverCol = vis.linkHoverColor || "rgba(140, 140, 140, 0.75)"
    var labelCol = vis.labelColor || "#666666"
    var labelHoverCol = vis.labelHoverColor || "#d4d4d4"
    var labelFontSize = (typeof vis.labelFontSize === "number") ? vis.labelFontSize : 10
    var nodeColorFile = vis.nodeColorFile || "#282828"
    var nodeColorBlock = vis.nodeColorBlock || "#342c44"
    var nodeColorTag = vis.nodeColorTag || "#3c3322"

    // 1. Отрисовка связей (ребер)
    for (var i = 0; i < links.length; i++) {
        var l = links[i]
        var s = l.source
        var t = l.target
        if (!s || !t) continue

        var isConnectedToHover = hasHover && (s.id === hoveredNode.id || t.id === hoveredNode.id)
        ctx.beginPath()
        ctx.moveTo(s.x, s.y)
        ctx.lineTo(t.x, t.y)

        if (isConnectedToHover) {
            ctx.strokeStyle = linkHoverCol
            ctx.lineWidth = 1.3
        } else {
            ctx.strokeStyle = linkCol
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

        var baseFill = (n.type === "block" ? nodeColorBlock : (n.type === "tag" ? nodeColorTag : nodeColorFile))
        var baseStroke = (n.type === "block" ? "#4a3e62" : (n.type === "tag" ? "#564830" : "#3c3c3c"))

        if (isDragged) {
            ctx.fillStyle = "#555555"
            ctx.fill()
            ctx.strokeStyle = "#808080"
            ctx.lineWidth = 1.8
            ctx.stroke()
        } else if (isHover) {
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
            ctx.fillStyle = baseFill
            ctx.fill()
            ctx.strokeStyle = baseStroke
            ctx.lineWidth = 1.0
            ctx.stroke()
        }

        // Текстовая подпись узла
        var shouldDrawLabel = isHover || isConnected || (q && matchesSearch) || (zoomScale > 0.9)
        if (shouldDrawLabel && nodeAlpha > 0.25) {
            var curFontSize = isHover ? (labelFontSize + 0.5) : labelFontSize
            ctx.font = (isHover ? "500 " + curFontSize + "px sans-serif" : curFontSize + "px sans-serif")
            ctx.fillStyle = isHover ? labelHoverCol : (isConnected ? "#aaaaaa" : labelCol)
            ctx.textAlign = "center"
            ctx.fillText(n.label || "", n.x, n.y + (n.radius || 4.5) + 11)
        }

        ctx.restore()
    }

    ctx.restore()
}
