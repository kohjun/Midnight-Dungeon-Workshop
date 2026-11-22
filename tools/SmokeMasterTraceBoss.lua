-- tools/SmokeMasterTraceBoss.lua
-- '스승의 흔적' 캠페인 규칙 헤드리스 검사 2부 (tools/SmokeMasterTrace 가 부른다):
--   ④ 60일차 밤: 월말 보스 대신 boss_master · 행/열 룬 사슬(그 줄 무기 사격 정지 → 시간이 지나면 풀림) ·
--      65% 균열 아이기스(피해 x0.25, 과부하 없이는 안 깨짐 → 과부하로 파훼 → 그로기 멈춤 · 피해 x1.5) · 30% 두 번째 아이기스
--   ⑤ 엔딩: 4/4 점화 상태로 보스 처치 = true_dawn(진엔딩 훈장 1회) · 그 밖 = new_gatekeeper · 저장/이어하기로 캠페인 상태 보존

local SmokeMasterTraceBoss = {}

local function kit()
    return require("tools.SmokeMasterTrace").kit
end

-- 60일차 밤: 보스가 나올 때까지
local function final_night(w)
    local check, DT = kit().check, kit().DT
    w.day, w.gold, w.max_hp, w.hp = 60, 1000000, 100000, 100000
    check(w:start_night(), "the final night should start")
    for _ = 1, 30 * 12 do
        w:update(DT)
        for _, monster in ipairs(w.combat.monsters) do
            if monster.spec.final then
                return monster
            end
        end
    end
    error("SmokeMasterTrace: boss_master never appeared")
end

local function check_boss()
    local K = kit()
    local check, near, recorder, campaign, fill_slots, DT = K.check, K.near, K.recorder, K.campaign, K.fill_slots, K.DT
    local WaveSpawner = require("systems.WaveSpawner")
    local ENEMIES = require("data.enemies")
    local DATA = ENEMIES.boss_patterns.master
    check(WaveSpawner.headliner(60, { day = 60, type = "boss_master" }) == "boss_master" and WaveSpawner.headliner(60) ~= "boss_master",
        "day 60 headliner is boss_master only in the campaign")
    local rec = recorder({ "boss:master_arrived", "boss:lockdown", "boss:lockdown_ended", "boss:aegis_raised", "boss:aegis_broken",
        "boss:groggy_ended", "combat:fired" })
    local w = campaign()
    fill_slots(w, 5)
    local boss = final_night(w)
    local combat = w.combat
    check(rec.seen["boss:master_arrived"] == 1 and boss.type_id == "boss_master" and boss:is_boss(), "boss_master arrives on night 60")
    for _ = 1, 30 * 8 do
        if rec.seen["boss:lockdown"] > 0 then
            break
        end
        w:update(DT)
    end
    local lock = rec.last["boss:lockdown"]
    check(lock ~= nil and #lock.cells == 5, "the shade chains a row or column")
    for _, index in ipairs(lock.cells) do
        check(combat:is_locked(index) and combat.chains[index] > 0, "chained cell " .. index)
    end
    local chained = nil
    for _, index in ipairs(lock.cells) do
        chained = chained or w.inventory:get("grid", index)
    end
    check(chained ~= nil, "the chained line holds a weapon")
    local fired = false
    local EventBus = require("core.EventBus")
    EventBus.subscribe("combat:fired", function(p) fired = fired or p.item == chained end, { owner = rec, priority = -300 })
    for _ = 1, math.floor(DATA.lock_time * 0.8 / DT) do
        boss.hp = boss.max_hp           -- 보스를 살려 둔다
        w:update(DT)
    end
    check(not fired, "a chained weapon does not fire")
    for _ = 1, math.floor(DATA.lock_time / DT) do
        if rec.seen["boss:lockdown_ended"] > 0 then
            break
        end
        w:update(DT)
    end
    check(rec.seen["boss:lockdown_ended"] > 0, "chains fall off after lock_time")
    -- 균열 아이기스 (65%)
    boss.hp = boss.max_hp * (DATA.thresholds[1] - 0.01)
    w:update(DT)
    check(boss.aegis ~= nil and rec.seen["boss:aegis_raised"] == 1 and near(boss.damage_taken_mult, 1 - DATA.reduction),
        "the Rift Aegis rises below 65%")
    combat:set_overclock(false)
    local before = boss.hp
    combat:damage_monster(boss, 100, nil, true, "fire")
    check(near(before - boss.hp, 100 * (1 - (boss.defense or 0)) * (1 - DATA.reduction), 1e-6), "the aegis cuts damage by 75%")
    combat:damage_monster(boss, boss.aegis.need * 8, nil, true, "fire")
    check(boss.aegis ~= nil and boss.aegis.dealt == 0, "without the overclock the aegis does not break")
    boss.hp = boss.max_hp * 0.5
    combat:set_overclock(true)
    for _ = 1, 200 do
        if boss.aegis == nil then
            break
        end
        combat:damage_monster(boss, boss.aegis.need / 20, nil, true, "fire")
    end
    check(boss.aegis == nil and rec.seen["boss:aegis_broken"] == 1 and boss.groggy_time > 0 and near(boss.damage_taken_mult, DATA.groggy_mult),
        "overclock damage shatters the aegis into a stagger")
    local x = boss.x
    w:update(DT)
    check(boss.x == x, "a staggered boss stands still")
    for _ = 1, math.ceil(DATA.groggy_time / DT) + 2 do
        w:update(DT)
    end
    check(rec.seen["boss:groggy_ended"] == 1 and boss.damage_taken_mult == 1, "the stagger ends")
    boss.hp = boss.max_hp * (DATA.thresholds[2] - 0.01)
    w:update(DT)
    check(boss.aegis ~= nil and rec.seen["boss:aegis_raised"] == 2, "a second aegis at 30%")
    w:destroy()
    rec.stop()
end

-- 보스를 쓰러뜨리고 밤을 끝까지 → 승리 엔딩
local function finish_campaign(lit_level)
    local K = kit()
    local check, campaign, DT = K.check, K.campaign, K.DT
    local Endings = require("systems.Endings")
    local w = campaign()
    K.fill_slots(w, lit_level)
    local boss = final_night(w)
    boss.max_hp, boss.hp, boss.hp_floor = 10, 1, nil
    w.combat:damage_monster(boss, 50, nil, true, "fire")
    check(boss.dead and w.master_trace.final ~= nil and w.master_trace.final.slain, "the final boss is slain")
    for _ = 1, 30 * 120 do
        if w.phase ~= "night" or w.result ~= nil then
            break
        end
        w:update(DT)
    end
    check(w.result == "victory", "surviving the final night wins the campaign (" .. tostring(w.result) .. ")")
    local ending = Endings.decide(w)
    w:destroy()
    return ending
end

local function check_endings()
    local K = kit()
    local check, near, campaign, ready = K.check, K.near, K.campaign, K.ready
    local Progress = require("systems.Progress")
    local RunSave = require("systems.RunSave")
    local Workshop = require("systems.Workshop")
    check(finish_campaign(5) == "true_dawn", "4/4 lit seals at the kill give the true ending")
    check(finish_campaign(4) == "new_gatekeeper", "an unlit array gives the hidden ending")
    Progress.use_memory_only()
    check(Progress.record_ending("true_dawn") and Progress.has_medal("true_dawn") and not Progress.record_ending("true_dawn")
        and not Progress.record_ending("new_gatekeeper"), "the true ending records its medal once")
    Progress.use_memory_only()
    -- 저장/이어하기: 수기 · Pity · 결과 · 점화 기록 · 유물 인장 보존
    local w = campaign()
    local trace = w.master_trace
    K.fill_slots(w, 5)
    trace.journals, trace.dry_days, trace.offered_today, trace.final = 3, 2, true, { slain = true, lit = 4 }
    trace:_sync(true)
    local sealed = ready("rune_tablet", 0, w, 13)
    sealed.silver_seal, sealed.revealed.seal = { x = 0.1, y = -0.2, claimed = true }, true
    local data = RunSave.deserialize(RunSave.serialize(RunSave.snapshot(w)))
    w:destroy()
    check(data ~= nil and data.version == RunSave.VERSION, "campaign snapshot serializes")
    local back = RunSave.resume(data, Workshop)
    local t = back.master_trace
    local relic = back.inventory:get("grid", 13)
    check(t ~= nil and t.journals == 3 and t.dry_days == 2 and t.offered_today and t.final.slain and t.final.lit == 4
        and t:lit_count() == 4 and t.lit[7] and relic.silver_seal.claimed and relic.revealed.seal and near(relic.silver_seal.y, -0.2),
        "save/continue keeps the campaign state")
    check(require("systems.Endings").decide(back) == "true_dawn", "the restored campaign keeps its ending")
    back:destroy()
end

function SmokeMasterTraceBoss.run()
    check_boss()
    check_endings()
end

return SmokeMasterTraceBoss
