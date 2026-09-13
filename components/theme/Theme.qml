pragma Singleton
import QtQuick

Item {
    id: theme
    visible: false

    // 1. Поверхности и фоны (Surfaces & Backgrounds)
    property color bgApp: "#141414"
    property color bgPaper: "#181818"
    property color bgSidebar: "#171717"
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
    property color scrollbarThumb: "#2c2c2c"
    property color scrollbarHover: "#3d3d3d"
    property color dangerColor: "#ef4444"

    // Применение настроек из объекта темы
    function applyConfig(cfg) {
        if (!cfg) return
        if (cfg.bg_app) bgApp = cfg.bg_app
        if (cfg.bg_paper) bgPaper = cfg.bg_paper
        if (cfg.bg_sidebar) bgSidebar = cfg.bg_sidebar
        if (cfg.bg_header) bgHeader = cfg.bg_header
        if (cfg.bg_footer) bgFooter = cfg.bg_footer
        if (cfg.bg_hover) bgHover = cfg.bg_hover
        if (cfg.bg_active) bgActive = cfg.bg_active
        if (cfg.bg_dialog) bgDialog = cfg.bg_dialog
        if (cfg.bg_input) bgInput = cfg.bg_input
        else if (cfg.bg_dialog) bgInput = cfg.bg_dialog

        if (cfg.text_primary) textPrimary = cfg.text_primary
        if (cfg.text_secondary) textSecondary = cfg.text_secondary
        if (cfg.text_muted) textMuted = cfg.text_muted
        if (cfg.text_selected) textSelected = cfg.text_selected
        if (cfg.text_hover) textHover = cfg.text_hover

        if (cfg.cursor_color) cursorColor = cfg.cursor_color
        if (cfg.selection_color) selectionColor = cfg.selection_color
        if (cfg.line_highlight) lineHighlight = cfg.line_highlight
        if (cfg.gutter_text) gutterText = cfg.gutter_text
        if (cfg.gutter_active) gutterActive = cfg.gutter_active
        if (cfg.bracket_match) bracketMatch = cfg.bracket_match

        if (cfg.border_color) borderColor = cfg.border_color
        if (cfg.border_focus) borderFocus = cfg.border_focus
        if (cfg.border_hover) borderHover = cfg.border_hover

        if (cfg.accent_color) accentColor = cfg.accent_color
        if (cfg.accent_hover) accentHover = cfg.accent_hover
        if (cfg.accent_active) accentActive = cfg.accent_active
        if (cfg.scrollbar_thumb) scrollbarThumb = cfg.scrollbar_thumb
        if (cfg.scrollbar_hover) scrollbarHover = cfg.scrollbar_hover
        if (cfg.danger_color) dangerColor = cfg.danger_color
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
