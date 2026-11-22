-- tools/BalanceGrid.lua
-- 밸런스 AI(tools/BalanceAI)의 진열장 판단 도우미: 빈 칸, 진열 가치, 가장 약한 진열품, 무기 비율,
-- 저주 대가(밤마다 방벽을 깎는 유물) 예산 — 방벽이 넉넉할 때만, 진열장 합계 TOLL_BUDGET 안에서만 진열한다.

local BalanceGrid = {}

local WEAPON_SHARE = 0.6        -- 열린 진열 칸 중 무기 비율 목표
local MIN_WEAPONS = 3
local TOLL_BUDGET = 1           -- 진열장 저주 대가 합계 상한 (밤마다 방벽 몇까지 감수하나)
local TOLL_HP = 0.7             -- 방벽이 최대의 이 비율 이상일 때만 대가 유물을 새로 진열한다
local TOLL_SHED = 0.5           -- 방벽이 이 비율 아래로 내려가면 대가 유물을 내린다 (자멸 방지)
local TOLL_POWER = 0.45         -- 대가 유물의 진열 가치 할인 (방벽 비용 감안 — 강화된 무기가 나오면 밀려난다)

-- 빈 열린 칸. '스승의 흔적' 캠페인이면 봉인 공명 슬롯(마모 x1.5 · 후보 자리)은 다른 빈 칸이 없을 때만
function BalanceGrid.open_empty_cell(w)
    local slot_at, fallback = w.master_trace and require("systems.MasterTrace").slot_at, nil
    for index = 1, w.inventory:size("grid") do
        if w:is_cell_open(index) and w.inventory:get("grid", index) == nil then
            if slot_at == nil or slot_at(index) == nil then
                return index
            end
            fallback = fallback or index
        end
    end
    return fallback
end

-- 진열 가치: 무기는 화력(공격 × 연사), 그 밖은 판매가 기준. 완전 마모(0%) 유물은 0 — 먼저 교체된다.
-- 저주 대가 유물은 TOLL_POWER 만큼 깎아 본다 (밤마다 방벽을 내주는 값)
function BalanceGrid.power(item)
    if item:is_worn_out() then
        return 0
    end
    local value = item:is_weapon() and item:attack() * item:fire_rate() * 4 or item:sale_value()
    return BalanceGrid.toll(item) > 0 and value * TOLL_POWER or value
end

-- filter(item) 를 만족하는 진열품 중 가장 약한 것 (item, index)
function BalanceGrid.weakest(w, filter)
    local weakest, index_of, lowest = nil, nil, math.huge
    for index = 1, w.inventory:size("grid") do
        local item = w.inventory:get("grid", index)
        if item ~= nil and (filter == nil or filter(item)) and BalanceGrid.power(item) < lowest then
            weakest, index_of, lowest = item, index, BalanceGrid.power(item)
        end
    end
    return weakest, index_of
end

-- 진열장 무기 수, 무기 목표 수, 빈 열린 칸 수
function BalanceGrid.weapon_balance(w)
    local weapons, open, empty = 0, 0, 0
    for index = 1, w.inventory:size("grid") do
        if w:is_cell_open(index) then
            open = open + 1
            local item = w.inventory:get("grid", index)
            if item == nil then
                empty = empty + 1
            elseif item:is_weapon() then
                weapons = weapons + 1
            end
        end
    end
    return weapons, math.max(MIN_WEAPONS, math.ceil(open * WEAPON_SHARE)), empty
end

-- 밤마다 방벽 대가 (저주 단검 · 피의 계약서 등의 hp_cost)
function BalanceGrid.toll(item)
    local total = 0
    for _, effect in ipairs(item:effects()) do
        total = total + (effect.hp_cost or 0)
    end
    return total
end

-- 진열장의 밤마다 대가 합계 (완전 마모 유물은 대가도 없다)
function BalanceGrid.grid_toll(w)
    local total = 0
    for index = 1, w.inventory:size("grid") do
        local item = w.inventory:get("grid", index)
        if item ~= nil and not item:is_worn_out() then
            total = total + BalanceGrid.toll(item)
        end
    end
    return total
end

-- 이 유물을 진열해도 되나: 대가가 없거나, 방벽이 넉넉하고 진열장 대가 합계가 예산 안일 때 (replacing = 대신 빠질 유물)
function BalanceGrid.toll_ok(w, item, replacing)
    local cost = BalanceGrid.toll(item)
    if cost <= 0 then
        return true
    end
    local freed = (replacing ~= nil and not replacing:is_worn_out()) and BalanceGrid.toll(replacing) or 0
    return w.hp >= w.max_hp * TOLL_HP and BalanceGrid.grid_toll(w) - freed + cost <= TOLL_BUDGET
end

-- 방벽이 위험하면 대가 유물 하나를 고른다 (내리거나 팔 대상, 없으면 nil)
function BalanceGrid.toll_to_shed(w)
    if w.hp >= w.max_hp * TOLL_SHED and BalanceGrid.grid_toll(w) <= TOLL_BUDGET then
        return nil
    end
    return (BalanceGrid.weakest(w, function(item) return BalanceGrid.toll(item) > 0 and not item:is_worn_out() end))
end

function BalanceGrid.is_weapon(item)
    return item:is_weapon()
end

function BalanceGrid.not_weapon(item)
    return not item:is_weapon()
end

return BalanceGrid
