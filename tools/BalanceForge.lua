-- tools/BalanceForge.lua
-- 밸런스 시뮬레이터(tools/BalanceSim)용 용광로 판단 — +10 강화 체계와 0~100% 내구도 (tools/BalanceAI 가 부른다). 게임 API 만 쓴다.
-- 하루 계획(plan_day, 낮 영업 끝무렵 한 번): 하루 최대 PER_DAY 번만 용광로를 돌린다 — 사람처럼 신중한 템포.
--   매입한 유물을 되팔려고 강화하지 않는다 (판매가에는 강화 몫의 일부만 붙는다, data/forge.lua 의 sale_share).
--   1) 정비: 진열장 무기·증폭기 중 내구도 MAINTAIN_BELOW% 이하(강한 것부터) → 다음 단계 강화 성공 = 100% 복구.
--      +6 이상 시도(파괴 위험)는 이미 0% 로 멈춘 유물만. 비용이 모자라면 그대로 둔다 (0% 유물은 매입품이 밀어낸다)
--   2) 성장: 남은 횟수로 진열장의 가장 강한 무기(다음은 증폭기)를 TARGET 단계까지 한 단계 — 파괴 위험 없는 단계만,
--      성공률 MIN_CHANCE 이상이고 비용과 다가오는 결계 유지비 여유가 있을 때. 같은 유물은 하루에 한 번만
--   저주 대가 유물(밤마다 방벽을 깎는 단검 등)에는 강화를 쓰지 않는다 — 닳으면 강화된 무기로 바꾼다
--   '스승의 흔적' 봉인 후보(tools/BalanceTrace.keeps)는 건드리지 않는다 — BalanceTrace 가 forge_item 으로 따로 키운다
-- record: forge_ok · forge_fail · forge_destroyed · forge_maint(정비 시도) · forge_grow(성장 시도) · restored(정비 성공) ·
--         forge_capped(하루 상한 때문에 감당할 수 있는 강화를 남긴 날 — 템포가 AI 상한이 아니라 경제로 정해지는지 본다)
-- 실험: 환경 변수 BALANCE_FORGE_PER_DAY 로 하루 상한을 바꿔 돌릴 수 있다 (예: 99 = 사실상 무제한 → 경제만으로 정해지는 템포).

local BalanceGrid = require("tools.BalanceGrid")

local BalanceForge = {}

local PER_DAY = tonumber(os.getenv("BALANCE_FORGE_PER_DAY") or "") or 2      -- 하루 용광로 시도 상한
local MIN_CHANCE = 0.5
local TARGET = { weapon = 5, amplifier = 3 }
local MAINTAIN_BELOW = 15       -- 이 % 이하로 닳은 진열품을 강화로 복구한다
local SAFE_LEVEL = 5            -- 이 단계까지의 시도는 파괴되지 않는다 (+6 부터 파괴 위험)

local function due_soon(w)
    local due, amount = w.tribute:next_due(w.day)
    if due ~= nil and due - w.day <= 3 then
        return amount
    end
    return 0
end

local function affordable(w, item)
    local gold = w.forge:cost(item)
    return gold ~= nil and w.forge:cost_block(item) == nil and w.gold - gold >= due_soon(w)
end
BalanceForge.affordable = affordable

-- 일반 진열품 강화: '스승의 흔적' 봉인 후보 몫의 연마석은 남긴다 (tools/BalanceTrace.stone_reserve)
local function spare_stones(w, item)
    local _, stones = w.forge:cost(item)
    return w.tempering_stones - (stones or 0) >= require("tools.BalanceTrace").stone_reserve(w)
end

-- 닳기 전 화력 (정비 우선순위 — BalanceGrid.power 는 0% 유물을 0 으로 본다)
local function raw_power(item)
    if item:is_weapon() then
        return item:attack() * item:fire_rate() * 4
    end
    return item:sale_value()
end

-- 용광로의 item 을 한 번 강화. "success" | "keep" | "down" | "destroyed" | "blocked"
local function forge_once(w, item, record)
    local from = item.level
    if not w.forge:start() then
        return "blocked"
    end
    while w.forge.forging ~= nil do
        w:update(0.1)
    end
    if w.inventory:locate(item) ~= "furnace" then
        record.forge_fail, record.forge_destroyed = record.forge_fail + 1, record.forge_destroyed + 1
        return "destroyed"
    end
    if item.level > from then
        record.forge_ok = record.forge_ok + 1
        return "success"
    end
    record.forge_fail = record.forge_fail + 1
    return item.level < from and "down" or "keep"
end

-- 진열장 index 칸의 유물을 용광로로 옮겨 한 번 강화하고 (남아 있으면) 제자리로
local function forge_cell(w, index, record, kind)
    local item = w.inventory:get("grid", index)
    if not w:move_item("grid", index, "furnace", 1) then
        return nil
    end
    record[kind] = (record[kind] or 0) + 1
    local result = forge_once(w, item, record)
    if w.inventory:locate(item) == "furnace" then
        w:move_item("furnace", 1, "grid", index)
    end
    return result
end

-- 어느 영역에 있든 용광로로 옮겨 한 번 강화하고 (남아 있으면) 제자리로 — tools/BalanceTrace 의 봉인 후보용
function BalanceForge.forge_item(w, item, record, kind)
    local area, index = w.inventory:locate(item)
    if area == nil or area == "furnace" or not w:move_item(area, index, "furnace", 1) then
        return nil
    end
    record[kind] = (record[kind] or 0) + 1
    local result = forge_once(w, item, record)
    if w.inventory:locate(item) == "furnace" then
        w:move_item("furnace", 1, area, index)
    end
    return result
end

-- filter(item) 를 만족하는 진열 칸 목록을 화력 내림차순으로 (캠페인 봉인 후보는 빼고)
local function ranked_cells(w, filter)
    local cells, keeps = {}, require("tools.BalanceTrace").keeps
    for index = 1, w.inventory:size("grid") do
        local item = w.inventory:get("grid", index)
        if item ~= nil and item:role() ~= "relic" and not item:is_immortal() and item:can_forge() and BalanceGrid.toll(item) == 0
            and filter(item) and not keeps(w, item) then
            cells[#cells + 1] = { index = index, power = raw_power(item), weapon = item:is_weapon() }
        end
    end
    table.sort(cells, function(a, b)
        if a.weapon ~= b.weapon then
            return a.weapon
        end
        return a.power > b.power or (a.power == b.power and a.index < b.index)
    end)
    return cells
end

-- AI 가 0% 가 되기 전에 정비해 주는 진열품인가 (BalanceAI 의 과부하 마모 가드와 같은 기준)
function BalanceForge.maintained(item)
    return item:role() ~= "relic" and not item:is_immortal() and item:can_forge() and BalanceGrid.toll(item) == 0
        and item.level < SAFE_LEVEL
end

local function needs_care(item)
    return item.durability <= MAINTAIN_BELOW and (item.level < SAFE_LEVEL or item.durability <= 0)
end

local function can_grow(w, item)
    return item.level < (TARGET[item:role()] or 0) and item.level < SAFE_LEVEL and w.forge:chance(item) >= MIN_CHANCE
end

-- 하루 상한에 걸렸는데 아직 감당할 수 있는 강화가 남았으면 그날을 센다 (하루 한 번)
local function note_capped(w, record, item, touched)
    if not record._capped_today and not touched[item] and affordable(w, item) then
        record._capped_today = true
        record.forge_capped = (record.forge_capped or 0) + 1
    end
end

-- 하루 계획: 정비 먼저, 남은 횟수로 성장. 같은 유물은 하루 한 번
function BalanceForge.plan_day(w, record)
    if w.inventory:get("furnace", 1) ~= nil then
        return
    end
    local left, touched = PER_DAY, {}
    record._capped_today = nil
    for _, cell in ipairs(ranked_cells(w, needs_care)) do
        local item = w.inventory:get("grid", cell.index)
        if left <= 0 then
            note_capped(w, record, item, touched)
            return
        end
        if affordable(w, item) and spare_stones(w, item) then
            touched[item] = true
            left = left - 1
            if forge_cell(w, cell.index, record, "forge_maint") == "success" then
                record.restored = record.restored + 1
            end
        end
    end
    for _, cell in ipairs(ranked_cells(w, function(item) return can_grow(w, item) end)) do
        local item = w.inventory:get("grid", cell.index)
        if left <= 0 then
            note_capped(w, record, item, touched)
            return
        end
        if not touched[item] and affordable(w, item) and spare_stones(w, item) then
            touched[item] = true
            left = left - 1
            forge_cell(w, cell.index, record, "forge_grow")
        end
    end
end

return BalanceForge
