import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#1e1e1e" // Темная тема редактора

    property string currentFilePath: ""
    property string currentFileName: "Без названия"
    property bool isModified: false

    // Функция загрузки файла
    function loadFile(filePath, fileName) {
        currentFilePath = filePath
        currentFileName = fileName
        var content = backend.read_file(filePath)
        editorArea.text = content
        isModified = false
    }

    // Функция сохранения файла
    function saveFile() {
        if (currentFilePath !== "") {
            var success = backend.save_file(currentFilePath, editorArea.text)
            if (success) {
                isModified = false
                statusLabel.text = "✓ Сохранено: " + new Date().toLocaleTimeString()
            } else {
                statusLabel.text = "✕ Ошибка сохранения!"
            }
        }
    }

    // Горячая клавиша Ctrl + S для сохранения
    Shortcut {
        sequence: "Ctrl+S"
        onActivated: root.saveFile()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Верхняя панель открытого файла
        Rectangle {
            Layout.fillWidth: true
            height: 38
            color: "#2d2d30"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 15
                anchors.rightMargin: 15
                spacing: 12

                // Вкладка открытого файла
                Rectangle {
                    height: 28
                    Layout.preferredWidth: tabText.implicitWidth + 30
                    color: "#1e1e1e"
                    radius: 4

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            id: tabText
                            text: root.currentFileName + (root.isModified ? " ●" : "")
                            color: root.isModified ? "#e5c07b" : "#ffffff"
                            font.pixelSize: 12
                        }
                    }
                }

                // Полный путь
                Text {
                    text: root.currentFilePath
                    color: "#858585"
                    font.pixelSize: 11
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                }

                // Кнопка сохранения
                Button {
                    text: "💾 Сохранить"
                    enabled: root.currentFilePath !== ""
                    onClicked: root.saveFile()
                    background: Rectangle {
                        color: parent.hovered ? "#0e639c" : "#1177bb"
                        radius: 3
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        // Разделитель
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#3e3e42"
        }

        // Рабочая зона редактора
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            TextArea {
                id: editorArea
                placeholderText: "// Выберите файл слева для просмотра и редактирования..."
                placeholderTextColor: "#555555"
                text: ""
                color: "#d4d4d4"
                font.family: "Consolas, 'Courier New', monospace"
                font.pixelSize: 15
                wrapMode: TextArea.NoWrap
                selectByMouse: true
                background: null
                leftPadding: 15
                topPadding: 15

                onTextChanged: {
                    if (root.currentFilePath !== "") {
                        root.isModified = true
                    }
                }
            }
        }

        // Нижний статус-бар
        Rectangle {
            Layout.fillWidth: true
            height: 24
            color: "#007acc" // Синяя полоса состояния как в VS Code

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10

                Text {
                    id: statusLabel
                    text: root.currentFilePath !== "" ? "Готов к работе" : "Файл не выбран"
                    color: "white"
                    font.pixelSize: 11
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "Символов: " + editorArea.text.length
                    color: "white"
                    font.pixelSize: 11
                }

                Text {
                    text: "UTF-8"
                    color: "white"
                    font.pixelSize: 11
                }
            }
        }
    }
}
