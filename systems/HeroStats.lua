-- systems/HeroStats.lua
-- 주인공 스탯 계산 (순수 함수 — 수치 data/hero.lua · data/armors.lua, 장비는 Workshop:hero_gear()).
--   compute(workshop) → {
--     max_hp, attack, defense, crit, crit_mult, move_speed, roll_cooldown, roll_invuln, resist, cooldown,    -- 합산 스탯
--     guard(방벽 피격 경감률) · counter(반격 배율) · strike_interval(일반 밤 레인 타격 간격),
--     damage_type(장착 무기의 피해 속성, 없으면 "physical"),
--     gear = { { slot, item|nil, broken(0% 완전 마모) } × 4 },
--     skills = { q = { id, cooldown, power }, e = { id, cooldown, … }, r = { id, cooldown, duration, power } },
--   }
-- 기본 스탯 + 착용 4부위: 무기는 공격력 × attack_share, 방어구는 Item:gear_stats() (등급 · 세척 · 강화 배율의 일부).
-- 내구도 0% 인 장비는 아무것도 주지 않는다 (무기 = 맨손 공격력 · 스킬도 맨손, 갑옷 = E 스킬 없음). 상한은 HERO.caps.

local DamageRules = require("systems.DamageRules")
local HERO = require("data.hero")
local ARMORS = require("data.armors")

local HeroStats = {}

local BASE, CAPS = HERO.base, HERO.caps
local ADDITIVE = { "max_hp", "defense", "crit", "resist", "cooldown", "roll_invuln" }

local function working(item)
    return item ~= nil and not item:is_worn_out()
end

-- Q 스킬 표: 장착 무기의 피해 속성 (저주 아키타입 무기는 curse)
local function weapon_skill(weapon)
    if not working(weapon) then
        return HERO.skills.unarmed
    end
    local key = weapon.proto.archetype == "curse" and "curse" or DamageRules.type_of(weapon)
    return HERO.skills.weapon[key] or HERO.skills.weapon.physical
end

local function with_cooldown(spec, reduction)
    local out = {}
    for key, value in pairs(spec) do
        out[key] = value
    end
    out.cooldown = spec.cooldown * (1 - reduction)
    return out
end

function HeroStats.compute(workshop)
    local gear = workshop:hero_gear()
    local stats = { gear = {} }
    for key, value in pairs(BASE) do
        stats[key] = value
    end
    local speed_bonus, roll_cut = 0, 0
    for _, slot in ipairs(HERO.slots) do
        local item = gear[slot]
        stats.gear[#stats.gear + 1] = { slot = slot, item = item, broken = item ~= nil and item:is_worn_out() }
        local bonus = item and item:gear_stats()
        if bonus ~= nil then
            for _, key in ipairs(ADDITIVE) do
                stats[key] = stats[key] + (bonus[key] or 0)
            end
            speed_bonus = speed_bonus + (bonus.move_speed or 0)
            roll_cut = roll_cut + (bonus.roll_cooldown or 0)
        end
    end
    local weapon = gear.weapon
    if working(weapon) then
        stats.attack = BASE.attack + weapon:attack() * HERO.weapon.attack_share
        stats.damage_type = DamageRules.type_of(weapon)
    else
        stats.damage_type = "physical"
    end
    stats.crit = math.min(CAPS.crit, stats.crit)
    stats.defense = math.min(CAPS.defense, stats.defense)
    stats.resist = math.min(CAPS.resist, stats.resist)
    stats.cooldown = math.min(CAPS.cooldown, stats.cooldown)
    stats.move_speed = math.min(CAPS.move_speed, BASE.move_speed * (1 + speed_bonus))
    stats.roll_cooldown = math.max(CAPS.roll_cooldown_min, BASE.roll_cooldown * (1 - roll_cut))
    local haste = stats.move_speed / BASE.move_speed - 1
    stats.guard = math.min(HERO.guard.max, stats.defense * HERO.guard.per_defense)
    stats.counter = HERO.counter.base + haste * HERO.counter.per_speed
    stats.strike_interval = HERO.melee.interval / (1 + haste * HERO.melee.speed_share)

    local chest = gear.chest
    local chest_skill = working(chest) and chest.proto.skill or nil
    local e_spec = chest_skill and ARMORS.skills[chest_skill] or HERO.skills.bare_chest
    stats.skills = {
        q = with_cooldown(weapon_skill(weapon), stats.cooldown),
        e = with_cooldown(e_spec, stats.cooldown),
        r = with_cooldown(HERO.skills.overdrive, stats.cooldown),
    }
    stats.skills.e.id = chest_skill or HERO.skills.bare_chest.id
    return stats
end

return HeroStats
