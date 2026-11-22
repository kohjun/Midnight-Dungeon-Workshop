-- ui/MetaUpgradeView.lua
-- [영구 능력치 강화] 모달 (타이틀·결과 화면): 장인 명성(RP)으로 6종 영구 스탯을 올린다. 즉시 save_meta.lua 에 저장된다.

local I18n = require("systems.I18n")
local MetaProgression = require("systems.MetaProgression")
local Modal = require("ui.Modal")
local META = require("data.meta")

local MetaUpgradeView = {}

function MetaUpgradeView.open()
    local modal
    local function rows()
        local list = {}
        for _, id in ipairs(META.order) do
            local stat = META.stats[id]
            list[#list + 1] = {
                title = I18n.t("modal.level", { name = I18n.t("meta." .. id .. ".name"), level = MetaProgression.level(id), max = stat.max }),
                text = I18n.t("meta." .. id .. ".text"),
                button = {
                    label = function()
                        local cost = MetaProgression.next_cost(id)
                        return cost and I18n.t("modal.cost_rp", { cost = cost }) or I18n.t("modal.max_short")
                    end,
                    enabled = function() return MetaProgression.can_upgrade(id) end,
                    reason = function()
                        return I18n.t(MetaProgression.next_cost(id) == nil and "modal.max_level" or "modal.rp_short")
                    end,
                    on_click = function() MetaProgression.upgrade(id) end,
                },
            }
        end
        return list
    end
    modal = Modal({
        title = function() return I18n.t("modal.meta_title") end,
        subtitle = function()
            return I18n.t("modal.meta_subtitle", { rp = MetaProgression.rp() })
        end,
        rows = rows,
        footer = { { label = function() return I18n.t("modal.close") end, on_click = function() modal:close() end } },
        on_cancel = function() modal:close() end,
    })
    modal.kind = "meta"
    return modal
end

return MetaUpgradeView
