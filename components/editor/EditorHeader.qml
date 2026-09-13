import QtQuick
import QtQuick.Layouts
import "../theme"

Item {
    id: headerRoot
    height: 70
    z: 20

    property string fileName: ""
    property string fileUrl: ""
    property bool isSplitMode: false
    property bool isActivePane: false
    property bool isEmpty: false
    property bool isPinned: false
    property bool isGraphMode: false
    property string folderName: ""
    property real scrollY: 0
    property real contentLeftPadding: 0
    property real contentRightPadding: 0

    property alias titleField: docHeader.titleField

    signal titleCommitted(string newTitle)
    signal paneActivated()
    signal pinToggled()

    function stripExt(name) {
        if (!name) return ""
        return name.replace(/\.md$/i, "")
    }

    y: isPinned ? Math.max(0, scrollY) : 0

    Rectangle {
        anchors.fill: parent
        color: Theme.bgHeader
        visible: headerRoot.isPinned && (headerRoot.scrollY > 0)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        DocumentHeader {
            id: docHeader
            visible: !headerRoot.isGraphMode
            fileName: headerRoot.fileName
            fileUrl: headerRoot.fileUrl
            isSplitMode: headerRoot.isSplitMode
            isActivePane: headerRoot.isActivePane
            isEmpty: headerRoot.isEmpty
            contentLeftPadding: headerRoot.contentLeftPadding
            contentRightPadding: headerRoot.contentRightPadding

            onTitleCommitted: (newTitle) => headerRoot.titleCommitted(newTitle)
            onPaneActivated: headerRoot.paneActivated()
        }

        // Строка заголовка в режиме графа на листе
        RowLayout {
            id: graphHeaderRow
            visible: headerRoot.isGraphMode
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.topMargin: 12
            Layout.leftMargin: 36
            Layout.rightMargin: 36
            Layout.preferredHeight: 44
            Layout.maximumHeight: 44
            Layout.minimumHeight: 44
            spacing: 8

            Text {
                text: "🕸 " + (headerRoot.fileName ? headerRoot.stripExt(headerRoot.fileName) : "Граф связей")
                font.pixelSize: 17
                font.bold: true
                color: Theme.textPrimary
                elide: Text.ElideRight
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                Layout.fillWidth: true
            }
        }

        // Верхняя разделительная линия (клик = закрепить/открепить)
        Item {
            id: headerDividerArea
            Layout.fillWidth: true
            Layout.preferredHeight: 14
            Layout.maximumHeight: 14
            Layout.leftMargin: 36
            Layout.rightMargin: 36

            Rectangle {
                id: headerDividerLine
                anchors.centerIn: parent
                width: parent.width
                height: 2
                radius: 1
                color: (headerRoot.isPinned || headerRoot.isGraphMode)
                    ? (headerDividerMouse.containsMouse ? Theme.textSecondary : Theme.textMuted)
                    : (headerDividerMouse.containsMouse ? Theme.borderHover : Theme.borderColor)
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            MouseArea {
                id: headerDividerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: headerRoot.isGraphMode ? Qt.ArrowCursor : Qt.PointingHandCursor
                onClicked: {
                    if (!headerRoot.isGraphMode) {
                        headerRoot.pinToggled()
                    }
                }
            }
        }
    }
}
