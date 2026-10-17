// js/editor/gutter_renderer.js — Отрисовка разметки строк, точек и направляющих блоков на Canvas гаттера

function drawGutterDots(canvas, editorArea, width, height, activeColor, textColor, isLiveMode, blocks, collapsedBlocks) {
    if (!canvas || typeof canvas.getContext !== "function") return
    var ctx = canvas.getContext("2d")
    ctx.clearRect(0, 0, width, height)
    if (!editorArea) return
    var txt = editorArea.text
    if (txt === undefined || txt === null) return

    var lines = txt.split("\n")
    var pos = 0
    var curPos = editorArea.cursorPosition
    var centerX = Math.round(width / 2)

    var fontSize = (editorArea.font && editorArea.font.pixelSize) ? editorArea.font.pixelSize : 15
    var scale = Math.max(0.6, Math.min(2.5, fontSize / 15.0))
    var dotRadius = 2.0 * scale

    // Подготовка карт блоков для быстрого поиска по номеру строки
    var blockStarts = {} // line -> block
    var blockBodies = {} // line -> block
    var collapsedLines = {} // line -> blockName

    if (isLiveMode && blocks && blocks.length > 0) {
        for (var b = 0; b < blocks.length; b++) {
            var blk = blocks[b]
            blockStarts[blk.startLine] = blk
            for (var l = blk.startLine + 1; l <= blk.endLine; l++) {
                blockBodies[l] = blk
            }
        }
    }

    if (isLiveMode && collapsedBlocks) {
        for (var cId in collapsedBlocks) {
            var cBlk = collapsedBlocks[cId]
            if (cBlk && cBlk.headerLine !== undefined) {
                collapsedLines[cBlk.headerLine] = cBlk
            }
        }
    }

    // 1. В Live Mode рисуем непрерывные вертикальные направляющие Scope Guides
    if (isLiveMode && blocks && blocks.length > 0) {
        ctx.strokeStyle = activeColor
        ctx.lineWidth = 1.5 * scale
        ctx.globalAlpha = 0.35

        for (var bi = 0; bi < blocks.length; bi++) {
            var block = blocks[bi]
            var sRect = editorArea.positionToRectangle(block.startPos)
            var eRect = editorArea.positionToRectangle(block.endPos)

            // Проверяем видимость диапазона в окне
            if (eRect.y >= -40 && sRect.y <= height + 40) {
                var topY = Math.round(sRect.y + sRect.height * 0.7)
                var bottomY = Math.round(eRect.y + (eRect.height / 2))
                ctx.beginPath()
                ctx.moveTo(centerX, topY)
                ctx.lineTo(centerX, bottomY)
                ctx.stroke()
            }
        }
        ctx.globalAlpha = 1.0
    }

    // 2. Отрисовка маркеров строк (точки, шевроны открытия и схлопывания)
    for (var i = 0; i < lines.length; i++) {
        var lineLen = lines[i].length
        var isCurrentLine = (curPos >= pos && curPos <= pos + lineLen)
        var r = editorArea.positionToRectangle(pos)
        var dotY = Math.round(r.y + (r.height / 2))

        // Прекращаем обход, если вышли за нижнюю границу видимости
        if (r.y > height + 40) {
            break
        }

        if (r.y + r.height >= -40) {
            if (isLiveMode && blockStarts[i]) {
                // Маркер открытого блока — шеврон вниз ▼ (зеленый акцент как на скриншоте)
                drawChevron(ctx, centerX, dotY, scale * 3.5, false, activeColor)
            } else if (isLiveMode && collapsedLines[i]) {
                // Маркер свёрнутого блока — шеврон вправо ▶
                drawChevron(ctx, centerX, dotY, scale * 3.5, true, activeColor)
            } else {
                // Обычная монохромная точка строки
                ctx.beginPath()
                ctx.arc(centerX, dotY, dotRadius, 0, 2 * Math.PI)
                ctx.fillStyle = isCurrentLine ? activeColor : textColor
                ctx.fill()
            }
        }

        pos += lineLen + 1
    }
}

/**
 * Отрисовывает аккуратный векторный шеврон свёртки блока
 */
function drawChevron(ctx, x, y, size, isRight, color) {
    ctx.save()
    ctx.fillStyle = color
    ctx.beginPath()
    if (isRight) {
        // Шеврон вправо ▶
        ctx.moveTo(x - size * 0.6, y - size)
        ctx.lineTo(x + size * 0.8, y)
        ctx.lineTo(x - size * 0.6, y + size)
    } else {
        // Шеврон вниз ▼
        ctx.moveTo(x - size, y - size * 0.6)
        ctx.lineTo(x + size, y - size * 0.6)
        ctx.lineTo(x, y + size * 0.8)
    }
    ctx.closePath()
    ctx.fill()
    ctx.restore()
}

