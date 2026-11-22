-- systems/HeroCombat.lua
-- 일반 밤 레인에서 공방 문 앞 주인공의 실전 전투 (Combat 이 소유 · 갱신, 수치 data/hero.lua · 스탯 systems/HeroStats).
--   근접 타격 : 방벽 앞 melee.range 안의 가장 앞선 마물을 strike_interval 초마다 직접 친다 — 피해 = 주인공 공격력
--               (맨손 기본 + 장착 무기 공격력 × attack_share) × 치명타(투구가 확률을 올린다). 장착 무기의 피해 속성으로
--               Combat:damage_monster 에 들어가므로 면역·방어력 규칙을 그대로 따른다. → "combat:hero_strike"
--   방어      : 방벽이 맞을 때 방어력만큼 막는다 (guard = 방어력 × per_defense, 상한) → "combat:hero_guard"
--   반격      : 막은 직후 counter.range 안의 가장 앞선 마물에게 공격력 × counter(신발의 이동속도가 올린다)
--   마모      : 장착 4부위는 밤 전투 중 초당 조금씩, 무기는 타격마다 · 방어구는 방어마다 더 닳는다 (+10 불멸 면역).
--               30% 이하 "hero:gear_wear_warning" · 0% "hero:gear_worn_out" — 0% 장비는 스탯에서 빠진다 (HeroStats).
-- 연출(포즈 · 망치 궤적 · 룬 방패)은 ui/LaneHero 가 이 이벤트를 받아 그린다.

local Class = require("lib.classic")
local EventBus = require("core.EventBus")
local RNG = require("core.RNG")
local HeroStats = require("systems.HeroStats")
local HERO = require("data.hero")
local DURABILITY = require("data.durability")
local LAYOUT = require("data.layout")

local HeroCombat = Class:extend()

local NIGHT = LAYOUT.night
local WALL_X = NIGHT.wall.x + NIGHT.wall.w
local WEAR = DURABILITY.wear

function HeroCombat:new(workshop, combat)
    self._workshop = workshop
    self._combat = combat
    self:reset()
end

-- 밤이 시작될 때
function HeroCombat:reset()
    self._cooldown = HERO.melee.interval * 0.5
    self.strikes, self.blocked = 0, 0             -- 이번 밤 타격 수 · 막아 낸 방벽 피해 (밸런스 보고 · 정산)
end

-- 방벽 앞 range(px, field_scale 적용 전) 안에서 방벽에 가장 가까운 살아 있는 마물 (없으면 nil)
function HeroCombat:front_monster(range)
    local limit = range * NIGHT.field_scale
    local best, best_gap = nil, limit
    for _, monster in ipairs(self._combat.monsters) do
        local gap = monster.x - monster.radius - WALL_X
        if not monster.dead and gap <= best_gap then
            best, best_gap = monster, gap
        end
    end
    return best
end

local function wears(item)
    return item ~= nil and item.durability > 0 and not item:is_immortal()
end

function HeroCombat:_wear(item, slot, amount)
    if not wears(item) or amount <= 0 then
        return
    end
    local before = item.durability
    item.durability = math.max(0, before - amount * item:wear_mult())
    if item.durability <= 0 then
        EventBus.emit("hero:gear_worn_out", { item = item, slot = slot })
    elseif before > DURABILITY.warn_below and item.durability <= DURABILITY.warn_below then
        EventBus.emit("hero:gear_wear_warning", { item = item, slot = slot, durability = item.durability })
    end
end

function HeroCombat:_strike(monster, stats, mult, counter)
    local weapon = self._workshop:hero_gear().weapon
    local crit = RNG.stream("combat"):chance(stats.crit)
    local damage = stats.attack * mult * (crit and stats.crit_mult or 1)
    self.strikes = self.strikes + 1
    EventBus.emit("combat:hero_strike", {
        monster = monster, damage = damage, crit = crit, counter = counter == true, item = weapon, x = monster.x, y = monster.y,
    })
    self._combat:damage_monster(monster, damage, weapon, false, stats.damage_type, false, crit)
    self:_wear(weapon, "weapon", WEAR.per_shot * HERO.wear.per_strike)
end

function HeroCombat:update(dt)
    local gear = self._workshop:hero_gear()
    for _, slot in ipairs(HERO.slots) do
        self:_wear(gear[slot], slot, WEAR.per_second * HERO.wear.per_second * dt)
    end
    self._cooldown = math.max(0, self._cooldown - dt)
    if self._cooldown > 0 then
        return
    end
    local monster = self:front_monster(HERO.melee.range)
    if monster ~= nil then
        local stats = HeroStats.compute(self._workshop)
        self:_strike(monster, stats, 1, false)
        self._cooldown = stats.strike_interval
    end
end

-- 방벽이 damage 만큼 맞는다: 주인공이 막고 남은 피해를 돌려준다 (그리고 반격)
function HeroCombat:guard(monster, damage)
    local stats = HeroStats.compute(self._workshop)
    local blocked = damage * stats.guard
    if blocked > 0 then
        self.blocked = self.blocked + blocked
        local gear = self._workshop:hero_gear()
        for _, slot in ipairs(HERO.slots) do
            if slot ~= "weapon" then
                self:_wear(gear[slot], slot, HERO.wear.per_block)
            end
        end
        EventBus.emit("combat:hero_guard", { monster = monster, blocked = blocked, damage = damage - blocked, x = WALL_X, y = monster.y })
    end
    local target = self:front_monster(HERO.counter.range)
    if target ~= nil and target ~= monster then
        self:_strike(target, stats, stats.counter, true)
    end
    return damage - blocked
end

return HeroCombat
