import sys
from PyQt6.QtWidgets import QApplication, QGraphicsView, QGraphicsScene, QGraphicsEllipseItem, QGraphicsLineItem, QMainWindow
from PyQt6.QtGui import QPen, QBrush, QColor, QPainter
from PyQt6.QtCore import Qt

class Node(QGraphicsEllipseItem):
    def __init__(self, x, y):
        # Чтобы центр круга совпадал с координатой мыши, рисуем его от -25 до +25
        super().__init__(-25, -25, 50, 50)
        self.setPos(x, y) # Ставим на нужные координаты
        self.setBrush(QBrush(QColor("skyblue")))
        
        # Разрешаем таскать узел И сообщать об изменении координат!
        self.setFlag(QGraphicsEllipseItem.GraphicsItemFlag.ItemIsMovable)
        self.setFlag(QGraphicsEllipseItem.GraphicsItemFlag.ItemSendsGeometryChanges)
        
        self.edges = [] # Тут будем хранить линии, привязанные к этому узлу

    def add_edge(self, edge):       
        self.edges.append(edge)

    # Эта магическая функция PyQt срабатывает КАЖДЫЙ РАЗ, когда мы тягаем узел
    def itemChange(self, change, value):
        if change == QGraphicsEllipseItem.GraphicsItemChange.ItemPositionHasChanged:
            # Говорим всем линиям: "Я сдвинулся, перерисуйтесь!"
            for edge in self.edges:
                edge.update_positions()
        return super().itemChange(change, value)


class Edge(QGraphicsLineItem):
    def __init__(self, source_node, dest_node):
        super().__init__()
        self.source_node = source_node
        self.dest_node = dest_node
        
        # Линия "привязывает" себя к обоим узлам
        self.source_node.add_edge(self)
        self.dest_node.add_edge(self)
        
        self.setPen(QPen(QColor("black"), 2))
        self.setZValue(-1) # Линия должна лежать "под" узлами
        self.update_positions() # Отрисовываем себя при создании

    def update_positions(self):
        # Рисуем линию от текущих координат первого узла до второго
        self.setLine(
            self.source_node.pos().x(),
            self.source_node.pos().y(),
            self.dest_node.pos().x(), 
            self.dest_node.pos().y()
        )


class GraphWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Наш собственный интерактивный граф")
        self.resize(800, 600)

        self.scene = QGraphicsScene()
        self.view = QGraphicsView(self.scene)
        self.view.setRenderHint(QPainter.RenderHint.Antialiasing)
        self.setCentralWidget(self.view)

        self.draw_test_graph()

    def draw_test_graph(self):
        # Теперь создание графа выглядит очень элегантно!
        node1 = Node(100, 100)
        node2 = Node(300, 200)
        node3 = Node(150, 300)

        self.scene.addItem(node1)
        self.scene.addItem(node2)
        self.scene.addItem(node3)

        # Соединяем их нашими "умными" линиями
        edge1 = Edge(node1, node2)
        edge2 = Edge(node2, node3)
        edge3 = Edge(node3, node1)

        self.scene.addItem(edge1)
        self.scene.addItem(edge2)
        self.scene.addItem(edge3)


if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = GraphWindow()
    window.show()
    sys.exit(app.exec())
