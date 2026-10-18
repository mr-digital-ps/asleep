import QtQuick
import "../theme"

Item {
    id: concealOverlay
    anchors.fill: parent

    property var editorArea: null
    property bool isLiveMode: false
    property var blocks: []

    Repeater {
        model: (concealOverlay.isLiveMode && concealOverlay.blocks) ? concealOverlay.blocks : []

        Item {
            id: blockConcealItem
            anchors.fill: parent

            property var blockData: modelData

            function updateAllPositions() {
                if (!concealOverlay.editorArea || !blockData) return
                var r1 = concealOverlay.editorArea.positionToRectangle(blockData.openBracePos)
                if (r1 && r1.width > 0) {
                    openBraceMask.x = r1.x - 1
                    openBraceMask.y = r1.y
                    openBraceMask.width = r1.width + 2
                    openBraceMask.height = r1.height
                }
                var r2 = concealOverlay.editorArea.positionToRectangle(blockData.closeBracePos)
                if (r2 && r2.width > 0) {
                    closeBraceMask.x = r2.x - 1
                    closeBraceMask.y = r2.y
                    closeBraceMask.width = r2.width + 2
                    closeBraceMask.height = r2.height
                }
            }

            Connections {
                target: concealOverlay.editorArea
                function onCursorRectangleChanged() { blockConcealItem.updateAllPositions() }
                function onWidthChanged() { blockConcealItem.updateAllPositions() }
                function onHeightChanged() { blockConcealItem.updateAllPositions() }
            }

            Component.onCompleted: blockConcealItem.updateAllPositions()

            // Скобки {} стилизуются полупрозрачно/приглушенно через DialectHighlighter
            Rectangle {
                id: openBraceMask
                visible: false
            }

            Rectangle {
                id: closeBraceMask
                visible: false
            }
        }
    }
}
