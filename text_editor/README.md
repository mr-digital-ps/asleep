# 📝 Простой текстовый редактор (Text Editor)

Этот проект создан как максимально понятный и чистый учебный пример.
Здесь нет перегруженного дизайна, лишних стилей или сложных трюков — только **базовая архитектура**, которую легко разобрать, понять и повторить с нуля.

---

## 🎯 Что умеет этот редактор

1. **Создавать новый документ** (кнопка `📄 Новый` или `Ctrl + N`).
2. **Открывать текстовые файлы** с диска через системный диалог (`📂 Открыть...` или `Ctrl + O`).
3. **Сохранять текущий файл** (`💾 Сохранить` или `Ctrl + S`).
4. **Сохранять в новый файл** через диалог (`💾 Сохранить как...`).
5. **Вводить многострочный текст** со скроллом и автопереносом строк (`TextArea` + `ScrollView`).
6. **Отображать статус**: имя файла в заголовке окна, статус операций и счетчик символов / строк в нижней панели (Status Bar).

---

## 📂 Структура проекта

```text
text_editor/
├── main.py     # Python-часть (Backend): чтение и запись файлов
├── main.qml    # QML-интерфейс (Frontend): кнопки, поле ввода, диалоги
└── README.md   # Это руководство для обучения
```

---

## 🧠 Как это работает: пошаговый разбор

### 1. Разделение обязанностей (Python vs QML)
* **QML** не имеет встроенных безопасных средств прямой записи файлов на диск. QML отвечает **только за отображение**: как выглядит кнопка, куда вводится текст, какие диалоговые окна всплывают.
* **Python** выполняет всю работу с операционной системой: находит файл, читает его содержимое в кодировке `UTF-8` или `CP1251`, записывает текст обратно.

### 2. Мост между Python и QML
В [main.py](file:///c:/.personal/.development/asleep-pyqt/text_editor/main.py) создан класс `TextEditorBackend(QObject)`:
```python
# Слоты (методы, которые QML может вызывать как функции):
@pyqtSlot(str, result=str)
def read_file(self, file_url: str) -> str:
    ...

@pyqtSlot(str, str, result=bool)
def save_file(self, file_url: str, content: str) -> bool:
    ...

# Сигналы (Python сообщает интерфейсу о событиях):
statusChanged = pyqtSignal(str)
errorOccurred = pyqtSignal(str)
```

В функции `main()` мы отдаем этот объект в QML:
```python
engine.rootContext().setContextProperty("backend", backend)
```
После этого в [main.qml](file:///c:/.personal/.development/asleep-pyqt/text_editor/main.qml) слово `backend` становится доступно повсюду.

### 3. Как работают системные диалоги (`FileDialog`)
В QML диалоги выбора файла подключаются через модуль `import QtQuick.Dialogs`:
```qml
FileDialog {
    id: openDialog
    title: "Открыть файл"
    fileMode: FileDialog.OpenFile
    onAccepted: {
        // selectedFile возвращает путь в виде URL, например "file:///C:/notes.txt"
        openFile(selectedFile)
    }
}
```
А в Python мы преобразуем `QUrl` в обычный путь файловой системы:
```python
local_path = QUrl(file_url).toLocalFile()
```

### 4. Поле ввода текста со скроллом
Для текстового редактора используется пара `ScrollView` + `TextArea`:
```qml
ScrollView {
    Layout.fillWidth: true
    Layout.fillHeight: true

    TextArea {
        id: editorArea
        wrapMode: TextArea.Wrap             // Автоперенос длинных строк
        selectByMouse: true                 // Выделение мышью
        font.family: "Consolas, monospace"  // Читаемый шрифт
    }
}
```

---

## 🚀 Как запустить

Откройте терминал в корне проекта и выполните:

```powershell
.\.venv\Scripts\python.exe text_editor/main.py
```
*(или просто `python text_editor/main.py`, если ваше виртуальное окружение уже активировано)*.

---

## 🛠 Задания для закрепления (попробуй повторить и доработать):

1. **Добавить кнопку "Очистить"**: сделать кнопку, которая просто стирает текст в `editorArea.text`.
2. **Добавить подтверждение при несохраненных изменениях**: проверять, изменился ли текст с момента открытия перед нажатием `Новый` или закрытием.
3. **Изменить шрифт / размер**: добавить выпадающий список (`ComboBox`) или ползунок для изменения `font.pixelSize`.
