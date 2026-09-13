import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../js/editor/mainbar_controller.js" as Controller
import "../theme"

Item {
    id: gutterItem

    property var editorArea: null
    property int barSize: 36
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

        Component.onCompleted: requestPaint()

        Connections {
            target: gutterItem.editorArea
            function onTextChanged() { gutterCanvas.requestPaint() }
            function onWidthChanged() { gutterCanvas.requestPaint() }
            function onCursorPositionChanged() { gutterCanvas.requestPaint() }
            function onFontChanged() { gutterCanvas.requestPaint() }
        }

        onPaint: Controller.drawGutterDots(gutterCanvas, gutterItem.editorArea, width, height, Theme.gutterActive, Theme.gutterText)
    }
}
