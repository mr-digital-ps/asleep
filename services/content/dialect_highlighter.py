# services/content/dialect_highlighter.py — Высокопроизводительный подсветчик синтаксиса для Live Mode
import re
from PyQt6.QtGui import QSyntaxHighlighter, QTextCharFormat, QColor, QFont


class DialectHighlighter(QSyntaxHighlighter):
    """
    Высокопроизводительный подсветчик канонического синтаксиса диалекта для Live Mode.
    Затемняет спецсимволы разметки (Theme.textMuted / #4c4c4c), убирая визуальный шум,
    и применяет аккуратную типографику (bold, italic, strike, underline) без изменения
    длины строк и метрик текста.

    Синтаксис вики-ссылок строго канонический [[Имя Файла]] (без алиасов).
    Разделитель --- визуально отображается нативной линией.
    Текст цитат и тегов остаётся нормальным основным цветом текста.
    Скобки блоков {} отображаются полупрозрачно/приглушённо.
    """

    def __init__(self, parent_document, theme_config: dict | None = None, is_live_mode: bool = True):
        super().__init__(parent_document)
        self._is_live_mode = is_live_mode
        self._theme = theme_config or {}
        self._build_formats()
        self._compile_patterns()
        self.rehighlight()

    def set_live_mode(self, is_live_mode: bool):
        if self._is_live_mode != is_live_mode:
            self._is_live_mode = is_live_mode
            self.rehighlight()

    def update_theme(self, theme_config: dict):
        self._theme = theme_config or {}
        self._build_formats()
        if self._is_live_mode:
            self.rehighlight()

    def _build_formats(self):
        text_primary = self._theme.get("text_primary", "#d4d4d4")
        text_secondary = self._theme.get("text_secondary", "#737373")
        delimiter_color = "#4c4c4c"
        brace_color = "#404040"

        # 0. Стандартный цвет текста для Source Mode
        self.fmt_default = QTextCharFormat()
        self.fmt_default.setForeground(QColor(text_primary))

        # 1. Затемнённые спецсимволы разметки
        self.fmt_delimiter = QTextCharFormat()
        self.fmt_delimiter.setForeground(QColor(delimiter_color))

        # 2. Полупрозрачные скобки блоков {}
        self.fmt_brace = QTextCharFormat()
        self.fmt_brace.setForeground(QColor(brace_color))

        # 3. Прозрачный формат для скрытия текста '---' (заменяется нативной линией оверлея)
        self.fmt_transparent = QTextCharFormat()
        self.fmt_transparent.setForeground(QColor(0, 0, 0, 0))

        # 4. Вики-ссылки [[Цель]] (строго без алиасов)
        self.fmt_wikilink = QTextCharFormat()
        self.fmt_wikilink.setForeground(QColor(text_primary))
        self.fmt_wikilink.setUnderlineStyle(QTextCharFormat.UnderlineStyle.SingleUnderline)
        self.fmt_wikilink.setUnderlineColor(QColor(text_secondary))

        # 5. Теги #тег (сам текст остаётся нормальным основным цветом с деликатным подчёркиванием)
        self.fmt_tag = QTextCharFormat()
        self.fmt_tag.setForeground(QColor(text_primary))
        self.fmt_tag.setUnderlineStyle(QTextCharFormat.UnderlineStyle.SingleUnderline)
        self.fmt_tag.setUnderlineColor(QColor(delimiter_color))

        # 6. Полужирный текст **текст**
        self.fmt_bold = QTextCharFormat()
        self.fmt_bold.setFontWeight(QFont.Weight.Bold)
        self.fmt_bold.setForeground(QColor(text_primary))

        # 7. Курсив *текст*
        self.fmt_italic = QTextCharFormat()
        self.fmt_italic.setFontItalic(True)
        self.fmt_italic.setForeground(QColor(text_primary))

        # 8. Зачёркнутый текст ~~текст~~
        self.fmt_strike = QTextCharFormat()
        self.fmt_strike.setFontStrikeOut(True)
        self.fmt_strike.setForeground(QColor(text_secondary))

        # 9. Маркеры списков (- и +)
        self.fmt_list_marker = QTextCharFormat()
        self.fmt_list_marker.setForeground(QColor(delimiter_color))

    def _compile_patterns(self):
        # Разделительная линия ---
        self.re_hr = re.compile(r"^[ \t]*---[ \t]*$")
        # Цитата (> текст)
        self.re_quote = re.compile(r"^[ \t]*(>)[ \t]*")
        # Списки и задачи (- [ ] / - [x] / - пункт)
        self.re_task = re.compile(r"^[ \t]*([-+])[ \t]+(\[[ xX]\])")
        self.re_list = re.compile(r"^[ \t]*([-+])[ \t]+")
        # Вики-ссылки [[Цель]] (строго без алиасов)
        self.re_wikilink = re.compile(r"\[\[([^\]\n]+)\]\]")
        # Теги #тег
        self.re_tag = re.compile(r"(?<!\S)#([a-zA-Zа-яА-ЯёЁ0-9_\-]+)(?!\S)")
        # Скобки блоков {}
        self.re_brace = re.compile(r"[{}]")
        # Жирный **текст**
        self.re_bold = re.compile(r"\*\*([^\*\n]+?)\*\*")
        # Курсив *текст* (строго одиночные звёздочки, исключая **)
        self.re_italic = re.compile(r"(?<!\*)\*([^\*\n]+?)\*(?!\*)")
        # Зачёркнутый ~~текст~~
        self.re_strike = re.compile(r"~~([^~\n]+?)~~")

    def _safe_set_format(self, start: int, length: int, fmt: QTextCharFormat):
        if length > 0 and start >= 0:
            self.setFormat(start, length, fmt)

    def highlightBlock(self, text: str):
        if not text:
            return

        if not self._is_live_mode:
            # В Source Mode текст строго монолитный и сухой (все символы и --- гарантированно видны)
            self._safe_set_format(0, len(text), self.fmt_default)
            return

        # 1. Горизонтальная линия '---' (текст '---' затемняется как маркер разметки fmt_delimiter,
        # а справа от него продолжается нативная линия оверлея HorizontalRuleOverlay)
        hr_match = self.re_hr.match(text)
        if hr_match:
            dash_start = text.find("---")
            if dash_start != -1:
                self._safe_set_format(dash_start, 3, self.fmt_delimiter)
            return

        # 2. Цитата (> текст) — затемняется ТОЛЬКО маркер '>', текст внутри остаётся обычным
        quote_match = self.re_quote.match(text)
        if quote_match:
            self._safe_set_format(quote_match.start(1), 1, self.fmt_delimiter)

        # 3. Списки и задачи (- [ ] / - [x] / - пункт)
        task_match = self.re_task.match(text)
        if task_match:
            self._safe_set_format(task_match.start(1), 1, self.fmt_list_marker)
            self._safe_set_format(task_match.start(2), task_match.end(2) - task_match.start(2), self.fmt_delimiter)
        else:
            list_match = self.re_list.match(text)
            if list_match:
                self._safe_set_format(list_match.start(1), 1, self.fmt_list_marker)

        # 4. Вики-ссылки [[Цель]] (без алиасов)
        for m in self.re_wikilink.finditer(text):
            self._safe_set_format(m.start(), 2, self.fmt_delimiter)
            self._safe_set_format(m.start(1), m.end(1) - m.start(1), self.fmt_wikilink)
            self._safe_set_format(m.end() - 2, 2, self.fmt_delimiter)

        # 5. Теги #тег (только '#' затемнён, текст тега остаётся нормальным основным цветом)
        for m in self.re_tag.finditer(text):
            self._safe_set_format(m.start(), 1, self.fmt_delimiter)
            self._safe_set_format(m.start(1), m.end(1) - m.start(1), self.fmt_tag)

        # 6. Полупрозрачные скобки блоков {}
        for m in self.re_brace.finditer(text):
            self._safe_set_format(m.start(), 1, self.fmt_brace)

        # 7. Жирный текст **текст**
        for m in self.re_bold.finditer(text):
            self._safe_set_format(m.start(), 2, self.fmt_delimiter)
            self._safe_set_format(m.start(1), m.end(1) - m.start(1), self.fmt_bold)
            self._safe_set_format(m.end() - 2, 2, self.fmt_delimiter)

        # 8. Курсив *текст*
        for m in self.re_italic.finditer(text):
            self._safe_set_format(m.start(), 1, self.fmt_delimiter)
            self._safe_set_format(m.start(1), m.end(1) - m.start(1), self.fmt_italic)
            self._safe_set_format(m.end() - 1, 1, self.fmt_delimiter)

        # 9. Зачёркнутый текст ~~текст~~
        for m in self.re_strike.finditer(text):
            self._safe_set_format(m.start(), 2, self.fmt_delimiter)
            self._safe_set_format(m.start(1), m.end(1) - m.start(1), self.fmt_strike)
            self._safe_set_format(m.end() - 2, 2, self.fmt_delimiter)
