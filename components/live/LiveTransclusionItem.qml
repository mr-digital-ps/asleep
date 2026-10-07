import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: transclusionRoot

    property string targetFile: ""
    property string targetBlock: ""
    property string transcludedContent: ""
    property bool isLoading: false
    property bool isNotFound: false

    signal activated()
    signal openTargetRequested(string fileUrl, string blockName)

    width: parent ? parent.width : Theme.defaultSheetWidth
    height: contentColumn.height + 14

    color: Qt.rgba(Theme.bgHover.r, Theme.bgHover.g, Theme.bgHover.b, 0.4)
    border.color: Theme.borderColor
    border.width: 1
    radius: 6

    function resolveTransclusion() {
        if (!targetBlock || targetBlock.length === 0) return
        if (typeof backend === "undefined" || !backend) return

        if (typeof backend.get_block === "function") {
            let res = backend.get_block(targetBlock)
            if (res && res.found) {
                transcludedContent = res.content ? res.content.trim() : ""
                isNotFound = false
            } else {
                transcludedContent = "Блок не найден: " + (targetFile ? (targetFile + "." + targetBlock) : targetBlock)
                isNotFound = true
            }
        }
    }

    Component.onCompleted: resolveTransclusion()

    Connections {
        target: (typeof backend !== "undefined") ? backend : null
        function onBlockUpdated(headingNorm, content, sourceFileUrl) {
            if (headingNorm === transclusionRoot.targetBlock.toLowerCase()) {
                transclusionRoot.transcludedContent = content.trim()
                transclusionRoot.isNotFound = false
            }
        }
    }

    Column {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 7
        spacing: 4

        // Заголовок трансклюзии (источник)
        RowLayout {
            width: parent.width
            height: 20
            spacing: 6

            Text {
                text: "⎘"
                color: Theme.accentColor
                font.pixelSize: 12
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: transclusionRoot.targetFile ? (transclusionRoot.targetFile + "." + transclusionRoot.targetBlock + "()") : (transclusionRoot.targetBlock + "()")
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: 12
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                elide: Text.ElideRight
            }

            Rectangle {
                implicitWidth: transBadge.implicitWidth + 8
                implicitHeight: 16
                radius: 3
                color: Theme.bgPaper
                border.color: Theme.borderColor
                border.width: 1
                Layout.alignment: Qt.AlignVCenter

                Text {
                    id: transBadge
                    anchors.centerIn: parent
                    text: "трансклюзия"
                    color: Theme.textMuted
                    font.pixelSize: 10
                }
            }
        }

        // Тело содержимого трансклюзии
        Text {
            width: parent.width
            text: transclusionRoot.transcludedContent ? transclusionRoot.transcludedContent : "..."
            color: transclusionRoot.isNotFound ? Theme.textMuted : Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.defaultFontSize
            font.italic: transclusionRoot.isNotFound
            wrapMode: Text.Wrap
            leftPadding: 4
            rightPadding: 4
            topPadding: 2
            bottomPadding: 2
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            transclusionRoot.activated()
            transclusionRoot.openTargetRequested(transclusionRoot.targetFile, transclusionRoot.targetBlock)
        }
    }
}
