-- tools/BalanceReport.lua
-- 밸런스 시뮬레이터(tools/BalanceSim)의 런 기록과 보고서. 게임 이벤트·상태를 읽기만 한다 (난수를 쓰지 않고 게임을 바꾸지 않는다).
--   new_record() → track(w, record)(이벤트 구독, owner = record) → 런 진행 → finish(w, record)(w:destroy() 전에 결과 기록)
--   summarize(difficulty, records) = 난이도별 보고 · pooled(records) = 여러 난이도를 돌렸을 때 모든 승리의 엔딩 분포
--   wall_share · forge_tempo · wear · ending_mix = 순수 계산 (줄 서식은 tools/BalanceReportText),
--   capture(fn) = fn 이 찍은 보고 줄을 화면 대신 배열로 (tools/SmokeBalanceReport 가 가짜 기록으로 검사한다)
-- AI(tools/BalanceAI · BalanceForge)가 record 에 올리는 값: bought · sold · forge_ok · forge_fail · forge_destroyed · restored ·
--   sold_worn · forge_maint(내구도 정비용 강화 시도) · forge_grow(단계를 올리려는 강화 시도). 없는 필드는 0 으로 본다.
-- systems/Endings.status 가 있으면 승리 런의 엔딩 판정 상태(골드/기준 · 방벽 비율 · 최고 단계 · 마스터 …)도 모아 보고한다.

local EventBus = require("core.EventBus")
local DIFFICULTIES = require("data.difficulties")
local ENDINGS = require("data.endings")
local Text = require("tools.BalanceReportText")

local BalanceReport = {}

local add, total, month_of = Text.add, Text.total, Text.month_of

local OBSERVER = -150                       -- 읽기만 하는 구독: 수정자(≥ 0)가 끝난 값을 본다
local SELF_DAMAGE = { curse = true }        -- 방벽 피해 중 자해(저주 유물의 대가). 나머지 원인은 전부 몬스터 쪽

-- 보고서 판정 기준 (게임 수치가 아니라 리밸런스 목표 — 보고 줄에 OK / LOW / HIGH / SKEWED 로 표시)
local TARGETS = {
    monster_share = 0.65,           -- 방벽 피해 중 몬스터 쪽 몫이 이 이상이면 OK, 아니면 LOW
    forge_low = 1.0,                -- 생존 하루당 강화 시도 OK 범위 (밖이면 LOW / HIGH)
    forge_high = 2.5,
    ending_skew = 0.9,              -- 승리 중 한 엔딩이 이 몫 이상이면 SKEWED
    high_level = 7,                 -- 승리 런의 최고 강화 단계가 이 이상인 몫
    cursed_bins = 6,                -- 최종일 보스 처치 때 진열장 저주 유물 수 히스토그램 0 .. 6+
}
BalanceReport.TARGETS = TARGETS

local function log(fmt, ...)
    print("[BALANCE] " .. string.format(fmt, ...))
    io.stdout:flush()
end

local _emit = log                           -- capture() 가 잠시 바꾼다

local function emit(fmt, ...)
    _emit(fmt, ...)
end

-- ── 기록 ────────────────────────────────────────────────────

function BalanceReport.new_record()
    return { gold = {}, before = {}, damage = {}, paid = {}, missed = {}, earned = {}, spent = {}, monthly = {},
        stones_in = {}, stones_out = {}, bought = 0, sold = 0, forge_ok = 0, forge_fail = 0, forge_destroyed = 0,
        restored = 0, sold_worn = 0, forge_maint = 0, forge_grow = 0, worn_out = 0, max_level = 0, midbosses = 0,
        wear_lost = 0, wear_samples = 0, wear_zeroed = 0, crowd_max = 0, crowd_sum = 0, crowd_nights = 0, softlock = false }
end

-- 밤 시작: 진열장 무기 중 닳을 수 있는 것(불멸·이미 0% 제외)의 내구도
local function wear_snapshot(w)
    local list = {}
    for index = 1, w.inventory:size("grid") do
        local item = w.inventory:get("grid", index)
        if item ~= nil and item:is_weapon() and not item:is_immortal() and item.durability > 0 then
            list[#list + 1] = { item = item, start = item.durability }
        end
    end
    return list
end

-- 밤 끝: 아직 진열장에 있는 무기의 마모량. 밤 도중 0% 가 된 무기는 마모가 잘려 속도를 낮춰 보이므로 따로 센다
local function settle_wear(w, record)
    for _, entry in ipairs(record._wear or {}) do
        if w.inventory:locate(entry.item) == "grid" then
            if entry.item.durability > 0 then
                record.wear_lost = record.wear_lost + (entry.start - entry.item.durability)
                record.wear_samples = record.wear_samples + 1
            else
                record.wear_zeroed = record.wear_zeroed + 1
            end
        end
    end
    record._wear = nil
end

function BalanceReport.track(w, record)
    local function on(event, handler)
        EventBus.subscribe(event, handler, { owner = record, priority = OBSERVER })
    end
    on("economy:tribute_paid", function(p)          -- 납부 직전 골드 = 징수 순간 (그날 새벽 수입·의뢰 정산 뒤)
        record.paid[p.day], record.before[p.day] = true, w.gold + p.amount
    end)
    on("economy:tribute_missed", function(p) record.missed[p.day], record.before[p.day] = true, p.gold end)
    on("phase:night_started", function() record._wear = wear_snapshot(w) end)
    require("tools.BalanceTraceReport").track(w, record, on)       -- '스승의 흔적' 캠페인이면 수기 · 최종 보스 기록
    on("phase:night_ended", function()
        settle_wear(w, record)
        local crowd = w.combat.night_spawns or 0         -- 그 밤 레인에 나온 몬스터 (웨이브 · 우두머리 · 소환)
        record.crowd_max, record.crowd_sum = math.max(record.crowd_max, crowd), record.crowd_sum + crowd
        record.crowd_nights = record.crowd_nights + 1
        record.hero_strikes = (record.hero_strikes or 0) + w.combat.hero.strikes       -- 주인공의 근접 타격 수 · 막아 낸 방벽 피해
        record.hero_blocked = (record.hero_blocked or 0) + w.combat.hero.blocked
    end)
    on("economy:gold_changed", function(p)          -- 수입·지출 원인별 합계 + 달별 총수입 (유지비 곡선 보정용)
        add(p.amount > 0 and record.earned or record.spent, p.reason or "?", math.abs(p.amount))
        if p.amount > 0 then
            add(record.monthly, month_of(w.day), p.amount)
        end
    end)
    on("economy:stones_changed", function(p)        -- 연마석 출처(drop · shop · quest …)와 소비(forge)
        add(p.amount > 0 and record.stones_in or record.stones_out, p.reason or "?", math.abs(p.amount))
    end)
    on("combat:item_worn_out", function() record.worn_out = record.worn_out + 1 end)
    on("forge:succeeded", function(p) record.max_level = math.max(record.max_level, p.level) end)
    on("combat:midboss_slain", function() record.midbosses = record.midbosses + 1 end)
    on("combat:hero_strike", function(p) record.hero_damage = (record.hero_damage or 0) + p.damage end)
    on("workshop:damaged", function(p)
        add(record.damage, p.reason or "?", p.amount)
        if p.hp <= 0 then                           -- 패배를 확정한 마지막 일격
            record.killing_blow = p.reason or "?"
        end
    end)
end

-- 숫자·참거짓·문자열 필드만 복사 (공방·유물 참조를 붙잡지 않는다)
local function plain(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        local kind = type(value)
        if kind == "number" or kind == "boolean" or kind == "string" then
            copy[key] = value
        end
    end
    return copy
end

-- w:destroy() 전에 부른다: 구독 해제 + 결과 · 엔딩 · (systems/Endings.status 가 있으면) 엔딩 판정 상태
function BalanceReport.finish(w, record)
    EventBus.unsubscribe_owner(record)
    record._wear = nil
    record.result = w.result or "unfinished"
    record.day, record.days_survived, record.kills = w.day, w.stats.days_survived, w.stats.kills
    record.final_gold, record.final_stones = w.gold, w.tempering_stones
    record.final_boss_cursed = w.stats.final_boss_cursed            -- 최종일 대보스를 못 잡은 승리면 nil (0 과 구별)
    record.final_boss_share = w.stats.final_boss_share
    record.trace = w.master_trace and plain(w.master_trace:status()) or nil     -- '스승의 흔적': 수기 · 점화 · 최종 보스
    if w.result == "victory" then
        local Endings = require("systems.Endings")
        record.ending = Endings.decide(w)
        if Endings.status then
            record.status = plain(Endings.status(w))
        end
    end
    return record
end

-- ── 순수 계산 ────────────────────────────────────────────────

-- 방벽 피해: 몬스터 쪽(자해가 아닌 모든 원인 — monster · reflect · boss …) vs 저주 자해, 몬스터 쪽 몫과 판정,
-- 패배의 마지막 일격 원인별 수
function BalanceReport.wall_share(records)
    local monster, curse, blows = 0, 0, {}
    for _, r in ipairs(records) do
        for reason, amount in pairs(r.damage or {}) do
            if SELF_DAMAGE[reason] then
                curse = curse + amount
            else
                monster = monster + amount
            end
        end
        if r.result == "defeat" then
            add(blows, r.killing_blow or "?", 1)
        end
    end
    local all = monster + curse
    local share = all > 0 and monster / all or nil
    return { monster = monster, curse = curse, total = all, share = share, blows = blows, target = TARGETS.monster_share,
        flag = share == nil and "n/a" or share >= TARGETS.monster_share and "OK" or "LOW" }
end

-- 강화 템포: 시도(성공 + 실패) · 생존 하루당 시도와 판정 · 정비/성장 시도 (AI 가 나눠 센 경우)
function BalanceReport.forge_tempo(records)
    local attempts, days = total(records, "forge_ok") + total(records, "forge_fail"), total(records, "days_survived")
    local per_day = days > 0 and attempts / days or 0
    local low, high = TARGETS.forge_low, TARGETS.forge_high
    return { attempts = attempts, days = days, per_day = per_day, maint = total(records, "forge_maint"),
        grow = total(records, "forge_grow"), capped = total(records, "forge_capped"), low = low, high = high,
        flag = per_day < low and "LOW" or per_day > high and "HIGH" or "OK" }
end

-- 진열 무기 하나가 밤 한 번에 잃는 내구도(%p) 평균과 그 속도로 100% → 0% 까지 버티는 밤 수 (표본이 없으면 nil)
function BalanceReport.wear(records)
    local samples = total(records, "wear_samples")
    local per_night = samples > 0 and total(records, "wear_lost") / samples or nil
    return { per_night = per_night, samples = samples, zeroed = total(records, "wear_zeroed"),
        nights = per_night ~= nil and per_night > 0 and 100 / per_night or nil }
end

-- 승리의 엔딩 분포: data/endings.lua 의 order 순서 + 그 밖에 나온 엔딩 id. 한 엔딩이 ending_skew 이상이면 SKEWED
function BalanceReport.ending_mix(records)
    local counts, order, wins, top = {}, {}, 0, nil
    for _, id in ipairs(ENDINGS.order) do
        counts[id], order[#order + 1] = 0, id
    end
    for _, r in ipairs(records) do
        if r.result == "victory" then
            local id = r.ending or "?"
            if counts[id] == nil then
                counts[id], order[#order + 1] = 0, id
            end
            counts[id], wins = counts[id] + 1, wins + 1
        end
    end
    for _, id in ipairs(order) do
        top = (top == nil or counts[id] > counts[top]) and id or top
    end
    local skewed = wins > 0 and counts[top] / wins >= TARGETS.ending_skew
    return { wins = wins, counts = counts, order = order, top = top, skew = TARGETS.ending_skew,
        flag = wins == 0 and "n/a" or skewed and "SKEWED" or "OK" }
end

-- ── 보고 ─────────────────────────────────────────────────────

function BalanceReport.summarize(difficulty, records)
    local mode = DIFFICULTIES.modes[difficulty]
    if #records == 0 then
        return
    end
    local wins = {}
    for _, r in ipairs(records) do
        if r.result == "victory" then
            wins[#wins + 1] = r
        end
    end
    Text.outcome(emit, difficulty, mode, records)
    Text.endings(emit, "endings", BalanceReport.ending_mix(records))
    if records[1].trace ~= nil then
        require("tools.BalanceTraceReport").emit(emit, records)
    elseif #wins > 0 then                   -- 상권 독점 · 심연 판정 재료 (캠페인에는 해당 없음)
        Text.status(emit, wins, TARGETS.high_level)
        Text.cursed(emit, wins, TARGETS.cursed_bins, ENDINGS.abyss)
    end
    Text.forge(emit, records, BalanceReport.forge_tempo(records), BalanceReport.wear(records))
    Text.crowd(emit, records)
    require("tools.BalanceHero").report(emit, records)
    Text.wall(emit, records, BalanceReport.wall_share(records))
    Text.economy(emit, mode, records)
end

-- 여러 난이도를 돌렸을 때: 모든 승리를 합친 엔딩 분포
function BalanceReport.pooled(records)
    emit("── all difficulties (%d runs) ──", #records)
    Text.endings(emit, "pooled endings", BalanceReport.ending_mix(records))
end

-- fn 이 찍는 보고 줄을 화면 대신 배열로 모아 돌려준다
function BalanceReport.capture(fn)
    local lines = {}
    _emit = function(fmt, ...)
        lines[#lines + 1] = string.format(fmt, ...)
    end
    local ok, err = pcall(fn)
    _emit = log
    if not ok then
        error(err, 0)
    end
    return lines
end

return BalanceReport
