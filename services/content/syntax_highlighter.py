"""
syntax_highlighter.py — подсветка синтаксиса Markdown для QTextDocument.

Поддерживает:
- Live Preview режим (в стиле Obsidian / Neovim render-markdown):
  - Крупные типографические заголовки H1-H3
  - Затухание/скрытие служебных символов на неактивных строках
  - Мгновенное раскрытие разметки при переходе курсора на строку
  - Переключение Live Preview / Source Mode через Ctrl+E
- Заголовки (# .. ######) с визуальным выделением
- Жирный (**жирный**, __жирный__)
- Курсив (*курсив*, _курсив_)
- Зачеркивание (~~зачеркнутый~~)
- Встроенный код (`код`)
- Блоки кода (```) с многострочным состоянием
- Цитаты (> цитата)
- Чекбоксы задач (- [ ] и - [x])
- Маркированные и нумерованные списки
- Ссылки ([текст](url))
- Вики-ссылки ([[заметка]])
- Теги (#тег)
- Горизонтальные разделители (---, ***)
"""

from PyQt6.QtGui import QSyntaxHighlighter, QTextCharFormat, QColor, QFont
from PyQt6.QtCore import QRegularExpression


class MarkdownHighlighter(QSyntaxHighlighter):
    """
    Высокопроизводительный подсветчик Markdown с поддержкой Live Preview
    для QQuickTextDocument / QTextDocument.
    """

    STATE_NORMAL = 0
    STATE_CODE_BLOCK = 1

    def __init__(self, parent_document):
        super().__init__(parent_document)
        self.live_preview_enabled: bool = False
        self.active_block_number: int = -1

        self._init_formats()
        self._init_rules()

    def _init_formats(self):
        # --- Базовые форматы заголовков (Source Mode) ---
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

        # --- Форматы заголовков для Live Preview (с типографическим масштабом) ---
        self.fmt_lp_h1 = QTextCharFormat()
        self.fmt_lp_h1.setForeground(QColor("#ffffff"))
        self.fmt_lp_h1.setFontWeight(QFont.Weight.Bold)
        self.fmt_lp_h1.setFontPointSize(20.0)

        self.fmt_lp_h2 = QTextCharFormat()
        self.fmt_lp_h2.setForeground(QColor("#eceff4"))
        self.fmt_lp_h2.setFontWeight(QFont.Weight.Bold)
        self.fmt_lp_h2.setFontPointSize(17.0)

        self.fmt_lp_h3 = QTextCharFormat()
        self.fmt_lp_h3.setForeground(QColor("#e5e9f0"))
        self.fmt_lp_h3.setFontWeight(QFont.Weight.DemiBold)
        self.fmt_lp_h3.setFontPointSize(15.0)

        self.fmt_lp_h_other = QTextCharFormat()
        self.fmt_lp_h_other.setForeground(QColor("#d8dee9"))
        self.fmt_lp_h_other.setFontWeight(QFont.Weight.DemiBold)
        self.fmt_lp_h_other.setFontPointSize(13.5)

        # Символы решетки в заголовках (#)
        self.fmt_hash = QTextCharFormat()
        self.fmt_hash.setForeground(QColor("#5c6370"))
        self.fmt_hash.setFontWeight(QFont.Weight.Normal)

        # Формат приглушения/скрытия служебных символов разметки на неактивных строках
        self.fmt_conceal = QTextCharFormat()
        self.fmt_conceal.setForeground(QColor(110, 115, 128, 55))

        # Формат приглушения хеша заголовка на неактивной строке
        self.fmt_conceal_hash = QTextCharFormat()
        self.fmt_conceal_hash.setForeground(QColor(110, 115, 128, 45))
        self.fmt_conceal_hash.setFontPointSize(11.0)
        self.fmt_conceal_hash.setFontWeight(QFont.Weight.Normal)

        # 2. Жирный текст (**bold** или __bold__)
        self.fmt_bold = QTextCharFormat()
        self.fmt_bold.setForeground(QColor("#f0f0f0"))
        self.fmt_bold.setFontWeight(QFont.Weight.Bold)

        # 3. Курсив (*italic* или _italic_)
        self.fmt_italic = QTextCharFormat()
        self.fmt_italic.setForeground(QColor("#c5c8c6"))
        self.fmt_italic.setFontItalic(True)

        # 4. Зачеркнутый текст (~~strike~~)
        self.fmt_strike = QTextCharFormat()
        self.fmt_strike.setFontStrikeOut(True)
        self.fmt_strike.setForeground(QColor("#7e8a9d"))

        # 5. Встроенный код (`code`)
        self.fmt_inline_code = QTextCharFormat()
        self.fmt_inline_code.setForeground(QColor("#e5c07b"))
        self.fmt_inline_code.setBackground(QColor("#21252b"))
        self.fmt_inline_code.setFontFamily("Consolas, Courier New, monospace")

        # 6. Блок кода (```...```)
        self.fmt_code_block = QTextCharFormat()
        self.fmt_code_block.setForeground(QColor("#abb2bf"))
        self.fmt_code_block.setBackground(QColor("#1e2227"))
        self.fmt_code_block.setFontFamily("Consolas, Courier New, monospace")

        # 7. Цитата (> quote)
        self.fmt_quote = QTextCharFormat()
        self.fmt_quote.setForeground(QColor("#7e8a9d"))
        self.fmt_quote.setFontItalic(True)

        # 8. Задачи: - [ ] не завершено, - [x] завершено
        self.fmt_task_open = QTextCharFormat()
        self.fmt_task_open.setForeground(QColor("#d19a66"))
        self.fmt_task_open.setFontWeight(QFont.Weight.Bold)

        self.fmt_task_done = QTextCharFormat()
        self.fmt_task_done.setForeground(QColor("#98c379"))
        self.fmt_task_done.setFontWeight(QFont.Weight.DemiBold)

        self.fmt_task_done_text = QTextCharFormat()
        self.fmt_task_done_text.setForeground(QColor("#5c6370"))
        self.fmt_task_done_text.setFontStrikeOut(True)

        # 9. Разделители (---, ***)
        self.fmt_hr = QTextCharFormat()
        self.fmt_hr.setForeground(QColor("#4b5263"))
        self.fmt_hr.setFontWeight(QFont.Weight.Bold)

        # 10. Теги (#тег) — точечное подчеркивание (Dotted Underline)
        self.fmt_tag = QTextCharFormat()
        self.fmt_tag.setForeground(QColor("#ffffff"))
        self.fmt_tag.setUnderlineStyle(QTextCharFormat.UnderlineStyle.DotLine)
        self.fmt_tag.setUnderlineColor(QColor("#ffffff"))

        # 11. Фигурные скобки блоков { и }
        self.fmt_brace = QTextCharFormat()
        self.fmt_brace.setForeground(QColor("#888888"))
        self.fmt_brace.setFontWeight(QFont.Weight.Bold)

        # 12. Списки (- item, * item, 1. item)
        self.fmt_list = QTextCharFormat()
        self.fmt_list.setForeground(QColor("#d19a66"))

    def _init_rules(self):
        # Регулярные выражения
        self.re_brace = QRegularExpression(r"[{}]")
        self.re_code_block_fence = QRegularExpression(r"^[ \t]*```")
        self.re_inline_code = QRegularExpression(r"`([^`\n]+)`")
        self.re_bold = QRegularExpression(r"(\*\*|__)(.*?)\1")
        self.re_italic = QRegularExpression(r"(?<!\*|\w)(\*|_)(?!\*|_)(.*?)(?<!\*|_)\1(?!\*|\w)")
        self.re_strike = QRegularExpression(r"~~(.*?)~~")
        self.re_quote = QRegularExpression(r"^[ \t]*>.*$")
        self.re_task_open = QRegularExpression(r"^[ \t]*[-*+]\s+(\[ \])")
        self.re_task_done = QRegularExpression(r"^[ \t]*[-*+]\s+(\[[xX]\])(.*)$")
        self.re_list = QRegularExpression(r"^[ \t]*([-*+]|\d+\.)\s")
        self.re_link = QRegularExpression(r"(\[([^\]\n]+)\])(\(([^)\n]+)\))")
        self.re_wikilink = QRegularExpression(r"(\[\[)([^\]\n]+)(\]\])")
        self.re_tag = QRegularExpression(r"(?:^|\s)(#[\p{L}0-9_\-]+)")

    def set_cursor_position(self, pos: int):
        """
        Обновляет номер активной строки по позиции курсора.
        Выполняет точечную переподсветку только старого и нового блока (O(1)).
        """
        doc = self.document()
        if not doc:
            return
        block = doc.findBlock(pos)
        new_block_num = block.blockNumber() if block.isValid() else -1
        if new_block_num != self.active_block_number:
            old_block_num = self.active_block_number
            self.active_block_number = new_block_num
            if self.live_preview_enabled:
                if old_block_num >= 0:
                    old_block = doc.findBlockByNumber(old_block_num)
                    if old_block.isValid():
                        self.rehighlightBlock(old_block)
                if new_block_num >= 0:
                    new_block = doc.findBlockByNumber(new_block_num)
                    if new_block.isValid():
                        self.rehighlightBlock(new_block)

    def toggle_live_preview(self) -> bool:
        """Переключает режим Live Preview ⟷ Source Mode и обновляет подсветку."""
        self.live_preview_enabled = not self.live_preview_enabled
        self.rehighlight()
        return self.live_preview_enabled

    def highlightBlock(self, text: str | None):
        if not text:
            self.setCurrentBlockState(self.STATE_NORMAL)
            return

        # В сухом текстовом режиме (Text / Notes) подсветка отключена:
        # чистый прозрачный монохромный текст без цветных ссылок, тегов и отвлекающих факторов
        if not self.live_preview_enabled:
            self.setCurrentBlockState(self.STATE_NORMAL)
            return

        current_block = self.currentBlock()
        blk_num = current_block.blockNumber() if current_block.isValid() else -1
        is_active = (blk_num == self.active_block_number)
        lp = self.live_preview_enabled

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

        # 2. Фигурные скобки блоков { и }
        it_brace = self.re_brace.globalMatch(text)
        while it_brace.hasNext():
            m_brace = it_brace.next()
            self.setFormat(m_brace.capturedStart(), m_brace.capturedLength(), self.fmt_brace)

        # 4. Цитаты
        if self.re_quote.match(text).hasMatch():
            self.setFormat(0, len(text), self.fmt_quote)
            if lp and not is_active:
                self.setFormat(0, 1, self.fmt_conceal)
            return

        # 5. Списки и задачи
        m_task_open = self.re_task_open.match(text)
        if m_task_open.hasMatch():
            self.setFormat(m_task_open.capturedStart(1), m_task_open.capturedLength(1), self.fmt_task_open)
        else:
            m_task_done = self.re_task_done.match(text)
            if m_task_done.hasMatch():
                self.setFormat(m_task_done.capturedStart(1), m_task_done.capturedLength(1), self.fmt_task_done)
                if lp and not is_active and m_task_done.capturedLength(2) > 0:
                    self.setFormat(m_task_done.capturedStart(2), m_task_done.capturedLength(2), self.fmt_task_done_text)
            else:
                m_list = self.re_list.match(text)
                if m_list.hasMatch():
                    self.setFormat(m_list.capturedStart(), m_list.capturedLength(), self.fmt_list)

        # 6. Жирный текст (**bold** или __bold__)
        it_bold = self.re_bold.globalMatch(text)
        while it_bold.hasNext():
            match = it_bold.next()
            m_start = match.capturedStart()
            m_len = match.capturedLength()
            delim_len = len(match.captured(1))
            self.setFormat(m_start, m_len, self.fmt_bold)
            if lp and not is_active:
                # Приглушаем маркеры разметки (** или __)
                self.setFormat(m_start, delim_len, self.fmt_conceal)
                self.setFormat(m_start + m_len - delim_len, delim_len, self.fmt_conceal)

        # 7. Курсив (*italic* или _italic_)
        it_italic = self.re_italic.globalMatch(text)
        while it_italic.hasNext():
            match = it_italic.next()
            m_start = match.capturedStart()
            m_len = match.capturedLength()
            self.setFormat(m_start, m_len, self.fmt_italic)
            if lp and not is_active:
                self.setFormat(m_start, 1, self.fmt_conceal)
                self.setFormat(m_start + m_len - 1, 1, self.fmt_conceal)

        # 8. Зачеркивание (~~strike~~)
        it_strike = self.re_strike.globalMatch(text)
        while it_strike.hasNext():
            match = it_strike.next()
            m_start = match.capturedStart()
            m_len = match.capturedLength()
            self.setFormat(m_start, m_len, self.fmt_strike)
            if lp and not is_active:
                self.setFormat(m_start, 2, self.fmt_conceal)
                self.setFormat(m_start + m_len - 2, 2, self.fmt_conceal)

        # 9. Ссылки [text](url) и вики-ссылки [[заметка]] (скрытие маркеров разметки только в Live Preview)
        if lp and not is_active:
            it_link = self.re_link.globalMatch(text)
            while it_link.hasNext():
                match = it_link.next()
                self.setFormat(match.capturedStart(1), 1, self.fmt_conceal)
                self.setFormat(match.capturedEnd(1) - 1, 1, self.fmt_conceal)
                self.setFormat(match.capturedStart(3), match.capturedLength(3), self.fmt_conceal)

            it_wiki = self.re_wikilink.globalMatch(text)
            while it_wiki.hasNext():
                match = it_wiki.next()
                self.setFormat(match.capturedStart(1), match.capturedLength(1), self.fmt_conceal)
                self.setFormat(match.capturedStart(3), match.capturedLength(3), self.fmt_conceal)


        # 12. Встроенный код `code` (поверх остальных)
        it_code = self.re_inline_code.globalMatch(text)
        while it_code.hasNext():
            match = it_code.next()
            m_start = match.capturedStart()
            m_len = match.capturedLength()
            self.setFormat(m_start, m_len, self.fmt_inline_code)
            if lp and not is_active:
                self.setFormat(m_start, 1, self.fmt_conceal)
                self.setFormat(m_start + m_len - 1, 1, self.fmt_conceal)

        # 13. Теги (#тег) с точечным подчеркиванием (Dotted Underline)
        it_tag = self.re_tag.globalMatch(text)
        while it_tag.hasNext():
            match = it_tag.next()
            self.setFormat(match.capturedStart(1), match.capturedLength(1), self.fmt_tag)
