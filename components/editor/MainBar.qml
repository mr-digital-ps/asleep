import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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
        let txt = (editorCanvas && editorCanvas.text) ? editorCanvas.text : ""
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

    // Доступ к редактору и заголовку для внешних скриптов (обратная совместимость)
    property alias editorArea: editorCanvas.editorArea
    property alias editorScroll: editorScroll
    property alias text: editorCanvas.text
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

        // Запас отступа сверху и снизу (~70-90px или 2-3 строки), чтобы курсор не прилипал к краю экрана
        let topMargin = Math.min(70, viewH * 0.2)
        let bottomMargin = Math.max(90, viewH * 0.2)

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
            readonly property real headerOffset: mainBar.isHeaderPinned ? 70 : 0
            readonly property real lastLineTop: editorArea ? (editorCanvas.y + editorArea.topPadding + editorArea.contentHeight - singleLineHeight) : 0
            height: Math.max(mainBar.height, (editorArea && editorArea.lineCount > 1 && editorArea.contentHeight > 60)
                ? Math.max(mainBar.height, lastLineTop - (headerOffset + 16) + editorScroll.availableHeight)
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
            EditorEmptyState {
                visible: mainBar.isEmpty
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

                // Фокус-режим: затемнение неактивных строк
                EditorFocusDimmer {
                    editorArea: editorCanvas.editorArea
                    focusMode: mainBar.focusMode
                }

                // 1. Верхний контейнер заголовка (с поддержкой закрепления Sticky Header)
                EditorHeader {
                    id: docHeader
                    anchors.left: parent.left
                    anchors.right: parent.right
                    fileName: mainBar.fileName
                    fileUrl: mainBar.fileUrl
                    isSplitMode: mainBar.isSplitMode
                    isActivePane: mainBar.isActivePane
                    isEmpty: mainBar.isEmpty
                    isPinned: mainBar.isHeaderPinned
                    scrollY: mainBar.scrollY
                    maxTitleWidth: paperSheet.width - 72
                    contentLeftPadding: editorArea.leftPadding
                    contentRightPadding: editorArea.rightPadding

                    onTitleCommitted: (newTitle) => mainBar.titleChangedByUser(newTitle)
                    onPaneActivated: mainBar.paneActivated()
                    onPinToggled: {
                        mainBar.isHeaderPinned = !mainBar.isHeaderPinned
                        mainBar.saveHeaderPinnedState(mainBar.isHeaderPinned)
                    }
                    onFileDragStarted: (url, name, gx, gy) => mainBar.fileDragStarted(url, name, gx, gy)
                    onFileDragMoved: (gx, gy) => mainBar.fileDragMoved(gx, gy)
                    onFileDragEnded: (url, name, gx, gy) => mainBar.fileDragEnded(url, name, gx, gy)
                }

                // 2. Рабочая область документа (Gutter + TextArea + шорткаты)
                EditorCanvas {
                    id: editorCanvas
                    anchors.top: parent.top
                    anchors.topMargin: 70
                    anchors.left: parent.left
                    anchors.right: parent.right
                    availableHeight: editorScroll.availableHeight
                    barSize: mainBar.barSize
                    customFontFamily: mainBar.customFontFamily

                    onPaneActivated: mainBar.paneActivated()
                    onCursorVisibilityRequested: mainBar.requestEnsureCursorVisible()
                    onTextChangedByUser: {
                        if (!mainBar.isReceivingExternalSync && activeFocus) {
                            blockSyncTimer.restart()
                        }
                        if (activeFocus) {
                            mainBar.requestEnsureCursorVisible()
                        }
                    }
                    onScrollRequested: (dy) => mainBar.smoothScrollBy(dy)
                    onScrollToTopRequested: {
                        if (editorScroll && editorScroll.contentItem) {
                            editorScroll.contentItem.contentY = 0
                        }
                    }
                    onFontSizeChanged: (sz) => {
                        mainBar.isCustomFontSizeSetByUser = true
                        mainBar.updateConfigParameterInText("font_size", sz)
                        if (typeof backend !== "undefined" && backend && typeof backend.update_font_size === "function") {
                            backend.update_font_size(sz)
                        }
                    }
                    onCloseRequested: mainBar.closeRequested()
                    onDetachRequested: mainBar.detachRequested()
                    onSyncNoticeRequested: (t) => mainBar.showSyncNotice(t)
                }

                // 3. Нижний контейнер со статистикой и разделителем (прилипает к низу экрана)
                EditorFooter {
                    id: docFooter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 70
                    z: 20
                    isPinned: mainBar.isFooterPinned
                    statsText: mainBar.statsString
                    visible: !mainBar.isEmpty
                    y: {
                        let naturalY = editorCanvas.y + editorCanvas.height + 4
                        let screenBottomY = (editorScroll && editorScroll.contentItem)
                            ? (editorScroll.contentItem.contentY + editorScroll.availableHeight - height)
                            : naturalY
                        if (mainBar.isFooterPinned) {
                            return screenBottomY
                        }
                        return Math.max(naturalY, screenBottomY)
                    }

                    onPinToggled: {
                        mainBar.isFooterPinned = !mainBar.isFooterPinned
                        mainBar.saveFooterPinnedState(mainBar.isFooterPinned)
                        mainBar.paneActivated()
                    }
                    onActivated: mainBar.paneActivated()
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
}
