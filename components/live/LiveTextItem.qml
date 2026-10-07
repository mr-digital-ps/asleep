import QtQuick
import QtQuick.Controls.Basic
import "../theme"

Item {
    id: textItemRoot

    property string content: ""
    property alias text: textInputArea.text
    property bool isFocused: textInputArea.activeFocus

    signal textContentEdited(string newContent)
    signal activated()

    width: parent ? parent.width : Theme.defaultSheetWidth
    height: textInputArea.implicitHeight + 4

    TextArea {
        id: textInputArea
        width: parent.width
        leftPadding: 4
        rightPadding: 4
        topPadding: 2
        bottomPadding: 2

        text: textItemRoot.content
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
                textItemRoot.activated()
            }
        }

        onTextChanged: {
            if (text !== textItemRoot.content) {
                textItemRoot.content = text
                textItemRoot.textContentEdited(text)
            }
        }
    }
}
