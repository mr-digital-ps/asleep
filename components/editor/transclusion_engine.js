// components/editor/transclusion_engine.js — управление нативным отображением трансклюзий как обычных блоков
.pragma library

/**
 * Разворачивает вызовы Имя() и Файл.Имя() в канонический вид блоков Имя { ... },
 * благодаря чему они визуально отображаются на листе ТОЧНО КАК ОБЫЧНЫЕ БЛОКИ:
 * с шевроном ▼ в гаттере, направляющими линиями и скрытием скобок в Live Mode.
 */
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
                var bodyLines = res.content.trim().split("\n").map(function(s) { return indent + "    " + s })
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
                var bodyLoc = resLoc.content.trim().split("\n").map(function(s) { return indentLoc + "    " + s })
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
    if (!text || !activeMap || Object.keys(activeMap).length === 0) {
        return { text: text, changed: false }
    }

    var lines = text.split("\n")
    var changed = false

    for (var key in activeMap) {
        var item = activeMap[key]
        var targetHeader = item.header + " {"

        for (var i = 0; i < lines.length; i++) {
            if (lines[i].indexOf(targetHeader) !== -1) {
                // Ищем парную закрывающую скобку } блока
                var closeIdx = -1
                for (var j = i + 1; j < lines.length; j++) {
                    if (lines[j].trim() === "}") {
                        closeIdx = j
                        break
                    }
                }
                if (closeIdx !== -1) {
                    lines = lines.slice(0, i).concat([item.rawCall]).concat(lines.slice(closeIdx + 1))
                    changed = true
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
