-- tools/BalanceSim.lua
-- 헤드리스 밸런스 시뮬레이션: 난이도마다 N번(기본 100) 휴리스틱 AI(tools/BalanceAI)로 런을 끝까지 돌리고 tools/BalanceReport 로
-- 기록·보고한다 (승리/파산/패배·소프트락 · 엔딩 분포 · 강화 템포 · 연마석 · 마모 · 방벽 피해 몫 · 결계 유지비 · 일차별 골드 …).
--   lovec . --balance-sim [runs] [difficulty]   (main.lua 의 스모크 훅 → SmokeTest.install_if_requested 가 넘겨준다)
--   difficulty 를 주면 그 난이도만 돌린다 (5단계 진엔딩 캠페인 master_trace 포함). 여러 난이도를 돌리면 끝에 전체 엔딩 분포를 더한다.
-- 실제 세이브는 건드리지 않는다 (진행도·메타·설정 메모리 전용, 런마다 메타 진행도 초기화 = 영구 강화 없는 첫 플레이 기준).
-- 소프트락: 아침에 골드 < SOFTLOCK_GOLD 이고 보유 유물이 하나도 없어 더 이상 벌 방법이 없는 상태.
-- 이 모듈은 게임을 켤 때마다 require 된다 (SmokeTest) — 게임 모듈은 함수 안에서만 require 한다.

local BalanceSim = {}

local FLAG = "--balance-sim"
local DEFAULT_RUNS = 100
local SEED_BASE = 9000
local NIGHT_DT = 1 / 20
local MAX_NIGHT_STEPS = 2000
local SOFTLOCK_GOLD = 30
local TRACE = os.getenv("BALANCE_TRACE") ~= nil

local function log(fmt, ...)
    print("[BALANCE] " .. string.format(fmt, ...))
    io.stdout:flush()
end

local function owned_count(w)
    local count = 0
    for _, area in ipairs({ "grid", "storage", "bench", "furnace", "hero" }) do
        for index = 1, w.inventory:size(area) do
            local item = w.inventory:get(area, index)
            if item ~= nil and item.owned then
                count = count + 1
            end
        end
    end
    return count
end

-- BALANCE_TRACE=1: 날마다 방벽·골드·진열 요약
local function trace_day(w, seed)
    local cursed, weapons = 0, 0
    for index = 1, w.inventory:size("grid") do
        local item = w.inventory:get("grid", index)
        cursed = cursed + ((item and (item.flaw == "curse" or item.proto.archetype == "curse")) and 1 or 0)
        weapons = weapons + ((item and item:is_weapon()) and 1 or 0)
    end
    log("seed %d day %d hp %d/%d gold %d weapons %d cursed %d%s", seed, w.day, w.hp, w.max_hp, w.gold, weapons, cursed,
        require("tools.BalanceTrace").describe(w))
end

function BalanceSim.run_one(difficulty, seed)
    local RNG = require("core.RNG")
    local Workshop = require("systems.Workshop")
    local BalanceAI = require("tools.BalanceAI")
    local BalanceReport = require("tools.BalanceReport")
    require("systems.MetaProgression").use_memory_only()
    RNG.set_seed(seed)
    local w = Workshop({ difficulty = difficulty, starter = true })
    local record = BalanceReport.new_record()
    BalanceReport.track(w, record)
    w:begin()
    for _ = 1, w.max_days * 4 do
        if w.result ~= nil then
            break
        end
        if w.phase == "day" then
            record.gold[w.day] = w.gold
            if w.gold < SOFTLOCK_GOLD and owned_count(w) == 0 then
                record.softlock = true
            end
            BalanceAI.play_day(w, record)
            if TRACE then
                trace_day(w, seed)
            end
            assert(w:start_night(), "BalanceSim: AI could not start the night on day " .. w.day)
        elseif w.phase == "night" then
            for _ = 1, MAX_NIGHT_STEPS do
                BalanceAI.night_tick(w)
                w:update(NIGHT_DT)
                if w.phase ~= "night" or w.result ~= nil then
                    break
                end
            end
        elseif w.phase == "shop" then
            BalanceAI.shop(w)
            w:close_shop()
        end
    end
    BalanceReport.finish(w, record)
    w:destroy()
    return record
end

function BalanceSim.run(runs, only)
    local DIFFICULTIES = require("data.difficulties")
    local BalanceReport = require("tools.BalanceReport")
    local started = love.timer.getTime()
    local all, covered = {}, 0
    for _, difficulty in ipairs(DIFFICULTIES.order) do
        if only == nil or only == difficulty then
            local records = {}
            for i = 1, runs do
                records[i] = BalanceSim.run_one(difficulty, SEED_BASE + i)
                all[#all + 1] = records[i]
            end
            BalanceReport.summarize(difficulty, records)
            covered = covered + 1
        end
    end
    if covered > 1 then
        BalanceReport.pooled(all)
    end
    log("done in %.1fs", love.timer.getTime() - started)
end

-- 돌릴 횟수와 (있으면) 난이도 하나
local function runs_from(raw_args)
    for i, value in ipairs(raw_args or {}) do
        if value == FLAG then
            local runs = tonumber(raw_args[i + 1])
            local only = runs and raw_args[i + 2] or raw_args[i + 1]
            if only ~= nil and (only:sub(1, 2) == "--" or require("data.difficulties").modes[only] == nil) then
                only = nil
            end
            return runs or DEFAULT_RUNS, only
        end
    end
    return nil
end

-- SmokeTest.install_if_requested 가 플래그를 보면 호출한다. 게임 대신 시뮬레이션만 돌리고 종료한다.
function BalanceSim.install_if_requested(raw_args)
    local runs, only = runs_from(raw_args)
    if runs == nil then
        return false
    end
    require("systems.Progress").use_memory_only()
    require("systems.MetaProgression").use_memory_only()
    local Settings = require("systems.Settings")
    Settings.use_memory_only()
    Settings.set("mute", true)
    love.run = function()
        local ok, err = xpcall(BalanceSim.run, debug.traceback, runs, only)
        if not ok then
            print("[BALANCE] FAIL: " .. tostring(err))
        end
        return function()
            return ok and 0 or 1
        end
    end
    return true
end

return BalanceSim
