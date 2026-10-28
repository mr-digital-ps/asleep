// components/metro/metro_renderer.js — Рендерер схемы метро сюжета (Metro Transit Map)
.pragma library

/**
 * Отрисовка схемы линий метро на HTML5 Canvas
 */
function renderMetro(ctx, width, height, metroData, config, panX, panY, zoomScale, hoveredStationId, activeFileUrl, hoveredTrackId) {
    if (!ctx) return

    ctx.save()
    ctx.clearRect(0, 0, width, height)

    var visual = (config && config.visual) ? config.visual : {}
    var lineWidth = visual.lineWidth || 4.0
    var lineRestingAlpha = (visual.lineRestingAlpha !== undefined) ? visual.lineRestingAlpha : 0.26
    var lineHighlightAlpha = (visual.lineHighlightAlpha !== undefined) ? visual.lineHighlightAlpha : 1.0
    var lineTributaryAlpha = (visual.lineTributaryAlpha !== undefined) ? visual.lineTributaryAlpha : 0.55
    var lineDimmedAlpha = (visual.lineDimmedAlpha !== undefined) ? visual.lineDimmedAlpha : 0.10
    var stationRadius = visual.stationRadius || 6.5
    var interchangeRadius = visual.interchangeRadius || 9.5
    var stBorderWidth = visual.stationBorderWidth || 2.5
    var stBorderColor = visual.stationBorderColor || "#18181B"
    var stFillColor = visual.stationFillColor || "#FFFFFF"
    var labelFontSize = visual.labelFontSize || 12
    var labelFontFamily = visual.labelFontFamily || "Segoe UI, Inter, sans-serif"
    var labelColor = visual.labelColor || "#E2E8F0"
    var labelSubColor = visual.labelSubColor || "#94A3B8"
    var showGrid = visual.showGrid !== false
    var gridColor = visual.gridColor || "rgba(255, 255, 255, 0.03)"
    var gridStep = visual.gridStep || 40

    // 1. Отрисовка фоновой сетки (в экранных координатах)
    if (showGrid && zoomScale > 0.4) {
        ctx.strokeStyle = gridColor
        ctx.lineWidth = 1
        var effStep = gridStep * zoomScale
        var startX = (panX % effStep + effStep) % effStep
        var startY = (panY % effStep + effStep) % effStep

        ctx.beginPath()
        for (var gx = startX; gx < width; gx += effStep) {
            ctx.moveTo(gx, 0)
            ctx.lineTo(gx, height)
        }
        for (var gy = startY; gy < height; gy += effStep) {
            ctx.moveTo(0, gy)
            ctx.lineTo(width, gy)
        }
        ctx.stroke()
    }

    // 2. Применяем матрицу масштабирования и панорамирования
    ctx.translate(panX, panY)
    ctx.scale(zoomScale, zoomScale)

    var segments = (metroData && metroData.segments) ? metroData.segments : []
    var stations = (metroData && metroData.stations) ? metroData.stations : []
    var tracks = (metroData && metroData.tracks) ? metroData.tracks : []
    var groups = (metroData && metroData.groups) ? metroData.groups : []
    var stages = (metroData && metroData.stages) ? metroData.stages : []

    // 2.3 Отрисовка вертикальных разделителей этапов (Stage Columns)
    if (stages.length > 0) {
        ctx.save()
        ctx.strokeStyle = "rgba(255, 255, 255, 0.04)"
        ctx.lineWidth = 1
        ctx.setLineDash([6, 8])
        for (var sIdx = 0; sIdx < stages.length; sIdx++) {
            var stgCol = stages[sIdx]
            var leftX = stgCol.x - 550
            ctx.beginPath()
            ctx.moveTo(leftX, 20)
            ctx.lineTo(leftX, 3500)
            ctx.stroke()
        }
        ctx.restore()
    }

    // 2.5 Отрисовка группирующих скобок этапов/актов
    renderGroups(ctx, groups, labelFontFamily)

    // 3. Вычисление причинно-следственного конуса предыстории (Causal Upstream Cone)
    var targetStation = null
    var directTracks = {}
    var predecessorStationIds = {}
    var indirectTrackCutoffs = {} // trackId -> maxX where it entered predecessor station

    if (hoveredStationId) {
        for (var hs = 0; hs < stations.length; hs++) {
            if (stations[hs].id === hoveredStationId) {
                targetStation = stations[hs]
                break
            }
        }
        if (targetStation && targetStation.tracks) {
            for (var ht = 0; ht < targetStation.tracks.length; ht++) {
                directTracks[targetStation.tracks[ht]] = true
            }

            // Находим все станции-предшественники, расположенные левее (в прошлом),
            // через которые проходили прямые ветки целевой станции
            for (var bs = 0; bs < stations.length; bs++) {
                var bSt = stations[bs]
                if (bSt.x < targetStation.x - 4 && bSt.tracks) {
                    var connectsToDirect = false
                    for (var bt = 0; bt < bSt.tracks.length; bt++) {
                        if (directTracks[bSt.tracks[bt]]) {
                            connectsToDirect = true
                            break
                        }
                    }
                    if (connectsToDirect) {
                        predecessorStationIds[bSt.id] = true
                        // Любая другая ветка, участвовавшая в этой предшествующей сцене,
                        // является притоком (tributary) предыстории до момента этой сцены!
                        for (var ot = 0; ot < bSt.tracks.length; ot++) {
                            var oTrack = bSt.tracks[ot]
                            if (!directTracks[oTrack]) {
                                var prevCut = indirectTrackCutoffs[oTrack] || 0
                                if (bSt.x > prevCut) {
                                    indirectTrackCutoffs[oTrack] = bSt.x
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // 4. Отрисовка соединительных линий (Segments) плавными кривыми Безье
    ctx.lineCap = "round"
    ctx.lineJoin = "round"

    for (var i = 0; i < segments.length; i++) {
        var seg = segments[i]
        var segAlpha = lineRestingAlpha
        var segLineWidth = lineWidth

        if (targetStation) {
            // Режим фокуса на станции: конус предыстории
            if (directTracks[seg.track_id]) {
                if (seg.to_x <= targetStation.x + 8) {
                    segAlpha = lineHighlightAlpha // Входящая ветка к станции — яркость 100%
                    segLineWidth = lineWidth + 1.6
                } else {
                    segAlpha = lineDimmedAlpha // Выходящая ветка (будущее после сцены) — затемнено
                    segLineWidth = lineWidth * 0.85
                }
            } else if (indirectTrackCutoffs[seg.track_id]) {
                var cutoffX = indirectTrackCutoffs[seg.track_id]
                if (seg.to_x <= cutoffX + 8) {
                    segAlpha = lineTributaryAlpha // Косвенный приток-предшественник — средняя яркость
                    segLineWidth = lineWidth + 0.4
                } else {
                    segAlpha = lineDimmedAlpha
                    segLineWidth = lineWidth * 0.85
                }
            } else {
                segAlpha = lineDimmedAlpha
                segLineWidth = lineWidth * 0.85
            }
        } else if (hoveredTrackId) {
            // Режим фокуса на ветке: подсветка всей линии
            if (seg.track_id === hoveredTrackId) {
                segAlpha = lineHighlightAlpha
                segLineWidth = lineWidth + 1.8
            } else {
                segAlpha = lineDimmedAlpha
                segLineWidth = lineWidth * 0.85
            }
        }

        ctx.globalAlpha = segAlpha
        ctx.lineWidth = segLineWidth
        ctx.strokeStyle = seg.color || "#A1A1AA"
        ctx.beginPath()
        drawSmoothTransitLine(ctx, seg.from_x, seg.from_y, seg.to_x, seg.to_y)
        ctx.stroke()

        // Начальная точка линии — круг (Start Node)
        if (seg.is_entry) {
            var startRad = stationRadius + 1.0
            ctx.beginPath()
            ctx.arc(seg.from_x, seg.from_y, startRad, 0, Math.PI * 2)
            ctx.fillStyle = stFillColor
            ctx.fill()
            ctx.lineWidth = stBorderWidth
            ctx.strokeStyle = seg.color || stBorderColor
            ctx.stroke()

            // Внутреннее заполнение стартового круга (акцент цвета линии)
            ctx.beginPath()
            ctx.arc(seg.from_x, seg.from_y, startRad - 3.2, 0, Math.PI * 2)
            ctx.fillStyle = seg.color || "#A1A1AA"
            ctx.fill()
        }

        // Конечная точка тупика линии
        if (seg.is_exit) {
            ctx.beginPath()
            ctx.arc(seg.to_x, seg.to_y, 4, 0, Math.PI * 2)
            ctx.fillStyle = seg.color || "#A1A1AA"
            ctx.fill()
        }
    }
    ctx.globalAlpha = 1.0

    // 5. Отрисовка плашек названий линий (Track Badges) слева
    renderTrackBadges(ctx, tracks, stations, labelFontFamily, hoveredTrackId, directTracks, indirectTrackCutoffs)

    // 6. Отрисовка станций в форме ромба (Rhombus / Diamond)
    var fontMain = "600 " + labelFontSize + "px " + labelFontFamily

    for (var s = 0; s < stations.length; s++) {
        var st = stations[s]
        var isHov = (st.id === hoveredStationId)
        var isCurrent = (activeFileUrl && st.file_url === activeFileUrl)
        var isPredecessor = !!predecessorStationIds[st.id]
        var isOnHoveredTrack = (hoveredTrackId && st.tracks && st.tracks.indexOf(hoveredTrackId) !== -1)

        var stAlpha = 0.85
        if (targetStation) {
            if (isHov) stAlpha = 1.0
            else if (isPredecessor) stAlpha = 0.95
            else stAlpha = 0.16
        } else if (hoveredTrackId) {
            stAlpha = isOnHoveredTrack ? 1.0 : 0.16
        } else {
            stAlpha = isCurrent ? 1.0 : 0.85
        }

        ctx.globalAlpha = stAlpha

        var rad = st.is_interchange ? interchangeRadius : stationRadius
        var rSize = rad * 1.25

        // Внешнее свечение при наведении или активном файле
        if (isHov || isCurrent || isOnHoveredTrack) {
            ctx.beginPath()
            drawRhombus(ctx, st.x, st.y, rSize + 6, rSize + 6)
            ctx.fillStyle = isCurrent ? "rgba(228, 228, 231, 0.35)" : "rgba(255, 255, 255, 0.22)"
            ctx.fill()
        } else if (isPredecessor) {
            ctx.beginPath()
            drawRhombus(ctx, st.x, st.y, rSize + 4, rSize + 4)
            ctx.fillStyle = "rgba(228, 228, 231, 0.18)"
            ctx.fill()
        }

        // Станция в форме ромба
        ctx.beginPath()
        drawRhombus(ctx, st.x, st.y, rSize, rSize)
        ctx.fillStyle = stFillColor
        ctx.fill()
        ctx.lineWidth = stBorderWidth
        ctx.strokeStyle = (isHov || isCurrent || isOnHoveredTrack) ? "#FFFFFF" : (isPredecessor ? "#E4E4E7" : stBorderColor)
        ctx.stroke()

        // Внутренний акцент для пересадочных станций (Interchange)
        if (st.is_interchange) {
            ctx.beginPath()
            drawRhombus(ctx, st.x, st.y, rSize - 4, rSize - 4)
            ctx.fillStyle = stBorderColor
            ctx.fill()
        }

        // 7. Подписи к станциям (Level of Detail)
        var showText = (zoomScale >= 0.58) || isHov || isCurrent || isPredecessor || isOnHoveredTrack

        if (showText && stAlpha > 0.3) {
            ctx.textAlign = "center"

            // Годы над станцией (если есть)
            if (st.date_str) {
                ctx.font = "bold 10px " + labelFontFamily
                ctx.textBaseline = "bottom"
                ctx.fillStyle = (isHov || isPredecessor) ? "#FFFFFF" : labelSubColor
                ctx.fillText(st.date_str, st.x, st.y - rSize - 4)
            }

            // Название под станцией с полупрозрачной подложкой против перекрытия линий
            var titleText = st.title
            ctx.font = fontMain
            ctx.textBaseline = "top"
            var titleY = st.y + rSize + 7

            var textW = ctx.measureText(titleText).width
            ctx.fillStyle = "rgba(18, 18, 18, 0.82)"
            ctx.beginPath()
            roundRect(ctx, st.x - textW / 2 - 5, titleY - 2, textW + 10, labelFontSize + 4, 3)
            ctx.fill()

            ctx.fillStyle = (isHov || isCurrent || isPredecessor || isOnHoveredTrack) ? "#FFFFFF" : labelColor
            ctx.fillText(titleText, st.x, titleY)
        }
    }
    ctx.globalAlpha = 1.0

    ctx.restore()
}

/**
 * Отрисовка плавной транзитной реки Безье (Smooth Cubic Spline)
 */
function drawSmoothTransitLine(ctx, x1, y1, x2, y2) {
    if (Math.abs(y1 - y2) < 1.0) {
        ctx.moveTo(x1, y1)
        ctx.lineTo(x2, y2)
        return
    }

    var dx = x2 - x1
    var cp1x = x1 + dx * 0.45
    var cp2x = x2 - dx * 0.45
    ctx.moveTo(x1, y1)
    ctx.bezierCurveTo(cp1x, y1, cp2x, y2, x2, y2)
}

/**
 * Отрисовка 45-градусной линии метро со скруглением углов
 */
function drawBeveledMetroLine(ctx, x1, y1, x2, y2, radius) {
    if (Math.abs(y1 - y2) < 1.0) {
        // Строго горизонтальная линия
        ctx.moveTo(x1, y1)
        ctx.lineTo(x2, y2)
        return
    }

    var dx = x2 - x1
    var dy = y2 - y1
    var absDy = Math.abs(dy)
    var r = Math.min(radius, absDy / 2, dx / 4)

    // Точка начала 45° диагонали
    // Диагональ имеет ширину absDy по горизонтали, чтобы угол был ровно 45°
    var midX1 = x1 + Math.max(20, (dx - absDy) * 0.4)
    var midX2 = midX1 + absDy
    var signY = dy > 0 ? 1 : -1

    ctx.moveTo(x1, y1)
    ctx.lineTo(midX1 - r, y1)
    // Плавный поворот в 45° скос
    ctx.quadraticCurveTo(midX1, y1, midX1 + r * 0.7, y1 + signY * r * 0.7)
    ctx.lineTo(midX2 - r * 0.7, y2 - signY * r * 0.7)
    // Плавный выход из скоса в горизонталь
    ctx.quadraticCurveTo(midX2, y2, midX2 + r, y2)
    ctx.lineTo(x2, y2)
}

/**
 * Отрисовка бейджей линий (Track Badges) в начале веток
 */
function renderTrackBadges(ctx, tracks, stations, fontFamily, hoveredTrackId, directTracks, indirectTracks) {
    if (!tracks || tracks.length === 0 || !stations || stations.length === 0) return

    ctx.font = "bold 11px " + fontFamily
    ctx.textBaseline = "middle"

    var hasDirect = directTracks && Object.keys(directTracks).length > 0

    for (var i = 0; i < tracks.length; i++) {
        var tr = tracks[i]
        if (!tr.station_ids || tr.station_ids.length === 0) continue

        // Находим первую станцию этой линии
        var firstSt = null
        for (var s = 0; s < stations.length; s++) {
            if (stations[s].id === tr.station_ids[0]) {
                firstSt = stations[s]
                break
            }
        }
        if (!firstSt) continue

        var badgeX = (tr.badge_x !== undefined) ? tr.badge_x : (firstSt.x - 45)
        var badgeY = (tr.badge_y !== undefined) ? tr.badge_y : firstSt.y
        var text = tr.title || tr.id
        var textW = ctx.measureText(text).width
        var badgeW = Math.max(40, textW + 16)
        var badgeH = 20

        var isTrHov = (hoveredTrackId === tr.id)
        var isDirect = directTracks && directTracks[tr.id]
        var isIndirect = indirectTracks && indirectTracks[tr.id]

        var badgeAlpha = 0.70
        if (hoveredTrackId) {
            badgeAlpha = isTrHov ? 1.0 : 0.20
        } else if (hasDirect) {
            if (isDirect) badgeAlpha = 1.0
            else if (isIndirect) badgeAlpha = 0.65
            else badgeAlpha = 0.18
        }

        ctx.save()
        ctx.globalAlpha = badgeAlpha

        // Фон плашки ветки: темная монохромная плашка с аккуратной рамкой цвета ветки
        ctx.beginPath()
        roundRect(ctx, badgeX - badgeW, badgeY - badgeH / 2, badgeW, badgeH, 10)
        ctx.fillStyle = (isTrHov || isDirect) ? "#27272A" : "#18181B"
        ctx.fill()
        ctx.lineWidth = (isTrHov || isDirect) ? 2.0 : 1.5
        ctx.strokeStyle = (isTrHov || isDirect) ? "#FFFFFF" : (tr.color || "#71717A")
        ctx.stroke()

        // Текст названия ветки
        ctx.fillStyle = (isTrHov || isDirect) ? "#FFFFFF" : "#FAFAFA"
        ctx.textAlign = "center"
        ctx.fillText(text, badgeX - badgeW / 2, badgeY)
        ctx.restore()
    }
}

/**
 * Отрисовка группирующих скобок иерархии блоков (Том -> Акт -> Глава)
 */
function renderGroups(ctx, groups, fontFamily) {
    if (!groups || groups.length === 0) return

    ctx.save()
    for (var i = 0; i < groups.length; i++) {
        var g = groups[i]
        var fromX = g.from_x
        var toX = g.to_x
        var y = g.y
        var depth = g.depth || 0
        var title = g.title || ""

        // Стилизация по уровню вложенности:
        // Уровень 0 (Том) — чуть более заметный, уровни глубже (Акт, Глава) — деликатнее
        var strokeCol = (depth === 0) ? "rgba(161, 161, 170, 0.45)" : "rgba(113, 113, 122, 0.3)"
        var textCol = (depth === 0) ? "#E4E4E7" : "#A1A1AA"
        var fontSize = (depth === 0) ? 11 : 10
        ctx.font = (depth === 0 ? "600 " : "500 ") + fontSize + "px " + fontFamily

        var textW = ctx.measureText(title).width
        var centerX = (fromX + toX) / 2
        var minW = textW + 24
        if (toX - fromX < minW) {
            fromX = centerX - minW / 2
            toX = centerX + minW / 2
        }

        var pad = 6
        var textLeft = centerX - textW / 2 - pad
        var textRight = centerX + textW / 2 + pad
        var tickH = 6

        // Рисуем скобку: левый хвостик вниз, левая горизонталь, пропуск под текст, правая горизонталь, правый хвостик вниз
        ctx.beginPath()
        ctx.strokeStyle = strokeCol
        ctx.lineWidth = 1.2
        ctx.lineCap = "round"

        // Левая часть скобки
        ctx.moveTo(fromX, y + tickH)
        ctx.lineTo(fromX, y)
        ctx.lineTo(textLeft, y)

        // Правая часть скобки
        ctx.moveTo(textRight, y)
        ctx.lineTo(toX, y)
        ctx.lineTo(toX, y + tickH)
        ctx.stroke()

        // Текст заголовка группы
        ctx.textAlign = "center"
        ctx.textBaseline = "middle"
        ctx.fillStyle = textCol
        ctx.fillText(title, centerX, y)
    }
    ctx.restore()
}

/**
 * Вспомогательная функция рисования скругленного прямоугольника
 */
function roundRect(ctx, x, y, w, h, r) {
    ctx.moveTo(x + r, y)
    ctx.arcTo(x + w, y, x + w, y + h, r)
    ctx.arcTo(x + w, y + h, x, y + h, r)
    ctx.arcTo(x, y + h, x, y, r)
    ctx.arcTo(x, y, x + w, y, r)
    ctx.closePath()
}

/**
 * Отрисовка ромба (Diamond / Rhombus) с центром в (cx, cy)
 */
function drawRhombus(ctx, cx, cy, rx, ry) {
    if (ry === undefined) ry = rx
    ctx.moveTo(cx, cy - ry)
    ctx.lineTo(cx + rx, cy)
    ctx.lineTo(cx, cy + ry)
    ctx.lineTo(cx - rx, cy)
    ctx.closePath()
}

/**
 * Поиск станции под курсором мыши (Hit-Testing)
 */
function findStationAt(stations, screenX, screenY, panX, panY, zoomScale) {
    if (!stations || stations.length === 0) return null

    var worldX = (screenX - panX) / zoomScale
    var worldY = (screenY - panY) / zoomScale
    var hitRadius = 22 // Щедрая зона клика для комфорта

    for (var i = 0; i < stations.length; i++) {
        var st = stations[i]
        var dx = worldX - st.x
        var dy = worldY - st.y
        if ((dx * dx + dy * dy) <= (hitRadius * hitRadius)) {
            return st
        }
    }
    return null
}

/**
 * Поиск бейджа линии под курсором
 */
function findTrackBadgeAt(tracks, stations, worldX, worldY) {
    if (!tracks || tracks.length === 0 || !stations || stations.length === 0) return null

    for (var i = 0; i < tracks.length; i++) {
        var tr = tracks[i]
        if (!tr.station_ids || tr.station_ids.length === 0) continue

        var firstSt = null
        for (var s = 0; s < stations.length; s++) {
            if (stations[s].id === tr.station_ids[0]) {
                firstSt = stations[s]
                break
            }
        }
        if (!firstSt) continue

        var badgeX = (tr.badge_x !== undefined) ? tr.badge_x : (firstSt.x - 45)
        var badgeY = (tr.badge_y !== undefined) ? tr.badge_y : firstSt.y
        var text = tr.title || tr.id
        var approxW = Math.max(40, text.length * 8 + 16)
        var badgeH = 22

        if (worldX >= badgeX - approxW - 6 && worldX <= badgeX + 6 &&
            worldY >= badgeY - badgeH / 2 - 4 && worldY <= badgeY + badgeH / 2 + 4) {
            return tr.id
        }
    }
    return null
}

/**
 * Поиск сегмента линии под курсором с расчетом дистанции до кубической кривой Безье
 */
function findSegmentTrackAt(segments, worldX, worldY, hitDist) {
    if (!segments || segments.length === 0) return null
    var bestTrackId = null
    var bestDist = hitDist || 10

    for (var i = 0; i < segments.length; i++) {
        var seg = segments[i]
        var x1 = seg.from_x
        var y1 = seg.from_y
        var x2 = seg.to_x
        var y2 = seg.to_y

        var minX = Math.min(x1, x2) - bestDist
        var maxX = Math.max(x1, x2) + bestDist
        var minY = Math.min(y1, y2) - bestDist
        var maxY = Math.max(y1, y2) + bestDist

        if (worldX < minX || worldX > maxX || worldY < minY || worldY > maxY) {
            continue
        }

        var dx = x2 - x1
        if (Math.abs(y1 - y2) < 1.0 || Math.abs(dx) < 1.0) {
            var distStraight = Math.abs(worldY - y1)
            if (distStraight < bestDist) {
                bestDist = distStraight
                bestTrackId = seg.track_id
            }
            continue
        }

        // Аналитический расчет высоты на кубической кривой Безье (Smoothstep)
        var t = (worldX - x1) / dx
        if (t < 0) t = 0
        if (t > 1) t = 1
        var s = t * t * (3 - 2 * t)
        var yCurve = y1 + (y2 - y1) * s
        var distCurve = Math.abs(worldY - yCurve)
        if (distCurve < bestDist) {
            bestDist = distCurve
            bestTrackId = seg.track_id
        }
    }
    return bestTrackId
}

/**
 * Единый поиск линии (бейдж или сплайн) под курсором
 */
function findTrackAt(tracks, segments, stations, screenX, screenY, panX, panY, zoomScale) {
    var worldX = (screenX - panX) / zoomScale
    var worldY = (screenY - panY) / zoomScale

    // 1. Проверяем бейджи линий
    var badgeId = findTrackBadgeAt(tracks, stations, worldX, worldY)
    if (badgeId) return badgeId

    // 2. Проверяем сегменты с динамическим порогом
    var hitDist = Math.max(9, 13 / zoomScale)
    return findSegmentTrackAt(segments, worldX, worldY, hitDist)
}

/**
 * Расчет панорамирования и масштаба для центрирования всей схемы
 */
function fitToBounds(bounds, viewWidth, viewHeight) {
    if (!bounds || bounds.width <= 0 || bounds.height <= 0) {
        return { panX: 50, panY: 50, zoomScale: 1.0 }
    }

    var padding = 80
    var availW = Math.max(100, viewWidth - padding * 2)
    var availH = Math.max(100, viewHeight - padding * 2)

    var scaleX = availW / bounds.width
    var scaleY = availH / bounds.height
    var scale = Math.min(1.2, Math.max(0.4, Math.min(scaleX, scaleY)))

    var centerX = bounds.min_x + bounds.width / 2
    var centerY = bounds.min_y + bounds.height / 2

    var pX = (viewWidth / 2) - centerX * scale
    var pY = (viewHeight / 2) - centerY * scale

    return { panX: pX, panY: pY, zoomScale: scale }
}
