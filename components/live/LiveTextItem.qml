import QtQuick
import QtQuick.Controls.Basic
import "../theme"

Item {
    id: textItemRoot

    property string content: ""
    property alias text: textInputArea.text
    property bool isFocused: textInputArea.activeFocus
    property int fontSize: Theme.defaultFontSize
    property bool showLineDots: true
    property real lineHeightPercent: Theme.defaultLineHeightPercent
    property var backendInstance: null

    signal textContentEdited(string newContent)
    signal activated()
    signal requestPreviousSegment()
    signal requestNextSegment()
    signal openWikiLinkRequested(string target)

    function tryOpenLink(txt, pos) {
        if (!txt) return false
        let re = /\[\[([^\]|]+)(?:\|[^\]]+)?\]\]/g
        let match
        while ((match = re.exec(txt)) !== null) {
            if (pos >= match.index && pos <= match.index + match[0].length) {
                textItemRoot.openWikiLinkRequested(match[1].trim())
                return true
            }
        }
        return false
    }

    function focusTop() {
        textInputArea.forceActiveFocus()
        textInputArea.cursorPosition = 0
    }

    function focusBottom() {
        textInputArea.forceActiveFocus()
        textInputArea.cursorPosition = textInputArea.text.length
    }

    width: parent ? parent.width : Theme.defaultSheetWidth
    height: textInputArea.implicitHeight

    function applyLineHeight() {
        if (backendInstance && typeof backendInstance.set_editor_line_height === "function") {
            backendInstance.set_editor_line_height(textInputArea, lineHeightPercent)
        }
    }

    function attachHighlighter() {
        if (backendInstance && typeof backendInstance.attach_highlighter === "function") {
            backendInstance.attach_highlighter(textInputArea)
        }
    }

    onLineHeightPercentChanged: applyLineHeight()
    onBackendInstanceChanged: {
        applyLineHeight()
        attachHighlighter()
    }

    // Отрисовка точек строк строго по нативным координатам каждой строки через positionToRectangle
    Repeater {
        model: {
            if (!textItemRoot.showLineDots) return 0
            let txt = textInputArea.text || ""
            let lines = txt.split("\n")
            return Math.max(1, lines.length)
        }

        delegate: Rectangle {
            x: -Theme.barSize / 2 - width / 2
            // Вычисляем точное положение строки текста
            y: {
                let txt = textInputArea.text || ""
                let lines = txt.split("\n")
                let charPos = 0
                for (let i = 0; i < index && i < lines.length; i++) {
                    charPos += lines[i].length + 1
                }
                let rect = textInputArea.positionToRectangle(charPos)
                return Math.round(rect.y + (rect.height / 2) - (height / 2))
            }
            width: 4
            height: 4
            radius: 2
            color: Theme.gutterText
        }
    }

    TextArea {
        id: textInputArea
        width: parent.width
        leftPadding: 0
        rightPadding: 0
        topPadding: 0
        bottomPadding: 0

        text: textItemRoot.content
        font.family: Theme.fontFamily
        font.pixelSize: textItemRoot.fontSize
        color: Theme.textPrimary
        selectionColor: Theme.selectionColor
        selectedTextColor: Theme.textSelected
        wrapMode: TextArea.Wrap
        selectByMouse: true
        background: null

        Keys.onUpPressed: (event) => {
            let firstLineEnd = text.indexOf("\n")
            let isFirstLine = (firstLineEnd === -1) ? true : (cursorPosition <= firstLineEnd)
            if (isFirstLine) {
                textItemRoot.requestPreviousSegment()
                event.accepted = true
                return
            }
            event.accepted = false
        }

        Keys.onDownPressed: (event) => {
            let lastLineStart = text.lastIndexOf("\n")
            let isLastLine = (lastLineStart === -1) ? true : (cursorPosition > lastLineStart)
            if (isLastLine) {
                textItemRoot.requestNextSegment()
                event.accepted = true
                return
            }
            event.accepted = false
        }

        Keys.onReturnPressed: (event) => {
            if (event.modifiers & Qt.ControlModifier) {
                if (textItemRoot.tryOpenLink(text, cursorPosition)) {
                    event.accepted = true
                    return
                }
            }
            event.accepted = false
        }

        TapHandler {
            acceptedModifiers: Qt.ControlModifier
            onTapped: (point) => {
                let pos = textInputArea.positionAt(point.position.x, point.position.y)
                textItemRoot.tryOpenLink(textInputArea.text, pos)
            }
        }

        onActiveFocusChanged: {
            if (activeFocus) {
                textItemRoot.activated()
            }
        }

        onTextChanged: {
            if (text !== textItemRoot.content) {
                textItemRoot.content = text
                textItemRoot.textContentEdited(text)
            }
            Qt.callLater(textItemRoot.applyLineHeight)
        }

        onCursorPositionChanged: {
            if (backendInstance && typeof backendInstance.update_highlighter_cursor === "function") {
                backendInstance.update_highlighter_cursor(textInputArea, cursorPosition)
            }
        }

        Component.onCompleted: {
            Qt.callLater(textItemRoot.applyLineHeight)
            Qt.callLater(textItemRoot.attachHighlighter)
        }
    }
}
