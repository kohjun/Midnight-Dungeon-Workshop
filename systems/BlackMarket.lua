-- systems/BlackMarket.lua
-- 암시장 특수 이벤트 (data/events.lua): 매일 아침 추첨, 그날 낮 동안 유효. [의뢰] 창(ui/QuestModal)에 제안으로 올라오고,
-- 수락(accept)해야 효과가 생긴다. 거절(decline)하거나 수락하지 않은 채 밤이 오면(night_started) 상인이 떠난다.
--   mystery_boxes : 수락하면 감정 불가 봉인 상자 3종을 열 수 있다 — 70% 고강화 유물 / 30% 저주 폭탄(오염·파손)
--   fence_request : 수락하면 그날 결함 유물 판매가 x2.5 ("economy:sale_price" 구독)
--   blood_moon    : 수락하면 오늘 밤 몬스터 강화, 버텨내면 다음 상납 목표액 차감

local Class = require("lib.classic")
local EventBus = require("core.EventBus")
local RNG = require("core.RNG")
local I18n = require("systems.I18n")
local ItemFactory = require("systems.ItemFactory")
local EVENTS = require("data.events")

local BlackMarket = Class:extend()

function BlackMarket:new(workshop)
    self._workshop = workshop
    self.event = nil
    self.accepted = false
    self.opened = {}
    self.blood_moon = false
end

function BlackMarket:destroy()
    EventBus.unsubscribe_owner(self)
end

function BlackMarket:event_data()
    return self.event and EVENTS.events[self.event] or nil
end

function BlackMarket:_end_event()
    EventBus.unsubscribe_owner(self)
    self.event = nil
    self.accepted = false
    self.opened = {}
    self.blood_moon = false
end

-- 아직 수락·거절하지 않은 제안이 있는지 ([의뢰] 배지)
function BlackMarket:is_pending()
    return self.event ~= nil and not self.accepted
end

-- 아침 추첨: daily_chance(+암시장 인맥) 또는 guaranteed_every 일마다 확정
function BlackMarket:roll(day)
    self:_end_event()
    local rng = RNG.stream("market")
    local chance = EVENTS.daily_chance + self._workshop:meta_value("event_chance")
    local hit = rng:chance(chance)
    if day % EVENTS.guaranteed_every == 0 then
        hit = true
    end
    if not hit then
        return nil
    end
    local entries = {}
    for _, id in ipairs(EVENTS.order) do
        entries[#entries + 1] = { id = id, weight = EVENTS.events[id].weight }
    end
    self:start_event(rng:weighted_pick(entries).id)
    return self.event
end

function BlackMarket:start_event(id)
    local data = EVENTS.events[id]
    assert(data ~= nil, "BlackMarket: unknown event '" .. tostring(id) .. "'")
    self:_end_event()
    self.event = id
    EventBus.emit("blackmarket:event_started", {
        id = id, name = I18n.t("events." .. id .. ".name"), banner = I18n.t("events." .. id .. ".banner"),
    })
end

-- 제안 수락: 그날 효과가 생긴다 (낮에만)
function BlackMarket:accept()
    if not self:is_pending() or not self._workshop:is_day() then
        return false
    end
    self.accepted = true
    local data = self:event_data()
    if self.event == "fence_request" then
        EventBus.subscribe("economy:sale_price", function(payload)
            if payload.item.flaw ~= nil then
                payload.price = payload.price * data.flaw_sale_mult
            end
        end, { owner = self, priority = 20 })
    elseif self.event == "blood_moon" then
        self.blood_moon = true
        EventBus.emit("blackmarket:blood_moon_accepted", {})
    end
    EventBus.emit("quest:accepted", { id = self.event, source = "market" })
    return true
end

-- 제안 거절: 상인이 떠난다
function BlackMarket:decline()
    if not self:is_pending() or not self._workshop:is_day() then
        return false
    end
    local id = self.event
    self:_end_event()
    EventBus.emit("quest:declined", { id = id, source = "market" })
    return true
end

-- 밤 시작: 수락하지 않은 제안은 사라진다 (수락한 핏빛 달은 오늘 밤 그대로)
function BlackMarket:night_started()
    if self:is_pending() then
        local id = self.event
        self:_end_event()
        EventBus.emit("quest:expired", { id = id, source = "market" })
    end
end

-- ── 미스터리 봉인 상자 ─────────────────────────────────────

function BlackMarket:box_availability(index)
    local data = self:event_data()
    local workshop = self._workshop
    if self.event ~= "mystery_boxes" or not workshop:is_day() then
        return false, I18n.t("reason.sale_ended")
    end
    if not self.accepted then
        return false, I18n.t("reason.accept_first")
    end
    if self.opened[index] then
        return false, I18n.t("reason.box_opened")
    end
    if workshop:free_grid_cell() == nil and workshop.inventory:find_empty("storage") == nil then
        return false, I18n.t("reason.display_full")              -- 무엇이 나와도 둘 자리 (진열장 빈칸 또는 임시 거치대)
    end
    if workshop.gold < data.boxes[index].price then
        return false, I18n.t("reason.no_gold")
    end
    return true, nil
end

function BlackMarket:open_box(index)
    local ok, reason = self:box_availability(index)
    if not ok then
        EventBus.emit("ui:message", { text = I18n.t("msg.cannot_open_box", { reason = reason }), kind = "warn" })
        return false
    end
    local data = self:event_data()
    local box = data.boxes[index]
    local workshop = self._workshop
    local rng = RNG.stream("market")
    workshop:spend_gold(box.price, "black_market")
    self.opened[index] = true
    if rng:chance(data.success_chance) then
        local rack_free = workshop.inventory:find_empty("storage") ~= nil      -- 방어구는 거치대에 자리가 있을 때만 나온다
        local item = ItemFactory.ready_item(rng, rng:pick(box.grades), rng:int(box.levels[1], box.levels[2]),
            workshop.unlocked_relics, rack_free)
        workshop:store_item(item)
        EventBus.emit("blackmarket:box_opened", { index = index, success = true, item = item })
    else
        local victim = self:_curse_bomb(rng, data.curse_bomb)
        EventBus.emit("blackmarket:box_opened", { index = index, success = false, victim = victim })
    end
    return true
end

-- 저주 폭탄: 보유 유물 하나를 오염·파손시킨다 (없으면 방벽 피해)
function BlackMarket:_curse_bomb(rng, bomb)
    local workshop = self._workshop
    local candidates = {}
    for _, area in ipairs({ "grid", "storage", "hero" }) do
        for index = 1, workshop.inventory:size(area) do
            local item = workshop.inventory:get(area, index)
            if item ~= nil and item.owned then
                candidates[#candidates + 1] = item
            end
        end
    end
    local victim = rng:pick(candidates)
    if victim == nil then
        workshop:damage_hp(bomb.hp_if_empty, "curse")
        return nil
    end
    victim.contamination = math.min(100, victim.contamination + bomb.contamination)
    victim.cleaned = false
    if not victim:is_immortal() then        -- 내구도를 갉아먹는다 (0% = 완전 마모, 지워지지는 않는다 · 불멸 각인은 면역)
        victim.durability = math.max(0, victim.durability - bomb.durability_loss)
    end
    EventBus.emit("inventory:changed", { inventory = workshop.inventory })
    return victim
end

-- ── 핏빛 달 ────────────────────────────────────────────────

function BlackMarket:accept_blood_moon()
    return self.event == "blood_moon" and self:accept()
end

-- 오늘 밤 몬스터 강화 배율 (없으면 nil)
function BlackMarket:night_modifiers()
    if not self.blood_moon then
        return nil
    end
    local data = EVENTS.events.blood_moon
    return { hp_mult = data.hp_mult, speed_mult = data.speed_mult, blood_moon = true }
end

-- 밤이 끝난 직후 (상납 징수 전): 핏빛 달을 버텼으면 다음 상납 목표액 차감
function BlackMarket:settle_night()
    if self.blood_moon and self._workshop.result == nil then
        local discount = EVENTS.events.blood_moon.tribute_discount
        local due = self._workshop.tribute:discount_next(self._workshop.day, discount)
        EventBus.emit("blackmarket:blood_moon_cleared", { discount = discount, due = due })
    end
    self.blood_moon = false
end

return BlackMarket
