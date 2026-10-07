import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: blockItemRoot

    property string blockName: ""
    property string blockContent: ""
    property bool isFolded: false
    property bool isFocused: blockTextArea.activeFocus

    signal blockContentEdited(string newContent)
    signal foldToggled()
    signal activated()

    width: parent ? parent.width : Theme.defaultSheetWidth
    height: isFolded ? headerRow.height + 12 : (headerRow.height + blockContentArea.height + 18)

    color: Theme.bgHover
    border.color: isFocused ? Theme.borderFocus : Theme.borderColor
    border.width: 1
    radius: 6

    Behavior on border.color { ColorAnimation { duration: Theme.animDurationNormal } }
    Behavior on height { NumberAnimation { duration: Theme.animDurationNormal } }

    Column {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 4

        // Заголовок блока и контрол сворачивания
        RowLayout {
            id: headerRow
            width: parent.width
            height: 24
            spacing: 6

            // Иконка/кнопка сворачивания
            Rectangle {
                width: 18
                height: 18
                radius: 3
                color: foldBtnMouse.containsMouse ? Theme.bgActive : "transparent"
                Layout.alignment: Qt.AlignVCenter

                Text {
                    anchors.centerIn: parent
                    text: blockItemRoot.isFolded ? "▸" : "▾"
                    color: Theme.textSecondary
                    font.pixelSize: 11
                }

                MouseArea {
                    id: foldBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        blockItemRoot.isFolded = !blockItemRoot.isFolded
                        blockItemRoot.foldToggled()
                    }
                }
            }

            // Метка имени блока (без синтаксического шума фигурных скобок)
            Text {
                text: blockItemRoot.blockName
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.bold: true
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                elide: Text.ElideRight
            }

            // Индикатор типа блока (бейдж)
            Rectangle {
                implicitWidth: badgeText.implicitWidth + 8
                implicitHeight: 16
                radius: 3
                color: Theme.bgPaper
                border.color: Theme.borderColor
                border.width: 1
                Layout.alignment: Qt.AlignVCenter

                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: "блок"
                    color: Theme.textMuted
                    font.pixelSize: 10
                }
            }
        }

        // Содержимое блока (редактируемое при развернутом состоянии)
        Item {
            id: blockContentArea
            width: parent.width
            height: isFolded ? 0 : blockTextArea.implicitHeight
            visible: !blockItemRoot.isFolded
            clip: true

            TextArea {
                id: blockTextArea
                width: parent.width
                leftPadding: 6
                rightPadding: 6
                topPadding: 4
                bottomPadding: 4

                text: blockItemRoot.blockContent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.defaultFontSize
                color: Theme.textPrimary
                selectionColor: Theme.selectionColor
                selectedTextColor: Theme.textSelected
                wrapMode: TextArea.Wrap
                selectByMouse: true
                background: null

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
                }
            }
        }
    }
}
