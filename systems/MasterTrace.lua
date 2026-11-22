-- systems/MasterTrace.lua
-- 5단계 진엔딩 캠페인 '스승의 흔적' 규칙 (data/master_trace.lua). Workshop 이 master_trace 계약에서만 만든다 (workshop.master_trace).
--   은빛 인장 · 수기 : 다음 수기가 열린 날부터 손님 유물에 UV 로만 보이는 스승의 은빛 인장(item.silver_seal = 표식 위치)을 숨긴다
--                      ("clues" 난수 스트림, chance · pity_days 일 동안 못 숨겼으면 반드시). 결함이 아니라 값은 그대로다.
--                      인장은 systems/Scanner 가 렌즈로 찾아 appraisal:seal_revealed 를 낸다. 찾은 인장이 있는 유물을 가지게 되면
--                      (매입 · 이미 산 유물을 다시 훑어 찾음) 수기가 1편부터 순서대로 열린다 → master:journal_unlocked
--   봉인 공명 슬롯   : 진열장 4칸에 계열이 하나씩. 그 계열 +min_level 이상 · 내구도 > 0% 유물이 놓이면 점화 (지금 진열장으로 계산).
--                      슬롯에 놓인 유물은 밤 마모 x wear_mult (systems/Wear 가 wear_mult(index) 로 묻는다, +10 불멸은 면역).
--                      플레이어가 옮기거나 밤에 완전 마모되면 점화 변화를 master:seal_lit / seal_dimmed (+ 4칸 완성 master:array_complete)
--   최종 보스        : 계약 마지막 날 밤 월말 대보스 대신 boss_master (final_rules → systems/Combat → WaveSpawner).
--                      쓰러뜨린 순간의 점화 수를 final 에 기록 — 승리 엔딩은 4/4 면 true_dawn, 아니면 new_gatekeeper (ending)
-- 저장(systems/RunSave): journals · dry_days · offered_today · final · lit (평범한 값). 그리기 금지.

local Class = require("lib.classic")
local EventBus = require("core.EventBus")
local RNG = require("core.RNG")
local Grid = require("systems.Grid")
local TRACE = require("data.master_trace")
local LAYOUT = require("data.layout")

local MasterTrace = Class:extend()

local CLUES = TRACE.clues
local RESONANCE = TRACE.resonance
local BENCH = LAYOUT.day.bench_slot

-- 슬롯 목록 { index, row, col, archetype, order } (진열장 칸 번호 순서는 data 순서 그대로)
MasterTrace.SLOTS = {}
local SLOT_AT = {}
for order, spec in ipairs(RESONANCE.slots) do
    local slot = { index = Grid.to_index(spec.row, spec.col), row = spec.row, col = spec.col, archetype = spec.archetype, order = order }
    MasterTrace.SLOTS[order] = slot
    SLOT_AT[slot.index] = slot
end
MasterTrace.CENTER = Grid.to_index(RESONANCE.center.row, RESONANCE.center.col)
MasterTrace.JOURNALS = #TRACE.journals

-- 그 칸의 봉인 공명 슬롯 (없으면 nil)
function MasterTrace.slot_at(index)
    return SLOT_AT[index]
end

function MasterTrace:new(workshop)
    self._workshop = workshop
    self.journals = 0           -- 연 수기 수 (0 ~ JOURNALS)
    self.dry_days = 0           -- 인장이 숨을 수 있었는데 한 번도 숨지 않은 날 수 (Pity)
    self.offered_today = false  -- 오늘 손님 유물에 인장을 숨겼는지
    self.final = nil            -- 최종 보스 결과 { slain = bool, lit = 점화 수 }
    self.lit = {}               -- 지난번에 본 점화 칸 (칸 번호 → true) — 변화 연출 이벤트용
    local function on(event, handler, priority)
        EventBus.subscribe(event, handler, { owner = self, priority = priority or -50 })
    end
    on("appraisal:customer_arrived", function(p) self:_hide_seal(p.item) end, 60)   -- 다른 구독자가 보기 전에 숨긴다
    on("appraisal:seal_revealed", function(p) self:_claim(p.item, p.x, p.y) end)
    on("appraisal:item_bought", function(p) self:_claim(p.item, p.x, p.y) end)
    on("phase:day_started", function(p) self:_morning(p.day) end)
    on("phase:night_started", function() self:_sync(true) end)
    on("inventory:item_moved", function() self:_sync(false) end)
    on("combat:item_worn_out", function() self:_sync(false) end)
    on("combat:monster_killed", function(p) self:_boss_done(p.monster, true) end)
    on("combat:wall_hit", function(p) self:_boss_done(p.monster, false) end)
end

function MasterTrace:destroy()
    EventBus.unsubscribe_owner(self)
end

-- ── 은빛 인장 · 수기 ──────────────────────────────────────────
-- 다음 수기(journals + 1)의 인장이 그 일차에 숨을 수 있는지
function MasterTrace:_seal_open(day)
    local entry = TRACE.journals[self.journals + 1]
    return entry ~= nil and day >= entry.opens
end

function MasterTrace:_hide_seal(item)
    if item == nil or item.owned or item.silver_seal ~= nil or not self:_seal_open(self._workshop.day) then
        return
    end
    local rng = RNG.stream("clues")
    if self.dry_days < CLUES.pity_days and not rng:chance(CLUES.chance) then
        return
    end
    local range, mark = CLUES.mark_range, item.flaw_mark or { x = 0, y = 0 }
    local x, y = 0, 0
    for _ = 1, 8 do                     -- 결함 표식과 겹치지 않게 (몇 번 다시 뽑는다)
        x, y = rng:float(-range, range), rng:float(-range, range)
        if item.flaw == nil or (x - mark.x) ^ 2 + (y - mark.y) ^ 2 >= CLUES.mark_gap ^ 2 then
            break
        end
    end
    item.silver_seal = { x = x, y = y }
    item.revealed.seal = false
    self.offered_today, self.dry_days = true, 0
end

-- 찾은(UV) 인장이 있는 내 유물이면 다음 수기를 연다
function MasterTrace:_claim(item, x, y)
    local seal = item and item.silver_seal
    if seal == nil or seal.claimed or not item.owned or not item.revealed.seal or self.journals >= MasterTrace.JOURNALS then
        return
    end
    seal.claimed = true
    self.journals = self.journals + 1
    EventBus.emit("master:journal_unlocked", { index = self.journals, total = MasterTrace.JOURNALS, item = item,
        x = x or BENCH.x + BENCH.w / 2, y = y or BENCH.y + BENCH.h / 2 })
end

function MasterTrace:_morning(day)
    if day > 1 and self:_seal_open(day - 1) and not self.offered_today then
        self.dry_days = self.dry_days + 1
    end
    self.offered_today = false
    self:_sync(true)
end

function MasterTrace:journal_count()
    return self.journals
end

-- ── 봉인 공명 슬롯 ────────────────────────────────────────────
function MasterTrace:is_lit(index)
    local slot = SLOT_AT[index]
    local item = slot and self._workshop.inventory:get("grid", index)
    return item ~= nil and item.proto.archetype == slot.archetype and (item.level or 0) >= RESONANCE.min_level
        and not item:is_worn_out()
end

function MasterTrace:lit_count()
    local count = 0
    for _, slot in ipairs(MasterTrace.SLOTS) do
        count = count + (self:is_lit(slot.index) and 1 or 0)
    end
    return count
end

function MasterTrace:is_complete()
    return self:lit_count() >= #MasterTrace.SLOTS
end

-- 그 칸에 놓인 유물의 밤 마모 배율 (슬롯이면 wear_mult)
function MasterTrace:wear_mult(index)
    return SLOT_AT[index] and RESONANCE.wear_mult or 1
end

-- 점화 상태를 다시 보고 바뀐 칸을 알린다 (quiet = 알리지 않고 맞추기만)
function MasterTrace:_sync(quiet)
    local was_complete, changed = true, {}
    for _, slot in ipairs(MasterTrace.SLOTS) do
        was_complete = was_complete and self.lit[slot.index] == true
        local now = self:is_lit(slot.index)
        if now ~= (self.lit[slot.index] == true) then
            changed[#changed + 1] = { slot = slot, lit = now }
        end
        self.lit[slot.index] = now or nil
    end
    if quiet then
        return
    end
    for _, change in ipairs(changed) do
        local x, y = Grid.cell_center(change.slot.index)
        EventBus.emit(change.lit and "master:seal_lit" or "master:seal_dimmed", {
            index = change.slot.index, archetype = change.slot.archetype, lit = self:lit_count(), x = x, y = y,
        })
    end
    if not was_complete and self:is_complete() then
        EventBus.emit("master:array_complete", { day = self._workshop.day })
    end
end

-- ── 최종 보스 · 엔딩 ──────────────────────────────────────────
-- 마지막 날 밤의 우두머리 (systems/Combat 이 WaveSpawner 일정으로 넘긴다)
function MasterTrace:final_rules()
    local final = TRACE.final
    return { day = self._workshop.max_days, type = final.type, at = final.at, hp_mult = final.hp_mult }
end

function MasterTrace:_boss_done(monster, slain)
    if monster ~= nil and monster.spec.final and self.final == nil then
        self.final = { slain = slain, lit = self:lit_count() }
        EventBus.emit("master:final_resolved", { slain = slain, lit = self.final.lit, total = #MasterTrace.SLOTS })
    end
end

-- 승리 엔딩 id (systems/Endings.decide)
function MasterTrace:ending()
    local final = self.final
    if final ~= nil and final.slain and final.lit >= #MasterTrace.SLOTS then
        return TRACE.endings.sealed
    end
    return TRACE.endings.failed
end

-- HUD · 도감 · 수기 창이 보는 요약
function MasterTrace:status()
    return { journals = self.journals, journal_total = MasterTrace.JOURNALS, lit = self:lit_count(), slots = #MasterTrace.SLOTS,
        final = self.final }
end

return MasterTrace
