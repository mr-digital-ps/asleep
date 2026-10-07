// components/live/live_segmenter.js — парсинг документа на живые сегменты для Live Mode
.pragma library

/**
 * Разбирает markdown-текст на упорядоченные сегменты для Live Mode:
 * - "block": Именованный блок `Имя Блока { ... }`
 * - "transclusion": Вызов блока `Файл.Имя()` или `Имя()` на отдельной строке
 * - "divider": Горизонтальный разделитель `---` или `***` на отдельной строке
 * - "text": Обычный текст между блоками/разделителями/трансклюзиями
 */
function parseLiveSegments(text) {
    if (!text || text.length === 0) {
        return []
    }

    let lines = text.split(/\r?\n/)
    let segments = []

    let inCodeFence = false
    let inBlock = false
    let currentBlockName = ""
    let currentBlockLines = []
    let currentTextLines = []

    // Регулярные выражения
    let reCodeFence = /^[ \t]*```/
    let reBlockStart = /^([^{}\n\r]+?)\s*\{[ \t]*$/
    let reBlockEnd = /^[ \t]*\}[ \t]*$/
    let reDivider = /^[ \t]*(?:---|\*\*\*|___)[ \t]*$/
    let reTransclusionExt = /^[ \t]*([^.(){}\n\r]+)\.([^.(){}\n\r]+)\(\)[ \t]*$/
    let reTransclusionLocal = /^[ \t]*([^.(){}\n\r]+)\(\)[ \t]*$/

    function flushText() {
        if (currentTextLines.length > 0) {
            let content = currentTextLines.join("\n")
            if (content.length > 0) {
                segments.push({
                    type: "text",
                    name: "",
                    content: content,
                    targetFile: "",
                    targetBlock: "",
                    isFolded: false
                })
            }
            currentTextLines = []
        }
    }

    for (let i = 0; i < lines.length; i++) {
        let line = lines[i]

        // 1. Блоки кода ``` (внутри блоков кода диалект не парсится)
        if (reCodeFence.test(line)) {
            inCodeFence = !inCodeFence
            if (inBlock) {
                currentBlockLines.append ? currentBlockLines.push(line) : currentBlockLines.push(line)
            } else {
                currentTextLines.push(line)
            }
            continue
        }

        if (inCodeFence) {
            if (inBlock) {
                currentBlockLines.push(line)
            } else {
                currentTextLines.push(line)
            }
            continue
        }

        // 2. Внутри именованного блока
        if (inBlock) {
            if (reBlockEnd.test(line)) {
                // Закрытие блока
                segments.push({
                    type: "block",
                    name: currentBlockName,
                    content: currentBlockLines.join("\n"),
                    targetFile: "",
                    targetBlock: "",
                    isFolded: false
                })
                inBlock = false
                currentBlockName = ""
                currentBlockLines = []
            } else {
                currentBlockLines.push(line)
            }
            continue
        }

        // 3. Открытие именованного блока `Имя {`
        let blockMatch = line.match(reBlockStart)
        if (blockMatch && blockMatch[1].indexOf(".") === -1) {
            flushText()
            inBlock = true
            currentBlockName = blockMatch[1].trim()
            currentBlockLines = []
            continue
        }

        // 4. Разделитель `---` на отдельной строке
        if (reDivider.test(line)) {
            flushText()
            segments.push({
                type: "divider",
                name: "",
                content: "",
                targetFile: "",
                targetBlock: "",
                isFolded: false
            })
            continue
        }

        // 5. Трансклюзия внешняя `Файл.Блок()`
        let extMatch = line.match(reTransclusionExt)
        if (extMatch) {
            flushText()
            segments.push({
                type: "transclusion",
                name: "",
                content: "",
                targetFile: extMatch[1].trim(),
                targetBlock: extMatch[2].trim(),
                isFolded: false
            })
            continue
        }

        // 6. Трансклюзия локальная `Блок()`
        let localMatch = line.match(reTransclusionLocal)
        if (localMatch) {
            flushText()
            segments.push({
                type: "transclusion",
                name: "",
                content: "",
                targetFile: "",
                targetBlock: localMatch[1].trim(),
                isFolded: false
            })
            continue
        }

        // 7. Обычная строка текста
        currentTextLines.push(line)
    }

    // Если блок остался незакрытым до конца файла
    if (inBlock) {
        segments.push({
            type: "block",
            name: currentBlockName,
            content: currentBlockLines.join("\n"),
            targetFile: "",
            targetBlock: "",
            isFolded: false
        })
    }

    flushText()
    return segments
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
            let blockContent = seg.content || ""
            if (blockContent.length > 0 && !blockContent.startsWith("\n")) {
                blockContent = "\n" + blockContent
            }
            if (blockContent.length > 0 && !blockContent.endsWith("\n")) {
                blockContent = blockContent + "\n"
            }
            parts.push(seg.name + " {" + blockContent + "}")
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
