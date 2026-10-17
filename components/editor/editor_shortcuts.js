// editor_shortcuts.js — чистая логика форматирования и горячих клавиш редактора
// Канонические 14 единиц синтаксиса asleep-pyqt

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

function handleTabIndent(editor, isShift, tabSize) {
    let size = (typeof tabSize === "number" && tabSize > 0) ? Math.floor(tabSize) : 4
    let tabSpaces = " ".repeat(size)
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
            let unindented = lines.map(l => l.startsWith(tabSpaces) ? l.substring(size) : (l.startsWith("\t") ? l.substring(1) : l)).join("\n")
            editor.text = before + unindented + after
            editor.select(start, blockStart + unindented.length)
        } else {
            let lineEnd = fullText.indexOf("\n", blockStart)
            if (lineEnd === -1) lineEnd = fullText.length
            let currentLine = fullText.substring(blockStart, lineEnd)
            if (currentLine.startsWith(tabSpaces)) {
                editor.text = fullText.substring(0, blockStart) + currentLine.substring(size) + fullText.substring(lineEnd)
                editor.cursorPosition = Math.max(blockStart, start - size)
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
            let indented = lines.map(l => tabSpaces + l).join("\n")
            editor.text = before + indented + after
            editor.select(start + size, blockStart + indented.length)
        } else {
            editor.insert(editor.cursorPosition, tabSpaces)
        }
    }
}

function handleTab(editor, isShift, tabSize) {
    return handleTabIndent(editor, isShift, tabSize)
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

    let closingKeys = [")", "]", "}", "\"", "'", "`"]
    if (closingKeys.indexOf(char) !== -1) {
        if (pos < fullText.length && fullText.charAt(pos) === char) {
            editor.cursorPosition = pos + 1
            return true
        }
    }

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

    // 0a. Внешняя трансклюзия: Файл.Блок()
    let extMatch = textBeforeCursor.match(/^([ \t]*)([^.(){}\n\r]+?)\.([^.(){}\n\r]+)\s*\(\s*\)\s*$/)
    if (extMatch) {
        let indent = extMatch[1]
        let fStem = extMatch[2].trim()
        let bName = extMatch[3].trim()
        if (typeof backend !== "undefined" && backend && typeof backend.get_external_block === "function") {
            let block = backend.get_external_block(fStem, bName)
            if (block && block.found && block.content && block.content.trim().length > 0) {
                let body = block.content.trim().split("\n").map(function(s) { return indent + "    " + s }).join("\n")
                let newBlockText = indent + fStem + "." + bName + " {\n" + body + "\n" + indent + "}\n"
                editor.remove(lineStart, pos)
                editor.insert(lineStart, newBlockText)
                editor.cursorPosition = lineStart + newBlockText.length
                if (typeof onSyncNotice === "function") {
                    onSyncNotice(fStem + "." + bName)
                }
                return true
            }
        }
    }

    // 0b. Локальная трансклюзия: Блок()
    let locMatch = textBeforeCursor.match(/^([ \t]*)([^.(){}\n\r]+)\s*\(\s*\)\s*$/)
    if (locMatch) {
        let indentLoc = locMatch[1]
        let lName = locMatch[2].trim()
        if (typeof backend !== "undefined" && backend && typeof backend.get_block === "function") {
            let block = backend.get_block(lName)
            if (block && block.found && block.content && block.content.trim().length > 0) {
                let bodyLoc = block.content.trim().split("\n").map(function(s) { return indentLoc + "    " + s }).join("\n")
                let newBlockText = indentLoc + lName + " {\n" + bodyLoc + "\n" + indentLoc + "}\n"
                editor.remove(lineStart, pos)
                editor.insert(lineStart, newBlockText)
                editor.cursorPosition = lineStart + newBlockText.length
                if (typeof onSyncNotice === "function") {
                    onSyncNotice(lName)
                }
                return true
            }
        }
    }

    // 0c. Авто-заполнение именованного блока: Имя { ... }
    let blockMatch = textBeforeCursor.match(/^[ \t]*([a-zA-Zа-яА-ЯёЁ0-9_\-\s]+?)\s*\{\s*$/)
    if (blockMatch) {
        let blockName = blockMatch[1].trim()
        if (typeof backend !== "undefined" && backend) {
            let block = backend.get_block(blockName)
            if (block && block.found && block.content && block.content.trim().length > 0) {
                let insertText = "\n" + block.content.trim() + "\n}\n"
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

    // Обратная совместимость с # Заголовок
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

function updateBracketHighlights(editorArea, primaryHighlight, matchHighlight) {
    if (!primaryHighlight || !matchHighlight) return;
    if (!editorArea || !editorArea.activeFocus || editorArea.selectionStart !== editorArea.selectionEnd) {
        primaryHighlight.visible = false;
        matchHighlight.visible = false;
        return;
    }

    var pair = findMatchingBracket(editorArea.text, editorArea.cursorPosition);
    if (!pair) {
        primaryHighlight.visible = false;
        matchHighlight.visible = false;
        return;
    }

    var r1 = editorArea.positionToRectangle(pair.primary);
    var r2 = editorArea.positionToRectangle(pair.match);

    if (r1 && r1.height > 0) {
        primaryHighlight.x = r1.x;
        primaryHighlight.y = r1.y;
        primaryHighlight.width = Math.max(8, r1.width);
        primaryHighlight.height = r1.height;
        primaryHighlight.visible = true;
    } else {
        primaryHighlight.visible = false;
    }

    if (r2 && r2.height > 0) {
        matchHighlight.x = r2.x;
        matchHighlight.y = r2.y;
        matchHighlight.width = Math.max(8, r2.width);
        matchHighlight.height = r2.height;
        matchHighlight.visible = true;
    } else {
        matchHighlight.visible = false;
    }
}
