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
    property real availableHeight: 600
    property real viewHeight: availableHeight

    // Исходный текст документа
    property string sourceText: ""

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
        parseDocument()
    }

    Component.onCompleted: {
        parseDocument()
    }

    function notifySegmentChanged(index, newContent) {
        if (index >= 0 && index < liveSheetRoot.segments.length) {
            liveSheetRoot.segments[index].content = newContent
            let updatedText = Segmenter.rebuildFullText(liveSheetRoot.segments)
            liveSheetRoot.textChangedByUser(updatedText)
        }
    }

    Column {
        id: contentColumn
        anchors.top: parent.top
        anchors.topMargin: liveSheetRoot.contentTopMargin
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: liveSheetRoot.barSize
        anchors.rightMargin: liveSheetRoot.barSize
        spacing: 12

        Repeater {
            model: liveSheetRoot.segments

            delegate: Item {
                width: contentColumn.width
                height: itemLoader.item ? itemLoader.item.height : 0

                Loader {
                    id: itemLoader
                    width: parent.width
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
                        isFolded: modelData.isFolded || false
                        onBlockContentEdited: (newContent) => liveSheetRoot.notifySegmentChanged(index, newContent)
                        onActivated: liveSheetRoot.paneActivated()
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
                        onTextContentEdited: (newContent) => liveSheetRoot.notifySegmentChanged(index, newContent)
                        onActivated: liveSheetRoot.paneActivated()
                    }
                }
            }
        }
    }
}
