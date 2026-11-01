import QtQuick
import "./editor_shortcuts.js" as Shortcuts
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

    Timer {
        id: bracketDebounceTimer
        interval: 35
        repeat: false
        onTriggered: {
            Shortcuts.updateBracketHighlights(editorArea, primaryBracketHighlight, matchBracketHighlight)
        }
    }

    function updateBracketHighlights() {
        bracketDebounceTimer.restart()
    }
}
