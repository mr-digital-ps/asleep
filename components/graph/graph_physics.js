// graph_physics.js — Высокопроизводительный 2D Force-Directed физический движок

function initSimulation(nodes, links, width, height, options) {
    options = options || {}
    var physics = options.physics || options
    var visual = options.visual || options

    var repulsion = (typeof physics.repulsion === "number") ? physics.repulsion : 3600
    var repulsionDistanceMax = (typeof physics.repulsionDistanceMax === "number") ? physics.repulsionDistanceMax : 800
    var linkDistance = (typeof physics.linkDistance === "number") ? physics.linkDistance : 85
    var linkStrength = (typeof physics.linkStrength === "number") ? physics.linkStrength : 0.014
    var plasticDeformation = (typeof physics.plasticDeformation === "number") ? physics.plasticDeformation : 0.035
    var plasticMaxDistance = (typeof physics.plasticMaxDistance === "number") ? physics.plasticMaxDistance : 300
    var plasticRecoveryRate = (typeof physics.plasticRecoveryRate === "number") ? physics.plasticRecoveryRate : 0.0005
    var gravity = (typeof physics.gravity === "number") ? physics.gravity : 0.0005
    var damping = (typeof physics.damping === "number") ? physics.damping : 0.82
    var maxVelocity = (typeof physics.maxVelocity === "number") ? physics.maxVelocity : 15.0
    var initialSpread = (typeof physics.initialSpread === "number") ? physics.initialSpread : 0.35

    var nodeRadiusMin = (typeof visual.nodeRadiusMin === "number") ? visual.nodeRadiusMin : 3.5
    var nodeRadiusMax = (typeof visual.nodeRadiusMax === "number") ? visual.nodeRadiusMax : 8.5
    var nodeRadiusBase = (typeof visual.nodeRadiusBase === "number") ? visual.nodeRadiusBase : 3.2
    var nodeRadiusWeight = (typeof visual.nodeRadiusWeight === "number") ? visual.nodeRadiusWeight : 1.3

    var cx = width / 2
    var cy = height / 2

    var nodeMap = {}
    var phi = 2.399963229728653 // Золотой угол для равномерного распределения семян Фибоначчи
    var distStep = Math.max(50, (linkDistance || 85) * 0.7)
    for (var i = 0; i < nodes.length; i++) {
        var n = nodes[i]
        if (typeof n.x === "undefined" || isNaN(n.x)) {
            // Равномерная спираль: узлы сразу начинают на естественном удалении друг от друга
            var r = Math.sqrt(i + 1) * distStep
            var theta = i * phi
            n.x = cx + Math.cos(theta) * r
            n.y = cy + Math.sin(theta) * r
        }
        n.vx = n.vx || 0
        n.vy = n.vy || 0
        // Аккуратный настраиваемый размер узлов
        n.radius = Math.max(nodeRadiusMin, Math.min(nodeRadiusMax, nodeRadiusBase + Math.sqrt(n.val || 1) * nodeRadiusWeight))
        nodeMap[n.id] = n
    }

    var resolvedLinks = []
    for (var j = 0; j < links.length; j++) {
        var l = links[j]
        var s = (typeof l.source === "object") ? l.source : nodeMap[l.source]
        var t = (typeof l.target === "object") ? l.target : nodeMap[l.target]
        if (s && t) {
            resolvedLinks.push({
                source: s,
                target: t,
                type: l.type || "link",
                distance: linkDistance,
                baseDistance: linkDistance
            })
        }
    }

    return {
        nodes: nodes,
        links: resolvedLinks,
        nodeMap: nodeMap,
        width: width,
        height: height,
        cx: cx,
        cy: cy,
        repulsion: repulsion,
        repulsionDistanceMax: repulsionDistanceMax,
        linkDistance: linkDistance,
        linkStrength: linkStrength,
        plasticDeformation: plasticDeformation,
        plasticMaxDistance: plasticMaxDistance,
        plasticRecoveryRate: plasticRecoveryRate,
        gravity: gravity,
        damping: damping,
        maxVelocity: maxVelocity,
        initialSpread: initialSpread,
        visual: visual,
        isSleeping: false,
        totalEnergy: 100
    }
}

function stepSimulation(sim, dt) {
    if (!sim || sim.isSleeping || !sim.nodes || sim.nodes.length === 0) {
        return false
    }

    var timeScale = (typeof dt === "number" && dt > 0 && !isNaN(dt)) ? Math.min(2.0, dt) : 1.0
    var nodes = sim.nodes
    var links = sim.links
    var cx = (typeof sim.cx === "number") ? sim.cx : sim.width / 2
    var cy = (typeof sim.cy === "number") ? sim.cy : sim.height / 2
    var repulsion = sim.repulsion
    var linkDistance = sim.linkDistance
    var linkStrength = sim.linkStrength
    var gravity = sim.gravity
    var damping = sim.damping
    var effectiveDamping = (timeScale === 1.0) ? damping : Math.pow(damping, timeScale)

    var nLen = nodes.length

    var repulsionDistMax = sim.repulsionDistanceMax || 800
    var plasticDef = (typeof sim.plasticDeformation === "number") ? sim.plasticDeformation : 0.035
    var plasticMax = (typeof sim.plasticMaxDistance === "number") ? sim.plasticMaxDistance : 300
    var recoveryRate = (typeof sim.plasticRecoveryRate === "number") ? sim.plasticRecoveryRate : 0.0005
    var maxV = sim.maxVelocity || 15.0
    var maxVSq = maxV * maxV

    var maxDistSq = repulsionDistMax * repulsionDistMax

    // 1. Отталкивание (Repulsion) всех пар узлов
    for (var i = 0; i < nLen; i++) {
        var n1 = nodes[i]
        for (var j = i + 1; j < nLen; j++) {
            var n2 = nodes[j]
            var dx = n2.x - n1.x
            var dy = n2.y - n1.y
            var distSq = dx * dx + dy * dy + 0.1

            if (distSq < maxDistSq) {
                var dist = Math.sqrt(distSq)
                var force = repulsion / distSq
                var fx = (dx / dist) * force
                var fy = (dy / dist) * force

                // Мягкое предотвращение наложений (Collision avoidance)
                var minDist = (n1.radius || 5) + (n2.radius || 5) + 10
                if (dist < minDist && dist > 0.01) {
                    var colPush = (minDist - dist) * 0.15
                    fx += (dx / dist) * colPush
                    fy += (dy / dist) * colPush
                }

                if (!n1.isFixed) {
                    n1.vx -= fx * timeScale
                    n1.vy -= fy * timeScale
                }
                if (!n2.isFixed) {
                    n2.vx += fx * timeScale
                    n2.vy += fy * timeScale
                }
            }
        }
    }

    // 2. Сила притяжения связей (Высокоэластичные резиновые связи с остаточной деформацией)
    for (var k = 0; k < links.length; k++) {
        var link = links[k]
        var s = link.source
        var t = link.target

        var ldx = t.x - s.x
        var ldy = t.y - s.y
        var ldist = Math.sqrt(ldx * ldx + ldy * ldy) + 0.01

        var targetDist = link.distance || linkDistance
        var disp = ldist - targetDist

        // Пластическая деформация: когда узел активно оттягивают, ребро пластически вытягивается
        if (disp > 0 && (s.isDragging || t.isDragging)) {
            link.distance = Math.min(plasticMax, targetDist + disp * plasticDef)
        } else if (link.distance > (link.baseDistance || linkDistance)) {
            // Медленная релаксация остаточной деформации (память формы)
            link.distance = link.distance * (1.0 - recoveryRate) + (link.baseDistance || linkDistance) * recoveryRate
        }

        // Мягкая сила эластичной резинки: не тянет за собой весь остальной проект
        var lforce = disp * linkStrength
        var lfx = (ldx / ldist) * lforce
        var lfy = (ldy / ldist) * lforce

        if (!s.isFixed) {
            s.vx += lfx * timeScale
            s.vy += lfy * timeScale
        }
        if (!t.isFixed) {
            t.vx -= lfx * timeScale
            t.vy -= lfy * timeScale
        }
    }

    // 3. Сбалансированная гравитация к центру масс графа и затухание скорости
    var sumX = 0, sumY = 0
    for (var c = 0; c < nLen; c++) {
        sumX += nodes[c].x
        sumY += nodes[c].y
    }
    var comX = nLen > 0 ? (sumX / nLen) : cx
    var comY = nLen > 0 ? (sumY / nLen) : cy

    var energy = 0
    for (var m = 0; m < nLen; m++) {
        var n = nodes[m]

        if (!n.isFixed) {
            // Гравитация относительно центра масс: сумма сил равна строго 0 (нет дрейфа графа)
            var gdx = comX - n.x
            var gdy = comY - n.y
            n.vx += gdx * gravity * timeScale
            n.vy += gdy * gravity * timeScale

            n.vx *= effectiveDamping
            n.vy *= effectiveDamping

            // Ограничение максимальной скорости без избыточного Math.sqrt
            var spdSq = n.vx * n.vx + n.vy * n.vy
            if (spdSq > maxVSq) {
                var speed = Math.sqrt(spdSq)
                var invSpd = maxV / speed
                n.vx *= invSpd
                n.vy *= invSpd
                spdSq = maxVSq
            }

            n.x += n.vx * timeScale
            n.y += n.vy * timeScale

            energy += spdSq
        }
    }

    sim.totalEnergy = energy
    if (energy < 0.05) {
        sim.isSleeping = true
    }

    return true
}
