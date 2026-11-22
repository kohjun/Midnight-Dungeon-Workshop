-- systems/Appraisal.lua
-- 좌측 작업대 규칙: 손님 응대(무료 손님 · 유료 모험가 호출), UV 홀드 스캔(배터리 소모), 세척(정화수 소모),
-- 즉시 감정 주문서, 매입·판매. 용광로는 systems/Forge.lua. 그리기 금지 — 결과는 이벤트로 발행한다.

local Class = require("lib.classic")
local EventBus = require("core.EventBus")
local RNG = require("core.RNG")
local I18n = require("systems.I18n")
local ItemFactory = require("systems.ItemFactory")
local HeroEquip = require("systems.HeroEquip")
local Scanner = require("systems.Scanner")
local BALANCE = require("data.balance")
local LAYOUT = require("data.layout")

local Appraisal = Class:extend()

local function message(key, vars, kind)
    EventBus.emit("ui:message", { text = I18n.t(key, vars), kind = kind or "warn" })
end

-- 작업대 유물의 화면 중심과 그리기 크기
local function bench_geometry()
    local slot = LAYOUT.day.bench_slot
    return slot.x + slot.w / 2, slot.y + slot.h / 2, slot.item_size
end

local function inside_bench(x, y)
    local slot = LAYOUT.day.bench_slot
    return x >= slot.x and x <= slot.x + slot.w and y >= slot.y and y <= slot.y + slot.h
end

function Appraisal:new(workshop)
    self._workshop = workshop
    self._inventory = workshop.inventory
    self.lens_on = false    -- UV 렌즈가 지금 켜져 있는지 (버튼 홀드 중) — 뷰·오디오가 읽는다
end

function Appraisal:bench_item()
    return self._inventory:get("bench", 1)
end

function Appraisal:has_customer()
    local item = self:bench_item()
    return item ~= nil and not item.owned
end

function Appraisal:scan_coverage(item)
    return Scanner.coverage(item)
end

-- 손님 유물을 작업대에 올린다. free = 하루 무료 손님 1명 차감
function Appraisal:present_customer(item, free)
    local workshop = self._workshop
    self._inventory:place(item, "bench", 1)
    if free ~= false then
        workshop.customers_left = workshop.customers_left - 1
    end
    EventBus.emit("appraisal:customer_arrived", { item = item })
    -- UV 렌즈 3단계 개량: 결함 1개 자동 탐지
    if item.flaw ~= nil and workshop.upgrades:value("lens", "auto_flaw", false) then
        local cx, cy, size = bench_geometry()
        Scanner.reveal_flaw(item, cx, cy, size)
    end
end

-- 작업대를 비울 수 있으면 true (매입 안 한 손님은 돌려보낸다)
function Appraisal:_make_room()
    local workshop = self._workshop
    if not workshop:allows("new_customer") then
        message("msg.finish_customer_first")
        return false
    end
    local current = self:bench_item()
    if current ~= nil and current.owned then
        message("msg.clear_bench_first")
        return false
    end
    if current ~= nil then
        self._inventory:remove(current)
        EventBus.emit("appraisal:customer_left", { item = current })
    end
    return true
end

function Appraisal:_new_item()
    local workshop = self._workshop
    local rng = RNG.stream("customers")
    local rules = workshop:customer_rules()                                          -- 난이도 + 계절(가을 위조 증가)
    local adventurer = ItemFactory.pick_adventurer(rng, rules)                         -- 고유 모험가 6인 중 한 명
    return ItemFactory.customer_item(rng, workshop.day, rules, workshop.unlocked_relics, adventurer)
end

-- 매입하지 않은 손님을 돌려보낸다
function Appraisal:dismiss()
    local item = self:bench_item()
    if item == nil or item.owned then
        return false
    end
    if not self._workshop:allows("new_customer") then
        message("msg.finish_customer_first")
        return false
    end
    self._inventory:remove(item)
    EventBus.emit("appraisal:customer_left", { item = item, dismissed = true })
    return true
end

-- 하루 무료 손님. 방어구를 가져온 손님은 무료 손님 수를 쓰지 않는 덤 방문이다 (무기·유물 수급은 하루 3명 그대로)
function Appraisal:new_customer()
    if self._workshop.customers_left <= 0 then
        message("msg.no_free_customers")
        return false
    end
    if not self:_make_room() then
        return false
    end
    local item = self:_new_item()
    self:present_customer(item, not item:is_armor())
    if item:is_armor() then
        message("msg.armor_visit", nil, "info")
    end
    return true
end

-- [새 모험가 호출] 비용: 기본 25 G + 같은 날 호출마다 +15 G (암시장 인맥으로 할인)
function Appraisal:summon_cost()
    local settings = BALANCE.workshop.summon
    local workshop = self._workshop
    local cost = settings.base_cost + settings.step_cost * workshop.summons_today - workshop:meta_value("summon_discount")
    return math.max(settings.min_cost, cost)
end

function Appraisal:summon_customer()
    local workshop = self._workshop
    local cost = self:summon_cost()
    if workshop.gold < cost then
        message("msg.summon_short", { cost = cost })
        return false
    end
    if not self:_make_room() then
        return false
    end
    workshop:spend_gold(cost, "summon")
    workshop.summons_today = workshop.summons_today + 1
    EventBus.emit("appraisal:summoned", { cost = cost })
    self:present_customer(self:_new_item(), false)
    return true
end

function Appraisal:lens_radius()
    return BALANCE.appraisal.scan_radius + self._workshop.upgrades:value("lens", "radius_bonus", 0)
end

function Appraisal:lens_drain_per_second()
    local workshop = self._workshop
    local mult = workshop.upgrades:value("lens", "drain_mult", 1) * (1 - workshop:meta_value("uv_saving")) * workshop:supply_mult()
    return BALANCE.supplies.uv_drain_per_second * math.max(0, mult)
end

-- 오염도 1%p 제거당 정화수 소모(%) — 난이도 소모 배율 · 고압 브러시 개조 반영
function Appraisal:water_per_point()
    local workshop = self._workshop
    return BALANCE.supplies.water_per_contamination * workshop.upgrades:value("brush", "water_mult", 1) * workshop:supply_mult()
end

-- UV 모드에서 매 프레임 호출. held = 왼쪽 버튼을 누르고 있는지 (움직이기만 하면 렌즈는 꺼져 있다).
-- 버튼을 누른 채 작업대 유물 영역 위에 있는 동안에만 렌즈가 켜지고(self.lens_on) 배터리를 소모한다.
-- 반환: "ok"(렌즈 켜짐) | "empty"(누르고 있지만 배터리 방전) | "idle"(렌즈 꺼짐)
function Appraisal:scan(x, y, dt, held)
    self.lens_on = false
    local item = self:bench_item()
    if not held or item == nil or not inside_bench(x, y) then
        return "idle"
    end
    local supplies = self._workshop.supplies
    if supplies.uv <= 0 then
        return "empty"
    end
    self.lens_on = true
    local cx, cy, size = bench_geometry()
    Scanner.scan(item, x, y, cx, cy, size, self:lens_radius())
    supplies:spend("uv", self:lens_drain_per_second() * dt)
    return "ok"
end

-- 즉시 감정 주문서: 배터리 없이 작업대 유물을 완전 감정
function Appraisal:use_scroll()
    local workshop = self._workshop
    local item = self:bench_item()
    if workshop.scrolls <= 0 then
        message("msg.no_scrolls")
        return false
    end
    if item == nil or item.revealed.complete then
        message("msg.nothing_to_appraise")
        return false
    end
    workshop.scrolls = workshop.scrolls - 1
    local cx, cy, size = bench_geometry()
    Scanner.reveal_all(item, cx, cy, size)
    EventBus.emit("appraisal:scroll_used", { item = item, x = cx, y = cy })
    return true
end

function Appraisal:clean_mult()
    return self._workshop.upgrades:value("brush", "clean_mult", BALANCE.appraisal.clean_mult)
end

-- 세척: 문지른 거리만큼 오염도 감소, 제거량에 비례해 정화수 소모.
-- 반환: "ok" | "no_item" | "not_owned" | "clean" | "no_water"
function Appraisal:scrub(x, y, distance)
    local item = self:bench_item()
    if item == nil or not inside_bench(x, y) then
        return "no_item"
    end
    if not item.owned then
        return "not_owned"
    end
    if item.cleaned then
        return "clean"
    end
    local supplies = self._workshop.supplies
    local cost_per_point = self:water_per_point()
    if supplies.water <= 0 then
        return "no_water"
    end
    local removed = math.min(item.contamination, distance * BALANCE.appraisal.scrub_per_pixel)
    if cost_per_point > 0 then
        removed = math.min(removed, supplies.water / cost_per_point)
    end
    supplies:spend("water", removed * cost_per_point)
    item.contamination = math.max(0, item.contamination - removed)
    EventBus.emit("appraisal:scrubbed", { item = item, x = x, y = y, distance = distance })
    if item.contamination <= 0.0001 then
        item.contamination = 0
        item.cleaned = true
        item.clean_mult = self:clean_mult()
        local cx, cy = bench_geometry()
        EventBus.emit("appraisal:cleaned", { item = item, x = cx, y = cy })
    end
    return "ok"
end

function Appraisal:buy()
    local item = self:bench_item()
    if item == nil or item.owned then
        message("msg.nothing_to_buy")
        return false
    end
    -- 자동 배치: 무기·유물 → 진열장 첫 빈칸 → 임시 거치대 / 방어구 → 빈 부위 칸에 바로 장착 → 임시 거치대.
    -- 갈 곳이 없으면 사지 못한다 (튜토리얼의 첫 매입은 바로 세척하도록 작업대에 남긴다)
    local workshop = self._workshop
    local area, slot = nil, nil
    if not workshop:keeps_purchase_on_bench() then
        area, slot = workshop:route_item(item)
        if area == nil then
            message("msg.no_room", { reason = I18n.t(HeroEquip.full_reason(item)) })
            return false
        end
    end
    local price = item:asking_price()
    if not workshop:spend_gold(price, "purchase") then
        message("msg.not_enough_gold", { price = price })
        return false
    end
    item.owned = true
    local cx, cy = bench_geometry()
    if area ~= nil then
        self._inventory:move("bench", 1, area, slot)
        EventBus.emit("equip:routed", { item = item, area = area, index = slot })
    end
    EventBus.emit("appraisal:item_bought", {
        item = item, price = price, discounted = item.flaw ~= nil and item.revealed.flaw, x = cx, y = cy,
        area = area, index = slot,
    })
    return true
end

function Appraisal:sell()
    local item = self:bench_item()
    if item == nil or not item.owned then
        message("msg.nothing_to_sell")
        return false
    end
    if not self._workshop:allows("sell") then
        message("msg.tutorial_clean_first")
        return false
    end
    local value = self._workshop:sale_price(item)
    self._inventory:remove(item)
    self._workshop:add_gold(value, "sale")
    local cx, cy = bench_geometry()
    EventBus.emit("appraisal:item_sold", { item = item, value = value, x = cx, y = cy })
    return true
end

return Appraisal
