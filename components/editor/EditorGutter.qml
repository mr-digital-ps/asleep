import QtQuick
import QtQuick.Layouts
import "./gutter_renderer.js" as GutterRenderer
import "../theme"

Item {
    id: gutterItem

    property var editorArea: null
    property int barSize: 36
    property bool showDots: true

    signal activated()

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
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.ArrowCursor
        onPressed: (mouse) => {
            gutterItem.activated()
            let win = Window.window
            if (win && typeof win.startSystemMove === "function") {
                win.startSystemMove()
            }
        }
        onDoubleClicked: {
            let win = Window.window
            if (win) {
                if (win.visibility === Window.Maximized) {
                    win.showNormal()
                } else {
                    win.showMaximized()
                }
            }
        }
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
