// js/history/timeline_controller.js — Логика расчета и группировки срезов истории проекта
.pragma library

function getDaysList(list) {
    if (!list || list.length === 0) return []
    var daysMap = {}
    var daysArr = []
    for (var i = 0; i < list.length; i++) {
        var item = list[i]
        var dateStr = (item.createdAt || "").split(",")[0].trim()
        if (!daysMap[dateStr]) {
            var dParts = dateStr.split(".")
            var dayNum = dParts[0] || ""
            var monthNum = parseInt(dParts[1] || "1", 10)
            var months = ["янв", "фев", "мар", "апр", "май", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"]
            var monthName = months[monthNum - 1] || ""
            var dayObj = {
                dateStr: dateStr,
                dayNum: dayNum,
                monthName: monthName,
                label: dayNum + " " + monthName,
                snapshotIndex: i,
                snapshotId: item.id,
                snapshot: item
            }
            daysMap[dateStr] = dayObj
            daysArr.push(dayObj)
        } else {
            daysMap[dateStr].snapshotIndex = i
            daysMap[dateStr].snapshotId = item.id
            daysMap[dateStr].snapshot = item
        }
    }
    return daysArr
}

function getDayIndexForSnapshot(snapIdx, daysArr, timelineList) {
    if (!daysArr || daysArr.length === 0) return 0
    if (snapIdx < 0) return daysArr.length - 1
    var item = (timelineList && snapIdx < timelineList.length) ? timelineList[snapIdx] : null
    if (!item || !item.createdAt) return daysArr.length - 1
    var dateStr = item.createdAt.split(",")[0].trim()
    for (var d = 0; d < daysArr.length; d++) {
        if (daysArr[d].dateStr === dateStr) return d
    }
    return daysArr.length - 1
}

function getMonthYearContext(idx, list) {
    if (!list || list.length === 0) return ""
    var item = (idx >= 0 && idx < list.length) ? list[idx] : list[list.length - 1]
    if (!item || !item.createdAt) return ""
    var datePart = item.createdAt.split(",")[0].trim()
    var dParts = datePart.split(".")
    if (dParts.length >= 3) {
        var monthNum = parseInt(dParts[1], 10)
        var year = dParts[2]
        var fullMonths = ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"]
        return (fullMonths[monthNum - 1] || "") + " " + year
    }
    return ""
}

function getStepTitleText(daysList, isHistoricalMode, currentDayIndex) {
    if (!daysList || daysList.length === 0) return "История пуста"
    if (!isHistoricalMode) {
        return "Сейчас (актуальное состояние) • " + daysList.length + " дней в истории"
    }
    var dIdx = currentDayIndex
    var dayObj = (dIdx >= 0 && dIdx < daysList.length) ? daysList[dIdx] : null
    if (!dayObj) return ""
    var desc = (dayObj.snapshot && dayObj.snapshot.description) ? (" • " + dayObj.snapshot.description) : ""
    return "День " + (dIdx + 1) + " из " + daysList.length + " (" + dayObj.label + ")" + desc
}

function getStatsCountText(timelineList, currentSnapshotIndex) {
    if (!timelineList || timelineList.length === 0) return ""
    var idx = currentSnapshotIndex
    var item = (idx >= 0 && idx < timelineList.length) ? timelineList[idx] : null
    if (!item) return ""
    if (typeof item.fileSize !== "undefined") {
        return item.fileSize + " байт"
    }
    if (typeof item.nodesCount !== "undefined" && typeof item.linksCount !== "undefined") {
        return item.nodesCount + " узлов, " + item.linksCount + " связей"
    }
    return ""
}
