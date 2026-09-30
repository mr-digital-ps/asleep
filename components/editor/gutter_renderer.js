// js/editor/gutter_renderer.js — Отрисовка разметки строк и точек на Canvas гаттера

function drawGutterDots(canvas, editorArea, width, height, activeColor, textColor) {
    if (!canvas || typeof canvas.getContext !== "function") return
    var ctx = canvas.getContext("2d")
    ctx.clearRect(0, 0, width, height)
    if (!editorArea) return
    var txt = editorArea.text
    if (txt === undefined || txt === null) return

    var lines = txt.split("\n")
    var pos = 0
    var curPos = editorArea.cursorPosition
    var centerX = width / 2

    var fontSize = (editorArea.font && editorArea.font.pixelSize) ? editorArea.font.pixelSize : 15
    var scale = Math.max(0.6, Math.min(2.5, fontSize / 15.0))

    for (var i = 0; i < lines.length; i++) {
        var lineLen = lines[i].length
        var isCurrentLine = (curPos >= pos && curPos <= pos + lineLen)
        var r = editorArea.positionToRectangle(pos)
        var dotY = r.y + (r.height / 2)

        // Прекращаем обход, если вышли за нижнюю границу видимости
        if (r.y > height + 40) {
            break
        }

        // Пропускаем строки выше верхней границы видимости
        if (r.y + r.height >= -40) {
            ctx.beginPath()
            var radius = (isCurrentLine ? 3.2 : 2.2) * scale
            ctx.arc(centerX, dotY, radius, 0, 2 * Math.PI)
            ctx.fillStyle = isCurrentLine ? activeColor : textColor
            ctx.fill()
        }

        pos += lineLen + 1
    }
}
