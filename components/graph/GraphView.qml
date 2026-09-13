import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../js/graph/graph_physics.js" as Physics
import "../../js/graph/graph_renderer.js" as Renderer
import "../../js/graph/graph_interaction.js" as Interaction
import "../theme"

Rectangle {
    id: graphRoot
    anchors.fill: parent
    color: embeddedInSheet ? "transparent" : ((graphConfig && graphConfig.visual && graphConfig.visual.backgroundColor && graphConfig.visual.backgroundColor !== "#141414") ? graphConfig.visual.backgroundColor : Theme.bgPaper)
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

    signal nodeClicked(string fileUrl, string label, string nodeType)
    signal closeRequested()

    focus: true
    Keys.onPressed: (event) => Interaction.handleKey(graphRoot, event)

    function reloadGraph() {
        Interaction.reloadGraph(graphRoot, canvas, (typeof backend !== "undefined" ? backend : null), Physics)
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

    onActiveFileUrlChanged: {
        if (activeFileUrl) centerOnNode(activeFileUrl)
    }

    Connections {
        target: (typeof backend !== "undefined") ? backend : null
        function onGraphDataChanged() { graphRoot.reloadGraph() }
        function onFolderFilesChanged() { graphRoot.reloadGraph() }
    }

    onWidthChanged: {
        if (activeNodeId) Interaction.keepActiveNodeCentered(graphRoot)
        canvas.requestPaint()
    }
    onHeightChanged: {
        if (activeNodeId) Interaction.keepActiveNodeCentered(graphRoot)
        canvas.requestPaint()
    }

    Timer {
        id: animTimer
        interval: 16
        repeat: true
        running: false
        onTriggered: Interaction.stepAnimation(graphRoot, canvas, animTimer, Physics)
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
        onPressed: (mouse) => Interaction.handleMouseDown(graphRoot, animTimer, mouse, graphMouse, Renderer)
        onReleased: (mouse) => Interaction.handleMouseUp(graphRoot, canvas, animTimer, mouse, graphMouse)
    }

    Rectangle {
        id: miniControls
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 12
        height: 28
        radius: 6
        color: Theme.bgDialog
        border.color: Theme.borderColor
        border.width: 1
        z: 100
        visible: !graphRoot.embeddedInSheet

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 6

            Text {
                text: "🔍"
                font.pixelSize: 10
                color: Theme.textMuted
            }

            TextInput {
                id: searchInput
                width: 100
                color: Theme.textPrimary
                selectionColor: Theme.selectionColor
                selectedTextColor: Theme.textSelected
                font.pixelSize: 11
                selectByMouse: true
                clip: true
                onTextChanged: Interaction.handleSearch(graphRoot, canvas, text)

                Text {
                    anchors.fill: parent
                    text: "Поиск..."
                    color: Theme.textMuted
                    font.pixelSize: 11
                    visible: !searchInput.text && !searchInput.activeFocus
                }
            }

            Rectangle {
                width: 1
                height: 14
                color: Theme.borderColor
            }

            Rectangle {
                width: 20
                height: 20
                radius: 4
                color: centerHover.hovered ? Theme.bgHover : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "⊙"
                    color: centerHover.hovered ? Theme.textPrimary : Theme.textMuted
                    font.pixelSize: 12
                }
                HoverHandler { id: centerHover }
                TapHandler { onTapped: graphRoot.resetView() }
            }

            Rectangle {
                width: 20
                height: 20
                radius: 4
                color: closeHover.hovered ? Theme.bgHover : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: closeHover.hovered ? Theme.dangerColor : Theme.textMuted
                    font.pixelSize: 11
                }
                HoverHandler { id: closeHover }
                TapHandler { onTapped: graphRoot.closeRequested() }
            }
        }
    }

    WheelHandler {
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => Interaction.handleWheel(graphRoot, canvas, event)
    }
}
