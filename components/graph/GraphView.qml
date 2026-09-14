import QtQuick
import QtQuick.Controls
import "../../js/graph/graph_physics.js" as Physics
import "../../js/graph/graph_renderer.js" as Renderer
import "../../js/graph/graph_interaction.js" as Interaction
import "../theme"

Rectangle {
    id: graphRoot
    anchors.fill: parent
    color: embeddedInSheet ? "transparent" : ((graphConfig && graphConfig.visual && graphConfig.visual.backgroundColor && graphConfig.visual.backgroundColor !== Theme.bgApp) ? graphConfig.visual.backgroundColor : Theme.bgPaper)
    clip: true

    property string folderUrl: ""
    property string activeFileUrl: ""
    property string activeNodeId: ""
    property bool embeddedInSheet: false
    property var sim: null
    property real zoomScale: 1.0
    property real panX: 0
    property real panY: 0
    property string searchQuery: ""

    property var graphConfig: ({})
    property var hoveredNode: null
    property var draggedNode: null
    property var highlightedNodeIds: ({})
    property var nodePositionsCache: ({})
    property alias canvas: canvas

    signal nodeClicked(string fileUrl, string label, string nodeType)
    signal closeRequested()

    focus: true
    Keys.onPressed: (event) => Interaction.handleKey(graphRoot, event)



    function reloadGraph() {
        Interaction.reloadGraph(graphRoot, canvas, (typeof backend !== "undefined" ? backend : null), Physics, animTimer)
    }

    function reloadGraphWithDimensions(w, h) {
        Interaction.reloadGraph(graphRoot, canvas, (typeof backend !== "undefined" ? backend : null), Physics, animTimer, w, h)
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
        return Interaction.getGraphStats(sim)
    }

    Component.onCompleted: reloadGraph()

    onVisibleChanged: {
        if (visible) {
            if (!sim || !sim.nodes || sim.nodes.length === 0) {
                reloadGraph()
            } else {
                if (activeFileUrl) centerOnNode(activeFileUrl)
                wakeSimulation()
            }
        }
    }

    onActiveFileUrlChanged: {
        if (activeFileUrl) centerOnNode(activeFileUrl)
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
            if (graphRoot.visible || !graphRoot.sim) {
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

    Timer {
        id: animTimer
        interval: 16
        repeat: true
        running: false
        onTriggered: Interaction.stepAnimation(graphRoot, canvas, animTimer, Physics, (typeof backend !== "undefined" ? backend : null))
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
                searchQuery: graphRoot.searchQuery,
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
            Interaction.handleMouseDown(graphRoot, animTimer, mouse, graphMouse, Renderer)
        }
        onReleased: (mouse) => Interaction.handleMouseUp(graphRoot, canvas, animTimer, mouse, graphMouse, (typeof backend !== "undefined" ? backend : null))
    }

    WheelHandler {
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => Interaction.handleWheel(graphRoot, canvas, event)
    }
}
