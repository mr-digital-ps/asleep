import sys
from PyQt6.QtCore import QSize, pyqtSignal
from PyQt6.QtWidgets import (QApplication, QWidget, QVBoxLayout, 
                             QLabel, QPushButton, QGridLayout)


class CalcMemory:
    """ Память калькулятора (Модель) """
    def __init__(self):
        self.memory = []
    
    def add_last(self, target):
        self.memory.append(target)

    def delete_last(self):
        if self.memory:
            del self.memory[-1]

class CalcInput(QPushButton):
    def __init__(self, text):
        super().__init__(text)
        self.setFixedSize(QSize(80, 60))
        self.text = text

class InputLayout(QGridLayout):
    button_pressed = pyqtSignal(str)

    def __init__(self):
        super().__init__()

        input_list = [
            ["(",")","C","D"],
            ["7","8","9","/"],
            ["4","5","6","*"],
            ["1","2","3","-"],
            [".","0","=","+"],
        ]

        for i, row in enumerate(input_list):
            for j, column in enumerate(row):
                btn = CalcInput(column)
            
                btn.clicked.connect(lambda checked, text=column: self.button_pressed.emit(text))
                self.addWidget(btn, i, j)

class Calcdisplay(QLabel):
    def __init__(self, text):
        super().__init__(text)
        self.setGeometry(0, 0, 400, 100)

class MainApp(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Stupid_Calc")
        self.resize(400, 400)

        self.main_layout = QVBoxLayout()
        self.display = Calcdisplay("Тут будет ввод...")
        self.input_layout = InputLayout()
        self.memory = CalcMemory()

        self.main_layout.addWidget(self.display)
        self.main_layout.addLayout(self.input_layout)

        self.input_layout.button_pressed.connect(self.handle_input)

        self.setLayout(self.main_layout)

    def handle_input(self, button_text):
        """ Этот метод срабатывает каждый раз, когда мы ловим сигнал снизу """
        
        if button_text == "C":
            self.memory.memory.clear()
        elif button_text == "D":
            self.memory.delete_last()
        else:
            self.memory.add_last(button_text)
            
        display_string = "".join(self.memory.memory)
        self.display.setText(display_string)


if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = MainApp()
    window.show()
    sys.exit(app.exec())
