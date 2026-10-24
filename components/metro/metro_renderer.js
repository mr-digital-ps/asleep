// components/metro/metro_renderer.js — Рендерер схемы метро сюжета (Metro Transit Map)
.pragma library

/**
 * Отрисовка схемы линий метро на HTML5 Canvas
 */
function renderMetro(ctx, width, height, metroData, config, panX, panY, zoomScale, hoveredStationId, activeFileUrl) {
    if (!ctx) return

    ctx.save()
    ctx.clearRect(0, 0, width, height)

    var visual = (config && config.visual) ? config.visual : {}
    var lineWidth = visual.lineWidth || 4.5
    var stationRadius = visual.stationRadius || 6.5
    var interchangeRadius = visual.interchangeRadius || 9.0
    var stBorderWidth = visual.stationBorderWidth || 2.5
    var stBorderColor = visual.stationBorderColor || "#18181B"
    var stFillColor = visual.stationFillColor || "#FFFFFF"
    var labelFontSize = visual.labelFontSize || 12
    var labelFontFamily = visual.labelFontFamily || "Segoe UI, Inter, sans-serif"
    var labelColor = visual.labelColor || "#E2E8F0"
    var labelSubColor = visual.labelSubColor || "#94A3B8"
    var showGrid = visual.showGrid !== false
    var gridColor = visual.gridColor || "rgba(255, 255, 255, 0.04)"
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

    // 3. Отрисовка соединительных линий (Segments) со скруглениями 45°
    ctx.lineCap = "round"
    ctx.lineJoin = "round"
    ctx.lineWidth = lineWidth

    for (var i = 0; i < segments.length; i++) {
        var seg = segments[i]
        ctx.strokeStyle = seg.color || "#A1A1AA"
        ctx.beginPath()
        drawBeveledMetroLine(ctx, seg.from_x, seg.from_y, seg.to_x, seg.to_y, 14)
        ctx.stroke()
    }

    // 4. Отрисовка плашек названий линий (Track Badges) слева
    renderTrackBadges(ctx, tracks, stations, labelFontFamily)

    // 5. Отрисовка станций (Stations)
    var fontMain = "600 " + labelFontSize + "px " + labelFontFamily
    var fontSub = "400 " + (labelFontSize - 2) + "px " + labelFontFamily

    for (var s = 0; s < stations.length; s++) {
        var st = stations[s]
        var isHov = (st.id === hoveredStationId)
        var isCurrent = (activeFileUrl && st.file_url === activeFileUrl)
        var rad = st.is_interchange ? interchangeRadius : stationRadius

        // Внешнее свечение при наведении или активном файле
        if (isHov || isCurrent) {
            ctx.beginPath()
            ctx.arc(st.x, st.y, rad + 6, 0, Math.PI * 2)
            ctx.fillStyle = isCurrent ? "rgba(228, 228, 231, 0.3)" : "rgba(255, 255, 255, 0.18)"
            ctx.fill()
        }

        // Окружность станции
        ctx.beginPath()
        ctx.arc(st.x, st.y, rad, 0, Math.PI * 2)
        ctx.fillStyle = stFillColor
        ctx.fill()
        ctx.lineWidth = stBorderWidth
        ctx.strokeStyle = stBorderColor
        ctx.stroke()

        // Внутренний акцент для пересадочных станций (Interchange)
        if (st.is_interchange) {
            ctx.beginPath()
            ctx.arc(st.x, st.y, rad - 3.5, 0, Math.PI * 2)
            ctx.fillStyle = stBorderColor
            ctx.fill()
        }

        // 6. Подписи к станциям
        ctx.textAlign = "center"
        ctx.textBaseline = "top"

        // Заголовок сцены / станции
        ctx.font = fontMain
        ctx.fillStyle = (isHov || isCurrent) ? "#FFFFFF" : labelColor
        var titleY = st.y + rad + 8
        ctx.fillText(st.title, st.x, titleY)

        // Дополнительная строка: краткое описание или персонажи
        if (st.summary && zoomScale >= 0.7) {
            ctx.font = fontSub
            ctx.fillStyle = labelSubColor
            var sumText = st.summary
            if (sumText.length > 28) sumText = sumText.substring(0, 26) + "…"
            ctx.fillText(sumText, st.x, titleY + labelFontSize + 3)
        }
    }

    ctx.restore()
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
function renderTrackBadges(ctx, tracks, stations, fontFamily) {
    if (!tracks || tracks.length === 0 || !stations || stations.length === 0) return

    ctx.font = "bold 11px " + fontFamily
    ctx.textBaseline = "middle"

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

        var badgeX = firstSt.x - 45
        var badgeY = firstSt.y
        var text = tr.title || tr.id
        var textW = ctx.measureText(text).width
        var badgeW = Math.max(40, textW + 16)
        var badgeH = 20

        // Фон плашки ветки: темная монохромная плашка с аккуратной рамкой цвета ветки
        ctx.beginPath()
        roundRect(ctx, badgeX - badgeW, badgeY - badgeH / 2, badgeW, badgeH, 10)
        ctx.fillStyle = "#18181B"
        ctx.fill()
        ctx.lineWidth = 1.5
        ctx.strokeStyle = tr.color || "#71717A"
        ctx.stroke()

        // Текст названия ветки
        ctx.fillStyle = "#FAFAFA"
        ctx.textAlign = "center"
        ctx.fillText(text, badgeX - badgeW / 2, badgeY)
    }
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
