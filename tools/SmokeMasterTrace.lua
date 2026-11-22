-- tools/SmokeMasterTrace.lua
-- '스승의 흔적' 캠페인 규칙 헤드리스 검사 (SmokeTest 가 SmokeCollection 다음에 실행 — 화면은 SmokeTrace* 가 본다):
--   ① 해금: 악몽 미클리어 = '???' 봉인 · 악몽 클리어 = 영구 해금 → 캠페인 공방(60일 · master_trace 하위 시스템 · 간섭 단계)
--   ② 은빛 인장: 확률 · Pity(인장 없는 날이 pity_days 면 다음 손님에 반드시) · 다음 수기가 열리기 전엔 안 숨음 · UV 렌즈로만 발견
--      (주문서 X) · 값 영향 없음 · 매입하면 수기 1~6편이 순서대로 · 6편 뒤엔 더 없음
--   ③ 봉인 공명 슬롯: 계열 +5 · 내구도 > 0% 에만 점화 (+4 · 다른 계열 · 0% = 소등) · 점화/소등/완성 이벤트 · 슬롯 마모 x1.5 · +10 면역
--   ④ 60일차 밤: 월말 보스 대신 boss_master · 행/열 룬 사슬(그 줄 무기 사격 정지 → 시간이 지나면 풀림) ·
--      65% 균열 아이기스(피해 x0.25, 과부하 없이는 안 깨짐 → 과부하로 파훼 → 그로기 멈춤 · 피해 x1.5) · 30% 두 번째 아이기스
--   ⑤ 엔딩: 4/4 점화 상태로 보스 처치 = true_dawn(진엔딩 훈장 1회) · 그 밖 = new_gatekeeper · 저장/이어하기로 캠페인 상태 보존

local SmokeMasterTrace = {}

local DT = 1 / 30

local function check(condition, message)
    if not condition then
        error("SmokeMasterTrace: " .. message, 2)
    end
end

local function near(a, b, eps)
    return math.abs(a - b) <= (eps or 1e-6)
end

-- 이벤트 기록기: seen[이름] = 발행 횟수, last[이름] = 마지막 payload
local function recorder(names)
    local EventBus = require("core.EventBus")
    local rec = { seen = {}, last = {} }
    for _, name in ipairs(names) do
        rec.seen[name] = 0
        EventBus.subscribe(name, function(p)
            rec.seen[name], rec.last[name] = rec.seen[name] + 1, p
        end, { owner = rec, priority = -300 })
    end
    function rec.stop()
        EventBus.unsubscribe_owner(rec)
    end
    return rec
end

local function campaign(options)
    local Workshop = require("systems.Workshop")
    options = options or {}
    options.difficulty = "master_trace"
    return Workshop(options)
end

local function ready(id, level, w, cell)
    local item = require("systems.ItemFactory").make_ready(id, "rare", level)
    if w ~= nil then
        w.inventory:place(item, "grid", cell)
    end
    return item
end

local function check_unlock()
    local Progress = require("systems.Progress")
    Progress.use_memory_only()
    check(Progress.is_veiled("master_trace") and not Progress.is_unlocked("master_trace"), "veiled before a Nightmare clear")
    Progress.mark_cleared("veteran")
    check(Progress.is_veiled("master_trace"), "still veiled after a veteran clear")
    local unlocked = Progress.mark_cleared("abyss")
    check(unlocked[1] == "master_trace" and Progress.is_unlocked("master_trace") and not Progress.is_veiled("master_trace"),
        "a Nightmare clear unveils The Master's Trace")
    Progress.use_memory_only()
    local w = campaign()
    check(w.max_days == 60 and w.master_trace ~= nil and w.final_rules.day == 60 and w:interference() == 1 and w:season() == nil,
        "a 60-day campaign with the master_trace system and month-1 interference")
    w.day = 51
    local mods = w:season_mods()
    check(w:interference() == 6 and mods.monster_hp_mult > 1 and mods.monster_defense > 0 and mods.honest_mult < 1,
        "month 6 interference toughens monsters and forgers")
    w:destroy()
    local broker = require("systems.Workshop")({ difficulty = "broker" })
    check(broker.master_trace == nil and broker.final_rules == nil and broker:interference() == nil, "other contracts have no campaign")
    broker:destroy()
end

-- 손님 유물 하나를 작업대에 (무료 손님)
local function next_customer(w)
    w.customers_left = 3
    for index = 1, w.inventory:size("storage") do       -- 산 유물은 치운다 (보관함이 차면 작업대에 남는다)
        local kept = w.inventory:get("storage", index)
        if kept ~= nil then
            w.inventory:remove(kept)
        end
    end
    local bench = w.appraisal:bench_item()
    if bench ~= nil and bench.owned then
        w.inventory:remove(bench)
    end
    check(w.appraisal:new_customer(), "a customer should arrive")
    return w.appraisal:bench_item()
end

local function seal_point(item)
    local slot = require("data.layout").day.bench_slot
    local seal = item.silver_seal
    return slot.x + slot.w / 2 + seal.x * slot.item_size, slot.y + slot.h / 2 + seal.y * slot.item_size
end

local function check_seals()
    local TRACE = require("data.master_trace")
    local Item = require("entities.Item")
    local rec = recorder({ "appraisal:seal_revealed", "master:journal_unlocked" })
    local w = campaign()
    local trace = w.master_trace
    local hidden = 0
    for _ = 1, 3000 do                                      -- 확률 (Pity 없이)
        local item = Item("flame_sword", {})
        trace.dry_days = 0
        trace:_hide_seal(item)
        hidden = hidden + (item.silver_seal and 1 or 0)
    end
    check(math.abs(hidden / 3000 - TRACE.clues.chance) < 0.03, "seal chance per customer relic: " .. hidden)
    trace.dry_days = TRACE.clues.pity_days
    local item = next_customer(w)
    check(item.silver_seal ~= nil and item.revealed.seal == false and trace.dry_days == 0 and trace.offered_today,
        "pity hides a seal on the next customer relic")
    check(math.abs(item.silver_seal.x) <= TRACE.clues.mark_range and math.abs(item.silver_seal.y) <= TRACE.clues.mark_range,
        "seal mark stays on the relic")
    local price = item:asking_price()
    item.revealed.seal = true
    check(item:asking_price() == price, "a silver seal does not change the price")
    item.revealed.seal = false
    w.scrolls = 1
    check(w.appraisal:use_scroll() and item.revealed.complete and not item.revealed.seal, "an appraisal scroll does not reveal the seal")
    local x, y = seal_point(item)
    w.appraisal:scan(x, y, DT, true)
    check(item.revealed.seal and rec.seen["appraisal:seal_revealed"] == 1, "the UV lens over the mark reveals the seal")
    w.gold = 100000
    check(w.appraisal:buy() and trace.journals == 1 and item.silver_seal.claimed and rec.last["master:journal_unlocked"].index == 1,
        "buying the sealed relic opens journal 1")
    trace.dry_days = 99                                     -- 2편은 8일차부터: 그 전엔 Pity 여도 숨지 않는다
    check(next_customer(w).silver_seal == nil, "no seal before the next journal opens")
    for index = 2, #TRACE.journals do
        w.day = TRACE.journals[index].opens
        trace.dry_days = TRACE.clues.pity_days
        local relic = next_customer(w)
        x, y = seal_point(relic)
        w.appraisal:scan(x, y, DT, true)
        check(w.appraisal:buy() and trace.journals == index and rec.last["master:journal_unlocked"].index == index,
            "journal " .. index .. " opens in order")
    end
    trace.dry_days = 99
    check(next_customer(w).silver_seal == nil and trace:status().journals == 6, "no more seals after the sixth journal")
    w:destroy()
    -- Pity 일수: 인장이 숨을 수 있는데 손님이 없던 날마다 +1 → pity_days 째 아침 다음 손님에 반드시
    w = campaign()
    trace = w.master_trace
    local DayCycle = require("systems.DayCycle")
    for day = 2, 1 + TRACE.clues.pity_days do
        DayCycle.start_next_day(w)
        check(w.day == day and trace.dry_days == day - 1, "a seal-less day adds pity (day " .. day .. ")")
    end
    check(next_customer(w).silver_seal ~= nil, "after pity_days dry days the next relic carries a seal")
    w:destroy()
    rec.stop()
end

local SLOT_ITEMS = { fire = "flame_sword", lightning = "storm_rod", curse = "hex_scythe", gold = "midas_gauntlet" }

-- 슬롯 4칸에 계열 무기 +level 을 놓는다
local function fill_slots(w, level)
    local MasterTrace = require("systems.MasterTrace")
    for _, slot in ipairs(MasterTrace.SLOTS) do
        ready(SLOT_ITEMS[slot.archetype], level, w, slot.index)
    end
end

local function check_resonance()
    local MasterTrace = require("systems.MasterTrace")
    local TRACE = require("data.master_trace")
    local EventBus = require("core.EventBus")
    local rec = recorder({ "master:seal_lit", "master:seal_dimmed", "master:array_complete" })
    local w = campaign()
    local trace = w.master_trace
    check(#MasterTrace.SLOTS == 4 and MasterTrace.slot_at(7).archetype == "fire" and MasterTrace.slot_at(9).archetype == "lightning"
        and MasterTrace.slot_at(17).archetype == "curse" and MasterTrace.slot_at(19).archetype == "gold", "slots at (2,2)(2,4)(4,2)(4,4)")
    local sword = ready("flame_sword", 5, w, 1)
    w.inventory:move("grid", 1, "storage", 1)
    check(w:move_item("storage", 1, "grid", 7) and trace:is_lit(7) and rec.seen["master:seal_lit"] == 1, "fire +5 lights the fire slot")
    sword.level = 4
    check(not trace:is_lit(7), "+4 does not light")
    sword.level = 5
    local rod = ready("storm_rod", 7, w, 2)
    w.inventory:move("grid", 2, "storage", 2)
    check(w:move_item("storage", 2, "grid", 17) and not trace:is_lit(17), "a lightning relic does not light the curse slot")
    w.inventory:remove(rod)
    for _, slot in ipairs(MasterTrace.SLOTS) do
        if slot.index ~= 7 then
            ready(SLOT_ITEMS[slot.archetype], 6, w, 1)
            w.inventory:move("grid", 1, "storage", 1)
            w:move_item("storage", 1, "grid", slot.index)
        end
    end
    check(trace:is_complete() and trace:lit_count() == 4 and rec.seen["master:array_complete"] == 1, "all four slots complete the array")
    sword.durability = 0
    EventBus.emit("combat:item_worn_out", { item = sword, index = 7, x = 0, y = 0 })
    check(not trace:is_lit(7) and trace:lit_count() == 3 and rec.seen["master:seal_dimmed"] == 1, "0% durability dims the slot at once")
    -- 마모: 같은 무기를 슬롯 칸과 보통 칸에 → 슬롯이 wear_mult 배
    local plain, socketed = ready("flame_sword", 5, w, 13), w.inventory:get("grid", 9)
    plain.durability, socketed.durability = 80, 80
    w.combat._wear:update(10, false)
    check(near(80 - socketed.durability, (80 - plain.durability) * socketed:wear_mult() / plain:wear_mult() * TRACE.resonance.wear_mult, 1e-6),
        "slot relics wear x" .. TRACE.resonance.wear_mult)
    local immortal = w.inventory:get("grid", 19)
    immortal.level = 10
    immortal:restore_durability()           -- +10 강화 성공 = 100%
    w.combat._wear:update(10, false)
    check(immortal.durability == 100 and trace:is_lit(19), "+10 immortal relics ignore resonance wear")
    w:destroy()
    rec.stop()
end

-- tools/SmokeMasterTraceBoss 가 함께 쓰는 도구
SmokeMasterTrace.kit = { check = check, near = near, recorder = recorder, campaign = campaign, ready = ready, DT = DT }
function SmokeMasterTrace.kit.fill_slots(w, level)
    return fill_slots(w, level)
end

function SmokeMasterTrace.run(log)
    require("core.RNG").set_seed(6060)
    require("systems.MetaProgression").use_memory_only()
    check_unlock()
    check_seals()
    check_resonance()
    require("tools.SmokeMasterTraceBoss").run()
    require("systems.Progress").use_memory_only()
    log("master trace ok (Nightmare unveils the 5th contract, seals: chance/pity/UV-only/no price/journals 1-6 in order, resonance "
        .. "lit at +5 only/dim at 0%%/x1.5 wear/+10 immune, day-60 boss_master: line chains stop fire, aegis -75%% breaks only "
        .. "with overclock → stagger, endings true_dawn/new_gatekeeper + medal, save/continue)")
end

return SmokeMasterTrace
