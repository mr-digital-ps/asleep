import QtQuick
import QtQuick.Layouts
import "./gutter_renderer.js" as GutterRenderer
import "./block_scanner.js" as BlockScanner
import "../theme"

Item {
    id: gutterItem

    property var editorArea: null
    property int barSize: Theme.barSize
    property bool showDots: true
    property bool isLiveMode: false
    property var blocks: []
    property var collapsedBlocks: ({})

    signal activated()
    signal dragStarted(var mouse, var item)
    signal dragUpdated(var mouse, var item)
    signal dragFinished()
    signal toggleBlockFoldRequested(var block, int lineIndex)

    function updateBlocks() {
        if (!editorArea || !editorArea.text || !isLiveMode) {
            blocks = []
        } else {
            blocks = BlockScanner.scanBlocks(editorArea.text)
        }
        gutterCanvas.requestPaint()
    }

    width: barSize
    Layout.preferredWidth: barSize
    Layout.fillHeight: true

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            if (event.modifiers & Qt.ControlModifier && gutterItem.editorArea) {
                if (event.angleDelta.y > 0) {
                    gutterItem.editorArea.font.pixelSize = Math.min(36, gutterItem.editorArea.font.pixelSize + 1)
                } else if (event.angleDelta.y < 0) {
                    gutterItem.editorArea.font.pixelSize = Math.max(10, gutterItem.editorArea.font.pixelSize - 1)
                }
                event.accepted = true
            }
        }
    }

    MouseArea {
        id: gutterBgArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        function findLineAtY(mouseY) {
            if (!gutterItem.editorArea || !gutterItem.editorArea.text) return -1
            var lines = gutterItem.editorArea.text.split("\n")
            var pos = 0
            for (var i = 0; i < lines.length; i++) {
                var r = gutterItem.editorArea.positionToRectangle(pos)
                if (mouseY >= r.y && mouseY <= r.y + r.height) {
                    return i
                }
                pos += lines[i].length + 1
            }
            return -1
        }

        onPressed: (mouse) => {
            gutterItem.activated()

            // В Live Mode проверяем клик по маркеру свёртки блока
            if (gutterItem.isLiveMode) {
                var clickedLine = findLineAtY(mouse.y)
                if (clickedLine >= 0) {
                    // Проверяем клик по открытому блоку
                    for (var b = 0; b < gutterItem.blocks.length; b++) {
                        var blk = gutterItem.blocks[b]
                        if (blk.startLine === clickedLine) {
                            gutterItem.toggleBlockFoldRequested(blk, clickedLine)
                            return
                        }
                    }
                    // Проверяем клик по свёрнутому блоку
                    if (gutterItem.collapsedBlocks) {
                        var lineText = ""
                        if (gutterItem.editorArea && gutterItem.editorArea.text) {
                            var allL = gutterItem.editorArea.text.split("\n")
                            if (clickedLine >= 0 && clickedLine < allL.length) {
                                lineText = allL[clickedLine].trim()
                            }
                        }
                        for (var cId in gutterItem.collapsedBlocks) {
                            var cBlk = gutterItem.collapsedBlocks[cId]
                            if (cBlk && (cBlk.headerLine === clickedLine || (lineText && cBlk.name + " ...." === lineText))) {
                                gutterItem.toggleBlockFoldRequested(cBlk, clickedLine)
                                return
                            }
                        }
                    }
                }
            }

            gutterItem.dragStarted(mouse, gutterBgArea)
        }
        onPositionChanged: (mouse) => {
            if (pressed) {
                gutterItem.dragUpdated(mouse, gutterBgArea)
            }
        }
        onReleased: gutterItem.dragFinished()
        onCanceled: gutterItem.dragFinished()
    }

    // Индикаторы колонок строк (точки строк, масштабируемые вместе со шрифтом)
    Canvas {
        id: gutterCanvas
        anchors.fill: parent
        visible: gutterItem.showDots
        property real lastCursorY: -1

        Component.onCompleted: requestPaint()

        Connections {
            target: gutterItem.editorArea
            function onLineCountChanged() {
                gutterItem.updateBlocks()
                gutterCanvas.requestPaint()
            }
            function onTextChanged() {
                gutterItem.updateBlocks()
                gutterCanvas.requestPaint()
            }
            function onCursorRectangleChanged() {
                if (!gutterItem.editorArea) return
                let curY = gutterItem.editorArea.cursorRectangle.y
                if (Math.abs(curY - gutterCanvas.lastCursorY) > 2) {
                    gutterCanvas.lastCursorY = curY
                    gutterCanvas.requestPaint()
                }
            }
            function onWidthChanged() { gutterCanvas.requestPaint() }
            function onFontChanged() { gutterCanvas.requestPaint() }
        }

        Connections {
            target: gutterItem
            function onIsLiveModeChanged() {
                gutterItem.updateBlocks()
                gutterCanvas.requestPaint()
            }
            function onCollapsedBlocksChanged() {
                gutterCanvas.requestPaint()
            }
        }

        onPaint: GutterRenderer.drawGutterDots(
            gutterCanvas,
            gutterItem.editorArea,
            width,
            height,
            Theme.gutterActive,
            Theme.gutterText,
            gutterItem.isLiveMode,
            gutterItem.blocks,
            gutterItem.collapsedBlocks
        )
    }
}
