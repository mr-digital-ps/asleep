// components/workspace/snap_engine.js — Чистый математический движок магнетизма и стыковки панелей
// Расчёт прилипания граней (Edge-to-Edge Snapping) и выравнивания вкладок.

.pragma library

var DEFAULT_SNAP_THRESHOLD = 18

/**
 * Проверяет магнетизм перемещаемого прямоугольника к списку стационарных прямоугольников.
 * 
 * @param {Object} draggedRect - { id, x, y, width, height }
 * @param {Array} otherPanes - массив { id, x, y, width, height }
 * @param {number} threshold - радиус захвата магнита в пикселях (дефолт: 18)
 * @returns {Object} результат: {
 *   snappedX: number,
 *   snappedY: number,
 *   isSnappedX: boolean,
 *   isSnappedY: boolean,
 *   guidelines: Array, // [{ x1, y1, x2, y2, orientation: "v"|"h" }]
 *   dockTargetId: string|null,
 *   dockSide: string|null // "left" | "right" | "top" | "bottom" | "tab_merge"
 * }
 */
function calculateSnap(draggedRect, otherPanes, threshold) {
    var snapDist = (typeof threshold === "number" && threshold > 0) ? threshold : DEFAULT_SNAP_THRESHOLD
    var curX = draggedRect.x
    var curY = draggedRect.y
    var curW = draggedRect.width
    var curH = draggedRect.height
    var curRight = curX + curW
    var curBottom = curY + curH

    var bestDiffX = snapDist + 1
    var bestDiffY = snapDist + 1
    var finalX = curX
    var finalY = curY
    var isSnappedX = false
    var isSnappedY = false

    var guidelines = []
    var dockTargetId = null
    var dockSide = null

    if (!otherPanes || otherPanes.length === 0) {
        return {
            snappedX: curX,
            snappedY: curY,
            isSnappedX: false,
            isSnappedY: false,
            guidelines: [],
            dockTargetId: null,
            dockSide: null
        }
    }

    for (var i = 0; i < otherPanes.length; i++) {
        var other = otherPanes[i]
        if (!other || other.id === draggedRect.id) continue

        var oX = other.x
        var oY = other.y
        var oW = other.width
        var oH = other.height
        var oRight = oX + oW
        var oBottom = oY + oH

        // Проверяем слияние во вкладку (Tab Merge): если центр шапки тащимого листа попал в верхнюю область соседа
        var headerZoneH = 44
        var draggedCenterX = curX + curW / 2
        var draggedCenterY = curY + headerZoneH / 2
        if (draggedCenterX >= oX && draggedCenterX <= oRight &&
            draggedCenterY >= oY && draggedCenterY <= (oY + headerZoneH)) {
            dockTargetId = other.id
            dockSide = "tab_merge"
            // При слиянии во вкладку подсвечиваем шапку целевого окна
            guidelines.push({
                x1: oX,
                y1: oY,
                x2: oRight,
                y2: oY + headerZoneH,
                orientation: "rect"
            })
            return {
                snappedX: oX,
                snappedY: oY,
                isSnappedX: true,
                isSnappedY: true,
                guidelines: guidelines,
                dockTargetId: dockTargetId,
                dockSide: dockSide
            }
        }

        // =====================================================================
        // 1. ГОРИЗОНТАЛЬНЫЙ МАГНЕТИЗМ (Ось X)
        // =====================================================================

        // А. Левый край тащимого к Правому краю соседа (вплотную справа)
        var diffLeftToRight = Math.abs(curX - oRight)
        if (diffLeftToRight < snapDist && diffLeftToRight < bestDiffX) {
            bestDiffX = diffLeftToRight
            finalX = oRight
            isSnappedX = true
            dockTargetId = other.id
            dockSide = "right"
        }

        // Б. Правый край тащимого к Левому краю соседа (вплотную слева)
        var diffRightToLeft = Math.abs(curRight - oX)
        if (diffRightToLeft < snapDist && diffRightToLeft < bestDiffX) {
            bestDiffX = diffRightToLeft
            finalX = oX - curW
            isSnappedX = true
            dockTargetId = other.id
            dockSide = "left"
        }

        // В. Выравнивание по левой границе в одну колонку (Flush Left)
        var diffLeftToLeft = Math.abs(curX - oX)
        if (diffLeftToLeft < snapDist && diffLeftToLeft < bestDiffX) {
            bestDiffX = diffLeftToLeft
            finalX = oX
            isSnappedX = true
        }

        // Г. Выравнивание по правой границе (Flush Right)
        var diffRightToRight = Math.abs(curRight - oRight)
        if (diffRightToRight < snapDist && diffRightToRight < bestDiffX) {
            bestDiffX = diffRightToRight
            finalX = oRight - curW
            isSnappedX = true
        }

        // =====================================================================
        // 2. ВЕРТИКАЛЬНЫЙ МАГНЕТИЗМ (Ось Y)
        // =====================================================================

        // А. Верхний край тащимого к Нижнему краю соседа (вплотную снизу)
        var diffTopToBottom = Math.abs(curY - oBottom)
        if (diffTopToBottom < snapDist && diffTopToBottom < bestDiffY) {
            bestDiffY = diffTopToBottom
            finalY = oBottom
            isSnappedY = true
            if (!dockSide) {
                dockTargetId = other.id
                dockSide = "bottom"
            }
        }

        // Б. Нижний край тащимого к Верхнему краю соседа (вплотную сверху)
        var diffBottomToTop = Math.abs(curBottom - oY)
        if (diffBottomToTop < snapDist && diffBottomToTop < bestDiffY) {
            bestDiffY = diffBottomToTop
            finalY = oY - curH
            isSnappedY = true
            if (!dockSide) {
                dockTargetId = other.id
                dockSide = "top"
            }
        }

        // В. Выравнивание по верхнему уровню (Same Top Level)
        var diffTopToTop = Math.abs(curY - oY)
        if (diffTopToTop < snapDist && diffTopToTop < bestDiffY) {
            bestDiffY = diffTopToTop
            finalY = oY
            isSnappedY = true
        }

        // Г. Выравнивание по нижнему уровню (Same Bottom Level)
        var diffBottomToBottom = Math.abs(curBottom - oBottom)
        if (diffBottomToBottom < snapDist && diffBottomToBottom < bestDiffY) {
            bestDiffY = diffBottomToBottom
            finalY = oBottom - curH
            isSnappedY = true
        }
    }

    // Формируем направляющие линии для подсвечивания стыка
    if (isSnappedX) {
        guidelines.push({
            x1: finalX,
            y1: Math.min(finalY, oY || finalY) - 20,
            x2: finalX,
            y2: Math.max(finalY + curH, (oBottom || (finalY + curH))) + 20,
            orientation: "v"
        })
    }

    if (isSnappedY) {
        guidelines.push({
            x1: Math.min(finalX, oX || finalX) - 20,
            y1: finalY,
            x2: Math.max(finalX + curW, (oRight || (finalX + curW))) + 20,
            y2: finalY,
            orientation: "h"
        })
    }

    return {
        snappedX: isSnappedX ? finalX : curX,
        snappedY: isSnappedY ? finalY : curY,
        isSnappedX: isSnappedX,
        isSnappedY: isSnappedY,
        guidelines: guidelines,
        dockTargetId: dockTargetId,
        dockSide: dockSide
    }
}
