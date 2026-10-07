import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: blockItemRoot

    property string blockName: ""
    property string blockContent: ""
    property int fontSize: Theme.defaultFontSize
    property bool showLineDots: true
    property real lineHeightPercent: Theme.defaultLineHeightPercent
    property var backendInstance: null
    property bool isFocused: blockTextArea.activeFocus || blockNameInput.activeFocus

    signal blockNameEdited(string newName)
    signal blockContentEdited(string newContent)
    signal activated()
    signal requestPreviousSegment()
    signal requestNextSegment()
    signal openWikiLinkRequested(string target)

    function tryOpenLink(txt, pos) {
        if (!txt) return false
        // Ищем вхождение [[заметка]] в окрестности позиции курсора
        let re = /\[\[([^\]|]+)(?:\|[^\]]+)?\]\]/g
        let match
        while ((match = re.exec(txt)) !== null) {
            if (pos >= match.index && pos <= match.index + match[0].length) {
                blockItemRoot.openWikiLinkRequested(match[1].trim())
                return true
            }
        }
        return false
    }

    function focusTop() {
        blockNameInput.forceActiveFocus()
        blockNameInput.cursorPosition = 0
    }

    function focusBottom() {
        blockTextArea.forceActiveFocus()
        blockTextArea.cursorPosition = blockTextArea.text.length
    }

    width: parent ? parent.width : Theme.defaultSheetWidth
    readonly property bool isEmptyBlock: blockItemRoot.blockContent.length === 0 && !blockTextArea.activeFocus
    height: contentCol.height + (isEmptyBlock ? 8 : 12)

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

    color: Theme.bgHover
    radius: 6

    // Точка строки в гаттере слева — строго по центру заголовка блока
    Rectangle {
        visible: blockItemRoot.showLineDots
        x: -Theme.barSize / 2 - width / 2
        y: contentCol.y + blockNameInput.y + Math.round((blockNameInput.height - height) / 2)
        width: 4
        height: 4
        radius: 2
        color: Theme.gutterText
    }

    Column {
        id: contentCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: blockItemRoot.isEmptyBlock ? 4 : 6
        spacing: blockItemRoot.isEmptyBlock ? 0 : 4

        // Редактируемый заголовок блока
        TextInput {
            id: blockNameInput
            width: parent.width
            text: blockItemRoot.blockName
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: blockItemRoot.fontSize
            font.bold: false
            selectionColor: Theme.selectionColor
            selectedTextColor: Theme.textSelected
            selectByMouse: true

            onActiveFocusChanged: {
                if (activeFocus) blockItemRoot.activated()
            }

            onTextChanged: {
                if (text !== blockItemRoot.blockName) {
                    blockItemRoot.blockName = text
                    blockItemRoot.blockNameEdited(text)
                }
            }

            Keys.onUpPressed: (event) => {
                blockItemRoot.requestPreviousSegment()
                event.accepted = true
            }

            Keys.onDownPressed: (event) => {
                blockTextArea.forceActiveFocus()
                blockTextArea.cursorPosition = 0
                event.accepted = true
            }

            Keys.onReturnPressed: (event) => {
                blockTextArea.forceActiveFocus()
                blockTextArea.cursorPosition = 0
                event.accepted = true
            }
        }

        // Содержимое блока (на том же уровне, padding 0)
        TextArea {
            id: blockTextArea
            width: parent.width
            visible: blockItemRoot.blockContent.length > 0 || blockTextArea.activeFocus
            leftPadding: 0
            rightPadding: 0
            topPadding: 0
            bottomPadding: 0

            text: blockItemRoot.blockContent
            font.family: Theme.fontFamily
            font.pixelSize: blockItemRoot.fontSize
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
                    blockNameInput.forceActiveFocus()
                    blockNameInput.cursorPosition = blockNameInput.text.length
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

            TapHandler {
                acceptedModifiers: Qt.ControlModifier
                onTapped: (point) => {
                    let pos = blockTextArea.positionAt(point.position.x, point.position.y)
                    blockItemRoot.tryOpenLink(blockTextArea.text, pos)
                }
            }

            onActiveFocusChanged: {
                if (activeFocus) {
                    blockItemRoot.activated()
                }
            }

            onTextChanged: {
                if (text !== blockItemRoot.blockContent) {
                    blockItemRoot.blockContent = text
                    blockItemRoot.blockContentEdited(text)
                }
                Qt.callLater(blockItemRoot.applyLineHeight)
            }

            onCursorPositionChanged: {
                if (backendInstance && typeof backendInstance.update_highlighter_cursor === "function") {
                    backendInstance.update_highlighter_cursor(blockTextArea, cursorPosition)
                }
            }

            Component.onCompleted: {
                Qt.callLater(blockItemRoot.applyLineHeight)
                Qt.callLater(blockItemRoot.attachHighlighter)
            }
        }
    }
}

