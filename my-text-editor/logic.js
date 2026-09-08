// logic.js — функции для текстового редактора

// 1. Создание нового документа
function createNew(root) {
	root.editorArea.text = ''
	root.currentFileUrl = ''
	root.currentFileName = 'Новый документ'
}

// 2. Сохранение файла
function saveFile(root, saveDialog, backend) {
	if (root.currentFileUrl === '') {
		// Если файл еще не сохранялся на диске — открываем проводник
		saveDialog.open()
	} else {
		// Если файл уже имеет имя — просто перезаписываем его
		backend.save_file(root.currentFileUrl, root.editorArea.text)
	}
}

// 3. Открытие файла после выбора в проводнике
function openFile(root, fileUrl, backend) {
	var content = backend.read_file(fileUrl)
	root.editorArea.text = content
	root.currentFileUrl = fileUrl
	root.currentFileName = backend.get_filename(fileUrl)
}

// 4. Развернуть / восстановить окно
function toggleMaximize(win) {
	if (!win) return

	if (win.visibility === 4) {
		// 4 соответствует Window.Maximized
		win.showNormal()
	} else {
		win.showMaximized()
	}
}
