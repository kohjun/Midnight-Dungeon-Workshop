-- systems/effects/CoreEffects.lua
-- 공용 효과 핸들러: 인접 증폭·저주, 수익 오라, 화상, 둔화, 연쇄 번개, 골드 보너스, 방벽 보호, 혈의 대가.

local Helpers = require("systems.effects.Helpers")

local CoreEffects = {}

-- 증폭기: 상하좌우 대상 카테고리 유물 강화
function CoreEffects.adjacent_boost(item, effect, ctx)
    return Helpers.adjacent_modifier(item, effect, ctx.inventory, "boost")
end

-- 저주 결함: 상하좌우 유물 약화
function CoreEffects.adjacent_curse(item, effect, ctx)
    return Helpers.adjacent_modifier(item, effect, ctx.inventory, "curse")
end

-- 진열장 전체 일일 수익 배율
function CoreEffects.income_aura(item, effect)
    return { {
        event = "grid:compute_stats",
        priority = 5,
        fn = function(payload)
            for _, stat in pairs(payload.stats) do
                stat.income_mult = stat.income_mult * effect.income_mult
                Helpers.add_label_bonus(stat, item, effect)
            end
        end,
    } }
end

-- 적중 시 화상 (강화·세척 배율과 화상 증폭 burn_mult 를 따른다)
function CoreEffects.burn(item, effect)
    return { {
        event = "combat:hit",
        fn = function(payload)
            if payload.item == item and not payload.chained then
                payload.monster:apply_burn(effect.dps * item:power_mult() * (payload.burn_mult or 1), effect.duration)
            end
        end,
    } }
end

-- 적중 시 둔화
function CoreEffects.slow(item, effect)
    return { {
        event = "combat:hit",
        fn = function(payload)
            if payload.item == item then
                payload.monster:apply_slow(effect.factor, effect.duration)
            end
        end,
    } }
end

-- 적중 시 주변으로 번개 연쇄 (연쇄 피해는 다시 연쇄하지 않는다)
function CoreEffects.chain(item, effect)
    return { {
        event = "combat:hit",
        priority = -10,
        fn = function(payload)
            if payload.item == item and not payload.chained then
                payload.combat:chain_from(payload.monster, effect.count, effect.range,
                    payload.damage * effect.damage_ratio, item)
            end
        end,
    } }
end

-- 몬스터 처치 골드 배율
function CoreEffects.gold_bonus(_, effect)
    return { {
        event = "combat:monster_killed",
        priority = 10,
        fn = function(payload)
            payload.gold = payload.gold * effect.gold_mult
        end,
    } }
end

-- 방벽 피해 감소
function CoreEffects.wall_guard(_, effect)
    return { {
        event = "combat:wall_hit",
        priority = 10,
        fn = function(payload)
            payload.damage = payload.damage * (1 - effect.reduction)
        end,
    } }
end

-- 매일 밤 시작 시 공방 내구도 대가 (priority 0 — 골드를 주는 계약(CurseEffects.hp_for_gold)이 상한을 먼저 쓴다)
function CoreEffects.blood_price(item, effect)
    return { {
        event = "phase:night_started",
        fn = function(payload)
            payload.workshop:damage_hp(effect.hp_cost, "curse", item)
        end,
    } }
end

return CoreEffects
