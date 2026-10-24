// graph_renderer.js — Отрисовка Canvas и экранная проекция для интерактивного графа связей

var PENTAGON_COS = [0, 0.9510565, 0.5877853, -0.5877853, -0.9510565]
var PENTAGON_SIN = [-1, -0.309017, 0.809017, 0.809017, -0.309017]

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

    // Преобразуем координаты мыши в мировые координаты один раз
    var wx = (screenX - (w / 2 + px)) / zs + w / 2
    var wy = (screenY - (h / 2 + py)) / zs + h / 2
    var invZs = 1.0 / zs

    for (var i = nodes.length - 1; i >= 0; i--) {
        var n = nodes[i]
        var dx = wx - n.x
        var dy = wy - n.y
        var distSq = dx * dx + dy * dy

        // 1. Попадание в сам кружок (минимальный радиус в мировых координатах)
        var hitR = Math.max(22 * invZs, (n.radius || 4.5) + 12 * invZs)
        var hitCircle = (distSq <= hitR * hitR)

        // 2. Попадание в подпись под кружком
        var labelLen = (n.label ? n.label.length : 6)
        var labelHalfW = Math.max(26 * invZs, (labelLen * 3.5 + 10) * Math.min(1.2 * invZs, 1.2))
        var hitLabel = (Math.abs(dx) <= labelHalfW && dy >= 0 && dy <= (26 * Math.min(1.2 * invZs, 1.2)))

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
    var accentColor = (theme.accentColor ? theme.accentColor.toString() : "#d4d4d4")

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

    // Расчет временного диапазона хранилища для гарантированного контраста (Adaptive Recency Span)
    var minMtime = Infinity
    var maxMtime = -Infinity
    if (isActivityMode && nodes) {
        for (var k = 0; k < nodes.length; k++) {
            var mt = nodes[k].mtime || nodes[k].timestamp || 0
            if (mt > 0) {
                if (mt < minMtime) minMtime = mt
                if (mt > maxMtime) maxMtime = mt
            }
        }
    }
    var mtimeSpan = (maxMtime > minMtime) ? (maxMtime - minMtime) : 0

    // 1. Отрисовка связей (ребер) с пакетной группировкой (Batch Link Rendering)
    var normalLinks = []
    var transclusionLinks = []
    var hoverLinks = []

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
        if (isConnectedToHover) {
            hoverLinks.push(l)
        } else if (l.type === "transclusion") {
            transclusionLinks.push(l)
        } else {
            normalLinks.push(l)
        }
    }

    // 1.1 Пакетная отрисовка обычных связей (1 draw call)
    if (normalLinks.length > 0) {
        ctx.beginPath()
        ctx.strokeStyle = linkCol
        ctx.lineWidth = 0.8
        for (var ni = 0; ni < normalLinks.length; ni++) {
            var nl = normalLinks[ni]
            ctx.moveTo(nl.source.x, nl.source.y)
            ctx.lineTo(nl.target.x, nl.target.y)
        }
        ctx.stroke()
    }

    // 1.2 Пакетная отрисовка трансклюзий (пунктир, 1 draw call)
    if (transclusionLinks.length > 0) {
        ctx.beginPath()
        ctx.strokeStyle = linkCol
        ctx.lineWidth = 0.7
        ctx.setLineDash([4, 4])
        for (var ti = 0; ti < transclusionLinks.length; ti++) {
            var tl = transclusionLinks[ti]
            ctx.moveTo(tl.source.x, tl.source.y)
            ctx.lineTo(tl.target.x, tl.target.y)
        }
        ctx.stroke()
        ctx.setLineDash([])
    }

    // 1.3 Подсвеченные связи при наведении
    if (hoverLinks.length > 0) {
        for (var hi = 0; hi < hoverLinks.length; hi++) {
            var hl = hoverLinks[hi]
            ctx.beginPath()
            if (hl.type === "transclusion") ctx.setLineDash([4, 4])
            else ctx.setLineDash([])
            ctx.moveTo(hl.source.x, hl.source.y)
            ctx.lineTo(hl.target.x, hl.target.y)
            ctx.strokeStyle = linkHoverCol
            ctx.lineWidth = (hl.type === "transclusion") ? 1.1 : 1.3
            ctx.stroke()
        }
        ctx.setLineDash([])
    }

    // Вспомогательная функция рисования сглаженного многоугольника (пентагон для блоков)
    function drawSmoothPentagon(cx, cy, r, cornerRadius) {
        var cr = cornerRadius || (r * 0.28)
        var s = r * 1.15
        var x0 = cx + s * PENTAGON_COS[0], y0 = cy + s * PENTAGON_SIN[0]
        var x1 = cx + s * PENTAGON_COS[1], y1 = cy + s * PENTAGON_SIN[1]
        var x2 = cx + s * PENTAGON_COS[2], y2 = cy + s * PENTAGON_SIN[2]
        var x3 = cx + s * PENTAGON_COS[3], y3 = cy + s * PENTAGON_SIN[3]
        var x4 = cx + s * PENTAGON_COS[4], y4 = cy + s * PENTAGON_SIN[4]

        ctx.beginPath()
        ctx.moveTo((x4 + x0) / 2, (y4 + y0) / 2)
        ctx.arcTo(x0, y0, x1, y1, cr)
        ctx.arcTo(x1, y1, x2, y2, cr)
        ctx.arcTo(x2, y2, x3, y3, cr)
        ctx.arcTo(x3, y3, x4, y4, cr)
        ctx.arcTo(x4, y4, x0, y0, cr)
        ctx.closePath()
    }

    // Вспомогательная функция рисования сглаженного ромба (для тегов)
    function drawSmoothDiamond(cx, cy, r, cornerRadius) {
        var cr = cornerRadius || (r * 0.28)
        var s = r * 1.25
        var x0 = cx, y0 = cy - s
        var x1 = cx + s, y1 = cy
        var x2 = cx, y2 = cy + s
        var x3 = cx - s, y3 = cy

        ctx.beginPath()
        ctx.moveTo((x3 + x0) / 2, (y3 + y0) / 2)
        ctx.arcTo(x0, y0, x1, y1, cr)
        ctx.arcTo(x1, y1, x2, y2, cr)
        ctx.arcTo(x2, y2, x3, y3, cr)
        ctx.arcTo(x3, y3, x0, y0, cr)
        ctx.closePath()
    }

    // 2. Отрисовка узлов (с предварительно вычисленными шрифтами и без избыточного save/restore)
    var fontNormal = labelFontSize + "px sans-serif"
    var fontHover = "500 " + (labelFontSize + 0.5) + "px sans-serif"
    var fontPlayer = "600 " + (labelFontSize + 1) + "px sans-serif"
    var fontOpen = "600 " + (labelFontSize + 0.5) + "px sans-serif"
    var curFont = ""
    function applyFont(f) {
        if (curFont !== f) {
            ctx.font = f
            curFont = f
        }
    }
    var currentAlpha = 1.0
    ctx.textAlign = "center"

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
                var nAbs = Math.pow(0.5, nAge / decayHalfLife)
                var nRel = (mtimeSpan > 60) ? Math.pow(Math.max(0, Math.min(1.0, (nTime - minMtime) / mtimeSpan)), 1.8) : nAbs
                nodeDecay = (mtimeSpan > 60) ? nRel : nAbs
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

        if (Math.abs(currentAlpha - nodeAlpha) > 0.01) {
            ctx.globalAlpha = nodeAlpha
            currentAlpha = nodeAlpha
        }

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
        if (isActivityMode && nodeDecay >= 0.70 && !isHover && !isDragged && !isActivePlayer && !isOpenAdjacent) {
            ctx.beginPath()
            ctx.arc(n.x, n.y, baseRadius + 2.0, 0, 2 * Math.PI)
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
                var tagFill = (isActivityMode && nodeDecay >= 0.70) ? textHover : (isActivityMode && nodeDecay < 0.35 ? bgHover : (isActivityMode ? textSecondary : nodeColorTag))
                ctx.fillStyle = tagFill
                ctx.fill()
                ctx.strokeStyle = (isActivityMode && nodeDecay >= 0.70) ? textHover : borderColor
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
                var blockFill = (isActivityMode && nodeDecay >= 0.70) ? textHover : (isActivityMode && nodeDecay < 0.35 ? bgHover : (isActivityMode ? textSecondary : nodeColorBlock))
                ctx.fillStyle = blockFill
                ctx.fill()
                ctx.strokeStyle = (isActivityMode && nodeDecay >= 0.70) ? textHover : borderColor
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
                var fileFill = (isActivityMode && nodeDecay >= 0.70) ? textHover : (isActivityMode && nodeDecay < 0.35 ? bgHover : (isActivityMode ? textSecondary : nodeColorFile))
                ctx.fillStyle = fileFill
                ctx.fill()
                ctx.strokeStyle = (isActivityMode && nodeDecay >= 0.70) ? textHover : borderColor
                ctx.lineWidth = 1.0
                ctx.stroke()
            }
        }

        // Текстовая подпись узла
        var shouldDrawLabel = isHover || isConnected || isActivePlayer || isOpenAdjacent || (q && matchesSearch) || (zoomScale > 0.9)
        if (shouldDrawLabel && nodeAlpha > 0.20) {
            if (isActivePlayer) {
                applyFont(fontPlayer)
                ctx.fillStyle = textPrimary
            } else if (isOpenAdjacent) {
                applyFont(fontOpen)
                ctx.fillStyle = textPrimary
            } else {
                applyFont(isHover ? fontHover : fontNormal)
                ctx.fillStyle = isHover ? labelHoverCol : (isConnected ? textSecondary : labelCol)
            }
            ctx.fillText(n.label || "", n.x, n.y + (n.radius || 4.5) + 11)
        }
    }

    if (currentAlpha !== 1.0) {
        ctx.globalAlpha = 1.0
    }

    ctx.restore()
}
