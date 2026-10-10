// js/editor/gutter_renderer.js — Отрисовка разметки строк и точек на Canvas гаттера

function drawGutterDots(canvas, editorArea, width, height, activeColor, textColor, isLiveMode) {
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

    // Если включен Live Mode: предварительно находим границы многострочных блоков { ... }
    var blockRanges = []
    if (isLiveMode) {
        var openStack = []
        for (var l = 0; l < lines.length; l++) {
            var trimmed = lines[l].trim()
            if (trimmed.indexOf("{") !== -1 && trimmed.indexOf("}") === -1) {
                openStack.push(l)
            } else if (trimmed.indexOf("}") !== -1 && openStack.length > 0) {
                var startLine = openStack.pop()
                blockRanges.push({ start: startLine, end: l })
            }
        }
    }

    // Вспомогательная функция: проверка, принадлежит ли строка блоку
    function getBlockForLine(lineIdx) {
        for (var b = 0; b < blockRanges.length; b++) {
            if (lineIdx >= blockRanges[b].start && lineIdx <= blockRanges[b].end) {
                return blockRanges[b]
            }
        }
        return null
    }

    // 1. В Live Mode рисуем непрерывные вертикальные направляющие линии блоков
    if (isLiveMode && blockRanges.length > 0) {
        ctx.lineWidth = 1.5
        for (var b = 0; b < blockRanges.length; b++) {
            var blk = blockRanges[b]
            var startPos = 0
            for (var p = 0; p < blk.start; p++) startPos += lines[p].length + 1
            var endPos = 0
            for (var p = 0; p < blk.end; p++) endPos += lines[p].length + 1

            var rStart = editorArea.positionToRectangle(startPos)
            var rEnd = editorArea.positionToRectangle(endPos)
            var yTop = Math.round(rStart.y + (rStart.height / 2))
            var yBottom = Math.round(rEnd.y + (rEnd.height / 2))

            // Проверяем, находится ли курсор внутри этого блока
            var isBlockActive = (curPos >= startPos && curPos <= endPos + lines[blk.end].length)
            ctx.strokeStyle = isBlockActive ? activeColor : textColor

            ctx.beginPath()
            ctx.moveTo(centerX, yTop)
            ctx.lineTo(centerX, yBottom)
            ctx.stroke()
        }
    }

    // 2. Рисуем точки строк
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
            var inBlock = isLiveMode ? getBlockForLine(i) : null

            ctx.beginPath()
            if (isLiveMode && inBlock) {
                // В Live Mode: на открытии { и закрытии } рисуем терминальные ноды блоков
                if (i === inBlock.start || i === inBlock.end) {
                    var nodeRadius = 3.2 * scale
                    ctx.arc(centerX, dotY, nodeRadius, 0, 2 * Math.PI)
                    ctx.fillStyle = isCurrentLine ? activeColor : textColor
                    ctx.fill()
                }
            } else {
                // В Source Mode или вне блоков: аккуратная точка строки
                ctx.arc(centerX, dotY, dotRadius, 0, 2 * Math.PI)
                ctx.fillStyle = isCurrentLine ? activeColor : textColor
                ctx.fill()
            }
        }

        pos += lineLen + 1
    }
}
