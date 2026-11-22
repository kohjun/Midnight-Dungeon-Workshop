-- systems/Inventory.lua
-- 유물 슬롯 저장소: 영역(storage / grid / bench / furnace)별 칸과 유물 위치 역참조.
-- 모든 변경은 "inventory:changed" 를 발행한다 (Grid 스탯 재계산, ItemEffects 구독 동기화).

local Class = require("lib.classic")
local EventBus = require("core.EventBus")

local Inventory = Class:extend()

-- sizes: { area_name = slot_count, ... }
function Inventory:new(sizes)
    self._sizes = sizes
    self._slots = {}
    for area in pairs(sizes) do
        self._slots[area] = {}
    end
    self._where = {}   -- item -> { area, index }
end

function Inventory:_check(area, index)
    local size = self._sizes[area]
    assert(size ~= nil, "Inventory: unknown area '" .. tostring(area) .. "'")
    assert(type(index) == "number" and index % 1 == 0 and index >= 1 and index <= size,
        "Inventory: bad index " .. tostring(index) .. " for area '" .. area .. "'")
end

function Inventory:_changed()
    EventBus.emit("inventory:changed", { inventory = self })
end

function Inventory:size(area)
    return self._sizes[area]
end

function Inventory:get(area, index)
    self:_check(area, index)
    return self._slots[area][index]
end

-- 유물 위치: area, index (없으면 nil)
function Inventory:locate(item)
    local where = self._where[item]
    if where == nil then
        return nil
    end
    return where.area, where.index
end

function Inventory:find_empty(area)
    for index = 1, self._sizes[area] do
        if self._slots[area][index] == nil then
            return index
        end
    end
    return nil
end

function Inventory:count(area)
    local total = 0
    for index = 1, self._sizes[area] do
        if self._slots[area][index] ~= nil then
            total = total + 1
        end
    end
    return total
end

function Inventory:place(item, area, index)
    self:_check(area, index)
    assert(self._slots[area][index] == nil, "Inventory.place: slot is occupied")
    assert(self._where[item] == nil, "Inventory.place: item is already placed")
    self._slots[area][index] = item
    self._where[item] = { area = area, index = index }
    self:_changed()
end

-- 제거 후 원래 위치(area, index) 반환
function Inventory:remove(item)
    local where = self._where[item]
    if where == nil then
        return nil
    end
    self._slots[where.area][where.index] = nil
    self._where[item] = nil
    self:_changed()
    return where.area, where.index
end

-- 이동. 대상 칸이 차 있으면 교환한다. 성공 여부 반환
function Inventory:move(from_area, from_index, to_area, to_index)
    self:_check(from_area, from_index)
    self:_check(to_area, to_index)
    if from_area == to_area and from_index == to_index then
        return false
    end
    local item = self._slots[from_area][from_index]
    if item == nil then
        return false
    end
    local other = self._slots[to_area][to_index]

    self._slots[to_area][to_index] = item
    self._where[item] = { area = to_area, index = to_index }
    self._slots[from_area][from_index] = other
    if other ~= nil then
        self._where[other] = { area = from_area, index = from_index }
    end

    EventBus.emit("inventory:item_moved", {
        item = item,
        from_area = from_area, from_index = from_index,
        to_area = to_area, to_index = to_index,
        swapped = other,
    })
    self:_changed()
    return true
end

return Inventory
