import QtQuick
import "../../js/editor/markdown_shortcuts.js" as Markdown
import "../theme"


Item {
    id: bracketOverlay
    anchors.fill: parent

    property var editorArea: null

    Rectangle {
        id: primaryBracketHighlight
        visible: false
        color: Qt.rgba(Theme.bracketMatch.r, Theme.bracketMatch.g, Theme.bracketMatch.b, 0.2)
        border.color: Theme.bracketMatch
        border.width: 1
        radius: 2
    }

    Rectangle {
        id: matchBracketHighlight
        visible: false
        color: Qt.rgba(Theme.bracketMatch.r, Theme.bracketMatch.g, Theme.bracketMatch.b, 0.2)
        border.color: Theme.bracketMatch
        border.width: 1
        radius: 2
    }

    function updateBracketHighlights() {
        if (!editorArea || !editorArea.activeFocus || editorArea.selectionStart !== editorArea.selectionEnd) {
            primaryBracketHighlight.visible = false
            matchBracketHighlight.visible = false
            return
        }

        let pair = Markdown.findMatchingBracket(editorArea.text, editorArea.cursorPosition)
        if (!pair) {
            primaryBracketHighlight.visible = false
            matchBracketHighlight.visible = false
            return
        }

        let r1 = editorArea.positionToRectangle(pair.primary)
        let r2 = editorArea.positionToRectangle(pair.match)

        if (r1 && r1.height > 0) {
            primaryBracketHighlight.x = r1.x
            primaryBracketHighlight.y = r1.y
            primaryBracketHighlight.width = Math.max(8, r1.width)
            primaryBracketHighlight.height = r1.height
            primaryBracketHighlight.visible = true
        } else {
            primaryBracketHighlight.visible = false
        }

        if (r2 && r2.height > 0) {
            matchBracketHighlight.x = r2.x
            matchBracketHighlight.y = r2.y
            matchBracketHighlight.width = Math.max(8, r2.width)
            matchBracketHighlight.height = r2.height
            matchBracketHighlight.visible = true
        } else {
            matchBracketHighlight.visible = false
        }
    }
}
