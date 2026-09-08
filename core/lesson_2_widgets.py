import sys
from PyQt6.QtWidgets import (QApplication, QWidget, QVBoxLayout, 
                             QLabel, QCheckBox, QComboBox, QPushButton)

class WidgetsDemo(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Урок 2: Базовые виджеты")
        self.resize(300, 200)
        
        layout = QVBoxLayout()
        
        # 1. Текст или надпись (QLabel)
        self.label = QLabel("Настройте свой профиль:")
        
        # 2. Галочка (QCheckBox)
        self.checkbox = QCheckBox("Получать уведомления")
        
        # 3. Выпадающий список (QComboBox)
        self.combo = QComboBox()
        self.combo.addItems(["Python", "JavaScript", "C++", "Go", "Rust"])
        
        # 4. Кнопка
        self.btn = QPushButton("Сохранить результат")
        # Связываем клик с функцией
        self.btn.clicked.connect(self.show_results)
        
        # Добавляем виджеты в компоновку
        layout.addWidget(self.label)
        layout.addWidget(self.checkbox)
        layout.addWidget(self.combo)
        layout.addWidget(self.btn)
        
        self.setLayout(layout)

    # 5. ФУНКЦИЯ ДЛЯ ЧТЕНИЯ ДАННЫХ
    def show_results(self):
        # Как получать данные из виджетов:
        
        # isChecked() возвращает True (если галочка стоит) или False
        is_notifications = self.checkbox.isChecked() 
        
        # currentText() возвращает текст выбранного пункта меню
        lang = self.combo.currentText()     
        
        # Формируем результат и выводим его в консоль (или можно было в QMessageBox)
        notif_text = "Включены" if is_notifications else "Выключены"
        print(f"Уведомления: {notif_text}. Выбран язык: {lang}")
        
        # Мы также можем изменять виджеты "на лету" - например, поменять текст у Label
        self.label.setText(f"Сохранено! Язык: {lang}")

if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = WidgetsDemo()
    window.show()
    sys.exit(app.exec())
