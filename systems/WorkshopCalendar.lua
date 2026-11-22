-- systems/WorkshopCalendar.lua
-- Workshop 믹스인: 달력·계절 기준으로 오늘 적용할 규칙을 묻는다 (systems/Calendar · data/calendar.lua · data/difficulties.lua).
--   date() → 달, 그 달의 날 · season() → 계절 id | nil · season_mods() → 계절 효과(중립 값 포함 — '스승의 흔적'은 포탈 간섭 효과,
--   mods.interference = 단계) · interference() → 오늘 포탈 간섭 단계 | nil
--   overheat_chance()   : 과열 위험 계수 = 난이도 overheat_chance + 여름 가산 (난이도가 0 이면 언제나 0)
--   overclock_wear_mult(): 과부하 중 내구도 마모 배율 = 1 + 과열 위험 계수 × per_risk (data/durability.lua, 견습 = 1)
--   customer_rules()    : 손님 규칙 (가을: 정직 확률 ↓ · 부풀림 ↑ — 위조 증가)
--   supply_mult()       : UV 배터리·정화수 소모 배율 (난이도)
--   wave_day(day)       : 밤 웨이브 실효 일차 = 1 + (일차 - 1) × 난이도 pace (긴 계약일수록 완만하게 강해진다)
--   night_modifiers(m)  : 밤 몬스터 수정자 = 암시장(핏빛 달) m + 계절(겨울 체력·방어력)
-- 그리기 금지.

local Calendar = require("systems.Calendar")
local BALANCE = require("data.balance")
local DURABILITY = require("data.durability")

local WorkshopCalendar = {}

local METHODS = {}

function METHODS:date()
    return Calendar.date(self.day)
end

function METHODS:season()
    return Calendar.season(self.rules, self.day)
end

function METHODS:interference()
    return Calendar.interference(self.rules, self.day)
end

function METHODS:season_mods(day)
    return Calendar.modifiers(self.rules, day or self.day)
end

function METHODS:overheat_chance()
    local base = self.overclock_rules.overheat_chance or 0
    if base <= 0 then
        return 0
    end
    return base + self:season_mods().overheat_add
end

function METHODS:overclock_wear_mult()
    local rules = DURABILITY.overclock
    return math.min(rules.max_mult, 1 + self:overheat_chance() * rules.per_risk)
end

function METHODS:customer_rules()
    local base = self.rules.customer or {}
    local mods = self:season_mods()
    if mods.honest_mult == 1 and mods.overclaim_add == 0 then
        return base
    end
    local rules = {}
    for key, value in pairs(base) do
        rules[key] = value
    end
    rules.honest_chance = (base.honest_chance or BALANCE.customer.honest_chance) * mods.honest_mult
    rules.overclaim_chance = math.min(1, (base.overclaim_chance or BALANCE.customer.overclaim_chance) + mods.overclaim_add)
    return rules
end

function METHODS:supply_mult()
    return self.rules.supply_mult or 1
end

function METHODS:wave_day(day)
    return 1 + ((day or self.day) - 1) * (self.rules.pace or 1)
end

function METHODS:night_modifiers(market)
    local mods = self:season_mods()
    local result = {}
    for key, value in pairs(market or {}) do
        result[key] = value
    end
    result.hp_mult = (result.hp_mult or 1) * mods.monster_hp_mult
    if mods.monster_defense > 0 then
        result.defense = mods.monster_defense
    end
    result.interference = mods.interference      -- '스승의 흔적' 포탈 간섭 단계 (몬스터 툴팁이 방어력 출처를 밝힌다)
    return result
end

function WorkshopCalendar.install(class)
    for name, method in pairs(METHODS) do
        class[name] = method
    end
end

return WorkshopCalendar
