-- systems/HeroEquip.lua
-- 주인공 장비창과 3분류 배치 규칙 (Workshop 믹스인 — install 이 메서드를 섞는다. 수치 data/hero.lua).
--   영역: Inventory "hero" 1~4 = 무기 · 투구 · 갑옷 · 신발 (HERO.slots) / "storage" 1~3 = 임시 거치대 (코드 id 는 예전
--         보관함 그대로) / "grid" = 5x5 공명 진열장 / "bench" · "furnace" = 작업대 · 용광로 (무엇이든 올린다)
--   3분류: weapon = 진열장 + 주인공 무기 칸 · armor = 주인공의 제 부위 칸만 · relic = 진열장만 (HeroEquip.fits)
--   자동 배치(route_item): 무기·유물 → 진열장의 첫 열린 빈칸 ('스승의 흔적' 봉인 공명 슬롯은 맨 나중) → 임시 거치대 /
--         방어구 → 그 부위 칸이 비었으면 바로 장착 → 임시 거치대. 둘 다 없으면 nil (매입·획득 불가)
--   빠른 교체(quick_move, 우클릭): 거치대·작업대의 방어구 → 장착(입고 있던 것과 맞바꿈) · 무기 → 주인공 무기 칸(차 있으면
--         진열장 빈칸, 그것도 없으면 맞바꿈) · 유물 → 진열장 빈칸 / 진열장 무기 → 주인공 무기와 맞바꿈 · 진열장 유물 → 거치대 /
--         장비창 → 거치대(무기는 거치대가 차 있으면 진열장 빈칸)
-- 거절하면 "equip:rejected" { item, area, index, reason } + 안내 토스트.

local EventBus = require("core.EventBus")
local I18n = require("systems.I18n")
local HERO = require("data.hero")

local HeroEquip = {}

local AREA, RACK = "hero", "storage"
local INDEX = {}
for i, slot in ipairs(HERO.slots) do
    INDEX[slot] = i
end

HeroEquip.AREA, HeroEquip.RACK, HeroEquip.SLOTS = AREA, RACK, HERO.slots

-- 부위 이름 → 장비창 칸 번호 ("weapon" = 1 …)
function HeroEquip.slot_index(slot)
    return INDEX[slot]
end

-- 그 유물을 (area, index) 에 놓을 수 있는가. 못 놓으면 false, 사유 키(msg.*)
function HeroEquip.fits(item, area, index)
    if area == "grid" and item.category == "armor" then
        return false, "msg.armor_not_on_grid"
    elseif area == AREA then
        if item.equip_slot == nil then
            return false, "msg.relic_not_on_hero"
        elseif item.equip_slot ~= HERO.slots[index] then
            return false, "msg.wrong_hero_slot"
        end
    end
    return true
end

local Mixin = {}

function Mixin:_reject(item, area, index, reason, vars)
    EventBus.emit("ui:message", { text = I18n.t(reason, vars), kind = "warn" })
    EventBus.emit("equip:rejected", { item = item, area = area, index = index, reason = reason })
    return false
end

-- move_item 의 3분류 검사: 옮기는 유물이 목적지에, (맞바꾸면) 밀려나는 유물이 출발지에 맞는가. 안 맞으면 거절하고 false
function Mixin:check_fit(item, target, from_area, from_index, to_area, to_index)
    local ok, reason = HeroEquip.fits(item, to_area, to_index)
    if ok and target ~= nil then
        ok, reason = HeroEquip.fits(target, from_area, from_index)
    end
    if not ok then
        local slot = to_area == AREA and HERO.slots[to_index] or (from_area == AREA and HERO.slots[from_index]) or "weapon"
        return self:_reject(item, to_area, to_index, reason, { slot = I18n.t("hero.slots." .. slot) })
    end
    return true
end

-- 진열장의 첫 열린 빈칸 (봉인 공명 슬롯은 다른 빈칸이 없을 때만). 없으면 nil
function Mixin:free_grid_cell()
    local trace, fallback = self.master_trace, nil
    for index = 1, self.inventory:size("grid") do
        if self:is_cell_open(index) and self.inventory:get("grid", index) == nil then
            if trace == nil or trace.slot_at(index) == nil then
                return index
            end
            fallback = fallback or index
        end
    end
    return fallback
end

-- 자동 배치 목적지: area, index (자리가 없으면 nil)
function Mixin:route_item(item)
    if item.category == "armor" then
        local slot = INDEX[item.equip_slot]
        if self.inventory:get(AREA, slot) == nil then
            return AREA, slot
        end
    else
        local cell = self:free_grid_cell()
        if cell ~= nil then
            return "grid", cell
        end
    end
    local rack = self.inventory:find_empty(RACK)
    if rack ~= nil then
        return RACK, rack
    end
    return nil
end

-- 자리가 없을 때의 사유 키 (매입·획득 불가 안내)
function HeroEquip.full_reason(item)
    return item.category == "armor" and "reason.hero_full" or "reason.display_full"
end

-- 새로 얻은 보유 유물(아직 어느 칸에도 없는 것)을 자동 배치한다. 반환: area, index (자리가 없으면 nil — 놓지 않는다)
function Mixin:store_item(item)
    local area, index = self:route_item(item)
    if area ~= nil then
        self.inventory:place(item, area, index)
        EventBus.emit("equip:routed", { item = item, area = area, index = index })
    end
    return area, index
end

-- 이미 칸에 있는 내 유물(작업대 등)을 자동 배치 목적지로 옮긴다. 성공 여부
function Mixin:auto_place(from_area, from_index)
    local item = self.inventory:get(from_area, from_index)
    if item == nil or not item.owned then
        return false
    end
    local area, index = self:route_item(item)
    if area == nil then
        return self:_reject(item, from_area, from_index, "msg.no_room", { reason = I18n.t(HeroEquip.full_reason(item)) })
    end
    if not self:move_item(from_area, from_index, area, index) then
        return false
    end
    EventBus.emit("equip:routed", { item = item, area = area, index = index })
    return true
end

-- 우클릭 빠른 교체. 성공 여부
function Mixin:quick_move(area, index)
    local inventory = self.inventory
    local item = inventory:get(area, index)
    if item == nil or not item.owned or not self:is_day() then
        return false
    end
    local to_area, to_index
    if area == AREA then                                    -- 벗기: 거치대 (무기는 거치대가 찼으면 진열장 빈칸)
        to_area, to_index = RACK, inventory:find_empty(RACK)
        if to_index == nil and item.category == "weapon" then
            to_area, to_index = "grid", self:free_grid_cell()
        end
    elseif item.category == "armor" then                    -- 입기 (입고 있던 것과 맞바꾼다)
        to_area, to_index = AREA, INDEX[item.equip_slot]
    elseif item.category == "weapon" then
        local weapon_slot = INDEX.weapon
        if area == "grid" or inventory:get(AREA, weapon_slot) == nil then
            to_area, to_index = AREA, weapon_slot
        else
            to_area, to_index = "grid", self:free_grid_cell()
            if to_index == nil then
                to_area, to_index = AREA, weapon_slot
            end
        end
    elseif area == "grid" then                              -- 진열장 유물 → 거치대
        to_area, to_index = RACK, inventory:find_empty(RACK)
    else                                                    -- 거치대·작업대 유물 → 진열장 빈칸
        to_area, to_index = "grid", self:free_grid_cell()
    end
    if to_index == nil then
        local reason = to_area == RACK and "reason.rack_full" or "reason.display_full"
        return self:_reject(item, area, index, "msg.no_room", { reason = I18n.t(reason) })
    end
    return self:move_item(area, index, to_area, to_index)
end

-- 장착 중인 장비 { weapon = Item|nil, helmet = …, chest = …, boots = … }
function Mixin:hero_gear()
    local gear = {}
    for i, slot in ipairs(HERO.slots) do
        gear[slot] = self.inventory:get(AREA, i)
    end
    return gear
end

function HeroEquip.install(class)
    for name, fn in pairs(Mixin) do
        class[name] = fn
    end
end

return HeroEquip
