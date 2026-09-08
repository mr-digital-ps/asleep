import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

ApplicationWindow {
    id: window
    visible: true
    width: 800
    height: 600
    minimumWidth: 480
    minimumHeight: 320
    title: currentFileName !== "" ? currentFileName + " — Простой текстовый редактор" : "Новый документ — Простой текстовый редактор"

    // ----------------------------------------------------
    // СОСТОЯНИЕ (ПЕРЕМЕННЫЕ)
    // ----------------------------------------------------
    // Хранит URL текущего открытого файла (например, "file:///C:/doc.txt")
    // Если пусто ("") — значит документ еще не был сохранен на диск.
    property string currentFileUrl: ""
    property string currentFileName: "Новый документ"

    // ----------------------------------------------------
    // ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (ДЛЯ ОБУЧЕНИЯ)
    // ----------------------------------------------------

    // 1. Очистка редактора для нового документа
    function newDocument() {
        editorArea.text = ""
        currentFileUrl = ""
        currentFileName = "Новый документ"
        statusText.text = "Создан новый документ"
    }

    // 2. Логика открытия файла (вызывается после выбора в диалоге)
    function openFile(fileUrl) {
        var text = backend.read_file(fileUrl)
        editorArea.text = text
        currentFileUrl = fileUrl
        currentFileName = backend.get_filename(fileUrl)
    }

    // 3. Логика сохранения
    function saveFile() {
        if (currentFileUrl === "") {
            // Если файл еще ни разу не сохранялся, открываем диалог "Сохранить как..."
            saveDialog.open()
        } else {
            // Если путь уже известен, сохраняем прямо в него
            backend.save_file(currentFileUrl, editorArea.text)
        }
    }

    // ----------------------------------------------------
    // СЛУШАТЕЛЬ СИГНАЛОВ ИЗ PYTHON (Connections)
    // ----------------------------------------------------
    Connections {
        target: backend

        // Срабатывает, когда Python шлет сигнал statusChanged(str)
        function onStatusChanged(message) {
            statusText.text = message
        }

        // Срабатывает, когда Python шлет сигнал errorOccurred(str)
        function onErrorOccurred(message) {
            statusText.text = "⚠️ " + message
        }
    }

    // ----------------------------------------------------
    // СИСТЕМНЫЕ ДИАЛОГИ ВЫБОРА ФАЙЛОВ
    // ----------------------------------------------------

    // Диалог "Открыть файл"
    FileDialog {
        id: openDialog
        title: "Открыть файл"
        fileMode: FileDialog.OpenFile
        onAccepted: {
            openFile(selectedFile)
        }
    }

    // Диалог "Сохранить файл как..."
    FileDialog {
        id: saveDialog
        title: "Сохранить файл как..."
        fileMode: FileDialog.SaveFile
        onAccepted: {
            var url = selectedFile
            var ok = backend.save_file(url, editorArea.text)
            if (ok) {
                currentFileUrl = url
                currentFileName = backend.get_filename(url)
            }
        }
    }

    // ----------------------------------------------------
    // ГОРЯЧИЕ КЛАВИШИ (Shortcuts)
    // ----------------------------------------------------
    Shortcut {
        sequence: StandardKey.Save      // Ctrl + S (или Cmd + S на Mac)
        onActivated: saveFile()
    }

    Shortcut {
        sequence: StandardKey.Open      // Ctrl + O
        onActivated: openDialog.open()
    }

    Shortcut {
        sequence: StandardKey.New       // Ctrl + N
        onActivated: newDocument()
    }

    // ----------------------------------------------------
    // ГЛАВНЫЙ СТРОИТЕЛЬНЫЙ МАКЕТ (ColumnLayout)
    // ----------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // 1. ВЕРХНЯЯ ПАНЕЛЬ С КНОПКАМИ (Toolbar)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            color: "#f0f0f0"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 8

                Button {
                    text: "📄 Новый"
                    onClicked: newDocument()
                }

                Button {
                    text: "📂 Открыть..."
                    onClicked: openDialog.open()
                }

                Button {
                    text: "💾 Сохранить"
                    onClicked: saveFile()
                }

                Button {
                    text: "💾 Сохранить как..."
                    onClicked: saveDialog.open()
                }

                // Распорка (занимает все пустое место справа)
                Item {
                    Layout.fillWidth: true
                }
            }

            // Тонкая линия-разделитель снизу панели кнопок
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: "#d0d0d0"
            }
        }

        // 2. ОСНОВНАЯ ОБЛАСТЬ: ПОЛЕ РЕДАКТИРОВАНИЯ СО СКРОЛЛОМ
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            TextArea {
                id: editorArea
                placeholderText: "Начните вводить текст здесь..."
                wrapMode: TextArea.Wrap
                selectByMouse: true
                font.family: "Consolas, Courier New, monospace"
                font.pixelSize: 15
                padding: 12

                // Базовый цвет фона редактора
                background: Rectangle {
                    color: "#ffffff"
                }
            }
        }

        // 3. НИЖНЯЯ СТРОКА СОСТОЯНИЯ (Status Bar)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            color: "#f8f8f8"

            // Линия-разделитель сверху статус-бара
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: "#dcdcdc"
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12

                // Статус или сообщения (слева)
                Label {
                    id: statusText
                    text: "Готово к работе"
                    color: "#444444"
                    font.pixelSize: 12
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                // Счетчик символов и строк (справа)
                Label {
                    text: "Символов: " + editorArea.text.length + " | Строк: " + (editorArea.text === "" ? 0 : editorArea.text.split("\n").length)
                    color: "#666666"
                    font.pixelSize: 12
                }
            }
        }
    }
}
