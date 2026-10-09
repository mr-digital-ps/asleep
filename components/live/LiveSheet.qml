import QtQuick
import QtQuick.Controls.Basic
import "../theme"
import "./live_segmenter.js" as Segmenter

Rectangle {
    id: liveSheetRoot

    property int barSize: 36
    property string fileName: "Новый документ"
    property string fileUrl: ""
    property string folderUrl: ""
    property bool isCenteredMode: true
    property real customSheetWidth: 800
    property real minSheetWidth: 380
    property bool isSplitMode: false
    property bool isActivePane: false
    property bool isEmpty: false
    property bool isHeaderPinned: false
    property bool showHeader: true
    property bool showLineDots: true
    property int editorFontSize: Theme.defaultFontSize
    property real lineHeightPercent: Theme.defaultLineHeightPercent
    readonly property real effectiveLineHeight: editorFontSize * (lineHeightPercent / 100.0)
    property var backendInstance: null
    property real availableHeight: 600
    property real viewHeight: availableHeight

    // Исходный текст документа
    property string sourceText: ""
    property bool _isInternalUpdate: false

    // Модель сегментов
    property var segments: []
    property string activeBlockName: ""

    signal textChangedByUser(string fullText)
    signal paneActivated()

    color: Theme.bgPaper

    width: isCenteredMode ? Math.min(parent ? parent.width : 800, Math.max(minSheetWidth, customSheetWidth)) : (parent ? parent.width : 800)
    height: Math.max(liveSheetRoot.viewHeight, contentColumn.height + contentTopMargin + Theme.sheetPadding)

    readonly property real contentTopMargin: liveSheetRoot.showHeader ? Theme.headerHeight : Theme.sheetPadding

    function parseDocument() {
        liveSheetRoot.segments = Segmenter.parseLiveSegments(liveSheetRoot.sourceText)
    }

    onSourceTextChanged: {
        if (!liveSheetRoot._isInternalUpdate) {
            parseDocument()
        }
    }

    Component.onCompleted: {
        parseDocument()
    }

    function notifySegmentChanged(index, newContent) {
        if (index >= 0 && index < liveSheetRoot.segments.length) {
            liveSheetRoot.segments[index].content = newContent
            let updatedText = Segmenter.rebuildFullText(liveSheetRoot.segments)
            liveSheetRoot._isInternalUpdate = true
            liveSheetRoot.sourceText = updatedText
            liveSheetRoot.textChangedByUser(updatedText)
            liveSheetRoot._isInternalUpdate = false
        }
    }

    function notifyBlockNameChanged(index, newName) {
        if (index >= 0 && index < liveSheetRoot.segments.length) {
            liveSheetRoot.segments[index].name = newName
            let updatedText = Segmenter.rebuildFullText(liveSheetRoot.segments)
            liveSheetRoot._isInternalUpdate = true
            liveSheetRoot.sourceText = updatedText
            liveSheetRoot.textChangedByUser(updatedText)
            liveSheetRoot._isInternalUpdate = false
        }
    }

    function focusPreviousSegment(currentIndex) {
        for (let i = currentIndex - 1; i >= 0; i--) {
            let item = repeater.itemAt(i)
            if (item && item.focusBottom) {
                item.focusBottom()
                return true
            }
        }
        return false
    }

    function focusNextSegment(currentIndex) {
        for (let i = currentIndex + 1; i < liveSheetRoot.segments.length; i++) {
            let item = repeater.itemAt(i)
            if (item && item.focusTop) {
                item.focusTop()
                return true
            }
        }
        return false
    }

    function scrollToBlock(blockName) {
        if (!blockName || !liveSheetRoot.segments) return
        var targetNorm = blockName.trim().toLowerCase()
        for (var i = 0; i < liveSheetRoot.segments.length; i++) {
            var seg = liveSheetRoot.segments[i]
            if (seg.type === "block" && (seg.name || "").trim().toLowerCase() === targetNorm) {
                var item = repeater.itemAt(i)
                if (item && typeof item.focusTop === "function") {
                    item.focusTop()
                    return true
                }
            }
        }
        return false
    }

    function getActiveDocumentCursor() {
        if (!liveSheetRoot.segments || liveSheetRoot.segments.length === 0) return -1
        let fullLines = (liveSheetRoot.sourceText || "").split(/\r?\n/)
        for (let i = 0; i < liveSheetRoot.segments.length; i++) {
            let item = repeater.itemAt(i)
            let seg = liveSheetRoot.segments[i]
            if (item && item.isFocused) {
                let innerPos = (typeof item.getCursorPos === "function") ? item.getCursorPos() : 0
                let sLine = Math.max(1, seg.sourceStartLine) - 1 // 0-indexed in fullLines
                let charOffset = 0
                for (let l = 0; l < sLine && l < fullLines.length; l++) {
                    charOffset += fullLines[l].length + 1
                }
                if (seg.type === "text") {
                    return charOffset + innerPos
                } else if (seg.type === "block") {
                    let innerText = item.text || ""
                    let beforeCursor = innerText.substring(0, innerPos)
                    let innerLinesBefore = beforeCursor.split("\n")
                    let lineInBlock = innerLinesBefore.length - 1
                    let colInLine = innerLinesBefore[lineInBlock].length
                    let targetSourceLine = sLine + lineInBlock
                    let sourceOffset = 0
                    for (let l = 0; l < targetSourceLine && l < fullLines.length; l++) {
                        sourceOffset += fullLines[l].length + 1
                    }
                    let lineMax = fullLines[targetSourceLine] ? fullLines[targetSourceLine].length : 0
                    return sourceOffset + Math.min(colInLine, lineMax)
                } else {
                    return charOffset
                }
            }
        }
        return -1
    }

    function focusFirstOrCurrent(targetCharPos) {
        if (!liveSheetRoot.segments || liveSheetRoot.segments.length === 0) return
        let fullLines = (liveSheetRoot.sourceText || "").split(/\r?\n/)
        let curLine = 0
        let col = 0
        let acc = 0
        for (let l = 0; l < fullLines.length; l++) {
            let lLen = fullLines[l].length + 1
            if (targetCharPos < acc + lLen || l === fullLines.length - 1) {
                curLine = l + 1 // 1-indexed
                col = Math.max(0, targetCharPos - acc)
                break
            }
            acc += lLen
        }

        // Ищем сегмент, содержащий curLine
        let targetIdx = 0
        for (let i = 0; i < liveSheetRoot.segments.length; i++) {
            let seg = liveSheetRoot.segments[i]
            if (curLine >= seg.sourceStartLine && curLine <= seg.sourceEndLine) {
                targetIdx = i
                break
            }
        }

        let item = repeater.itemAt(targetIdx)
        let seg = liveSheetRoot.segments[targetIdx]
        if (item && seg) {
            let lineInSeg = Math.max(0, curLine - seg.sourceStartLine)
            let itemText = item.text || ""
            if (!itemText && seg.type === "block") {
                itemText = (seg.name || "") + (seg.content ? ("\n" + seg.content) : "")
            } else if (!itemText && seg.type === "text") {
                itemText = seg.content || ""
            }
            let itemLines = itemText.split("\n")
            let relPos = 0
            for (let il = 0; il < lineInSeg && il < itemLines.length; il++) {
                relPos += itemLines[il].length + 1
            }
            let lineLen = (lineInSeg < itemLines.length && itemLines[lineInSeg]) ? itemLines[lineInSeg].length : 0
            relPos += Math.min(col, lineLen)

            if (typeof item.focusAtPos === "function") {
                item.focusAtPos(relPos)
            } else if (item.focusTop) {
                item.focusTop()
            }
        }
    }

    Column {
        id: contentColumn
        anchors.top: parent.top
        anchors.topMargin: liveSheetRoot.contentTopMargin + 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: liveSheetRoot.barSize
        anchors.rightMargin: liveSheetRoot.barSize
        spacing: 0

        Repeater {
            id: repeater
            model: liveSheetRoot.segments

            delegate: Item {
                id: segDelegate
                width: contentColumn.width
                // Естественная высота сегмента с сохранением единого межстрочного ритма (line_height)
                height: itemLoader.item ? itemLoader.item.height : 0

                function focusTop() {
                    if (itemLoader.item && typeof itemLoader.item.focusTop === "function") {
                        itemLoader.item.focusTop()
                    }
                }

                function focusBottom() {
                    if (itemLoader.item && typeof itemLoader.item.focusBottom === "function") {
                        itemLoader.item.focusBottom()
                    }
                }

                function focusAtPos(pos) {
                    if (itemLoader.item && typeof itemLoader.item.focusAtPos === "function") {
                        itemLoader.item.focusAtPos(pos)
                    } else if (itemLoader.item && typeof itemLoader.item.focusTop === "function") {
                        itemLoader.item.focusTop()
                    }
                }

                readonly property bool isFocused: itemLoader.item ? !!itemLoader.item.isFocused : false
                readonly property string text: itemLoader.item ? (itemLoader.item.text || "") : ""

                function getCursorPos() {
                    if (itemLoader.item && typeof itemLoader.item.getCursorPos === "function") {
                        return itemLoader.item.getCursorPos()
                    }
                    return 0
                }

                Loader {
                    id: itemLoader
                    width: parent.width
                    y: 0
                    sourceComponent: {
                        if (modelData.type === "block") return blockComp
                        if (modelData.type === "transclusion") return transclusionComp
                        if (modelData.type === "divider") return dividerComp
                        return textComp
                    }
                }

                Component {
                    id: blockComp
                    LiveBlockItem {
                        width: parent.width
                        blockName: modelData.name
                        blockContent: modelData.content
                        isSingleLine: !!modelData.isSingleLine
                        fontSize: liveSheetRoot.editorFontSize
                        showLineDots: liveSheetRoot.showLineDots
                        lineHeightPercent: liveSheetRoot.lineHeightPercent
                        backendInstance: liveSheetRoot.backendInstance
                        onBlockNameEdited: (newName) => liveSheetRoot.notifyBlockNameChanged(index, newName)
                        onBlockContentEdited: (newContent) => liveSheetRoot.notifySegmentChanged(index, newContent)
                        onActivated: liveSheetRoot.paneActivated()
                        onRequestPreviousSegment: () => liveSheetRoot.focusPreviousSegment(index)
                        onRequestNextSegment: () => liveSheetRoot.focusNextSegment(index)
                        onIsFocusedChanged: {
                            if (isFocused) {
                                liveSheetRoot.activeBlockName = modelData.name || "(безымянный)"
                            }
                        }
                    }
                }

                Component {
                    id: transclusionComp
                    LiveTransclusionItem {
                        width: parent.width
                        targetFile: modelData.targetFile
                        targetBlock: modelData.targetBlock
                        fontSize: liveSheetRoot.editorFontSize
                        showLineDots: liveSheetRoot.showLineDots
                        lineHeightPercent: liveSheetRoot.lineHeightPercent
                        backendInstance: liveSheetRoot.backendInstance
                        onActivated: liveSheetRoot.paneActivated()
                        onRequestPreviousSegment: () => liveSheetRoot.focusPreviousSegment(index)
                        onRequestNextSegment: () => liveSheetRoot.focusNextSegment(index)
                        onIsFocusedChanged: {
                            if (isFocused) {
                                liveSheetRoot.activeBlockName = (modelData.targetFile ? (modelData.targetFile + " › ") : "") + (modelData.targetBlock || "")
                            }
                        }
                    }
                }

                Component {
                    id: dividerComp
                    LiveDividerItem {
                        width: parent.width
                    }
                }

                Component {
                    id: textComp
                    LiveTextItem {
                        width: parent.width
                        content: modelData.content
                        fontSize: liveSheetRoot.editorFontSize
                        showLineDots: liveSheetRoot.showLineDots
                        lineHeightPercent: liveSheetRoot.lineHeightPercent
                        backendInstance: liveSheetRoot.backendInstance
                        onTextContentEdited: (newContent) => liveSheetRoot.notifySegmentChanged(index, newContent)
                        onActivated: liveSheetRoot.paneActivated()
                        onRequestPreviousSegment: () => liveSheetRoot.focusPreviousSegment(index)
                        onRequestNextSegment: () => liveSheetRoot.focusNextSegment(index)
                        onIsFocusedChanged: {
                            if (isFocused) {
                                liveSheetRoot.activeBlockName = ""
                            }
                        }
                    }
                }
            }
        }
    }
}
