-- tools/SmokeCrowd.lua
-- 하룻밤 몬스터 상한 헤드리스 검사 (SmokeTest 가 SmokeWaves 다음에 실행) — data/waves.lua 의 crowd_cap · systems/WaveCrowd ·
-- systems/WaveSpawner · systems/Combat (night_spawns · summon):
--   실효 1~59일 밤 모두 per_night 이하 (예전 견습 마지막 밤 같은 500마리 스파이크 재발 방지)
--   상한 안의 밤(실효 5 · 10일): 계획 물량 그대로 · 몬스터 체력 = 스펙 × 그 밤 배율 · 웨이브 가중치 그대로 (예전과 똑같이)
--   상한을 넘는 밤(실효 20 · 30일): 정예 가중치가 그 자리에서 elite_mult 배 · hp_mult = 데이터로 다시 계산한 공식 ·
--     나온 몬스터마다 체력 = 스펙 × 그 밤 배율 × hp_mult · 밤새 고르게(12초 뒤 40% 이상 · 마지막 스폰이 스폰 창 끝 1초 안) ·
--     돌격 무리 크기 = floor(계획 크기 / r) · 소환(make)과 우두머리는 hp_mult 를 받지 않는다
--   레인 전체 상한: 웨이브 몬스터가 다 나온 뒤에 부른 소환도 그 밤 total 에서 멈추고, 받아 준 수만큼만 돌려준다

local SmokeCrowd = {}

local DT = 1 / 60

local function check(condition, message)
    if not condition then
        error("SmokeCrowd: " .. message, 2)
    end
end

local function near(a, b)
    return math.abs(a - b) <= 1e-9 * math.max(1, math.abs(b))
end

-- 한 밤을 끝까지: { monster, t } 목록
local function run_night(spawner)
    local all, t = {}, 0
    for _ = 1, 60 * 30 do
        t = t + DT
        for _, monster in ipairs(spawner:update(DT) or {}) do
            all[#all + 1] = { monster = monster, t = t }
        end
    end
    return all
end

local function base_weight(spec, wave_day)
    return spec.weight + spec.weight_growth * (wave_day - 1)
end

-- 그 밤의 체력 배율 (상한 전): 성장 × 중후반
local function night_scale(wave_day)
    local WAVES = require("data.waves")
    return (1 + WAVES.hp_growth * (wave_day - 1)) * (1 + WAVES.late.hp * math.max(0, wave_day - WAVES.late.from))
end

-- 가중치로 본 평균 기본 체력 (정예 가중치 x elite_mult)
local function average_hp(wave_day, elite_mult)
    local ENEMIES = require("data.enemies")
    local hp, weight = 0, 0
    for _, id in ipairs(ENEMIES.monster_order) do
        local spec = ENEMIES.monsters[id]
        if wave_day >= spec.min_day then
            local w = base_weight(spec, wave_day) * (spec.elite and elite_mult or 1)
            hp, weight = hp + w * spec.hp, weight + w
        end
    end
    return hp / weight
end

local function spawner_for(wave_day, day, schedule)
    return require("systems.WaveSpawner")(day or 1, require("core.RNG").stream("smoke_crowd"), schedule, nil, wave_day)
end

local function check_ceiling()
    local CAP = require("data.waves").crowd_cap
    for wave_day = 1, 59, 2 do                                      -- 41일 = 예전 견습 마지막 밤 (계획 약 500)
        local all = run_night(spawner_for(wave_day))
        check(#all <= CAP.per_night, string.format("wave day %d spawned %d > cap %d", wave_day, #all, CAP.per_night))
    end
end

local function check_identity()
    local ENEMIES, CAP = require("data.enemies"), require("data.waves").crowd_cap
    local WaveCrowd = require("systems.WaveCrowd")
    for _, wave_day in ipairs({ 5, 10 }) do
        local planned = WaveCrowd.planned(wave_day)
        check(planned <= CAP.per_night, "precondition: wave day " .. wave_day .. " is under the cap")
        local spawner = spawner_for(wave_day)
        check(spawner.crowd.ratio == 1 and spawner.crowd.hp_mult == 1, "under-cap nights keep ratio 1 and HP x1")
        for _, entry in ipairs(spawner._entries) do
            check(entry.weight == base_weight(ENEMIES.monsters[entry.id], wave_day), entry.id .. " keeps its wave weight under the cap")
        end
        local all = run_night(spawner)
        check(#all == planned, string.format("wave day %d spawns exactly the planned %d (got %d)", wave_day, planned, #all))
        for _, s in ipairs(all) do
            check(near(s.monster.max_hp, ENEMIES.monsters[s.monster.type_id].hp * night_scale(wave_day)), "under-cap HP has no crowd factor")
        end
    end
end

local function check_over_cap()
    local ENEMIES, WAVES = require("data.enemies"), require("data.waves")
    local WaveCrowd, CAP = require("systems.WaveCrowd"), WAVES.crowd_cap
    for _, wave_day in ipairs({ 20, 30 }) do
        local spawner = spawner_for(wave_day)
        local c = spawner.crowd
        check(near(c.ratio, WaveCrowd.planned(wave_day) / CAP.per_night) and c.ratio > 1
            and near(c.elite_mult, 1 + CAP.elite_weight * (c.ratio - 1)), "wave day " .. wave_day .. ": ratio and elite multiplier")
        for _, entry in ipairs(spawner._entries) do                 -- 정예 가중치가 웨이브 구성에서 실제로 올랐다
            local spec = ENEMIES.monsters[entry.id]
            check(near(entry.weight, base_weight(spec, wave_day) * (spec.elite and c.elite_mult or 1)), entry.id .. " weight is boosted in place")
        end
        local expected = 1 + CAP.hp_share * (c.ratio * average_hp(wave_day, 1) / average_hp(wave_day, c.elite_mult) - 1)
        check(near(c.hp_mult, expected), string.format("hp_mult %.4f follows the formula (%.4f)", c.hp_mult, expected))
        local all = run_night(spawner)
        local late, last = 0, 0
        for _, s in ipairs(all) do
            check(near(s.monster.max_hp, ENEMIES.monsters[s.monster.type_id].hp * night_scale(wave_day) * c.hp_mult), "crowd HP applied")
            late, last = late + (s.t > 12 and 1 or 0), math.max(last, s.t)
        end
        check(#all <= CAP.per_night and #all >= CAP.per_night - #WAVES.packs - 1, "wave day " .. wave_day .. " fills the cap: " .. #all)
        check(late / #all >= 0.4 and last >= WAVES.spawn_window - 1, string.format("capped spawns spread over the night (%d of %d after 12 s, "
            .. "last at %.1f s)", late, #all, last))
        local fresh, out = spawner_for(wave_day), {}
        fresh:_spawn_pack(WAVES.packs[#WAVES.packs], out)
        check(#out == math.floor(WaveCrowd.pack_size(WAVES.packs[#WAVES.packs], wave_day) / c.ratio), "pack bursts shrink by the ratio")
        local summon = fresh:make("goblin", 900, 400)
        check(near(summon.max_hp, ENEMIES.monsters.goblin.hp * night_scale(wave_day)), "summons skip the crowd HP multiplier")
    end
    local head = spawner_for(30, 35, { midboss = { at = 0, hp_mult = 1 } }):update(0.001)[1]
    check(head ~= nil and head:is_midboss() and near(head.max_hp, ENEMIES.monsters[head.type_id].hp * night_scale(30)
        * (1 + WAVES.escalation.hp_per_month * 3)), "headliners skip the crowd HP multiplier")
end

-- 레인 전체 상한: 웨이브·우두머리가 나온 뒤에 부른 소환도 total 에서 멈춘다
local function check_lane_total()
    local CAP = require("data.waves").crowd_cap
    local w = require("systems.Workshop")({ difficulty = "broker" })
    w.day, w.max_hp, w.hp = 60, 1000000, 1000000                   -- 실효 27일 = 상한이 꽉 차는 밤 (진열장 비어 있음)
    check(w:start_night(), "the lane-total night should start")
    for _ = 1, 60 * 26 do
        w:update(DT)
    end
    local before, accepted = w.combat.night_spawns, 0
    check(before >= CAP.per_night * 0.9, "waves filled the lane before summoning (" .. before .. ")")
    for _ = 1, CAP.total + 50 do
        accepted = accepted + (w.combat:summon("skeleton", 900, 450) and 1 or 0)
    end
    check(w.combat.night_spawns == CAP.total and accepted == CAP.total - before,
        string.format("summons stop at the lane total: %d before + %d accepted = %d", before, accepted, w.combat.night_spawns))
    w:destroy()
end

function SmokeCrowd.run(log)
    require("core.RNG").set_seed(8282)
    check_ceiling()
    check_identity()
    check_over_cap()
    check_lane_total()
    log("crowd ok (wave days 1~59 <= cap (no 500 spike), under-cap nights identical (count/HP/weights), over-cap: elite weights "
        .. "boosted in place, hp_mult formula, crowd HP per monster, spread over the night, packs / ratio, summons & headliners "
        .. "skip crowd HP, lane total stops summons after the waves)")
end

return SmokeCrowd
