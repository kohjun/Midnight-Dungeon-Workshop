-- systems/Calendar.lua
-- 장기 압축 달력 (data/calendar.lua): 일차 → "M개월 D일", 계절(seasons = true 난이도만), 계절 효과 수정자.
-- '스승의 흔적' 캠페인(interference = true)은 계절 대신 달마다 포탈 균열 간섭 단계(1~6, data/master_trace.lua)가 오르고,
-- 그 효과가 계절 효과 자리에 들어간다 (mods.interference = 단계).
-- 순수 함수 모음 — 상태 없음. Workshop 은 systems/WorkshopCalendar 믹스인으로 오늘 기준 값을 묻는다.

local CALENDAR = require("data.calendar")
local TRACE = require("data.master_trace")

local Calendar = {}

local NEUTRAL = { overheat_add = 0, honest_mult = 1, overclaim_add = 0, monster_hp_mult = 1, monster_defense = 0, tribute_mult = 1 }

-- 일차 → 달(1~), 그 달의 날(1~month_days)
function Calendar.date(day)
    local length = CALENDAR.month_days
    return math.floor((day - 1) / length) + 1, (day - 1) % length + 1
end

function Calendar.month(day)
    return (Calendar.date(day))
end

function Calendar.is_month_end(day)
    return day % CALENDAR.month_days == 0
end

-- 그 일차의 계절 id (계절이 없는 난이도면 nil)
function Calendar.season(rules, day)
    if rules == nil or not rules.seasons then
        return nil
    end
    local order = CALENDAR.season_order
    return order[math.floor((day - 1) / CALENDAR.season_days) % #order + 1]
end

-- 오늘 새 계절이 시작되었으면 그 계절 id (1일차·계절 없는 난이도는 nil)
function Calendar.season_started(rules, day)
    if day <= 1 then
        return nil
    end
    local season = Calendar.season(rules, day)
    if season ~= nil and season ~= Calendar.season(rules, day - 1) then
        return season
    end
    return nil
end

-- 그 일차의 포탈 균열 간섭 단계 (interference 난이도만 — 달 = 단계, 상한 months). 없으면 nil
function Calendar.interference(rules, day)
    if rules == nil or not rules.interference then
        return nil
    end
    return math.min(TRACE.interference.months, Calendar.month(day))
end

-- 오늘 간섭 단계가 올랐으면 그 단계 (1일차·간섭 없는 난이도는 nil)
function Calendar.interference_started(rules, day)
    local level = day > 1 and Calendar.interference(rules, day) or nil
    if level ~= nil and level ~= Calendar.interference(rules, day - 1) then
        return level
    end
    return nil
end

-- 그 일차의 계절(또는 간섭) 효과 (난이도 season_scale 로 증폭). 둘 다 없으면 중립 값. 반환 표는 매번 새로 만든다
function Calendar.modifiers(rules, day)
    local mods = {}
    for key, value in pairs(NEUTRAL) do
        mods[key] = value
    end
    local level = Calendar.interference(rules, day)
    if level ~= nil then                -- 단계 - 1 만큼 쌓인다 (1단계 = 기준)
        local per, n = TRACE.interference.per_level, level - 1
        mods.interference = level
        mods.overheat_add = per.overheat_add * n
        mods.honest_mult = math.max(0, 1 - per.honest_drop * n)
        mods.monster_hp_mult = 1 + per.monster_hp * n
        mods.monster_defense = math.min(0.9, per.monster_defense * n)
        return mods
    end
    local season = Calendar.season(rules, day)
    if season == nil then
        return mods
    end
    local spec, scale = CALENDAR.seasons[season], rules.season_scale or 1
    mods.season = season
    mods.overheat_add = (spec.overheat_add or 0) * scale
    mods.honest_mult = math.max(0, 1 - (1 - (spec.honest_mult or 1)) * scale)
    mods.overclaim_add = (spec.overclaim_add or 0) * scale
    mods.monster_hp_mult = 1 + ((spec.monster_hp_mult or 1) - 1) * scale
    mods.monster_defense = math.min(0.9, (spec.monster_defense or 0) * scale)
    mods.tribute_mult = 1 + ((spec.tribute_mult or 1) - 1) * scale
    return mods
end

function Calendar.season_color(season)
    local spec = CALENDAR.seasons[season]
    return spec and spec.color or { 1, 1, 1 }
end

return Calendar
