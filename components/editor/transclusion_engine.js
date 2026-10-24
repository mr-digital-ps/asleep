// components/editor/transclusion_engine.js — управление нативным отображением трансклюзий как обычных блоков
.pragma library

/**
 * Разворачивает вызовы Имя() и Файл.Имя() в канонический вид блоков Имя { ... },
 * благодаря чему они визуально отображаются на листе ТОЧНО КАК ОБЫЧНЫЕ БЛОКИ:
 * с шевроном ▼ в гаттере, направляющими линиями и скрытием скобок в Live Mode.
 */
function dedentText(text) {
    if (!text) return ""
    var lines = text.split("\n")
    var minIndent = Infinity
    for (var i = 0; i < lines.length; i++) {
        var l = lines[i]
        if (!l.trim()) continue
        var m = l.match(/^([ \t]*)/)
        var indLen = m ? m[1].length : 0
        if (indLen < minIndent) minIndent = indLen
    }
    if (minIndent === Infinity || minIndent === 0) return lines.join("\n")
    return lines.map(function(l) {
        if (!l.trim()) return ""
        return (l.length >= minIndent) ? l.substring(minIndent) : l.trimStart()
    }).join("\n")
}

function expandTransclusions(text, backend, activeMap) {
    if (!text || !backend) return { text: text, changed: false, map: activeMap || {} }

    var lines = text.split("\n")
    var inCode = false
    var changed = false
    var newMap = Object.assign({}, activeMap || {})

    // Регулярные выражения вызовов:
    // Внешняя трансклюзия: Файл.Блок()
    var extRegex = /^([ \t]*)([^.(){}\n\r]+?)\.([^.(){}\n\r]+)\s*\(\s*\)[ \t]*$/
    // Локальная трансклюзия: Блок()
    var locRegex = /^([ \t]*)([^.(){}\n\r]+)\s*\(\s*\)[ \t]*$/

    for (var i = 0; i < lines.length; i++) {
        var line = lines[i]
        if (line.trim().startsWith("```")) {
            inCode = !inCode
            continue
        }
        if (inCode) continue

        // 1. Внешний вызов: Файл.Блок()
        var extMatch = line.match(extRegex)
        if (extMatch) {
            var indent = extMatch[1]
            var fStem = extMatch[2].trim()
            var bName = extMatch[3].trim()
            var extKey = fStem + "." + bName
            var res = (typeof backend.get_external_block === "function") ? backend.get_external_block(fStem, bName) : null
            if (res && res.found && res.content && res.content.trim().length > 0) {
                var headerLine = indent + extKey + " {"
                var cleanContent = dedentText(res.content.replace(/^\r?\n+|\r?\n+$/g, ""))
                var bodyLines = cleanContent.split("\n").map(function(s) {
                    return s.trim().length > 0 ? (indent + "    " + s) : ""
                })
                var closeLine = indent + "}"
                var blockLines = [headerLine].concat(bodyLines).concat([closeLine])

                newMap[extKey] = {
                    rawCall: line,
                    header: extKey
                }
                lines = lines.slice(0, i).concat(blockLines).concat(lines.slice(i + 1))
                i += blockLines.length - 1
                changed = true
            }
            continue
        }

        // 2. Локальный вызов: Блок()
        var locMatch = line.match(locRegex)
        if (locMatch) {
            var indentLoc = locMatch[1]
            var lName = locMatch[2].trim()
            var locKey = lName
            var resLoc = (typeof backend.get_block === "function") ? backend.get_block(lName) : null
            if (resLoc && resLoc.found && resLoc.content && resLoc.content.trim().length > 0) {
                var headerLoc = indentLoc + locKey + " {"
                var cleanContentLoc = dedentText(resLoc.content.replace(/^\r?\n+|\r?\n+$/g, ""))
                var bodyLoc = cleanContentLoc.split("\n").map(function(s) {
                    return s.trim().length > 0 ? (indentLoc + "    " + s) : ""
                })
                var closeLoc = indentLoc + "}"
                var blockLinesLoc = [headerLoc].concat(bodyLoc).concat([closeLoc])

                newMap[locKey] = {
                    rawCall: line,
                    header: locKey
                }
                lines = lines.slice(0, i).concat(blockLinesLoc).concat(lines.slice(i + 1))
                i += blockLinesLoc.length - 1
                changed = true
            }
        }
    }

    return {
        text: lines.join("\n"),
        changed: changed,
        map: newMap
    }
}

/**
 * Сворачивает блоки обратно в чистый исходный синтаксис вызова Имя() / Файл.Имя().
 * Применяется при переходе в Source Mode (Alt+S) и при сохранении на диск (Ctrl+S).
 */
function collapseTransclusions(text, activeMap) {
    if (!text) {
        return { text: text, changed: false }
    }

    var lines = text.split("\n")
    var changed = false

    // 1. Сворачивание по activeMap
    if (activeMap && Object.keys(activeMap).length > 0) {
        for (var key in activeMap) {
            var item = activeMap[key]
            var targetHeader = item.header + " {"
            var collapsedTarget = item.header + " ...."

            // 1a. Восстанавливаем свернутые заголовки трансклюзий
            for (var k = 0; k < lines.length; k++) {
                if (lines[k].trim() === collapsedTarget || lines[k].trim().indexOf(collapsedTarget) !== -1) {
                    lines[k] = item.rawCall
                    changed = true
                }
            }

            // 1b. Сворачиваем развернутые тела трансклюзий обратно в rawCall с балансировкой глубины
            var foundAny = true
            while (foundAny) {
                foundAny = false
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].indexOf(targetHeader) !== -1) {
                        var closeIdx = -1
                        var depth = 0
                        for (var j = i; j < lines.length; j++) {
                            var l = lines[j]
                            var opens = (l.match(/\{/g) || []).length
                            var closes = (l.match(/\}/g) || []).length
                            depth += opens - closes
                            if (j > i && depth <= 0) {
                                closeIdx = j
                                break
                            }
                        }
                        if (closeIdx !== -1) {
                            lines = lines.slice(0, i).concat([item.rawCall]).concat(lines.slice(closeIdx + 1))
                            changed = true
                            foundAny = true
                            break
                        }
                    }
                }
            }
        }
    }

    // 2. Гарантированное сворачивание любых внешних блоков Файл.Блок { ... }
    // (По канону asleep точка в имени блока зарезервирована исключительно для трансклюзий)
    var extHeaderRegex = /^([ \t]*)([^.(){}\n\r]+?)\.([^.(){}\n\r]+)\s*\{[ \t]*$/
    var extCollapsedRegex = /^([ \t]*)([^.(){}\n\r]+?)\.([^.(){}\n\r]+)\s*\.{3,4}[ \t]*$/

    // 2a. Свернутые заголовки Файл.Блок ....
    for (var m = 0; m < lines.length; m++) {
        var cMatch = lines[m].match(extCollapsedRegex)
        if (cMatch) {
            lines[m] = cMatch[1] + cMatch[2].trim() + "." + cMatch[3].trim() + "()"
            changed = true
        }
    }

    // 2b. Развернутые тела Файл.Блок { ... }
    var scanExt = true
    while (scanExt) {
        scanExt = false
        for (var n = 0; n < lines.length; n++) {
            var hMatch = lines[n].match(extHeaderRegex)
            if (hMatch) {
                var cCloseIdx = -1
                var cDepth = 0
                for (var p = n; p < lines.length; p++) {
                    var lineP = lines[p]
                    var opensP = (lineP.match(/\{/g) || []).length
                    var closesP = (lineP.match(/\}/g) || []).length
                    cDepth += opensP - closesP
                    if (p > n && cDepth <= 0) {
                        cCloseIdx = p
                        break
                    }
                }
                if (cCloseIdx !== -1) {
                    var rawCallStr = hMatch[1] + hMatch[2].trim() + "." + hMatch[3].trim() + "()"
                    lines = lines.slice(0, n).concat([rawCallStr]).concat(lines.slice(cCloseIdx + 1))
                    changed = true
                    scanExt = true
                    break
                }
            }
        }
    }

    return {
        text: lines.join("\n"),
        changed: changed
    }
}
