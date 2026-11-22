-- systems/Wear.lua
-- 밤 전투 중 진열장 유물의 점진 마모 (data/durability.lua). Combat 이 소유한다: start 때 reset, 매 틱 update(dt, overclock),
-- 무기가 쏠 때마다 shot(item, index). 기존의 과열 판정(무작위 내구도 -1 · 파괴)은 이 백분율 마모로 대체되었다.
--   활성 시간 : 진열장의 작동 중인 유물(완전 마모·불멸 제외)이 초당 per_second % 씩
--   발사      : 무기 한 발마다 per_shot % 더
--   과부하 ON : 두 마모 모두 Workshop:overclock_wear_mult() 배 (견습 = 1 — 가속 없음). "combat:wear_check" 수정자
--              (냉각 핀·균열 프리즘)가 가속분(extra = 배율 - 1)을 줄인다 — 틱마다 한 번 발행
--   균열 결함 : x Item:wear_mult()
--   봉인 공명 슬롯('스승의 흔적' 캠페인): 그 칸에 놓인 유물은 x MasterTrace:wear_mult(index) (data/master_trace.lua 의 resonance)
-- 경계: warn_below 아래로 내려가는 순간 "combat:item_wear_warning", 0% 가 되는 순간 "combat:item_worn_out"
-- (Workshop 이 진열장 스탯을 다시 계산하고 ItemEffects 가 그 유물의 효과 구독을 끊는다 — 공격·증폭·시너지 정지).
-- 아이템을 지우지 않는다. 내구도 복구는 용광로 강화 성공뿐 (systems/Forge). 그리기 금지.

local Class = require("lib.classic")
local EventBus = require("core.EventBus")
local Grid = require("systems.Grid")
local DURABILITY = require("data.durability")

local Wear = Class:extend()

local WEAR = DURABILITY.wear

function Wear:new(workshop)
    self._workshop = workshop
    self._mult = 1
end

function Wear:reset()
    self._mult = 1
end

-- 지금 과부하 마모 배율 (꺼져 있으면 1)
function Wear:multiplier()
    return self._mult
end

local function overclock_mult(workshop)
    local base = workshop:overclock_wear_mult()
    if base <= 1 then
        return 1
    end
    local check = EventBus.emit("combat:wear_check", { extra = base - 1 })
    return 1 + math.max(0, check.extra)
end

function Wear:_wear(item, index, amount)
    local before, trace = item.durability, self._workshop.master_trace
    item.durability = math.max(0, before - amount * item:wear_mult() * (trace and trace:wear_mult(index) or 1))
    if item.durability >= before then
        return
    end
    local x, y = Grid.cell_center(index)
    local warn = DURABILITY.warn_below
    if item.durability <= 0 then
        EventBus.emit("combat:item_worn_out", { item = item, index = index, x = x, y = y })
    elseif before > warn and item.durability <= warn then
        EventBus.emit("combat:item_wear_warning", { item = item, index = index, x = x, y = y, durability = item.durability })
    end
end

local function wears(item)
    return item ~= nil and item.durability > 0 and not item:is_immortal()
end

function Wear:update(dt, overclock)
    local workshop = self._workshop
    self._mult = overclock and overclock_mult(workshop) or 1
    local amount = WEAR.per_second * dt * self._mult
    local inventory = workshop.inventory
    for index = 1, inventory:size("grid") do
        local item = inventory:get("grid", index)
        if wears(item) then
            self:_wear(item, index, amount)
        end
    end
end

-- 무기 한 발 (Combat._update_weapons)
function Wear:shot(item, index)
    if wears(item) then
        self:_wear(item, index, WEAR.per_shot * self._mult)
    end
end

return Wear
