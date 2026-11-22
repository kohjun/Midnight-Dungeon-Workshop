-- systems/Forge.lua
-- 연금술 용광로 +1 ~ +10 강화 도박 (data/forge.lua). 비용 = 골드 + 연마석(+2 부터) — 시작할 때 낸다 (실패해도 돌려주지 않음).
-- 성공률 = 단계 기본값 + 난이도 + 영구 스탯(연금술 숙련) + 공방 개조(용광로 안정화), max_chance 상한 (100% 단계는 그대로).
--   성공 : 강화 +1 · 내구도 100% 복구 (+10 에 닿으면 불멸 각인 — 마모 면역, entities/Item)
--   실패 : 단계표의 fail — keep(단계 유지) · down(-1 하락) · risk(destroy 확률로 파괴 + 고철 회수, 나머지는 -1 하락).
--          파괴되지 않으면 내구도는 그대로다.
-- 이벤트: forge:started / succeeded / failed(outcome = "keep"|"down"|"destroyed") / resolved. 판정은 "forge" 난수 스트림.
-- overclock 필드 = 연마석을 쓰는 +2 이상 위험 강화 (ui/ForgeDrama 의 가열·결과 연출, 효과음 구분).

local Class = require("lib.classic")
local EventBus = require("core.EventBus")
local RNG = require("core.RNG")
local I18n = require("systems.I18n")
local FORGE = require("data.forge")
local LAYOUT = require("data.layout")

local Forge = Class:extend()

local OUTCOMES = { success = true, keep = true, down = true, destroyed = true }

local function message(key)
    EventBus.emit("ui:message", { text = I18n.t(key), kind = "warn" })
end

local function furnace_center()
    local slot = LAYOUT.day.furnace_slot
    return slot.x + slot.w / 2, slot.y + slot.h / 2
end

function Forge:new(workshop)
    self._workshop = workshop
    self.forging = nil   -- { item, timer, duration, chance, overclock, from, force }
end

function Forge:furnace_item()
    return self._workshop.inventory:get("furnace", 1)
end

-- 용광로 작업 중인 유물은 옮길 수 없다
function Forge:is_locked(item)
    return self.forging ~= nil and self.forging.item == item
end

-- 다음 단계 비용: 골드, 연마석 (+10 이면 nil)
function Forge:cost(item)
    local spec = item:next_forge()
    if spec == nil then
        return nil
    end
    return spec.gold, spec.stones
end

-- 연마석을 쓰는 +2 이상 = 위험 강화 (가열 연출)
function Forge:is_risky(item)
    local _, stones = self:cost(item)
    return (stones or 0) > 0
end
Forge.is_overclock = Forge.is_risky

-- 비용을 낼 수 없으면 사유 키, 변수 (낼 수 있으면 nil)
function Forge:cost_block(item)
    local gold, stones = self:cost(item)
    local workshop = self._workshop
    if gold == nil then
        return "disabled.forge_max"
    elseif workshop.gold < gold then
        return "disabled.forge_no_gold", { cost = gold }
    elseif workshop.tempering_stones < stones then
        return "disabled.forge_no_stones", { need = stones, have = workshop.tempering_stones }
    end
    return nil
end

function Forge:can_forge()
    local item = self:furnace_item()
    return self.forging == nil and item ~= nil and item.owned and item:can_forge() and self._workshop:allows("forge")
        and self:cost_block(item) == nil
end

function Forge:bonus()
    local workshop = self._workshop
    return (workshop.rules.forge_bonus or 0) + workshop:meta_value("forge_bonus")
        + workshop.upgrades:value("furnace", "forge_bonus", 0)
end

local function boosted(base, bonus)
    if base >= 1 then
        return 1
    end
    return math.min(FORGE.max_chance, base + bonus)
end

-- 보정이 모두 반영된 성공 확률
function Forge:chance(item)
    return boosted(item:forge_chance(), self:bonus())
end

-- 단계별 성공 확률 목록 +1 ~ +10 (UI 안내용)
function Forge:chances()
    local list, bonus = {}, self:bonus()
    for i, spec in ipairs(FORGE.levels) do
        list[i] = boosted(spec.chance, bonus)
    end
    return list
end

-- 다음 시도의 결과 확률 { success, keep, down, destroy } (합 = 1, +10 이면 nil)
function Forge:odds(item)
    local spec = item:next_forge()
    if spec == nil then
        return nil
    end
    local success = self:chance(item)
    local fail = 1 - success
    local odds = { success = success, keep = 0, down = 0, destroy = 0 }
    if spec.fail == "keep" then
        odds.keep = fail
    elseif spec.fail == "risk" then
        odds.destroy = fail * spec.destroy
        odds.down = fail - odds.destroy
    else
        odds.down = fail
    end
    return odds
end

-- force: 결과 고정 "success" | "keep" | "down" | "destroyed" (개발 도구 — 스모크 테스트)
function Forge:start(force)
    assert(force == nil or OUTCOMES[force], "Forge: unknown forced outcome '" .. tostring(force) .. "'")
    if not self:can_forge() then
        local item = self:furnace_item()
        if item ~= nil and not item:can_forge() then
            message("msg.forge_max")
        elseif not self._workshop:allows("forge") then
            message("msg.tutorial_finish_cleaning")
        elseif item ~= nil and item.owned and self.forging == nil and self:cost_block(item) ~= nil then
            local key, vars = self:cost_block(item)
            EventBus.emit("ui:message", { text = I18n.t(key, vars), kind = "warn" })
        elseif self.forging == nil then
            message("msg.furnace_empty")
        end
        return false
    end
    local item = self:furnace_item()
    local chance = self:chance(item)
    local gold, stones = self:cost(item)
    if gold > 0 then
        self._workshop:spend_gold(gold, "forge")
    end
    if stones > 0 then
        self._workshop:spend_stones(stones, "forge")
    end
    local risky = stones > 0
    local duration = risky and FORGE.risky_anticipation or FORGE.anticipation
    self.forging = { item = item, timer = duration, duration = duration, chance = chance, overclock = risky, from = item.level,
        force = force }
    local x, y = furnace_center()
    EventBus.emit("forge:started", { item = item, chance = chance, x = x, y = y, overclock = risky, duration = duration,
        level = item.level + 1 })
    return true
end

-- 0~1: 긴장 연출 진행도 (작업 중이 아니면 nil)
function Forge:progress()
    if self.forging == nil then
        return nil
    end
    return 1 - self.forging.timer / self.forging.duration
end

function Forge:update(dt)
    if self.forging ~= nil then
        self.forging.timer = self.forging.timer - dt
        if self.forging.timer <= 0 then
            self:_resolve()
        end
    end
end

function Forge:_outcome(forging)
    if forging.force ~= nil then
        return forging.force
    end
    local rng = RNG.stream("forge")
    if rng:random() < forging.chance then
        return "success"
    end
    local spec = FORGE.levels[forging.from + 1]
    if spec.fail == "keep" then
        return "keep"
    elseif spec.fail == "risk" and rng:random() < spec.destroy then
        return "destroyed"
    end
    return "down"
end

function Forge:_resolve()
    local forging = self.forging
    self.forging = nil
    local workshop = self._workshop
    local item = forging.item
    if workshop.inventory:locate(item) ~= "furnace" then
        return
    end
    local outcome = self:_outcome(forging)
    local x, y = furnace_center()
    if outcome == "success" then
        item.level = item.level + 1
        item:restore_durability()
        EventBus.emit("forge:succeeded", { item = item, level = item.level, from = forging.from, x = x, y = y,
            overclock = forging.overclock, immortal = item:is_immortal() })
    elseif outcome == "destroyed" then
        local scrap_mult = workshop.upgrades:value("furnace", "scrap_mult", 1)
        local scrap = math.max(FORGE.scrap_min, math.floor(item:sale_value() * FORGE.scrap_ratio * scrap_mult))
        workshop.inventory:remove(item)
        workshop:add_gold(scrap, "scrap")
        workshop.stats.items_lost = workshop.stats.items_lost + 1
        EventBus.emit("forge:failed", { item = item, outcome = outcome, level = forging.from, from = forging.from, scrap = scrap,
            x = x, y = y, overclock = forging.overclock })
    else
        if outcome == "down" then
            item.level = math.max(0, item.level - 1)
        end
        EventBus.emit("forge:failed", { item = item, outcome = outcome, level = item.level, from = forging.from, x = x, y = y,
            overclock = forging.overclock })
    end
    EventBus.emit("forge:resolved", { item = item, success = outcome == "success", outcome = outcome, x = x, y = y,
        overclock = forging.overclock })
end

return Forge
