// js/editor/block_scanner.js — Парсинг и обнаружение блоков диалекта в тексте
.pragma library

/**
 * Сканирует текст документа и возвращает список найденных блоков:
 * [{
 *   id: string,
 *   name: string,
 *   startLine: number,  // 0-based
 *   endLine: number,    // 0-based
 *   startPos: number,   // char offset of header line start
 *   openBracePos: number, // char offset of '{'
 *   endPos: number,     // char offset of closing line
 *   closeBracePos: number, // char offset of '}'
 *   isCollapsed: boolean
 * }]
 */
function scanBlocks(text) {
    if (!text) return []

    var lines = text.split("\n")
    var blocks = []
    var stack = []
    var pos = 0

    // Регулярные выражения блоков по канону asleep
    var reSingleLineBlock = /^([^{}\n\r]+?)\s*\{\s*(.*?)\s*\}\s*$/
    var reBlockStart = /^([^{}\n\r]+?)\s*\{(.*)$/
    var reBlockEnd = /^[ \t]*\}[ \t]*$/

    for (var i = 0; i < lines.length; i++) {
        var line = lines[i]
        var lineLen = line.length

        // 1. Проверка однострочного блока: Имя { текст }
        var matchSingle = line.match(reSingleLineBlock)
        if (matchSingle) {
            var singleName = matchSingle[1].trim()
            var singleOpenBrace = line.indexOf("{")
            var singleCloseBrace = line.lastIndexOf("}")
            blocks.push({
                id: "block_" + i + "_" + singleName,
                name: singleName,
                startLine: i,
                endLine: i,
                startPos: pos,
                openBracePos: pos + singleOpenBrace,
                endPos: pos,
                closeBracePos: pos + singleCloseBrace,
                lineCount: 1
            })
        } else {
            // 2. Проверка открытия многострочного блока: Имя { или Имя { текст...
            var matchStart = line.match(reBlockStart)
            if (matchStart) {
                var blockName = matchStart[1].trim()
                var braceIdx = line.indexOf("{")
                stack.push({
                    id: "block_" + i + "_" + blockName,
                    name: blockName,
                    startLine: i,
                    startPos: pos,
                    openBracePos: pos + braceIdx,
                    lineCount: 1
                })
            } else if (reBlockEnd.test(line) && stack.length > 0) {
                // Закрытие блока
                var top = stack.pop()
                var closeBraceIdx = line.indexOf("}")
                blocks.push({
                    id: top.id,
                    name: top.name,
                    startLine: top.startLine,
                    endLine: i,
                    startPos: top.startPos,
                    openBracePos: top.openBracePos,
                    endPos: pos,
                    closeBracePos: pos + closeBraceIdx,
                    lineCount: (i - top.startLine + 1)
                })
            }
        }

        pos += lineLen + 1 // +1 для \n
    }

    blocks.sort(function(a, b) { return a.startLine - b.startLine })
    return blocks
}

/**
 * Проверяет, является ли строка заголовком свёрнутого блока (Заголовок ....)
 */
function isCollapsedHeader(line) {
    if (!line) return false
    return /^[^{}\n\r]+?\s*\.{4,}$/.test(line.trim())
}
