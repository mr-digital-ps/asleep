import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../js/markdown_shortcuts.js" as Markdown

RowLayout {
    id: canvasRoot
    spacing: 0

    property int barSize: 36
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

    function isCloseKey(event) {
        if (!(event.modifiers & Qt.ControlModifier)) return false
        if (event.key === Qt.Key_W || event.nativeScanCode === 17 || event.text === 'w' || event.text === 'W' || event.text === 'ц' || event.text === 'Ц' || event.key === 1062 || event.key === 1030) return true
        if (event.key === Qt.Key_Q || event.nativeScanCode === 16 || event.text === 'q' || event.text === 'Q' || event.text === 'й' || event.text === 'Й' || event.key === 1081 || event.key === 1049) return true
        return false
    }

    function isToggleHeaderFooterKey(event) {
        if (event.key === Qt.Key_F9) return true
        let isH = event.key === Qt.Key_H || event.nativeScanCode === 35 || event.text === 'h' || event.text === 'H' || event.text === 'р' || event.text === 'Р'
        if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier) && isH) return true
        if ((event.modifiers & Qt.AltModifier) && isH) return true
        return false
    }

    function isToggleFooterKey(event) {
        let isF = event.key === Qt.Key_F || event.nativeScanCode === 33 || event.text === 'f' || event.text === 'F' || event.text === 'а' || event.text === 'А'
        if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier) && isF) return true
        if ((event.modifiers & Qt.AltModifier) && isF) return true
        return false
    }

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
        barSize: canvasRoot.barSize
        editorArea: editorArea
        Layout.preferredWidth: barSize
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
        color: "#d4d4d4"
        selectionColor: "#282828"
        selectedTextColor: "#ffffff"
        placeholderText: "Начните вводить текст..."
        placeholderTextColor: "#666666"

        cursorDelegate: Item {
            id: cursorWrapper
            visible: editorArea.activeFocus
            Rectangle {
                id: customCursor
                width: 2
                height: parent.height
                anchors.centerIn: parent
                color: "#e0e0e0"
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
                color: "#0effffff"
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
            if (canvasRoot.isCloseKey(event)) {
                event.accepted = true
                canvasRoot.closeRequested()
                return
            }
            if (canvasRoot.isToggleHeaderFooterKey(event)) {
                event.accepted = true
                canvasRoot.toggleHeaderFooterRequested()
                return
            }
            if (canvasRoot.isToggleFooterKey(event)) {
                event.accepted = true
                canvasRoot.toggleFooterRequested()
                return
            }
            if (event.modifiers & Qt.ControlModifier) {
                if (event.key === Qt.Key_D) {
                    event.accepted = true
                    canvasRoot.detachRequested()
                    return
                }
                if (event.key === Qt.Key_B) {
                    event.accepted = true
                    Markdown.toggleBold(editorArea)
                    return
                }
                if (event.key === Qt.Key_I) {
                    event.accepted = true
                    Markdown.toggleItalic(editorArea)
                    return
                }
                if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Tab) {
                    event.accepted = true
                    Markdown.handleTab(editorArea, true)
                    return
                }
            }
        }

        Keys.onTabPressed: (event) => {
            Markdown.handleTab(editorArea, false)
            event.accepted = true
        }
        Keys.onBacktabPressed: (event) => {
            Markdown.handleTab(editorArea, true)
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
            if (event.key === Qt.Key_ParenRight && Markdown.handleAutoPair(editorArea, ")")) {
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_BracketRight && Markdown.handleAutoPair(editorArea, "]")) {
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_BraceRight && Markdown.handleAutoPair(editorArea, "}")) {
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_QuoteDbl && Markdown.handleAutoPair(editorArea, "\"")) {
                event.accepted = true
                return
            }
            if (event.key === 1069 && Markdown.handleAutoPair(editorArea, "\"")) {
                event.accepted = true
                return
            }
            if (event.text === "`" && Markdown.handleAutoPair(editorArea, "`")) {
                event.accepted = true
                return
            }
            if (event.key === 1025 && Markdown.handleAutoPair(editorArea, "`")) {
                event.accepted = true
                return
            }
            if (event.key === 1105 && Markdown.handleAutoPair(editorArea, "`")) {
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_ParenLeft && Markdown.handleAutoPair(editorArea, "(")) {
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_BracketLeft && Markdown.handleAutoPair(editorArea, "[")) {
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_BraceLeft && Markdown.handleAutoPair(editorArea, "{")) {
                event.accepted = true
                return
            }

            if (event.modifiers & Qt.ControlModifier) {
                if (event.key === Qt.Key_B) {
                    event.accepted = true
                    Markdown.toggleBold(editorArea)
                    return
                }
                if (event.key === Qt.Key_I) {
                    event.accepted = true
                    Markdown.toggleItalic(editorArea)
                    return
                }
            }
            if (canvasRoot.isCloseKey(event)) {
                event.accepted = true
                canvasRoot.closeRequested()
                return
            }
            if (canvasRoot.isToggleHeaderFooterKey(event)) {
                event.accepted = true
                canvasRoot.toggleHeaderFooterRequested()
                return
            }
            if (canvasRoot.isToggleFooterKey(event)) {
                event.accepted = true
                canvasRoot.toggleFooterRequested()
                return
            }
        }

        Keys.onReleased: (event) => {
            if (event.modifiers & Qt.ControlModifier) {
                if (event.key === Qt.Key_B || event.key === Qt.Key_I) {
                    event.accepted = true
                    return
                }
            }
            if (canvasRoot.isCloseKey(event)) {
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
