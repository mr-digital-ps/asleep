pragma Singleton
import QtQuick

Item {
    id: theme
    visible: false

    // 1. Поверхности и фоны (Surfaces & Backgrounds)
    property color bgApp: "#141414"
    property color bgPaper: "#181818"
    property color bgHeader: "#181818"
    property color bgFooter: "#181818"
    property color bgHover: "#202020"
    property color bgActive: "#282828"
    property color bgDialog: "#1e1e1e"
    property color bgInput: "#1a1a1a"

    // 2. Текст (Typography)
    property color textPrimary: "#d4d4d4"
    property color textSecondary: "#737373"
    property color textMuted: "#525252"
    property color textSelected: "#ffffff"
    property color textHover: "#ffffff"

    // 3. Редактор текста (Editor Canvas)
    property color cursorColor: "#e0e0e0"
    property color selectionColor: "#282828"
    property color lineHighlight: "#0effffff"
    property color gutterText: "#505050"
    property color gutterActive: "#999999"
    property color bracketMatch: "#888888"

    // 4. Границы и разделители (Borders & Dividers)
    property color borderColor: "#262626"
    property color borderFocus: "#555555"
    property color borderHover: "#333333"

    // 5. Акценты и интерактивные элементы (Accents & Controls)
    property color accentColor: "#d4d4d4"
    property color accentHover: "#ffffff"
    property color accentActive: "#888888"
    property color scrollbarThumb: "#484848"
    property color scrollbarHover: "#646464"
    property color scrollbarTrack: "#18ffffff"
    property color dangerColor: "#ef4444"

    // 6. Размеры и геометрия (Geometry Tokens)
    property int barSize: 36
    property int headerCompactHeight: 40
    property int headerExpandedHeight: 76
    property real defaultSheetWidth: 800
    property real minSheetWidth: 380
    property int defaultTabSize: 4
    property real defaultLineHeightPercent: 135.0
    property string defaultFontFamily: "Segoe UI, Inter, -apple-system, sans-serif"

    // Применение настроек из объекта темы (автоматический маппинг snake_case -> camelCase)
    function applyConfig(cfg) {
        if (!cfg) return
        for (var key in cfg) {
            var camelKey = key.replace(/_([a-z0-9])/g, function(_, letter) {
                return letter.toUpperCase()
            })
            if (theme.hasOwnProperty(camelKey)) {
                theme[camelKey] = cfg[key]
            }
        }
        if (!cfg.bg_input && cfg.bg_dialog) {
            bgInput = cfg.bg_dialog
        }
    }

    // Автоматическая реактивная синхронизация при изменении theme.json на диске
    Connections {
        target: (typeof backend !== "undefined") ? backend : null
        function onThemeConfigChanged() {
            if (backend && typeof backend.get_theme_config === "function") {
                theme.applyConfig(backend.get_theme_config())
            }
        }
    }

    Component.onCompleted: {
        if (typeof backend !== "undefined" && backend && typeof backend.get_theme_config === "function") {
            theme.applyConfig(backend.get_theme_config())
        }
    }
}
