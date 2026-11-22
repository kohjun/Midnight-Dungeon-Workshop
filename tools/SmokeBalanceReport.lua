-- tools/SmokeBalanceReport.lua
-- 밸런스 보고서(tools/BalanceReport · BalanceReportText) 헤드리스 검사 (SmokeTest 가 SmokeWear 다음에 실행).
--   가짜 런 기록: 방벽 피해 몫(저주 외 모든 원인 = 몬스터 쪽, ≥ 65% OK · 아니면 LOW) · 패배의 마지막 일격 원인 ·
--   강화 템포(생존 하루당 1.0~2.5 = OK, 밖이면 LOW / HIGH · 정비/성장 합계 · 없는 필드 = 0) · 진열 무기 밤당 마모와 "~N 밤" ·
--   엔딩 분포(승리 대비 %, 한 엔딩 ≥ 90% = SKEWED, 처음 보는 엔딩 id 도 센다) · 보고 줄(엔딩 판정 상태 · 저주 히스토그램 ·
--   연마석 · 결계 유지비 · 아침 골드 · 전체 엔딩 분포)을 capture 로 받아 확인한다.
--   실제 공방 하나: track → 저주 피해 · 연마석 출처/소비 · 밤 마모 12%p · 마지막 일격 → finish(구독 해제 · 결과 기록).

local SmokeBalanceReport = {}

local function check(condition, message)
    if not condition then
        error("SmokeBalanceReport: " .. message, 2)
    end
end

local function near(a, b)
    return a ~= nil and math.abs(a - b) < 1e-6
end

-- 가짜 런 기록: BalanceReport.new_record() 위에 fields 를 덮어쓴다 (기본 = 60일 승리)
local function fake(fields)
    local record = require("tools.BalanceReport").new_record()
    record.result, record.day, record.days_survived, record.kills, record.final_gold, record.final_stones =
        "victory", 60, 60, 900, 70000, 2
    for key, value in pairs(fields) do
        record[key] = value
    end
    return record
end

local function has_line(lines, needle)
    for _, line in ipairs(lines) do
        if line:find(needle, 1, true) then
            return true
        end
    end
    return false
end

local function check_wall(Report)
    local low = Report.wall_share({ fake({ damage = { curse = 70, monster = 30 } }) })
    check(near(low.share, 0.3) and low.flag == "LOW", "curse-heavy wall damage is flagged LOW")
    local mixed = Report.wall_share({
        fake({ damage = { monster = 80, reflect = 5, curse = 15 }, result = "defeat", killing_blow = "monster" }),
        fake({ damage = { curse = 20 }, result = "defeat", killing_blow = "curse" }),
        fake({ damage = { midboss = 100 }, killing_blow = "monster" }),        -- 승리 런은 마지막 일격으로 세지 않는다
    })
    check(mixed.monster == 185 and mixed.curse == 35 and near(mixed.share, 185 / 220) and mixed.flag == "OK",
        "every non-curse cause (monster, reflect, new ones) counts as monster-side")
    check(mixed.blows.monster == 1 and mixed.blows.curse == 1, "killing blows are counted per cause, defeats only")
    check(Report.wall_share({ fake({}) }).flag == "n/a", "no wall damage at all is n/a")
end

local function check_tempo_and_wear(Report)
    local tempo = Report.forge_tempo({ fake({ forge_ok = 40, forge_fail = 20, forge_maint = 15, forge_grow = 45,
        days_survived = 30 }) })
    check(tempo.attempts == 60 and near(tempo.per_day, 2) and tempo.flag == "OK" and tempo.maint == 15 and tempo.grow == 45,
        "2 attempts per survived day is OK and maintenance/growth are summed")
    check(Report.forge_tempo({ fake({ forge_ok = 250, forge_fail = 50, days_survived = 30 }) }).flag == "HIGH",
        "10 attempts per day is HIGH")
    local legacy = fake({ forge_ok = 5, days_survived = 30 })
    legacy.forge_maint, legacy.forge_grow = nil, nil                    -- 정비/성장을 세지 않는 AI
    local slow = Report.forge_tempo({ legacy })
    check(slow.flag == "LOW" and slow.maint == 0 and slow.grow == 0, "0.17 per day is LOW and missing fields count as 0")
    local wear = Report.wear({ fake({ wear_lost = 120, wear_samples = 10, wear_zeroed = 2 }),
        fake({ wear_lost = 30, wear_samples = 5 }) })
    check(near(wear.per_night, 10) and near(wear.nights, 10) and wear.samples == 15 and wear.zeroed == 2,
        "10%p per weapon-night means a main weapon lasts ~10 nights")
    check(Report.wear({ fake({}) }).per_night == nil, "no weapon-night samples means no wear rate")
end

local function check_endings(Report)
    local runs = {}
    for i = 1, 10 do
        runs[i] = fake({ ending = i == 1 and "relocation" or "monopoly" })
    end
    local skewed = Report.ending_mix(runs)
    check(skewed.wins == 10 and skewed.counts.monopoly == 9 and skewed.top == "monopoly" and skewed.flag == "SKEWED",
        "9 of 10 wins on one ending is SKEWED")
    local mix = Report.ending_mix({ fake({ ending = "relocation" }), fake({ ending = "monopoly" }), fake({ ending = "tycoon" }),
        fake({ result = "defeat", ending = "monopoly" }) })
    check(mix.wins == 3 and mix.flag == "OK" and mix.counts.tycoon == 1 and mix.order[#mix.order] == "tycoon",
        "unknown ending ids are listed after data/endings order and defeats are not wins")
    check(Report.ending_mix({ fake({ result = "defeat" }) }).flag == "n/a", "no wins is n/a")
end

local function check_lines(Report)
    local status = { gold = 90000, need = 60000, base_need = 80000, hp_ratio = 0.8, min_hp_ratio = 0.5, best_level = 8,
        master = true, cursed = 7, cursed_need = 4, abyss_contract = false }
    local runs = {
        fake({ ending = "monopoly", status = status, final_boss_cursed = 7, damage = { curse = 300, monster = 100 },
            forge_ok = 250, forge_fail = 50, stones_in = { drop = 4, shop = 2 }, stones_out = { forge = 5 },
            wear_lost = 50, wear_samples = 5 }),
        fake({ result = "defeat", day = 23, days_survived = 22, killing_blow = "curse", damage = { curse = 100 } }),
    }
    runs[1].paid[10], runs[1].before[10], runs[1].gold[1] = true, 5000, 180
    local lines = Report.capture(function() Report.summarize("broker", runs) end)
    for _, needle in ipairs({
        string.format("── broker (%d days, 2 runs) ──", require("data.difficulties").modes.broker.days),
        "victory 50% · bankrupt 0% · defeat 50%",
        "endings (% of 1 wins): ", "monopoly 1 (100%)", "SKEWED (monopoly >= 90%)",
        "ending status (1 wins): gold/need P25 1.50 · P50 1.50 · P75 1.50 · gold >= need 100% · need P50 60000 (base 80000) · "
            .. "master 100%", "hp ratio P25 0.80", "best level avg +8.0 · >= +7 100%", "5: 0 · 6+: 1",
        "forge tempo: 150.0 attempts/run · 3.66 per survived day · HIGH (target 1.0-2.5)",
        "stones per run: gained drop 2.0 · shop 1.0 (total 3.0) · spent forge 2.5", "lose 10.0%/night", "lasts ~10.0 nights",
        "losses by day: defeat M03: 1", "killing blow (defeats): curse 1", "avg wall damage per run by cause: curse 200.0 · monster 50.0",
        "wall damage share: monster-side 50.0/run (20%) · curse 200.0/run (80%) · LOW (target monster-side >= 65%)",
        "upkeep D10", "pass 100% (1/1) · gold before upkeep P10 5000", "avg morning gold: D1 180",
    }) do
        check(has_line(lines, needle), "report line missing: " .. needle)
    end
    check(has_line(Report.capture(function() Report.pooled(runs) end), "pooled endings (% of 1 wins)"), "pooled ending line")
    local lost = Report.capture(function() Report.summarize("apprentice", { runs[2] }) end)
    check(has_line(lost, "endings: no wins") and not has_line(lost, "ending status")
        and has_line(lost, "wear: no display weapon-nights recorded"), "no wins / no wear samples: placeholder lines only")
    check(not pcall(Report.capture, function() error("boom") end), "capture passes errors through")
end

-- 실제 공방: 저주 피해 · 연마석 · 밤 마모 · 마지막 일격이 기록되고, finish 뒤에는 더 세지 않는다
local function check_tracking(Report)
    local Workshop, DayCycle = require("systems.Workshop"), require("systems.DayCycle")
    require("core.RNG").set_seed(4242)
    local w = Workshop({ difficulty = "apprentice" })
    local sword = require("systems.ItemFactory").make_ready("flame_sword", "common", 0)
    w.inventory:place(sword, "grid", 13)
    local record, stones = Report.new_record(), w.tempering_stones
    Report.track(w, record)
    w:begin()
    w:add_stones(3, "drop")
    w:spend_stones(1, "forge")
    w:damage_hp(5, "curse")
    check(w:start_night(), "the test night should start")
    sword.durability = sword.durability - 12                            -- 밤 동안 12%p 닳았다고 치고 새벽을 맞는다
    DayCycle.finish_night(w)
    check(near(record.wear_lost, 12) and record.wear_samples == 1 and record.before[1] == nil,
        "one weapon-night of 12%p wear is recorded at dawn (day 1 collects no upkeep, so no gold-before-upkeep)")
    require("core.EventBus").emit("economy:tribute_paid", { day = 10, amount = 720 })
    check(record.before[10] == w.gold + 720, "gold before upkeep is read at the collection itself (gold after + amount paid)")
    w:damage_hp(w.hp, "monster")
    Report.finish(w, record)
    w:add_stones(1, "drop")                                             -- 구독 해제 뒤: 세지 않는다
    w:destroy()
    check(record.result == "defeat" and record.killing_blow == "monster" and record.damage.curse == 5,
        "the defeat, its killing blow and the curse self-damage are recorded")
    check(record.stones_in.drop == 3 and record.stones_out.forge == 1 and record.final_stones == stones + 2
        and record.days_survived == 1, "stone gains/spends by reason, final stones and days survived are recorded")
end

function SmokeBalanceReport.run(log)
    local Report = require("tools.BalanceReport")
    check_wall(Report)
    check_tempo_and_wear(Report)
    check_endings(Report)
    check_lines(Report)
    check_tracking(Report)
    log("balance report ok (wall share monster-side >= 65%% OK / LOW, killing blows, forge tempo 1.0-2.5/day LOW/OK/HIGH, "
        .. "maintenance/growth, wear %%/night → ~N nights, endings %% of wins + SKEWED >= 90%%, status/cursed/stones/upkeep lines, "
        .. "track → finish)")
end

return SmokeBalanceReport
