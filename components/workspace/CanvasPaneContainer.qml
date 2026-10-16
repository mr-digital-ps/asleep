import QtQuick
import "./snap_engine.js" as SnapEngine
import "../theme"

// components/workspace/CanvasPaneContainer.qml — Контейнер плавающей/примагниченной панели на холсте
Item {
    id: containerRoot

    property string paneId: ""
    property alias pane: innerPane
    property bool isFloating: false
    property var otherPanesProvider: null

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
        onPaneActivated: containerRoot.paneActivated()
    }

    // Верхняя область перетаскивания (Header Drag Handler)
    MouseArea {
        id: headerDragArea
        x: 0
        y: 0
        width: parent.width
        height: Theme.headerHeight
        z: 50 // Поверх контента шапки, но под кнопками и полем ввода
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        property real startMouseX: 0
        property real startMouseY: 0
        property real startPaneX: 0
        property real startPaneY: 0
        property bool isDragging: false

        onPressed: (mouse) => {
            // Активируем панель при клике
            containerRoot.paneActivated()
            startMouseX = mouse.x
            startMouseY = mouse.y
            startPaneX = containerRoot.x
            startPaneY = containerRoot.y
            isDragging = false
        }

        onPositionChanged: (mouse) => {
            var dx = mouse.x - startMouseX
            var dy = mouse.y - startMouseY
            if (!isDragging && (Math.abs(dx) > 4 || Math.abs(dy) > 4)) {
                isDragging = true
                containerRoot.isFloating = true
            }

            if (isDragging) {
                var rawX = containerRoot.x + dx
                var rawY = containerRoot.y + dy

                var others = otherPanesProvider ? otherPanesProvider(containerRoot.paneId) : []
                var draggedRect = {
                    id: containerRoot.paneId,
                    x: rawX,
                    y: rawY,
                    width: containerRoot.width,
                    height: containerRoot.height
                }

                // Расчёт магнетизма
                var snapResult = SnapEngine.calculateSnap(draggedRect, others, 18)
                containerRoot.x = snapResult.snappedX
                containerRoot.y = snapResult.snappedY

                containerRoot.snapMoved(snapResult.guidelines, snapResult.dockSide, snapResult.dockTargetId)
            }
        }

        onReleased: {
            if (isDragging) {
                isDragging = false
                containerRoot.snapEnded()
            }
        }
    }

    // Рамка ресайза (8 направлений: грани и углы)
    // 1. Правый край (Resize Right)
    MouseArea {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 6
        z: 60
        cursorShape: Qt.SizeHorCursor
        onPositionChanged: (mouse) => {
            if (pressed) {
                var newW = containerRoot.width + mouse.x
                containerRoot.width = Math.max(Theme.minSheetWidth, newW)
            }
        }
    }

    // 2. Нижний край (Resize Bottom)
    MouseArea {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 6
        z: 60
        cursorShape: Qt.SizeVerCursor
        onPositionChanged: (mouse) => {
            if (pressed) {
                var newH = containerRoot.height + mouse.y
                containerRoot.height = Math.max(300, newH)
            }
        }
    }

    // 3. Правый нижний угол (Resize Corner)
    MouseArea {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 12
        height: 12
        z: 70
        cursorShape: Qt.SizeFDiagCursor
        onPositionChanged: (mouse) => {
            if (pressed) {
                containerRoot.width = Math.max(Theme.minSheetWidth, containerRoot.width + mouse.x)
                containerRoot.height = Math.max(300, containerRoot.height + mouse.y)
            }
        }
    }
}
