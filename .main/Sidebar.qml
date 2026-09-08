import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    color: "#252526"

    signal fileSelected(string filePath, string fileName)
    property string selectedPath: ""

    ScrollView {
        anchors.fill: parent
        clip: true

        TreeView {
            id: fileTree
            anchors.fill: parent
            model: fileModel
            rootIndex: rootPathIndex
            boundsBehavior: Flickable.StopAtBounds

            delegate: TreeViewDelegate {
                id: treeDelegate
                implicitHeight: 26

                readonly property var itemIndex: fileTree.index(row, 0)
                readonly property string itemPath: (typeof backend !== "undefined" && backend && itemIndex) ? backend.get_file_path(itemIndex) : ""
                readonly property bool itemIsDir: (typeof backend !== "undefined" && backend && itemIndex) ? backend.is_directory(itemIndex) : false
                readonly property bool isCurrent: root.selectedPath !== "" && root.selectedPath === itemPath

                background: Rectangle {
                    color: treeDelegate.isCurrent
                           ? "#094771"
                           : (treeDelegate.hovered ? "#2a2d2e" : "transparent")
                }

                contentItem: Text {
                    text: (model && model.display !== undefined) ? model.display : ""
                    color: treeDelegate.isCurrent ? "#ffffff" : "#cccccc"
                    font.pixelSize: 13
                    font.family: "Segoe UI"
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    if (itemIndex && !itemIsDir && itemPath !== "") {
                        root.selectedPath = itemPath
                        root.fileSelected(itemPath, model.display)
                    } else if (itemIsDir) {
                        fileTree.toggleExpanded(row)
                    }
                }

                onDoubleClicked: {
                    if (itemIsDir) {
                        fileTree.toggleExpanded(row)
                    } else if (itemPath !== "") {
                        root.selectedPath = itemPath
                        root.fileSelected(itemPath, model.display)
                    }
                }
            }
        }
    }
}
