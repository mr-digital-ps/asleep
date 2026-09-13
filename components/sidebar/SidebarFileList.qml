import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Item {
    id: fileListContainer

    property var appWindow: null
    property var filesModel: null
    property int barSize: 36
    property bool expanded: true
    property string currentFileUrl: ""
    property string backgroundFileUrl: ""
    property bool isSplit: false
    property var tabsModel: null
    property var externalWindowFiles: []

    signal fileSelected(string url, string name, bool isShift)
    signal fileRenameRequested(string url, string newName)
    signal openInNewWindowRequested(string url, string name)
    signal fileDeleteRequested(string url)
    signal toggleMaximizeClicked()
    signal fileDragStarted(string url, string name, real gx, real gy)
    signal fileDragMoved(real gx, real gy)
    signal fileDragEnded(string url, string name, real gx, real gy)

    clip: true

    // 1. Скроллируемый список файлов (нативный скролл ListView)
    ListView {
        id: filesListView
        objectName: "filesListView"
        anchors.fill: parent
        clip: true
        model: fileListContainer.filesModel
        spacing: 1
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        WheelHandler {
            target: filesListView
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                let dy = -event.angleDelta.y
                let newY = filesListView.contentY + dy
                let maxY = Math.max(0, filesListView.contentHeight - filesListView.height)
                filesListView.contentY = Math.max(0, Math.min(maxY, newY))
            }
        }

        delegate: SidebarFileItem {
            barSize: fileListContainer.barSize
            expanded: fileListContainer.expanded
            fileIndex: index
            fileName: (typeof model !== "undefined" && model && model.name) ? model.name : ""
            fileUrl: (typeof model !== "undefined" && model && model.fileUrl) ? model.fileUrl : ""

            isActive: (fileUrl !== "" && fileListContainer.currentFileUrl !== "") ? (fileUrl === fileListContainer.currentFileUrl) : false

            isBackgroundOpen: {
                if (!fileUrl) return false
                if (isActive) return false

                // Файл открыт во второй панели сплита
                if (fileListContainer.isSplit && fileListContainer.backgroundFileUrl && fileUrl === fileListContainer.backgroundFileUrl) {
                    return true
                }

                // Файл открыт в другом окне приложения
                if (fileListContainer.externalWindowFiles && fileListContainer.externalWindowFiles.indexOf(fileUrl) !== -1) {
                    return true
                }

                return false
            }

            onFileSelected: (url, name, isShift) => fileListContainer.fileSelected(url, name, isShift)
            onFileRenameRequested: (url, newName) => fileListContainer.fileRenameRequested(url, newName)
            onOpenInNewWindowRequested: (url, name) => fileListContainer.openInNewWindowRequested(url, name)
            onFileDeleteRequested: (url) => fileListContainer.fileDeleteRequested(url)
            onFileDragStarted: (url, name, gx, gy) => fileListContainer.fileDragStarted(url, name, gx, gy)
            onFileDragMoved: (gx, gy) => fileListContainer.fileDragMoved(gx, gy)
            onFileDragEnded: (url, name, gx, gy) => fileListContainer.fileDragEnded(url, name, gx, gy)
        }
    }

    // 2. Скроллбар сайдбара (виден только при переполнении списка файлов)
    ScrollBar {
        id: sidebarVBar
        objectName: "sidebarVBar"
        anchors.right: parent.right
        anchors.rightMargin: 2
        width: 6
        anchors.top: parent.top
        anchors.topMargin: 4
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        z: 20
        visible: filesListView.contentHeight > filesListView.height
        size: (filesListView.contentHeight > 0)
            ? Math.min(1.0, Math.max(0.06, filesListView.height / filesListView.contentHeight)) : 1.0
        position: (filesListView.contentHeight > filesListView.height)
            ? Math.max(0.0, Math.min(1.0 - size, filesListView.contentY / filesListView.contentHeight)) : 0.0
        active: true
        orientation: Qt.Vertical

        onPositionChanged: {
            if (pressed) {
                let maxScroll = filesListView.contentHeight - filesListView.height
                if (maxScroll > 0 && (1.0 - size) > 0) {
                    filesListView.contentY = (position / (1.0 - size)) * maxScroll
                }
            }
        }

        contentItem: Rectangle {
            implicitWidth: sidebarVBar.hovered || sidebarVBar.pressed ? 6 : 4
            implicitHeight: 24
            radius: 3
            color: sidebarVBar.pressed ? Theme.textSelected : (sidebarVBar.hovered ? Theme.scrollbarHover : Theme.scrollbarThumb)
            anchors.right: parent.right

            Behavior on implicitWidth { NumberAnimation { duration: 100 } }
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        background: Rectangle {
            anchors.right: parent.right
            width: 4
            height: parent.height
            radius: 2
            color: "transparent"
        }
    }

    // 3. Свободное пространство ниже списка файлов (перетаскивание и максимизация окна)
    MouseArea {
        id: emptySpaceArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.max(0, fileListContainer.height - filesListView.contentHeight)
        visible: height > 0
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.ArrowCursor
        z: 5
        onPressed: (mouse) => {
            if (mouse.button === Qt.LeftButton && fileListContainer.appWindow) {
                fileListContainer.appWindow.startSystemMove()
            }
        }
        onDoubleClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                fileListContainer.toggleMaximizeClicked()
            }
        }
    }
}
