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
    // Ищет '{' в конце строки. Имя до скобки опционально (может быть пустым: просто '{')
    let reBlockStart = /^([^{}\n\r]*?)\s*\{[ \t]*$/
    let reBlockEnd = /^[ \t]*\}[ \t]*$/
    let reDivider = /^[ \t]*(?:---|\*\*\*|___)[ \t]*$/
    let reTransclusionExt = /^[ \t]*([^.(){}\n\r]+)\.([^.(){}\n\r]+)\(\)[ \t]*$/
    let reTransclusionLocal = /^[ \t]*([^.(){}\n\r]+)\(\)[ \t]*$/

    function flushText() {
        if (currentTextLines.length > 0) {
            let content = currentTextLines.join("\n")
            segments.push({
                type: "text",
                name: "",
                content: content,
                targetFile: "",
                targetBlock: "",
                isFolded: false
            })
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

        // 2. Внутри именованного/безымянного блока
        if (inBlock) {
            // Если встречаем начало другого блока, аварийно завершаем текущий
            let nextBlockMatch = line.match(reBlockStart)
            if (nextBlockMatch && nextBlockMatch[1].indexOf(".") === -1) {
                segments.push({
                    type: "block",
                    name: currentBlockName,
                    content: currentBlockLines.join("\n"),
                    targetFile: "",
                    targetBlock: "",
                    isFolded: false
                })
                inBlock = true
                currentBlockName = nextBlockMatch[1].trim()
                currentBlockLines = []
                continue
            }

            // Проверка на закрытие блока:
            // Вариант А: строка состоит только из '}'
            if (reBlockEnd.test(line)) {
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
                continue
            } else if (line.indexOf("}") !== -1) {
                // Если '}' встретилась внутри или в конце строки
                let closeIdx = line.lastIndexOf("}")
                let beforeClose = line.substring(0, closeIdx).replace(/\s+$/, "")
                let afterClose = line.substring(closeIdx + 1).replace(/^\s+/, "")

                if (beforeClose.length > 0) {
                    currentBlockLines.push(beforeClose)
                }

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

                if (afterClose.length > 0) {
                    currentTextLines.push(afterClose)
                }
                continue
            } else {
                currentBlockLines.push(line)
                continue
            }
        }

        // 3. Открытие блока (строка содержит '{')
        let braceIdx = line.indexOf("{")
        if (braceIdx !== -1 && line.indexOf("```") === -1) {
            let beforeBrace = line.substring(0, braceIdx).trim()
            let afterBrace = line.substring(braceIdx + 1)

            // Проверяем, что это не вызов трансклюзии или разделитель
            if (beforeBrace.indexOf(".") === -1 && beforeBrace.indexOf("(") === -1) {
                flushText()
                inBlock = true
                currentBlockName = beforeBrace
                currentBlockLines = []

                // Если на той же строке уже есть содержимое или закрывающая скобка
                if (afterBrace.indexOf("}") !== -1) {
                    let endIdx = afterBrace.lastIndexOf("}")
                    let inside = afterBrace.substring(0, endIdx).trim()
                    let rest = afterBrace.substring(endIdx + 1).trim()
                    if (inside.length > 0) currentBlockLines.push(inside)

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
                    if (rest.length > 0) currentTextLines.push(rest)
                } else if (afterBrace.trim().length > 0) {
                    currentBlockLines.push(afterBrace.trim())
                }
                continue
            }
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
            let header = (seg.name && seg.name.length > 0) ? (seg.name + " {") : "{"
            parts.push(header + blockContent + "}")
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
