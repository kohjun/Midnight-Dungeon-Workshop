-- systems/Tribute.lua
-- 결계 유지비(상납금): 매달 말일(data/balance.lua 의 tribute.every 일마다) 밤이 끝난 새벽에 징수한다.
-- 금액 = tribute.amounts[달] × 난이도 tribute_mult × 그 날 계절의 tribute_mult(겨울, systems/Calendar) − 할인 + 가산.
-- 모자라면 징수하지 않고 false → DayCycle 이 즉시 파산 처리.
-- 할인: 핏빛 달(discount_next) · 길드 의뢰 보상(discount_ratio_next) / 가산: 의뢰 위약금 중 골드로 못 낸 몫(surcharge_next).

local Class = require("lib.classic")
local EventBus = require("core.EventBus")
local Calendar = require("systems.Calendar")
local BALANCE = require("data.balance")

local Tribute = Class:extend()

local T = BALANCE.tribute

function Tribute:new(workshop)
    self._workshop = workshop
    self._mult = workshop.rules.tribute_mult or 1
    self._discounts = {}   -- day -> 차감액 (음수면 가산)
end

local function base_amount(index)
    if index <= #T.amounts then
        return T.amounts[index]
    end
    return T.amounts[#T.amounts] + (index - #T.amounts) * T.after_step
end

function Tribute:is_due_day(day)
    return day >= T.every and day % T.every == 0 and day <= self._workshop.max_days
end

-- 계약 기간 안의 징수일 목록
function Tribute:schedule()
    local days = {}
    for day = T.every, self._workshop.max_days, T.every do
        days[#days + 1] = day
    end
    return days
end

-- 할인·가산 전 금액 (징수일이 아니면 nil)
function Tribute:base_for(day)
    if not self:is_due_day(day) then
        return nil
    end
    local season = Calendar.modifiers(self._workshop.rules, day).tribute_mult
    return math.floor(base_amount(math.floor(day / T.every)) * self._mult * season + 0.5)
end

-- 그 일차 새벽에 징수할 금액 (징수일이 아니거나 목표 일수 밖이면 nil)
function Tribute:amount_for(day)
    local base = self:base_for(day)
    if base == nil then
        return nil
    end
    return math.max(0, base - (self._discounts[day] or 0))
end

-- 오늘 포함 다음 징수일과 금액 (남은 징수가 없으면 nil)
function Tribute:next_due(day)
    local due = math.max(T.every, math.ceil(day / T.every) * T.every)
    if due > self._workshop.max_days then
        return nil
    end
    return due, self:amount_for(due)
end

-- 경고 배너 표시 여부: 상납일 D-1 ~ D-Day 낮
function Tribute:warning(day)
    local due, amount = self:next_due(day)
    if due == nil or due - day > T.warn_days_before then
        return nil
    end
    return { due = due, amount = amount, days_left = due - day, shortfall = math.max(0, amount - self._workshop.gold) }
end

-- 다음 상납 목표액 차감 (핏빛 달 보상). 차감한 징수일 반환
function Tribute:discount_next(day, amount)
    local due = self:next_due(day)
    if due ~= nil then
        self._discounts[due] = (self._discounts[due] or 0) + amount
    end
    return due
end

-- 다음 상납 목표액을 비율만큼 차감 (길드 의뢰 보상). 징수일과 차감액 반환 (남은 징수가 없으면 nil, 0)
function Tribute:discount_ratio_next(day, ratio)
    local due = self:next_due(day)
    if due == nil then
        return nil, 0
    end
    local amount = math.floor(self:base_for(due) * ratio + 0.5)
    self:discount_next(day, amount)
    return due, amount
end

-- 다음 상납 목표액 가산 (의뢰 위약금 미납분). 징수일 반환 (남은 징수가 없으면 nil — 가산하지 않는다)
function Tribute:surcharge_next(day, amount)
    local due = self:next_due(day)
    if due ~= nil and amount > 0 then
        self._discounts[due] = (self._discounts[due] or 0) - amount
    end
    return due
end

-- 징수 실행. 징수일이 아니면 nil, 완납 true, 미달 false (골드는 건드리지 않는다)
function Tribute:collect(day)
    local amount = self:amount_for(day)
    if amount == nil then
        return nil
    end
    local workshop = self._workshop
    if workshop.gold >= amount then
        workshop:spend_gold(amount, "tribute")
        workshop.stats.tributes_paid = workshop.stats.tributes_paid + 1
        EventBus.emit("economy:tribute_paid", { day = day, amount = amount })
        return true
    end
    EventBus.emit("economy:tribute_missed", { day = day, amount = amount, gold = workshop.gold, shortfall = amount - workshop.gold })
    return false
end

return Tribute
