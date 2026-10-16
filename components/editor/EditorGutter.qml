import QtQuick
import QtQuick.Layouts
import "./gutter_renderer.js" as GutterRenderer
import "../theme"

Item {
    id: gutterItem

    property var editorArea: null
    property int barSize: Theme.barSize
    property bool showDots: true

    signal activated()
    signal dragStarted(var mouse, var item)
    signal dragUpdated(var mouse, var item)
    signal dragFinished()

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
        onPressed: (mouse) => {
            gutterItem.activated()
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
            function onLineCountChanged() { gutterCanvas.requestPaint() }
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

        onPaint: GutterRenderer.drawGutterDots(gutterCanvas, gutterItem.editorArea, width, height, Theme.gutterActive, Theme.gutterText)
    }
}
