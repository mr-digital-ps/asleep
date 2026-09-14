import QtQuick
import QtQuick.Layouts
import "../theme"

Item {
    id: footerRoot
    height: 70

    property bool isPinned: false
    property bool isGraphMode: false
    property string statsText: ""
    property bool showBackground: true
    property int barSize: 36

    signal pinToggled()
    signal activated()

    Rectangle {
        anchors.fill: parent
        color: Theme.bgFooter
        visible: footerRoot.showBackground
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onPressed: footerRoot.activated()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Разделительная линия (клик = переключить закрепление)
        Item {
            id: footerDividerArea
            Layout.fillWidth: true
            Layout.preferredHeight: 14
            Layout.maximumHeight: 14
            Layout.leftMargin: footerRoot.barSize
            Layout.rightMargin: footerRoot.barSize

            Rectangle {
                id: footerDividerLine
                anchors.centerIn: parent
                width: parent.width
                height: 2
                radius: 1
                color: (footerRoot.isPinned || footerRoot.isGraphMode)
                    ? (footerDividerMouse.containsMouse ? Theme.textSecondary : Theme.textMuted)
                    : (footerDividerMouse.containsMouse ? Theme.borderHover : Theme.borderColor)
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            MouseArea {
                id: footerDividerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: footerRoot.isGraphMode ? Qt.ArrowCursor : Qt.PointingHandCursor
                onClicked: {
                    if (!footerRoot.isGraphMode) {
                        footerRoot.pinToggled()
                        footerRoot.activated()
                    }
                }
            }
        }

        // Информационная строка со статистикой (слова, знаки)
        RowLayout {
            id: statsRow
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: footerRoot.barSize
            Layout.rightMargin: footerRoot.barSize
            Layout.bottomMargin: 12
            spacing: 12

            Text {
                id: docStatsText
                Layout.alignment: Qt.AlignVCenter
                font.pixelSize: 12
                color: Theme.textSecondary
                text: footerRoot.statsText
            }

            Item { Layout.fillWidth: true }
        }
    }
}
