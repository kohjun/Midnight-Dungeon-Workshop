-- systems/WorkshopEconomy.lua
-- Workshop 믹스인: 골드 · 연마석 · 방벽 내구도 · 판매가 (WorkshopEconomy.install(Workshop) 으로 메서드를 붙인다).
--   add_gold / spend_gold       → "economy:gold_changed"
--   add_stones / spend_stones   → "economy:stones_changed"  (연마석: 용광로 +2 이상 오버클럭 강화 재화)
--   damage_hp / heal / raise_max_hp → "workshop:damaged" / "workshop:healed"
--     밤의 저주 대가(reason "curse")는 한 밤에 BALANCE.curse.night_cap 까지만 (Workshop:start_night 가 curse_paid 를 0 으로)
--   sale_price                  → "economy:sale_price" 구독자(상인의 저울·장물아비 의뢰)가 수정

local EventBus = require("core.EventBus")
local BALANCE = require("data.balance")

local WorkshopEconomy = {}

local METHODS = {}

function METHODS:add_gold(amount, reason)
    if amount == 0 then
        return
    end
    self.gold = self.gold + amount
    if amount > 0 then
        self.stats.gold_earned = self.stats.gold_earned + amount
    end
    EventBus.emit("economy:gold_changed", { amount = amount, reason = reason, gold = self.gold })
end

function METHODS:spend_gold(amount, reason)
    if self.gold < amount then
        return false
    end
    self.gold = self.gold - amount
    EventBus.emit("economy:gold_changed", { amount = -amount, reason = reason, gold = self.gold })
    return true
end

function METHODS:add_stones(amount, reason)
    if amount <= 0 then
        return
    end
    self.tempering_stones = self.tempering_stones + amount
    EventBus.emit("economy:stones_changed", { amount = amount, reason = reason, stones = self.tempering_stones })
end

function METHODS:spend_stones(amount, reason)
    if self.tempering_stones < amount then
        return false
    end
    self.tempering_stones = self.tempering_stones - amount
    EventBus.emit("economy:stones_changed", { amount = -amount, reason = reason, stones = self.tempering_stones })
    return true
end

-- item: 피해 원인 유물 (저주 등), 없으면 nil. 실제로 깎인 양을 돌려준다 (저주 대가 상한에 막히면 0)
function METHODS:damage_hp(amount, reason, item)
    if self.result ~= nil or amount <= 0 then
        return 0
    end
    local toll = reason == "curse" and self.phase == "night"
    if toll then
        amount = math.min(amount, BALANCE.curse.night_cap - (self.curse_paid or 0))
        if amount <= 0 then
            return 0
        end
        self.curse_paid = (self.curse_paid or 0) + amount
    end
    self.hp = math.max(0, self.hp - amount)
    if self.phase == "night" and not toll then
        self.night_damage = (self.night_damage or 0) + amount      -- 새벽 무피해 보너스 판정 (Workshop:dawn_bonus, 저주 대가 제외)
    end
    EventBus.emit("workshop:damaged", { amount = amount, hp = self.hp, reason = reason, item = item })
    if self.hp <= 0 then
        self.result = "defeat"
    end
    return amount
end

function METHODS:heal(amount, reason)
    local healed = math.min(amount, self.max_hp - self.hp)
    if healed > 0 and self.result == nil then
        self.hp = self.hp + healed
        EventBus.emit("workshop:healed", { amount = healed, hp = self.hp, reason = reason })
    end
    return healed
end

-- 최대 내구도 증가 (늘어난 만큼 즉시 회복)
function METHODS:raise_max_hp(amount)
    self.max_hp = self.max_hp + amount
    self.hp = self.hp + amount
end

-- 실제 판매가: 기본가 × 거래 수완, 이후 "economy:sale_price" 구독자(상인의 저울·장물아비 의뢰)가 수정
function METHODS:sale_price(item)
    local price = item:sale_value() * (1 + self:meta_value("sale_bonus"))
    local payload = EventBus.emit("economy:sale_price", { item = item, price = price, workshop = self })
    return math.max(1, math.floor(payload.price + 0.5))
end

function WorkshopEconomy.install(class)
    for name, fn in pairs(METHODS) do
        class[name] = fn
    end
end

return WorkshopEconomy
