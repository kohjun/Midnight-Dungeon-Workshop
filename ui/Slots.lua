-- ui/Slots.lua
-- 슬롯 영역(hero / storage / grid / bench / furnace)의 화면 좌표, 유물 그리기 크기, 마우스 히트 판정.
-- hero = 주인공 장비창 4칸(무기 · 투구 · 갑옷 · 신발), storage = 임시 거치대 (data/layout.lua 의 day.hero_slots · storage_slots).
-- 공방 화면 모드에 따라 보이는 영역과 좌표가 다르다 (data/layout.lua 의 day / night):
--   "day"   : 낮 — 작업대 · 용광로 · 보관함(오른쪽 위) · 진열장(오른쪽 아래, LAYOUT.day.grid) 이 한 화면에 함께 보인다
--   "night" : 밤 — 진열장(LAYOUT.night.grid, 전투 원점과 같은 좌표)
-- 지금 모드는 RunState 가 set_mode_provider 로 알려 준다 (없으면 "day"). 좌표 함수는 mode 를 직접 받을 수도 있다.

local Grid = require("systems.Grid")
local BALANCE = require("data.balance")
local HERO = require("data.hero")
local LAYOUT = require("data.layout")

local Slots = {}

local DAY, NIGHT = LAYOUT.day, LAYOUT.night
local VISIBLE = {
    day = { bench = true, furnace = true, storage = true, grid = true, hero = true },
    night = { grid = true },
}

local _provider = nil

local function inside(x, y, rx, ry, rw, rh)
    return x >= rx and x <= rx + rw and y >= ry and y <= ry + rh
end

-- provider() → "day" | "night" (nil 이면 기본값으로 되돌린다)
function Slots.set_mode_provider(provider)
    _provider = provider
end

function Slots.mode()
    return _provider and _provider() or "day"
end

-- 그 모드의 진열장 칸 기하 (낮 = LAYOUT.day.grid, 밤 = LAYOUT.night.grid)
function Slots.grid_geometry(mode)
    return (mode or Slots.mode()) == "night" and NIGHT.grid or DAY.grid
end

-- 진열장 전체 사각형 x, y, w, h
function Slots.grid_bounds(mode)
    return Grid.bounds(Slots.grid_geometry(mode))
end

-- 그 영역이 지금(또는 mode 에서) 화면에 보이는지
function Slots.is_visible(area, mode)
    return VISIBLE[mode or Slots.mode()][area] == true
end

-- x, y, w, h
function Slots.rect(area, index, mode)
    if area == "grid" then
        return Grid.cell_rect(index, Slots.grid_geometry(mode))
    elseif area == "storage" or area == "hero" then
        local row = area == "hero" and DAY.hero_slots or DAY.storage_slots
        return row.x + (index - 1) * (row.size + row.gap), row.y, row.size, row.size
    elseif area == "bench" then
        local slot = DAY.bench_slot
        return slot.x, slot.y, slot.w, slot.h
    elseif area == "furnace" then
        local slot = DAY.furnace_slot
        return slot.x, slot.y, slot.w, slot.h
    end
    error("Slots.rect: unknown area '" .. tostring(area) .. "'")
end

function Slots.center(area, index, mode)
    local x, y, w, h = Slots.rect(area, index, mode)
    return x + w / 2, y + h / 2
end

-- 해당 영역에서 유물을 그리는 크기(px)
function Slots.item_size(area, mode)
    if area == "grid" then
        return Slots.grid_geometry(mode).item_size
    elseif area == "storage" then
        return DAY.storage_slots.item_size
    elseif area == "hero" then
        return DAY.hero_slots.item_size
    elseif area == "bench" then
        return DAY.bench_slot.item_size
    end
    return DAY.furnace_slot.item_size
end

function Slots.storage_count()
    return BALANCE.workshop.storage_slots
end

-- 화면 좌표 → area, index (지금 보이는 영역만, 없으면 nil)
function Slots.at(x, y, mode)
    mode = mode or Slots.mode()
    local visible = VISIBLE[mode]
    if visible.grid then
        local cell = Grid.cell_at(x, y, Slots.grid_geometry(mode))
        if cell ~= nil then
            return "grid", cell
        end
    end
    if visible.storage then
        for index = 1, Slots.storage_count() do
            if inside(x, y, Slots.rect("storage", index)) then
                return "storage", index
            end
        end
    end
    if visible.hero then
        for index = 1, #HERO.slots do
            if inside(x, y, Slots.rect("hero", index)) then
                return "hero", index
            end
        end
    end
    for _, area in ipairs({ "bench", "furnace" }) do
        if visible[area] and inside(x, y, Slots.rect(area, 1)) then
            return area, 1
        end
    end
    return nil
end

return Slots
