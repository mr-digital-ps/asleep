import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: gutterItem

    property var editorArea: null
    property int barSize: 36
    signal activated()

    width: barSize
    Layout.preferredWidth: barSize
    Layout.fillHeight: true

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.ArrowCursor
        onPressed: {
            gutterItem.activated()
            Window.window.startSystemMove()
        }
        onDoubleClicked: {
            if (Window.window.visibility === Window.Maximized) {
                Window.window.showNormal()
            } else {
                Window.window.showMaximized()
            }
        }
    }

    // Индикаторы колонок строк (точки строк наподобие Obsidian)
    Canvas {
        id: gutterCanvas
        anchors.fill: parent

        Component.onCompleted: requestPaint()

        Connections {
            target: gutterItem.editorArea
            function onTextChanged() { gutterCanvas.requestPaint() }
            function onWidthChanged() { gutterCanvas.requestPaint() }
            function onCursorPositionChanged() { gutterCanvas.requestPaint() }
        }

        onPaint: {
            let ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (!gutterItem.editorArea) return
            let txt = gutterItem.editorArea.text
            if (txt === undefined || txt === null) return

            let lines = txt.split("\n")
            let pos = 0
            let curPos = gutterItem.editorArea.cursorPosition
            let centerX = width / 2

            for (let i = 0; i < lines.length; i++) {
                let lineLen = lines[i].length
                let isCurrentLine = (curPos >= pos && curPos <= pos + lineLen)
                let r = gutterItem.editorArea.positionToRectangle(pos)
                let dotY = r.y + (r.height / 2)

                ctx.beginPath()
                let radius = isCurrentLine ? 3.2 : 2.4
                ctx.arc(centerX, dotY, radius, 0, 2 * Math.PI)
                ctx.fillStyle = isCurrentLine ? "#888888" : "#444444"
                ctx.fill()

                pos += lineLen + 1
            }
        }
    }
}
