-- systems/effects/GoldEffects.lua
-- 황금/상인 아키타입: 보유 골드 비례 공격력, 판매가 보너스, 처치 골드 추가.

local GoldEffects = {}

-- 미다스의 건틀릿: 보유 골드 per_gold 마다 피해 +100% (최대 +max_bonus)
function GoldEffects.gold_scaling(item, effect, ctx)
    return { {
        event = "combat:hit",
        priority = 10,
        fn = function(payload)
            if payload.item == item then
                local bonus = math.min(effect.max_bonus, ctx.workshop.gold / effect.per_gold)
                payload.damage = payload.damage * (1 + bonus)
            end
        end,
    } }
end

-- 상인의 저울: 모든 판매가 배율
function GoldEffects.sale_bonus(_, effect)
    return { {
        event = "economy:sale_price",
        priority = 10,
        fn = function(payload)
            payload.price = payload.price * effect.mult
        end,
    } }
end

-- 동전 골렘: 이 무기로 처치하면 골드 추가
function GoldEffects.kill_gold_flat(item, effect)
    return { {
        event = "combat:monster_killed",
        priority = 5,
        fn = function(payload)
            if payload.item == item then
                payload.gold = payload.gold + effect.gold
            end
        end,
    } }
end

return GoldEffects
