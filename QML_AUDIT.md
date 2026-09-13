# Аудит QML-компонентов: неиспользуемые элементы, скрытые кнопки и мёртвый код

> **Дата составления:** 14 сентября 2026 г.  
> **Статус:** Актуальный аудит кодовой базы `asleep-pyqt`.

---

## 1. Неиспользуемые визуальные блоки интерфейса (Мёртвый UI)

### 1.1. Мини-панель управления графом (`miniControls`)
* **Файл:** [`components/graph/GraphView.qml`](components/graph/GraphView.qml) (строки 163–246, 84 строки кода).
* **Что содержит:**
  * Поле поиска заметок (`searchInput`, плейсхолдер *"Поиск заметок..."*).
  * Кнопку сброса/центрирования камеры `⊙` (`centerBtn`, сигнал `graphRoot.resetView()`).
  * Кнопку закрытия графа `✕` (`closeBtn`, сигнал `graphRoot.closeRequested()`).
* **Почему не используется:**
  * Имеет условие видимости: `visible: !graphRoot.embeddedInSheet`.
  * В [`components/editor/MainBar.qml`](components/editor/MainBar.qml) (строка 340) граф подключён с флагом `embeddedInSheet: true`.
  * Других мест создания `GraphView` в проекте нет. Панель **всегда скрыта** и потребляет ресурсы на инициализацию.

---

## 2. Мёртвые цепочки сигналов и событий

### 2.1. Сигнал `toggleGraphModeRequested(bool toGraph)`
* **Файлы:**
  * [`components/editor/MainBar.qml:L97`](components/editor/MainBar.qml)
  * [`components/editor/EditorSplitLayout.qml:L55`](components/editor/EditorSplitLayout.qml)
  * [`views/web.qml:L321`](views/web.qml)
* **Проблема:**
  * В `web.qml` объявлен обработчик:
    ```qml
    onToggleGraphModeRequested: (toGraph) => WebLifecycle.handleToggleGraphMode(root, backend, toGraph)
    ```
  * Однако ни в одном QML-компоненте и ни в одном JS-файле вызов `toggleGraphModeRequested(...)` **никогда не испускается** (0 вызовов).
  * Переключение режима графа сейчас реализовано напрямую через хоткеи (`Ctrl+G`), клик по иконке в сайдбаре и флаг `root.isGraphVisible`.

---

## 3. Неиспользуемые свойства (Properties), флаги и алиасы

| Файл | Имя свойства / метода | Описание и причина неиспользования |
| :--- | :--- | :--- |
| [`views/web.qml:L83`](views/web.qml) | `property var draggedNewWin: null` | Остаток раннего прототипа отрыва вкладок в новое окно. В `drag_manager.js` проверяется и сбрасывается в `null`, но окно туда никогда не создаётся. |
| [`components/hotkeys/HotkeyManager.qml`](components/hotkeys/HotkeyManager.qml) | `property var hotkeyMapping` | Загружается из Python-бэкенда при старте, но ни один QML-компонент (диалог, меню) его не читает. |
| [`components/hotkeys/HotkeyManager.qml`](components/hotkeys/HotkeyManager.qml) | `property var flatHotkeysList` | Список хоткеев для UI-шпаргалки; в текущем интерфейсе не отображается. |
| [`views/web.qml:L215`](views/web.qml) | `function isCloseKey(event)` | Алиас на функцию менеджера хоткеев; нигде снаружи `web.qml` не вызывается. |
| [`components/editor/MainBar.qml:L82`](components/editor/MainBar.qml) | `property bool isTitleFocused` | Связано с `docHeader.titleField.activeFocus`, но нигде в условиях рендеринга или JS не читается. |
| [`components/editor/MainBar.qml:L19`](components/editor/MainBar.qml) | `property bool isCustomWidthSetByUser` | Флаг устанавливается в `true` в `mainbar_controller.js`, но его значение ни на что не влияет. |
| [`components/editor/MainBar.qml:L20`](components/editor/MainBar.qml) | `property bool isCustomFontSizeSetByUser` | Флаг устанавливается в `true` в `mainbar_controller.js`, но нигде не читается. |
| [`components/editor/EditorHeader.qml:L17`](components/editor/EditorHeader.qml) | `property string folderName: ""` | Передаётся из `MainBar`, но в строке заголовка рендерится только `fileName`. Папка не отображается. |

---

## 4. Неиспользуемые токены в теме оформления

В [`components/theme/Theme.qml`](components/theme/Theme.qml) загружаются из `theme.json`:
* `property color textHover`
* `property color borderFocus`
* `property color accentHover`
* `property color accentActive`

> **Статус:** Ни один QML-компонент не использует эти цвета (цвета вычисляются инлайн либо используются базовые токены `textPrimary`, `borderColor`, `borderHover`, `accentColor`).

---

## 5. Кнопки и контролы, которые реализованы, но не отображаются в UI

В проекте есть ряд кнопок и интерактивных элементов, логика которых написана, но визуально они скрыты намеренно (согласно концепции минимализма «чистого листа»):

### 5.1. Кнопки в шапке сайдбара ([`components/sidebar/SidebarHeader.qml`](components/sidebar/SidebarHeader.qml))
1. **Кнопка настроек каталога `⚙`** (`folderBtn.configClicked()`) — открывает `_index.md` / настройки папки.
2. **Кнопка открытия графа связей `🕸`** (`folderBtn.graphClicked()`) — открывает граф заметок.
3. **Стрелка выпадающего списка `▾`** — индикатор смены рабочей папки.
* **Поведение скрытия:**
  * При свёрнутом узком сайдбаре (ширина 36px, `expanded === false`) все эти кнопки скрываются (`visible: folderBtn.expanded`), остаётся только иконка папки `📁`.
  * Кнопки `⚙` и `🕸` также скрываются, если рабочая папка не открыта (`!currentFolderUrl`).

### 5.2. Скрытые кнопки-линии закрепления шапки и подвала
1. **Верхняя разделительная линия** ([`components/editor/EditorHeader.qml:L89-L119`](components/editor/EditorHeader.qml)):
   * Замаскирована под обычную тонкую 2px полосу под заголовком заметки.
   * На самом деле это интерактивная кнопка (`headerDividerMouse`) с курсором `PointingHandCursor` и плавной подсветкой. По клику вызывает `pinToggled()` (закрепляет/открепляет шапку при вертикальном скролле).
   * В режиме графа клик намеренно отключается (`cursorShape: Qt.ArrowCursor`).
2. **Нижняя разделительная линия** ([`components/editor/EditorFooter.qml:L34-L65`](components/editor/EditorFooter.qml)):
   * Аналогичная скрытая кнопка над статистикой слов/символов. Клик по ней закрепляет или открепляет нижний подвал.

### 5.3. Отсутствующие кнопки управления вкладками (Закрыть / Открепить)
* В кодовой базе ([`EditorCanvas.qml`](components/editor/EditorCanvas.qml), [`EditorSplitLayout.qml`](components/editor/EditorSplitLayout.qml)) полностью прописаны сигналы:
  * `primaryCloseRequested` / `secondaryCloseRequested`
  * `primaryDetachRequested` / `secondaryDetachRequested`
* Однако визуальных кнопок закрытия (`✕`) или открепления (`⧉`) в заголовке листа документа **нет**. Это сделано намеренно для сохранения минималистичного дизайна. Управление осуществляется исключительно горячими клавишами (`Ctrl+W`, `Ctrl+Shift+N`) либо через ПКМ в сайдбаре.

### 5.4. Оконные кнопки управления (Minimize / Maximize / Close)
* В [`views/window.qml`](views/window.qml) окно создаётся с флагом `Qt.FramelessWindowHint`.
* Верхней стандартной плашки с кнопками `—`, `🗖`, `✕` нет. 
* Управление окном перенесено в:
  1. Меню кнопки `⚙️ Настройки` внизу сайдбара (`MenuItem: "Развернуть окно" / "Закрыть приложение"`).
  2. Двойной клик по свободной области сайдбара (развернуть/восстановить).

---

## 6. Рекомендации к предстоящему рефакторингу графа

1. **Удалить блок `miniControls` из `GraphView.qml`**: если граф живёт внутри листа документа, кнопки `resetView` и `closeRequested` избыточны (закрытие через `Esc` / `Ctrl+G` работает чище). Либо, если эти кнопки нужны, их нужно перенести в общий заголовок листа (`EditorHeader.qml` в секцию `isGraphMode`).
2. **Удалить мёртвый сигнал `toggleGraphModeRequested`** во всех трёх файлах (`MainBar`, `EditorSplitLayout`, `web.qml`).
3. **Удалить неиспользуемые флаги** (`isCustomWidthSetByUser`, `isCustomFontSizeSetByUser`, `isTitleFocused`, `draggedNewWin`) для разгрузки контекста и памяти.
4. **Физика графа:** переработать узлы и силовую модель графа (spring force / repulsion) с фиксированным центром экрана при инициализации, без паразитного смещения при первом клике.
