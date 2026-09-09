import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: fileItem

    property int barSize: 36
    property bool expanded: true
    property int fileIndex: 0
    property string fileName: ""
    property string fileUrl: ""
    property bool isActive: false
    property bool isBackgroundOpen: false
    property bool isEditing: false

    signal fileSelected(string url, string name)
    signal fileRenameRequested(string url, string newName)
    signal openInNewWindowRequested(string url, string name)
    signal fileDeleteRequested(string url)
    signal fileDragStarted(string url, string name, real gx, real gy)
    signal fileDragMoved(real gx, real gy)
    signal fileDragEnded(string url, string name, real gx, real gy)

    width: parent ? parent.width : 200
    height: barSize

    color: isActive ? "#262626" : (isBackgroundOpen ? "#1e1e1e" : (fileHover.hovered ? "#222222" : "transparent"))
    opacity: fileHover.isDraggingFile ? 0.45 : 1.0

    Behavior on color {
        ColorAnimation { duration: 120 }
    }

    // 0. Акцентный индикатор активного / фонового документа на левой кромке
    Rectangle {
        id: activeIndicator
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: fileItem.isActive ? 3 : (fileItem.isBackgroundOpen ? 2 : 0)
        height: fileItem.isActive ? 20 : (fileItem.isBackgroundOpen ? 14 : 0)
        radius: 1.5
        color: fileItem.isActive ? "#ffffff" : "#666666"
        visible: fileItem.isActive || fileItem.isBackgroundOpen

        Behavior on width { NumberAnimation { duration: 120 } }
        Behavior on height { NumberAnimation { duration: 120 } }
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    // Контекстное меню файла по ПКМ
    Menu {
        id: fileMenu
        MenuItem {
            text: "✏️  Переименовать"
            onTriggered: {
                if (fileItem.expanded) {
                    fileItem.isEditing = true
                    fileRenameInput.isCancelled = false
                    fileRenameInput.text = fileItem.fileName
                    fileRenameInput.forceActiveFocus()
                    fileRenameInput.selectAll()
                }
            }
        }
        MenuItem {
            text: "🗖  Открыть в новом окне"
            onTriggered: fileItem.openInNewWindowRequested(fileItem.fileUrl, fileItem.fileName)
        }
        MenuItem {
            text: "🗑️  Удалить файл"
            onTriggered: fileItem.fileDeleteRequested(fileItem.fileUrl)
        }
    }

    MouseArea {
        id: fileHover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        visible: !fileItem.isEditing
        preventStealing: true

        property real pressX: 0
        property real pressY: 0
        property bool isLeftPressed: false
        property bool isDraggingFile: false
        property bool wasDragged: false

        onPressed: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                pressX = mouse.x
                pressY = mouse.y
                isLeftPressed = true
                isDraggingFile = false
                wasDragged = false
            } else {
                isLeftPressed = false
            }
        }

        onPositionChanged: (mouse) => {
            if (!isLeftPressed) return

            let deltaX = mouse.x - pressX
            let deltaY = mouse.y - pressY
            let dist = Math.hypot(deltaX, deltaY)
            let globalPoint = fileHover.mapToGlobal(mouse.x, mouse.y)

            if (!isDraggingFile) {
                if (dist > 8) {
                    isDraggingFile = true
                    wasDragged = true
                    // НЕ ВЫЗЫВАЕМ fileSelected — файл перетаскивается, а не открывается!
                    fileItem.fileDragStarted(fileItem.fileUrl, fileItem.fileName, globalPoint.x, globalPoint.y)
                }
            } else {
                fileItem.fileDragMoved(globalPoint.x, globalPoint.y)
            }
        }

        onReleased: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                isLeftPressed = false
                if (isDraggingFile) {
                    isDraggingFile = false
                    let globalPoint = fileHover.mapToGlobal(mouse.x, mouse.y)
                    fileItem.fileDragEnded(fileItem.fileUrl, fileItem.fileName, globalPoint.x, globalPoint.y)
                }
            }
        }

        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                if (!wasDragged) {
                    // Файл открывается / переключается ТОЛЬКО при чистом клике!
                    fileItem.fileSelected(fileItem.fileUrl, fileItem.fileName)
                }
            } else if (mouse.button === Qt.RightButton) {
                fileMenu.popup()
            }
        }

        onDoubleClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton && fileItem.expanded && !wasDragged) {
                fileItem.isEditing = true
                fileRenameInput.isCancelled = false
                fileRenameInput.text = fileItem.fileName
                fileRenameInput.forceActiveFocus()
                fileRenameInput.selectAll()
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Порядковый номер файла
        Text {
            Layout.preferredWidth: fileItem.barSize
            Layout.fillHeight: true
            text: (fileItem.fileIndex + 1 < 10 ? "0" : "") + (fileItem.fileIndex + 1)
            color: fileItem.isActive ? "#ffffff" : (fileItem.isBackgroundOpen ? "#888888" : "#444444")
            Behavior on color { ColorAnimation { duration: 120 } }
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.family: "Consolas, Courier New, monospace"
            font.bold: fileItem.isActive
            font.pixelSize: 12
        }

        // Имя файла
        Text {
            visible: fileItem.expanded && !fileItem.isEditing
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.rightMargin: 12
            text: fileItem.fileName
            color: fileItem.isActive ? "#ffffff" : (fileItem.isBackgroundOpen ? "#aaaaaa" : (fileHover.hovered ? "#dddddd" : "#777777"))
            Behavior on color { ColorAnimation { duration: 120 } }
            font.bold: fileItem.isActive
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            font.pixelSize: 13
        }

        // Поле ввода для переименования
        TextField {
            id: fileRenameInput
            visible: fileItem.expanded && fileItem.isEditing
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            Layout.rightMargin: 12
            font.pixelSize: 12
            color: "#ffffff"
            selectByMouse: true
            property bool isCancelled: false

            background: Rectangle {
                color: "#1a1a1a"
                border.color: "#ffffff"
                radius: 2
            }

            Keys.onEscapePressed: {
                isCancelled = true
                fileItem.isEditing = false
            }

            onAccepted: {
                if (!isCancelled && text.trim() !== "") {
                    fileItem.isEditing = false
                    fileItem.fileRenameRequested(fileItem.fileUrl, text.trim())
                }
                isCancelled = false
            }

            onActiveFocusChanged: {
                if (!activeFocus && fileItem.isEditing) {
                    fileItem.isEditing = false
                    if (!isCancelled && text.trim() !== "") {
                        fileItem.fileRenameRequested(fileItem.fileUrl, text.trim())
                    }
                    isCancelled = false
                }
            }
        }
    }

    ToolTip.visible: Boolean(fileHover && fileHover.hovered && !fileItem.expanded)
    ToolTip.text: fileItem.fileName
}
