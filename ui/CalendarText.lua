-- ui/CalendarText.lua
-- 달력·계절 문구 (data/locales/<언어>/ui.lua 의 calendar.*) — HUD 배지 · 새벽 정산 · 툴팁 · 의뢰 기한 · 길드 일정이 같이 쓴다.
--   date(day) → "2개월 3일" · count(workshop) → "(13/60)" · full(workshop, day) → "2개월 3일 (13/60일)"
--   season_name(id) · season_effect(rules, day) → "과열 위험 +2%p/초" | nil · season_line(rules, day) → "여름: …" | nil
-- 그릴 때마다 현재 언어로 조회한다. 규칙 계산은 systems/Calendar.

local I18n = require("systems.I18n")
local Calendar = require("systems.Calendar")
local DURABILITY = require("data.durability")

local CalendarText = {}

-- 0.032 → "3.2", 0.06 → "6" (퍼센트 숫자)
function CalendarText.percent(ratio)
    local value = ratio * 100
    local rounded = math.floor(value + 0.5)
    if math.abs(value - rounded) < 0.05 then
        return tostring(rounded)
    end
    return string.format("%.1f", value)
end

-- 1.15 → "1.15", 1.2 → "1.2", 0.7 → "0.7"
local function number(value)
    local text = string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
    return text
end

function CalendarText.date(day)
    local month, date = Calendar.date(day)
    return I18n.t("calendar.date", { month = month, day = date })
end

function CalendarText.count(workshop)
    return I18n.t("calendar.count", { day = workshop.day, max = workshop.max_days })
end

function CalendarText.full(workshop, day)
    day = day or workshop.day
    local month, date = Calendar.date(day)
    return I18n.t("calendar.full", { month = month, day = date, now = day, max = workshop.max_days })
end

function CalendarText.season_name(season)
    return I18n.t("calendar.season." .. season)
end

function CalendarText.season_effect(rules, day)
    local mods = Calendar.modifiers(rules, day)
    if mods.season == nil then
        return nil
    end
    return I18n.t("calendar.effect." .. mods.season, {
        overheat = CalendarText.percent(mods.overheat_add), honest = number(mods.honest_mult),
        wear = number(mods.overheat_add * DURABILITY.overclock.per_risk),
        hp = number(mods.monster_hp_mult), defense = CalendarText.percent(mods.monster_defense), tribute = number(mods.tribute_mult),
    })
end

function CalendarText.season_line(rules, day)
    local season = Calendar.season(rules, day)
    if season == nil then
        return nil
    end
    return I18n.t("calendar.season_line", { season = CalendarText.season_name(season), effect = CalendarText.season_effect(rules, day) })
end

return CalendarText
