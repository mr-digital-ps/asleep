import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

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

    signal fileSelected(string url, string name)
    signal fileRenameRequested(string url, string newName)
    signal openInNewWindowRequested(string url, string name)
    signal fileDeleteRequested(string url)
    signal toggleMaximizeClicked()
    signal fileDragStarted(string url, string name, real gx, real gy)
    signal fileDragMoved(real gx, real gy)
    signal fileDragEnded(string url, string name, real gx, real gy)

    clip: true

    // 1. Скроллируемый список файлов
    ScrollView {
        id: filesScroll
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.min(parent.height, filesListView.contentHeight)
        clip: true
        contentWidth: availableWidth
        ScrollBar.vertical.policy: (filesListView.contentHeight > parent.height) ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ListView {
            id: filesListView
            width: filesScroll.availableWidth
            height: contentHeight
            model: fileListContainer.filesModel
            spacing: 1
            boundsBehavior: Flickable.StopAtBounds

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

                onFileSelected: (url, name) => fileListContainer.fileSelected(url, name)
                onFileRenameRequested: (url, newName) => fileListContainer.fileRenameRequested(url, newName)
                onOpenInNewWindowRequested: (url, name) => fileListContainer.openInNewWindowRequested(url, name)
                onFileDeleteRequested: (url) => fileListContainer.fileDeleteRequested(url)
                onFileDragStarted: (url, name, gx, gy) => fileListContainer.fileDragStarted(url, name, gx, gy)
                onFileDragMoved: (gx, gy) => fileListContainer.fileDragMoved(gx, gy)
                onFileDragEnded: (url, name, gx, gy) => fileListContainer.fileDragEnded(url, name, gx, gy)
            }
        }
    }

    // 2. Свободное пространство ниже списка файлов (перетаскивание и максимизация окна)
    MouseArea {
        id: emptySpaceArea
        anchors.top: filesScroll.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        visible: filesScroll.height < fileListContainer.height
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.ArrowCursor

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
