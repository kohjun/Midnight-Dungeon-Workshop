-- systems/WorkshopUpgrades.lua
-- 런 내부 공방 시설 개조 레벨과 효과 조회. 정의는 data/upgrades.lua.
-- value(id, key, default): 현재 레벨 정의에 key 가 있으면 그 값, 없거나 0레벨이면 default.

local Class = require("lib.classic")
local EventBus = require("core.EventBus")
local I18n = require("systems.I18n")
local UPGRADES = require("data.upgrades")

local WorkshopUpgrades = Class:extend()

-- start_grid_stage: 영구 스탯으로 정해지는 시작 그리드 단계 (1 = 3x3)
function WorkshopUpgrades:new(workshop, start_grid_stage)
    self._workshop = workshop
    self._levels = {}
    for _, id in ipairs(UPGRADES.order) do
        self._levels[id] = 0
    end
    self._levels.grid = math.max(0, (start_grid_stage or 1) - 1)
end

local function definition(id)
    local upgrade = UPGRADES.upgrades[id]
    assert(upgrade ~= nil, "WorkshopUpgrades: unknown upgrade '" .. tostring(id) .. "'")
    return upgrade
end

function WorkshopUpgrades:level(id)
    definition(id)
    return self._levels[id]
end

function WorkshopUpgrades:max_level(id)
    return #definition(id).levels
end

function WorkshopUpgrades:grid_stage()
    return self._levels.grid + 1
end

function WorkshopUpgrades:value(id, key, default)
    local level = self:level(id)
    if level == 0 then
        return default
    end
    local value = definition(id).levels[level][key]
    if value == nil then
        return default
    end
    return value
end

-- 다음 레벨 정의 (최대면 nil)
function WorkshopUpgrades:next_level(id)
    return definition(id).levels[self:level(id) + 1]
end

-- 구매 가능 여부와 불가 사유
function WorkshopUpgrades:can_buy(id)
    local nxt = self:next_level(id)
    if nxt == nil then
        return false, I18n.t("reason.max_level")
    end
    if not self._workshop:is_day() then
        return false, I18n.t("reason.day_only")
    end
    if self._workshop.gold < nxt.cost then
        return false, I18n.t("reason.no_gold")
    end
    return true, nil
end

function WorkshopUpgrades:buy(id)
    local ok, reason = self:can_buy(id)
    if not ok then
        EventBus.emit("ui:message", { text = I18n.t("msg.cannot_upgrade", { reason = reason }), kind = "warn" })
        return false
    end
    local workshop = self._workshop
    local nxt = self:next_level(id)
    local hp_before = self:value(id, "max_hp_bonus", 0)
    workshop:spend_gold(nxt.cost, "upgrade")
    self._levels[id] = self._levels[id] + 1
    local hp_gain = self:value(id, "max_hp_bonus", 0) - hp_before
    if hp_gain > 0 then
        workshop:raise_max_hp(hp_gain)
    end
    EventBus.emit("upgrades:purchased", {
        id = id, level = self._levels[id], name = I18n.t("upgrades." .. id .. ".name"), cost = nxt.cost,
    })
    return true
end

return WorkshopUpgrades
