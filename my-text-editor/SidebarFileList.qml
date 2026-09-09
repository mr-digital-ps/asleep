import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ScrollView {
    id: filesScroll

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
    contentWidth: availableWidth

    background: MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onPressed: {
            if (filesScroll.appWindow) filesScroll.appWindow.startSystemMove()
        }
        onDoubleClicked: filesScroll.toggleMaximizeClicked()
    }

    ListView {
        id: filesListView
        width: filesScroll.availableWidth
        height: Math.max(filesScroll.availableHeight, contentHeight)
        model: filesScroll.filesModel
        spacing: 1
        boundsBehavior: Flickable.StopAtBounds

        // Фоновое перемещение окна внутри ListView на свободном месте
        MouseArea {
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.LeftButton
            onPressed: {
                if (filesScroll.appWindow) filesScroll.appWindow.startSystemMove()
            }
            onDoubleClicked: filesScroll.toggleMaximizeClicked()
        }

        delegate: SidebarFileItem {
            barSize: filesScroll.barSize
            expanded: filesScroll.expanded
            fileIndex: index
            fileName: (typeof model !== "undefined" && model && model.name) ? model.name : ""
            fileUrl: (typeof model !== "undefined" && model && model.fileUrl) ? model.fileUrl : ""

            isActive: (fileUrl !== "" && filesScroll.currentFileUrl !== "") ? (fileUrl === filesScroll.currentFileUrl) : false

            isBackgroundOpen: {
                if (!fileUrl) return false
                if (isActive) return false

                // 1. Файл открыт во второй панели сплита
                if (filesScroll.isSplit && filesScroll.backgroundFileUrl && fileUrl === filesScroll.backgroundFileUrl) {
                    return true
                }

                // 2. Файл открыт в другом окне приложения
                if (filesScroll.externalWindowFiles && filesScroll.externalWindowFiles.indexOf(fileUrl) !== -1) {
                    return true
                }

                return false
            }

            onFileSelected: (url, name) => filesScroll.fileSelected(url, name)
            onFileRenameRequested: (url, newName) => filesScroll.fileRenameRequested(url, newName)
            onOpenInNewWindowRequested: (url, name) => filesScroll.openInNewWindowRequested(url, name)
            onFileDeleteRequested: (url) => filesScroll.fileDeleteRequested(url)
            onFileDragStarted: (url, name, gx, gy) => filesScroll.fileDragStarted(url, name, gx, gy)
            onFileDragMoved: (gx, gy) => filesScroll.fileDragMoved(gx, gy)
            onFileDragEnded: (url, name, gx, gy) => filesScroll.fileDragEnded(url, name, gx, gy)
        }
    }
}
