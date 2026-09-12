# Руководство по настройке темы оформления (`theme.json`)

Файл настроек: `config/user/theme.json` (переопределяет `config/default/theme.json`).  
Локальный файл в каталоге заметок: `_theme_settings.json`.

---

## Таблица параметров темы

| Параметр | Тип | По умолчанию | Описание |
| :--- | :---: | :---: | :--- |
| **`sidebar_width`** | `number` | `260` | Базовая ширина боковой панели файлов в пикселях. |
| **`sidebar_min_width`** | `number` | `180` | Минимальная ширина сайдбара при растягивании мышью. |
| **`sidebar_max_width`** | `number` | `480` | Максимальная ширина сайдбара. |
| **`bg_app`** | `color` | `"#141414"` | Основной фоновый цвет рабочей области редактора. |
| **`bg_sidebar`** | `color` | `"#171717"` | Фоновый цвет боковой панели проводника файлов. |
| **`border_color`** | `color` | `"#262626"` | Цвет разделительных линий, границ вкладок и рамок. |
| **`accent_color`** | `color` | `"#4da6ff"` | Главный акцентный цвет приложения (активные кнопки, курсор, ссылки). |
| **`text_primary`** | `color` | `"#d4d4d4"` | Основной цвет текста документов и заголовков. |
| **`text_secondary`** | `color` | `"#737373"` | Цвет вторичного текста (статистика слов, счетчики, пути). |
| **`header_visible`** | `boolean` | `true` | Показывать ли верхнюю шапку документа по умолчанию. |
| **`footer_visible`** | `boolean` | `true` | Показывать ли нижнюю строку статуса по умолчанию. |

---

## Примеры цветовых палитр

### Палитра: «Deep Obsidian (Глубокий темный)»
```json
{
  "bg_app": "#0f0f11",
  "bg_sidebar": "#16161a",
  "border_color": "#23232a",
  "accent_color": "#7f5af0",
  "text_primary": "#fffffe",
  "text_secondary": "#94a1b2"
}
```

### Палитра: «Nord Frost»
```json
{
  "bg_app": "#2e3440",
  "bg_sidebar": "#242933",
  "border_color": "#3b4252",
  "accent_color": "#88c0d0",
  "text_primary": "#eceff4",
  "text_secondary": "#d8dee9"
}
```

### Палитра: «Warm Amber / Sepia Dark»
```json
{
  "bg_app": "#1c1917",
  "bg_sidebar": "#171412",
  "border_color": "#292524",
  "accent_color": "#f59e0b",
  "text_primary": "#e7e5e4",
  "text_secondary": "#a8a29e"
}
```
