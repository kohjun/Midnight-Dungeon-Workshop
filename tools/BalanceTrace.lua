-- tools/BalanceTrace.lua
-- 밸런스 AI(tools/BalanceAI)의 '스승의 흔적' 캠페인 판단 (w.master_trace 가 있을 때만 — 다른 계약에서는 아무것도 바꾸지 않는다).
--   은빛 인장 : UV 스윕으로 찾은 인장 유물은 마진과 상관없이 산다 (수기). 다가오는 결계 유지비의 SEAL_RESERVE 몫은 남긴다
--   봉인 후보 : 계열마다 하나 — 가진 그 계열 유물 중 강화 단계 · 분류(무기 > 증폭기 > 유물) · 값이 가장 높은 것 (저주 대가 유물 제외).
--               후보는 팔거나 밀어내지 않고(keeps) 일반 강화 계획(tools/BalanceForge)도 건드리지 않는다.
--               후보가 없는 계열의 유물은 마진이 모자라도 산다 (wants). 일반 강화는 연마석을 stone_reserve 만큼 남긴다
--   하루 계획(plan_day, BalanceForge 보다 먼저) — 점화(+5)한 유물은 슬롯에서 1.5배로 닳으므로 늦게 켜고 보관함에서 아낀다:
--     ① LIGHT_FROM 전: 후보를 HOLD_LEVEL(+4)까지 하루 GROW_PER_DAY 번 키운다. +4 에서 완전 마모된 후보는 보관함으로 (칸 비우기)
--     ② LIGHT_FROM 부터: 하루 LIGHT_PER_DAY 번 +5 로 올린다 (성공 = 내구도 100%). 이미 +5 인데 남은 밤을 버틸 내구도
--        (남은 밤 × NIGHT_WEAR + FINAL_MARGIN)가 없으면 한 단계 더 (성공 = 100%, 위험). PLACE_FROM 전에는 +5 후보를 보관함에 (닳지 않게)
--     ③ PLACE_FROM 부터: +5 후보를 자기 슬롯에 넣는다 (그 자리 유물과 맞바꾼다)
--   진열       : 일반 유물은 슬롯이 아닌 빈 칸을 먼저 쓴다 (tools/BalanceGrid.open_empty_cell)
--   밤         : 최종 보스의 균열 아이기스가 서 있거나 그로기 동안은 과부하를 켠다. 점화된 슬롯이 있으면 그 밖에는 끈다 (마모 가속)

local BalanceGrid = require("tools.BalanceGrid")

local BalanceTrace = {}

local HOLD_LEVEL = 4
local LIGHT_FROM = 45
local PLACE_FROM = 54
local NIGHT_WEAR = 11           -- 슬롯에 놓인 점화 유물이 하룻밤에 닳는 정도 (%, 과부하 거의 없이)
local FINAL_MARGIN = 6          -- 마지막 밤 아이기스 과부하 몫
local GROW_PER_DAY = 1
local LIGHT_PER_DAY = 2
local STONE_RESERVE = { grow = 3, light = 8 }
local SEAL_RESERVE = 0.5
local AREAS = { "grid", "storage", "bench", "furnace", "hero" }     -- 주인공이 든 무기도 후보가 될 수 있다
local RANK = { weapon = 3, amplifier = 2, relic = 1 }

local function slots()
    return require("systems.MasterTrace").SLOTS
end

local function min_level()
    return require("data.master_trace").resonance.min_level
end

local function rank(item)
    return item.level * 10000 + (RANK[item:role()] or 0) * 1000 + math.min(999, item:sale_value())
end

-- 계열별 봉인 후보 { archetype = item } (보유 유물 · 저주 대가 없음 · 영역/칸 순서로 결정론적)
function BalanceTrace.candidates(w)
    local best, score = {}, {}
    for _, area in ipairs(AREAS) do
        for index = 1, w.inventory:size(area) do
            local item = w.inventory:get(area, index)
            if item ~= nil and item.owned and BalanceGrid.toll(item) == 0 then
                local archetype, value = item.proto.archetype, rank(item)
                if archetype ~= nil and (score[archetype] == nil or value > score[archetype]) then
                    best[archetype], score[archetype] = item, value
                end
            end
        end
    end
    return best
end

-- 팔거나 밀어내지 않는 유물 (봉인 후보)
function BalanceTrace.keeps(w, item)
    return w.master_trace ~= nil and item ~= nil and item.proto.archetype ~= nil
        and BalanceTrace.candidates(w)[item.proto.archetype] == item
end

-- 보관함에서 아껴 둘 후보 (PLACE_FROM 전의 +5 후보 · 완전 마모된 +4 후보) — 보관함 정리가 진열장으로 꺼내지 않게
function BalanceTrace.parks(w, item)
    if w.day >= PLACE_FROM or not BalanceTrace.keeps(w, item) then
        return false
    end
    return item.level >= min_level() or (item.level >= HOLD_LEVEL and item:is_worn_out())
end

-- 일반 강화(tools/BalanceForge)가 남겨 둘 연마석
function BalanceTrace.stone_reserve(w)
    if w.master_trace == nil then
        return 0
    end
    return w.day >= LIGHT_FROM - 4 and STONE_RESERVE.light or STONE_RESERVE.grow
end

-- 손님 유물을 마진과 상관없이 살까: 찾은 은빛 인장(수기가 남았을 때) · 후보가 없는 계열
function BalanceTrace.wants(w, item)
    local trace = w.master_trace
    if trace == nil or item == nil or item.owned then
        return false
    end
    if item.silver_seal ~= nil and item.revealed.seal and trace.journals < require("systems.MasterTrace").JOURNALS then
        return true
    end
    local archetype = item.proto.archetype
    return archetype ~= nil and BalanceGrid.toll(item) == 0 and BalanceTrace.candidates(w)[archetype] == nil
end

function BalanceTrace.can_afford(w, price, keep)
    return w.gold - price >= keep * SEAL_RESERVE
end

-- 임시 거치대(3칸)의 빈 칸 — 매입 자동 배치가 막히지 않게 한 칸은 늘 비워 둔다 (진열장도 거치대도 가득하면 살 수 없다)
local function free_box(w)
    local inventory = w.inventory
    if inventory:size("storage") - inventory:count("storage") <= 1 then
        return nil
    end
    return inventory:find_empty("storage")
end

-- 작업대에서 처리 중인 후보를 팔지 않고 둔다: 아껴 둘 후보는 보관함, 무기는 진열장 빈 칸, 아니면 보관함 → 진열장
function BalanceTrace.stash(w, item)
    if not BalanceTrace.keeps(w, item) or w.inventory:locate(item) ~= "bench" then
        return false
    end
    local cell, box = BalanceGrid.open_empty_cell(w), free_box(w)
    if cell ~= nil and (box == nil or (not BalanceTrace.parks(w, item) and item:is_weapon())) then
        return w:move_item("bench", 1, "grid", cell)        -- 임시 거치대(3칸)가 찼으면 아끼던 후보도 진열장에 둔다
    end
    return box ~= nil and w:move_item("bench", 1, "storage", box)
end

-- 아껴 둘 후보를 진열장에서 임시 거치대로. 거치대가 찼으면 무기 후보는 주인공이 든다 (문 앞에서는 진열장의 절반만 닳고,
-- 들고 있던 무기는 그 진열 칸으로 내려온다)
local function park(w, item)
    local area, index = w.inventory:locate(item)
    if area ~= "grid" then
        return
    end
    local box = free_box(w)
    if box ~= nil then
        w:move_item(area, index, "storage", box)
    elseif item:is_weapon() and not BalanceTrace.keeps(w, w.inventory:get("hero", 1)) then
        w:move_item(area, index, "hero", 1)
    end
end

-- +5 후보를 자기 슬롯으로 (작업대·용광로에 있는 것은 건너뛴다 — 작업대를 막지 않게)
function BalanceTrace.place(w)
    local candidates = BalanceTrace.candidates(w)
    for _, slot in ipairs(slots()) do
        local item = candidates[slot.archetype]
        if item ~= nil and item.level >= min_level() and not item:is_worn_out() then
            local area, index = w.inventory:locate(item)
            if (area == "grid" and index ~= slot.index) or area == "storage" then
                w:move_item(area, index, "grid", slot.index)
            elseif area == "hero" and (w.inventory:get("grid", slot.index) == nil or w.inventory:get("grid", slot.index):is_weapon()) then
                w:move_item(area, index, "grid", slot.index)        -- 주인공이 들고 있던 후보 (그 칸의 무기와 맞바꾼다)
            elseif area == "hero" then
                w:quick_move("hero", index)                         -- 그 칸에 유물이 있으면: 일단 내려놓고 내일 옮긴다
            end
        end
    end
end

-- 오늘 강화할 후보 (낮은 단계부터): 목표 단계 아래 · 점화 단계부터는 많이 닳은 +5 도 한 단계 더 (복구)
local function forge_list(w, lighting)
    local goal, list = lighting and min_level() or HOLD_LEVEL, {}
    for _, slot in ipairs(slots()) do
        local item = BalanceTrace.candidates(w)[slot.archetype]
        local need = (w.max_days - math.max(w.day, PLACE_FROM) + 1) * NIGHT_WEAR + FINAL_MARGIN     -- 슬롯에서 버틸 남은 밤
        local refresh = lighting and item ~= nil and item.level >= min_level() and item.durability < need
        if item ~= nil and item:can_forge() and (item.level < goal or refresh) then
            list[#list + 1] = { item = item, order = slot.order }
        end
    end
    table.sort(list, function(a, b)
        return a.item.level < b.item.level or (a.item.level == b.item.level and a.order < b.order)
    end)
    return list
end

-- 하루 계획: 후보 성장(+4) → LIGHT_FROM 부터 +5 점화 강화 · 보관 → PLACE_FROM 부터 슬롯에 넣기
function BalanceTrace.plan_day(w, record)
    if w.master_trace == nil or w.inventory:get("furnace", 1) ~= nil then
        return
    end
    local BalanceForge = require("tools.BalanceForge")
    local lighting = w.day >= LIGHT_FROM
    local budget = lighting and LIGHT_PER_DAY or GROW_PER_DAY
    for _, entry in ipairs(forge_list(w, lighting)) do
        if budget <= 0 then
            break
        end
        if BalanceForge.affordable(w, entry.item) then
            budget = budget - 1
            BalanceForge.forge_item(w, entry.item, record, "forge_trace")
        end
    end
    for _, item in pairs(BalanceTrace.candidates(w)) do
        if BalanceTrace.parks(w, item) then
            park(w, item)
        end
    end
    if w.day >= PLACE_FROM then
        BalanceTrace.place(w)
    end
end

-- 밤: want = 일반 과부하 판단. 아이기스 · 그로기 → 켠다, 점화된 슬롯이 있으면 → 끈다
function BalanceTrace.overclock(w, want)
    local trace = w.master_trace
    if trace == nil then
        return want
    end
    for _, monster in ipairs(w.combat.monsters) do
        if not monster.dead and monster.spec.final and (monster.aegis ~= nil or monster.groggy_time > 0) then
            return true
        end
    end
    return want and trace:lit_count() == 0
end

-- BALANCE_TRACE=1 이면 날마다 후보 상태를 찍는다 (tools/BalanceSim 의 trace_day 가 부른다)
function BalanceTrace.describe(w)
    if w.master_trace == nil then
        return ""
    end
    local parts = {}
    for _, slot in ipairs(slots()) do
        local item = BalanceTrace.candidates(w)[slot.archetype]
        local area = item and w.inventory:locate(item) or "-"
        parts[#parts + 1] = string.format("%s=%s+%d/%.0f%%@%s", slot.archetype, item and item.proto_id or "-", item and item.level or 0,
            item and item.durability or 0, area)
    end
    return string.format(" stones %d lit %d %s", w.tempering_stones, w.master_trace:lit_count(), table.concat(parts, " "))
end

return BalanceTrace
