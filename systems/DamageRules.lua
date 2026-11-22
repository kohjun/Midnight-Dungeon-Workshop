-- systems/DamageRules.lua
-- 몬스터가 받는 피해 보정 (data/combat.lua 의 damage). Combat:damage_monster 가 피해를 적용하기 직전에 부른다.
--   피해 종류: 유물 원형의 damage_type ("physical" | "fire" | "lightning" | "frost"), 화상·폭발 = "fire", 낙뢰·연쇄 = "lightning"
--   ① 면역: 균열 군주가 "physical" 면역이면 원소가 아닌 피해, "elemental" 면역이면 원소 피해를 막는다
--   ② 감전: 감전된 적은 피해 + shock_bonus × (몬스터 shock_vulnerability, 기본 1)
--   ③ 연사 경감: rapid_resist 몬스터(방패병)는 실제 연사가 rapid_rate 이상인 무기의 직접 타격 피해를 깎는다
--   ④ 받는 피해 배율: monster.damage_taken_mult (최종 보스 균열 아이기스 x0.25 · 그로기 x1.5 — systems/MasterBossPattern)

local RNG = require("core.RNG")
local COMBAT = require("data.combat")

local DamageRules = {}

local RULES = COMBAT.damage
local ELEMENTAL = {}
for _, kind in ipairs(RULES.elemental) do
    ELEMENTAL[kind] = true
end

function DamageRules.type_of(item)
    return item and item.proto.damage_type or "physical"
end

-- 치명타 판정 (무기의 직접 타격마다, "combat" 난수 스트림): 피해 배율, 치명타 여부
function DamageRules.roll_crit()
    if RNG.stream("combat"):chance(COMBAT.crit.chance) then
        return COMBAT.crit.mult, true
    end
    return 1, false
end

function DamageRules.is_elemental(kind)
    return ELEMENTAL[kind] == true
end

-- source: { item, damage_type, direct = 무기의 직접 타격인지, rate = 그 무기의 실제 연사 }
-- 반환: 최종 피해, 표시 표식("immune" | "armored" | nil)
function DamageRules.apply(monster, amount, source)
    local spec = monster.spec
    local kind = source.damage_type or DamageRules.type_of(source.item)
    if monster.immunity ~= nil and (monster.immunity == "elemental") == (ELEMENTAL[kind] == true) then
        return amount * RULES.immune_mult, "immune"
    end
    local mark = nil
    if monster:is_shocked() then
        amount = amount * (1 + RULES.shock_bonus * (spec.shock_vulnerability or 1))
    end
    if (monster.defense or 0) > 0 then              -- 겨울 방어력 (systems/WaveSpawner)
        amount = amount * (1 - monster.defense)
    end
    amount = amount * (monster.damage_taken_mult or 1)
    if spec.rapid_resist ~= nil and source.direct and (source.rate or 0) >= spec.rapid_rate then
        amount = amount * (1 - spec.rapid_resist)
        mark = "armored"
    end
    return amount, mark
end

return DamageRules
