-- systems/GuildShop.lua
-- 길드 보급 상점: 상납 성공 직후(phase "shop") 남은 골드로 소모품·수리·연마석·감정 주문서·희귀 유물 1점을 산다.
-- 낮 영업 중에는 day_offers(정화수·UV 배터리·방벽 수리·연마석)만 같은 값에 판다 (낮 [길드] 창, ui/GuildModal).
-- daily_limit 상품(연마석)은 하루 구매 수량 제한 — new_day()(아침, DayCycle)에 초기화.
-- 목록과 가격은 data/shop.lua. [다음 날 시작]은 Workshop:close_shop().

local Class = require("lib.classic")
local EventBus = require("core.EventBus")
local RNG = require("core.RNG")
local I18n = require("systems.I18n")
local ItemFactory = require("systems.ItemFactory")
local HeroEquip = require("systems.HeroEquip")
local ITEMS = require("data.items")
local SHOP = require("data.shop")

local GuildShop = Class:extend()

local DAY_OFFERS = {}       -- 낮에도 파는 소모품 (data/shop.lua 의 day_offers)
for _, id in ipairs(SHOP.day_offers) do
    DAY_OFFERS[id] = true
end

function GuildShop:new(workshop)
    self._workshop = workshop
    self.relic = nil
    self.relic_price = 0
    self.bought_today = {}
end

function GuildShop:new_day()
    self.bought_today = {}
end

-- 오늘 더 살 수 있는 수량 (제한 없는 상품은 nil)
function GuildShop:remaining(id)
    local limit = SHOP.offers[id].daily_limit
    if limit == nil then
        return nil
    end
    return math.max(0, limit - (self.bought_today[id] or 0))
end

function GuildShop:is_day_offer(id)
    return DAY_OFFERS[id] == true
end

function GuildShop:open(day)
    local offer = SHOP.offers.rare_relic
    self.relic = ItemFactory.ready_item(RNG.stream("shop"), offer.grade, 0, self._workshop.unlocked_relics)
    local grade_mult = ITEMS.grades[offer.grade].mult
    self.relic_price = math.floor(self.relic.proto.value * grade_mult * offer.price_mult + 0.5)
    self.day = day
end

function GuildShop:price(id)
    if id == "rare_relic" then
        return self.relic_price
    end
    return SHOP.offers[id].price
end

-- 구매 가능 여부와 불가 사유 (현재 언어 문구)
function GuildShop:availability(id)
    local workshop = self._workshop
    local offer = SHOP.offers[id]
    assert(offer ~= nil, "GuildShop: unknown offer '" .. tostring(id) .. "'")
    if workshop.phase ~= "shop" and not (DAY_OFFERS[id] and workshop:is_day()) then
        return false, I18n.t("reason.shop_closed")
    end
    if offer.daily_limit ~= nil and self:remaining(id) <= 0 then
        return false, I18n.t("reason.daily_limit")
    end
    if offer.kind == "supply" and workshop.supplies:is_full(offer.supply) then
        return false, I18n.t("reason.already_full")
    elseif offer.kind == "repair" and workshop.hp >= workshop.max_hp then
        return false, I18n.t("reason.wall_intact")
    elseif offer.kind == "relic" then
        if self.relic == nil then
            return false, I18n.t("reason.sold_out")
        elseif workshop:route_item(self.relic) == nil then           -- 자동 배치할 자리 (진열장·장비창 → 임시 거치대)
            return false, I18n.t(HeroEquip.full_reason(self.relic))
        end
    end
    if workshop.gold < self:price(id) then
        return false, I18n.t("reason.no_gold")
    end
    return true, nil
end

function GuildShop:buy(id)
    local ok, reason = self:availability(id)
    if not ok then
        EventBus.emit("ui:message", { text = I18n.t("msg.cannot_buy", { reason = reason }), kind = "warn" })
        return false
    end
    local workshop = self._workshop
    local offer = SHOP.offers[id]
    local price = self:price(id)
    workshop:spend_gold(price, "shop")
    if offer.kind == "supply" then
        workshop.supplies:add(offer.supply, offer.amount, "shop")
    elseif offer.kind == "repair" then
        workshop:heal(offer.amount, "shop")
    elseif offer.kind == "stone" then
        workshop:add_stones(offer.amount, "shop")
    elseif offer.kind == "scroll" then
        workshop.scrolls = workshop.scrolls + offer.amount
    elseif offer.kind == "relic" then
        workshop:store_item(self.relic)
        self.relic = nil
    end
    self.bought_today[id] = (self.bought_today[id] or 0) + 1
    EventBus.emit("shop:purchased", { id = id, name = I18n.t("shop." .. id .. ".name"), price = price })
    return true
end

return GuildShop
