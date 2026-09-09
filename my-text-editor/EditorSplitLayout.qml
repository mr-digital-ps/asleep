import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: splitLayout

    // Свойства режима сплита
    property int barSize: 36
    property bool isSplit: false
    property real splitRatio: 0.5
    property int activePane: 0 // 0: primary, 1: secondary
    property string dropZone: "" // "left" | "right" | "center" | "sidebar" | ""

    // Свойства документов
    property string primaryFileName: "Новый документ"
    property string secondaryFileName: "Новый документ"
    property bool isPrimaryEmpty: false

    // Доступ к редакторам
    property alias primaryBar: primaryBar
    property alias secondaryBar: secondaryBar
    readonly property var activeEditor: (isSplit && activePane === 1) ? secondaryBar : primaryBar
    readonly property var activeEditorArea: activeEditor.editorArea

    // Сигналы
    signal primaryTitleChanged(string newTitle)
    signal secondaryTitleChanged(string newTitle)
    signal primaryTextChanged(string newText)
    signal secondaryTextChanged(string newText)
    signal primaryDetachRequested()
    signal secondaryDetachRequested()
    signal primaryCloseRequested()
    signal secondaryCloseRequested()
    signal closeSplitRequested()
    signal paneActivated(int paneIndex)

    // Контейнер с панелями редактора
    Item {
        id: panesContainer
        anchors.fill: parent

        // Левая / Основная панель
        MainBar {
            id: primaryBar
            barSize: splitLayout.barSize
            fileName: splitLayout.primaryFileName
            isSplitMode: splitLayout.isSplit
            isActivePane: splitLayout.activePane === 0
            isEmpty: splitLayout.isPrimaryEmpty
            showCloseButton: false

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: splitLayout.isSplit ? Math.round((parent.width - splitterDivider.width) * splitLayout.splitRatio) : parent.width

            onTitleChangedByUser: (newTitle) => splitLayout.primaryTitleChanged(newTitle)
            onDetachRequested: splitLayout.primaryDetachRequested()
            onCloseRequested: splitLayout.primaryCloseRequested()
            onPaneActivated: splitLayout.paneActivated(0)
        }

        // Вертикальный разделитель (виден только при включенном сплите)
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
                color: splitterMouseArea.pressed ? "#888888" : (splitterMouseArea.containsMouse ? "#555555" : "#262626")
            }

            MouseArea {
                id: splitterMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SplitHCursor
                preventStealing: true

                property real startX: 0
                property real startRatio: 0.5

                onPressed: (mouse) => {
                    let globalP = splitterMouseArea.mapToGlobal(mouse.x, mouse.y)
                    startX = globalP.x
                    startRatio = splitLayout.splitRatio
                }

                onPositionChanged: (mouse) => {
                    if (pressed) {
                        let globalP = splitterMouseArea.mapToGlobal(mouse.x, mouse.y)
                        let dx = globalP.x - startX
                        let totalW = panesContainer.width - splitterDivider.width
                        if (totalW > 100) {
                            let newRatio = startRatio + (dx / totalW)
                            splitLayout.splitRatio = Math.max(0.15, Math.min(0.85, newRatio))
                        }
                    }
                }
            }
        }

        // Правая / Вторичная панель
        MainBar {
            id: secondaryBar
            visible: splitLayout.isSplit
            barSize: splitLayout.barSize
            fileName: splitLayout.secondaryFileName
            isSplitMode: splitLayout.isSplit
            isActivePane: splitLayout.activePane === 1
            showCloseButton: true

            anchors.left: splitterDivider.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            onTitleChangedByUser: (newTitle) => splitLayout.secondaryTitleChanged(newTitle)
            onDetachRequested: splitLayout.secondaryDetachRequested()
            onCloseRequested: splitLayout.secondaryCloseRequested()
            onPaneActivated: splitLayout.paneActivated(1)
        }

        Connections {
            target: primaryBar.editorArea
            function onTextChanged() {
                splitLayout.primaryTextChanged(primaryBar.editorArea.text)
            }
        }

        Connections {
            target: secondaryBar.editorArea
            function onTextChanged() {
                if (splitLayout.isSplit) {
                    splitLayout.secondaryTextChanged(secondaryBar.editorArea.text)
                }
            }
        }
    }

    function focusPane(paneIndex) {
        if (paneIndex === 1 && secondaryBar && secondaryBar.editorArea) {
            secondaryBar.editorArea.forceActiveFocus()
        } else if (primaryBar && primaryBar.editorArea) {
            primaryBar.editorArea.forceActiveFocus()
        }
    }

    // =========================================================================
    // ПОЛУПРОЗРАЧНЫЙ ОВЕРЛЕЙ ПРЕДПРОСМОТРА ЗОНЫ ДОКИНГА (DROP PREVIEW OVERLAY)
    // =========================================================================
    Item {
        id: dropOverlayLayer
        anchors.fill: parent
        z: 999
        visible: splitLayout.dropZone === "left" || splitLayout.dropZone === "right" || splitLayout.dropZone === "center"
        opacity: visible ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }

        Rectangle {
            id: previewBox

            readonly property bool isLeft: splitLayout.dropZone === "left"
            readonly property bool isRight: splitLayout.dropZone === "right"
            readonly property bool isCenter: splitLayout.dropZone === "center"

            x: isLeft ? 8 : (isRight ? Math.round(parent.width * 0.5 + 4) : 8)
            y: 8
            width: isCenter ? (parent.width - 16) : Math.max(40, Math.round(parent.width * 0.5 - 12))
            height: Math.max(40, parent.height - 16)

            Behavior on x { NumberAnimation { duration: 120 } }
            Behavior on width { NumberAnimation { duration: 120 } }

            color: "#253b82f6"
            border.color: "#3b82f6"
            border.width: 2
            radius: 8

            RowLayout {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: previewBox.isLeft ? "◧ Разместить слева" : (previewBox.isRight ? "◨ Разместить справа" : "🗖 Заменить в редакторе")
                    color: "#ffffff"
                    font.pixelSize: 13
                    font.bold: true
                }
            }
        }
    }
}
