import QtQuick
import QtQuick.Dialogs

Item {
    id: dialogsRoot

    property string currentFolderUrl: ""

    signal folderAccepted(string folderUrl)
    signal fileOpenAccepted(string fileUrl)
    signal fileSaveAccepted(string fileUrl)

    property alias folderDialog: folderDialog
    property alias openDialog: openDialog
    property alias saveDialog: saveDialog

    FolderDialog {
        id: folderDialog
        title: "Выберите рабочую папку"
        currentFolder: dialogsRoot.currentFolderUrl
        onAccepted: {
            dialogsRoot.folderAccepted(selectedFolder.toString())
        }
    }

    FileDialog {
        id: openDialog
        title: "Открыть файл"
        fileMode: FileDialog.OpenFile
        currentFolder: dialogsRoot.currentFolderUrl
        nameFilters: ["Текстовые файлы (*.txt)", "Все файлы (*.*)"]
        defaultSuffix: "txt"
        onAccepted: {
            dialogsRoot.fileOpenAccepted(selectedFile.toString())
        }
    }

    FileDialog {
        id: saveDialog
        title: "Сохранить файл как..."
        fileMode: FileDialog.SaveFile
        currentFolder: dialogsRoot.currentFolderUrl
        nameFilters: ["Текстовые файлы (*.txt)", "Все файлы (*.*)"]
        defaultSuffix: "txt"
        onAccepted: {
            dialogsRoot.fileSaveAccepted(selectedFile.toString())
        }
    }
}
