-- ui/WorkshopUpgradeView.lua
-- [공방 개조] 모달 (낮): 진열장 확장(3x3 → 5x5), UV 렌즈, 고압 브러시, 용광로 안정화, 방벽 보강.

local Grid = require("systems.Grid")
local I18n = require("systems.I18n")
local Modal = require("ui.Modal")
local UPGRADES = require("data.upgrades")

local WorkshopUpgradeView = {}

function WorkshopUpgradeView.open(workshop)
    local upgrades = workshop.upgrades
    local modal
    local function rows()
        local list = {}
        for _, id in ipairs(UPGRADES.order) do
            local prefix = "upgrades." .. id
            local level = upgrades:level(id)
            local has_next = upgrades:next_level(id) ~= nil
            list[#list + 1] = {
                title = I18n.t("modal.level", { name = I18n.t(prefix .. ".name"), level = level, max = upgrades:max_level(id) }),
                text = has_next and I18n.t("modal.next", { text = I18n.t(prefix .. ".levels." .. (level + 1)) })
                    or I18n.t("modal.max_level_desc", { description = I18n.t(prefix .. ".description") }),
                button = {
                    label = function()
                        local nxt = upgrades:next_level(id)
                        return nxt and I18n.t("modal.cost_gold", { cost = nxt.cost }) or I18n.t("modal.max_level")
                    end,
                    enabled = function() return (upgrades:can_buy(id)) end,
                    reason = function() return select(2, upgrades:can_buy(id)) end,
                    on_click = function() upgrades:buy(id) end,
                },
            }
        end
        return list
    end
    modal = Modal({
        title = function() return I18n.t("modal.upgrades_title") end,
        subtitle = function()
            return I18n.t("modal.upgrades_subtitle", {
                gold = workshop.gold, stage = Grid.stage_label(upgrades:grid_stage()), max_hp = workshop.max_hp,
            })
        end,
        rows = rows,
        footer = { { label = function() return I18n.t("modal.close") end, on_click = function() modal:close() end } },
        on_cancel = function() modal:close() end,
    })
    modal.kind = "upgrades"
    return modal
end

return WorkshopUpgradeView
