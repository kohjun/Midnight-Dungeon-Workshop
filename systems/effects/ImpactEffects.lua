-- systems/effects/ImpactEffects.lua
-- 타격감 효과 (무기 원형의 effects 에서 쓴다, 직접 타격에만):
--   knockback : 중량 물리 무기 — 맞은 적을 포탈 쪽(오른쪽)으로 distance(× field_scale) 밀어낸다.
--               정예·보스는 data/combat.lua 의 knockback 저항만큼 덜 밀리고(Monster:knock_back), 조준 가능 구역 밖으로는 밀리지 않는다
--   splash    : 화염 무기 — 맞은 지점 반경 radius(× field_scale) 안의 다른 적에게 이번 피해의 ratio 만큼 화염 피해 (Combat:splash_from)
-- 수정자(priority ≥ 0)가 피해를 확정한 뒤에 실행되도록 낮은 우선순위로 구독한다.

local EventBus = require("core.EventBus")
local COMBAT = require("data.combat")
local LAYOUT = require("data.layout")

local ImpactEffects = {}

local FIELD_SCALE = LAYOUT.night.field_scale
local LANE = LAYOUT.night.lane
local PUSH_LIMIT_X = LANE.x + LANE.w - COMBAT.projectiles.target_margin * FIELD_SCALE     -- 조준 가능 구역 오른쪽 끝
local PRIORITY = -20

function ImpactEffects.knockback(item, effect)
    return { {
        event = "combat:hit",
        priority = PRIORITY,
        fn = function(payload)
            local monster = payload.monster
            if payload.item == item and not payload.chained and not monster.dead then
                local moved = monster:knock_back(effect.distance * FIELD_SCALE, PUSH_LIMIT_X)
                if moved > 0 then
                    EventBus.emit("combat:knockback", { monster = monster, distance = moved, x = monster.x, y = monster.y, item = item })
                end
            end
        end,
    } }
end

function ImpactEffects.splash(item, effect)
    return { {
        event = "combat:hit",
        priority = PRIORITY,
        fn = function(payload)
            if payload.item == item and not payload.chained then
                payload.combat:splash_from(payload.monster, payload.damage * effect.ratio, effect.radius, item)
            end
        end,
    } }
end

return ImpactEffects
