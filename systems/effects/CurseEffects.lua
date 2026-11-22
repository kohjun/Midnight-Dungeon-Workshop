-- systems/effects/CurseEffects.lua
-- 저주/혈마법 아키타입: 저주 유물 수 비례 곱연산, 처치 시 방벽 흡혈, 내구도를 바쳐 골드 획득.

local I18n = require("systems.I18n")
local Helpers = require("systems.effects.Helpers")

local CurseEffects = {}

-- 혈석 우상: 진열장의 저주 유물 n개 → 모든 무기 공격 x per_curse^n (인접 배율 이후에 곱한다)
function CurseEffects.curse_count_mult(item, effect, ctx)
    return { {
        event = "grid:compute_stats",
        priority = 1,
        fn = function(payload)
            local cursed = 0
            for target in pairs(payload.stats) do
                if target.flaw == "curse" then
                    cursed = cursed + 1
                end
            end
            if cursed == 0 then
                return
            end
            local mult = effect.per_curse ^ cursed
            for target, stat in pairs(payload.stats) do
                if target:is_weapon() then
                    stat.attack_mult = stat.attack_mult * mult
                    Helpers.add_bonus(stat, I18n.t("bonus.curse_count", {
                        name = I18n.item_name(item), count = cursed, mult = string.format("%.2f", mult),
                    }))
                end
            end
        end,
    } }
end

-- 저주 낫: 이 무기로 처치할 때마다 방벽 회복
function CurseEffects.wall_leech(item, effect, ctx)
    return { {
        event = "combat:monster_killed",
        fn = function(payload)
            if payload.item == item then
                ctx.workshop:heal(effect.hp, "leech")
            end
        end,
    } }
end

-- 피의 계약서: 매일 밤 내구도를 바치고 골드를 얻는다 (저주 대가 상한에 막히면 실제로 바친 만큼만).
-- 한 밤의 저주 대가 상한(BALANCE.curse.night_cap)은 HP 1 당 골드가 큰 계약부터 쓴다 — priority = gold / hp_cost
-- (골드 없는 피의 대가(단검, priority 0)는 맨 나중). 진열 순서·이어하기 복원 순서와 무관하게 결과가 같다.
function CurseEffects.hp_for_gold(item, effect)
    return { {
        event = "phase:night_started",
        priority = math.max(1, math.floor(effect.gold / effect.hp_cost)),
        fn = function(payload)
            local paid = payload.workshop:damage_hp(effect.hp_cost, "curse", item) or 0
            if paid > 0 then
                payload.workshop:add_gold(math.floor(effect.gold * paid / effect.hp_cost + 0.5), "pact")
            end
        end,
    } }
end

return CurseEffects
