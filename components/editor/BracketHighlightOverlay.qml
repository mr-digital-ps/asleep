import QtQuick
import "./markdown_shortcuts.js" as Markdown
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
        Markdown.updateBracketHighlights(editorArea, primaryBracketHighlight, matchBracketHighlight)
    }
}
