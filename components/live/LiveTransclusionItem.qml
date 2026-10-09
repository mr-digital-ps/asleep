import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme"
import "../editor"

Rectangle {
    id: transclusionRoot
    color: "transparent"

    property string targetFile: ""
    property string targetBlock: ""
    property string transcludedContent: ""
    property bool isLoading: false
    property bool isNotFound: false

    property int fontSize: Theme.defaultFontSize
    property bool showLineDots: true
    property real lineHeightPercent: Theme.defaultLineHeightPercent
    readonly property real effectiveLineHeight: Math.round(fontSize * (lineHeightPercent / 100.0))
    property var backendInstance: null

    property bool isFocused: transTextArea.activeFocus
    property alias text: transTextArea.text

    signal activated()
    signal requestPreviousSegment()
    signal requestNextSegment()

    property bool isFolded: false

    readonly property real scaleFactor: Math.max(0.6, Math.min(2.5, transclusionRoot.fontSize / 15.0))
    readonly property real dotDiameter: Math.round(6.0 * scaleFactor)
    readonly property real borderWidth: Math.max(1.5, Math.round(2.0 * scaleFactor))

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

    function openTarget(tFile, bName) {
        let fullTarget = tFile ? (bName ? (tFile + "#" + bName) : tFile) : ("#" + bName)
        if (backendInstance && typeof backendInstance.open_wiki_link === "function") {
            return backendInstance.open_wiki_link(fullTarget)
        }
        return false
    }

    function focusTop() {
        transTextArea.forceActiveFocus()
        transTextArea.cursorPosition = 0
    }

    function focusBottom() {
        transTextArea.forceActiveFocus()
        transTextArea.cursorPosition = transTextArea.text.length
    }

    function focusAtPos(pos) {
        transTextArea.forceActiveFocus()
        transTextArea.cursorPosition = Math.min(Math.max(0, pos), transTextArea.text.length)
    }

    function getCursorPos() {
        return transTextArea.cursorPosition
    }

    // Вычисляем вертикальный центр первой строки (где заголовок и точка в гаттере)
    readonly property real headerDotCenterY: {
        let rect = transTextArea.positionToRectangle(0)
        return Math.round(rect.y + (rect.height / 2))
    }

    // Низ линии: нижняя граница свисающих элементов букв последней строки контента
    readonly property real lastLineBottomY: {
        let txt = transTextArea.text || ""
        let pos = txt.length
        let rect = transTextArea.positionToRectangle(pos)
        let h = (rect.height > 0) ? rect.height : transclusionRoot.effectiveLineHeight
        return Math.round(rect.y + h - 2)
    }

    readonly property real firstLineHeight: {
        let rect = transTextArea.positionToRectangle(0)
        return Math.max(transclusionRoot.effectiveLineHeight, rect.height)
    }

    height: transclusionRoot.isFolded ? Math.round(transclusionRoot.firstLineHeight) : Math.round(transTextArea.implicitHeight + transTextArea.topPadding + transTextArea.bottomPadding)

    // Элегантная вертикальная направляющая линия по оси гаттера (dot line), идентичная LiveBlockItem
    Rectangle {
        id: leftTransBorder
        visible: transclusionRoot.showLineDots && !transclusionRoot.isFolded && !transclusionRoot.isNotFound
        x: Math.round(-Theme.barSize / 2 - width / 2)
        y: Math.round(transclusionRoot.headerDotCenterY)
        height: Math.max(0, Math.round(transclusionRoot.lastLineBottomY - y))
        width: transclusionRoot.borderWidth
        color: transclusionRoot.isFocused ? Theme.gutterActive : Theme.gutterText
        z: 1

        MouseArea {
            anchors.fill: parent
            anchors.leftMargin: -6
            anchors.rightMargin: -6
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: {
                transclusionRoot.isFolded = !transclusionRoot.isFolded
            }
        }
    }

    // Точка-маркер в гаттере (Node Dot), монолитная с линией (как в LiveBlockItem)
    Rectangle {
        id: transNodeDot
        visible: transclusionRoot.showLineDots
        readonly property real normalDotSize: Math.round(5.0 * transclusionRoot.scaleFactor)
        x: Math.round(-Theme.barSize / 2 - width / 2)
        y: Math.round(transclusionRoot.headerDotCenterY - height / 2)
        width: transclusionRoot.isFolded ? normalDotSize : transclusionRoot.dotDiameter
        height: width
        radius: width / 2
        color: (transclusionRoot.isFolded || transclusionRoot.isFocused) ? Theme.gutterActive : Theme.gutterText
        z: 2

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: {
                transclusionRoot.isFolded = !transclusionRoot.isFolded
            }
        }
    }

    function syncText() {
        let titleLine = transclusionRoot.targetFile ? (transclusionRoot.targetFile + " › " + transclusionRoot.targetBlock) : transclusionRoot.targetBlock
        let body = transclusionRoot.transcludedContent || ""
        let full = titleLine
        if (body.length > 0) {
            full += "\n" + body
        }
        if (transTextArea.text !== full) {
            transTextArea.text = full
        }
    }

    function resolveTransclusion() {
        if (!targetBlock || targetBlock.length === 0) return
        if (typeof backend === "undefined" || !backend) return

        if (typeof backend.get_block === "function") {
            let res = backend.get_block(targetBlock)
            if (res && res.found) {
                let cnt = (res.raw_content !== undefined && res.raw_content !== null) ? res.raw_content : (res.content || "")
                // Сохраняем исходные табуляции, переводы строк и структуру (включая завершающую пустую строку оригинального блока)
                transcludedContent = cnt.replace(/^\r?\n+/, "")
                // Если контент не пустой и не оканчивается переводом строки, добавляем \n чтобы соответствовать закрывающей строке блока (как в LiveBlockItem)
                if (transcludedContent.length > 0 && !transcludedContent.endsWith("\n")) {
                    transcludedContent += "\n"
                }
                isNotFound = false
            } else {
                transcludedContent = "Блок не найден: " + (targetFile ? (targetFile + "." + targetBlock) : targetBlock)
                isNotFound = true
            }
            syncText()
        }
    }

    function applyLineHeight() {
        if (backendInstance && typeof backendInstance.set_editor_line_height === "function") {
            backendInstance.set_editor_line_height(transTextArea, lineHeightPercent)
        }
    }

    function attachHighlighter() {
        if (backendInstance && typeof backendInstance.attach_highlighter === "function") {
            backendInstance.attach_highlighter(transTextArea)
        }
    }

    onLineHeightPercentChanged: applyLineHeight()
    onBackendInstanceChanged: {
        applyLineHeight()
        attachHighlighter()
    }

    Component.onCompleted: {
        resolveTransclusion()
        Qt.callLater(applyLineHeight)
        Qt.callLater(attachHighlighter)
    }

    Connections {
        target: (typeof backend !== "undefined") ? backend : null
        function onBlockUpdated(headingNorm, content, sourceFileUrl) {
            if (headingNorm === transclusionRoot.targetBlock.toLowerCase()) {
                let cnt = content || ""
                transclusionRoot.transcludedContent = cnt.replace(/^\r?\n+/, "")
                if (transclusionRoot.transcludedContent.length > 0 && !transclusionRoot.transcludedContent.endsWith("\n")) {
                    transclusionRoot.transcludedContent += "\n"
                }
                transclusionRoot.isNotFound = false
                syncText()
                Qt.callLater(applyLineHeight)
                Qt.callLater(attachHighlighter)
            }
        }
    }

    TextArea {
        id: transTextArea
        anchors.fill: parent
        clip: transclusionRoot.isFolded
        leftPadding: 0
        rightPadding: 0
        topPadding: 0
        bottomPadding: 0

        font.family: Theme.fontFamily
        font.pixelSize: transclusionRoot.fontSize
        color: Theme.textPrimary
        selectionColor: "transparent"
        selectedTextColor: Theme.textPrimary
        wrapMode: TextArea.Wrap
        selectByMouse: true

        background: Item {
            SelectionHighlightOverlay {
                editorArea: transTextArea
            }

            Rectangle {
                id: currentLineHighlight
                visible: transTextArea.activeFocus && transTextArea.cursorRectangle.height > 0 && (transTextArea.selectionStart === transTextArea.selectionEnd)
                x: 0
                width: parent.width
                y: transTextArea.cursorRectangle.y
                height: transTextArea.cursorRectangle.height
                color: Theme.lineHighlight
                radius: 3
            }
        }

        Keys.onUpPressed: (event) => {
            let firstLineEnd = text.indexOf("\n")
            let isFirstLine = (firstLineEnd === -1) ? true : (cursorPosition <= firstLineEnd)
            if (isFirstLine) {
                transclusionRoot.requestPreviousSegment()
                event.accepted = true
                return
            }
            event.accepted = false
        }

        Keys.onDownPressed: (event) => {
            let lastLineStart = text.lastIndexOf("\n")
            let isLastLine = (lastLineStart === -1) ? true : (cursorPosition > lastLineStart)
            if (isLastLine) {
                transclusionRoot.requestNextSegment()
                event.accepted = true
                return
            }
            event.accepted = false
        }

        Keys.onReturnPressed: (event) => {
            let firstLineEnd = text.indexOf("\n")
            let isHeaderLine = (firstLineEnd === -1) ? true : (cursorPosition <= firstLineEnd)
            if (event.modifiers & Qt.ControlModifier) {
                if (isHeaderLine) {
                    transclusionRoot.openTarget(transclusionRoot.targetFile, transclusionRoot.targetBlock)
                    event.accepted = true
                    return
                }
                if (transclusionRoot.tryOpenLink(text, cursorPosition)) {
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
                    let pos = transTextArea.positionAt(mouse.x, mouse.y)
                    let firstLineEnd = transTextArea.text.indexOf("\n")
                    let isHeaderLine = (firstLineEnd === -1) ? true : (pos <= firstLineEnd)
                    if (isHeaderLine) {
                        transclusionRoot.openTarget(transclusionRoot.targetFile, transclusionRoot.targetBlock)
                        mouse.accepted = true
                        return
                    }
                    if (transclusionRoot.tryOpenLink(transTextArea.text, pos)) {
                        mouse.accepted = true
                        return
                    }
                }
                mouse.accepted = false
            }
        }

        onActiveFocusChanged: {
            if (activeFocus) {
                transclusionRoot.activated()
            }
        }

        onCursorPositionChanged: {
            if (backendInstance && typeof backendInstance.update_highlighter_cursor === "function") {
                backendInstance.update_highlighter_cursor(transTextArea, cursorPosition)
            }
        }

        onTextChanged: {
            Qt.callLater(transclusionRoot.applyLineHeight)
        }
    }
}
