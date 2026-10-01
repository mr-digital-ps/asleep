// js/history/timeline_controller.js — Логика расчета и группировки срезов истории проекта
.pragma library

function parseSnapshotDate(item) {
    if (!item) return null
    var str = item.createdAt || ""
    if (!str && item.timestamp) {
        return new Date(item.timestamp * 1000)
    }
    if (!str) return null

    // Format usually ISO or "YYYY-MM-DD HH:MM:SS" or "DD.MM.YYYY, HH:MM"
    if (str.indexOf(" ") !== -1) {
        var parts = str.split(" ")
        var datePart = parts[0]
        var timePart = parts[1] || "00:00:00"
        if (datePart.indexOf("-") !== -1) {
            var dp = datePart.split("-")
            var tp = timePart.split(":")
            return new Date(parseInt(dp[0], 10), parseInt(dp[1], 10) - 1, parseInt(dp[2], 10),
                            parseInt(tp[0] || 0, 10), parseInt(tp[1] || 0, 10), parseInt(tp[2] || 0, 10))
        } else if (datePart.indexOf(".") !== -1) {
            var dp = datePart.split(".")
            var tp = timePart.split(":")
            return new Date(parseInt(dp[2], 10), parseInt(dp[1], 10) - 1, parseInt(dp[0], 10),
                            parseInt(tp[0] || 0, 10), parseInt(tp[1] || 0, 10), parseInt(tp[2] || 0, 10))
        }
    }
    var d = new Date(str)
    return isNaN(d.getTime()) ? null : d
}

function pad2(n) {
    return (n < 10 ? "0" : "") + n
}

// Формат времени: HH:MM:SS am/pm (12-часовой с секундами и am/pm в нижнем регистре, например 12:07:22 pm)
function formatTime12(item) {
    var d = parseSnapshotDate(item)
    if (!d) return "--:--:-- --"
    var hours = d.getHours()
    var minutes = d.getMinutes()
    var seconds = d.getSeconds()
    var ampm = hours >= 12 ? "pm" : "am"
    var h12 = hours % 12
    if (h12 === 0) h12 = 12
    return pad2(h12) + ":" + pad2(minutes) + ":" + pad2(seconds) + " " + ampm
}

// Формат даты: DD/MM/YYYY (например 01/10/2026)
function formatDateDMY(item) {
    var d = parseSnapshotDate(item)
    if (!d) return "--/--/----"
    var day = d.getDate()
    var month = d.getMonth() + 1
    var year = d.getFullYear()
    return pad2(day) + "/" + pad2(month) + "/" + year
}

function formatSnapshotLabel(item) {
    if (!item) return ""
    if (item.isLive) return "Live (Сейчас)"
    if (item.isCreation) return "Создан"
    var str = item.createdAt || ""
    if (!str) return "Срез"
    return formatTime12(item)
}

function getDaysList(list) {
    if (!list || list.length === 0) return []
    var daysArr = []
    for (var i = 0; i < list.length; i++) {
        var item = list[i]
        var label = formatSnapshotLabel(item)
        daysArr.push({
            label: label,
            timeStr: formatTime12(item),
            dateStr: formatDateDMY(item),
            snapshotIndex: i,
            snapshotId: item.id,
            snapshot: item,
            isLive: !!item.isLive,
            isCreation: !!item.isCreation
        })
    }
    return daysArr
}

function getDayIndexForSnapshot(snapIdx, daysArr, timelineList) {
    if (!daysArr || daysArr.length === 0) return 0
    if (snapIdx < 0) return daysArr.length - 1
    return Math.max(0, Math.min(daysArr.length - 1, snapIdx))
}

function getStepTitleText(daysList, isHistoricalMode, currentDayIndex) {
    if (!daysList || daysList.length === 0) return "История пуста"
    if (!isHistoricalMode) {
        return "Live • Текущее состояние"
    }
    var dIdx = currentDayIndex
    var dayObj = (dIdx >= 0 && dIdx < daysList.length) ? daysList[dIdx] : null
    if (!dayObj) return ""
    var desc = (dayObj.snapshot && dayObj.snapshot.description) ? (" • " + dayObj.snapshot.description) : ""
    return dayObj.label + desc
}
