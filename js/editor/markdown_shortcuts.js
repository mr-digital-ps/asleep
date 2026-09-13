// markdown_shortcuts.js — чистая логика форматирования и горячих клавиш редактора Markdown

function wrapSelection(editor, prefix, suffix) {
    let start = editor.selectionStart
    let end = editor.selectionEnd
    if (start !== end) {
        let selText = editor.selectedText
        editor.remove(start, end)
        editor.insert(start, prefix + selText + suffix)
        editor.select(start + prefix.length, start + prefix.length + selText.length)
    } else {
        editor.insert(start, prefix + suffix)
        editor.cursorPosition = start + prefix.length
    }
}

function toggleBold(editor) {
    if (!editor) return
    let start = editor.selectionStart
    let end = editor.selectionEnd
    if (start !== end) {
        let selText = editor.selectedText
        if (selText.startsWith("**") && selText.endsWith("**") && selText.length >= 4) {
            let unwrapped = selText.substring(2, selText.length - 2)
            editor.remove(start, end)
            editor.insert(start, unwrapped)
            editor.select(start, start + unwrapped.length)
            return
        }
    }
    wrapSelection(editor, "**", "**")
}

function toggleItalic(editor) {
    if (!editor) return
    let start = editor.selectionStart
    let end = editor.selectionEnd
    if (start !== end) {
        let selText = editor.selectedText
        if (selText.startsWith("*") && selText.endsWith("*") && !selText.startsWith("**") && selText.length >= 2) {
            let unwrapped = selText.substring(1, selText.length - 1)
            editor.remove(start, end)
            editor.insert(start, unwrapped)
            editor.select(start, start + unwrapped.length)
            return
        }
    }
    wrapSelection(editor, "*", "*")
}

function toggleHeading(editor, level) {
    let fullText = editor.text
    let pos = editor.cursorPosition
    let lineStart = fullText.lastIndexOf("\n", Math.max(0, pos - 1)) + 1
    let lineEnd = fullText.indexOf("\n", pos)
    if (lineEnd === -1) lineEnd = fullText.length
    let currentLine = fullText.substring(lineStart, lineEnd)

    let cleaned = currentLine.replace(/^([ \t]*)(#{1,6}\s*)/, "$1")
    let newHeading = ""
    if (level > 0) {
        let matchIndent = cleaned.match(/^([ \t]*)/)
        let indent = matchIndent ? matchIndent[1] : ""
        let rest = cleaned.substring(indent.length)
        newHeading = indent + "#".repeat(level) + " " + rest
    } else {
        newHeading = cleaned
    }

    editor.remove(lineStart, lineEnd)
    editor.insert(lineStart, newHeading)
    editor.cursorPosition = Math.min(lineStart + newHeading.length, pos + (newHeading.length - currentLine.length))
}

function toggleTask(editor) {
    let fullText = editor.text
    let pos = editor.cursorPosition
    let lineStart = fullText.lastIndexOf("\n", Math.max(0, pos - 1)) + 1
    let lineEnd = fullText.indexOf("\n", pos)
    if (lineEnd === -1) lineEnd = fullText.length
    let currentLine = fullText.substring(lineStart, lineEnd)

    let newLine = currentLine
    if (/\[ \]/.test(currentLine)) {
        newLine = currentLine.replace(/\[ \]/, "[x]")
    } else if (/\[[xX]\]/.test(currentLine)) {
        newLine = currentLine.replace(/\[[xX]\]/, "[ ]")
    } else if (/^([ \t]*)([-*+]) (.*)$/.test(currentLine)) {
        newLine = currentLine.replace(/^([ \t]*)([-*+]) (.*)$/, "$1$2 [ ] $3")
    } else {
        let match = currentLine.match(/^([ \t]*)(.*)$/)
        let indent = match ? match[1] : ""
        let rest = match ? match[2] : ""
        newLine = indent + "- [ ] " + rest
    }

    editor.remove(lineStart, lineEnd)
    editor.insert(lineStart, newLine)
    editor.cursorPosition = Math.min(lineStart + newLine.length, pos + (newLine.length - currentLine.length))
}

function duplicateLine(editor) {
    let fullText = editor.text
    let pos = editor.cursorPosition
    let lineStart = fullText.lastIndexOf("\n", Math.max(0, pos - 1)) + 1
    let lineEnd = fullText.indexOf("\n", pos)
    if (lineEnd === -1) lineEnd = fullText.length
    let currentLine = fullText.substring(lineStart, lineEnd)
    editor.insert(lineEnd, "\n" + currentLine)
}

function moveLineUp(editor) {
    let fullText = editor.text
    let pos = editor.cursorPosition
    let lineStart = fullText.lastIndexOf("\n", Math.max(0, pos - 1)) + 1
    if (lineStart > 0) {
        let prevLineStart = fullText.lastIndexOf("\n", lineStart - 2) + 1
        let lineEnd = fullText.indexOf("\n", pos)
        if (lineEnd === -1) lineEnd = fullText.length
        let currentLine = fullText.substring(lineStart, lineEnd)
        let prevLine = fullText.substring(prevLineStart, lineStart - 1)
        let before = fullText.substring(0, prevLineStart)
        let after = fullText.substring(lineEnd)
        editor.text = before + currentLine + "\n" + prevLine + after
        editor.cursorPosition = prevLineStart + (pos - lineStart)
    }
}

function moveLineDown(editor) {
    let fullText = editor.text
    let pos = editor.cursorPosition
    let lineStart = fullText.lastIndexOf("\n", Math.max(0, pos - 1)) + 1
    let lineEnd = fullText.indexOf("\n", pos)
    if (lineEnd !== -1) {
        let nextLineEnd = fullText.indexOf("\n", lineEnd + 1)
        if (nextLineEnd === -1) nextLineEnd = fullText.length
        let currentLine = fullText.substring(lineStart, lineEnd)
        let nextLine = fullText.substring(lineEnd + 1, nextLineEnd)
        let before = fullText.substring(0, lineStart)
        let after = fullText.substring(nextLineEnd)
        editor.text = before + nextLine + "\n" + currentLine + after
        editor.cursorPosition = lineStart + nextLine.length + 1 + (pos - lineStart)
    }
}

function handleTabIndent(editor, isShift) {
    let start = editor.selectionStart
    let end = editor.selectionEnd
    let fullText = editor.text
    if (isShift) {
        let blockStart = fullText.lastIndexOf("\n", Math.max(0, start - 1)) + 1
        if (start !== end) {
            let before = fullText.substring(0, blockStart)
            let middle = fullText.substring(blockStart, end)
            let after = fullText.substring(end)
            let lines = middle.split("\n")
            let unindented = lines.map(l => l.startsWith("    ") ? l.substring(4) : (l.startsWith("\t") ? l.substring(1) : l)).join("\n")
            editor.text = before + unindented + after
            editor.select(start, blockStart + unindented.length)
        } else {
            // Без выделения: снимаем отступ на текущей строке
            let lineEnd = fullText.indexOf("\n", blockStart)
            if (lineEnd === -1) lineEnd = fullText.length
            let currentLine = fullText.substring(blockStart, lineEnd)
            if (currentLine.startsWith("    ")) {
                editor.text = fullText.substring(0, blockStart) + currentLine.substring(4) + fullText.substring(lineEnd)
                editor.cursorPosition = Math.max(blockStart, start - 4)
            } else if (currentLine.startsWith("\t")) {
                editor.text = fullText.substring(0, blockStart) + currentLine.substring(1) + fullText.substring(lineEnd)
                editor.cursorPosition = Math.max(blockStart, start - 1)
            }
        }
    } else {
        if (start !== end) {
            let blockStart = fullText.lastIndexOf("\n", Math.max(0, start - 1)) + 1
            let before = fullText.substring(0, blockStart)
            let middle = fullText.substring(blockStart, end)
            let after = fullText.substring(end)
            let lines = middle.split("\n")
            let indented = lines.map(l => "    " + l).join("\n")
            editor.text = before + indented + after
            editor.select(start + 4, blockStart + indented.length)
        } else {
            editor.insert(editor.cursorPosition, "    ")
        }
    }
}

function handleTab(editor, isShift) {
    return handleTabIndent(editor, isShift)
}

function handleAutoWrap(editor, char) {
    let pairs = {
        "*": "*", "_": "_", "~": "~", "`": "`",
        "(": ")", ")": ")",
        "[": "]", "]": "]",
        "{": "}", "}": "}",
        "\"": "\"", "'": "'"
    }
    let suffix = pairs[char]
    if (suffix) {
        wrapSelection(editor, char === ")" ? "(" : (char === "]" ? "[" : (char === "}" ? "{" : char)), suffix)
        return true
    }
    return false
}

function handleAutoPair(editor, char) {
    if (!editor) return false
    let start = editor.selectionStart
    let end = editor.selectionEnd
    if (start !== end) return false

    let pairs = {
        "(": ")",
        "[": "]",
        "{": "}",
        "\"": "\"",
        "'": "'",
        "`": "`"
    }

    let fullText = editor.text || ""
    let pos = editor.cursorPosition

    // 1. Если введен закрывающий символ, и курсор уже стоит перед ним — просто перешагиваем
    let closingKeys = [")", "]", "}", "\"", "'", "`"]
    if (closingKeys.indexOf(char) !== -1) {
        if (pos < fullText.length && fullText.charAt(pos) === char) {
            editor.cursorPosition = pos + 1
            return true
        }
    }

    // 2. Если введен открывающий символ — вставляем пару и ставим курсор в середину
    let close = pairs[char]
    if (close) {
        editor.insert(pos, char + close)
        editor.cursorPosition = pos + 1
        return true
    }

    return false
}

function handleAutoPairBackspace(editor) {
    if (!editor) return false
    let start = editor.selectionStart
    let end = editor.selectionEnd
    if (start !== end) return false

    let pos = editor.cursorPosition
    if (pos <= 0) return false

    let fullText = editor.text || ""
    if (pos >= fullText.length + 1) return false

    let cBefore = fullText.charAt(pos - 1)
    let cAfter = fullText.charAt(pos)

    let pairs = {
        "(": ")",
        "[": "]",
        "{": "}",
        "\"": "\"",
        "'": "'",
        "`": "`"
    }

    if (pairs[cBefore] && pairs[cBefore] === cAfter) {
        editor.remove(pos - 1, pos + 1)
        editor.cursorPosition = pos - 1
        return true
    }

    return false
}

function handleSmartEnter(editor, backend, onSyncNotice) {
    let fullText = editor.text
    let pos = editor.cursorPosition
    let lineStart = fullText.lastIndexOf("\n", Math.max(0, pos - 1)) + 1
    let textBeforeCursor = fullText.substring(lineStart, pos)

    // 0. Синхронизированный блок заголовка (Трансклюзия по #..###### Заголовок)
    let headingMatch = textBeforeCursor.match(/^[ \t]*(#{1,6})\s+(.+)$/)
    if (headingMatch) {
        let headingText = headingMatch[2].trim()
        if (typeof backend !== "undefined" && backend) {
            let block = backend.get_block(headingText)
            if (block && block.found && block.content && block.content.trim().length > 0) {
                let insertText = "\n" + block.content.trim() + "\n\n"
                editor.insert(pos, insertText)
                editor.cursorPosition = pos + insertText.length
                if (typeof onSyncNotice === "function") {
                    onSyncNotice(block.title)
                }
                return true
            }
        }
        editor.insert(pos, "\n")
        return true
    }

    // 1. Чекбокс задачи: - [ ] или - [x]
    let taskMatch = textBeforeCursor.match(/^([ \t]*[-*+]) \[[ xX]\] (.*)$/)
    if (taskMatch) {
        let prefix = taskMatch[1]
        let content = taskMatch[2].trim()
        if (content === "") {
            editor.remove(lineStart, pos)
            return true
        } else {
            editor.insert(pos, "\n" + prefix + " [ ] ")
            return true
        }
    }

    // 2. Маркированный список: - , * , +
    let bulletMatch = textBeforeCursor.match(/^([ \t]*[-*+]) (.*)$/)
    if (bulletMatch) {
        let prefix = bulletMatch[1]
        let content = bulletMatch[2].trim()
        if (content === "") {
            editor.remove(lineStart, pos)
            return true
        } else {
            editor.insert(pos, "\n" + prefix + " ")
            return true
        }
    }

    // 3. Нумерованный список: 1. , 2.
    let numMatch = textBeforeCursor.match(/^([ \t]*)(\d+)\. (.*)$/)
    if (numMatch) {
        let indent = numMatch[1]
        let num = parseInt(numMatch[2], 10)
        let content = numMatch[3].trim()
        if (content === "") {
            editor.remove(lineStart, pos)
            return true
        } else {
            let nextNum = (num + 1) + ". "
            editor.insert(pos, "\n" + indent + nextNum)
            return true
        }
    }

    // 4. Цитата: >
    let quoteMatch = textBeforeCursor.match(/^([ \t]*> ?)(.*)$/)
    if (quoteMatch) {
        let prefix = quoteMatch[1]
        let content = quoteMatch[2].trim()
        if (content === "") {
            editor.remove(lineStart, pos)
            return true
        } else {
            editor.insert(pos, "\n" + prefix)
            return true
        }
    }

    // 5. Обычный авто-отступ пробелами
    let indentMatch = textBeforeCursor.match(/^([ \t]+)/)
    let indent = indentMatch ? indentMatch[1] : ""
    editor.insert(pos, "\n" + indent)
    return true
}

function findMatchingBracket(text, cursorPosition) {
    if (!text || cursorPosition < 0 || cursorPosition > text.length) return null;

    var pairs = {
        '(': { partner: ')', forward: true },
        '[': { partner: ']', forward: true },
        '{': { partner: '}', forward: true },
        ')': { partner: '(', forward: false },
        ']': { partner: '[', forward: false },
        '}': { partner: '{', forward: false }
    };

    var checkPositions = [];
    if (cursorPosition > 0) checkPositions.push(cursorPosition - 1);
    if (cursorPosition < text.length) checkPositions.push(cursorPosition);

    var foundPrimary = -1;
    var info = null;

    for (var i = 0; i < checkPositions.length; i++) {
        var p = checkPositions[i];
        var ch = text.charAt(p);
        if (pairs[ch]) {
            foundPrimary = p;
            info = pairs[ch];
            break;
        }
    }

    if (foundPrimary === -1 || !info) return null;

    var target = info.partner;
    var source = text.charAt(foundPrimary);
    var depth = 0;

    if (info.forward) {
        for (var j = foundPrimary; j < text.length; j++) {
            var c = text.charAt(j);
            if (c === source) {
                depth++;
            } else if (c === target) {
                depth--;
                if (depth === 0) {
                    return { primary: foundPrimary, match: j };
                }
            }
        }
    } else {
        for (var k = foundPrimary; k >= 0; k--) {
            var c2 = text.charAt(k);
            if (c2 === source) {
                depth++;
            } else if (c2 === target) {
                depth--;
                if (depth === 0) {
                    return { primary: foundPrimary, match: k };
                }
            }
        }
    }

    return null;
}

