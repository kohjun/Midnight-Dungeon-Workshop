-- systems/Grid.lua
-- 5x5 진열장 그리드: 칸 기하(인덱스·이웃·좌표)와 유효 스탯 계산.
-- 시너지는 여기서 계산하지 않는다 — "grid:compute_stats" 를 발행하면 ItemEffects 의 구독자가
-- 배율(attack_mult / rate_mult / income_mult), 보너스 문구, 연결선(links)을 추가한다.

local EventBus = require("core.EventBus")
local LAYOUT = require("data.layout")
local UPGRADES = require("data.upgrades")

local Grid = {}

-- 칸 좌표는 기본으로 밤 진열장(전투 원점) 기준. 낮 [진열장 배치] 탭은 ui/Slots 가 LAYOUT.day.grid 를 넘긴다
local GEOMETRY = LAYOUT.night.grid
local NEIGHBOR_OFFSETS = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }

Grid.COLS = LAYOUT.grid_cols
Grid.ROWS = LAYOUT.grid_rows
Grid.SIZE = Grid.COLS * Grid.ROWS
Grid.CORE = (LAYOUT.grid_core.row - 1) * Grid.COLS + LAYOUT.grid_core.col     -- 정중앙 직접 동조 슬롯 (ui/ConduitView · ui/LaneHero)

function Grid.to_row_col(index)
    return math.floor((index - 1) / Grid.COLS) + 1, (index - 1) % Grid.COLS + 1
end

function Grid.to_index(row, col)
    return (row - 1) * Grid.COLS + col
end

-- 그리드 확장 단계(1=3x3 … 5=5x5)에서 그 칸이 개방되어 있는지
function Grid.is_open(index, stage)
    local region = UPGRADES.grid_stages[stage]
    assert(region ~= nil, "Grid.is_open: unknown grid stage " .. tostring(stage))
    local row, col = Grid.to_row_col(index)
    return row >= region.rows[1] and row <= region.rows[2] and col >= region.cols[1] and col <= region.cols[2]
end

function Grid.stage_count()
    return #UPGRADES.grid_stages
end

function Grid.stage_label(stage)
    return UPGRADES.grid_stages[stage].label
end

-- 상하좌우 이웃 인덱스 목록
function Grid.neighbors(index)
    local row, col = Grid.to_row_col(index)
    local result = {}
    for _, offset in ipairs(NEIGHBOR_OFFSETS) do
        local r, c = row + offset[1], col + offset[2]
        if r >= 1 and r <= Grid.ROWS and c >= 1 and c <= Grid.COLS then
            result[#result + 1] = Grid.to_index(r, c)
        end
    end
    return result
end

-- geometry: { x, y, cell, gap } (생략하면 밤 진열장)
function Grid.cell_rect(index, geometry)
    local g = geometry or GEOMETRY
    local row, col = Grid.to_row_col(index)
    local step = g.cell + g.gap
    return g.x + (col - 1) * step, g.y + (row - 1) * step, g.cell, g.cell
end

function Grid.cell_center(index, geometry)
    local x, y, w, h = Grid.cell_rect(index, geometry)
    return x + w / 2, y + h / 2
end

-- 그리드 전체 사각형 x, y, w, h
function Grid.bounds(geometry)
    local g = geometry or GEOMETRY
    return g.x, g.y, Grid.COLS * (g.cell + g.gap) - g.gap, Grid.ROWS * (g.cell + g.gap) - g.gap
end

-- 화면 좌표 → 칸 인덱스 (칸 사이 틈이나 그리드 밖이면 nil)
function Grid.cell_at(x, y, geometry)
    local g = geometry or GEOMETRY
    local lx, ly = x - g.x, y - g.y
    if lx < 0 or ly < 0 then
        return nil
    end
    local step = g.cell + g.gap
    local col, row = math.floor(lx / step) + 1, math.floor(ly / step) + 1
    if col > Grid.COLS or row > Grid.ROWS then
        return nil
    end
    if lx - (col - 1) * step > g.cell or ly - (row - 1) * step > g.cell then
        return nil
    end
    return Grid.to_index(row, col)
end

-- 그리드 유물의 유효 스탯. 완전 마모(내구도 0%) 유물은 빠진다 — 공격·증폭·시너지·일일 수익 없음.
-- 반환: { stats = { [item] = { index, attack, fire_rate, income, *_mult, bonuses } }, links, order }
function Grid.compute_stats(inventory)
    local stats, order = {}, {}
    for index = 1, Grid.SIZE do
        local item = inventory:get("grid", index)
        if item ~= nil and not item:is_worn_out() then
            stats[item] = { index = index, attack_mult = 1, rate_mult = 1, income_mult = 1, bonuses = {} }
            order[#order + 1] = item
        end
    end

    local result = EventBus.emit("grid:compute_stats", { stats = stats, links = {}, inventory = inventory })

    for _, item in ipairs(order) do
        local stat = stats[item]
        stat.attack = item:attack() * stat.attack_mult
        stat.fire_rate = item:fire_rate() * stat.rate_mult
        stat.income = math.floor(item:base_income() * stat.income_mult + 0.5)
    end
    return { stats = stats, links = result.links, order = order }
end

return Grid
