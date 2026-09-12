import QtQuick
import QtQuick.Layouts

Item {
    id: footerRoot
    height: 70

    property bool isPinned: false
    property string statsText: ""
    property bool showBackground: true

    signal pinToggled()
    signal activated()

    Rectangle {
        anchors.fill: parent
        color: "#181818"
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
            Layout.leftMargin: 36
            Layout.rightMargin: 36

            Rectangle {
                id: footerDividerLine
                anchors.centerIn: parent
                width: parent.width
                height: 2
                radius: 1
                color: footerRoot.isPinned
                    ? (footerDividerMouse.containsMouse ? "#888888" : "#666666")
                    : (footerDividerMouse.containsMouse ? "#4a4a4a" : "#3a3a3a")
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            MouseArea {
                id: footerDividerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    footerRoot.pinToggled()
                    footerRoot.activated()
                }
            }
        }

        // Информационная строка со статистикой (слова, знаки)
        RowLayout {
            id: statsRow
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 36
            Layout.rightMargin: 36
            Layout.bottomMargin: 12
            spacing: 12

            Text {
                id: docStatsText
                Layout.alignment: Qt.AlignVCenter
                font.pixelSize: 12
                color: "#666666"
                text: footerRoot.statsText
            }

            Item { Layout.fillWidth: true }
        }
    }
}
