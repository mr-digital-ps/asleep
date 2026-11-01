import QtQuick
import "../theme"

Item {
    id: concealOverlay
    anchors.fill: parent

    property var editorArea: null
    property bool isLiveMode: false
    property var blocks: []

    // Скобки {} стилизуются полупрозрачно/приглушенно напрямую через DialectHighlighter (re_brace).
    // Пустой оверлей сохранен для обратной совместимости API компонентов.
}
