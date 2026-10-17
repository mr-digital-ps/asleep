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

    var bestTargetX = null
    var bestTargetY = null

    for (var i = 0; i < otherPanes.length; i++) {
        var other = otherPanes[i]
        if (!other || other.id === draggedRect.id) continue

        var oX = other.x
        var oY = other.y
        var oW = other.width
        var oH = other.height
        var oRight = oX + oW
        var oBottom = oY + oH

        // 0. Если это viewport (границы видимой камеры): магнитим строго к 4 внутренним краям экрана
        if (other.id === "__viewport__") {
            var diffVpTop = Math.abs(curY - oY)
            if (diffVpTop < snapDist && diffVpTop < bestDiffY) {
                bestDiffY = diffVpTop
                finalY = oY
                isSnappedY = true
                bestTargetY = other
            }
            var diffVpBottom = Math.abs(curBottom - oBottom)
            if (diffVpBottom < snapDist && diffVpBottom < bestDiffY) {
                bestDiffY = diffVpBottom
                finalY = oBottom - curH
                isSnappedY = true
                bestTargetY = other
            }
            var diffVpLeft = Math.abs(curX - oX)
            if (diffVpLeft < snapDist && diffVpLeft < bestDiffX) {
                bestDiffX = diffVpLeft
                finalX = oX
                isSnappedX = true
                bestTargetX = other
            }
            var diffVpRight = Math.abs(curRight - oRight)
            if (diffVpRight < snapDist && diffVpRight < bestDiffX) {
                bestDiffX = diffVpRight
                finalX = oRight - curW
                isSnappedX = true
                bestTargetX = other
            }
            continue // Пропускаем проверку tab_merge и dock к внешним границам для viewport
        }

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
            bestTargetX = other
            dockTargetId = other.id
            dockSide = "right"
        }

        // Б. Правый край тащимого к Левому краю соседа (вплотную слева)
        var diffRightToLeft = Math.abs(curRight - oX)
        if (diffRightToLeft < snapDist && diffRightToLeft < bestDiffX) {
            bestDiffX = diffRightToLeft
            finalX = oX - curW
            isSnappedX = true
            bestTargetX = other
            dockTargetId = other.id
            dockSide = "left"
        }

        // В. Выравнивание по левой границе в одну колонку (Flush Left)
        var diffLeftToLeft = Math.abs(curX - oX)
        if (diffLeftToLeft < snapDist && diffLeftToLeft < bestDiffX) {
            bestDiffX = diffLeftToLeft
            finalX = oX
            isSnappedX = true
            bestTargetX = other
        }

        // Г. Выравнивание по правой границе (Flush Right)
        var diffRightToRight = Math.abs(curRight - oRight)
        if (diffRightToRight < snapDist && diffRightToRight < bestDiffX) {
            bestDiffX = diffRightToRight
            finalX = oRight - curW
            isSnappedX = true
            bestTargetX = other
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
            bestTargetY = other
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
            bestTargetY = other
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
            bestTargetY = other
        }

        // Г. Выравнивание по нижнему уровню (Same Bottom Level)
        var diffBottomToBottom = Math.abs(curBottom - oBottom)
        if (diffBottomToBottom < snapDist && diffBottomToBottom < bestDiffY) {
            bestDiffY = diffBottomToBottom
            finalY = oBottom - curH
            isSnappedY = true
            bestTargetY = other
        }
    }

    // Формируем направляющие линии для подсвечивания стыка
    if (isSnappedX) {
        var minY = finalY
        var maxY = finalY + curH
        if (bestTargetX && bestTargetX.id !== "__viewport__") {
            minY = Math.min(minY, bestTargetX.y)
            maxY = Math.max(maxY, bestTargetX.y + bestTargetX.height)
        }
        guidelines.push({
            x1: finalX,
            y1: minY - 8,
            x2: finalX,
            y2: maxY + 8,
            orientation: "v"
        })
    }

    if (isSnappedY) {
        var minX = finalX
        var maxX = finalX + curW
        if (bestTargetY && bestTargetY.id !== "__viewport__") {
            minX = Math.min(minX, bestTargetY.x)
            maxX = Math.max(maxX, bestTargetY.x + bestTargetY.width)
        }
        guidelines.push({
            x1: minX - 8,
            y1: finalY,
            x2: maxX + 8,
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

/**
 * Расчёт магнетизма при изменении размера прямоугольника к соседним панелям.
 * Магнитит как по граням (Flush/Dock), так и по совпадающим габаритам (Same Width/Height).
 *
 * @param {Object} draggedRect - { id, x, y, width, height }
 * @param {Array} otherPanes - массив { id, x, y, width, height }
 * @param {string} handleType - "right"|"left"|"bottom"|"top"|"bottom-right"|"bottom-left"|"top-right"|"top-left"
 * @param {number} threshold - радиус магнетизма в пикселях
 * @param {number} minWidth - минимальная ширина
 * @param {number} minHeight - минимальная высота
 * @returns {Object} результат: { snappedX, snappedY, snappedWidth, snappedHeight, guidelines }
 */
function calculateResizeSnap(draggedRect, otherPanes, handleType, threshold, minWidth, minHeight) {
    var snapDist = (typeof threshold === "number" && threshold > 0) ? threshold : DEFAULT_SNAP_THRESHOLD
    var minW = (typeof minWidth === "number" && minWidth > 0) ? minWidth : 380
    var minH = (typeof minHeight === "number" && minHeight > 0) ? minHeight : 300

    var curX = draggedRect.x
    var curY = draggedRect.y
    var curW = Math.max(minW, draggedRect.width)
    var curH = Math.max(minH, draggedRect.height)
    var curRight = curX + curW
    var curBottom = curY + curH

    var modifiesRight = (handleType === "right" || handleType === "bottom-right" || handleType === "top-right")
    var modifiesLeft = (handleType === "left" || handleType === "bottom-left" || handleType === "top-left")
    var modifiesBottom = (handleType === "bottom" || handleType === "bottom-right" || handleType === "bottom-left")
    var modifiesTop = (handleType === "top" || handleType === "top-right" || handleType === "top-left")

    var finalX = curX
    var finalY = curY
    var finalW = curW
    var finalH = curH

    var bestDiffX = snapDist + 1
    var bestDiffY = snapDist + 1
    var guidelines = []

    if (!otherPanes || otherPanes.length === 0) {
        return {
            snappedX: finalX,
            snappedY: finalY,
            snappedWidth: finalW,
            snappedHeight: finalH,
            isSnappedX: false,
            isSnappedY: false,
            isSnappedWidth: false,
            isSnappedHeight: false,
            guidelines: []
        }
    }

    var bestSnapOtherX = null
    var bestSnapOtherY = null
    var bestGuideX = null
    var bestGuideY = null

    for (var i = 0; i < otherPanes.length; i++) {
        var other = otherPanes[i]
        if (!other || other.id === draggedRect.id) continue

        var oX = other.x
        var oY = other.y
        var oW = other.width
        var oH = other.height
        var oRight = oX + oW
        var oBottom = oY + oH

        // =====================================================================
        // ГОРИЗОНТАЛЬНЫЙ РЕСАЙЗ-МАГНЕТИЗМ (Width / X)
        // =====================================================================
        if (modifiesRight) {
            // 1. Совпадение по ширине с соседом (Same Width)
            if (other.id !== "__viewport__") {
                var diffWidth = Math.abs(curW - oW)
                if (diffWidth < snapDist && diffWidth < bestDiffX) {
                    bestDiffX = diffWidth
                    finalW = oW
                    bestGuideX = curX + oW
                    bestSnapOtherX = other
                }
            }

            // 2. Правый край к правому краю соседа (Flush Right)
            var diffFlushRight = Math.abs(curRight - oRight)
            if (diffFlushRight < snapDist && diffFlushRight < bestDiffX) {
                var candidateW = oRight - curX
                if (candidateW >= minW) {
                    bestDiffX = diffFlushRight
                    finalW = candidateW
                    bestGuideX = oRight
                    bestSnapOtherX = other
                }
            }

            // 3. Правый край к левому краю соседа (Dock Left)
            var diffDockLeft = Math.abs(curRight - oX)
            if (diffDockLeft < snapDist && diffDockLeft < bestDiffX) {
                var candidateW = oX - curX
                if (candidateW >= minW) {
                    bestDiffX = diffDockLeft
                    finalW = candidateW
                    bestGuideX = oX
                    bestSnapOtherX = other
                }
            }
        } else if (modifiesLeft) {
            var fixedRight = curX + curW

            // 1. Совпадение по ширине с соседом (Same Width)
            if (other.id !== "__viewport__") {
                var diffWidth = Math.abs(curW - oW)
                if (diffWidth < snapDist && diffWidth < bestDiffX) {
                    bestDiffX = diffWidth
                    finalW = oW
                    finalX = fixedRight - oW
                    bestGuideX = finalX
                    bestSnapOtherX = other
                }
            }

            // 2. Левый край к левому краю соседа (Flush Left)
            var diffFlushLeft = Math.abs(curX - oX)
            if (diffFlushLeft < snapDist && diffFlushLeft < bestDiffX) {
                var candidateW = fixedRight - oX
                if (candidateW >= minW) {
                    bestDiffX = diffFlushLeft
                    finalX = oX
                    finalW = candidateW
                    bestGuideX = oX
                    bestSnapOtherX = other
                }
            }

            // 3. Левый край к правому краю соседа (Dock Right)
            var diffDockRight = Math.abs(curX - oRight)
            if (diffDockRight < snapDist && diffDockRight < bestDiffX) {
                var candidateW = fixedRight - oRight
                if (candidateW >= minW) {
                    bestDiffX = diffDockRight
                    finalX = oRight
                    finalW = candidateW
                    bestGuideX = oRight
                    bestSnapOtherX = other
                }
            }
        }

        // =====================================================================
        // ВЕРТИКАЛЬНЫЙ РЕСАЙЗ-МАГНЕТИЗМ (Height / Y)
        // =====================================================================
        if (modifiesBottom) {
            // 1. Совпадение по высоте с соседом (Same Height)
            if (other.id !== "__viewport__") {
                var diffHeight = Math.abs(curH - oH)
                if (diffHeight < snapDist && diffHeight < bestDiffY) {
                    bestDiffY = diffHeight
                    finalH = oH
                    bestGuideY = curY + oH
                    bestSnapOtherY = other
                }
            }

            // 2. Нижний край к нижнему краю соседа (Flush Bottom)
            var diffFlushBottom = Math.abs(curBottom - oBottom)
            if (diffFlushBottom < snapDist && diffFlushBottom < bestDiffY) {
                var candidateH = oBottom - curY
                if (candidateH >= minH) {
                    bestDiffY = diffFlushBottom
                    finalH = candidateH
                    bestGuideY = oBottom
                    bestSnapOtherY = other
                }
            }

            // 3. Нижний край к верхнему краю соседа (Dock Top)
            var diffDockTop = Math.abs(curBottom - oY)
            if (diffDockTop < snapDist && diffDockTop < bestDiffY) {
                var candidateH = oY - curY
                if (candidateH >= minH) {
                    bestDiffY = diffDockTop
                    finalH = candidateH
                    bestGuideY = oY
                    bestSnapOtherY = other
                }
            }
        } else if (modifiesTop) {
            var fixedBottom = curY + curH

            // 1. Совпадение по высоте с соседом (Same Height)
            if (other.id !== "__viewport__") {
                var diffHeight = Math.abs(curH - oH)
                if (diffHeight < snapDist && diffHeight < bestDiffY) {
                    bestDiffY = diffHeight
                    finalH = oH
                    finalY = fixedBottom - oH
                    bestGuideY = finalY
                    bestSnapOtherY = other
                }
            }

            // 2. Верхний край к верхнему краю соседа (Flush Top)
            var diffFlushTop = Math.abs(curY - oY)
            if (diffFlushTop < snapDist && diffFlushTop < bestDiffY) {
                var candidateH = fixedBottom - oY
                if (candidateH >= minH) {
                    bestDiffY = diffFlushTop
                    finalY = oY
                    finalH = candidateH
                    bestGuideY = oY
                    bestSnapOtherY = other
                }
            }

            // 3. Верхний край к нижнему краю соседа (Dock Bottom)
            var diffDockBottom = Math.abs(curY - oBottom)
            if (diffDockBottom < snapDist && diffDockBottom < bestDiffY) {
                var candidateH = fixedBottom - oBottom
                if (candidateH >= minH) {
                    bestDiffY = diffDockBottom
                    finalY = oBottom
                    finalH = candidateH
                    bestGuideY = oBottom
                    bestSnapOtherY = other
                }
            }
        }
    }

    if (bestGuideX !== null) {
        var minY = finalY
        var maxY = finalY + finalH
        if (bestSnapOtherX && bestSnapOtherX.id !== "__viewport__") {
            minY = Math.min(minY, bestSnapOtherX.y)
            maxY = Math.max(maxY, bestSnapOtherX.y + bestSnapOtherX.height)
        }
        guidelines.push({
            x1: bestGuideX,
            y1: minY - 8,
            x2: bestGuideX,
            y2: maxY + 8,
            orientation: "v"
        })
    }

    if (bestGuideY !== null) {
        var minX = finalX
        var maxX = finalX + finalW
        if (bestSnapOtherY && bestSnapOtherY.id !== "__viewport__") {
            minX = Math.min(minX, bestSnapOtherY.x)
            maxX = Math.max(maxX, bestSnapOtherY.x + bestSnapOtherY.width)
        }
        guidelines.push({
            x1: minX - 8,
            y1: bestGuideY,
            x2: maxX + 8,
            y2: bestGuideY,
            orientation: "h"
        })
    }

    return {
        snappedX: finalX,
        snappedY: finalY,
        snappedWidth: finalW,
        snappedHeight: finalH,
        isSnappedX: Math.abs(finalX - curX) > 0.001,
        isSnappedY: Math.abs(finalY - curY) > 0.001,
        isSnappedWidth: Math.abs(finalW - curW) > 0.001,
        isSnappedHeight: Math.abs(finalH - curH) > 0.001,
        guidelines: guidelines
    }
}
