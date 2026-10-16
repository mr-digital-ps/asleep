import QtQuick
import "../theme"

// components/workspace/SnapGuideOverlay.qml — Отрисовка направляющих линий магнита при перетаскивании панелей
Item {
    id: guideRoot
    anchors.fill: parent
    z: 1000
    visible: activeGuides.length > 0

    property var activeGuides: []

    Repeater {
        model: guideRoot.activeGuides

        delegate: Item {
            id: guideDelegate
            property var guideData: modelData

            // Линия магнита (вертикальная или горизонтальная)
            Rectangle {
                visible: guideData.orientation !== "rect"
                x: guideData.orientation === "v" ? guideData.x1 - 1 : guideData.x1
                y: guideData.orientation === "h" ? guideData.y1 - 1 : guideData.y1
                width: guideData.orientation === "v" ? 2 : Math.max(2, Math.abs(guideData.x2 - guideData.x1))
                height: guideData.orientation === "h" ? 2 : Math.max(2, Math.abs(guideData.y2 - guideData.y1))
                color: Theme.accentColor
                opacity: 0.85
            }

            // Прямоугольная подсветка шапки при слиянии во вкладку (Tab Merge)
            Rectangle {
                visible: guideData.orientation === "rect"
                x: guideData.x1
                y: guideData.y1
                width: Math.abs(guideData.x2 - guideData.x1)
                height: Math.abs(guideData.y2 - guideData.y1)
                color: "transparent"
                border.color: Theme.accentColor
                border.width: 2
                radius: 4
                opacity: 0.9
            }
        }
    }
}
