import QtQuick
import "../theme"

// Органическое непрерывное выделение: единый контур-полигон строк,
// каждая вершина которого скругляется через arcTo (выпуклые и вогнутые углы одинаково).
Canvas {
    id: root
    anchors.fill: parent

    property var editorArea: null
    property var outline: []          // вершины полигона [{x, y}]

    FontMetrics {
        id: fm
        font: root.editorArea ? root.editorArea.font : Qt.font({})
    }

    Connections {
        target: root.editorArea
        ignoreUnknownSignals: true
        function onSelectionStartChanged() { root.rebuild() }
        function onSelectionEndChanged() { root.rebuild() }
        function onWidthChanged() { root.rebuild() }
        function onTextChanged() { root.rebuild() }
        function onFontChanged() { root.rebuild() }
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
            rows.push({ x: rs.x, y: rs.y, w: re.x - rs.x, h: rs.height })
            if (best >= end) break
            pos = best + 1
        }
        return rows
    }

    function rebuild() {
        let pts = []
        if (editorArea) {
            let s = Math.min(editorArea.selectionStart, editorArea.selectionEnd)
            let e = Math.max(editorArea.selectionStart, editorArea.selectionEnd)
            if (s >= 0 && e > s) {
                let rows = collectRows(s, e)
                let cw = Math.max(1, Math.round(fm.advanceWidth(" ")))
                let lineStep = rows.length > 1 ? (rows[1].y - rows[0].y) : rows[0].h

                // Нормализуем строки: смежные без зазоров и наложений (bottom_i == top_{i+1})
                let n = rows.length
                let L = [], R = [], T = [], B = []
                for (let i = 0; i < n; i++) {
                    let r = rows[i]
                    let step = Math.max(r.h, lineStep)
                    let top = Math.round(r.y - (step - r.h) / 2)
                    L.push(Math.round(r.x))
                    R.push(Math.round(r.x + Math.max(0, r.w)) + cw)   // всегда +1 визуальный пробел
                    T.push(top)
                    B.push(top + step)
                }
                for (let i = 0; i < n - 1; i++) B[i] = T[i + 1]

                // Склеиваем микро-ступеньки (< 2 радиусов) — иначе arcTo даёт зубцы
                let snap = Theme.selectionRadius * 2
                for (let pass = 0; pass < 2; pass++) {
                    for (let i = 0; i < n - 1; i++) {
                        if (Math.abs(R[i] - R[i + 1]) < snap) R[i] = R[i + 1] = Math.max(R[i], R[i + 1])
                        if (Math.abs(L[i] - L[i + 1]) < snap) L[i] = L[i + 1] = Math.min(L[i], L[i + 1])
                    }
                }

                // Обход по часовой: правый край сверху вниз, левый край снизу вверх
                pts.push({ x: L[0], y: T[0] })
                for (let i = 0; i < n; i++) {
                    pts.push({ x: R[i], y: T[i] })
                    pts.push({ x: R[i], y: B[i] })
                }
                for (let i = n - 1; i >= 0; i--) {
                    pts.push({ x: L[i], y: B[i] })
                    pts.push({ x: L[i], y: T[i] })
                }
                pts = simplify(pts)
            }
        }
        outline = pts
        requestPaint()
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
        let p = outline
        let n = p.length
        if (n < 3) return

        let rad = Theme.selectionRadius
        function dist(a, b) { return Math.abs(a.x - b.x) + Math.abs(a.y - b.y) }

        ctx.fillStyle = Theme.selectionColor
        ctx.beginPath()
        // Старт — середина первого ребра
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
