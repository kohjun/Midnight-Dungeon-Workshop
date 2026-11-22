-- tools/SmokeWaves.lua
-- 밤 물량 · 중간 보스 헤드리스 검사 (SmokeTest 가 SmokeBalanceReport 다음에 실행) — data/waves.lua · data/enemies.lua · systems/MidBossPatterns:
--   계획 물량(systems/WaveCrowd.planned)이 예전(간격 2.0초 시작 · 6일마다 +1) 같은 실효 일차의 1.5~2배 · 실제 스폰은 하룻밤 상한
--   (crowd_cap.per_night) 이하 · 돌격 무리(Pack Burst)가 한 프레임에 여러 마리
--   (하룻밤 상한의 자세한 검사는 tools/SmokeCrowd — 실효 1~59일 상한 이하 · 상한 안의 밤 그대로 · 넘는 밤의 정예·체력 · 레인 전체 상한)
--   중후반 위협(late · escalation, 수치는 전부 data 에서): 소환·일반 몬스터의 방벽 피해는 late.from 일차까지 스펙 그대로,
--     그 뒤 x(1 + late.damage × n) · 체력 비율에 late 체력 배율 포함 / 우두머리(35일 중간 보스)는 그 밤의 체력 배율 × 달별 체력,
--     방벽 피해는 달별 배율만 (late 피해 X)
--   일정: 월 중순 5·15·25·35일 = 선봉장 · 약탈 대장 · 주술사 · 추적자 (45일 다시 선봉장, 기믹 강도 상승) · 월말 = 대보스
--   기믹: 선봉장 돌파(가속 + 둔화 면역 + 넉백 저항) · 약탈 대장 궁지 돌진 · 주술사 오라(아군 회복) · 추적자 졸개 소환
--   처치 보상(연마석 · 보너스 골드, combat:midboss_slain) · 툴팁 등급 "중간 보스" · 상단 전용 체력 바 픽셀
--   (--shots 면 smoke_midboss.png)

local SmokeWaves = {}

local DT = 1 / 60
-- 예전 물량 (같은 실효 일차의 한 밤 총 스폰 수, 2단계 이전 공식)
local REFERENCE = { [1] = 12, [10] = 34, [20] = 140, [30] = 210 }

local function check(condition, message)
    if not condition then
        error("SmokeWaves: " .. message, 2)
    end
end

local function near(a, b)
    return math.abs(a - b) <= 1e-9 * math.max(1, math.abs(b))
end

-- 한 밤을 끝까지: 나온 몬스터 목록 · 한 프레임 최대 수
local function run_night(spawner)
    local all, biggest = {}, 0
    for _ = 1, 60 * 30 do
        local list = spawner:update(DT)
        for _, monster in ipairs(list or {}) do
            all[#all + 1] = monster
        end
        biggest = math.max(biggest, list and #list or 0)
    end
    return all, biggest
end

local function check_density()
    local WaveSpawner, WaveCrowd = require("systems.WaveSpawner"), require("systems.WaveCrowd")
    local RNG = require("core.RNG")
    local cap = require("data.waves").crowd_cap.per_night
    for wave_day, reference in pairs(REFERENCE) do
        local planned = WaveCrowd.planned(wave_day)
        local ratio = planned / reference
        check(ratio >= 1.5 and ratio <= 2.0, string.format("wave day %d plans %d (x%.2f of the old %d)", wave_day, planned, ratio, reference))
        local spawner = WaveSpawner(1, RNG.stream("smoke_waves"), nil, nil, wave_day)
        local all, biggest = run_night(spawner)
        local exact = planned <= cap                              -- 상한 안의 밤은 계획 물량 그대로
        check(#all == spawner.spawned and #all <= cap and (exact and #all == planned or not exact and #all >= cap - 4),
            string.format("wave day %d spawns %d of the planned %d (cap %d)", wave_day, #all, planned, cap))
        check(spawner:is_done() and biggest >= (wave_day >= 10 and 4 or 2), "pack bursts drop several monsters in one frame (day "
            .. wave_day .. ", biggest " .. biggest .. ")")
    end
end

-- 중후반 위협 (data/waves.lua 의 late · escalation): 소환(make)·일반 몬스터는 late 체력·방벽 피해를 받고,
-- 우두머리는 그 밤의 체력 배율(late 포함) × 달별 체력 배율, 방벽 피해는 달별 배율만 받는다
local function check_scaling()
    local WaveSpawner, Calendar, RNG = require("systems.WaveSpawner"), require("systems.Calendar"), require("core.RNG")
    local WAVES, MONSTERS = require("data.waves"), require("data.enemies").monsters
    local LATE, ESC = WAVES.late, WAVES.escalation
    check(LATE.hp > 0 and LATE.damage > 0 and ESC.hp_per_month > 0 and ESC.damage_per_month > 0,
        "precondition: the late threat and the monthly escalation both scale HP and damage")
    local function hp_scale(wave_day)                       -- 그 밤의 체력 배율 (수정자 없음)
        return (1 + WAVES.hp_growth * (wave_day - 1)) * (1 + LATE.hp * math.max(0, wave_day - LATE.from))
    end
    local low, high = LATE.from, LATE.from + 10             -- n = 0 · n = 10
    local n = high - LATE.from
    local function summon(wave_day)
        return WaveSpawner(wave_day, RNG.stream("smoke_waves"), nil, nil, wave_day):make("goblin", 900, 400)
    end
    local spec, early, late = MONSTERS.goblin, summon(low), summon(high)
    check(early.damage == spec.damage, string.format("no late damage up to wave day %d: summon hits %s, spec %s",
        low, tostring(early.damage), tostring(spec.damage)))
    check(near(late.damage, spec.damage * (1 + LATE.damage * n)), string.format("wave day %d summons hit x%.2f: %s vs %s",
        high, 1 + LATE.damage * n, tostring(late.damage), tostring(spec.damage * (1 + LATE.damage * n))))
    local ratio, growth = late.max_hp / early.max_hp, (1 + WAVES.hp_growth * (high - 1)) / (1 + WAVES.hp_growth * (low - 1))
    check(near(early.max_hp, spec.hp * hp_scale(low)) and near(ratio, hp_scale(high) / hp_scale(low)) and ratio > growth,
        string.format("summon HP x%.3f from wave day %d to %d includes the late HP factor (growth alone x%.3f)", ratio, low, high, growth))

    local day = 35                                          -- 4개월 중순: 중간 보스, 실효 일차는 high (late 피해가 1보다 크다)
    local id, months = WaveSpawner.midboss_for(day), Calendar.month(day) - 1
    check(id ~= nil and months > 0, "day " .. day .. " is a mid-month night after the first month")
    local spawner = WaveSpawner(day, RNG.stream("smoke_waves"), { midboss = { at = 0, hp_mult = 1 } }, nil, high)
    local head = nil
    for _, monster in ipairs(spawner:update(0.001) or {}) do
        head = monster:is_midboss() and monster or head
    end
    check(head ~= nil and head.type_id == id, "the day " .. day .. " headliner " .. id .. " spawns at once")
    local boss = MONSTERS[id]
    local damage, hp = boss.damage * (1 + ESC.damage_per_month * months), boss.hp * hp_scale(high) * (1 + ESC.hp_per_month * months)
    check(near(head.damage, damage), string.format("headliners get only the monthly damage x%.2f (no late damage): %s vs %s",
        1 + ESC.damage_per_month * months, tostring(head.damage), tostring(damage)))
    check(near(head.max_hp, hp), string.format("headliner HP = spec x night scale x month %.2f: %s vs %s",
        1 + ESC.hp_per_month * months, tostring(head.max_hp), tostring(hp)))
end

-- day 일차 밤: 진열장엔 쏘지 않는 증폭기만 (중간 보스가 살아 있도록) → 우두머리가 나올 때까지
local function night(day)
    local Workshop, Item = require("systems.Workshop"), require("entities.Item")
    local w = Workshop({ difficulty = "broker" })
    w.day, w.max_hp, w.hp = day, 100000, 100000
    local crystal = Item("mana_crystal", {})
    crystal.owned = true
    w.inventory:place(crystal, "grid", 13)
    check(w:start_night(), "night should start on day " .. day)
    for _ = 1, 60 * 15 do
        w:update(DT)
        for _, monster in ipairs(w.combat.monsters) do
            if monster:is_midboss() or monster:is_boss() then
                return w, monster
            end
        end
    end
    error("SmokeWaves: no headliner on day " .. day)
end

local function advance(w, seconds)
    for _ = 1, math.floor(seconds / DT) do
        w:update(DT)
    end
end

local function check_midbosses(shots)
    local EventBus = require("core.EventBus")
    local WaveSpawner = require("systems.WaveSpawner")
    local MonsterTooltip = require("ui.MonsterTooltip")
    check(WaveSpawner.midboss_for(5) == "mid_vanguard" and WaveSpawner.boss_for(10) == "gatekeeper_golem", "mid-month / month-end")
    local events, probe = {}, {}
    for _, name in ipairs({ "boss:vanguard_charge", "boss:raider_dash", "boss:hex_pulse", "boss:summoned", "combat:midboss_slain",
        "combat:midboss_arrived" }) do
        EventBus.subscribe(name, function(p) events[name] = p end, { owner = probe })
    end
    local w, vanguard = night(5)
    check(vanguard.type_id == "mid_vanguard" and events["combat:midboss_arrived"] ~= nil, "day 5 brings the Ironclad Vanguard")
    check(MonsterTooltip.tier(vanguard) == "midboss" and #MonsterTooltip.traits(vanguard) >= 3, "the tooltip shows mid-boss tier and traits")
    vanguard:apply_slow(0.3, 3)
    check(vanguard.slow_time == 0 and vanguard:knock_back(100) < 10, "the vanguard ignores slows and barely budges")
    advance(w, 4.2)
    check(events["boss:vanguard_charge"] ~= nil and vanguard.boost_time > 0, "the vanguard charges ahead")
    local stones, gold = w.tempering_stones, w.gold
    w.combat:damage_monster(vanguard, vanguard.hp + 1, nil, false, "fire")
    local slain = events["combat:midboss_slain"]
    check(slain ~= nil and w.tempering_stones >= stones + slain.stones and w.gold >= gold + slain.gold, "mid-bosses pay stones and gold")
    w:destroy()

    local w2, raider = night(15)
    check(raider.type_id == "mid_raider", "day 15 brings the Raid Captain")
    raider.hp = raider.max_hp * 0.3
    advance(w2, 0.3)
    check(events["boss:raider_dash"] ~= nil and raider.boost_time > 0, "a cornered raid captain dashes")
    w2:destroy()

    local w3, hexer = night(25)
    check(hexer.type_id == "mid_hexer", "day 25 brings the Plague Hexer")
    w3.combat:summon("slime", hexer.x + 20, hexer.y)
    local ally = w3.combat.monsters[#w3.combat.monsters]
    ally.hp = ally.max_hp * 0.2
    advance(w3, 3.2)
    check(events["boss:hex_pulse"] ~= nil and ally.hp > ally.max_hp * 0.2, "the hexer's aura heals nearby monsters")
    w3:destroy()

    local w4, stalker = night(35)
    check(stalker.type_id == "mid_stalker", "day 35 brings the Rift Stalker")
    local count = #w4.combat.monsters
    advance(w4, 3.2)
    check(events["boss:summoned"] ~= nil and events["boss:summoned"].count >= 2 and #w4.combat.monsters > count, "the stalker summons")
    w4:destroy()

    local w5, again = night(45)
    check(again.type_id == "mid_vanguard" and again.intensity > 1.3, "the cycle repeats with stronger gimmicks")
    local Viewport, LaneView, MidBossView = require("core.Viewport"), require("ui.LaneView"), require("ui.MidBossView")
    local canvas = love.graphics.newCanvas(Viewport.width(), Viewport.height())
    love.graphics.push("all")
    love.graphics.setCanvas({ canvas, stencil = true })
    LaneView.draw(w5, 1, nil)
    love.graphics.setCanvas()
    love.graphics.pop()
    local data = canvas:newImageData()
    local bar = MidBossView.bar_rect(require("data.layout").night.lane)
    local r, g = data:getPixel(bar.x + 6, bar.y + bar.h / 2)
    check(r > 0.6 and g < 0.35, "the dedicated mid-boss HP bar is drawn at the top of the lane")
    if shots then
        data:encode("png", "smoke_midboss.png")
    end
    w5:destroy()
    EventBus.unsubscribe_owner(probe)
end

function SmokeWaves.run(log, shots)
    require("core.RNG").set_seed(8181)
    check_density()
    check_scaling()
    check_midbosses(shots)
    log("waves ok (x1.5~2 planned vs the old curve, spawns = planned under the cap / <= cap over it, pack bursts; "
        .. "late HP/damage on summons, headliners month-only damage; "
        .. "mid-bosses 5/15/25/35/45 · vanguard charge/slow-immune/knockback · "
        .. "raider dash · hexer heal aura · stalker minions · stones+gold reward · tooltip tier · top HP bar)")
end

return SmokeWaves
