import QtQuick
import QtQuick.Controls.Basic
import "../theme"
import "../editor"

Rectangle {
    id: blockItemRoot
    color: "transparent"

    property string blockName: ""
    property string blockContent: ""
    property bool isSingleLine: false
    property int fontSize: Theme.defaultFontSize
    property bool showLineDots: true
    property real lineHeightPercent: Theme.defaultLineHeightPercent
    readonly property real effectiveLineHeight: Math.round(fontSize * (lineHeightPercent / 100.0))
    property var backendInstance: null
    property bool isFocused: blockTextArea.activeFocus
    property bool _updatingTextInternally: false

    signal blockNameEdited(string newName)
    signal blockContentEdited(string newContent)
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
        blockTextArea.forceActiveFocus()
        blockTextArea.cursorPosition = 0
    }

    function focusBottom() {
        blockTextArea.forceActiveFocus()
        blockTextArea.cursorPosition = blockTextArea.text.length
    }

    function focusAtPos(pos) {
        blockTextArea.forceActiveFocus()
        blockTextArea.cursorPosition = Math.min(Math.max(0, pos), blockTextArea.text.length)
    }

    function getCursorPos() {
        return blockTextArea.cursorPosition
    }

    function syncTextFromProperties() {
        if (blockItemRoot._updatingTextInternally) return
        blockItemRoot._updatingTextInternally = true
        let expected = ""
        if (blockItemRoot.isSingleLine) {
            expected = blockItemRoot.blockName || ""
            if (blockItemRoot.blockContent && blockItemRoot.blockContent.length > 0) {
                expected = expected.length > 0 ? (expected + " " + blockItemRoot.blockContent.trim()) : blockItemRoot.blockContent.trim()
            }
        } else {
            expected = blockItemRoot.blockName || ""
            if (blockItemRoot.blockContent !== undefined && blockItemRoot.blockContent !== null) {
                expected += "\n" + blockItemRoot.blockContent
            }
        }
        if (blockTextArea.text !== expected) {
            blockTextArea.text = expected
        }
        blockItemRoot._updatingTextInternally = false
    }

    onBlockNameChanged: syncTextFromProperties()
    onBlockContentChanged: syncTextFromProperties()
    onIsSingleLineChanged: syncTextFromProperties()

    width: parent ? parent.width : Theme.defaultSheetWidth
    property bool isFolded: false

    readonly property real scaleFactor: Math.max(0.6, Math.min(2.5, blockItemRoot.fontSize / 15.0))
    readonly property real dotDiameter: Math.round(6.0 * scaleFactor)
    readonly property real borderWidth: Math.max(1.5, Math.round(2.0 * scaleFactor))
    readonly property bool hasHeader: (blockItemRoot.blockName && blockItemRoot.blockName.trim().length > 0)

    // Вычисляем вертикальный центр первой строки (где находится заголовок и точка в гаттере)
    readonly property real headerDotCenterY: {
        let rect = blockTextArea.positionToRectangle(0)
        return Math.round(rect.y + (rect.height / 2))
    }

    // Типографические границы блока:
    // Верх линии: высота заглавной буквы строки заголовка (где открывается {)
    readonly property real headerTopY: {
        let rect = blockTextArea.positionToRectangle(0)
        return Math.round(rect.y + 2)
    }

    // Низ линии: нижняя граница свисающих элементов букв (р, у, g, }) последней строки
    readonly property real lastLineBottomY: {
        let txt = blockTextArea.text || ""
        let pos = txt.length
        let rect = blockTextArea.positionToRectangle(pos)
        // Если последняя позиция дает нулевую высоту или некорректную, берем максимум
        let h = (rect.height > 0) ? rect.height : blockItemRoot.effectiveLineHeight
        return Math.round(rect.y + h - 2)
    }

    // Высота первой строки для сложенного состояния
    readonly property real firstLineHeight: {
        let rect = blockTextArea.positionToRectangle(0)
        return Math.max(blockItemRoot.effectiveLineHeight, rect.height)
    }

    height: blockItemRoot.isFolded ? Math.round(blockItemRoot.firstLineHeight) : Math.round(blockTextArea.implicitHeight + blockTextArea.topPadding + blockTextArea.bottomPadding)


    property alias text: blockTextArea.text

    // Элегантная вертикальная направляющая линия блока по оси гаттера (dot line)
    // Начинается строго от центра точки заголовка (визуально объединена с точкой) и заканчивается на уровне свисающих букв последней строки
    // Цвет совпадает с обычными точками гаттера (Theme.gutterText), а при фокусе курсора внутри блока светится Theme.gutterActive
    Rectangle {
        id: leftBlockBorder
        visible: blockItemRoot.showLineDots && !blockItemRoot.isFolded
        x: Math.round(-Theme.barSize / 2 - width / 2)
        y: Math.round(blockItemRoot.headerDotCenterY)
        height: Math.max(0, Math.round(blockItemRoot.lastLineBottomY - y))
        width: blockItemRoot.borderWidth
        color: blockItemRoot.isFocused ? Theme.gutterActive : Theme.gutterText
        z: 1

        MouseArea {
            anchors.fill: parent
            anchors.leftMargin: -6
            anchors.rightMargin: -6
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: {
                blockItemRoot.isFolded = !blockItemRoot.isFolded
            }
        }
    }

    // Точка-маркер (Node Dot): отображается на оси линии
    // В развернутом виде: цвет совпадает с линией (Theme.gutterActive при фокусе, иначе Theme.gutterText)
    // В свернутом виде: превращается в обычную точку гаттера (Theme.gutterActive), клик по которой заново раскрывает блок
    Rectangle {
        id: headerNodeDot
        visible: blockItemRoot.showLineDots && (blockItemRoot.hasHeader || blockItemRoot.isFolded)
        readonly property real normalDotSize: Math.round(5.0 * blockItemRoot.scaleFactor)
        x: Math.round(-Theme.barSize / 2 - width / 2)
        y: Math.round(blockItemRoot.headerDotCenterY - height / 2)
        width: blockItemRoot.isFolded ? normalDotSize : blockItemRoot.dotDiameter
        height: width
        radius: width / 2
        readonly property bool isHeaderActiveLine: {
            if (!blockTextArea.activeFocus) return false
            let firstLineEnd = (blockTextArea.text || "").indexOf("\n")
            let endPos = (firstLineEnd === -1) ? (blockTextArea.text || "").length : firstLineEnd
            return blockTextArea.cursorPosition <= endPos
        }
        color: (blockItemRoot.isFolded || blockItemRoot.isFocused) ? Theme.gutterActive : Theme.gutterText
        z: 2

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: {
                blockItemRoot.isFolded = !blockItemRoot.isFolded
            }
        }
    }





    function applyLineHeight() {
        if (backendInstance && typeof backendInstance.set_editor_line_height === "function") {
            backendInstance.set_editor_line_height(blockTextArea, lineHeightPercent)
        }
    }

    function attachHighlighter() {
        if (backendInstance && typeof backendInstance.attach_highlighter === "function") {
            backendInstance.attach_highlighter(blockTextArea)
        }
    }

    onLineHeightPercentChanged: applyLineHeight()
    onBackendInstanceChanged: {
        applyLineHeight()
        attachHighlighter()
    }

    TextArea {
        id: blockTextArea
        anchors.fill: parent
        clip: blockItemRoot.isFolded
        leftPadding: 0
        rightPadding: 0
        topPadding: 0
        bottomPadding: 0



        font.family: Theme.fontFamily
        font.pixelSize: blockItemRoot.fontSize
        color: Theme.textPrimary
        selectionColor: "transparent"
        selectedTextColor: Theme.textPrimary
        wrapMode: TextArea.Wrap
        selectByMouse: true
        background: Item {
            SelectionHighlightOverlay {
                editorArea: blockTextArea
            }

            Rectangle {
                id: currentLineHighlight
                visible: blockTextArea.activeFocus && blockTextArea.cursorRectangle.height > 0 && (blockTextArea.selectionStart === blockTextArea.selectionEnd)
                x: 0
                width: parent.width
                y: blockTextArea.cursorRectangle.y
                height: blockTextArea.cursorRectangle.height
                color: Theme.lineHighlight
                radius: 3
            }
        }

        Keys.onUpPressed: (event) => {
            let firstLineEnd = text.indexOf("\n")
            let isFirstLine = (firstLineEnd === -1) ? true : (cursorPosition <= firstLineEnd)
            if (isFirstLine) {
                blockItemRoot.requestPreviousSegment()
                event.accepted = true
                return
            }
            event.accepted = false
        }

        Keys.onDownPressed: (event) => {
            let lastLineStart = text.lastIndexOf("\n")
            let isLastLine = (lastLineStart === -1) ? true : (cursorPosition > lastLineStart)
            if (isLastLine) {
                blockItemRoot.requestNextSegment()
                event.accepted = true
                return
            }
            event.accepted = false
        }

        Keys.onReturnPressed: (event) => {
            if (event.modifiers & Qt.ControlModifier) {
                if (blockItemRoot.tryOpenLink(text, cursorPosition)) {
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
                    let pos = blockTextArea.positionAt(mouse.x, mouse.y)
                    if (blockItemRoot.tryOpenLink(blockTextArea.text, pos)) {
                        mouse.accepted = true
                        return
                    }
                }
                mouse.accepted = false
            }
        }

        onActiveFocusChanged: {
            if (activeFocus) {
                blockItemRoot.activated()
            }
        }

        onTextChanged: {
            if (blockItemRoot._updatingTextInternally) return
            blockItemRoot._updatingTextInternally = true

            if (blockItemRoot.isSingleLine) {
                if (text !== blockItemRoot.blockName) {
                    blockItemRoot.blockName = text
                    blockItemRoot.blockContent = ""
                    blockItemRoot.blockNameEdited(text)
                    blockItemRoot.blockContentEdited("")
                }
            } else {
                let lines = text.split("\n")
                let newName = lines[0] || ""
                let newContent = lines.slice(1).join("\n")
                if (newName !== blockItemRoot.blockName) {
                    blockItemRoot.blockName = newName
                    blockItemRoot.blockNameEdited(newName)
                }
                if (newContent !== blockItemRoot.blockContent) {
                    blockItemRoot.blockContent = newContent
                    blockItemRoot.blockContentEdited(newContent)
                }
            }

            blockItemRoot._updatingTextInternally = false
            Qt.callLater(blockItemRoot.applyLineHeight)
        }

        onCursorPositionChanged: {
            if (backendInstance && typeof backendInstance.update_highlighter_cursor === "function") {
                backendInstance.update_highlighter_cursor(blockTextArea, cursorPosition)
            }
        }

        Component.onCompleted: {
            blockItemRoot.syncTextFromProperties()
            Qt.callLater(blockItemRoot.applyLineHeight)
            Qt.callLater(blockItemRoot.attachHighlighter)
        }
    }
}
