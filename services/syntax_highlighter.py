"""
syntax_highlighter.py — подсветка синтаксиса Markdown для QTextDocument.

Поддерживает:
- Заголовки (# .. ######) с визуальным выделением
- Жирный (**жирный**, __жирный__)
- Курсив (*курсив*, _курсив_)
- Встроенный код (`код`)
- Блоки кода (```) с многострочным состоянием
- Цитаты (> цитата)
- Чекбоксы задач (- [ ] и - [x])
- Маркированные и нумерованные списки
- Ссылки ([текст](url))
- Горизонтальные разделители (---, ***)
"""

import sys
from PyQt6.QtGui import QSyntaxHighlighter, QTextCharFormat, QColor, QFont
from PyQt6.QtCore import QRegularExpression

class MarkdownHighlighter(QSyntaxHighlighter):
    """
    Высокопроизводительный легковесный подсветчик Markdown для QQuickTextDocument.
    """

    STATE_NORMAL = 0
    STATE_CODE_BLOCK = 1

    def __init__(self, parent_document):
        super().__init__(parent_document)
        self._init_formats()
        self._init_rules()

    def _init_formats(self):
        # 1. Заголовки (# H1, ## H2, etc.)
        self.fmt_h1 = QTextCharFormat()
        self.fmt_h1.setForeground(QColor("#ffffff"))
        self.fmt_h1.setFontWeight(QFont.Weight.Bold)

        self.fmt_h2 = QTextCharFormat()
        self.fmt_h2.setForeground(QColor("#eceff4"))
        self.fmt_h2.setFontWeight(QFont.Weight.Bold)

        self.fmt_h3 = QTextCharFormat()
        self.fmt_h3.setForeground(QColor("#e5e9f0"))
        self.fmt_h3.setFontWeight(QFont.Weight.DemiBold)

        self.fmt_h_other = QTextCharFormat()
        self.fmt_h_other.setForeground(QColor("#d8dee9"))
        self.fmt_h_other.setFontWeight(QFont.Weight.DemiBold)

        # Символы решетки в заголовках (#)
        self.fmt_hash = QTextCharFormat()
        self.fmt_hash.setForeground(QColor("#5c6370"))
        self.fmt_hash.setFontWeight(QFont.Weight.Normal)

        # 2. Жирный текст (**bold** или __bold__)
        self.fmt_bold = QTextCharFormat()
        self.fmt_bold.setForeground(QColor("#f0f0f0"))
        self.fmt_bold.setFontWeight(QFont.Weight.Bold)

        # 3. Курсив (*italic* или _italic_)
        self.fmt_italic = QTextCharFormat()
        self.fmt_italic.setForeground(QColor("#c5c8c6"))
        self.fmt_italic.setFontItalic(True)

        # 4. Встроенный код (`code`)
        self.fmt_inline_code = QTextCharFormat()
        self.fmt_inline_code.setForeground(QColor("#e5c07b"))
        self.fmt_inline_code.setBackground(QColor("#24272e"))
        self.fmt_inline_code.setFontFamily("Consolas, Courier New, monospace")

        # 5. Блок кода (```...```)
        self.fmt_code_block = QTextCharFormat()
        self.fmt_code_block.setForeground(QColor("#abb2bf"))
        self.fmt_code_block.setBackground(QColor("#1e2227"))
        self.fmt_code_block.setFontFamily("Consolas, Courier New, monospace")

        # 6. Цитата (> quote)
        self.fmt_quote = QTextCharFormat()
        self.fmt_quote.setForeground(QColor("#7e8a9d"))
        self.fmt_quote.setFontItalic(True)

        # 7. Задачи: - [ ] не завершено, - [x] завершено
        self.fmt_task_open = QTextCharFormat()
        self.fmt_task_open.setForeground(QColor("#e06c75"))
        self.fmt_task_open.setFontWeight(QFont.Weight.Bold)

        self.fmt_task_done = QTextCharFormat()
        self.fmt_task_done.setForeground(QColor("#98c379"))
        self.fmt_task_done.setFontWeight(QFont.Weight.DemiBold)

        # 8. Списки (- , * , 1. )
        self.fmt_list = QTextCharFormat()
        self.fmt_list.setForeground(QColor("#61afef"))

        # 9. Ссылки [text](url)
        self.fmt_link_text = QTextCharFormat()
        self.fmt_link_text.setForeground(QColor("#61afef"))
        self.fmt_link_text.setFontUnderline(True)

        self.fmt_link_url = QTextCharFormat()
        self.fmt_link_url.setForeground(QColor("#5c6370"))

        # 10. Разделители (---, ***)
        self.fmt_hr = QTextCharFormat()
        self.fmt_hr.setForeground(QColor("#4b5263"))
        self.fmt_hr.setFontWeight(QFont.Weight.Bold)

    def _init_rules(self):
        # Регулярные выражения
        self.re_code_block_fence = QRegularExpression(r"^[ \t]*```")
        self.re_inline_code = QRegularExpression(r"`([^`\n]+)`")
        self.re_bold = QRegularExpression(r"(\*\*|__)(.*?)\1")
        self.re_italic = QRegularExpression(r"(?<!\*|\w)(\*|_)(?!\*|_)(.*?)(?<!\*|_)\1(?!\*|\w)")
        self.re_quote = QRegularExpression(r"^[ \t]*>.*$")
        self.re_task_open = QRegularExpression(r"^[ \t]*[-*+]\s+\[ \]")
        self.re_task_done = QRegularExpression(r"^[ \t]*[-*+]\s+\[[xX]\]")
        self.re_list = QRegularExpression(r"^[ \t]*([-*+]|\d+\.)\s")
        self.re_link = QRegularExpression(r"(\[([^\]\n]+)\])(\(([^)\n]+)\))")
        self.re_hr = QRegularExpression(r"^[ \t]*(-{3,}|\*{3,}|_{3,})[ \t]*$")
        self.re_heading = QRegularExpression(r"^[ \t]*(#{1,6})[ \t]+(.*)$")

    def highlightBlock(self, text: str):
        if not text:
            self.setCurrentBlockState(self.STATE_NORMAL)
            return

        prev_state = self.previousBlockState()

        # 1. Проверка блока кода ```
        is_fence = self.re_code_block_fence.match(text).hasMatch()
        if prev_state == self.STATE_CODE_BLOCK:
            self.setFormat(0, len(text), self.fmt_code_block)
            if is_fence:
                self.setCurrentBlockState(self.STATE_NORMAL)
            else:
                self.setCurrentBlockState(self.STATE_CODE_BLOCK)
            return
        elif is_fence:
            self.setFormat(0, len(text), self.fmt_code_block)
            self.setCurrentBlockState(self.STATE_CODE_BLOCK)
            return

        self.setCurrentBlockState(self.STATE_NORMAL)

        # 2. Горизонтальный разделитель ---
        if self.re_hr.match(text).hasMatch():
            self.setFormat(0, len(text), self.fmt_hr)
            return

        # 3. Заголовки (# .. ######)
        m_head = self.re_heading.match(text)
        if m_head.hasMatch():
            hashes = m_head.captured(1)
            level = len(hashes)
            hash_start = m_head.capturedStart(1)
            hash_len = len(hashes)

            if level == 1:
                fmt = self.fmt_h1
            elif level == 2:
                fmt = self.fmt_h2
            elif level == 3:
                fmt = self.fmt_h3
            else:
                fmt = self.fmt_h_other

            # Форматируем всю строку
            self.setFormat(0, len(text), fmt)
            # Символы # делаем чуть тоньше и спокойнее
            self.setFormat(hash_start, hash_len, self.fmt_hash)
            return

        # 4. Цитаты
        if self.re_quote.match(text).hasMatch():
            self.setFormat(0, len(text), self.fmt_quote)
            return

        # 5. Списки и задачи
        m_task_open = self.re_task_open.match(text)
        if m_task_open.hasMatch():
            self.setFormat(m_task_open.capturedStart(), m_task_open.capturedLength(), self.fmt_task_open)
        else:
            m_task_done = self.re_task_done.match(text)
            if m_task_done.hasMatch():
                self.setFormat(m_task_done.capturedStart(), m_task_done.capturedLength(), self.fmt_task_done)
            else:
                m_list = self.re_list.match(text)
                if m_list.hasMatch():
                    self.setFormat(m_list.capturedStart(), m_list.capturedLength(), self.fmt_list)

        # 6. Жирный текст
        it = self.re_bold.globalMatch(text)
        while it.hasNext():
            match = it.next()
            self.setFormat(match.capturedStart(), match.capturedLength(), self.fmt_bold)

        # 7. Курсив
        it = self.re_italic.globalMatch(text)
        while it.hasNext():
            match = it.next()
            self.setFormat(match.capturedStart(), match.capturedLength(), self.fmt_italic)

        # 8. Ссылки [text](url)
        it = self.re_link.globalMatch(text)
        while it.hasNext():
            match = it.next()
            # [text]
            self.setFormat(match.capturedStart(1), match.capturedLength(1), self.fmt_link_text)
            # (url)
            self.setFormat(match.capturedStart(3), match.capturedLength(3), self.fmt_link_url)

        # 9. Встроенный код `code` (поверх остальных)
        it = self.re_inline_code.globalMatch(text)
        while it.hasNext():
            match = it.next()
            self.setFormat(match.capturedStart(), match.capturedLength(), self.fmt_inline_code)
