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

    // 4. Отрисовка соединительных линий (Segments) в 2 прохода
    // Исключает потемнение на пересечениях и масштабирует толщину магистралей (Bundling)
    ctx.lineCap = "round"
    ctx.lineJoin = "round"
    ctx.globalAlpha = 1.0

    // 4.1 Группировка сегментов по коридорам: несколько веток между двумя станциями идут параллельными путями
    var corridorSegments = {}
    for (var ci = 0; ci < segments.length; ci++) {
        var s = segments[ci]
        if (!s.is_entry && s.from_id && s.to_id) {
            var cKey = s.from_id + "->" + s.to_id
            if (!corridorSegments[cKey]) corridorSegments[cKey] = []
            corridorSegments[cKey].push(s)
        }
    }

    var pass1Segments = []
    var pass2Segments = []

    var COLOR_ACTIVE    = "#FFFFFF"  // 100% чистый белый для активной ветки к сцене
    var COLOR_TRIBUTARY = "#63636E"  // Сдержанный графит для предшествующих притоков
    var COLOR_RESTING   = "#404044"  // Однородный темный графит для дефолтного состояния
    var COLOR_DIMMED    = "#222226"  // Фоновый глубокий антрацит для неактивных линий

    for (var i = 0; i < segments.length; i++) {
        var seg = segments[i]
        var segColor = COLOR_RESTING
        var isPass2 = false

        // Расчет вертикального смещения и адаптивной ширины внутри коридора
        var cCount = 1
        var k = 0
        var isCorridorActive = false

        if (!seg.is_entry && seg.from_id && seg.to_id) {
            var cList = corridorSegments[seg.from_id + "->" + seg.to_id] || [seg]
            cCount = cList.length
            k = cList.indexOf(seg)
            if (k === -1) k = 0

            // Коридор раскрывается на параллельные нити ТОЛЬКО при наведении на него
            if (hoveredTrackId) {
                for (var ch = 0; ch < cList.length; ch++) {
                    if (cList[ch].track_id === hoveredTrackId) {
                        isCorridorActive = true
                        break
                    }
                }
            } else if (targetStation) {
                for (var cs = 0; cs < cList.length; cs++) {
                    var tId = cList[cs].track_id
                    if (directTracks[tId] || indirectTrackCutoffs[tId]) {
                        isCorridorActive = true
                        break
                    }
                }
            }
        }

        var baseW = lineWidth || 3.6
        var bundleW = (cCount > 1) ? Math.min(6.0, baseW + (cCount - 1) * 1.2) : baseW
        var subW = (cCount > 1) ? (bundleW / cCount) : baseW
        var trackWidth = baseW
        var offset = 0

        if (cCount > 1 && isCorridorActive) {
            // ИНТЕРАКТИВНЫЙ РЕЖИМ: нити плотно прилегают друг к другу без пустого пространства (щелей),
            // а общая толщина коридора остается неизменной (subW * cCount === bundleW)
            trackWidth = subW
            offset = (k - (cCount - 1) / 2.0) * subW
        } else if (cCount > 1) {
            // РЕЖИМ ПОКОЯ: единая монолитная магистраль без разрывов
            offset = 0
            trackWidth = bundleW
        }

        seg.offsetY = offset
        var segLineWidth = trackWidth

        if (targetStation) {
            // Режим фокуса на станции: конус причинно-следственной связи
            if (directTracks[seg.track_id]) {
                if (seg.to_x <= targetStation.x + 8) {
                    segColor = COLOR_ACTIVE
                    segLineWidth = trackWidth
                    isPass2 = true
                } else {
                    segColor = COLOR_DIMMED
                    segLineWidth = trackWidth * 0.8
                }
            } else if (indirectTrackCutoffs[seg.track_id]) {
                var cutoffX = indirectTrackCutoffs[seg.track_id]
                if (seg.to_x <= cutoffX + 8) {
                    segColor = COLOR_TRIBUTARY
                    segLineWidth = trackWidth
                    isPass2 = true
                } else {
                    segColor = COLOR_DIMMED
                    segLineWidth = trackWidth * 0.8
                }
            } else {
                segColor = COLOR_DIMMED
                segLineWidth = trackWidth * 0.8
            }
        } else if (hoveredTrackId) {
            // Режим фокуса на линии
            if (seg.track_id === hoveredTrackId) {
                segColor = COLOR_ACTIVE
                segLineWidth = trackWidth
                isPass2 = true
            } else if (isCorridorActive) {
                // Нити-спутники в активном коридоре видны рядом в сдержанном тоне
                segColor = "#52525B"
                segLineWidth = trackWidth
            } else {
                segColor = COLOR_DIMMED
                segLineWidth = trackWidth * 0.8
            }
        }

        var segItem = { seg: seg, color: segColor, width: segLineWidth }
        if (isPass2) {
            pass2Segments.push(segItem)
        } else {
            pass1Segments.push(segItem)
        }
    }

    // Проход 1: фоновые и пассивные параллельные нити
    for (var p1 = 0; p1 < pass1Segments.length; p1++) {
        var it1 = pass1Segments[p1]
        var off1 = it1.seg.offsetY || 0
        ctx.lineWidth = it1.width
        ctx.strokeStyle = it1.color
        ctx.beginPath()
        if (it1.seg.is_entry) {
            drawBeveledMetroLine(ctx, it1.seg.from_x, it1.seg.from_y + off1, it1.seg.to_x, it1.seg.to_y + off1, 12)
        } else {
            drawSmoothTransitLine(ctx, it1.seg.from_x, it1.seg.from_y + off1, it1.seg.to_x, it1.seg.to_y + off1)
        }
        ctx.stroke()
    }

    // Проход 2: активные и притоковые нити строго ПОВЕРХ фоновых с ярким акцентом
    for (var p2 = 0; p2 < pass2Segments.length; p2++) {
        var it2 = pass2Segments[p2]
        var off2 = it2.seg.offsetY || 0
        ctx.lineWidth = it2.width
        ctx.strokeStyle = it2.color
        ctx.beginPath()
        if (it2.seg.is_entry) {
            drawBeveledMetroLine(ctx, it2.seg.from_x, it2.seg.from_y + off2, it2.seg.to_x, it2.seg.to_y + off2, 12)
        } else {
            drawSmoothTransitLine(ctx, it2.seg.from_x, it2.seg.from_y + off2, it2.seg.to_x, it2.seg.to_y + off2)
        }
        ctx.stroke()
    }

    // 5. Отрисовка начала линий и плашек сущностей (@Сущность)
    var indirectTracks = {}
    for (var indTr in indirectTrackCutoffs) {
        indirectTracks[indTr] = true
    }
    renderTrackBadges(ctx, tracks, stations, labelFontFamily, hoveredTrackId, directTracks, indirectTracks)
    ctx.globalAlpha = 1.0

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
        var showText = (zoomScale >= 0.28) || isHov || isCurrent || isPredecessor || isOnHoveredTrack

        if (showText && stAlpha > 0.3) {
            // Название под станцией без карточки/плашки
            ctx.font = fontMain
            ctx.textAlign = "center"
            ctx.textBaseline = "top"
            var startTitleY = st.y + rSize + 7

            var titleLines = wrapText(ctx, st.title, 160)
            var lineH = labelFontSize + 3

            ctx.fillStyle = (isHov || isCurrent || isPredecessor || isOnHoveredTrack) ? "#FFFFFF" : labelColor
            for (var tl2 = 0; tl2 < titleLines.length; tl2++) {
                ctx.fillText(titleLines[tl2], st.x, startTitleY + tl2 * lineH)
            }
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
    var signY = dy > 0 ? 1 : -1

    // Полка перед станцией
    var endShelf = 16
    var midX2 = x2 - endShelf
    // Диагональ имеет ровно 45 градусов: DeltaX = absDy
    var midX1 = midX2 - absDy

    // Защита, если горизонтальный отрезок слишком короткий
    if (midX1 < x1 + 4) {
        var availDx = dx - absDy
        if (availDx > 0) {
            midX1 = x1 + availDx * 0.4
            midX2 = midX1 + absDy
        } else {
            drawSmoothTransitLine(ctx, x1, y1, x2, y2)
            return
        }
    }

    var leadLen = midX1 - x1
    var tailLen = x2 - midX2
    var r = Math.min(radius || 10, absDy * 0.45, leadLen * 0.45, tailLen * 0.45)

    ctx.moveTo(x1, y1)
    if (r > 1.0) {
        ctx.lineTo(midX1 - r, y1)
        ctx.quadraticCurveTo(midX1, y1, midX1 + r * 0.707, y1 + signY * r * 0.707)
        ctx.lineTo(midX2 - r * 0.707, y2 - signY * r * 0.707)
        ctx.quadraticCurveTo(midX2, y2, midX2 + r, y2)
    } else {
        ctx.lineTo(midX1, y1)
        ctx.lineTo(midX2, y2)
    }
    ctx.lineTo(x2, y2)
}

/**
 * Отрисовка бейджей линий (Track Badges) в начале веток
 */
/**
 * Отрисовка начала линий (Terminal Dot) и плашек сущностей (@Сущность)
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

        var badgeX = (tr.badge_x !== undefined) ? tr.badge_x : (firstSt.x - 60)
        var badgeY = (tr.badge_y !== undefined) ? tr.badge_y : firstSt.y
        var text = (tr.badge_title || tr.title || tr.id).replace(/^@/, "").replace(/_/g, " ")

        var isTrHov = (hoveredTrackId === tr.id)
        var isDirect = directTracks && directTracks[tr.id]
        var isIndirect = indirectTracks && indirectTracks[tr.id]

        var textColor = "#A1A1AA"
        var dotColor = "#52525B"

        if (hoveredTrackId) {
            if (isTrHov) {
                textColor = "#FFFFFF"
                dotColor = "#FFFFFF"
            } else {
                textColor = "#3F3F46"
                dotColor = "#222226"
            }
        } else if (hasDirect) {
            if (isDirect) {
                textColor = "#FFFFFF"
                dotColor = "#FFFFFF"
            } else if (isIndirect) {
                textColor = "#8E8E96"
                dotColor = "#63636E"
            } else {
                textColor = "#3F3F46"
                dotColor = "#222226"
            }
        }

        ctx.save()
        ctx.globalAlpha = 1.0

        // Стартовая точка начала ветки
        ctx.beginPath()
        ctx.arc(badgeX, badgeY, 3.5, 0, Math.PI * 2)
        ctx.fillStyle = dotColor
        ctx.fill()

        // Плашка сущности слева от стартовой точки
        var textW = ctx.measureText(text).width
        var badgeW = Math.max(32, textW + 14)
        var badgeH = 18
        var pillRight = badgeX - 6
        var pillLeft = pillRight - badgeW
        var pillTop = badgeY - badgeH / 2

        ctx.fillStyle = (isTrHov || isDirect) ? "#27272A" : "#18181B"
        ctx.beginPath()
        roundRect(ctx, pillLeft, pillTop, badgeW, badgeH, 4)
        ctx.fill()
        ctx.lineWidth = (isTrHov || isDirect) ? 1.5 : 1.0
        ctx.strokeStyle = (isTrHov || isDirect) ? "#FFFFFF" : "#3F3F46"
        ctx.stroke()

        // Текст названия сущности
        ctx.fillStyle = textColor
        ctx.textAlign = "center"
        ctx.textBaseline = "middle"
        ctx.fillText(text, pillLeft + badgeW / 2, badgeY)
        ctx.restore()
    }
}

/**
 * Отрисовка группирующих фигурных скобок {} для параллельных станций
 */
function renderGroups(ctx, groups, fontFamily) {
    if (!groups || groups.length === 0) return

    ctx.save()
    ctx.lineCap = "round"
    ctx.lineJoin = "round"
    ctx.globalAlpha = 1.0

    for (var i = 0; i < groups.length; i++) {
        var g = groups[i]
        if (g.top_y === undefined || g.bottom_y === undefined || g.station_count <= 1) continue

        var topY = g.top_y
        var bottomY = g.bottom_y
        var midY = (topY + bottomY) / 2
        var bx = g.x - 30
        var braceW = 10

        var q1Y = (topY + midY) / 2
        var q2Y = (midY + bottomY) / 2

        // Элегантная вертикальная фигурная скобка {
        ctx.beginPath()
        ctx.strokeStyle = "rgba(161, 161, 170, 0.45)"
        ctx.lineWidth = 1.5

        // Верхнее полукрыло {
        ctx.moveTo(bx + braceW, topY)
        ctx.bezierCurveTo(bx + braceW * 0.2, topY, bx, q1Y, bx, midY)
        // Нижнее полукрыло {
        ctx.bezierCurveTo(bx, q2Y, bx + braceW * 0.2, bottomY, bx + braceW, bottomY)
        ctx.stroke()

        // Подпись года группы { 1453 } слева от острия скобки
        if (g.title) {
            var text = "{ " + g.title + " }"
            ctx.font = "bold 11px " + fontFamily
            var tw = ctx.measureText(text).width

            ctx.fillStyle = "rgba(18, 18, 20, 0.88)"
            ctx.beginPath()
            roundRect(ctx, bx - tw - 12, midY - 9, tw + 8, 18, 4)
            ctx.fill()

            ctx.fillStyle = "#E4E4E7"
            ctx.textAlign = "right"
            ctx.textBaseline = "middle"
            ctx.fillText(text, bx - 8, midY)
        }
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
        var text = (tr.badge_title || tr.title || tr.id).replace(/^@/, "").replace(/_/g, " ")
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

    // Обеспечиваем учет параллельных нитей коридоров
    var corridorSegments = {}
    for (var ci = 0; ci < segments.length; ci++) {
        var s = segments[ci]
        if (!s.is_entry && s.from_id && s.to_id) {
            var cKey = s.from_id + "->" + s.to_id
            if (!corridorSegments[cKey]) corridorSegments[cKey] = []
            corridorSegments[cKey].push(s)
        }
    }

    for (var i = 0; i < segments.length; i++) {
        var seg = segments[i]
        var offY = 0

        if (!seg.is_entry && seg.from_id && seg.to_id) {
            var cList = corridorSegments[seg.from_id + "->" + seg.to_id] || [seg]
            var cCount = cList.length
            var k = cList.indexOf(seg)
            if (k === -1) k = 0
            if (cCount > 1) {
                var baseW = 3.6
                var bundleW = Math.min(6.0, baseW + (cCount - 1) * 1.2)
                var subW = bundleW / cCount
                offY = (k - (cCount - 1) / 2.0) * subW
            }
        }

        var x1 = seg.from_x
        var y1 = seg.from_y + offY
        var x2 = seg.to_x
        var y2 = seg.to_y + offY

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

    var padding = 60
    var availW = Math.max(100, viewWidth - padding * 2)
    var availH = Math.max(100, viewHeight - padding * 2)

    var scaleX = availW / bounds.width
    var scaleY = availH / bounds.height
    var scale = Math.min(1.1, Math.max(0.28, Math.min(scaleX, scaleY)))

    var centerX = bounds.min_x + bounds.width / 2
    var centerY = bounds.min_y + bounds.height / 2

    var pX = (viewWidth / 2) - centerX * scale
    var pY = (viewHeight / 2) - centerY * scale

    return { panX: pX, panY: pY, zoomScale: scale }
}

/**
 * Разбивка длинного текста на строки с ограничением максимальной ширины
 */
function wrapText(ctx, text, maxWidth) {
    if (!text) return []
    var cleanText = text.replace(/_/g, " ")
    var words = cleanText.split(" ")
    if (words.length <= 1) return [cleanText]

    var lines = []
    var curLine = words[0]

    for (var i = 1; i < words.length; i++) {
        var word = words[i]
        var testLine = curLine + " " + word
        if (ctx.measureText(testLine).width <= maxWidth) {
            curLine = testLine
        } else {
            lines.push(curLine)
            curLine = word
        }
    }
    lines.push(curLine)
    return lines
}
