// js/graph/graph_interaction.js — Интерактивное управление графом связей (Zoom, Pan, Drag, Hit Test, Hover, Pre-warming)

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
    for (var i = 0; i < graphRoot.sim.nodes.length; i++) {
        var n = graphRoot.sim.nodes[i]
        if (n.id === graphRoot.activeNodeId) {
            graphRoot.panX = -(n.x - graphRoot.width / 2) * graphRoot.zoomScale
            graphRoot.panY = -(n.y - graphRoot.height / 2) * graphRoot.zoomScale
            break
        }
    }
}

function centerOnNode(graphRoot, canvas, targetFileUrl) {
    if (!graphRoot.sim || !graphRoot.sim.nodes || graphRoot.sim.nodes.length === 0) return false
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
        graphRoot.panX = -(found.x - graphRoot.width / 2) * graphRoot.zoomScale
        graphRoot.panY = -(found.y - graphRoot.height / 2) * graphRoot.zoomScale
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

function getGraphStats(sim) {
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
    return parts.join(" · ")
}

function reloadGraph(graphRoot, canvas, backend, Physics, animTimer) {
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

    if (graphRoot.nodePositionsCache) {
        for (var p = 0; p < pureNodes.length; p++) {
            var pn = pureNodes[p]
            if (graphRoot.nodePositionsCache[pn.id]) {
                pn.x = graphRoot.nodePositionsCache[pn.id].x
                pn.y = graphRoot.nodePositionsCache[pn.id].y
            }
        }
    }

    var sim = Physics.initSimulation(pureNodes, pureLinks, (canvas && canvas.width) || 800, (canvas && canvas.height) || 600, config)
    graphRoot.sim = sim

    // Мягкий прогрев симуляции, оставляющий энергию для живого движения
    for (var tick = 0; tick < 60; tick++) {
        Physics.stepSimulation(sim)
        if (sim.isSleeping) break
    }
    sim.isSleeping = false
    sim.totalEnergy = 25
    if (animTimer) {
        animTimer.running = true
    }

    for (var s = 0; s < pureNodes.length; s++) {
        graphRoot.nodePositionsCache[pureNodes[s].id] = { x: pureNodes[s].x, y: pureNodes[s].y }
    }

    if (graphRoot.activeFileUrl) {
        centerOnNode(graphRoot, canvas, graphRoot.activeFileUrl)
    }
    if (canvas) canvas.requestPaint()
}

function wakeSimulation(graphRoot, canvas, animTimer) {
    if (graphRoot.sim) {
        graphRoot.sim.isSleeping = false
        graphRoot.sim.totalEnergy = 25
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

function stepAnimation(graphRoot, canvas, animTimer, Physics) {
    if (!graphRoot.sim) {
        animTimer.running = false
        return
    }
    Physics.stepSimulation(graphRoot.sim)
    canvas.requestPaint()
    if (graphRoot.sim.isSleeping) {
        animTimer.running = false
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
        wakeSimulation(graphRoot, null, animTimer)
    } else {
        graphRoot.draggedNode = null
        graphMouse.isPanning = true
        graphMouse.cursorShape = Qt.ClosedHandCursor
    }
}

function handleMouseUp(graphRoot, canvas, animTimer, mouse, graphMouse) {
    var movedDist = Math.hypot(mouse.x - graphMouse.dragStartX, mouse.y - graphMouse.dragStartY)
    var wasDraggingNode = (graphRoot.draggedNode !== null)
    var nodeRef = graphRoot.draggedNode

    if (wasDraggingNode) {
        nodeRef.isFixed = false
        nodeRef.isDragging = false
        if (graphRoot.nodePositionsCache) {
            graphRoot.nodePositionsCache[nodeRef.id] = { x: nodeRef.x, y: nodeRef.y }
        }
        graphRoot.draggedNode = null
        if (graphRoot.sim) {
            graphRoot.sim.isSleeping = false
            graphRoot.sim.totalEnergy = 35
        }
        animTimer.running = true
        canvas.requestPaint()
    }

    if (graphMouse.isPanning) {
        graphMouse.isPanning = false
        canvas.requestPaint()
    }

    graphMouse.cursorShape = (graphRoot.hoveredNode ? Qt.OpenHandCursor : Qt.ArrowCursor)

    if (movedDist < 6 && mouse.button === Qt.LeftButton) {
        if (graphRoot.hoveredNode) {
            var hNode = graphRoot.hoveredNode
            if (hNode.type === "file" && hNode.fileUrl) {
                graphRoot.nodeClicked(hNode.fileUrl, hNode.label, "file")
            } else if (hNode.type === "block" && hNode.sourceFileUrl) {
                graphRoot.nodeClicked(hNode.sourceFileUrl, hNode.label, "block")
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
        if (event.key === Qt.Key_G || event.nativeScanCode === 34 || event.text === 'g' || event.text === 'G' || event.text === 'п' || event.text === 'П' || event.key === 1087 || event.key === 1055) {
            graphRoot.closeRequested()
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

