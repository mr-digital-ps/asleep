import QtQuick
import "../theme"

// Органическое выделение текста:
// Связанные (перекрывающиеся по горизонтали) строки объединяются в единый непрерывный полигон
// со скруглёнными внешними и внутренними углами через arcTo.
// Строки без достаточного горизонтального перекрытия (< 2 * radius) рендерятся как
// независимые аккуратные скруглённые блоки.
Canvas {
    id: root
    anchors.fill: parent

    property var editorArea: null
    property var polygons: []

    FontMetrics {
        id: fm
        font: root.editorArea ? root.editorArea.font : Qt.font({})
    }

    Connections {
        target: root.editorArea
        ignoreUnknownSignals: true
        function onSelectionStartChanged() { root.rebuild() }
        function onSelectionEndChanged() { root.rebuild() }
        function onCursorPositionChanged() { root.rebuild() }
        function onWidthChanged() { root.rebuild() }
        function onTextChanged() { root.rebuild() }
        function onFontChanged() { root.rebuild() }
    }

    function getSingleRowStep(r) {
        let lhPercent = (typeof Theme !== "undefined" && Theme && Theme.defaultLineHeightPercent) ? Theme.defaultLineHeightPercent : 135.0
        return Math.round(r.h * (lhPercent / 100.0))
    }

    function collectRows(start, end) {
        let rows = []
        let pos = start
        while (pos < end) {
            let rs = editorArea.positionToRectangle(pos)
            let lo = pos, hi = end, best = pos
            while (lo <= hi) {
                let mid = Math.floor((lo + hi) / 2)
                if (Math.abs(editorArea.positionToRectangle(mid).y - rs.y) < 2.0) { best = mid; lo = mid + 1 }
                else hi = mid - 1
            }
            let re = editorArea.positionToRectangle(best)
            rows.push({ x: rs.x, y: rs.y, w: re.x - rs.x, h: rs.height, startPos: pos, endPos: best })
            if (best >= end) break
            pos = best + 1
        }
        return rows
    }

    function rebuild() {
        if (!editorArea) {
            if (polygons.length > 0) {
                polygons = []
                requestPaint()
            }
            return
        }

        let s = Math.min(editorArea.selectionStart, editorArea.selectionEnd)
        let e = Math.max(editorArea.selectionStart, editorArea.selectionEnd)

        // Оптимизация: если выделения нет и ранее не было, избегаем холостых запросов requestPaint
        if (s < 0 || s === e) {
            if (polygons.length > 0) {
                polygons = []
                requestPaint()
            }
            return
        }

        let resultPolygons = []
        let rows = collectRows(s, e)
        let n = rows.length
        if (n > 0) {
                    let cw = Math.max(1, Math.round(fm.advanceWidth(" ")))
                    let snap = Theme.selectionRadius * 2

                    // Вычисляем базовую геометрию каждой строки
                    let normRows = []
                    for (let i = 0; i < n; i++) {
                        let r = rows[i]
                        let isLastRow = (i === n - 1)
                        // Пробел добавляется только если строка пустая (r.w <= 0)
                        // или на промежуточных строках до конца строки (!isLastRow).
                        // На строке, где заканчивается выделение / стоит курсор, лишний отступ не добавляется.
                        let addSpace = (r.w <= 0) || (!isLastRow)
                        let rowW = Math.max(0, r.w) + (addSpace ? cw : 0)

                        let rowStep = (i < n - 1) ? (rows[i + 1].y - rows[i].y) : (n > 1 ? (rows[i].y - rows[i - 1].y) : getSingleRowStep(r))
                        if (rowStep <= 0) rowStep = getSingleRowStep(r)
                        if (rowStep <= 0) rowStep = Math.max(1, fm.height)

                        let step = Math.max(r.h, rowStep)
                        let top = Math.round(r.y - (step - r.h) / 2)
                        let left = Math.round(r.x)
                        let right = Math.round(r.x + rowW)
                        if (right <= left) right = left + cw

                        normRows.push({
                            L: left,
                            R: right,
                            T: top,
                            B: top + step
                        })
                    }

                    // Разбиваем строки на связные кластеры по достаточному горизонтальному перекрытию (>= snap)
                    let clusters = []
                    let currentCluster = [normRows[0]]
                    for (let i = 0; i < n - 1; i++) {
                        let r1 = normRows[i]
                        let r2 = normRows[i + 1]
                        let overlap = Math.min(r1.R, r2.R) - Math.max(r1.L, r2.L)
                        if (overlap >= snap) {
                            currentCluster.push(r2)
                        } else {
                            clusters.push(currentCluster)
                            currentCluster = [r2]
                        }
                    }
                    clusters.push(currentCluster)

                    // Строим сглаженный полигон для каждого кластера
                    for (let c = 0; c < clusters.length; c++) {
                        let pts = buildClusterPolygon(clusters[c], snap)
                        if (pts && pts.length >= 3) {
                            resultPolygons.push(pts)
                        }
                    }
                }
        polygons = resultPolygons
        requestPaint()
    }

    function buildClusterPolygon(cluster, snap) {
        let m = cluster.length
        if (m === 0) return []
        if (m === 1) {
            let r0 = cluster[0]
            return [
                { x: r0.L, y: r0.T },
                { x: r0.R, y: r0.T },
                { x: r0.R, y: r0.B },
                { x: r0.L, y: r0.B }
            ]
        }

        // Выравниваем вертикальные границы смежных строк внутри кластера без зазоров
        for (let i = 0; i < m - 1; i++) {
            cluster[i].B = cluster[i + 1].T
        }

        // Склеиваем микро-ступеньки (< snap) строго внутри кластера
        for (let pass = 0; pass < 2; pass++) {
            for (let i = 0; i < m - 1; i++) {
                if (Math.abs(cluster[i].R - cluster[i + 1].R) < snap) {
                    cluster[i].R = cluster[i + 1].R = Math.max(cluster[i].R, cluster[i + 1].R)
                }
                if (Math.abs(cluster[i].L - cluster[i + 1].L) < snap) {
                    cluster[i].L = cluster[i + 1].L = Math.min(cluster[i].L, cluster[i + 1].L)
                }
            }
        }

        let pts = []
        pts.push({ x: cluster[0].L, y: cluster[0].T })
        for (let i = 0; i < m; i++) {
            pts.push({ x: cluster[i].R, y: cluster[i].T })
            pts.push({ x: cluster[i].R, y: cluster[i].B })
        }
        for (let i = m - 1; i >= 0; i--) {
            pts.push({ x: cluster[i].L, y: cluster[i].B })
            pts.push({ x: cluster[i].L, y: cluster[i].T })
        }
        return simplify(pts)
    }

    // Убираем дубли и коллинеарные точки, чтобы скругления ставились только на реальных изломах
    function simplify(p) {
        let out = []
        for (let i = 0; i < p.length; i++) {
            let q = p[i], last = out[out.length - 1]
            if (!last || last.x !== q.x || last.y !== q.y) out.push(q)
        }
        if (out.length > 1 && out[0].x === out[out.length - 1].x && out[0].y === out[out.length - 1].y) out.pop()
        let changed = true
        while (changed && out.length > 3) {
            changed = false
            for (let i = 0; i < out.length; i++) {
                let a = out[(i - 1 + out.length) % out.length], b = out[i], c = out[(i + 1) % out.length]
                if ((a.x === b.x && b.x === c.x) || (a.y === b.y && b.y === c.y)) {
                    out.splice(i, 1); changed = true; break
                }
            }
        }
        return out
    }

    onPaint: {
        let ctx = getContext("2d")
        ctx.reset()
        if (!polygons || polygons.length === 0) return

        let rad = Theme.selectionRadius
        function dist(a, b) { return Math.abs(a.x - b.x) + Math.abs(a.y - b.y) }

        ctx.fillStyle = Theme.selectionColor

        for (let idx = 0; idx < polygons.length; idx++) {
            let p = polygons[idx]
            let n = p.length
            if (n < 3) continue

            ctx.beginPath()
            ctx.moveTo((p[0].x + p[1].x) / 2, (p[0].y + p[1].y) / 2)
            for (let k = 1; k <= n; k++) {
                let prev = p[(k - 1) % n], cur = p[k % n], next = p[(k + 1) % n]
                let r = Math.min(rad, dist(prev, cur) / 2, dist(cur, next) / 2)
                ctx.arcTo(cur.x, cur.y, next.x, next.y, r)
            }
            ctx.closePath()
            ctx.fill()
        }
    }
}
