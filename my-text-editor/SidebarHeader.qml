import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Button {
    id: folderBtn

    property var appWindow: null
    property int barSize: 36
    property bool expanded: true
    property string currentFolderUrl: ""
    property string currentFolderName: ""

    signal folderClicked()

    Layout.fillWidth: true
    Layout.preferredHeight: barSize
    padding: 0
    hoverEnabled: true

    background: Rectangle {
        color: folderBtn.down ? "#222222" : (folderBtn.hovered ? "#222222" : "#181818")
        border.color: folderBtn.hovered ? "#2e2e2e" : "transparent"
        border.width: 1
    }

    contentItem: RowLayout {
        anchors.fill: parent
        spacing: 0

        // Иконка папки строго по центру в узком сайдбаре
        Text {
            Layout.preferredWidth: folderBtn.barSize
            Layout.fillHeight: true
            text: "📁"
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        // Название текущей папки
        Text {
            visible: folderBtn.expanded
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: folderBtn.currentFolderName || "Выбрать папку"
            color: folderBtn.hovered ? "#ffffff" : "#e0e0e0"
            font.pixelSize: 12
            font.bold: true
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        // Индикатор смены
        Text {
            visible: folderBtn.expanded
            Layout.preferredWidth: 20
            Layout.fillHeight: true
            Layout.rightMargin: 6
            text: "▾"
            color: folderBtn.hovered ? "#cccccc" : "#777777"
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    onClicked: folderBtn.folderClicked()

    ToolTip.visible: hovered
    ToolTip.text: currentFolderUrl ? `Рабочая папка: ${decodeURIComponent(currentFolderUrl).replace("file:///", "")}\n(Нажмите для смены)` : "Нажмите для выбора рабочей папки"
}
