-- systems/effects/FireEffects.lua
-- 화염/연소 아키타입: 화상 부여(인접), 화상 증폭, 화상 중첩 폭발, 불타는 적 사망 시 연쇄 폭발.

local Helpers = require("systems.effects.Helpers")

local FireEffects = {}

-- 잉걸불 화로: 상하좌우 무기의 적중에 화상을 더한다
function FireEffects.grant_burn(item, effect, ctx)
    return { {
        event = "combat:hit",
        fn = function(payload)
            if payload.item ~= item and not payload.chained and Helpers.adjacent(ctx.inventory, item, payload.item) then
                payload.monster:apply_burn(effect.dps * item:power_mult() * (payload.burn_mult or 1), effect.duration)
            end
        end,
    } }
end

-- 불사조 깃털: 이번 적중으로 부여되는 모든 화상 피해 배율 (화상 핸들러보다 먼저 실행)
function FireEffects.burn_amp(_, effect)
    return { {
        event = "combat:hit",
        priority = 20,
        fn = function(payload)
            payload.burn_mult = (payload.burn_mult or 1) * effect.mult
        end,
    } }
end

-- 폭염 화승총: 화상 stacks 중첩된 적을 맞히면 폭발 (중첩 초기화)
function FireEffects.burn_detonate(item, effect)
    return { {
        event = "combat:hit",
        priority = -5,
        fn = function(payload)
            local monster = payload.monster
            if payload.item == item and not payload.chained and monster.burn_stacks >= effect.stacks then
                monster.burn_stacks = 0
                payload.combat:damage_area(monster.x, monster.y, effect.radius, effect.damage * item:power_mult(), item)
            end
        end,
    } }
end

-- 용암 핵: 불타던 적이 죽으면 주변 폭발 (폭발로 죽은 불타는 적이 다시 터지는 연쇄 가능)
function FireEffects.burn_death_blast(item, effect)
    return { {
        event = "combat:monster_killed",
        fn = function(payload)
            if payload.burning and payload.combat ~= nil then
                payload.combat:damage_area(payload.x, payload.y, effect.radius, effect.damage, item)
            end
        end,
    } }
end

return FireEffects
