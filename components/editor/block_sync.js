// block_sync.js — определение активного блока и применение внешних обновлений

function getCurrentBlockInfo(editor, backend) {
    if (!editor) return null
    let fullText = editor.text
    let pos = editor.cursorPosition
    // Синхронизируем блоки заголовков любого уровня (#..######)
    let headingRegex = /^[ \t]*(#{1,6})\s+(.+)$/gm
    let match
    let matches = []
    while ((match = headingRegex.exec(fullText)) !== null) {
        matches.push({
            start: match.index,
            end: match.index + match[0].length,
            level: match[1].length,
            title: match[2].trim()
        })
    }
    for (let i = 0; i < matches.length; i++) {
        let m = matches[i]
        let contentStart = m.end
        let contentEnd = (i + 1 < matches.length) ? matches[i + 1].start : fullText.length

        // Если курсор на самой строке заголовка (pos <= contentStart), не синхронизируем как тело блока
        if (pos <= contentStart) {
            continue
        }

        if (pos > contentStart && pos <= contentEnd) {
            let rawContent = fullText.substring(contentStart, contentEnd)
            let cleanContent = rawContent.replace(/^\r?\n/, "").replace(/\r?\n$/, "")

            // Если тело блока пустое — проверяем, существует ли уже контент в кэше/других файлах
            if (!cleanContent) {
                if (typeof backend !== "undefined" && backend && typeof backend.get_block === "function") {
                    let existing = backend.get_block(m.title)
                    if (existing && existing.found && existing.content && existing.content.trim().length > 0) {
                        return {
                            heading: m.title,
                            headingNorm: m.title.toLowerCase(),
                            shouldAutoFill: true,
                            autoFillContent: existing.content.trim(),
                            contentStart: contentStart,
                            contentEnd: contentEnd
                        }
                    }
                }
                return null
            }

            return {
                heading: m.title,
                headingNorm: m.title.toLowerCase(),
                content: cleanContent,
                blockStart: m.start,
                contentStart: contentStart,
                contentEnd: contentEnd
            }
        }
    }
    return null
}

function applyExternalBlockUpdate(editor, headingNorm, newContent) {
    if (!editor) return false
    let fullText = editor.text
    let headingRegex = /^[ \t]*(#{1,6})\s+(.+)$/gm
    let match
    let matches = []
    while ((match = headingRegex.exec(fullText)) !== null) {
        matches.push({
            start: match.index,
            end: match.index + match[0].length,
            level: match[1].length,
            title: match[2].trim()
        })
    }

    let updatedText = fullText
    let cursor = editor.cursorPosition
    let changed = false

    for (let i = matches.length - 1; i >= 0; i--) {
        let m = matches[i]
        if (m.title.toLowerCase() === headingNorm.toLowerCase()) {
            let contentStart = m.end
            let contentEnd = (i + 1 < matches.length) ? matches[i + 1].start : fullText.length
            let oldContent = fullText.substring(contentStart, contentEnd)
            let cleanOld = oldContent.replace(/^\r?\n/, "").replace(/\r?\n$/, "")
            let cleanNew = newContent.replace(/^\r?\n/, "").replace(/\r?\n$/, "")
            if (cleanOld === cleanNew) continue

            let formattedNew = "\n" + cleanNew + (i + 1 < matches.length ? "\n\n" : "\n")
            let before = updatedText.substring(0, contentStart)
            let after = updatedText.substring(contentEnd)
            updatedText = before + formattedNew + after
            changed = true

            if (cursor >= contentEnd) {
                cursor += (formattedNew.length - oldContent.length)
            }
        }
    }

    if (changed) {
        return {
            text: updatedText,
            cursor: Math.min(cursor, updatedText.length)
        }
    }
    return null
}
