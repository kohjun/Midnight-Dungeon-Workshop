-- systems/Drops.lua
-- 전투 자원 드랍: 일반 몬스터 처치 시 확률적으로 UV 배터리 또는 정화수, 보스는 둘 다 확정.
-- 연마석: 일반 몬스터 낮은 확률 · 엘리트(elite = true) 높은 확률 · 보스 확정 (data/balance.lua 의 stones).
--   무작위 드랍은 한 밤에 stones.night_cap 개까지 (보스·중간 보스 확정분은 따로).
-- 중간 보스: 연마석 · 보너스 골드 확정 (data/waves.lua 의 midboss.reward, 골드는 달마다 증가) → "combat:midboss_slain".
-- "combat:monster_killed" 구독으로 동작한다 (Combat 은 드랍을 모른다).

local Class = require("lib.classic")
local EventBus = require("core.EventBus")
local RNG = require("core.RNG")
local Calendar = require("systems.Calendar")
local BALANCE = require("data.balance")
local WAVES = require("data.waves")

local Drops = Class:extend()

local DROP_KINDS = { "uv", "water" }

function Drops:new(workshop)
    self._workshop = workshop
    self._night_stones = 0                -- 이번 밤 무작위 연마석 드랍 수 (상한)
    EventBus.subscribe("phase:night_started", function()
        self._night_stones = 0
    end, { owner = self })
    EventBus.subscribe("combat:monster_killed", function(payload)
        self:_on_kill(payload)
    end, { owner = self, priority = -40 })
end

function Drops:destroy()
    EventBus.unsubscribe_owner(self)
end

-- 연마석: 보스 확정 · 엘리트 높은 확률 · 일반 낮은 확률
function Drops:_drop_stones(rng, payload)
    local spec, stones = payload.monster.spec, BALANCE.stones
    local amount = 0
    if spec.boss then
        amount = stones.boss_drop
    elseif self._night_stones < stones.night_cap and rng:chance(spec.elite and stones.elite_chance or stones.drop_chance) then
        amount = 1
        self._night_stones = self._night_stones + 1
    end
    if amount > 0 then
        self._workshop:add_stones(amount, "drop")
        EventBus.emit("supplies:dropped", { kind = "stone", amount = amount, x = payload.x, y = payload.y, boss = spec.boss })
    end
end

-- 중간 보스 확정 보상: 연마석 + 보너스 골드
function Drops:_midboss_reward(payload)
    local reward, workshop = WAVES.midboss.reward, self._workshop
    local gold = reward.gold + reward.gold_per_month * (Calendar.month(workshop.day) - 1)
    workshop:add_stones(reward.stones, "drop")
    workshop:add_gold(gold, "midboss")
    EventBus.emit("combat:midboss_slain", { monster = payload.monster, gold = gold, stones = reward.stones, x = payload.x, y = payload.y })
end

function Drops:_on_kill(payload)
    local settings = BALANCE.supplies
    local supplies = self._workshop.supplies
    local rng = RNG.stream("drops")
    if payload.monster.spec.midboss then
        self:_midboss_reward(payload)
    end
    self:_drop_stones(rng, payload)
    if payload.monster.spec.boss then
        supplies:add("uv", settings.boss_drop, "boss")
        supplies:add("water", settings.boss_drop, "boss")
        EventBus.emit("supplies:dropped", { kind = "both", amount = settings.boss_drop, x = payload.x, y = payload.y, boss = true })
        return
    end
    if rng:chance(settings.drop_chance) then
        local kind = rng:pick(DROP_KINDS)
        supplies:add(kind, settings.drop_amount, "drop")
        EventBus.emit("supplies:dropped", { kind = kind, amount = settings.drop_amount, x = payload.x, y = payload.y })
    end
end

return Drops
