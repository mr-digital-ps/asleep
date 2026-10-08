// components/live/live_segmenter.js — парсинг документа на живые сегменты для Live Mode
.pragma library

/**
 * Разбирает markdown-текст на упорядоченные сегменты для Live Mode.
 *
 * ЖЕЛЕЗНЫЕ ПРАВИЛА:
 * 1. Блочный текст начинается со строки, где стоит '{' (включая имя блока на этой строке).
 * 2. Блочный текст заканчивается на строке, где стоит '}'.
 * 3. Если '{' и '}' на одной строке — это 1 строка.
 * 4. Если между строкой '{' и строкой '}' N строк — блочный текст занимает ровно эти строки:
 *    - 1-я строка блока: заголовок / имя (где '{')
 *    - промежуточные строки: содержимое
 *    - последняя строка блока: строка, где стояла '}'
 * 5. Общее количество строк в Source Mode и в Live Mode должно СТРОГО СОВПАДАТЬ.
 */
function parseLiveSegments(text) {
    if (!text || text.length === 0) {
        console.log("[Segmenter Report] Source text is empty (0 lines).")
        return []
    }

    let lines = text.split(/\r?\n/)
    let totalSourceLines = lines.length
    let segments = []

    let inCodeFence = false
    let currentTextLines = []
    let currentTextStartLine = 1 // 1-indexed

    let reCodeFence = /^[ \t]*```/
    let reDivider = /^[ \t]*(?:---|\*\*\*|___)[ \t]*$/
    let reTransclusionExt = /^[ \t]*([^.(){}\n\r]+)\.([^.(){}\n\r]+)\(\)[ \t]*$/
    let reTransclusionLocal = /^[ \t]*([^.(){}\n\r]+)\(\)[ \t]*$/

    function flushText(endLineIdx) {
        if (currentTextLines.length > 0) {
            let segLinesCount = currentTextLines.length
            let startLine = currentTextStartLine
            let endLine = startLine + segLinesCount - 1
            segments.push({
                type: "text",
                name: "",
                content: currentTextLines.join("\n"),
                linesCount: segLinesCount,
                sourceStartLine: startLine,
                sourceEndLine: endLine,
                targetFile: "",
                targetBlock: "",
                isFolded: false
            })
            currentTextLines = []
        }
        currentTextStartLine = endLineIdx + 2 // следующая строка (1-indexed)
    }

    let i = 0
    while (i < lines.length) {
        let line = lines[i]
        let lineNum = i + 1 // 1-indexed

        // 1. Блоки кода ``` (внутри кода диалект не парсится)
        if (reCodeFence.test(line)) {
            inCodeFence = !inCodeFence
            currentTextLines.push(line)
            i++
            continue
        }
        if (inCodeFence) {
            currentTextLines.push(line)
            i++
            continue
        }

        // 2. Проверяем, начинается ли блочный текст со строки с '{'
        let openBraceIdx = line.indexOf("{")
        if (openBraceIdx !== -1) {
            let beforeOpen = line.substring(0, openBraceIdx)
            let isTransclusion = (beforeOpen.indexOf(".") !== -1 && beforeOpen.indexOf("(") !== -1)

            if (!isTransclusion) {
                // Сбрасываем накопленный обычный текст перед блоком
                flushText(i - 1)

                let blockStartLine = lineNum
                let closeBraceIdx = line.indexOf("}", openBraceIdx + 1)

                if (closeBraceIdx !== -1) {
                    // Однострочный блок: '{' и '}' на одной и той же строке
                    let prefix = beforeOpen.trim()
                    let inside = line.substring(openBraceIdx + 1, closeBraceIdx)
                    let postfix = line.substring(closeBraceIdx + 1)

                    // Блок занимает ровно 1 строку
                    segments.push({
                        type: "block",
                        name: prefix,
                        content: inside,
                        rawStartLine: line,
                        rawEndLine: line,
                        isSingleLine: true,
                        linesCount: 1,
                        sourceStartLine: blockStartLine,
                        sourceEndLine: blockStartLine,
                        targetFile: "",
                        targetBlock: "",
                        isFolded: false
                    })

                    currentTextStartLine = blockStartLine + 1
                    if (postfix.trim().length > 0) {
                        currentTextLines.push(postfix)
                    }
                    i++
                    continue
                }

                // Многострочный блок:
                // Строка i — где стоит '{'
                let blockName = beforeOpen.trim()
                let blockLines = [line]
                let insideLines = []

                let afterFirst = line.substring(openBraceIdx + 1).trim()
                if (afterFirst.length > 0) {
                    insideLines.push(afterFirst)
                }

                let foundClose = false
                let j = i + 1
                for (; j < lines.length; j++) {
                    let curLine = lines[j]
                    blockLines.push(curLine)

                    let cIdx = curLine.indexOf("}")
                    if (cIdx !== -1) {
                        // Строка j — где стоит '}'
                        // Текст перед '}' на этой строке
                        let beforeClose = curLine.substring(0, cIdx).trim()
                        // Последняя строка блока внутри LiveBlockItem:
                        insideLines.push(beforeClose)
                        foundClose = true
                        break
                    } else {
                        insideLines.push(curLine)
                    }
                }

                let blockEndLine = foundClose ? (j + 1) : lines.length
                let blockLinesCount = blockEndLine - blockStartLine + 1

                segments.push({
                    type: "block",
                    name: blockName,
                    content: insideLines.join("\n"),
                    rawLines: blockLines,
                    isSingleLine: false,
                    linesCount: blockLinesCount,
                    sourceStartLine: blockStartLine,
                    sourceEndLine: blockEndLine,
                    targetFile: "",
                    targetBlock: "",
                    isFolded: false
                })

                currentTextStartLine = blockEndLine + 1
                i = foundClose ? (j + 1) : lines.length
                continue
            }
        }

        // 3. Разделитель `---`
        if (reDivider.test(line)) {
            flushText(i - 1)
            segments.push({
                type: "divider",
                name: "",
                content: "",
                linesCount: 1,
                sourceStartLine: lineNum,
                sourceEndLine: lineNum,
                targetFile: "",
                targetBlock: "",
                isFolded: false
            })
            currentTextStartLine = lineNum + 1
            i++
            continue
        }

        // 4. Трансклюзия внешняя
        let extMatch = line.match(reTransclusionExt)
        if (extMatch) {
            flushText(i - 1)
            segments.push({
                type: "transclusion",
                name: "",
                content: "",
                linesCount: 1,
                sourceStartLine: lineNum,
                sourceEndLine: lineNum,
                targetFile: extMatch[1].trim(),
                targetBlock: extMatch[2].trim(),
                isFolded: false
            })
            currentTextStartLine = lineNum + 1
            i++
            continue
        }

        // 5. Трансклюзия локальная
        let localMatch = line.match(reTransclusionLocal)
        if (localMatch) {
            flushText(i - 1)
            segments.push({
                type: "transclusion",
                name: "",
                content: "",
                linesCount: 1,
                sourceStartLine: lineNum,
                sourceEndLine: lineNum,
                targetFile: "",
                targetBlock: localMatch[1].trim(),
                isFolded: false
            })
            currentTextStartLine = lineNum + 1
            i++
            continue
        }

        // 6. Обычная строка текста
        currentTextLines.push(line)
        i++
    }

    flushText(lines.length - 1)

    // ПОДРОБНЫЙ ОТЧЕТ В КОНСОЛЬ
    printSegmentationReport(totalSourceLines, segments)

    return segments
}

/**
 * Печатает подробный сравнительный отчет Source Mode ⟷ Live Mode
 */
function printSegmentationReport(totalSourceLines, segments) {
    let liveTotalLines = 0
    let blocksInfo = []

    for (let s = 0; s < segments.length; s++) {
        let seg = segments[s]
        let linesInSeg = seg.linesCount || 1
        liveTotalLines += linesInSeg

        if (seg.type === "block") {
            blocksInfo.push({
                index: s,
                name: seg.name || "(безымянный)",
                isSingleLine: seg.isSingleLine,
                sourceStart: seg.sourceStartLine,
                sourceEnd: seg.sourceEndLine,
                linesCount: linesInSeg
            })
        }
    }

    console.log("==================== [PARSER / SEGMENTER REPORT] ====================")
    console.log("[Source Mode] Всего строк:", totalSourceLines)
    console.log("[Live Mode]   Всего строк:", liveTotalLines)
    console.log("[Совпадение строк]:", (totalSourceLines === liveTotalLines) ? "ДА (100% совпадение)" : "НЕТ! (Разница: " + (liveTotalLines - totalSourceLines) + " строк)")
    console.log("[Блочные тексты] Найдено блоков:", blocksInfo.length)

    for (let b = 0; b < blocksInfo.length; b++) {
        let bi = blocksInfo[b]
        if (bi.isSingleLine) {
            console.log(`  -> Блок #${b + 1} "${bi.name}": ОДНОСТРОЧНЫЙ в строке ${bi.sourceStart}. Начало '{' и конец '}' в строке ${bi.sourceStart}. Строк: 1`)
        } else {
            console.log(`  -> Блок #${b + 1} "${bi.name}": Начало '{' в строке ${bi.sourceStart}, Конец '}' в строке ${bi.sourceEnd}. Занимает строк: ${bi.linesCount}`)
        }
    }
    console.log("=====================================================================")
}

/**
 * Собирает обратно полный текст документа из массива сегментов Live Mode
 */
function rebuildFullText(segments) {
    if (!segments || segments.length === 0) return ""

    let parts = []
    for (let i = 0; i < segments.length; i++) {
        let seg = segments[i]
        if (!seg) continue

        if (seg.type === "text") {
            parts.push(seg.content)
        } else if (seg.type === "block") {
            if (seg.isSingleLine) {
                let header = (seg.name && seg.name.length > 0) ? (seg.name + " {") : "{"
                let inner = (seg.content && seg.content.length > 0) ? (" " + seg.content.trim() + " ") : ""
                parts.push(header + inner + "}")
            } else {
                let header = (seg.name && seg.name.length > 0) ? (seg.name + " {") : "{"
                let blockContent = seg.content || ""
                let innerLines = blockContent.split("\n")
                // Последняя строка — это строка, где закрывается '}'
                let lastLine = innerLines.length > 0 ? innerLines[innerLines.length - 1] : ""
                let midLines = innerLines.slice(0, -1)
                
                let res = header
                if (midLines.length > 0) {
                    res += "\n" + midLines.join("\n")
                }
                res += "\n" + (lastLine.length > 0 ? (lastLine + "}") : "}")
                parts.push(res)
            }
        } else if (seg.type === "divider") {
            parts.push("---")
        } else if (seg.type === "transclusion") {
            if (seg.targetFile && seg.targetFile.length > 0) {
                parts.push(seg.targetFile + "." + seg.targetBlock + "()")
            } else {
                parts.push(seg.targetBlock + "()")
            }
        }
    }

    return parts.join("\n")
}
