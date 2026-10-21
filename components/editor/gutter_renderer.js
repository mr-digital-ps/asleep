function drawDiamond(ctx, cx, cy, r) {
    ctx.beginPath()
    ctx.moveTo(cx, cy - r)
    ctx.lineTo(cx + r, cy)
    ctx.lineTo(cx, cy + r)
    ctx.lineTo(cx - r, cy)
    ctx.closePath()
}

function drawCircledPlus(ctx, cx, cy, r, color, bgColor) {
    if (bgColor) {
        ctx.beginPath()
        ctx.arc(cx, cy, r, 0, 2 * Math.PI)
        ctx.fillStyle = bgColor
        ctx.fill()
    }
    ctx.beginPath()
    ctx.arc(cx, cy, r, 0, 2 * Math.PI)
    ctx.moveTo(cx - r, cy)
    ctx.lineTo(cx + r, cy)
    ctx.moveTo(cx, cy - r)
    ctx.lineTo(cx, cy + r)
    ctx.strokeStyle = color
    ctx.stroke()
}

function drawCircledMinus(ctx, cx, cy, r, color, bgColor) {
    if (bgColor) {
        ctx.beginPath()
        ctx.arc(cx, cy, r, 0, 2 * Math.PI)
        ctx.fillStyle = bgColor
        ctx.fill()
    }
    ctx.beginPath()
    ctx.arc(cx, cy, r, 0, 2 * Math.PI)
    ctx.moveTo(cx - r, cy)
    ctx.lineTo(cx + r, cy)
    ctx.strokeStyle = color
    ctx.stroke()
}

function drawGutterDots(canvas, editorArea, width, height, activeColor, textColor, isLiveMode, blocks, collapsedBlocks, diffData, diffBrightColor, bgColor) {
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
    var headerDotRadius = 3.4 * scale

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
        var cKeys = Object.keys(collapsedBlocks)
        if (cKeys.length > 0) {
            for (var l = 0; l < lines.length; l++) {
                var lTrim = lines[l].trim()
                if (lTrim.indexOf(" ....") !== -1) {
                    for (var ck = 0; ck < cKeys.length; ck++) {
                        var cb = collapsedBlocks[cKeys[ck]]
                        if (cb && (cb.name + " ...." === lTrim || cb.headerLine === l)) {
                            collapsedLines[l] = cb
                            cb.headerLine = l
                            break
                        }
                    }
                }
            }
            for (var cId in collapsedBlocks) {
                var cBlk = collapsedBlocks[cId]
                if (cBlk && cBlk.headerLine !== undefined && !collapsedLines[cBlk.headerLine]) {
                    collapsedLines[cBlk.headerLine] = cBlk
                }
            }
        }
    }

    // 1. В Live Mode рисуем непрерывные вертикальные линии блоков
    // Ширина и цвет линии совпадают с диаметром и цветом круга точек (textColor), перекрывая их
    if (isLiveMode && blocks && blocks.length > 0) {
        ctx.strokeStyle = textColor
        ctx.lineWidth = dotRadius * 2
        ctx.lineCap = "round"
        ctx.globalAlpha = 1.0

        for (var bi = 0; bi < blocks.length; bi++) {
            var block = blocks[bi]
            if (block.startLine >= block.endLine || collapsedLines[block.startLine]) continue

            var sRect = editorArea.positionToRectangle(block.startPos)
            var eRect = editorArea.positionToRectangle(block.endPos)

            // Проверяем видимость диапазона в окне
            if (eRect.y >= -40 && sRect.y <= height + 40) {
                var topY = Math.round(sRect.y + (sRect.height / 2))
                var bottomY = Math.round(eRect.y + (eRect.height / 2))
                ctx.beginPath()
                ctx.moveTo(centerX, topY)
                ctx.lineTo(centerX, bottomY)
                ctx.stroke()
            }
        }
    }

    // 2. Отрисовка маркеров строк (точки строк и маркеры заголовков)
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
            var isDiffAdded = false
            var isDiffDeleted = false
            if (diffData && diffData.lines && i < diffData.lines.length) {
                var dType = diffData.lines[i].type
                if (dType === "added") isDiffAdded = true
                else if (dType === "deleted") isDiffDeleted = true
            }

            var isCollapsed = isLiveMode && (collapsedLines[i] !== undefined)
            var isOpenHeader = isLiveMode && (blockStarts[i] !== undefined) && !isCollapsed
            var isBody = isLiveMode && (blockBodies[i] !== undefined) && !isCollapsed && (!blockStarts[i] || !collapsedLines[blockStarts[i].startLine])
            var isHr = isLiveMode && /^[ \t]*---[ \t]*$/.test(lines[i])

            if (isDiffAdded) {
                // ⊕ (Circled Plus): оптически равен ромбу или самую малость компактнее (headerDotRadius * 0.88)
                var diffMarkerRadius = headerDotRadius * 0.88
                var diffColor = isCurrentLine ? (diffBrightColor || "#ffffff") : (activeColor || "#999999")
                ctx.lineWidth = 1.0 * scale
                drawCircledPlus(ctx, centerX, dotY, diffMarkerRadius, diffColor, bgColor)
            } else if (isDiffDeleted) {
                // ⊖ (Circled Minus): оптически равен ромбу или самую малость компактнее (headerDotRadius * 0.88)
                var diffMarkerRadius = headerDotRadius * 0.88
                var diffColor = isCurrentLine ? (diffBrightColor || "#ffffff") : (activeColor || "#999999")
                ctx.lineWidth = 1.0 * scale
                drawCircledMinus(ctx, centerX, dotY, diffMarkerRadius, diffColor, bgColor)
            } else if (isCollapsed) {
                // Свёрнутый блок: аккуратный ромбик свёртки activeColor (семиотика: ромб = блок)
                drawDiamond(ctx, centerX, dotY, headerDotRadius * 1.15)
                ctx.fillStyle = activeColor
                ctx.fill()
            } else if (isOpenHeader) {
                // Заголовок открытого блока: аккуратный ромбик (семиотика: ромб = блок)
                // В спокойном цвете линии (textColor), а при нахождении курсора на строке — activeColor
                drawDiamond(ctx, centerX, dotY, headerDotRadius * 1.15)
                ctx.fillStyle = isCurrentLine ? activeColor : textColor
                ctx.fill()
            } else if (isHr) {
                // Разделитель '---': крупная точка (headerDotRadius), как и у заголовка блока
                ctx.beginPath()
                ctx.arc(centerX, dotY, headerDotRadius, 0, 2 * Math.PI)
                ctx.fillStyle = isCurrentLine ? activeColor : textColor
                ctx.fill()
            } else if (isBody) {
                // Строка внутри тела блока: вертикальная линия уже перекрывает точку тем же цветом и диаметром.
                // Если строка активна (курсор на ней), подсвечиваем точку активным цветом поверх линии:
                if (isCurrentLine) {
                    ctx.beginPath()
                    ctx.arc(centerX, dotY, dotRadius, 0, 2 * Math.PI)
                    ctx.fillStyle = activeColor
                    ctx.fill()
                }
            } else {
                // Обычная монохромная точка строки вне блока
                ctx.beginPath()
                ctx.arc(centerX, dotY, dotRadius, 0, 2 * Math.PI)
                ctx.fillStyle = isCurrentLine ? activeColor : textColor
                ctx.fill()
            }
        }

        pos += lineLen + 1
    }
}


