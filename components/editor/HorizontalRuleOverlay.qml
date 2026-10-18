import QtQuick
import "../theme"

Item {
    id: hrOverlay
    anchors.fill: parent
    visible: hrOverlay.isLiveMode

    property var editorArea: null
    property bool isLiveMode: true

    property var hrRules: []

    function updateRules() {
        if (!editorArea || !editorArea.text || !isLiveMode) {
            hrRules = []
            return
        }
        var txt = editorArea.text
        if (txt.indexOf("---") === -1) {
            if (hrRules.length > 0) hrRules = []
            return
        }
        var lines = txt.split("\n")
        var newRules = []
        var charIdx = 0
        var totalWidth = editorArea ? editorArea.width : parent.width
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (/^[ \t]*---[ \t]*$/.test(line)) {
                var dashEndIdx = charIdx + line.indexOf("---") + 3
                var r = editorArea.positionToRectangle(dashEndIdx)
                if (r && r.height > 0) {
                    var gap = 8
                    var startX = r.x + gap
                    var ruleWidth = Math.max(0, totalWidth - startX)
                    var ruleY = r.y + Math.round(r.height / 2) - 1
                    newRules.push({
                        x: startX,
                        y: ruleY,
                        width: ruleWidth
                    })
                }
            }
            charIdx += line.length + 1
        }
        hrRules = newRules
    }

    Connections {
        target: hrOverlay.editorArea
        function onTextChanged() { hrOverlay.updateRules() }
        function onWidthChanged() { hrOverlay.updateRules() }
        function onHeightChanged() { hrOverlay.updateRules() }
        function onContentHeightChanged() { hrOverlay.updateRules() }
    }

    onIsLiveModeChanged: updateRules()
    Component.onCompleted: updateRules()

    Repeater {
        model: hrOverlay.hrRules
        Rectangle {
            x: modelData.x
            y: modelData.y
            width: modelData.width
            height: 2
            radius: 1
            color: Theme.borderColor
            opacity: 0.6
            visible: hrOverlay.isLiveMode
        }
    }
}
