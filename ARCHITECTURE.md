# Архитектурное руководство my-text-editor

## Принципы архитектуры
1. **Single Responsibility**: каждый файл выполняет одну четкую задачу и не должен разрастаться более 300–400 строк.
2. **Изоляция UI и логики**:
   - `services/` — чистый Python код работы с диском, окнами и данными.
   - `js/` — клиентская логика (манипуляции с текстом, физика перетаскивания, состояние вкладок).
   - `components/` — только QML-компоненты представления.
3. **Безопасность данных**:
   - Синхронизация блоков Markdown (`## `) никогда не затирает непустые данные пустой строкой.
   - Коллизии заголовков с разным текстом объединяются (Safe Merge), а не перезаписываются.

---

## Структура репозитория

```
asleep-pyqt/ (корень проекта)
├── services/                 # Бэкенд на Python (Qt / OS / I/O)
│   ├── block_engine.py       # Парсинг и кэш Markdown-блоков
│   ├── file_service.py       # Файловые операции и нативные диалоги
│   ├── window_manager.py     # Реестр окон ОС и зоны сброса
│   ├── config_service.py     # Парсинг frontmatter и настроек
│   └── syntax_highlighter.py # Подсветка синтаксиса Markdown для QTextDocument
│
├── js/                       # Клиентские модули JavaScript
│   ├── tabs.js               # Стейт-машина модели вкладок и сплитов
│   ├── drag_manager.js       # Физика Drag-and-Drop окон и вкладок
│   ├── markdown_shortcuts.js # Горячие клавиши, списки, авто-пары, умный Enter
│   └── block_sync.js         # Клиентский парсинг границ блоков ##
│
├── components/               # Модули интерфейса QML
│   ├── editor/               # Компоненты редактора
│   │   ├── qmldir
│   │   ├── EditorSplitLayout.qml
│   │   ├── MainBar.qml
│   │   ├── DocumentHeader.qml
│   │   ├── EditorGutter.qml
│   │   ├── EditorScrollbar.qml
│   │   ├── SheetResizeHandle.qml
│   │   └── SyncNotice.qml
│   │
│   └── sidebar/              # Компоненты бокового меню
│       ├── qmldir
│       ├── Sidebar.qml
│       └── SidebarFileList.qml
│
├── web.py                    # Фасад Backend + Live Reload
├── web.qml                   # Главный контейнер интерфейса
├── window.qml                # Корневое ApplicationWindow
├── verify.py                 # Скрипт самодиагностики проекта
└── pyproject.toml            # Зависимости и конфигурация проекта
```

---

## Диагностика проекта
Перед отправкой изменений запустите:
```bash
uv run python verify.py
```
Скрипт проверяет целостность файловой структуры, импорты сервисов и компиляцию QML.
