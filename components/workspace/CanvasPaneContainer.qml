import QtQuick
import QtQuick.Controls
import "./snap_engine.js" as SnapEngine
import "../theme"

// components/workspace/CanvasPaneContainer.qml — Контейнер плавающей/примагниченной панели на холсте
Item {
    id: containerRoot

    property string savedText: ""
    signal closeRequested()
    signal actionRequested(string action)
    signal renameRequested(string title)
    signal contentChanged()

    property string paneId: ""
    property alias pane: innerPane
    property bool isFloating: false
    property var otherPanesProvider: null

    property string tileState: "none"
    property var floatingBounds: null

    ParallelAnimation {
        id: boundsAnim
        NumberAnimation { id: animX; target: containerRoot; property: "x"; duration: Theme.animDurationNormal; easing.type: Easing.OutCubic }
        NumberAnimation { id: animY; target: containerRoot; property: "y"; duration: Theme.animDurationNormal; easing.type: Easing.OutCubic }
        NumberAnimation { id: animW; target: containerRoot; property: "width"; duration: Theme.animDurationNormal; easing.type: Easing.OutCubic }
        NumberAnimation { id: animH; target: containerRoot; property: "height"; duration: Theme.animDurationNormal; easing.type: Easing.OutCubic }
    }

    function setBoundsAnimated(tx, ty, tw, th) {
        boundsAnim.stop()
        animX.to = tx
        animY.to = ty
        animW.to = Math.max(Theme.minSheetWidth, tw)
        animH.to = Math.max(Theme.canvasMinHeight, th)
        boundsAnim.start()
    }

    signal snapMoved(var guidelines, var dockSide, string dockTargetId)
    signal snapEnded()
    signal paneActivated()

    // Минимальные габариты панели
    implicitWidth: 700
    implicitHeight: 800

    // Внутренняя панель
    WorkspacePane {
        id: innerPane
        anchors.fill: parent
        onTextChanged: containerRoot.contentChanged()
        onTitleChangedByUser: (title) => containerRoot.renameRequested(title)
        onCloseRequested: containerRoot.closeRequested()
        onSaveRequested: containerRoot.actionRequested("save_file")
        onNewRequested: containerRoot.actionRequested("new_tab")
        onOpenRequested: containerRoot.actionRequested("open_file")
        onToggleGraphRequested: containerRoot.actionRequested("toggle_graph")
        onToggleLocalGraphRequested: containerRoot.actionRequested("toggle_local_graph")
        onCloseGraphRequested: innerPane.isGraphMode = false
        onOpenStructureRequested: containerRoot.actionRequested("open_structure")
        onPaneActivated: containerRoot.paneActivated()
        onPanelDragStarted: (mouse, item) => containerRoot.startDrag(mouse, item)
        onPanelDragUpdated: (mouse, item) => containerRoot.updateDrag(mouse, item)
        onPanelDragFinished: () => containerRoot.endDrag()
    }

    // Тонкая деликатная граница блокнота на холсте
    Rectangle {
        id: paneBorder
        anchors.fill: parent
        color: "transparent"
        border.width: 1
        border.color: innerPane.isActivePane ? Theme.borderFocus : Theme.borderColor
        z: 50 // Поверх контента, но под интерактивными рамками ресайза (z: 60/70)

        Behavior on border.color {
            ColorAnimation { duration: Theme.animDurationNormal }
        }
    }

    property real startMouseX: 0
    property real startMouseY: 0
    property real startPaneX: 0
    property real startPaneY: 0
    property bool isDragPressed: false
    property bool isDragging: false

    function startDrag(mouse, item) {
        if (!mouse || !item) return
        if (boundsAnim.running) boundsAnim.stop()
        containerRoot.tileState = "none"
        containerRoot.floatingBounds = null
        containerRoot.paneActivated()
        var pt = item.mapToItem(containerRoot.parent, mouse.x, mouse.y)
        startMouseX = pt.x
        startMouseY = pt.y
        startPaneX = containerRoot.x
        startPaneY = containerRoot.y
        isDragPressed = true
        isDragging = false
    }

    function updateDrag(mouse, item) {
        if (!isDragPressed || !mouse || !item) return
        var pt = item.mapToItem(containerRoot.parent, mouse.x, mouse.y)
        var dx = pt.x - startMouseX
        var dy = pt.y - startMouseY
        if (!isDragging) {
            if (Math.abs(dx) > 6 || Math.abs(dy) > 6) {
                isDragging = true
                containerRoot.isFloating = true
            } else {
                return
            }
        }

        if (isDragging) {
            var rawX = startPaneX + dx
            var rawY = startPaneY + dy

            var others = otherPanesProvider ? otherPanesProvider(containerRoot.paneId) : []
            var draggedRect = {
                id: containerRoot.paneId,
                x: rawX,
                y: rawY,
                width: containerRoot.width,
                height: containerRoot.height
            }

            // Расчёт магнетизма
            var snapResult = SnapEngine.calculateSnap(draggedRect, others, Theme.canvasSnapDistance)
            containerRoot.x = snapResult.snappedX
            containerRoot.y = snapResult.snappedY

            containerRoot.snapMoved(snapResult.guidelines, snapResult.dockSide, snapResult.dockTargetId)
        }
    }

    function endDrag() {
        isDragPressed = false
        if (isDragging) {
            isDragging = false
            containerRoot.snapEnded()
        }
    }

    // -------------------------------------------------------------------------
    // Стандартная рамка изменения размера панели (8 направлений: грани и углы)
    // -------------------------------------------------------------------------
    property real resizeStartPaneX: 0
    property real resizeStartPaneY: 0
    property real resizeStartPaneW: 0
    property real resizeStartPaneH: 0
    property real resizeStartMouseX: 0
    property real resizeStartMouseY: 0

    function initResize(mouse, item) {
        if (boundsAnim.running) boundsAnim.stop()
        containerRoot.tileState = "none"
        containerRoot.floatingBounds = null
        var pt = item.mapToItem(containerRoot.parent, mouse.x, mouse.y)
        resizeStartMouseX = pt.x
        resizeStartMouseY = pt.y
        resizeStartPaneX = containerRoot.x
        resizeStartPaneY = containerRoot.y
        resizeStartPaneW = containerRoot.width
        resizeStartPaneH = containerRoot.height
    }

    function applyResize(rawX, rawY, rawW, rawH, handleType) {
        var others = otherPanesProvider ? otherPanesProvider(containerRoot.paneId) : []
        var candidateRect = {
            id: containerRoot.paneId,
            x: rawX,
            y: rawY,
            width: rawW,
            height: rawH
        }
        var snap = SnapEngine.calculateResizeSnap(
            candidateRect,
            others,
            handleType,
            Theme.canvasSnapDistance,
            Theme.minSheetWidth,
            Theme.canvasMinHeight
        )
        containerRoot.x = snap.snappedX
        containerRoot.y = snap.snappedY
        containerRoot.width = snap.snappedWidth
        containerRoot.height = snap.snappedHeight
        containerRoot.snapMoved(snap.guidelines, null, null)
    }

    function endResize() {
        containerRoot.snapEnded()
    }

    // 1. Грани (Edges, z: 60)
    // Правый край (Right)
    MouseArea {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: Theme.canvasResizeMargin
        anchors.bottomMargin: Theme.canvasResizeMargin
        width: Theme.canvasResizeMargin
        z: 60
        cursorShape: Qt.SizeHorCursor
        onPressed: (mouse) => containerRoot.initResize(mouse, this)
        onPositionChanged: (mouse) => {
            if (pressed) {
                var pt = mapToItem(containerRoot.parent, mouse.x, mouse.y)
                var dx = pt.x - resizeStartMouseX
                containerRoot.applyResize(resizeStartPaneX, resizeStartPaneY, resizeStartPaneW + dx, resizeStartPaneH, "right")
            }
        }
        onReleased: containerRoot.endResize()
        onCanceled: containerRoot.endResize()
    }

    // Левый край (Left)
    MouseArea {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: Theme.canvasResizeMargin
        anchors.bottomMargin: Theme.canvasResizeMargin
        width: Theme.canvasResizeMargin
        z: 60
        cursorShape: Qt.SizeHorCursor
        onPressed: (mouse) => containerRoot.initResize(mouse, this)
        onPositionChanged: (mouse) => {
            if (pressed) {
                var pt = mapToItem(containerRoot.parent, mouse.x, mouse.y)
                var dx = pt.x - resizeStartMouseX
                containerRoot.applyResize(resizeStartPaneX + dx, resizeStartPaneY, resizeStartPaneW - dx, resizeStartPaneH, "left")
            }
        }
        onReleased: containerRoot.endResize()
        onCanceled: containerRoot.endResize()
    }

    // Нижний край (Bottom)
    MouseArea {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Theme.canvasResizeMargin
        anchors.rightMargin: Theme.canvasResizeMargin
        height: Theme.canvasResizeMargin
        z: 60
        cursorShape: Qt.SizeVerCursor
        onPressed: (mouse) => containerRoot.initResize(mouse, this)
        onPositionChanged: (mouse) => {
            if (pressed) {
                var pt = mapToItem(containerRoot.parent, mouse.x, mouse.y)
                var dy = pt.y - resizeStartMouseY
                containerRoot.applyResize(resizeStartPaneX, resizeStartPaneY, resizeStartPaneW, resizeStartPaneH + dy, "bottom")
            }
        }
        onReleased: containerRoot.endResize()
        onCanceled: containerRoot.endResize()
    }

    // Верхний край (Top)
    MouseArea {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Theme.canvasResizeMargin
        anchors.rightMargin: Theme.canvasResizeMargin
        height: Theme.canvasResizeMargin
        z: 60
        cursorShape: Qt.SizeVerCursor
        onPressed: (mouse) => containerRoot.initResize(mouse, this)
        onPositionChanged: (mouse) => {
            if (pressed) {
                var pt = mapToItem(containerRoot.parent, mouse.x, mouse.y)
                var dy = pt.y - resizeStartMouseY
                containerRoot.applyResize(resizeStartPaneX, resizeStartPaneY + dy, resizeStartPaneW, resizeStartPaneH - dy, "top")
            }
        }
        onReleased: containerRoot.endResize()
        onCanceled: containerRoot.endResize()
    }

    // 2. Углы (Corners, z: 70)
    // Правый нижний угол (Bottom-Right)
    MouseArea {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: Theme.canvasResizeMargin * 2
        height: Theme.canvasResizeMargin * 2
        z: 70
        cursorShape: Qt.SizeFDiagCursor
        onPressed: (mouse) => containerRoot.initResize(mouse, this)
        onPositionChanged: (mouse) => {
            if (pressed) {
                var pt = mapToItem(containerRoot.parent, mouse.x, mouse.y)
                var dx = pt.x - resizeStartMouseX
                var dy = pt.y - resizeStartMouseY
                containerRoot.applyResize(resizeStartPaneX, resizeStartPaneY, resizeStartPaneW + dx, resizeStartPaneH + dy, "bottom-right")
            }
        }
        onReleased: containerRoot.endResize()
        onCanceled: containerRoot.endResize()
    }

    // Левый нижний угол (Bottom-Left)
    MouseArea {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: Theme.canvasResizeMargin * 2
        height: Theme.canvasResizeMargin * 2
        z: 70
        cursorShape: Qt.SizeBDiagCursor
        onPressed: (mouse) => containerRoot.initResize(mouse, this)
        onPositionChanged: (mouse) => {
            if (pressed) {
                var pt = mapToItem(containerRoot.parent, mouse.x, mouse.y)
                var dx = pt.x - resizeStartMouseX
                var dy = pt.y - resizeStartMouseY
                containerRoot.applyResize(resizeStartPaneX + dx, resizeStartPaneY, resizeStartPaneW - dx, resizeStartPaneH + dy, "bottom-left")
            }
        }
        onReleased: containerRoot.endResize()
        onCanceled: containerRoot.endResize()
    }

    // Правый верхний угол (Top-Right)
    MouseArea {
        anchors.right: parent.right
        anchors.top: parent.top
        width: Theme.canvasResizeMargin * 2
        height: Theme.canvasResizeMargin * 2
        z: 70
        cursorShape: Qt.SizeBDiagCursor
        onPressed: (mouse) => containerRoot.initResize(mouse, this)
        onPositionChanged: (mouse) => {
            if (pressed) {
                var pt = mapToItem(containerRoot.parent, mouse.x, mouse.y)
                var dx = pt.x - resizeStartMouseX
                var dy = pt.y - resizeStartMouseY
                containerRoot.applyResize(resizeStartPaneX, resizeStartPaneY + dy, resizeStartPaneW + dx, resizeStartPaneH - dy, "top-right")
            }
        }
        onReleased: containerRoot.endResize()
        onCanceled: containerRoot.endResize()
    }

    // Левый верхний угол (Top-Left)
    MouseArea {
        anchors.left: parent.left
        anchors.top: parent.top
        width: Theme.canvasResizeMargin * 2
        height: Theme.canvasResizeMargin * 2
        z: 70
        cursorShape: Qt.SizeFDiagCursor
        onPressed: (mouse) => containerRoot.initResize(mouse, this)
        onPositionChanged: (mouse) => {
            if (pressed) {
                var pt = mapToItem(containerRoot.parent, mouse.x, mouse.y)
                var dx = pt.x - resizeStartMouseX
                var dy = pt.y - resizeStartMouseY
                containerRoot.applyResize(resizeStartPaneX + dx, resizeStartPaneY + dy, resizeStartPaneW - dx, resizeStartPaneH - dy, "top-left")
            }
        }
        onReleased: containerRoot.endResize()
        onCanceled: containerRoot.endResize()
    }
}
