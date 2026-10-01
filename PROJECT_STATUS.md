# Реестр компонентов и статус переноса (Feature Matrix)

> Принцип: зелёные компоненты проверены и работают стабильно. Серые — временно изолированы флагами. Красные — балласт на удаление.

## Матрица компонентов

| Модуль | Файл / Компонент | Статус | Заметки |
| :--- | :--- | :---: | :--- |
| **Окно (Window)** | `views/window.qml`, `WindowFrame.qml` | 🟢 Работает | Безрамочное окно, resize, drag, закрытие, QML движок собирает дерево |
| **Тема (Theme)** | `components/theme/Theme.qml`, `config/default/theme.json` | 🟢 Работает | Цвета и стили темы |
| **Конфиги (Config)** | `config/default/*.json` | 🟢 Работает | App, Theme, Editor, Hotkeys, Graph |
| **Рабочее пространство (Workspace)** | `components/workspace/` | 🟢 Работает | Сплит панелей `WorkspaceSplit`, контейнер панелей `WorkspacePane`, единые `PaneHeader` и `PaneFooter` |
| **Лист редактора** | `components/editor/EditorSheet.qml` | 🟢 Работает | Чистый бумажный лист: фокус, TextArea, подсветка синтаксиса MarkdownHighlighter активна |
| **Хедер панели** | `components/workspace/PaneHeader.qml` | 🟢 Работает | Единый расширяемый HUD: заголовок, булавка, встроенный Git Graph таймлайн (`history`), статистика (`info`), плавающая высота |
| **Футер панели** | `components/workspace/PaneFooter.qml` | ❌ Удалён | Полностью устранён: функционал истории и статистики перенесен в расширяемый PaneHeader, освобождая низ экрана |
| **История (History)** | `components/history/` | 🟢 Работает | Горизонтальный Git Graph таймлайн, моноширинный блок даты/времени, встроен в выдвижной ящик хедера |
| **Сайдбар** | `components/sidebar/` | ❌ Удалён | Исключён из архитектуры проекта: упор на чистый минималистичный лист |
| **Сплиты (Split)** | `components/workspace/WorkspaceSplit.qml` | 🟢 Работает | Разделение экрана на 2 панели (Ctrl+\), ресайз сплиттера, независимый ввод |
| **Хоткеи** | `components/hotkeys/`, `services/system/hotkey_service.py` | 🟢 Работает | Аппаратный GlobalHotkeyFilter, русская раскладка, Ctrl+S/N/O/W, Alt+W |
| **Граф знаний** | `components/graph/GraphView.qml` | 🟢 Работает | Интерактивный Canvas-граф (Ctrl+G, Alt+G), физика связей, центрирование |
| **Аутлайнер / Структура** | `components/outliner/DocumentOutliner.qml` | 🟢 Работает | Оглавление заметок и структура проекта, drag-and-drop блоков, вынесен в автономный модуль |
| **Парсер диалекта** | `services/content/user_dialect_parser.py` | 🟢 Работает | Пользовательский диалект для писателей/сценаристов: блоки `Имя { ... }`, трансклюзия `Имя()`, `Файл.Имя()`, `[[...]]`, экранирование кода |
| **Detached Tabs** | `tabs.js` (открепление на рабочий стол) | ❌ Удалён | Вычищен: в монолитной модели используется чистый Split View без рассинхронов |
| **Views Контроллеры** | `views/web_lifecycle.js`, `views/window_controller.js` | 🟢 Монолит | Устранены `views/tabs/` и `action_dispatcher.js`, единый жизненный цикл и диспетчеризация |

## Текущий этап: Все основные фазы (1 - 5) завершены и архитектура очищена
- [x] Окно открывается с правильным фоном темы
- [x] Окно двигается и меняет размер
- [x] Чистый лист редактора на весь экран
- [x] Хоткеи: Ctrl+S (сохранение), Ctrl+N (новый), Ctrl+O (открытие), Ctrl+W (закрытие)
- [x] Центрированный режим: Alt+W (или Alt+J)
- [x] Сплит-режим: Ctrl+\ делит экран на две независимые панели с перетаскиваемым сплиттером
- [x] Граф заметок: Ctrl+G (глобальный граф связей), Alt+G (локальный граф)
- [x] Корневая папка `js/` полностью устранена: скрипты перенесены в соответствующие фичи
- [x] Иерархия `views/` сокращена до чистого монолита: удалены `views/tabs/` и `action_dispatcher.js`
- [x] Fix: `backend` прокинут явно в `.pragma library` (`openFileFromFolder`, `createNewTab`, `renameTab`, `handleNodeSelected`)
- [x] Fix: двойной toggle графа в `WorkspaceSplit` устранён (один вызов `toggleGraph()`)
- [x] Fix: binding loop `height` в `scrollContentContainer` (замена `availableHeight` → `height`)
- [x] Реализован парсер пользовательского диалекта `user_dialect_parser.py` с тестами (блоки с пробелами, запрет точек в имени, трансклюзия, вики-ссылки, экранирование в коде)
- [x] 100% тестов в verify.py пройдены

