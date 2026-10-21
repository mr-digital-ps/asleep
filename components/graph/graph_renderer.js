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
    var textHover = (theme.textHover ? theme.textHover.toString() : "#ffffff")
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

    // Единый монохромный цвет узлов для всех типов (различие задаётся исключительно геометрической формой)
    var nodeBaseColor = (vis.nodeColorFile && vis.nodeColorFile !== "#4da6ff") ? vis.nodeColorFile : (theme.bgActive ? theme.bgActive.toString() : "#383838")
    var nodeColorFile = nodeBaseColor
    var nodeColorBlock = nodeBaseColor
    var nodeColorTag = nodeBaseColor

    var showBlockEdges = (state.showBlockEdges !== false)
    var showTagEdges = (state.showTagEdges !== false)
    var showLinkEdges = (state.showLinkEdges !== false)

    var isActivityMode = (state.activityMode === true)
    var decayHalfLife = (vis && typeof vis.decayHalfLifeDays === "number") ? vis.decayHalfLifeDays : 14
    var minBrightness = (vis && typeof vis.activityMinBrightness === "number") ? vis.activityMinBrightness : 0.22
    var maxBrightness = (vis && typeof vis.activityMaxBrightness === "number") ? vis.activityMaxBrightness : 1.0
    var curTimeSec = Date.now() / 1000

    // 1. Отрисовка связей (ребер)
    for (var i = 0; i < links.length; i++) {
        var l = links[i]
        var s = l.source
        var t = l.target
        if (!s || !t) continue

        // Фильтрация видимости линий по типам (Shift+B, Shift+T, Shift+L):
        if (l.type === "block" || l.type === "transclusion") {
            if (!showBlockEdges) continue
        } else if (l.type === "tag") {
            if (!showTagEdges) continue
        } else if (l.type === "link") {
            if (!showLinkEdges) continue
        }

        var isConnectedToHover = hasHover && (s.id === hoveredNode.id || t.id === hoveredNode.id)
        var isTransclusion = (l.type === "transclusion")

        var linkAlpha = 1.0
        if (isActivityMode && !isConnectedToHover) {
            var sTime = s.mtime || s.timestamp || 0
            var tTime = t.mtime || t.timestamp || 0
            var maxT = Math.max(sTime, tTime)
            if (maxT > 0) {
                var lAge = Math.max(0, (curTimeSec - maxT) / 86400)
                var lDecay = Math.pow(0.5, lAge / decayHalfLife)
                linkAlpha = minBrightness + (maxBrightness - minBrightness) * lDecay
            } else {
                linkAlpha = minBrightness
            }
        }

        ctx.save()
        if (isActivityMode && !isConnectedToHover) {
            ctx.globalAlpha = Math.max(0.12, linkAlpha * 0.75)
        }

        ctx.beginPath()
        if (isTransclusion) {
            ctx.setLineDash([4, 4])
        } else {
            ctx.setLineDash([])
        }
        ctx.moveTo(s.x, s.y)
        ctx.lineTo(t.x, t.y)

        if (isConnectedToHover) {
            ctx.strokeStyle = linkHoverCol
            ctx.lineWidth = isTransclusion ? 1.1 : 1.3
        } else {
            ctx.strokeStyle = linkCol
            ctx.lineWidth = isTransclusion ? 0.7 : 0.8
        }
        ctx.stroke()
        ctx.restore()
    }
    ctx.setLineDash([]) // сброс пунктира

    // Вспомогательная функция рисования сглаженного многоугольника (пентагон для блоков)
    function drawSmoothPentagon(cx, cy, r, cornerRadius) {
        var sides = 5
        var cr = cornerRadius || (r * 0.28)
        var points = []
        // Вершины пентагона, развернутого вверх (-PI/2)
        for (var p = 0; p < sides; p++) {
            var angle = -Math.PI / 2 + (p * 2 * Math.PI / sides)
            points.push({
                x: cx + r * 1.15 * Math.cos(angle),
                y: cy + r * 1.15 * Math.sin(angle)
            })
        }

        ctx.beginPath()
        for (var k = 0; k < sides; k++) {
            var p1 = points[k]
            var p2 = points[(k + 1) % sides]
            var p0 = points[(k - 1 + sides) % sides]
            if (k === 0) {
                // Стартуем из середины первого ребра
                ctx.moveTo((p0.x + p1.x) / 2, (p0.y + p1.y) / 2)
            }
            ctx.arcTo(p1.x, p1.y, p2.x, p2.y, cr)
        }
        ctx.closePath()
    }

    // Вспомогательная функция рисования сглаженного ромба (для тегов)
    function drawSmoothDiamond(cx, cy, r, cornerRadius) {
        var cr = cornerRadius || (r * 0.28)
        var dPoints = [
            { x: cx, y: cy - r * 1.25 },
            { x: cx + r * 1.25, y: cy },
            { x: cx, y: cy + r * 1.25 },
            { x: cx - r * 1.25, y: cy }
        ]

        ctx.beginPath()
        for (var d = 0; d < 4; d++) {
            var dp1 = dPoints[d]
            var dp2 = dPoints[(d + 1) % 4]
            var dp0 = dPoints[(d - 1 + 4) % 4]
            if (d === 0) {
                ctx.moveTo((dp0.x + dp1.x) / 2, (dp0.y + dp1.y) / 2)
            }
            ctx.arcTo(dp1.x, dp1.y, dp2.x, dp2.y, cr)
        }
        ctx.closePath()
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

        var nodeDecay = 1.0
        var activityFactor = 1.0
        if (isActivityMode) {
            var nTime = n.mtime || n.timestamp || 0
            if (nTime > 0) {
                var nAge = Math.max(0, (curTimeSec - nTime) / 86400)
                nodeDecay = Math.pow(0.5, nAge / decayHalfLife)
            } else {
                nodeDecay = 0.0
            }
            activityFactor = minBrightness + (maxBrightness - minBrightness) * nodeDecay
        }

        var nodeAlpha = 1.0
        if (q && !matchesSearch) {
            nodeAlpha = 0.12
        } else if (hasHover && !isHover && !isConnected && !isActivePlayer && !isOpenAdjacent) {
            nodeAlpha = isActivityMode ? (0.28 * activityFactor) : 0.35
        } else if (isActivityMode) {
            nodeAlpha = activityFactor
        }

        ctx.save()
        ctx.globalAlpha = nodeAlpha

        var baseRadius = n.radius || 4.5
        var nType = n.type || "file"

        // Маркер активного файла ("Вы здесь") или соседнего открытого файла
        if (isActivePlayer) {
            ctx.beginPath()
            ctx.arc(n.x, n.y, baseRadius + 2.8, 0, 2 * Math.PI)
            ctx.strokeStyle = textSecondary
            ctx.lineWidth = 1.2
            ctx.stroke()
        } else if (isOpenAdjacent) {
            ctx.beginPath()
            ctx.arc(n.x, n.y, baseRadius + 2.8, 0, 2 * Math.PI)
            ctx.strokeStyle = accentColor
            ctx.lineWidth = 1.3
            ctx.stroke()
        }

        // В режиме созвездия (Anki) свежие заметки сияют ярче и получают звёздный ореол
        if (isActivityMode && nodeDecay >= 0.75 && !isHover && !isDragged && !isActivePlayer && !isOpenAdjacent) {
            ctx.beginPath()
            ctx.arc(n.x, n.y, baseRadius + 1.8, 0, 2 * Math.PI)
            ctx.strokeStyle = textPrimary
            ctx.lineWidth = 0.8
            ctx.stroke()
        }

        // Отрисовка геометрической фигуры в зависимости от типа узла:
        // - file: сплошной круг
        // - block: сглаженный ромб (smooth diamond)
        // - tag: сглаженный пентагон (smooth pentagon - ярлык/бирка)
        if (nType === "tag") {
            drawSmoothPentagon(n.x, n.y, baseRadius)
            if (isDragged || isHover) {
                ctx.fillStyle = borderHover
                ctx.fill()
                ctx.strokeStyle = textPrimary
                ctx.lineWidth = 1.4
                ctx.stroke()
            } else if (isConnected) {
                ctx.fillStyle = bgActive
                ctx.fill()
                ctx.strokeStyle = borderHover
                ctx.lineWidth = 1.2
                ctx.stroke()
            } else {
                var tagFill = (isActivityMode && nodeDecay >= 0.75) ? textPrimary : (isActivityMode && nodeDecay < 0.35 ? bgHover : nodeColorTag)
                ctx.fillStyle = tagFill
                ctx.fill()
                ctx.strokeStyle = (isActivityMode && nodeDecay >= 0.75) ? textHover : borderColor
                ctx.lineWidth = 1.0
                ctx.stroke()
            }
        } else if (nType === "block") {
            drawSmoothDiamond(n.x, n.y, baseRadius)
            if (isDragged || isHover) {
                ctx.fillStyle = borderHover
                ctx.fill()
                ctx.strokeStyle = textPrimary
                ctx.lineWidth = 1.4
                ctx.stroke()
            } else if (isConnected) {
                ctx.fillStyle = bgActive
                ctx.fill()
                ctx.strokeStyle = borderHover
                ctx.lineWidth = 1.2
                ctx.stroke()
            } else {
                var blockFill = (isActivityMode && nodeDecay >= 0.75) ? textPrimary : (isActivityMode && nodeDecay < 0.35 ? bgHover : nodeColorBlock)
                ctx.fillStyle = blockFill
                ctx.fill()
                ctx.strokeStyle = (isActivityMode && nodeDecay >= 0.75) ? textHover : borderColor
                ctx.lineWidth = 1.0
                ctx.stroke()
            }
        } else {
            // Файлы (сплошные круги)
            ctx.beginPath()
            ctx.arc(n.x, n.y, baseRadius, 0, 2 * Math.PI)

            if (isDragged || isHover) {
                ctx.fillStyle = borderHover
                ctx.fill()
                ctx.strokeStyle = textPrimary
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
                var fileFill = (isActivityMode && nodeDecay >= 0.75) ? textPrimary : (isActivityMode && nodeDecay < 0.35 ? bgHover : nodeColorFile)
                ctx.fillStyle = fileFill
                ctx.fill()
                ctx.strokeStyle = (isActivityMode && nodeDecay >= 0.75) ? textHover : borderColor
                ctx.lineWidth = 1.0
                ctx.stroke()
            }
        }

        // Текстовая подпись узла
        var shouldDrawLabel = isHover || isConnected || isActivePlayer || isOpenAdjacent || (q && matchesSearch) || (zoomScale > 0.9)
        if (shouldDrawLabel && nodeAlpha > 0.20) {
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
