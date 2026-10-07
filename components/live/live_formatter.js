// components/live/live_formatter.js — форматирование markdown (теги и вики-ссылки) в строгом стиле темы
.pragma library

/**
 * Преобразует markdown-текст в RichText с единым монохромным стилем:
 * - #тег -> неяркий вторичный текст темы без синего цвета
 * - [[цель]] -> подчеркнутый текст темы без синего цвета
 */
function formatMarkdownToRichText(rawText, Theme) {
    if (!rawText || rawText.length === 0) return ""

    let textSecondary = Theme ? Theme.textSecondary : "#737373"
    let textPrimary = Theme ? Theme.textPrimary : "#d4d4d4"

    // 1. Экранирование HTML-символов
    let escaped = rawText
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")

    // 2. Парсинг тегов #тег (только теги с буквами/цифрами/подчеркиванием)
    let withTags = escaped.replace(/(^|\s)(#[A-Za-zА-Яа-я0-9_\-\/]+)(?=$|\s|[.,;:!?])/g, function(match, prefix, tag) {
        return prefix + '<span style="color: ' + textSecondary + ';">' + tag + '</span>'
    })

    // 3. Парсинг вики-ссылок [[цель|алиас]] или [[цель]]
    let withLinks = withTags.replace(/\[\[([^\]|]+)(?:\|([^\]]+))?\]\]/g, function(match, target, alias) {
        let label = alias ? alias.trim() : target.trim()
        let cleanTarget = target.trim()
        return '<a href="file://' + cleanTarget + '" style="color: ' + textPrimary + '; text-decoration: underline;">' + label + '</a>'
    })

    return withLinks.replace(/\n/g, "<br/>")
}

function extractWikiLinkTarget(link) {
    if (!link) return ""
    return link.replace(/^file:\/\/\/?/, "").trim()
}
