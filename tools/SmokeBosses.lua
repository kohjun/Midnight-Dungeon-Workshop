-- tools/SmokeBosses.lua
-- 전투 깊이 헤드리스 검사: 피해 규칙(감전·암살자 취약·방패병 연사 경감·균열 면역)과 5일 주기 보스 4종의 고유 패턴.
--   5일차 골렘 거미줄(봉인 칸 사격 정지 → 5번 클릭 해제) · 10일차 약탈자(골드 강탈 → 처치 시 2배 반환)
--   15일차 사령술사(해골 소환 · 보호막 반사로 방벽 피해) · 20일차 균열 군주(물리/원소 면역 교대)

local SmokeBosses = {}

local DT = 1 / 30

local function check(condition, message)
    assert(condition, "SmokeBosses: " .. message)
end

local function boss_of(combat)
    for _, monster in ipairs(combat.monsters) do
        if monster:is_boss() then
            return monster
        end
    end
    return nil
end

-- day 일차 밤을 시작해 보스가 나올 때까지 진행. 진열장에는 쏘지 않는 증폭기 하나만 둔다 (보스가 살아 있도록)
local function night_with_boss(day)
    local Workshop = require("systems.Workshop")
    local Item = require("entities.Item")
    local w = Workshop({ difficulty = "broker" })
    w.day, w.gold = day, 1000
    w.max_hp, w.hp = 100000, 100000     -- 무기 없이 버티도록 (방벽이 무너지면 전투가 멈춘다)
    local crystal = Item("mana_crystal", {})
    crystal.owned = true
    w.inventory:place(crystal, "grid", 13)
    check(w:start_night(), "night should start on day " .. day)
    for _ = 1, 30 * 12 do
        w:update(DT)
        if boss_of(w.combat) ~= nil then
            return w, boss_of(w.combat)
        end
    end
    error("SmokeBosses: no boss appeared on day " .. day)
end

local function advance(w, seconds)
    for _ = 1, math.floor(seconds / DT) do
        w:update(DT)
    end
end

local function check_damage_rules()
    local DamageRules = require("systems.DamageRules")
    local Monster = require("entities.Monster")
    local Item = require("entities.Item")
    local slime = Monster("slime", 0, 0, 1)
    slime:apply_shock(2)
    check(math.abs(DamageRules.apply(slime, 10, { damage_type = "fire" }) - 12) < 1e-9, "shock adds +20% damage")
    local assassin = Monster("shadow_assassin", 0, 0, 1)
    assassin:apply_shock(2)
    check(math.abs(DamageRules.apply(assassin, 10, { damage_type = "fire" }) - 16) < 1e-9, "assassins take x3 shock bonus")
    local shield = Monster("shield_bearer", 0, 0, 1)
    local fast, mark = DamageRules.apply(shield, 10, { damage_type = "physical", direct = true, rate = 1.5 })
    check(math.abs(fast - 3) < 1e-9 and mark == "armored", "shieldbearers block 70% of rapid-fire hits")
    check(DamageRules.apply(shield, 10, { damage_type = "physical", direct = true, rate = 0.7 }) == 10, "slow heavy hits pass shields")
    check(DamageRules.apply(shield, 10, { damage_type = "fire" }) == 10, "explosions and burns pass shields")
    local sword, orb = Item("flame_sword", {}), Item("lightning_orb", {})
    check(sword.proto.damage_type == "fire" and orb.proto.damage_type == "lightning", "weapons carry damage types")
end

local function check_golem()
    local w, golem = night_with_boss(10)
    check(golem.type_id == "gatekeeper_golem", "month 1 end (day 10) boss is the gatekeeper golem")
    advance(w, 3.5)
    check(w.combat.webs[13] == 5, "the golem webs the showcase cell with a relic")
    for _ = 1, 4 do
        w.combat:hit_web(13)
    end
    check(w.combat.webs[13] == 1, "each click tears one strand")
    w.combat:hit_web(13)
    check(w.combat.webs[13] == nil, "five clicks clear the web")
    w:destroy()
end

local function check_raider()
    local w, raider = night_with_boss(20)
    check(raider.type_id == "greed_raider", "month 2 end (day 20) boss is the greedy raider")
    local before = w.gold
    advance(w, 3.05)
    local stolen = raider.pattern.stolen
    check(stolen >= 15 and w.gold == before - stolen, "the raider steals 5 G per second, stole " .. stolen)
    local gold = w.gold
    w.combat:damage_monster(raider, raider.hp + 1, nil, false, "fire")
    check(raider.dead and w.gold >= gold + stolen * 2, "killing the raider returns double the loot")
    w:destroy()
end

local function check_necromancer()
    local w, necro = night_with_boss(30)
    check(necro.type_id == "abyss_necromancer", "month 3 end (day 30) boss is the necromancer")
    advance(w, 6.2)
    local skeletons = 0
    for _, monster in ipairs(w.combat.monsters) do
        skeletons = skeletons + (monster.type_id == "skeleton" and 1 or 0)
    end
    check(skeletons >= 2, "the necromancer raises skeletons")
    check(necro.shield_time > 0 or necro.pattern.shield > 0, "shield timer is running")
    necro.shield_time = 4
    local hp = w.hp
    w.combat:damage_monster(necro, 40, nil, false, "fire")
    check(math.abs(w.hp - (hp - 10)) < 1e-9, "the red shield reflects 25% of damage onto the wall, hp " .. hp .. " -> " .. w.hp)
    w:destroy()
end

local function check_rift_lord()
    local Item = require("entities.Item")
    local w, lord = night_with_boss(40)
    check(lord.type_id == "rift_lord" and lord.immunity == "physical", "month 4 end (day 40) boss is the rift lord, physical-immune first")
    local hp = lord.hp
    w.combat:damage_monster(lord, 50, Item("hex_scythe", {}), false, nil, true)
    check(lord.hp == hp, "physical damage is blocked while physical-immune")
    w.combat:damage_monster(lord, 50, Item("flame_sword", {}), false, nil, true)
    check(lord.hp < hp, "fire damage gets through")
    advance(w, 10.1)
    check(lord.immunity == "elemental", "immunity swaps every 10 seconds")
    w:destroy()
end

function SmokeBosses.run(log)
    require("core.RNG").set_seed(5150)
    check_damage_rules()
    check_golem()
    check_raider()
    check_necromancer()
    check_rift_lord()
    log("bosses ok (shock/assassin/shield/immunity rules; golem web, raider theft+refund, necro summons+reflect, rift immunity swap)")
end

return SmokeBosses
