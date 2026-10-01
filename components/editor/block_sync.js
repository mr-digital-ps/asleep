// components/editor/block_sync.js — определение активного именованного блока Имя { ... } и синхронизация
.pragma library

function getCurrentBlockInfo(editor, backend) {
    if (!editor) return null
    let fullText = editor.text
    let pos = editor.cursorPosition

    // Именованные блоки по спецификации: Имя Блока { ... }
    let blockRegex = /^([^{}\n\r]+?)\s*\{[ \t]*$/gm
    let endRegex = /^[ \t]*\}[ \t]*$/gm
    let match

    // Находим все открывающие скобки
    let blockStarts = []
    while ((match = blockRegex.exec(fullText)) !== null) {
        blockStarts.push({
            name: match[1].trim(),
            start: match.index,
            headerEnd: match.index + match[0].length
        })
    }

    if (blockStarts.length === 0) return null

    // Для каждого блока ищем парную закрывающую скобку '}'
    for (let i = 0; i < blockStarts.length; i++) {
        let b = blockStarts[i]
        let contentStart = b.headerEnd

        // Ищем закрывающую скобку до следующего блока или конца текста
        let searchEnd = (i + 1 < blockStarts.length) ? blockStarts[i + 1].start : fullText.length
        endRegex.lastIndex = contentStart
        let endMatch = endRegex.exec(fullText)
        let contentEnd = (endMatch && endMatch.index < searchEnd) ? endMatch.index : searchEnd

        if (pos > contentStart && pos <= contentEnd) {
            let rawContent = fullText.substring(contentStart, contentEnd)
            let cleanContent = rawContent.replace(/^\r?\n/, "").replace(/\r?\n$/, "").trim()

            if (!cleanContent) {
                if (typeof backend !== "undefined" && backend && typeof backend.get_block === "function") {
                    let existing = backend.get_block(b.name)
                    if (existing && existing.found && existing.content && existing.content.trim().length > 0) {
                        return {
                            heading: b.name,
                            headingNorm: b.name.toLowerCase(),
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
                heading: b.name,
                headingNorm: b.name.toLowerCase(),
                content: cleanContent,
                blockStart: b.start,
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
    let blockRegex = /^([^{}\n\r]+?)\s*\{[ \t]*$/gm
    let endRegex = /^[ \t]*\}[ \t]*$/gm
    let match

    let blockStarts = []
    while ((match = blockRegex.exec(fullText)) !== null) {
        blockStarts.push({
            name: match[1].trim(),
            start: match.index,
            headerEnd: match.index + match[0].length
        })
    }

    let updatedText = fullText
    let cursor = editor.cursorPosition
    let changed = false

    for (let i = blockStarts.length - 1; i >= 0; i--) {
        let b = blockStarts[i]
        if (b.name.toLowerCase() === headingNorm.toLowerCase()) {
            let contentStart = b.headerEnd
            let searchEnd = (i + 1 < blockStarts.length) ? blockStarts[i + 1].start : fullText.length
            endRegex.lastIndex = contentStart
            let endMatch = endRegex.exec(fullText)
            let contentEnd = (endMatch && endMatch.index < searchEnd) ? endMatch.index : searchEnd

            let oldContent = fullText.substring(contentStart, contentEnd)
            let cleanOld = oldContent.replace(/^\r?\n/, "").replace(/\r?\n$/, "").trim()
            let cleanNew = newContent.replace(/^\r?\n/, "").replace(/\r?\n$/, "").trim()
            if (cleanOld === cleanNew) continue

            let formattedNew = "\n    " + cleanNew + "\n"
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
