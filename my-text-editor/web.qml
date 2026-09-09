import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "logic.js" as Logic
import "tabs.js" as Tabs

Rectangle {
    id: root
    anchors.fill: parent
    color: "#141414"

    // Ссылка на родительское ApplicationWindow
    property var appWindow: null

    // Переменные текущего активного файла
    property string currentFileUrl: ""
    property string currentFileName: "Новый документ"
    property int barSize: 36

    // Видимость боковой панели (сайдбара)
    property bool isSidebarVisible: true

    // Параметры для клонирования окна
    property string initialFileUrl: ""
    property string initialTitle: ""
    property string initialContent: ""
    property bool startWithSidebarHidden: false

    // Текущая рабочая папка
    property string currentFolderUrl: (typeof backend !== "undefined" && backend) ? backend.get_default_folder() : ""
    property string currentFolderName: (typeof backend !== "undefined" && backend && currentFolderUrl) ? backend.get_folder_name(currentFolderUrl) : "my-text-editor"

    // =========================================================================
    // РЕЖИМ СПЛИТА (SPLIT VIEW)
    // =========================================================================
    property bool isSplit: false
    property int primaryTabIndex: 0
    property int secondaryTabIndex: -1
    property int activePane: 0 // 0: primary, 1: secondary
    property string dropZone: "" // "left" | "right" | "center" | "sidebar" | ""
    property string primaryFileName: "Новый документ"
    property string secondaryFileName: "Новый документ"

    property alias editorArea: splitLayout.activeEditorArea
    property alias splitLayout: splitLayout

    // =========================================================================
    // МОДЕЛЬ ВКЛАДОК, ФАЙЛОВ ПАПКИ И ОТКРЕПЛЕННЫХ ОКОН
    // =========================================================================
    property int currentTabIndex: 0
    property var externalWindowFiles: []
    property string draggingFileUrl: ""
    property string draggingFileName: ""
    property var draggedNewWin: null

    // Таймер аппаратного отслеживания курсора во время перетаскивания (60 FPS)
    Timer {
        id: dragTrackerTimer
        interval: 16
        repeat: true
        running: false
        onTriggered: Tabs.pollCursorState(root, sideBar)
    }

    property alias tabsModel: tabsModel
    property alias folderFilesModel: folderFilesModel
    property alias dragTrackerTimer: dragTrackerTimer
    property alias sideBar: sideBar

    ListModel {
        id: tabsModel
        ListElement {
            title: "Новый документ"
            fileUrl: ""
            content: ""
            isDetached: false
        }
    }

    // Модель файлов в текущей рабочей папке
    ListModel {
        id: folderFilesModel
    }

    function reloadFolderFiles() {
        if (typeof backend === "undefined" || !backend || !root.currentFolderUrl) return
        let files = backend.get_folder_files(root.currentFolderUrl)
        folderFilesModel.clear()
        for (let i = 0; i < files.length; i++) {
            folderFilesModel.append(files[i])
        }
    }

    Connections {
        target: (typeof backend !== "undefined") ? backend : null
        function onFolderFilesChanged() {
            root.reloadFolderFiles()
        }
    }

    function openFileFromFolder(fileUrl, fileName) {
        if (typeof backend === "undefined" || !backend || !fileUrl) return

        // 1. Если файл уже открыт в одной из панелей — просто активируем её
        if (root.tabsModel.count > 0) {
            if (root.primaryTabIndex >= 0 && root.primaryTabIndex < root.tabsModel.count) {
                let pTab = root.tabsModel.get(root.primaryTabIndex)
                if (pTab && pTab.fileUrl === fileUrl) {
                    Tabs.setActivePane(root, 0)
                    return
                }
            }
            if (root.isSplit && root.secondaryTabIndex >= 0 && root.secondaryTabIndex < root.tabsModel.count) {
                let sTab = root.tabsModel.get(root.secondaryTabIndex)
                if (sTab && sTab.fileUrl === fileUrl) {
                    Tabs.setActivePane(root, 1)
                    return
                }
            }
        }

        // Сохраняем текущий текст перед открытием нового файла
        Tabs.syncCurrentPaneText(root)

        let content = backend.read_file(fileUrl)

        // Если экран был пуст (все вкладки закрыты)
        if (root.tabsModel.count === 0 || root.primaryTabIndex < 0) {
            root.tabsModel.clear()
            root.tabsModel.append({
                title: fileName,
                fileUrl: fileUrl,
                content: content,
                isDetached: false
            })
            root.primaryTabIndex = 0
            root.secondaryTabIndex = -1
            root.isSplit = false
            root.activePane = 0
            Tabs.syncEditorsFromModel(root)
            Tabs.setActivePane(root, 0)
            return
        }

        // Прямое открытие в текущей активной панели без накопления скрытых вкладок
        let activeIdx = (root.isSplit && root.activePane === 1) ? root.secondaryTabIndex : root.primaryTabIndex
        if (activeIdx >= 0 && activeIdx < root.tabsModel.count) {
            root.tabsModel.setProperty(activeIdx, "title", fileName)
            root.tabsModel.setProperty(activeIdx, "fileUrl", fileUrl)
            root.tabsModel.setProperty(activeIdx, "content", content)
            Tabs.syncEditorsFromModel(root)
            Tabs.setActivePane(root, root.activePane)
        } else {
            root.tabsModel.append({
                title: fileName,
                fileUrl: fileUrl,
                content: content,
                isDetached: false
            })
            Tabs.switchToTab(root, root.tabsModel.count - 1)
        }
    }

    // Делегированные методы управления вкладками и сплитом
    function createNewTab() { Tabs.createNewTab(root) }
    function switchToTab(index) { Tabs.switchToTab(root, index) }
    function closeTab(index) { Tabs.closeTab(root, index) }
    function renameTab(index, newTitle) { Tabs.renameTab(root, index, newTitle) }
    function detachTab(index, spawnX, spawnY) { Tabs.detachTab(root, index, spawnX, spawnY) }
    function reattachTab(index, content, title) { Tabs.reattachTab(root, index, content, title) }
    function toggleSplit() { Tabs.toggleSplit(root) }
    function closeSplit() { Tabs.closeSplit(root) }
    function setActivePane(paneIndex) { Tabs.setActivePane(root, paneIndex) }
    function openInNewWindow(fileUrl, fileName, wx, wy) { Tabs.openInNewWindow(root, fileUrl, fileName, wx, wy) }
    function handleFileDragMoved(gx, gy) { Tabs.handleFileDragMoved(root, gx, gy) }
    function handleFileDragEnded(fileUrl, fileName, gx, gy) { Tabs.handleFileDragEnded(root, fileUrl, fileName, gx, gy) }
    function dockExternalTab(fileUrl, fileName, content, zone) { Tabs.dockExternalTab(root, fileUrl, fileName, content, zone) }

    // Переключение видимости боковой панели (сайдбара)
    function toggleSidebar() {
        sideBar.toggleSidebar()
        root.isSidebarVisible = sideBar.isSidebarVisible
    }

    // Клонирование окна приложения со скрытым сайдбаром (для открепленного файла)
    function spawnClonedAppWindow(fileUrl, title, content, wx, wy, ww, wh) {
        let comp = Qt.createComponent("window.qml")
        if (comp.status === Component.Ready) {
            let winW = Math.max(750, ww || 850)
            let winH = Math.max(550, wh || 600)
            let appWin = root.Window.window
            let newWin = comp.createObject(null, {
                x: wx || (appWin ? (appWin.x + 50) : 100),
                y: wy || (appWin ? (appWin.y + 50) : 100),
                width: winW,
                height: winH,
                initialFileUrl: fileUrl || "",
                initialTitle: title || "Документ",
                initialContent: content || "",
                startWithSidebarHidden: true
            })
            if (newWin && fileUrl) {
                root.registerExternalFile(fileUrl, newWin)
            }
            return newWin
        } else {
            console.log("[QML] Ошибка создания нового окна приложения:", comp.errorString())
            return null
        }
    }

    function registerExternalFile(fUrl, win) {
        if (!fUrl) return
        let list = (root.externalWindowFiles || []).slice()
        if (list.indexOf(fUrl) === -1) {
            list.push(fUrl)
            root.externalWindowFiles = list
        }
        if (win && win.closing) {
            win.closing.connect(function() {
                if (root && typeof root.unregisterExternalFile === "function") {
                    root.unregisterExternalFile(fUrl)
                }
            })
        }
    }

    function unregisterExternalFile(fUrl) {
        let list = (root.externalWindowFiles || []).slice()
        let idx = list.indexOf(fUrl)
        if (idx !== -1) {
            list.splice(idx, 1)
            root.externalWindowFiles = list
        }
    }

    // =========================================================================
    // ДИАЛОГИ И ШОРТКАТЫ
    // =========================================================================
    FolderDialog {
        id: folderDialog
        title: "Выберите рабочую папку"
        currentFolder: root.currentFolderUrl
        onAccepted: {
            root.currentFolderUrl = selectedFolder.toString()
            root.currentFolderName = backend.get_folder_name(root.currentFolderUrl)
            if (typeof backend !== "undefined" && backend) {
                backend.save_last_folder(root.currentFolderUrl)
                backend.watch_folder(root.currentFolderUrl)
            }
            openDialog.currentFolder = root.currentFolderUrl
            saveDialog.currentFolder = root.currentFolderUrl
            root.reloadFolderFiles()
        }
    }

    FileDialog {
        id: openDialog
        title: "Открыть файл"
        fileMode: FileDialog.OpenFile
        currentFolder: root.currentFolderUrl
        nameFilters: ["Markdown (*.md)", "Текстовые файлы (*.txt)", "Все файлы (*.*)"]
        defaultSuffix: "md"
        onAccepted: {
            let content = backend.read_file(selectedFile)
            let name = backend.get_filename(selectedFile)

            let targetIndex = (root.isSplit && root.activePane === 1) ? root.secondaryTabIndex : root.primaryTabIndex
            let curTab = (targetIndex >= 0 && targetIndex < tabsModel.count) ? tabsModel.get(targetIndex) : null

            if (curTab && !curTab.isDetached && curTab.fileUrl === "" && root.editorArea.text === "") {
                tabsModel.setProperty(targetIndex, "title", name)
                tabsModel.setProperty(targetIndex, "fileUrl", selectedFile)
                tabsModel.setProperty(targetIndex, "content", content)
                Tabs.syncEditorsFromModel(root)
            } else {
                tabsModel.append({
                    title: name,
                    fileUrl: selectedFile,
                    content: content,
                    isDetached: false
                })
                root.switchToTab(tabsModel.count - 1)
            }
        }
    }

    FileDialog {
        id: saveDialog
        title: "Сохранить файл как..."
        fileMode: FileDialog.SaveFile
        currentFolder: root.currentFolderUrl
        nameFilters: ["Markdown (*.md)", "Текстовые файлы (*.txt)", "Все файлы (*.*)"]
        defaultSuffix: "md"
        onAccepted: {
            let targetIndex = (root.isSplit && root.activePane === 1) ? root.secondaryTabIndex : root.primaryTabIndex
            backend.save_file(selectedFile, root.editorArea.text)
            currentFileUrl = selectedFile
            currentFileName = backend.get_filename(selectedFile)
            if (tabsModel.count > 0 && targetIndex >= 0 && targetIndex < tabsModel.count) {
                tabsModel.setProperty(targetIndex, "title", currentFileName)
                tabsModel.setProperty(targetIndex, "fileUrl", currentFileUrl)
                tabsModel.setProperty(targetIndex, "content", root.editorArea.text)
                Tabs.syncEditorsFromModel(root)
            }
        }
    }

    // Применение начальных параметров при клонировании окна
    function applyInitialState() {
        let appWin = root.Window.window
        let initUrl = (appWin && appWin.initialFileUrl) ? appWin.initialFileUrl : root.initialFileUrl
        let initTitle = (appWin && appWin.initialTitle) ? appWin.initialTitle : root.initialTitle
        let initContent = (appWin && appWin.initialContent) ? appWin.initialContent : root.initialContent
        let hideSidebar = (appWin && appWin.startWithSidebarHidden) || root.startWithSidebarHidden

        if (hideSidebar) {
            root.isSidebarVisible = false
            if (sideBar) {
                sideBar.isSidebarVisible = false
                sideBar.currentWidth = 0
            }
        }

        if (initUrl || initTitle) {
            tabsModel.setProperty(0, "title", initTitle || "Документ")
            tabsModel.setProperty(0, "fileUrl", initUrl || "")
            tabsModel.setProperty(0, "content", initContent || "")
            root.currentFileName = initTitle || "Документ"
            root.currentFileUrl = initUrl || ""
            root.primaryFileName = initTitle || "Документ"
            Tabs.syncEditorsFromModel(root)
            return true
        }
        return false
    }

    Component.onCompleted: {
        let hasInitialDoc = applyInitialState()

        if (typeof backend !== "undefined" && backend) {
            root.currentFolderUrl = backend.get_default_folder()
            root.currentFolderName = backend.get_folder_name(root.currentFolderUrl)
            openDialog.currentFolder = root.currentFolderUrl
            saveDialog.currentFolder = root.currentFolderUrl

            backend.watch_folder(root.currentFolderUrl)
            root.reloadFolderFiles()

            // Если окно создано при клонировании с конкретным документом, не перезаписываем его
            if (hasInitialDoc) {
                // Уже применили в applyInitialState
            } else if (folderFilesModel.count > 0) {
                // Если есть файлы в папке — открываем первый файл
                let firstFile = folderFilesModel.get(0)
                let content = backend.read_file(firstFile.fileUrl)
                tabsModel.setProperty(0, "title", firstFile.name)
                tabsModel.setProperty(0, "fileUrl", firstFile.fileUrl)
                tabsModel.setProperty(0, "content", content)
                root.currentFileName = firstFile.name
                root.currentFileUrl = firstFile.fileUrl
                root.primaryFileName = firstFile.name
                Tabs.syncEditorsFromModel(root)
            } else {
                let res = backend.create_file_in_folder(root.currentFolderUrl, "Новый документ")
                if (res && res.success) {
                    tabsModel.setProperty(0, "title", res.fileName)
                    tabsModel.setProperty(0, "fileUrl", res.fileUrl)
                    root.currentFileName = res.fileName
                    root.currentFileUrl = res.fileUrl
                    root.primaryFileName = res.fileName
                    root.reloadFolderFiles()
                }
            }
        }
    }

    Shortcut {
        sequences: [StandardKey.Save]
        onActivated: Logic.saveFile(root, saveDialog, backend)
    }

    Shortcut {
        sequences: [StandardKey.Open]
        onActivated: openDialog.open()
    }

    Shortcut {
        sequences: [StandardKey.New]
        onActivated: root.createNewTab()
    }

    Shortcut {
        sequence: "Ctrl+\\"
        onActivated: root.toggleSplit()
    }

    Shortcut {
        sequence: "Ctrl+B"
        onActivated: root.toggleSidebar()
    }

    function closeActiveTab() {
        if (root.tabsModel.count === 0) return
        let targetIdx = (root.isSplit && root.activePane === 1) ? root.secondaryTabIndex : root.primaryTabIndex
        if (targetIdx >= 0 && targetIdx < root.tabsModel.count) {
            root.closeTab(targetIdx)
        } else if (root.currentTabIndex >= 0 && root.currentTabIndex < root.tabsModel.count) {
            root.closeTab(root.currentTabIndex)
        } else {
            root.closeTab(root.tabsModel.count - 1)
        }
    }

    function isCloseKey(event) {
        if (!(event.modifiers & Qt.ControlModifier)) return false
        // W key: Key_W, scan code 17, or Cyrillic 'ц'
        if (event.key === Qt.Key_W || event.nativeScanCode === 17 || event.text === 'w' || event.text === 'W' || event.text === 'ц' || event.text === 'Ц' || event.key === 1062 || event.key === 1030) return true
        // Q key: Key_Q, scan code 16, or Cyrillic 'й'
        if (event.key === Qt.Key_Q || event.nativeScanCode === 16 || event.text === 'q' || event.text === 'Q' || event.text === 'й' || event.text === 'Й' || event.key === 1081 || event.key === 1049) return true
        return false
    }

    // Закрытие активного сплита или вкладки (Ctrl+W, Ctrl+Q, Ctrl+F4)
    Shortcut {
        sequence: "Ctrl+W"
        context: Qt.ApplicationShortcut
        onActivated: root.closeActiveTab()
    }

    Shortcut {
        sequence: "Ctrl+Q"
        context: Qt.ApplicationShortcut
        onActivated: root.closeActiveTab()
    }

    Shortcut {
        sequence: "Ctrl+F4"
        context: Qt.ApplicationShortcut
        onActivated: root.closeActiveTab()
    }

    Keys.onPressed: (event) => {
        if (root.isCloseKey(event)) {
            root.closeActiveTab()
            event.accepted = true
        }
    }

    // Переключение ширины листа (вместо занятого Alt+Z)
    Shortcut {
        sequences: ["Alt+W", "Ctrl+Shift+W"]
        onActivated: {
            if (splitLayout.primaryBar) {
                splitLayout.primaryBar.isCenteredMode = !splitLayout.primaryBar.isCenteredMode
            }
            if (splitLayout.isSplit && splitLayout.secondaryBar) {
                splitLayout.secondaryBar.isCenteredMode = splitLayout.primaryBar.isCenteredMode
            }
        }
    }

    // =========================================================================
    // РАСКЛАДКА ОКНА
    // =========================================================================
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // 1. Сайдбар со списком файлов папки и кнопкой настроек внизу
        Sidebar {
            id: sideBar
            appWindow: root.appWindow
            barSize: root.barSize
            isSidebarVisible: root.isSidebarVisible
            tabsModel: tabsModel
            filesModel: folderFilesModel
            currentTabIndex: (root.isSplit && root.activePane === 1) ? root.secondaryTabIndex : root.primaryTabIndex
            currentFolderUrl: root.currentFolderUrl
            currentFolderName: root.currentFolderName
            currentFileUrl: {
                let idx = (root.isSplit && root.activePane === 1) ? root.secondaryTabIndex : root.primaryTabIndex
                if (idx >= 0 && idx < tabsModel.count) {
                    let tab = tabsModel.get(idx)
                    if (tab && tab.fileUrl) return tab.fileUrl
                }
                return root.currentFileUrl || ""
            }
            isSplit: root.isSplit
            backgroundTabIndex: root.isSplit ? (root.activePane === 0 ? root.secondaryTabIndex : root.primaryTabIndex) : -1
            backgroundFileUrl: {
                if (!root.isSplit) return ""
                let bgIdx = (root.activePane === 0 ? root.secondaryTabIndex : root.primaryTabIndex)
                if (bgIdx >= 0 && bgIdx < root.tabsModel.count) {
                    let tab = root.tabsModel.get(bgIdx)
                    return (tab && tab.fileUrl) ? tab.fileUrl : ""
                }
                return ""
            }
            externalWindowFiles: root.externalWindowFiles

            onFolderClicked: {
                if (typeof backend !== "undefined" && backend) {
                    let res = backend.choose_folder_dialog(root.currentFolderUrl)
                    if (res && res.success) {
                        root.currentFolderUrl = res.folderUrl
                        root.currentFolderName = res.folderName
                        openDialog.currentFolder = res.folderUrl
                        saveDialog.currentFolder = res.folderUrl
                        root.reloadFolderFiles()
                    }
                } else {
                    folderDialog.open()
                }
            }
            onNewClicked: root.createNewTab()
            onFileSelected: (fUrl, fName) => root.openFileFromFolder(fUrl, fName)
            onOpenInNewWindowRequested: (fUrl, fName) => root.openInNewWindow(fUrl, fName)
            onFileDeleteRequested: (fUrl) => {
                for (let i = tabsModel.count - 1; i >= 0; i--) {
                    if (tabsModel.get(i).fileUrl === fUrl) {
                        root.closeTab(i)
                    }
                }
                backend.delete_file(fUrl)
            }
            onFileRenameRequested: (fUrl, newName) => {
                let res = backend.rename_file(fUrl, newName)
                if (res && res.success) {
                    for (let i = 0; i < tabsModel.count; i++) {
                        if (tabsModel.get(i).fileUrl === fUrl) {
                            tabsModel.setProperty(i, "fileUrl", res.fileUrl)
                            tabsModel.setProperty(i, "title", res.fileName)
                            if (i === root.primaryTabIndex) root.primaryFileName = res.fileName
                            if (i === root.secondaryTabIndex) root.secondaryFileName = res.fileName
                        }
                    }
                    if (root.currentFileUrl === fUrl) {
                        root.currentFileUrl = res.fileUrl
                        root.currentFileName = res.fileName
                    }
                }
            }
            onTabDragStarted: (url, name, gx, gy) => {
                root.draggingFileUrl = url
                root.draggingFileName = name
                dragTrackerTimer.running = true
            }
            onTabDragMoved: (gx, gy) => root.handleFileDragMoved(gx, gy)
            onTabDragEnded: (fUrl, fName, gx, gy) => root.handleFileDragEnded(fUrl, fName, gx, gy)

            onOpenClicked: openDialog.open()
            onSaveClicked: Logic.saveFile(root, saveDialog, backend)
            onCloseClicked: (root.appWindow || Window.window).close()
            onToggleMaximizeClicked: Logic.toggleMaximize(root.appWindow || Window.window)
        }

        // 2. Главная область: Холст с поддержкой разделения экрана (Split View)
        EditorSplitLayout {
            id: splitLayout
            Layout.fillWidth: true
            Layout.fillHeight: true
            barSize: root.barSize
            isSplit: root.isSplit
            activePane: root.activePane
            dropZone: root.dropZone
            primaryFileName: root.primaryFileName
            secondaryFileName: root.secondaryFileName

            isPrimaryEmpty: root.tabsModel.count === 0 || root.primaryTabIndex < 0

            onPrimaryTitleChanged: (newTitle) => Tabs.renameTab(root, root.primaryTabIndex, newTitle)
            onSecondaryTitleChanged: (newTitle) => Tabs.renameTab(root, root.secondaryTabIndex, newTitle)
            onPrimaryDetachRequested: Tabs.detachTab(root, root.primaryTabIndex)
            onSecondaryDetachRequested: Tabs.detachTab(root, root.secondaryTabIndex)
            onPrimaryTextChanged: (text) => Tabs.handlePrimaryTextChanged(root, text)
            onSecondaryTextChanged: (text) => Tabs.handleSecondaryTextChanged(root, text)
            onPrimaryCloseRequested: root.closeTab(root.primaryTabIndex)
            onSecondaryCloseRequested: root.closeTab(root.secondaryTabIndex)
            onCloseSplitRequested: () => Tabs.closeSplit(root)
            onPaneActivated: (paneIndex) => Tabs.setActivePane(root, paneIndex)
        }
    }
}