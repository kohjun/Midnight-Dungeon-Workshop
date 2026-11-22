-- ui/GuildShopView.lua
-- 길드 보급 상점 모달 (상납 성공 직후 자동으로 열린다). [다음 날 시작]으로 닫으면 다음 날 아침이 된다.
-- 연마석은 낮 [길드] 창과 하루 구매 수량을 함께 센다 (systems/GuildShop).

local I18n = require("systems.I18n")
local Modal = require("ui.Modal")
local ITEMS = require("data.items")
local SHOP = require("data.shop")

local GuildShopView = {}

function GuildShopView.open(workshop)
    local shop = workshop.shop
    local modal
    local function rows()
        local list = {}
        for _, id in ipairs(SHOP.order) do
            local name = I18n.t("shop." .. id .. ".name")
            local row = {
                title = name, text = I18n.t("shop." .. id .. ".text"),
                button = {
                    label = function() return I18n.t("modal.cost_gold", { cost = shop:price(id) }) end,
                    enabled = function() return (shop:availability(id)) end,
                    reason = function() return select(2, shop:availability(id)) end,
                    on_click = function() shop:buy(id) end,
                },
            }
            if id == "rare_relic" and shop.relic ~= nil then
                local relic = shop.relic
                row.title = I18n.t("modal.shop_relic", { offer = name, item = I18n.item_name(relic), grade = I18n.grade(relic.grade) })
                row.text = I18n.item_description(relic)
                row.item = relic
                row.color = ITEMS.grades[relic.grade].color
            end
            list[#list + 1] = row
        end
        return list
    end
    modal = Modal({
        title = function() return I18n.t("modal.shop_title") end,
        subtitle = function()
            local supplies = workshop.supplies
            return I18n.t("modal.shop_subtitle", {
                gold = workshop.gold, stones = workshop.tempering_stones, uv = math.floor(supplies.uv), water = math.floor(supplies.water),
                hp = math.ceil(workshop.hp), max_hp = workshop.max_hp, scrolls = workshop.scrolls,
            })
        end,
        rows = rows,
        footer = { {
            label = function() return I18n.t("modal.next_day") end, style = "accent",
            on_click = function()
                workshop:close_shop()
                modal:close()
            end,
        } },
    })
    modal.kind = "shop"
    return modal
end

return GuildShopView
