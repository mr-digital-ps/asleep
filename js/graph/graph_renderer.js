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

function normalizeUrl(url) {
    if (!url) return ""
    return decodeURIComponent(url.toString().replace(/^file:\/\/\/?/i, "").toLowerCase().replace(/\\/g, "/"))
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
    var activeNodeId = state.activeNodeId || ""
    var activeFileUrl = state.activeFileUrl || ""
    var normActiveUrl = normalizeUrl(activeFileUrl)
    var openFileUrls = state.openFileUrls || []
    var openUrlsMap = {}
    for (var u = 0; u < openFileUrls.length; u++) {
        var nu = normalizeUrl(openFileUrls[u])
        if (nu) openUrlsMap[nu] = true
    }
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
    var theme = state.theme || {}

    var textMuted = (theme.textMuted ? theme.textMuted.toString() : "#666666")
    var textPrimary = (theme.textPrimary ? theme.textPrimary.toString() : "#d4d4d4")
    var textSecondary = (theme.textSecondary ? theme.textSecondary.toString() : "#888888")
    var borderColor = (theme.borderColor ? theme.borderColor.toString() : "#282828")
    var borderHover = (theme.borderHover ? theme.borderHover.toString() : "#383838")
    var bgActive = (theme.bgActive ? theme.bgActive.toString() : "#282828")
    var bgHover = (theme.bgHover ? theme.bgHover.toString() : "#202020")
    var accentColor = (theme.accentColor ? theme.accentColor.toString() : "#7aa2f7")

    var linkCol = vis.linkColor || borderColor
    var linkHoverCol = vis.linkHoverColor || borderHover
    var labelCol = vis.labelColor || textMuted
    var labelHoverCol = vis.labelHoverColor || textPrimary
    var labelFontSize = (typeof vis.labelFontSize === "number") ? vis.labelFontSize : 10

    var nodeColorFile = (vis.nodeColorFile && vis.nodeColorFile !== "#4da6ff") ? vis.nodeColorFile : (theme.bgActive ? theme.bgActive.toString() : "#383838")
    var nodeColorBlock = (vis.nodeColorBlock && vis.nodeColorBlock !== "#bb9af7") ? vis.nodeColorBlock : (theme.bgHover ? theme.bgHover.toString() : "#2a2a2a")
    var nodeColorTag = (vis.nodeColorTag && vis.nodeColorTag !== "#e0af68") ? vis.nodeColorTag : (theme.bgHover ? theme.bgHover.toString() : "#323232")

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
        var isActivePlayer = (n.type === "file") && (
            (activeNodeId && n.id === activeNodeId) ||
            (normActiveUrl && n.fileUrl && normalizeUrl(n.fileUrl) === normActiveUrl)
        )
        var normNodeUrl = (n.type === "file" && n.fileUrl) ? normalizeUrl(n.fileUrl) : ""
        var isOpenAdjacent = (n.type === "file") && normNodeUrl && (openUrlsMap[normNodeUrl] === true) && !isActivePlayer
        var matchesSearch = (!q || (n.label && n.label.toLowerCase().indexOf(q) !== -1))

        var nodeAlpha = 1.0
        if (q && !matchesSearch) {
            nodeAlpha = 0.12
        } else if (hasHover && !isHover && !isConnected && !isActivePlayer && !isOpenAdjacent) {
            nodeAlpha = 0.35
        }

        ctx.save()
        ctx.globalAlpha = nodeAlpha

        var baseFill = (n.type === "block" ? nodeColorBlock : (n.type === "tag" ? nodeColorTag : nodeColorFile))
        var baseStroke = borderColor

        // Маркер активного файла ("Вы здесь") или соседнего открытого файла
        if (isActivePlayer) {
            ctx.beginPath()
            ctx.arc(n.x, n.y, (n.radius || 4.5) + 2.6, 0, 2 * Math.PI)
            ctx.strokeStyle = textSecondary
            ctx.lineWidth = 1.2
            ctx.stroke()
        } else if (isOpenAdjacent) {
            ctx.beginPath()
            ctx.arc(n.x, n.y, (n.radius || 4.5) + 2.6, 0, 2 * Math.PI)
            ctx.strokeStyle = accentColor
            ctx.lineWidth = 1.3
            ctx.stroke()
        }

        ctx.beginPath()
        ctx.arc(n.x, n.y, n.radius || 4.5, 0, 2 * Math.PI)

        if (isDragged) {
            ctx.fillStyle = bgActive
            ctx.fill()
            ctx.strokeStyle = textSecondary
            ctx.lineWidth = 1.4
            ctx.stroke()
        } else if (isHover) {
            ctx.fillStyle = borderHover
            ctx.fill()
            ctx.strokeStyle = textSecondary
            ctx.lineWidth = 1.4
            ctx.stroke()
        } else if (isActivePlayer) {
            ctx.fillStyle = textSecondary
            ctx.fill()
            ctx.strokeStyle = borderColor
            ctx.lineWidth = 1.0
            ctx.stroke()
        } else if (isOpenAdjacent) {
            ctx.fillStyle = bgActive
            ctx.fill()
            ctx.strokeStyle = accentColor
            ctx.lineWidth = 1.3
            ctx.stroke()
        } else if (isConnected) {
            ctx.fillStyle = bgActive
            ctx.fill()
            ctx.strokeStyle = borderHover
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
        var shouldDrawLabel = isHover || isConnected || isActivePlayer || isOpenAdjacent || (q && matchesSearch) || (zoomScale > 0.9)
        if (shouldDrawLabel && nodeAlpha > 0.25) {
            if (isActivePlayer) {
                var playerFontSize = labelFontSize + 1
                ctx.font = "600 " + playerFontSize + "px sans-serif"
                ctx.fillStyle = textPrimary
            } else if (isOpenAdjacent) {
                var openFontSize = labelFontSize + 0.5
                ctx.font = "600 " + openFontSize + "px sans-serif"
                ctx.fillStyle = textPrimary
            } else {
                var curFontSize = isHover ? (labelFontSize + 0.5) : labelFontSize
                ctx.font = (isHover ? "500 " + curFontSize + "px sans-serif" : curFontSize + "px sans-serif")
                ctx.fillStyle = isHover ? labelHoverCol : (isConnected ? textSecondary : labelCol)
            }
            ctx.textAlign = "center"
            ctx.fillText(n.label || "", n.x, n.y + (n.radius || 4.5) + 11)
        }

        ctx.restore()
    }

    ctx.restore()
}
