import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "./markdown_shortcuts.js" as Markdown
import "./editor_keys.js" as EditorKeys
import "../theme"


RowLayout {
    id: canvasRoot
    spacing: 0

    property int barSize: 36
    property bool showLineDots: true
    property int tabSize: 4
    property string customFontFamily: "Segoe UI, Inter, -apple-system, sans-serif"
    property real availableHeight: 600
    property bool hasHeader: true
    property bool hasFooter: true

    property alias editorArea: editorArea
    property alias text: editorArea.text

    signal paneActivated()
    signal cursorVisibilityRequested()
    signal textChangedByUser()
    signal scrollRequested(real dy)
    signal scrollToTopRequested()
    signal fontSizeChanged(int newSize)
    signal closeRequested()
    signal detachRequested()
    signal syncNoticeRequested(string title)
    signal toggleHeaderFooterRequested()
    signal toggleFooterRequested()
    signal toggleHeaderRequested()
    signal toggleCenteredModeRequested()
    signal saveRequested()
    signal openRequested()
    signal openSplitRequested()
    signal newRequested()
    signal newSplitRequested()
    signal toggleGraphRequested()
    signal toggleSplitRequested()

    function updateBracketHighlights() {
        if (bracketHighlightOverlay) {
            bracketHighlightOverlay.updateBracketHighlights()
        }
    }

    Layout.preferredHeight: Math.max(availableHeight - ((canvasRoot.hasHeader ? 70 : 16) + (canvasRoot.hasFooter ? 70 : 16)), editorArea.implicitHeight)
    height: Math.max(availableHeight - ((canvasRoot.hasHeader ? 70 : 16) + (canvasRoot.hasFooter ? 70 : 16)), editorArea.implicitHeight)

    // Левая полоса 36px для нумерации строк и фокуса
    EditorGutter {
        id: editorGutter
        visible: canvasRoot.showLineDots
        barSize: canvasRoot.barSize
        editorArea: editorArea
        Layout.preferredWidth: visible ? barSize : 0
        Layout.fillHeight: true
        onActivated: canvasRoot.paneActivated()
    }

    // Текстовое поле документа
    TextArea {
        id: editorArea
        Layout.fillWidth: true
        Layout.fillHeight: true
        leftPadding: 0
        rightPadding: 0
        topPadding: 6
        bottomPadding: 0

        font.family: canvasRoot.customFontFamily
        font.pixelSize: 15
        wrapMode: TextArea.Wrap
        selectByMouse: true
        color: Theme.textPrimary
        selectionColor: Theme.selectionColor
        selectedTextColor: Theme.textSelected
        placeholderText: "Начните вводить текст..."
        placeholderTextColor: Theme.textMuted

        cursorDelegate: Item {
            id: cursorWrapper
            visible: editorArea.activeFocus
            Rectangle {
                id: customCursor
                width: 2
                height: parent.height
                anchors.centerIn: parent
                color: Theme.cursorColor
            }
        }

        background: Item {
            Rectangle {
                id: currentLineHighlight
                visible: editorArea.activeFocus && editorArea.cursorRectangle.height > 0 && (editorArea.selectionStart === editorArea.selectionEnd)
                x: 0
                width: parent.width
                y: editorArea.cursorRectangle.y
                height: editorArea.cursorRectangle.height
                color: Theme.lineHighlight
                radius: 3
            }

            // Оверлей подсветки парных скобок
            BracketHighlightOverlay {
                id: bracketHighlightOverlay
                editorArea: editorArea
            }
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                if (event.modifiers & Qt.ControlModifier) {
                    if (event.angleDelta.y > 0) {
                        editorArea.font.pixelSize = Math.min(36, editorArea.font.pixelSize + 1)
                    } else if (event.angleDelta.y < 0) {
                        editorArea.font.pixelSize = Math.max(10, editorArea.font.pixelSize - 1)
                    }
                    canvasRoot.fontSizeChanged(editorArea.font.pixelSize)
                    event.accepted = true
                } else {
                    let dy = -event.angleDelta.y
                    canvasRoot.scrollRequested(dy)
                    event.accepted = true
                }
            }
        }

        onActiveFocusChanged: {
            if (activeFocus) {
                canvasRoot.paneActivated()
                canvasRoot.cursorVisibilityRequested()
            }
            bracketHighlightOverlay.updateBracketHighlights()
        }

        onCursorPositionChanged: {
            if (activeFocus) {
                canvasRoot.cursorVisibilityRequested()
            }
            bracketHighlightOverlay.updateBracketHighlights()
        }

        onSelectionStartChanged: bracketHighlightOverlay.updateBracketHighlights()
        onSelectionEndChanged: bracketHighlightOverlay.updateBracketHighlights()

        Keys.onShortcutOverride: (event) => {
            EditorKeys.handleShortcutOverride(event, canvasRoot, editorArea, Markdown)
        }

        Keys.onTabPressed: (event) => {
            Markdown.handleTab(editorArea, false, canvasRoot.tabSize)
            event.accepted = true
        }
        Keys.onBacktabPressed: (event) => {
            Markdown.handleTab(editorArea, true, canvasRoot.tabSize)
            event.accepted = true
        }

        Keys.onBackPressed: (event) => {
            if (Markdown.handleSmartBackspace(editorArea)) {
                event.accepted = true
                return
            }
            event.accepted = false
        }

        Keys.onDeletePressed: (event) => {
            if (Markdown.handleSmartDelete(editorArea)) {
                event.accepted = true
                return
            }
            event.accepted = false
        }

        Keys.onSpacePressed: (event) => {
            if (Markdown.handleAutoPair(editorArea, " ")) {
                event.accepted = true
                return
            }
            event.accepted = false
        }

        Keys.onPressed: (event) => {
            EditorKeys.handleKeyPressed(event, canvasRoot, editorArea, Markdown)
        }

        Keys.onReleased: (event) => {
            if (event.modifiers & Qt.ControlModifier) {
                if (event.key === Qt.Key_B || event.key === Qt.Key_I) {
                    event.accepted = true
                    return
                }
            }
            if (EditorKeys.isCloseKey(event)) {
                event.accepted = true
            }
        }

        Keys.onReturnPressed: (event) => {
            event.accepted = Markdown.handleSmartEnter(editorArea, (typeof backend !== "undefined" ? backend : null), (t) => canvasRoot.syncNoticeRequested(t))
        }
        Keys.onEnterPressed: (event) => {
            event.accepted = Markdown.handleSmartEnter(editorArea, (typeof backend !== "undefined" ? backend : null), (t) => canvasRoot.syncNoticeRequested(t))
        }

        Keys.onUpPressed: (event) => {
            let firstLineEnd = text.indexOf("\n")
            let isFirstLine = (firstLineEnd === -1) ? true : (cursorPosition <= firstLineEnd)
            if (cursorPosition === 0 || isFirstLine) {
                canvasRoot.scrollToTopRequested()
            }
            event.accepted = false
        }

        onTextChanged: {
            canvasRoot.textChangedByUser()
            bracketHighlightOverlay.updateBracketHighlights()
        }

        onPressed: canvasRoot.paneActivated()
    }

    // Правая полоса 36px для скроллбара (предотвращает наложение на текст)
    Item {
        id: rightGutterSpacer
        Layout.preferredWidth: canvasRoot.barSize
        Layout.fillHeight: true
    }
}
