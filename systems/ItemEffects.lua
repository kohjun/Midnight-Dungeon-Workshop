-- systems/ItemEffects.lua
-- 유물 효과 = EventBus 구독. 유물이 그리드에 놓이면 그 유물의 effects(+결함 효과)를 owner = item 으로
-- 구독하고, 그리드를 떠나거나 완전 마모(내구도 0%, combat:item_worn_out)되면 EventBus.unsubscribe_owner(item) 으로 해제한다.
-- Combat / Grid 는 이벤트만 발행하며 유물별 분기를 갖지 않는다.
--
-- 핸들러는 아키타입별 모듈(systems/effects/*.lua)에 있다. 새 효과 타입은 해당 모듈에
--   Module.<type> = function(item, effect, ctx) return { { event, fn, priority? }, ... } end
-- 를 추가한다. ctx = { inventory, workshop }.

local Class = require("lib.classic")
local EventBus = require("core.EventBus")

local ItemEffects = Class:extend()

local HANDLER_MODULES = {
    "systems.effects.CoreEffects",
    "systems.effects.FireEffects",
    "systems.effects.LightningEffects",
    "systems.effects.CurseEffects",
    "systems.effects.GoldEffects",
    "systems.effects.ImpactEffects",
}

local HANDLERS = {}
for _, path in ipairs(HANDLER_MODULES) do
    for name, factory in pairs(require(path)) do
        assert(HANDLERS[name] == nil, "ItemEffects: duplicate effect type '" .. name .. "'")
        HANDLERS[name] = factory
    end
end

function ItemEffects.has_handler(effect_type)
    return HANDLERS[effect_type] ~= nil
end

function ItemEffects:new(workshop)
    self._workshop = workshop
    self._inventory = workshop.inventory
    self._ctx = { inventory = workshop.inventory, workshop = workshop }
    self._active = {}   -- item -> true (구독 중)
    for _, event in ipairs({ "inventory:changed", "combat:item_worn_out", "forge:resolved" }) do
        EventBus.subscribe(event, function()
            self:sync()
        end, { owner = self, priority = 100 })
    end
    self:sync()
end

-- 그리드에서 작동 중인 유물(완전 마모 제외)만 구독 상태가 되도록 맞춘다
function ItemEffects:sync()
    local on_grid = {}
    for index = 1, self._inventory:size("grid") do
        local item = self._inventory:get("grid", index)
        if item ~= nil and not item:is_worn_out() then
            on_grid[item] = true
            if not self._active[item] then
                self:_activate(item)
            end
        end
    end
    for item in pairs(self._active) do
        if not on_grid[item] then
            EventBus.unsubscribe_owner(item)
            self._active[item] = nil
        end
    end
end

function ItemEffects:_activate(item)
    for _, effect in ipairs(item:effects()) do
        local factory = HANDLERS[effect.type]
        assert(factory ~= nil, "ItemEffects: unknown effect type '" .. tostring(effect.type) .. "'")
        for _, sub in ipairs(factory(item, effect, self._ctx)) do
            EventBus.subscribe(sub.event, sub.fn, { owner = item, priority = sub.priority or 0 })
        end
    end
    self._active[item] = true
end

function ItemEffects:is_active(item)
    return self._active[item] == true
end

function ItemEffects:destroy()
    for item in pairs(self._active) do
        EventBus.unsubscribe_owner(item)
    end
    self._active = {}
    EventBus.unsubscribe_owner(self)
end

return ItemEffects
