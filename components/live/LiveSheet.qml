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

    signal textChangedByUser(string fullText)
    signal paneActivated()
    signal nodeSelected(string fileUrl, string label, string nodeType)

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

    function openWikiLink(targetName) {
        if (!targetName) return
        var clean = targetName.trim()
        var fUrl = ""
        if (backendInstance && typeof backendInstance.get_note_file_url === "function") {
            fUrl = backendInstance.get_note_file_url(clean, liveSheetRoot.folderUrl)
        }
        liveSheetRoot.nodeSelected(fUrl, clean, "file")
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

    function focusFirstOrCurrent(targetCharPos) {
        if (!liveSheetRoot.segments || liveSheetRoot.segments.length === 0) return
        let charAcc = 0
        let targetIdx = 0
        for (let i = 0; i < liveSheetRoot.segments.length; i++) {
            let segLen = (liveSheetRoot.segments[i].content ? liveSheetRoot.segments[i].content.length : 0) + 1
            if (targetCharPos <= charAcc + segLen) {
                targetIdx = i
                break
            }
            charAcc += segLen
        }
        let item = repeater.itemAt(targetIdx)
        if (item && item.focusTop) {
            item.focusTop()
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
                // Добавляем аккуратный отступ сверху и снизу для блочного текста (10px), чтобы отделить от обычных строк
                height: (itemLoader.item ? itemLoader.item.height : 0) + (modelData.type === "block" ? 10 : 0)

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

                Loader {
                    id: itemLoader
                    width: parent.width
                    y: (modelData.type === "block") ? 4 : 0
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
                        fontSize: liveSheetRoot.editorFontSize
                        showLineDots: liveSheetRoot.showLineDots
                        lineHeightPercent: liveSheetRoot.lineHeightPercent
                        backendInstance: liveSheetRoot.backendInstance
                        onBlockNameEdited: (newName) => liveSheetRoot.notifyBlockNameChanged(index, newName)
                        onBlockContentEdited: (newContent) => liveSheetRoot.notifySegmentChanged(index, newContent)
                        onActivated: liveSheetRoot.paneActivated()
                        onRequestPreviousSegment: () => liveSheetRoot.focusPreviousSegment(index)
                        onRequestNextSegment: () => liveSheetRoot.focusNextSegment(index)
                        onOpenWikiLinkRequested: (target) => liveSheetRoot.openWikiLink(target)
                    }
                }

                Component {
                    id: transclusionComp
                    LiveTransclusionItem {
                        width: parent.width
                        targetFile: modelData.targetFile
                        targetBlock: modelData.targetBlock
                        onActivated: liveSheetRoot.paneActivated()
                        onOpenTargetRequested: (fUrl, bName) => {
                            liveSheetRoot.nodeSelected(fUrl, bName, "block")
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
                        onOpenWikiLinkRequested: (target) => liveSheetRoot.openWikiLink(target)
                    }
                }
            }
        }
    }
}
