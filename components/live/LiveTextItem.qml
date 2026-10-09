import QtQuick
import QtQuick.Controls.Basic
import "../theme"
import "../editor"

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

    function tryOpenLink(txt, pos) {
        if (!txt) return false
        let re = /\[\[([^\]|]+)(?:\|[^\]]+)?\]\]/g
        let match
        while ((match = re.exec(txt)) !== null) {
            if (pos >= match.index && pos <= match.index + match[0].length) {
                let target = match[1].trim()
                if (backendInstance && typeof backendInstance.open_wiki_link === "function") {
                    return backendInstance.open_wiki_link(target)
                }
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

    function focusAtPos(pos) {
        textInputArea.forceActiveFocus()
        textInputArea.cursorPosition = Math.min(Math.max(0, pos), textInputArea.text.length)
    }

    function getCursorPos() {
        return textInputArea.cursorPosition
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
            readonly property real scaleFactor: Math.max(0.6, Math.min(2.5, textItemRoot.fontSize / 15.0))
            readonly property real dotSize: Math.round(4.0 * scaleFactor)
            x: Math.round(-Theme.barSize / 2 - dotSize / 2)
            // Вычисляем точное положение строки текста
            y: {
                let txt = textInputArea.text || ""
                let lines = txt.split("\n")
                let charPos = 0
                for (let i = 0; i < index && i < lines.length; i++) {
                    charPos += lines[i].length + 1
                }
                let rect = textInputArea.positionToRectangle(charPos)
                return Math.round(rect.y + (rect.height / 2) - (dotSize / 2))
            }
            width: dotSize
            height: dotSize
            radius: dotSize / 2
            readonly property bool isCurrentLine: {
                if (!textInputArea.activeFocus) return false
                let txt = textInputArea.text || ""
                let lines = txt.split("\n")
                let startPos = 0
                for (let i = 0; i < index && i < lines.length; i++) {
                    startPos += lines[i].length + 1
                }
                let endPos = startPos + (index < lines.length ? lines[index].length : 0)
                let cur = textInputArea.cursorPosition
                return cur >= startPos && cur <= endPos
            }
            color: isCurrentLine ? Theme.gutterActive : Theme.gutterText
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
        selectionColor: "transparent"
        selectedTextColor: Theme.textPrimary
        wrapMode: TextArea.Wrap
        selectByMouse: true
        background: Item {
            SelectionHighlightOverlay {
                editorArea: textInputArea
            }

            Rectangle {
                id: currentLineHighlight
                visible: textInputArea.activeFocus && textInputArea.cursorRectangle.height > 0 && (textInputArea.selectionStart === textInputArea.selectionEnd)
                x: 0
                width: parent.width
                y: textInputArea.cursorRectangle.y
                height: textInputArea.cursorRectangle.height
                color: Theme.lineHighlight
                radius: 3
            }
        }

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

        MouseArea {
            anchors.fill: parent
            cursorShape: (mouse.modifiers & Qt.ControlModifier) ? Qt.PointingHandCursor : Qt.IBeamCursor
            acceptedButtons: Qt.LeftButton
            propagateComposedEvents: true
            onPressed: (mouse) => {
                if (mouse.modifiers & Qt.ControlModifier) {
                    let pos = textInputArea.positionAt(mouse.x, mouse.y)
                    if (textItemRoot.tryOpenLink(textInputArea.text, pos)) {
                        mouse.accepted = true
                        return
                    }
                }
                mouse.accepted = false
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
