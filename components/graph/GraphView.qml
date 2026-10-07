import QtQuick
import "./graph_physics.js" as Physics
import "./graph_renderer.js" as Renderer
import "./graph_interaction.js" as Interaction
import "../theme"

Rectangle {
    id: graphRoot
    color: embeddedInSheet ? "transparent" : ((graphConfig && graphConfig.visual && graphConfig.visual.backgroundColor && graphConfig.visual.backgroundColor !== Theme.bgApp) ? graphConfig.visual.backgroundColor : Theme.bgPaper)
    clip: true

    property string folderUrl: ""
    property string activeFileUrl: ""
    property string activeNodeId: ""
    property bool embeddedInSheet: false
    property bool isLocalGraph: false
    property bool _lastIsLocalGraph: false
    property bool showBlocks: true
    property bool showTags: true
    property bool showLinks: true
    property bool showBlockEdges: true
    property bool showTagEdges: true
    property bool showLinkEdges: true
    property bool _layersInitialized: false
    property var historicalData: null
    property var sim: null
    property real zoomScale: 1.0
    property real panX: 0
    property real panY: 0
    property string searchQuery: ""
    property string statsText: ""

    onShowBlocksChanged: {
        if (historicalData) {
            Interaction.loadHistoricalGraph(graphRoot, canvas, historicalData, Physics, animTimer)
        } else {
            reloadGraph()
        }
    }
    onShowTagsChanged: {
        if (historicalData) {
            Interaction.loadHistoricalGraph(graphRoot, canvas, historicalData, Physics, animTimer)
        } else {
            reloadGraph()
        }
    }
    onShowLinksChanged: {
        if (historicalData) {
            Interaction.loadHistoricalGraph(graphRoot, canvas, historicalData, Physics, animTimer)
        } else {
            reloadGraph()
        }
    }
    onShowBlockEdgesChanged: {
        if (canvas) canvas.requestPaint()
    }
    onShowTagEdgesChanged: {
        if (canvas) canvas.requestPaint()
    }
    onShowLinkEdgesChanged: {
        if (canvas) canvas.requestPaint()
    }

    property var graphConfig: ({})
    onGraphConfigChanged: {
        if (!_layersInitialized && graphConfig && graphConfig.visual) {
            if (typeof graphConfig.visual.showBlocks === "boolean") showBlocks = graphConfig.visual.showBlocks
            if (typeof graphConfig.visual.showTags === "boolean") showTags = graphConfig.visual.showTags
            if (typeof graphConfig.visual.showLinks === "boolean") showLinks = graphConfig.visual.showLinks
            if (typeof graphConfig.visual.showBlockEdges === "boolean") showBlockEdges = graphConfig.visual.showBlockEdges
            if (typeof graphConfig.visual.showTagEdges === "boolean") showTagEdges = graphConfig.visual.showTagEdges
            if (typeof graphConfig.visual.showLinkEdges === "boolean") showLinkEdges = graphConfig.visual.showLinkEdges
            _layersInitialized = true
        }
    }
    property var hoveredNode: null
    property var draggedNode: null
    property var highlightedNodeIds: ({})
    property var nodePositionsCache: ({})
    property alias canvas: canvas

    signal nodeClicked(string fileUrl, string label, string nodeType)
    signal closeRequested()
    signal graphPressed()
    signal toggleInfoRequested()

    focus: true
    Keys.onPressed: (event) => Interaction.handleKey(graphRoot, event)

    function reloadGraph() {
        historicalData = null
        Interaction.reloadGraph(graphRoot, canvas, (typeof backend !== "undefined" ? backend : null), Physics, animTimer)
    }

    function reloadGraphWithDimensions(w, h) {
        historicalData = null
        Interaction.reloadGraph(graphRoot, canvas, (typeof backend !== "undefined" ? backend : null), Physics, animTimer, w, h)
    }

    function loadHistoricalGraph(graphData) {
        historicalData = graphData
        Interaction.loadHistoricalGraph(graphRoot, canvas, graphData, Physics, animTimer)
    }

    function wakeSimulation() {
        Interaction.wakeSimulation(graphRoot, canvas, animTimer)
    }

    function resetView() {
        Interaction.resetView(graphRoot, canvas, animTimer)
    }

    function centerOnNode(targetFileUrl) {
        return Interaction.centerOnNode(graphRoot, canvas, targetFileUrl)
    }

    function zoomAt(sx, sy, zoomFactor) {
        Interaction.zoomAt(graphRoot, canvas, sx, sy, zoomFactor)
    }

    function getGraphStats() {
        return Interaction.getGraphStats(sim, graphRoot.isLocalGraph)
    }

    property string lastCenteredUrl: ""

    property var openFileUrls: []
    onOpenFileUrlsChanged: if (canvas) canvas.requestPaint()

    Component.onCompleted: reloadGraph()

    onVisibleChanged: {
        if (visible) {
            if (!sim || !sim.nodes || sim.nodes.length === 0) {
                reloadGraph()
            }
            if (activeFileUrl) {
                if (!centerOnNode(activeFileUrl)) {
                    Qt.callLater(() => {
                        if (graphRoot && graphRoot.visible && graphRoot.activeFileUrl) {
                            graphRoot.centerOnNode(graphRoot.activeFileUrl)
                        }
                    })
                }
            }
            wakeSimulation()
        }
    }

    onIsLocalGraphChanged: {
        reloadGraph()
    }

    onActiveFileUrlChanged: {
        if (isLocalGraph) {
            reloadGraph()
        } else if (activeFileUrl && activeFileUrl !== lastCenteredUrl) {
            if (!centerOnNode(activeFileUrl)) {
                Qt.callLater(() => {
                    if (graphRoot && graphRoot.visible && graphRoot.activeFileUrl) {
                        graphRoot.centerOnNode(graphRoot.activeFileUrl)
                    }
                })
            }
        }
    }

    onFolderUrlChanged: {
        if (folderUrl) {
            reloadGraph()
        }
    }

    Connections {
        target: (typeof backend !== "undefined") ? backend : null
        function onGraphDataChanged() { graphRoot.reloadGraph() }
        function onFolderFilesChanged() {
            if (!graphRoot.sim || !graphRoot.sim.nodes || graphRoot.sim.nodes.length === 0) {
                graphRoot.reloadGraph()
            }
        }
    }

    onWidthChanged: {
        Interaction.handleResize(graphRoot, canvas, width, height)
    }
    onHeightChanged: {
        Interaction.handleResize(graphRoot, canvas, width, height)
    }

    // Целевая частота кадров физики графа
    property int targetFps: (typeof backend !== "undefined" && backend && typeof backend.get_target_fps === "function") ? backend.get_target_fps() : 60
    readonly property int animIntervalMs: targetFps <= 0 ? 1 : Math.max(1, Math.round(1000 / targetFps))

    Connections {
        target: (typeof backend !== "undefined") ? backend : null
        ignoreUnknownSignals: true
        function onAppConfigChanged() {
            if (backend && typeof backend.get_target_fps === "function") {
                graphRoot.targetFps = backend.get_target_fps()
            }
        }
    }

    Timer {
        id: animTimer
        interval: graphRoot.animIntervalMs
        repeat: true
        running: false
        onTriggered: Interaction.stepAnimation(graphRoot, canvas, animTimer, Physics, (typeof backend !== "undefined" ? backend : null), (graphRoot.animIntervalMs / 16.666))
    }


    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            Renderer.renderGraph(ctx, width, height, graphRoot.sim, {
                panX: graphRoot.panX,
                panY: graphRoot.panY,
                zoomScale: graphRoot.zoomScale,
                hoveredNode: graphRoot.hoveredNode,
                draggedNode: graphRoot.draggedNode,
                highlightedNodeIds: graphRoot.highlightedNodeIds,
                activeNodeId: graphRoot.activeNodeId,
                activeFileUrl: graphRoot.activeFileUrl,
                openFileUrls: graphRoot.openFileUrls,
                searchQuery: graphRoot.searchQuery,
                showBlockEdges: graphRoot.showBlockEdges,
                showTagEdges: graphRoot.showTagEdges,
                showLinkEdges: graphRoot.showLinkEdges,
                graphConfig: graphRoot.graphConfig,
                theme: {
                    bgApp: Theme.bgApp,
                    textPrimary: Theme.textPrimary,
                    textSecondary: Theme.textSecondary,
                    textMuted: Theme.textMuted,
                    borderColor: Theme.borderColor,
                    borderHover: Theme.borderHover,
                    bgActive: Theme.bgActive,
                    bgHover: Theme.bgHover,
                    accentColor: Theme.accentColor
                }
            })
        }
    }

    Connections {
        target: Theme
        function onBgAppChanged() { canvas.requestPaint() }
        function onTextPrimaryChanged() { canvas.requestPaint() }
        function onBorderColorChanged() { canvas.requestPaint() }
    }

    MouseArea {
        id: graphMouse
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property real lastMouseX: 0
        property real lastMouseY: 0
        property bool isPanning: false
        property real dragStartX: 0
        property real dragStartY: 0
        property real dragOffsetX: 0
        property real dragOffsetY: 0

        onWheel: (wheel) => Interaction.handleWheel(graphRoot, canvas, wheel)
        onPositionChanged: (mouse) => Interaction.handleMouseMove(graphRoot, canvas, animTimer, mouse, graphMouse, Renderer)
        onPressed: (mouse) => {
            graphRoot.forceActiveFocus()
            graphRoot.graphPressed()
            Interaction.handleMouseDown(graphRoot, animTimer, mouse, graphMouse, Renderer)
        }
        onReleased: (mouse) => Interaction.handleMouseUp(graphRoot, canvas, animTimer, mouse, graphMouse, (typeof backend !== "undefined" ? backend : null))
    }

    WheelHandler {
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => Interaction.handleWheel(graphRoot, canvas, event)
    }

    // Подсказка при отсутствии связей в локальном графе
    Rectangle {
        visible: Boolean(graphRoot.isLocalGraph && graphRoot.sim && graphRoot.sim.nodes && graphRoot.sim.nodes.length <= 1 && (!graphRoot.sim.links || graphRoot.sim.links.length === 0))
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        anchors.horizontalCenter: parent.horizontalCenter
        height: 32
        width: localHintText.implicitWidth + 24
        radius: 16
        color: Theme.bgPaper
        border.color: Theme.borderColor
        border.width: 1
        opacity: 0.85
        z: 20

        Text {
            id: localHintText
            anchors.centerIn: parent
            text: "Нет связей с другими заметками. Добавьте [[ссылку]] или тег #тег"
            font.pixelSize: 11
            color: Theme.textMuted
        }
    }

}
