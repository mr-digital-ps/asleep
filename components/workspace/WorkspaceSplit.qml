import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../graph"
import "../theme"

Item {
    id: splitLayout

    // Свойства режима сплита
    property int barSize: 36
    property bool isSplit: false
    property real splitRatio: 0.5
    property int activePane: 0 // 0: primary, 1: secondary
    property string dropZone: "" // "left" | "right" | "center" | "sidebar" | ""

    // Свойства графа связей
    property bool isPrimaryGraphVisible: false
    property bool isSecondaryGraphVisible: false
    property bool isPrimaryLocalGraph: false
    property bool isSecondaryLocalGraph: false
    readonly property bool isGraphVisible: isPrimaryGraphVisible || (isSplit && isSecondaryGraphVisible)
    property string currentFolderUrl: ""
    property string currentFolderName: ""
    property var openFileUrls: []

    onIsSplitChanged: {
        if (!isSplit) {
            if (activePane === 1) {
                isPrimaryGraphVisible = isSecondaryGraphVisible
                isPrimaryLocalGraph = isSecondaryLocalGraph
            }
            isSecondaryGraphVisible = false
            isSecondaryLocalGraph = false
        }
    }

    function toggleGraph() {
        if (isSplit && activePane === 1) {
            if (isSecondaryGraphVisible && isSecondaryLocalGraph) {
                isSecondaryLocalGraph = false
            } else {
                isSecondaryGraphVisible = !isSecondaryGraphVisible
                isSecondaryLocalGraph = false
            }
        } else {
            if (isPrimaryGraphVisible && isPrimaryLocalGraph) {
                isPrimaryLocalGraph = false
            } else {
                isPrimaryGraphVisible = !isPrimaryGraphVisible
                isPrimaryLocalGraph = false
            }
        }
    }

    function toggleLocalGraph() {
        if (isSplit && activePane === 1) {
            if (isSecondaryGraphVisible && !isSecondaryLocalGraph) {
                isSecondaryLocalGraph = true
            } else if (isSecondaryGraphVisible && isSecondaryLocalGraph) {
                isSecondaryGraphVisible = false
                isSecondaryLocalGraph = false
            } else {
                isSecondaryLocalGraph = true
                isSecondaryGraphVisible = true
            }
        } else {
            if (isPrimaryGraphVisible && !isPrimaryLocalGraph) {
                isPrimaryLocalGraph = true
            } else if (isPrimaryGraphVisible && isPrimaryLocalGraph) {
                isPrimaryGraphVisible = false
                isPrimaryLocalGraph = false
            } else {
                isPrimaryLocalGraph = true
                isPrimaryGraphVisible = true
            }
        }
    }

    function closeGraph() {
        if (isSplit && activePane === 1) {
            if (isSecondaryGraphVisible) {
                isSecondaryGraphVisible = false
                isSecondaryLocalGraph = false
                return
            }
        }
        if (isPrimaryGraphVisible) {
            isPrimaryGraphVisible = false
            isPrimaryLocalGraph = false
            return
        }
        if (isSecondaryGraphVisible) {
            isSecondaryGraphVisible = false
            isSecondaryLocalGraph = false
        }
    }

    function closeAllGraphs() {
        isPrimaryGraphVisible = false
        isPrimaryLocalGraph = false
        isSecondaryGraphVisible = false
        isSecondaryLocalGraph = false
    }

    // Свойства документов
    property string primaryFileName: "Новый документ"
    property string primaryFileUrl: ""
    property string secondaryFileName: "Новый документ"
    property string secondaryFileUrl: ""
    property bool isPrimaryEmpty: false

    // Доступ к редакторам
    property alias primaryBar: primaryBar
    property alias secondaryBar: secondaryBar
    readonly property var activeEditor: (isSplit && activePane === 1) ? secondaryBar : primaryBar
    readonly property var activeEditorArea: activeEditor.editorArea

    // Сигналы
    signal primaryTitleChanged(string newTitle)
    signal secondaryTitleChanged(string newTitle)
    signal primaryTextChanged()
    signal secondaryTextChanged()
    signal primaryDetachRequested()
    signal secondaryDetachRequested()
    signal primaryCloseRequested()
    signal secondaryCloseRequested()
    signal paneActivated(int paneIndex)
    signal fileDragStarted(int paneIndex, string url, string name, real gx, real gy)
    signal fileDragMoved(real gx, real gy)
    signal fileDragEnded(int paneIndex, string url, string name, real gx, real gy)
    signal saveRequested()
    signal openRequested()
    signal openSplitRequested()
    signal newRequested()
    signal newSplitRequested()
    signal toggleGraphRequested()
    signal toggleLocalGraphRequested()
    signal toggleSplitRequested()
    signal nodeSelected(string fileUrl, string label)
    signal closeGraphRequested()
    signal openStructureRequested()

    // Контейнер с панелями
    Item {
        id: panesContainer
        anchors.fill: parent

        // Левая / Основная панель
        WorkspacePane {
            id: primaryBar
            visible: true
            barSize: splitLayout.barSize
            fileName: splitLayout.primaryFileName
            fileUrl: splitLayout.primaryFileUrl
            isSplitMode: splitLayout.isSplit
            isActivePane: splitLayout.activePane === 0
            isEmpty: splitLayout.isPrimaryEmpty

            isGraphMode: splitLayout.isPrimaryGraphVisible
            isLocalGraphMode: splitLayout.isPrimaryLocalGraph
            folderUrl: splitLayout.currentFolderUrl
            currentFolderName: splitLayout.currentFolderName
            openFileUrls: splitLayout.openFileUrls

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: splitLayout.isSplit ? Math.round((parent.width - splitterDivider.width) * splitLayout.splitRatio) : parent.width

            onTitleChangedByUser: (newTitle) => splitLayout.primaryTitleChanged(newTitle)
            onDetachRequested: splitLayout.primaryDetachRequested()
            onCloseRequested: splitLayout.primaryCloseRequested()
            onPaneActivated: splitLayout.paneActivated(0)
            onFileDragStarted: (url, name, gx, gy) => splitLayout.fileDragStarted(0, url, name, gx, gy)
            onFileDragMoved: (gx, gy) => splitLayout.fileDragMoved(gx, gy)
            onFileDragEnded: (url, name, gx, gy) => splitLayout.fileDragEnded(0, url, name, gx, gy)
            onSaveRequested: splitLayout.saveRequested()
            onOpenRequested: splitLayout.openRequested()
            onOpenSplitRequested: splitLayout.openSplitRequested()
            onNewRequested: splitLayout.newRequested()
            onNewSplitRequested: splitLayout.newSplitRequested()
            onToggleGraphRequested: {
                splitLayout.isPrimaryGraphVisible = !splitLayout.isPrimaryGraphVisible
                splitLayout.toggleGraphRequested()
            }
            onToggleSplitRequested: splitLayout.toggleSplitRequested()
            onCloseGraphRequested: {
                splitLayout.isPrimaryGraphVisible = false
                splitLayout.closeGraphRequested()
            }
            onNodeSelected: (fUrl, lbl) => {
                splitLayout.isPrimaryGraphVisible = false
                splitLayout.nodeSelected(fUrl, lbl)
            }
            onOpenStructureRequested: splitLayout.openStructureRequested()
        }

        // Вертикальный разделитель
        Item {
            id: splitterDivider
            visible: splitLayout.isSplit
            width: 7
            anchors.left: primaryBar.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            Rectangle {
                anchors.centerIn: parent
                width: 1
                height: parent.height
                color: splitterMouseArea.pressed ? Theme.accentColor : (splitterMouseArea.containsMouse ? Theme.borderHover : Theme.borderColor)
            }

            MouseArea {
                id: splitterMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SplitHCursor
                preventStealing: true

                onPositionChanged: (mouse) => {
                    if (pressed) {
                        let totalW = panesContainer.width - splitterDivider.width
                        if (totalW > 100) {
                            let pos = splitterMouseArea.mapToItem(panesContainer, mouse.x, 0)
                            let newRatio = pos.x / totalW
                            splitLayout.splitRatio = Math.max(0.15, Math.min(0.85, newRatio))
                        }
                    }
                }
            }
        }

        // Правая / Вторичная панель
        WorkspacePane {
            id: secondaryBar
            visible: splitLayout.isSplit
            barSize: splitLayout.barSize
            fileName: splitLayout.secondaryFileName
            fileUrl: splitLayout.secondaryFileUrl
            isSplitMode: splitLayout.isSplit
            isActivePane: splitLayout.activePane === 1

            isGraphMode: splitLayout.isSplit && splitLayout.isSecondaryGraphVisible
            isLocalGraphMode: splitLayout.isSecondaryLocalGraph
            folderUrl: splitLayout.currentFolderUrl
            currentFolderName: splitLayout.currentFolderName
            openFileUrls: splitLayout.openFileUrls

            anchors.left: splitterDivider.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            onTitleChangedByUser: (newTitle) => splitLayout.secondaryTitleChanged(newTitle)
            onDetachRequested: splitLayout.secondaryDetachRequested()
            onCloseRequested: splitLayout.secondaryCloseRequested()
            onPaneActivated: splitLayout.paneActivated(1)
            onFileDragStarted: (url, name, gx, gy) => splitLayout.fileDragStarted(1, url, name, gx, gy)
            onFileDragMoved: (gx, gy) => splitLayout.fileDragMoved(gx, gy)
            onFileDragEnded: (url, name, gx, gy) => splitLayout.fileDragEnded(1, url, name, gx, gy)
            onSaveRequested: splitLayout.saveRequested()
            onOpenRequested: splitLayout.openRequested()
            onOpenSplitRequested: splitLayout.openSplitRequested()
            onNewRequested: splitLayout.newRequested()
            onNewSplitRequested: splitLayout.newSplitRequested()
            onToggleGraphRequested: {
                splitLayout.isSecondaryGraphVisible = !splitLayout.isSecondaryGraphVisible
                splitLayout.toggleGraphRequested()
            }
            onToggleSplitRequested: splitLayout.toggleSplitRequested()
            onCloseGraphRequested: {
                splitLayout.isSecondaryGraphVisible = false
                splitLayout.closeGraphRequested()
            }
            onNodeSelected: (fUrl, lbl) => {
                splitLayout.isSecondaryGraphVisible = false
                splitLayout.nodeSelected(fUrl, lbl)
            }
            onOpenStructureRequested: splitLayout.openStructureRequested()
        }

        Connections {
            target: primaryBar.editorArea
            function onTextChanged() {
                splitLayout.primaryTextChanged()
            }
        }

        Connections {
            target: secondaryBar.editorArea
            function onTextChanged() {
                if (splitLayout.isSplit) {
                    splitLayout.secondaryTextChanged()
                }
            }
        }
    }

    // Оверлей предпросмотра зоны сплита
    Item {
        id: dropOverlayLayer
        anchors.fill: parent
        z: 999
        visible: splitLayout.dropZone === "left" || splitLayout.dropZone === "right" || splitLayout.dropZone === "center"
        opacity: visible ? 1 : 0

        Rectangle {
            id: previewBox

            readonly property bool isLeft: splitLayout.dropZone === "left"
            readonly property bool isRight: splitLayout.dropZone === "right"
            readonly property bool isCenter: splitLayout.dropZone === "center"

            x: {
                if (splitLayout.isSplit) {
                    return isLeft ? 8 : (splitterDivider.x + splitterDivider.width + 8)
                }
                return isLeft ? 8 : (isRight ? Math.round(parent.width * 0.5 + 4) : 8)
            }
            y: 8
            width: {
                if (splitLayout.isSplit) {
                    return isLeft ? Math.max(40, primaryBar.width - 16) : Math.max(40, secondaryBar.width - 16)
                }
                return isCenter ? (parent.width - 16) : Math.max(40, Math.round(parent.width * 0.5 - 12))
            }
            height: Math.max(40, parent.height - 16)

            color: Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.1)
            border.color: Theme.accentColor
            border.width: 1.5
            radius: 8

            Rectangle {
                anchors.centerIn: parent
                color: Theme.bgDialog
                border.color: Theme.borderHover
                border.width: 1
                radius: 6
                implicitWidth: hintLabel.implicitWidth + 28
                implicitHeight: hintLabel.implicitHeight + 14

                Text {
                    id: hintLabel
                    anchors.centerIn: parent
                    text: {
                        if (splitLayout.isSplit) {
                            return previewBox.isLeft ? "◧ Разместить в левой панели" : "◨ Разместить в правой панели"
                        }
                        return previewBox.isLeft ? "◧ Разместить слева" : (previewBox.isRight ? "◨ Разместить справа" : "🗖 Открыть в редакторе")
                    }
                    color: Theme.textPrimary
                    font.pixelSize: 13
                    font.bold: true
                }
            }
        }
    }
}
