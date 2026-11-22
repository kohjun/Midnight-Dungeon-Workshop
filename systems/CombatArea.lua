-- systems/CombatArea.lua
-- Combat 의 범위 피해 메서드 (유물 효과용 공개 API): 연쇄 번개(chain_from) · 폭발(damage_area) · 낙뢰(strike_all)
-- · 화염 스플래시(splash_from).
-- CombatArea.install(Combat) 이 메서드를 Combat 클래스에 붙인다 (Combat.lua 300줄 제한 때문에 분리).
-- 피해 종류: 연쇄·낙뢰 = "lightning", 폭발 = "fire" (systems/DamageRules — 면역·감전 보정을 받는다).

local EventBus = require("core.EventBus")
local Projectiles = require("systems.Projectiles")
local COMBAT = require("data.combat")
local ITEMS = require("data.items")
local LAYOUT = require("data.layout")

local CombatArea = {}

local THUNDER_COLOR = { 0.8, 0.9, 1.0 }
local LANE = LAYOUT.night.lane
local FIELD_SCALE = LAYOUT.night.field_scale     -- 연쇄 거리·폭발 반경도 넓어진 레인만큼 키운다

-- 연쇄 번개: origin 에서 가까운 순으로 count 마리까지 (ItemEffects 의 chain 효과가 호출)
local function chain_from(self, origin, count, range, damage, item)
    local visited = { [origin] = true }
    local current = origin
    local color = ITEMS.elements[item.element].color
    for _ = 1, count do
        local next_target = self:nearest_monster(current.x, current.y, visited, range * FIELD_SCALE)
        if next_target == nil then
            break
        end
        visited[next_target] = true
        Projectiles.add_beam(self, current.x, current.y, next_target.x, next_target.y, color, nil, item)
        local hit = EventBus.emit("combat:hit", {
            item = item, monster = next_target, damage = damage, combat = self, chained = true,
        })
        self:damage_monster(next_target, hit.damage, item, false, "lightning")
        current = next_target
    end
end

-- 폭발: (x, y) 반경 안의 모든 적에게 화염 피해
local function damage_area(self, x, y, radius, damage, item)
    radius = radius * FIELD_SCALE
    EventBus.emit("combat:explosion", { x = x, y = y, radius = radius, item = item })
    for _, monster in ipairs(self.monsters) do
        local dx, dy = monster.x - x, monster.y - y
        if not monster.dead and dx * dx + dy * dy <= (radius + monster.radius) ^ 2 then
            self:damage_monster(monster, damage, item, false, "fire")
        end
    end
end

-- 화염 스플래시: origin 둘레 radius 안의 다른 적에게 화염 피해 (화염 무기의 직접 타격, ImpactEffects 의 splash)
local function splash_from(self, origin, damage, radius, item)
    radius = radius * FIELD_SCALE
    local hits = 0
    for _, monster in ipairs(self.monsters) do
        local dx, dy = monster.x - origin.x, monster.y - origin.y
        if monster ~= origin and not monster.dead and dx * dx + dy * dy <= (radius + monster.radius) ^ 2 then
            self:damage_monster(monster, damage, item, false, "fire")
            hits = hits + 1
        end
    end
    EventBus.emit("combat:splash", { x = origin.x, y = origin.y, radius = radius, item = item, hits = hits })
    return hits
end

-- 낙뢰: 레인 위(조준 가능 구역)의 모든 적에게 번개 피해
local function strike_all(self, damage, item)
    local limit = LANE.x + LANE.w
    local targets = {}
    for _, monster in ipairs(self.monsters) do
        if not monster.dead and monster.x < limit then
            targets[#targets + 1] = monster
        end
    end
    EventBus.emit("combat:thunder", { targets = targets, item = item })
    for _, monster in ipairs(targets) do
        Projectiles.add_beam(self, monster.x, LANE.y, monster.x, monster.y, THUNDER_COLOR, 6, item)
        self:damage_monster(monster, damage, item, false, "lightning")
    end
end

function CombatArea.install(Combat)
    Combat.chain_from = chain_from
    Combat.damage_area = damage_area
    Combat.strike_all = strike_all
    Combat.splash_from = splash_from
    assert(COMBAT.projectiles ~= nil, "CombatArea: data/combat.lua is missing projectiles")
end

return CombatArea
