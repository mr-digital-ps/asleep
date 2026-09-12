import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../js/markdown_shortcuts.js" as Markdown
import "../../js/block_sync.js" as BlockSync

Item {
    id: mainBar

    // Свойства
    property int barSize: 36
    property string fileName: "Новый документ"
    property string fileUrl: ""
    property bool isCenteredMode: true
    property real customSheetWidth: 800
    property real minSheetWidth: 380
    property bool isCustomWidthSetByUser: false
    property bool isCustomFontSizeSetByUser: false
    property bool isSplitMode: false
    property bool isActivePane: false
    property bool showCloseButton: false
    property bool isEmpty: false
    property bool isReceivingExternalSync: false
    property string customFontFamily: "Segoe UI, Inter, -apple-system, sans-serif"
    property bool typewriterMode: false
    property bool focusMode: false
    property bool isHeaderPinned: false
    property bool isFooterPinned: true

    readonly property string statsString: {
        let txt = (editorArea && editorArea.text) ? editorArea.text : ""
        let words = 0
        let trimmed = txt.trim()
        if (trimmed.length > 0) {
            words = trimmed.split(/\s+/).length
        }
        let chars = txt.length
        return words + " слов · " + chars + " знаков"
    }

    function saveHeaderPinnedState(pinned) {
        if (typeof backend !== "undefined" && backend && typeof backend.save_header_pinned === "function") {
            backend.save_header_pinned(pinned)
        }
    }

    function saveFooterPinnedState(pinned) {
        if (typeof backend !== "undefined" && backend && typeof backend.save_footer_pinned === "function") {
            backend.save_footer_pinned(pinned)
        }
    }

    // Плавный скролл с накоплением дельты
    NumberAnimation {
        id: smoothScrollAnim
        target: editorScroll ? editorScroll.contentItem : null
        property: "contentY"
        duration: 160
        easing.type: Easing.OutQuad
    }

    function smoothScrollBy(deltaY) {
        if (!editorScroll || !editorScroll.contentItem) return
        let maxY = Math.max(0, editorScroll.contentItem.contentHeight - editorScroll.availableHeight)
        let cur = smoothScrollAnim.running ? smoothScrollAnim.to : editorScroll.contentItem.contentY
        let target = Math.max(0, Math.min(maxY, cur + deltaY))
        smoothScrollAnim.stop()
        smoothScrollAnim.from = editorScroll.contentItem.contentY
        smoothScrollAnim.to = target
        smoothScrollAnim.start()
    }

    // Доступ к редактору и заголовку для внешних скриптов
    property alias editorArea: editorArea
    property alias editorScroll: editorScroll
    property alias text: editorArea.text
    property alias titleField: docHeader.titleField
    property bool isTitleFocused: docHeader ? docHeader.titleField.activeFocus : false
    readonly property real scrollY: (editorScroll && editorScroll.contentItem) ? editorScroll.contentItem.contentY : 0

    // Сигналы
    signal titleChangedByUser(string newTitle)
    signal closeRequested()
    signal paneActivated()
    signal detachRequested()
    signal fileDragStarted(string url, string name, real gx, real gy)
    signal fileDragMoved(real gx, real gy)
    signal fileDragEnded(string url, string name, real gx, real gy)

    readonly property bool isResizingSheet: (leftHandle && (leftHandle.containsMouse || leftHandle.pressed)) || (rightHandle && (rightHandle.containsMouse || rightHandle.pressed))

    function stripExt(name) {
        if (!name) return ""
        return name.replace(/\.md$/i, "")
    }

    function updateConfigParameterInText(key, value) {
        if (!mainBar.fileName || (!mainBar.fileName.startsWith("_Настройка каталога") && !mainBar.fileName.startsWith("Настройка каталога"))) return
        let txt = editorArea.text
        let regex = new RegExp("^(\\s*" + key + "\\s*:\\s*)[^\\s#]+", "m")
        if (regex.test(txt)) {
            let newTxt = txt.replace(regex, "$1" + value)
            let curPos = editorArea.cursorPosition
            editorArea.text = newTxt
            editorArea.cursorPosition = Math.min(curPos, newTxt.length)
        }
    }

    function toggleFullWidth() {
        if (!editorScroll) return
        mainBar.isCustomWidthSetByUser = true
        if (mainBar.customSheetWidth >= editorScroll.availableWidth - 20) {
            mainBar.customSheetWidth = 800
        } else {
            mainBar.customSheetWidth = editorScroll.availableWidth
        }
        mainBar.isCenteredMode = true
        mainBar.updateConfigParameterInText("sheet_width", mainBar.customSheetWidth)
        if (typeof backend !== "undefined" && backend && typeof backend.update_sheet_width === "function") {
            backend.update_sheet_width(mainBar.customSheetWidth)
        }
    }

    function isCloseKey(event) {
        if (!(event.modifiers & Qt.ControlModifier)) return false
        if (event.key === Qt.Key_W || event.nativeScanCode === 17 || event.text === 'w' || event.text === 'W' || event.text === 'ц' || event.text === 'Ц' || event.key === 1062 || event.key === 1030) return true
        if (event.key === Qt.Key_Q || event.nativeScanCode === 16 || event.text === 'q' || event.text === 'Q' || event.text === 'й' || event.text === 'Й' || event.key === 1081 || event.key === 1049) return true
        return false
    }

    function applyConfig(cfg) {
        if (!cfg || !cfg.editor) return
        if (!mainBar.isCustomWidthSetByUser && typeof cfg.editor.sheet_width === "number" && cfg.editor.sheet_width > 0) {
            mainBar.customSheetWidth = cfg.editor.sheet_width
        }
        if (typeof cfg.editor.font_family === "string" && cfg.editor.font_family.length > 0) {
            mainBar.customFontFamily = cfg.editor.font_family
        }
        if (!mainBar.isCustomFontSizeSetByUser && typeof cfg.editor.font_size === "number" && cfg.editor.font_size > 0) {
            editorArea.font.pixelSize = cfg.editor.font_size
        }
        if (typeof cfg.editor.padding_left === "number") {
            editorArea.leftPadding = cfg.editor.padding_left
        }
        if (typeof cfg.editor.padding_right === "number") {
            editorArea.rightPadding = cfg.editor.padding_right
        }
        if (typeof cfg.editor.padding_top === "number") {
            editorArea.topPadding = cfg.editor.padding_top
        }
        if (typeof cfg.editor.padding_bottom === "number") {
            editorArea.bottomPadding = cfg.editor.padding_bottom
        }
        if (typeof cfg.editor.typewriter_mode === "boolean") {
            mainBar.typewriterMode = cfg.editor.typewriter_mode
        }
        if (typeof cfg.editor.focus_mode === "boolean") {
            mainBar.focusMode = cfg.editor.focus_mode
        }
        if (typeof backend !== "undefined" && backend && typeof backend.set_editor_line_height === "function") {
            let percent = (typeof cfg.editor.line_height === "number" && cfg.editor.line_height > 0) ? (cfg.editor.line_height * 100) : 135.0
            backend.set_editor_line_height(editorArea, percent)
        }
    }

    Component.onCompleted: {
        if (typeof backend !== "undefined" && backend && typeof backend.get_current_config === "function") {
            try {
                let cfgStr = backend.get_current_config()
                if (cfgStr) {
                    mainBar.applyConfig(JSON.parse(cfgStr))
                }
            } catch(e) {}
        }
        if (typeof backend !== "undefined" && backend && typeof backend.get_session_config === "function") {
            try {
                let sess = backend.get_session_config()
                if (sess) {
                    if (typeof sess.sheet_width === "number" && sess.sheet_width >= mainBar.minSheetWidth) {
                        mainBar.customSheetWidth = sess.sheet_width
                        mainBar.isCustomWidthSetByUser = true
                    }
                    if (typeof sess.font_size === "number" && sess.font_size >= 10) {
                        editorArea.font.pixelSize = sess.font_size
                        mainBar.isCustomFontSizeSetByUser = true
                    }
                    if (typeof sess.header_pinned === "boolean") {
                        mainBar.isHeaderPinned = sess.header_pinned
                    }
                    if (typeof sess.footer_pinned === "boolean") {
                        mainBar.isFooterPinned = sess.footer_pinned
                    }
                }
            } catch(e) {}
        }
        if (typeof backend !== "undefined" && backend) {
            if (typeof backend.set_editor_line_height === "function") {
                backend.set_editor_line_height(editorArea, 135.0)
            }
            if (typeof backend.attach_highlighter === "function") {
                backend.attach_highlighter(editorArea)
            }
        }
    }

    onFileUrlChanged: {
        if (typeof backend !== "undefined" && backend) {
            if (typeof backend.set_editor_line_height === "function") {
                Qt.callLater(() => backend.set_editor_line_height(editorArea, 135.0))
            }
            if (typeof backend.attach_highlighter === "function") {
                Qt.callLater(() => backend.attach_highlighter(editorArea))
            }
        }
    }

    // Автоматическая прокрутка для удержания текстового курсора "|" в поле зрения
    function ensureCursorVisible() {
        if (!editorArea || !editorScroll || !editorScroll.contentItem) return
        if (!editorArea.activeFocus) return

        let rect = editorArea.cursorRectangle
        if (!rect || rect.height <= 0) return

        // Позиция курсора в координатах видимой области editorScroll
        let pt = editorArea.mapToItem(editorScroll, 0, rect.y)
        let cursorTop = pt.y
        let cursorBottom = cursorTop + rect.height

        let viewH = editorScroll.availableHeight
        if (viewH <= 0) return

        let currentY = editorScroll.contentItem.contentY
        let maxY = Math.max(0, editorScroll.contentItem.contentHeight - viewH)

        // Режим печатной машинки: центрируем активную строку
        if (mainBar.typewriterMode) {
            let cursorCenter = cursorTop + rect.height / 2
            let viewportCenter = viewH / 2
            let diff = cursorCenter - viewportCenter
            editorScroll.contentItem.contentY = Math.max(0, Math.min(maxY, currentY + diff))
            return
        }

        // Запас отступа сверху и снизу (~70px или 2-3 строки), чтобы курсор не прилипал к краю экрана
        let topMargin = Math.min(70, viewH * 0.2)
        let bottomMargin = Math.max(70, mainBar.isFooterPinned ? 70 : 30)

        if (cursorBottom + bottomMargin > viewH) {
            let diff = (cursorBottom + bottomMargin) - viewH
            editorScroll.contentItem.contentY = Math.max(0, Math.min(maxY, currentY + diff))
        } else if (cursorTop < topMargin) {
            let diff = topMargin - cursorTop
            let firstLineEnd = editorArea.text.indexOf("\n")
            if (editorArea.cursorPosition === 0 || (firstLineEnd !== -1 && editorArea.cursorPosition <= firstLineEnd)) {
                editorScroll.contentItem.contentY = 0
            } else {
                editorScroll.contentItem.contentY = Math.max(0, Math.min(maxY, currentY - diff))
            }
        }
    }

    function requestEnsureCursorVisible() {
        Qt.callLater(mainBar.ensureCursorVisible)
    }

    // Применение внешнего обновления блока от другого окна или сплит-панели
    function applyExternalBlockUpdate(headingNorm, newContent) {
        let res = BlockSync.applyExternalBlockUpdate(editorArea, headingNorm, newContent)
        if (res) {
            mainBar.isReceivingExternalSync = true
            editorArea.text = res.text
            editorArea.cursorPosition = res.cursor
            mainBar.isReceivingExternalSync = false
        }
    }

    // Таймер дебаунса для синхронизации редактируемого блока с бэкендом
    Timer {
        id: blockSyncTimer
        interval: 350
        repeat: false
        onTriggered: {
            if (mainBar.isReceivingExternalSync) return
            if (typeof backend === "undefined" || !backend) return
            let b = (typeof backend !== "undefined") ? backend : null
            let block = BlockSync.getCurrentBlockInfo(editorArea, b)
            if (!block) return

            // Если блок пустой, но уже существует в других файлах — автоматически подтягиваем контент
            if (block.shouldAutoFill && block.autoFillContent) {
                mainBar.isReceivingExternalSync = true
                let insertText = "\n" + block.autoFillContent + "\n\n"
                let before = editorArea.text.substring(0, block.contentStart)
                let after = editorArea.text.substring(block.contentEnd)
                editorArea.text = before + insertText + after
                editorArea.cursorPosition = block.contentStart + insertText.length
                mainBar.isReceivingExternalSync = false
                mainBar.showSyncNotice(block.heading)
                return
            }

            let sourceId = mainBar.fileUrl || ("tab://" + (mainBar.fileName || "doc"))
            if (block.heading && block.content !== undefined) {
                backend.sync_block(sourceId, block.heading, block.content)
            }
        }
    }

    // Всплывающее уведомление о синхронизации блока
    SyncNotice {
        id: syncNotice
    }

    function showSyncNotice(title) {
        syncNotice.showNotice(title)
    }

    // Перехват кликов по панели для мгновенной активации нужной половины сплита
    TapHandler {
        gesturePolicy: TapHandler.WithinBounds
        onTapped: {
            if (docHeader && docHeader.titleField && docHeader.titleField.activeFocus) return
            mainBar.paneActivated()
        }
    }

    // =========================================================================
    // ХОЛСТ РЕДАКТОРА
    // =========================================================================
    ScrollView {
        id: editorScroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        contentHeight: scrollContentContainer.height
        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        WheelHandler {
            target: editorScroll.contentItem
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                if (event.modifiers & Qt.ControlModifier) {
                    mainBar.isCustomFontSizeSetByUser = true
                    if (event.angleDelta.y > 0) {
                        editorArea.font.pixelSize = Math.min(36, editorArea.font.pixelSize + 1)
                    } else if (event.angleDelta.y < 0) {
                        editorArea.font.pixelSize = Math.max(10, editorArea.font.pixelSize - 1)
                    }
                    mainBar.updateConfigParameterInText("font_size", editorArea.font.pixelSize)
                    if (typeof backend !== "undefined" && backend && typeof backend.update_font_size === "function") {
                        backend.update_font_size(editorArea.font.pixelSize)
                    }
                    event.accepted = true
                    return
                }
                let dy = -event.angleDelta.y
                mainBar.smoothScrollBy(dy)
                event.accepted = true
            }
        }

        Connections {
            target: editorScroll.contentItem
            function onContentHeightChanged() {
                if (editorArea && editorArea.activeFocus) {
                    mainBar.requestEnsureCursorVisible()
                }
            }
        }

        Item {
            id: scrollContentContainer
            width: editorScroll.availableWidth
            readonly property real singleLineHeight: (editorArea && editorArea.cursorRectangle.height > 0) ? editorArea.cursorRectangle.height : 24
            height: Math.max(mainBar.height, (editorArea && editorArea.lineCount > 1 && editorArea.contentHeight > 60)
                ? (contentRow.y + contentRow.height + docFooterContainer.height + editorScroll.availableHeight - (editorArea.bottomPadding + singleLineHeight + (mainBar.isHeaderPinned ? 70 : 0) + 16))
                : mainBar.height)

            // Перетаскивание файла по пустому пространству вокруг документа (в режиме сплита)
            MouseArea {
                anchors.fill: parent
                z: -1
                acceptedButtons: Qt.LeftButton
                cursorShape: mainBar.isSplitMode ? Qt.OpenHandCursor : Qt.ArrowCursor
                hoverEnabled: true

                property real pressX: 0
                property real pressY: 0
                property bool isPressed: false
                property bool isDragging: false

                onPressed: (mouse) => {
                    if (mouse.button === Qt.LeftButton) {
                        mainBar.paneActivated()
                        if (mainBar.isSplitMode) {
                            pressX = mouse.x
                            pressY = mouse.y
                            isPressed = true
                            isDragging = false
                        }
                    }
                }

                onPositionChanged: (mouse) => {
                    if (!isPressed || !mainBar.isSplitMode) return
                    let dx = mouse.x - pressX
                    let dy = mouse.y - pressY
                    let dist = Math.hypot(dx, dy)
                    let globalP = scrollContentContainer.mapToGlobal(mouse.x, mouse.y)

                    if (!isDragging) {
                        if (dist > 8 && !mainBar.isEmpty) {
                            isDragging = true
                            mainBar.fileDragStarted(mainBar.fileUrl, mainBar.fileName, globalP.x, globalP.y)
                        }
                    } else {
                        mainBar.fileDragMoved(globalP.x, globalP.y)
                    }
                }

                onReleased: (mouse) => {
                    if (mouse.button === Qt.LeftButton) {
                        isPressed = false
                        if (isDragging && mainBar.isSplitMode) {
                            isDragging = false
                            let globalP = scrollContentContainer.mapToGlobal(mouse.x, mouse.y)
                            mainBar.fileDragEnded(mainBar.fileUrl, mainBar.fileName, globalP.x, globalP.y)
                        }
                    }
                }
            }

            // Экран-заглушка, если нет открытых файлов
            Item {
                anchors.centerIn: parent
                visible: mainBar.isEmpty
                width: 320
                height: 120

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Нет открытых файлов"
                        color: "#4a4a4a"
                        font.pixelSize: 16
                        font.bold: true
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Выберите файл в меню слева\nили Shift + Клик для разделения экрана"
                        color: "#383838"
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        lineHeight: 1.3
                    }
                }
            }

            // Поле для отображения страницы (на полную или среднюю/настраиваемую ширину)
            Rectangle {
                id: paperSheet
                visible: !mainBar.isEmpty

                width: mainBar.isCenteredMode ? Math.min(parent.width, Math.max(mainBar.minSheetWidth, mainBar.customSheetWidth)) : parent.width
                height: parent.height
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top

                color: "#181818"

                opacity: (mainBar.isSplitMode && !mainBar.isActivePane) ? 0.55 : 1.0
                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }

                // Фокус-режим: кинематографичное приглушение неактивных абзацев
                Item {
                    id: focusOverlay
                    anchors.fill: parent
                    visible: mainBar.focusMode && editorArea.activeFocus
                    opacity: (mainBar.focusMode && editorArea.activeFocus) ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    z: 5
                    enabled: false

                    Rectangle {
                        id: focusTopDim
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        readonly property real targetH: {
                            if (!editorArea || !editorArea.activeFocus) return 0
                            let p = editorArea.mapToItem(focusOverlay, 0, editorArea.cursorRectangle.y)
                            return Math.max(0, p.y - 8)
                        }
                        height: targetH
                        color: "#cc181818"
                        Behavior on height { NumberAnimation { duration: 70; easing.type: Easing.OutQuad } }
                    }

                    Rectangle {
                        id: focusBottomDim
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        readonly property real targetY: {
                            if (!editorArea || !editorArea.activeFocus) return parent.height
                            let p = editorArea.mapToItem(focusOverlay, 0, editorArea.cursorRectangle.y + editorArea.cursorRectangle.height)
                            return p.y + 8
                        }
                        y: targetY
                        height: Math.max(0, parent.height - targetY)
                        color: "#cc181818"
                        Behavior on y { NumberAnimation { duration: 70; easing.type: Easing.OutQuad } }
                        Behavior on height { NumberAnimation { duration: 70; easing.type: Easing.OutQuad } }
                    }
                }

                // 1. Верхний контейнер заголовка (с поддержкой закрепления Sticky Header)
                Item {
                    id: docHeaderContainer
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 70
                    z: 20
                    y: mainBar.isHeaderPinned
                        ? (editorScroll && editorScroll.contentItem ? Math.max(0, editorScroll.contentItem.contentY) : 0)
                        : 0

                    Rectangle {
                        anchors.fill: parent
                        color: "#181818"
                        visible: mainBar.isHeaderPinned && (editorScroll && editorScroll.contentItem && editorScroll.contentItem.contentY > 0)
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        DocumentHeader {
                            id: docHeader
                            fileName: mainBar.fileName
                            fileUrl: mainBar.fileUrl
                            isSplitMode: mainBar.isSplitMode
                            isActivePane: mainBar.isActivePane
                            isEmpty: mainBar.isEmpty
                            maxTitleWidth: paperSheet.width - 72
                            contentLeftPadding: editorArea.leftPadding
                            contentRightPadding: editorArea.rightPadding

                            onTitleCommitted: (newTitle) => mainBar.titleChangedByUser(newTitle)
                            onPaneActivated: mainBar.paneActivated()
                            onFileDragStarted: (url, name, gx, gy) => mainBar.fileDragStarted(url, name, gx, gy)
                            onFileDragMoved: (gx, gy) => mainBar.fileDragMoved(gx, gy)
                            onFileDragEnded: (url, name, gx, gy) => mainBar.fileDragEnded(url, name, gx, gy)
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
                                color: mainBar.isHeaderPinned ? (headerDividerMouse.containsMouse ? "#888888" : "#666666") : (headerDividerMouse.containsMouse ? "#4a4a4a" : "#3a3a3a")
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            MouseArea {
                                id: headerDividerMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    mainBar.isHeaderPinned = !mainBar.isHeaderPinned
                                    mainBar.saveHeaderPinnedState(mainBar.isHeaderPinned)
                                }
                            }
                        }
                    }
                }

                // 2. Содержимое документа (левая полоса 36px + текст + правая полоса 36px)
                RowLayout {
                    id: contentRow
                    anchors.top: parent.top
                    anchors.topMargin: 70
                    anchors.left: parent.left
                    anchors.right: parent.right
                    Layout.preferredHeight: Math.max(editorScroll.availableHeight - 100, editorArea.implicitHeight)
                    height: Math.max(editorScroll.availableHeight - 100, editorArea.implicitHeight)
                    spacing: 0

                    EditorGutter {
                        barSize: 36
                        editorArea: editorArea
                        Layout.preferredWidth: barSize
                        Layout.fillHeight: true
                        onActivated: mainBar.paneActivated()
                    }

                    TextArea {
                        id: editorArea
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        leftPadding: 0
                        rightPadding: 0
                        topPadding: 6
                        bottomPadding: 0

                        font.family: mainBar.customFontFamily
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
                            Item {
                                id: bracketHighlightOverlay
                                anchors.fill: parent

                                Rectangle {
                                    id: primaryBracketHighlight
                                    visible: false
                                    color: "#25ffffff"
                                    border.color: "#70ffffff"
                                    border.width: 1
                                    radius: 2
                                }

                                Rectangle {
                                    id: matchBracketHighlight
                                    visible: false
                                    color: "#25ffffff"
                                    border.color: "#70ffffff"
                                    border.width: 1
                                    radius: 2
                                }

                                function updateBracketHighlights() {
                                    if (!editorArea.activeFocus || editorArea.selectionStart !== editorArea.selectionEnd) {
                                        primaryBracketHighlight.visible = false
                                        matchBracketHighlight.visible = false
                                        return
                                    }

                                    let pair = Markdown.findMatchingBracket(editorArea.text, editorArea.cursorPosition)
                                    if (!pair) {
                                        primaryBracketHighlight.visible = false
                                        matchBracketHighlight.visible = false
                                        return
                                    }

                                    let r1 = editorArea.positionToRectangle(pair.primary)
                                    let r2 = editorArea.positionToRectangle(pair.match)

                                    if (r1 && r1.height > 0) {
                                        primaryBracketHighlight.x = r1.x
                                        primaryBracketHighlight.y = r1.y
                                        primaryBracketHighlight.width = Math.max(8, r1.width)
                                        primaryBracketHighlight.height = r1.height
                                        primaryBracketHighlight.visible = true
                                    } else {
                                        primaryBracketHighlight.visible = false
                                    }

                                    if (r2 && r2.height > 0) {
                                        matchBracketHighlight.x = r2.x
                                        matchBracketHighlight.y = r2.y
                                        matchBracketHighlight.width = Math.max(8, r2.width)
                                        matchBracketHighlight.height = r2.height
                                        matchBracketHighlight.visible = true
                                    } else {
                                        matchBracketHighlight.visible = false
                                    }
                                }
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
                                    event.accepted = true
                                } else {
                                    let dy = -event.angleDelta.y
                                    mainBar.smoothScrollBy(dy)
                                    event.accepted = true
                                }
                            }
                        }

                        onActiveFocusChanged: {
                            if (activeFocus) {
                                mainBar.paneActivated()
                                mainBar.requestEnsureCursorVisible()
                            }
                            bracketHighlightOverlay.updateBracketHighlights()
                        }

                        onCursorPositionChanged: {
                            if (activeFocus) {
                                mainBar.ensureCursorVisible()
                                mainBar.requestEnsureCursorVisible()
                            }
                            bracketHighlightOverlay.updateBracketHighlights()
                        }

                        onSelectionStartChanged: bracketHighlightOverlay.updateBracketHighlights()
                        onSelectionEndChanged: bracketHighlightOverlay.updateBracketHighlights()

                        Keys.onShortcutOverride: (event) => {
                            if (mainBar.isCloseKey(event)) {
                                event.accepted = true
                                return
                            }
                            if (event.modifiers & Qt.ControlModifier) {
                                if (event.key === Qt.Key_B || event.key === Qt.Key_I || event.key === Qt.Key_K ||
                                    event.key === Qt.Key_E || event.key === Qt.Key_D ||
                                    event.key === Qt.Key_Return || event.key === Qt.Key_Enter ||
                                    (event.key >= Qt.Key_0 && event.key <= Qt.Key_6)) {
                                    event.accepted = true
                                    return
                                }
                            }
                        }

                        Keys.onPressed: (event) => {
                            if (mainBar.isCloseKey(event)) {
                                mainBar.closeRequested()
                                event.accepted = true
                                return
                            }

                            // Backspace: удаление пустой пары скобок/кавычек
                            if (event.key === Qt.Key_Backspace && !(event.modifiers & Qt.ControlModifier)) {
                                if (Markdown.handleAutoPairBackspace(editorArea)) {
                                    event.accepted = true
                                    return
                                }
                            }

                            // Alt+Shift+T: переключить Typewriter Mode
                            if ((event.modifiers & Qt.AltModifier) && (event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_T) {
                                mainBar.typewriterMode = !mainBar.typewriterMode
                                mainBar.showSyncNotice(mainBar.typewriterMode ? "Typewriter: Вкл" : "Typewriter: Выкл")
                                if (mainBar.typewriterMode) mainBar.ensureCursorVisible()
                                event.accepted = true
                                return
                            }

                            // Alt+Shift+F: переключить Focus Mode
                            if ((event.modifiers & Qt.AltModifier) && (event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_F) {
                                mainBar.focusMode = !mainBar.focusMode
                                mainBar.showSyncNotice(mainBar.focusMode ? "Focus Mode: Вкл" : "Focus Mode: Выкл")
                                event.accepted = true
                                return
                            }

                            // Ctrl+D: дублирование строки
                            if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_D)) {
                                Markdown.duplicateLine(editorArea)
                                event.accepted = true
                                return
                            }

                            // Ctrl+B / I / K / E: форматирование
                            if ((event.modifiers & Qt.ControlModifier) && !(event.modifiers & Qt.ShiftModifier)) {
                                if (event.key === Qt.Key_B) { Markdown.wrapSelection(editorArea, "**", "**"); event.accepted = true; return }
                                if (event.key === Qt.Key_I) { Markdown.wrapSelection(editorArea, "*", "*"); event.accepted = true; return }
                                if (event.key === Qt.Key_K) { Markdown.wrapSelection(editorArea, "[", "](url)"); event.accepted = true; return }
                                if (event.key === Qt.Key_E) { Markdown.wrapSelection(editorArea, "`", "`"); event.accepted = true; return }
                            }

                            // Ctrl+Enter: переключение чекбокса задачи
                            if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                                Markdown.toggleTask(editorArea)
                                event.accepted = true
                                return
                            }

                            // Ctrl+0..6: заголовки
                            if ((event.modifiers & Qt.ControlModifier) && event.key >= Qt.Key_0 && event.key <= Qt.Key_6) {
                                Markdown.toggleHeading(editorArea, event.key - Qt.Key_0)
                                event.accepted = true
                                return
                            }

                            // Авто-обертка выделенного текста при вводе скобок и кавычек
                            if (selectionStart !== selectionEnd && event.text) {
                                if (Markdown.handleAutoWrap(editorArea, event.text)) {
                                    event.accepted = true
                                    return
                                }
                            }

                            // Авто-пара при вводе скобок/кавычек без выделения
                            if (selectionStart === selectionEnd && event.text && event.text.length === 1 &&
                                !(event.modifiers & Qt.ControlModifier) && !(event.modifiers & Qt.AltModifier)) {
                                if (Markdown.handleAutoPair(editorArea, event.text)) {
                                    event.accepted = true
                                    return
                                }
                            }

                            // Alt+Up / Alt+Down: перемещение строк
                            if (event.modifiers & Qt.AltModifier) {
                                if (event.key === Qt.Key_Up) { Markdown.moveLineUp(editorArea); event.accepted = true; return }
                                if (event.key === Qt.Key_Down) { Markdown.moveLineDown(editorArea); event.accepted = true; return }
                            }

                            // Alt+Z / Alt+F: переключить ширину листа (занять всё свободное пространство)
                            if ((event.modifiers & Qt.AltModifier) && !(event.modifiers & Qt.ControlModifier)) {
                                if (event.key === Qt.Key_Z || event.key === Qt.Key_F) {
                                    mainBar.toggleFullWidth()
                                    event.accepted = true
                                    return
                                }
                            }
                        }

                        Keys.onTabPressed: (event) => {
                            Markdown.handleTabIndent(editorArea, event.modifiers & Qt.ShiftModifier)
                            event.accepted = true
                        }

                        Keys.onReturnPressed: (event) => {
                            event.accepted = Markdown.handleSmartEnter(editorArea, (typeof backend !== "undefined" ? backend : null), (t) => mainBar.showSyncNotice(t))
                        }
                        Keys.onEnterPressed: (event) => {
                            event.accepted = Markdown.handleSmartEnter(editorArea, (typeof backend !== "undefined" ? backend : null), (t) => mainBar.showSyncNotice(t))
                        }

                        Keys.onUpPressed: (event) => {
                            let firstLineEnd = text.indexOf("\n")
                            let isFirstLine = (firstLineEnd === -1) ? true : (cursorPosition <= firstLineEnd)
                            if (cursorPosition === 0 || isFirstLine) {
                                if (editorScroll && editorScroll.contentItem) {
                                    editorScroll.contentItem.contentY = 0
                                }
                            }
                            event.accepted = false
                        }

                        onTextChanged: {
                            if (!mainBar.isReceivingExternalSync && activeFocus) {
                                blockSyncTimer.restart()
                            }
                            if (activeFocus) {
                                mainBar.requestEnsureCursorVisible()
                            }
                            bracketHighlightOverlay.updateBracketHighlights()
                        }

                        onPressed: mainBar.paneActivated()
                    }

                    // 4. Правая полоса 36px для скроллбара (предотвращает наложение на текст)
                    Item {
                        id: rightGutterSpacer
                        Layout.preferredWidth: barSize
                        Layout.fillHeight: true
                    }
                }

                // 3. Нижний контейнер со статистикой и разделителем (когда откреплен)
                Item {
                    id: docFooterContainer
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 44
                    z: 20
                    y: contentRow.y + contentRow.height + 4
                    visible: !mainBar.isFooterPinned

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        // Нижняя разделительная линия (клик = закрепить)
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
                                color: footerDividerMouse.containsMouse ? "#4a4a4a" : "#3a3a3a"
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            MouseArea {
                                id: footerDividerMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    mainBar.isFooterPinned = true
                                    mainBar.saveFooterPinnedState(true)
                                    mainBar.paneActivated()
                                }
                            }
                        }

                        // Информационная строка со статистикой (слова, знаки)
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 36
                            Layout.rightMargin: 36
                            Layout.preferredHeight: 30
                            spacing: 12

                            Text {
                                id: docStatsText
                                Layout.alignment: Qt.AlignVCenter
                                font.pixelSize: 12
                                color: "#666666"
                                text: mainBar.statsString
                            }

                            Item { Layout.fillWidth: true }
                        }
                    }
                }

                // Интерактивная граница изменения ширины листа слева
                SheetResizeHandle {
                    id: leftHandle
                    isLeft: true
                    containerItem: scrollContentContainer
                    anchors.left: parent.left
                    anchors.leftMargin: -12
                    minWidth: mainBar.minSheetWidth
                    maxWidth: scrollContentContainer.width
                    forceVisible: mainBar.isResizingSheet
                    onSheetWidthRequested: (w) => {
                        mainBar.isCenteredMode = true
                        mainBar.isCustomWidthSetByUser = true
                        mainBar.customSheetWidth = w
                        mainBar.updateConfigParameterInText("sheet_width", w)
                    }
                    onSheetWidthCommitted: (w) => {
                        mainBar.isCustomWidthSetByUser = true
                        mainBar.updateConfigParameterInText("sheet_width", w)
                        if (typeof backend !== "undefined" && backend && typeof backend.update_sheet_width === "function") {
                            backend.update_sheet_width(w)
                        }
                    }
                    onDoubleClickedToggle: {
                        mainBar.toggleFullWidth()
                    }
                }

                // Интерактивная граница изменения ширины листа справа
                SheetResizeHandle {
                    id: rightHandle
                    isLeft: false
                    containerItem: scrollContentContainer
                    anchors.right: parent.right
                    anchors.rightMargin: -12
                    minWidth: mainBar.minSheetWidth
                    maxWidth: scrollContentContainer.width
                    forceVisible: mainBar.isResizingSheet
                    onSheetWidthRequested: (w) => {
                        mainBar.isCenteredMode = true
                        mainBar.isCustomWidthSetByUser = true
                        mainBar.customSheetWidth = w
                        mainBar.updateConfigParameterInText("sheet_width", w)
                    }
                    onSheetWidthCommitted: (w) => {
                        mainBar.isCustomWidthSetByUser = true
                        mainBar.updateConfigParameterInText("sheet_width", w)
                        if (typeof backend !== "undefined" && backend && typeof backend.update_sheet_width === "function") {
                            backend.update_sheet_width(w)
                        }
                    }
                    onDoubleClickedToggle: {
                        mainBar.toggleFullWidth()
                    }
                }
            }
        }
    }

    // Правая полоса со скроллбаром документа
    EditorScrollbar {
        id: editorScrollbar
        editorScroll: editorScroll
        paperSheet: paperSheet
        isEmpty: mainBar.isEmpty
        isFooterPinned: mainBar.isFooterPinned
        barSize: 36
        onActivated: mainBar.paneActivated()
    }

    // Закрепленный внизу экрана статус-бар с разделителем (когда isFooterPinned == true)
    Item {
        id: pinnedFooterBar
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: paperSheet.width
        height: 44
        z: 25
        visible: mainBar.isFooterPinned && !mainBar.isEmpty
        opacity: (mainBar.isSplitMode && !mainBar.isActivePane) ? 0.55 : 1.0

        Rectangle {
            anchors.fill: parent
            color: "#181818"
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onPressed: mainBar.paneActivated()
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Нижняя разделительная линия (клик = открепить)
            Item {
                id: pinnedFooterDividerArea
                Layout.fillWidth: true
                Layout.preferredHeight: 14
                Layout.maximumHeight: 14
                Layout.leftMargin: 36
                Layout.rightMargin: 36

                Rectangle {
                    id: pinnedFooterDividerLine
                    anchors.centerIn: parent
                    width: parent.width
                    height: 2
                    radius: 1
                    color: pinnedFooterDividerMouse.containsMouse ? "#888888" : "#666666"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id: pinnedFooterDividerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        mainBar.isFooterPinned = false
                        mainBar.saveFooterPinnedState(false)
                        mainBar.paneActivated()
                    }
                }
            }

            // Информационная строка со статистикой (слова, знаки)
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 36
                Layout.rightMargin: 36
                Layout.preferredHeight: 30
                spacing: 12

                Text {
                    id: pinnedDocStatsText
                    Layout.alignment: Qt.AlignVCenter
                    font.pixelSize: 12
                    color: "#666666"
                    text: mainBar.statsString
                }

                Item { Layout.fillWidth: true }
            }
        }
    }
}
