// js/graph/graph_interaction.js — Интерактивное управление графом связей (Zoom, Pan, Drag, Hit Test, Hover, Pre-warming)

var globalNodePositionsCache = {}

function normalizeUrl(url) {
    if (!url) return ""
    return decodeURIComponent(url.toString().replace(/^file:\/\/\/?/i, "").toLowerCase().replace(/\\/g, "/"))
}

function zoomAt(graphRoot, canvas, sx, sy, zoomFactor) {
    var oldZoom = graphRoot.zoomScale
    var newZoom = Math.max(0.25, Math.min(3.5, oldZoom * zoomFactor))
    if (Math.abs(newZoom - oldZoom) < 0.0001) return

    var ratio = 1.0 - newZoom / oldZoom
    graphRoot.panX += (sx - graphRoot.width / 2 - graphRoot.panX) * ratio
    graphRoot.panY += (sy - graphRoot.height / 2 - graphRoot.panY) * ratio
    graphRoot.zoomScale = newZoom

    wakeSimulation(graphRoot, canvas)
    if (canvas) canvas.requestPaint()
}

function keepActiveNodeCentered(graphRoot) {
    if (!graphRoot.activeNodeId || !graphRoot.sim || !graphRoot.sim.nodes) return
    var curW = (graphRoot.width > 50) ? graphRoot.width : 0
    var curH = (graphRoot.height > 50) ? graphRoot.height : 0
    if (!curW || !curH) return

    for (var i = 0; i < graphRoot.sim.nodes.length; i++) {
        var n = graphRoot.sim.nodes[i]
        if (n.id === graphRoot.activeNodeId) {
            graphRoot.panX = -(n.x - curW / 2) * graphRoot.zoomScale
            graphRoot.panY = -(n.y - curH / 2) * graphRoot.zoomScale
            break
        }
    }
}

function centerOnNode(graphRoot, canvas, targetFileUrl) {
    if (!graphRoot.sim || !graphRoot.sim.nodes || graphRoot.sim.nodes.length === 0) return false
    var curW = (graphRoot.width > 50) ? graphRoot.width : (canvas && canvas.width > 50 ? canvas.width : 0)
    var curH = (graphRoot.height > 50) ? graphRoot.height : (canvas && canvas.height > 50 ? canvas.height : 0)
    if (!curW || !curH) return false

    var target = targetFileUrl || graphRoot.activeFileUrl
    if (!target) return false
    var normTarget = normalizeUrl(target)
    var found = null

    for (var i = 0; i < graphRoot.sim.nodes.length; i++) {
        var n = graphRoot.sim.nodes[i]
        if (n.type === "file" && n.fileUrl && (n.fileUrl === target || normalizeUrl(n.fileUrl) === normTarget)) {
            found = n
            break
        }
    }
    if (found) {
        graphRoot.activeNodeId = found.id
        graphRoot.panX = -(found.x - curW / 2) * graphRoot.zoomScale
        graphRoot.panY = -(found.y - curH / 2) * graphRoot.zoomScale
        graphRoot.lastCenteredUrl = target
        if (canvas) canvas.requestPaint()
        return true
    }
    return false
}

function pluralize(n, one, few, many) {
    var mod10 = n % 10
    var mod100 = n % 100
    if (mod100 >= 11 && mod100 <= 19) return many
    if (mod10 === 1) return one
    if (mod10 >= 2 && mod10 <= 4) return few
    return many
}

function getGraphStats(sim, isLocal) {
    if (!sim || !sim.nodes) return ""
    var nFiles = 0
    var nBlocks = 0
    var nTags = 0
    for (var i = 0; i < sim.nodes.length; i++) {
        var t = sim.nodes[i].type
        if (t === "file") nFiles++
        else if (t === "block") nBlocks++
        else if (t === "tag") nTags++
    }
    var nLinks = (sim.links ? sim.links.length : 0)
    var parts = []
    if (nFiles > 0) parts.push(nFiles + " " + pluralize(nFiles, "заметка", "заметки", "заметок"))
    if (nLinks > 0) parts.push(nLinks + " " + pluralize(nLinks, "связь", "связи", "связей"))
    if (nTags > 0) parts.push(nTags + " " + pluralize(nTags, "тег", "тега", "тегов"))
    if (nBlocks > 0) parts.push(nBlocks + " " + pluralize(nBlocks, "блок", "блока", "блоков"))
    var text = parts.join(" · ")
    return isLocal ? ("Локальный граф · " + text) : text
}

function reloadGraph(graphRoot, canvas, backend, Physics, animTimer, forcedW, forcedH) {
    if (!backend || typeof backend.get_graph_data !== "function") return
    var data = backend.get_graph_data(graphRoot.folderUrl)
    if (!data || !data.nodes) return

    var config = {}
    if (typeof backend.get_graph_config === "function") {
        try {
            config = JSON.parse(JSON.stringify(backend.get_graph_config(graphRoot.folderUrl) || {}))
        } catch (e) {
            config = {}
        }
    }
    graphRoot.graphConfig = config

    var pureNodes = JSON.parse(JSON.stringify(data.nodes))
    var pureLinks = JSON.parse(JSON.stringify(data.links || []))

    // Фильтрация слоев (отключенные слои полностью исключаются из симуляции физики)
    var showBlocks = (graphRoot.showBlocks !== false)
    var showTags = (graphRoot.showTags !== false)

    if (!showBlocks || !showTags) {
        var allowedNodeIds = {}
        pureNodes = pureNodes.filter(function(n) {
            if (n.type === "block" && !showBlocks) return false
            if (n.type === "tag" && !showTags) return false
            allowedNodeIds[n.id] = true
            return true
        })

        pureLinks = pureLinks.filter(function(lk) {
            var srcId = (typeof lk.source === "object" && lk.source !== null) ? lk.source.id : lk.source
            var tgtId = (typeof lk.target === "object" && lk.target !== null) ? lk.target.id : lk.target
            return !!(allowedNodeIds[srcId] && allowedNodeIds[tgtId])
        })
    }

    // Фильтрация для режима локального графа (Local Graph) текущей заметки (1-hop connections)
    var localTargetNode = null
    if (graphRoot.isLocalGraph && graphRoot.activeFileUrl) {
        var normAct = normalizeUrl(graphRoot.activeFileUrl)
        for (var f = 0; f < pureNodes.length; f++) {
            var nd = pureNodes[f]
            if (nd.type === "file" && nd.fileUrl && 
                (nd.fileUrl === graphRoot.activeFileUrl || normalizeUrl(nd.fileUrl) === normAct)) {
                localTargetNode = nd
                break
            }
        }

        if (localTargetNode) {
            var targetId = localTargetNode.id
            var localConnectedIds = {}
            localConnectedIds[targetId] = true

            // 1. Собираем прямые 1-hop связи текущей заметки (входящие и исходящие)
            var bridgeHubIds = {}
            for (var k = 0; k < pureLinks.length; k++) {
                var lk = pureLinks[k]
                var srcId = (typeof lk.source === "object" && lk.source !== null) ? lk.source.id : lk.source
                var tgtId = (typeof lk.target === "object" && lk.target !== null) ? lk.target.id : lk.target
                if (srcId === targetId || tgtId === targetId) {
                    localConnectedIds[srcId] = true
                    localConnectedIds[tgtId] = true

                    // Запоминаем соседние узлы, которые являются Блоками или Тегами
                    var otherId = (srcId === targetId) ? tgtId : srcId
                    bridgeHubIds[otherId] = true
                }
            }

            // 2. Раскрываем все соединения блоков и тегов (показываем все файлы, подключенные к этим блокам/тегам)
            for (var h = 0; h < pureNodes.length; h++) {
                var candNode = pureNodes[h]
                if (bridgeHubIds[candNode.id] && (candNode.type === "block" || candNode.type === "tag")) {
                    for (var l = 0; l < pureLinks.length; l++) {
                        var hubLk = pureLinks[l]
                        var hSrc = (typeof hubLk.source === "object" && hubLk.source !== null) ? hubLk.source.id : hubLk.source
                        var hTgt = (typeof hubLk.target === "object" && hubLk.target !== null) ? hubLk.target.id : hubLk.target
                        if (hSrc === candNode.id || hTgt === candNode.id) {
                            localConnectedIds[hSrc] = true
                            localConnectedIds[hTgt] = true
                        }
                    }
                }
            }

            // 3. Формируем итоговые ребра и узлы локального подграфа
            var filteredLinks = []
            for (var m = 0; m < pureLinks.length; m++) {
                var lk2 = pureLinks[m]
                var srcId2 = (typeof lk2.source === "object" && lk2.source !== null) ? lk2.source.id : lk2.source
                var tgtId2 = (typeof lk2.target === "object" && lk2.target !== null) ? lk2.target.id : lk2.target
                if (localConnectedIds[srcId2] && localConnectedIds[tgtId2]) {
                    filteredLinks.push(lk2)
                }
            }

            pureNodes = pureNodes.filter(function(n) {
                return !!localConnectedIds[n.id]
            })
            pureLinks = filteredLinks
        }
    }

    var backendPositions = (backend && typeof backend.get_node_positions === "function")
        ? (backend.get_node_positions(graphRoot.folderUrl) || {})
        : {}

    // Сохраняем текущие живые физические координаты и скорости узлов, если симуляция уже запущена
    var liveNodeMap = {}
    if (graphRoot.sim && graphRoot.sim.nodes) {
        for (var l = 0; l < graphRoot.sim.nodes.length; l++) {
            var ln = graphRoot.sim.nodes[l]
            liveNodeMap[ln.id] = { x: ln.x, y: ln.y, vx: ln.vx, vy: ln.vy }
        }
    }

    var canW = (typeof forcedW === "number" && forcedW > 50) ? forcedW : ((canvas && canvas.width > 50) ? canvas.width : ((graphRoot && graphRoot.width > 50) ? graphRoot.width : 800))
    var canH = (typeof forcedH === "number" && forcedH > 50) ? forcedH : ((canvas && canvas.height > 50) ? canvas.height : ((graphRoot && graphRoot.height > 50) ? graphRoot.height : 600))
    var targetCX = canW / 2
    var targetCY = canH / 2

    var anyMissing = false
    if (graphRoot.isLocalGraph && localTargetNode) {
        // В локальном графе располагаем активную заметку строго по центру, а соседей — по кругу вокруг нее
        localTargetNode.x = targetCX
        localTargetNode.y = targetCY
        localTargetNode.isFixed = true
        var angleStep = (pureNodes.length > 1) ? (2 * Math.PI / (pureNodes.length - 1)) : 0
        var radius = Math.min(canW, canH) * 0.28
        var nIdx = 0
        for (var ni = 0; ni < pureNodes.length; ni++) {
            if (pureNodes[ni].id !== localTargetNode.id) {
                var angle = nIdx * angleStep
                pureNodes[ni].x = targetCX + radius * Math.cos(angle)
                pureNodes[ni].y = targetCY + radius * Math.sin(angle)
                nIdx++
            }
        }
        anyMissing = true
        graphRoot.panX = 0
        graphRoot.panY = 0
        graphRoot.zoomScale = 1.0
        graphRoot.activeNodeId = localTargetNode.id
    } else {
        for (var p = 0; p < pureNodes.length; p++) {
            var pn = pureNodes[p]
            if (liveNodeMap[pn.id] && typeof liveNodeMap[pn.id].x === "number" && !isNaN(liveNodeMap[pn.id].x)) {
                pn.x = liveNodeMap[pn.id].x
                pn.y = liveNodeMap[pn.id].y
                pn.vx = liveNodeMap[pn.id].vx || 0
                pn.vy = liveNodeMap[pn.id].vy || 0
            } else {
                var cached = (graphRoot.nodePositionsCache && graphRoot.nodePositionsCache[pn.id]) ||
                             globalNodePositionsCache[pn.id] ||
                             backendPositions[pn.id]
                if (cached && typeof cached.x === "number" && typeof cached.y === "number") {
                    pn.x = cached.x
                    pn.y = cached.y
                } else if (typeof pn.x === "number" && typeof pn.y === "number") {
                    // Узел уже имеет позицию от backend build_graph
                } else {
                    anyMissing = true
                }
            }
        }
    }

    var sim = Physics.initSimulation(pureNodes, pureLinks, canW, canH, config)
    graphRoot.sim = sim
    graphRoot.statsText = getGraphStats(sim, graphRoot.isLocalGraph)

    // 1. Полный расчет равновесия в памяти JS:
    var warmupTicks = anyMissing ? 400 : 0
    for (var tick = 0; tick < warmupTicks; tick++) {
        Physics.stepSimulation(sim)
        if (sim.isSleeping) break
    }

    // 2. Находим активный узел (последний открытый документ) в стабилизированном графе
    var normActive = normalizeUrl(graphRoot.activeFileUrl)
    var activeNode = null
    if (normActive) {
        for (var a = 0; a < sim.nodes.length; a++) {
            var sn = sim.nodes[a]
            if (sn.type === "file" && sn.fileUrl && 
                (sn.fileUrl === graphRoot.activeFileUrl || normalizeUrl(sn.fileUrl) === normActive)) {
                activeNode = sn
                graphRoot.activeNodeId = sn.id
                break
            }
        }
    }

    // 3. Сохраняем физические координаты узлов в кэш без искусственного смещения мира (только для глобального графа)
    if (!graphRoot.isLocalGraph) {
        for (var m2 = 0; m2 < sim.nodes.length; m2++) {
            sim.nodes[m2].vx = 0
            sim.nodes[m2].vy = 0
            var posObj = { x: sim.nodes[m2].x, y: sim.nodes[m2].y }
            globalNodePositionsCache[sim.nodes[m2].id] = posObj
            if (graphRoot.nodePositionsCache) {
                graphRoot.nodePositionsCache[sim.nodes[m2].id] = posObj
            }
        }
        if (backend && typeof backend.save_node_positions === "function") {
            backend.save_node_positions(graphRoot.folderUrl, globalNodePositionsCache)
        }
    }

    // 4. Центрируем КАМЕРУ (panX, panY)
    if (graphRoot.isLocalGraph) {
        graphRoot.panX = 0
        graphRoot.panY = 0
        graphRoot.zoomScale = 1.0
        graphRoot.lastCenteredUrl = graphRoot.activeFileUrl
    } else {
        var hadExistingSim = Object.keys(liveNodeMap).length > 0
        if (!hadExistingSim || (activeNode && graphRoot.lastCenteredUrl !== graphRoot.activeFileUrl)) {
            if (activeNode && typeof activeNode.x === "number" && !isNaN(activeNode.x)) {
                graphRoot.panX = -(activeNode.x - targetCX) * graphRoot.zoomScale
                graphRoot.panY = -(activeNode.y - targetCY) * graphRoot.zoomScale
                graphRoot.lastCenteredUrl = graphRoot.activeFileUrl
            } else if (sim.nodes.length > 0 && !hadExistingSim) {
                var sumX = 0, sumY = 0
                for (var c = 0; c < sim.nodes.length; c++) {
                    sumX += sim.nodes[c].x
                    sumY += sim.nodes[c].y
                }
                var avgX = sumX / sim.nodes.length
                var avgY = sumY / sim.nodes.length
                graphRoot.panX = -(avgX - targetCX) * graphRoot.zoomScale
                graphRoot.panY = -(avgY - targetCY) * graphRoot.zoomScale
            } else if (!hadExistingSim) {
                graphRoot.panX = 0
                graphRoot.panY = 0
            }
        }
    }

    // 5. Граф автоматически оживает при открытии: деликатное органическое дыхание связей
    wakeSimulation(graphRoot, canvas, animTimer)
}

function loadHistoricalGraph(graphRoot, canvas, graphData, Physics, animTimer) {
    if (!graphData || !graphData.nodes) return
    var pureNodes = []
    for (var i = 0; i < graphData.nodes.length; i++) {
        pureNodes.push(Object.assign({}, graphData.nodes[i]))
    }
    var pureLinks = []
    if (graphData.links) {
        for (var j = 0; j < graphData.links.length; j++) {
            pureLinks.push(Object.assign({}, graphData.links[j]))
        }
    }

    var config = graphRoot.graphConfig || {}
    var liveNodeMap = {}
    if (graphRoot.sim && graphRoot.sim.nodes) {
        for (var l = 0; l < graphRoot.sim.nodes.length; l++) {
            var ln = graphRoot.sim.nodes[l]
            liveNodeMap[ln.id] = { x: ln.x, y: ln.y, vx: ln.vx, vy: ln.vy }
        }
    }

    for (var p = 0; p < pureNodes.length; p++) {
        var pn = pureNodes[p]
        if (liveNodeMap[pn.id] && typeof liveNodeMap[pn.id].x === "number" && !isNaN(liveNodeMap[pn.id].x)) {
            pn.x = liveNodeMap[pn.id].x
            pn.y = liveNodeMap[pn.id].y
            pn.vx = liveNodeMap[pn.id].vx || 0
            pn.vy = liveNodeMap[pn.id].vy || 0
        } else {
            var cached = (graphRoot.nodePositionsCache && graphRoot.nodePositionsCache[pn.id]) || globalNodePositionsCache[pn.id]
            if (cached && typeof cached.x === "number" && typeof cached.y === "number") {
                pn.x = cached.x
                pn.y = cached.y
            }
        }
    }

    var canW = (canvas && canvas.width > 50) ? canvas.width : ((graphRoot && graphRoot.width > 50) ? graphRoot.width : 800)
    var canH = (canvas && canvas.height > 50) ? canvas.height : ((graphRoot && graphRoot.height > 50) ? graphRoot.height : 600)
    var sim = Physics.initSimulation(pureNodes, pureLinks, canW, canH, config)
    graphRoot.sim = sim

    wakeSimulation(graphRoot, canvas, animTimer)
    if (canvas) canvas.requestPaint()
}

function handleResize(graphRoot, canvas, newWidth, newHeight) {
    if (!graphRoot.sim || !graphRoot.sim.nodes || graphRoot.sim.nodes.length === 0) return
    var sim = graphRoot.sim
    var oldW = (typeof sim.width === "number" && sim.width > 50) ? sim.width : newWidth
    var oldH = (typeof sim.height === "number" && sim.height > 50) ? sim.height : newHeight

    var deltaW = newWidth - oldW
    var deltaH = newHeight - oldH

    sim.width = newWidth
    sim.height = newHeight
    sim.cx = newWidth / 2
    sim.cy = newHeight / 2

    // Корректируем смещение камеры (panX, panY), чтобы видимый центр обзора
    // оставался строго зафиксирован в геометрическом центре холста (newWidth / 2, newHeight / 2)
    // при любом сжатии или расширении листа / окна
    var zs = graphRoot.zoomScale || 1.0
    if (deltaW !== 0 && oldW > 50) {
        graphRoot.panX += (deltaW / 2) * zs
    }
    if (deltaH !== 0 && oldH > 50) {
        graphRoot.panY += (deltaH / 2) * zs
    }

    if (graphRoot.activeFileUrl && graphRoot.lastCenteredUrl !== graphRoot.activeFileUrl && newWidth > 50 && newHeight > 50) {
        centerOnNode(graphRoot, canvas, graphRoot.activeFileUrl)
    }

    if (canvas) canvas.requestPaint()
}

function wakeSimulation(graphRoot, canvas, animTimer, energyBoost) {
    if (graphRoot.sim && graphRoot.sim.nodes && graphRoot.sim.nodes.length > 0) {
        var boost = (typeof energyBoost === "number") ? energyBoost : 8
        graphRoot.sim.isSleeping = false
        graphRoot.sim.totalEnergy = boost
        for (var v = 0; v < graphRoot.sim.nodes.length; v++) {
            var n = graphRoot.sim.nodes[v]
            if (!n.isFixed) {
                n.vx = (n.vx || 0) * 0.3 + (Math.random() - 0.5) * 0.6
                n.vy = (n.vy || 0) * 0.3 + (Math.random() - 0.5) * 0.6
            }
        }
        if (animTimer) animTimer.running = true
        if (canvas) canvas.requestPaint()
    }
}

function resetView(graphRoot, canvas, animTimer) {
    graphRoot.zoomScale = 1.0
    if (graphRoot.activeFileUrl && centerOnNode(graphRoot, canvas, graphRoot.activeFileUrl)) {
        return
    }
    graphRoot.panX = 0
    graphRoot.panY = 0
    if (graphRoot.sim && graphRoot.sim.links) {
        for (var i = 0; i < graphRoot.sim.links.length; i++) {
            graphRoot.sim.links[i].distance = graphRoot.sim.links[i].baseDistance || 85
        }
    }
    wakeSimulation(graphRoot, canvas, animTimer)
}

function stepAnimation(graphRoot, canvas, animTimer, Physics, backend, dt) {
    if (!graphRoot.sim) {
        animTimer.running = false
        return
    }

    Physics.stepSimulation(graphRoot.sim, dt)
    canvas.requestPaint()

    // Непрерывно синхронизируем актуальные координаты узлов в оперативный кэш
    if (graphRoot.sim.nodes) {
        for (var i = 0; i < graphRoot.sim.nodes.length; i++) {
            var node = graphRoot.sim.nodes[i]
            var posObj = { x: node.x, y: node.y }
            globalNodePositionsCache[node.id] = posObj
            if (graphRoot.nodePositionsCache) {
                graphRoot.nodePositionsCache[node.id] = posObj
            }
        }
    }

    if (graphRoot.sim.isSleeping) {
        animTimer.running = false
        if (backend && typeof backend.save_node_positions === "function") {
            backend.save_node_positions(graphRoot.folderUrl, globalNodePositionsCache)
        }
    }
}

function handleMouseMove(graphRoot, canvas, animTimer, mouse, graphMouse, Renderer) {
    if (graphRoot.draggedNode) {
        var wx = Renderer.toWorldX(mouse.x, graphMouse.width, graphRoot.panX, graphRoot.zoomScale)
        var wy = Renderer.toWorldY(mouse.y, graphMouse.height, graphRoot.panY, graphRoot.zoomScale)
        graphRoot.draggedNode.x = wx + graphMouse.dragOffsetX
        graphRoot.draggedNode.y = wy + graphMouse.dragOffsetY
        graphRoot.draggedNode.vx = 0
        graphRoot.draggedNode.vy = 0
        if (graphRoot.sim) {
            graphRoot.sim.isSleeping = false
            graphRoot.sim.totalEnergy = 15
        }
        animTimer.running = true
        canvas.requestPaint()
        graphMouse.cursorShape = Qt.ClosedHandCursor
        return
    }

    if (graphMouse.isPanning) {
        graphRoot.panX += (mouse.x - graphMouse.lastMouseX)
        graphRoot.panY += (mouse.y - graphMouse.lastMouseY)
        graphMouse.lastMouseX = mouse.x
        graphMouse.lastMouseY = mouse.y
        canvas.requestPaint()
        graphMouse.cursorShape = Qt.ClosedHandCursor
        return
    }

    var node = Renderer.findNodeAtScreen(graphRoot.sim, mouse.x, mouse.y, graphMouse.width, graphMouse.height, graphRoot.zoomScale, graphRoot.panX, graphRoot.panY)

    if (node !== graphRoot.hoveredNode) {
        graphRoot.hoveredNode = node
        var map = {}
        if (node && graphRoot.sim && graphRoot.sim.links) {
            map[node.id] = true
            for (var i = 0; i < graphRoot.sim.links.length; i++) {
                var l = graphRoot.sim.links[i]
                if (l.source.id === node.id) map[l.target.id] = true
                if (l.target.id === node.id) map[l.source.id] = true
            }
        }
        graphRoot.highlightedNodeIds = map
        canvas.requestPaint()
    }

    graphMouse.cursorShape = (node ? Qt.OpenHandCursor : Qt.ArrowCursor)
}

function handleMouseDown(graphRoot, animTimer, mouse, graphMouse, Renderer) {
    graphRoot.forceActiveFocus()
    graphMouse.lastMouseX = mouse.x
    graphMouse.lastMouseY = mouse.y
    graphMouse.dragStartX = mouse.x
    graphMouse.dragStartY = mouse.y

    var node = Renderer.findNodeAtScreen(graphRoot.sim, mouse.x, mouse.y, graphMouse.width, graphMouse.height, graphRoot.zoomScale, graphRoot.panX, graphRoot.panY)

    if (node && mouse.button === Qt.LeftButton) {
        graphRoot.draggedNode = node
        node.isFixed = true
        node.isDragging = true
        graphMouse.isPanning = false
        var wx = Renderer.toWorldX(mouse.x, graphMouse.width, graphRoot.panX, graphRoot.zoomScale)
        var wy = Renderer.toWorldY(mouse.y, graphMouse.height, graphRoot.panY, graphRoot.zoomScale)
        graphMouse.dragOffsetX = node.x - wx
        graphMouse.dragOffsetY = node.y - wy
        graphMouse.cursorShape = Qt.ClosedHandCursor
    } else {
        graphRoot.draggedNode = null
        graphMouse.isPanning = true
        graphMouse.cursorShape = Qt.ClosedHandCursor
    }
}

function handleMouseUp(graphRoot, canvas, animTimer, mouse, graphMouse, backend) {
    var movedDist = Math.hypot(mouse.x - graphMouse.dragStartX, mouse.y - graphMouse.dragStartY)
    var wasDraggingNode = (graphRoot.draggedNode !== null)
    var nodeRef = graphRoot.draggedNode

    if (wasDraggingNode) {
        nodeRef.isFixed = false
        nodeRef.isDragging = false
        var posObj = { x: nodeRef.x, y: nodeRef.y }
        globalNodePositionsCache[nodeRef.id] = posObj
        if (graphRoot.nodePositionsCache) {
            graphRoot.nodePositionsCache[nodeRef.id] = posObj
        }
        graphRoot.draggedNode = null
        if (movedDist >= 6 && graphRoot.sim) {
            graphRoot.sim.isSleeping = false
            graphRoot.sim.totalEnergy = 15
            animTimer.running = true
        } else if (graphRoot.sim) {
            graphRoot.sim.isSleeping = true
            graphRoot.sim.totalEnergy = 0
            animTimer.running = false
            if (backend && typeof backend.save_node_positions === "function") {
                backend.save_node_positions(graphRoot.folderUrl, globalNodePositionsCache)
            }
        }
        canvas.requestPaint()
    }

    if (graphMouse.isPanning) {
        graphMouse.isPanning = false
        canvas.requestPaint()
    }

    graphMouse.cursorShape = (graphRoot.hoveredNode ? Qt.OpenHandCursor : Qt.ArrowCursor)

    if (movedDist < 10 && mouse.button === Qt.LeftButton) {
        var clickedNode = graphRoot.hoveredNode || nodeRef
        if (clickedNode) {
            if (clickedNode.type === "file" && clickedNode.fileUrl) {
                graphRoot.nodeClicked(clickedNode.fileUrl, clickedNode.label, "file")
            } else if (clickedNode.type === "block" && clickedNode.sourceFileUrl) {
                graphRoot.nodeClicked(clickedNode.sourceFileUrl, clickedNode.label, "block")
            }
        }
    }
}

function handleWheel(graphRoot, canvas, event) {
    if (!event) return
    var factor = event.angleDelta.y > 0 ? 1.15 : 0.87
    var px = (event.point && event.point.position) ? event.point.position.x : (event.x !== undefined ? event.x : graphRoot.width / 2)
    var py = (event.point && event.point.position) ? event.point.position.y : (event.y !== undefined ? event.y : graphRoot.height / 2)
    zoomAt(graphRoot, canvas, px, py, factor)
    event.accepted = true
}

function handleKey(graphRoot, event) {
    if (!event) return false
    if (event.key === Qt.Key_Escape) {
        graphRoot.closeRequested()
        event.accepted = true
        return true
    }
    if (event.modifiers & Qt.ControlModifier) {
        // Поддержка Ctrl+G (EN) и обоих русских вариантов: Ctrl+П (физическая клавиша G) и Ctrl+Г (буква Г для графа, клавиша U)
        var isG = (event.key === Qt.Key_G || event.nativeScanCode === 34 || 
                   event.text === 'g' || event.text === 'G' || 
                   event.text === 'п' || event.text === 'П' || 
                   event.key === 1087 || event.key === 1055)
        var isRuGe = (event.key === Qt.Key_U || event.nativeScanCode === 22 || 
                      event.text === 'г' || event.text === 'Г' || 
                      event.key === 1075 || event.key === 1043)
        // Поддержка Ctrl+W (EN: W / RU: Ц, scan 17) и Ctrl+Q (EN: Q / RU: Й, scan 16) для закрытия графа
        var isW = (event.key === Qt.Key_W || event.nativeScanCode === 17 ||
                   event.key === 1062 || event.key === 1094 ||
                   event.text === 'w' || event.text === 'W' || event.text === 'ц' || event.text === 'Ц')
        var isQ = (event.key === Qt.Key_Q || event.nativeScanCode === 16 ||
                   event.key === 1049 || event.key === 1081 ||
                   event.text === 'q' || event.text === 'Q' || event.text === 'й' || event.text === 'Й')
        if (isG || isRuGe || isW || isQ) {
            graphRoot.closeRequested()
            event.accepted = true
            return true
        }
    }

    if (event.modifiers & Qt.AltModifier) {
        // Alt+I — переключение информации/статистики (EN: I / RU: Ш, scan 23)
        var isI = (event.key === Qt.Key_I || event.nativeScanCode === 23 ||
                   event.key === 1096 || event.key === 1064 ||
                   event.text === 'i' || event.text === 'I' || event.text === 'ш' || event.text === 'Ш')
        if (isI) {
            graphRoot.toggleInfoRequested()
            event.accepted = true
            return true
        }
    }

    // Горячие клавиши переключения слоев графа (строго без модификаторов Alt/Ctrl, чтобы не конфликтовать с Alt+T — toggle tabs):
    if (!event.modifiers) {
        // B — Blocks / Именованные блоки (русская 'и'/'И', scan 48)
        var isKeyB = (event.key === Qt.Key_B || event.nativeScanCode === 48 ||
                      event.text === 'b' || event.text === 'B' ||
                      event.text === 'и' || event.text === 'И' ||
                      event.key === 1080 || event.key === 1048)
        if (isKeyB) {
            graphRoot.showBlocks = !graphRoot.showBlocks
            event.accepted = true
            return true
        }

        // T — Tags / Теги (русская 'е'/'Е', scan 20)
        var isKeyT = (event.key === Qt.Key_T || event.nativeScanCode === 20 ||
                      event.text === 't' || event.text === 'T' ||
                      event.text === 'е' || event.text === 'Е' ||
                      event.key === 1077 || event.key === 1045)
        if (isKeyT) {
            graphRoot.showTags = !graphRoot.showTags
            event.accepted = true
            return true
        }
    }

    return false
}

function handleSearch(graphRoot, canvas, text) {
    graphRoot.searchQuery = (text || "").trim().toLowerCase()
    if (canvas) canvas.requestPaint()
}

