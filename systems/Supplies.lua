-- systems/Supplies.lua
-- 작업대 소모 자원: UV 배터리("uv")와 정화수("water"), 각 0~100%.
-- 변경 시 "supplies:changed", low_warning(25%) 아래로 떨어지는 순간 "supplies:low", 0%가 되는 순간 "supplies:depleted".
-- 소모량 자체는 Appraisal(렌즈 초당 소모 · 오염 1%p 당 정화수)이 정한다 (data/balance.lua × 난이도 supply_mult).

local Class = require("lib.classic")
local EventBus = require("core.EventBus")
local BALANCE = require("data.balance")

local Supplies = Class:extend()

local KINDS = { uv = true, water = true }

function Supplies:new(workshop)
    self._workshop = workshop
    local settings = BALANCE.supplies
    self.max = settings.max
    self.uv = settings.start
    self.water = settings.start
end

local function check(kind)
    assert(KINDS[kind], "Supplies: unknown kind '" .. tostring(kind) .. "'")
end

function Supplies:get(kind)
    check(kind)
    return self[kind]
end

function Supplies:is_full(kind)
    return self:get(kind) >= self.max
end

-- 보충 (최대치까지). 실제 보충량 반환
function Supplies:add(kind, amount, reason)
    check(kind)
    local before = self[kind]
    self[kind] = math.min(self.max, before + amount)
    local added = self[kind] - before
    if added > 0 then
        EventBus.emit("supplies:changed", { kind = kind, amount = added, value = self[kind], reason = reason })
    end
    return added
end

-- 소모 (있는 만큼만). 실제 소모량 반환
function Supplies:spend(kind, amount)
    check(kind)
    local before = self[kind]
    if before <= 0 or amount <= 0 then
        return 0
    end
    self[kind] = math.max(0, before - amount)
    local low = BALANCE.supplies.low_warning
    if self[kind] <= 0 then
        EventBus.emit("supplies:depleted", { kind = kind })
    elseif before >= low and self[kind] < low then
        EventBus.emit("supplies:low", { kind = kind, value = self[kind] })
    end
    return before - self[kind]
end

function Supplies:morning_refill()
    local amount = BALANCE.supplies.morning_refill
    self:add("uv", amount, "morning")
    self:add("water", amount, "morning")
end

return Supplies
