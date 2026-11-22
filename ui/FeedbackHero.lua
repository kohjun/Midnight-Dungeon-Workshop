-- ui/FeedbackHero.lua
-- 주인공 장비 · 3분류 배치 연출 (ui/Feedback 이 subscribe 로 붙인다 — 이벤트는 systems/HeroEquip · systems/HeroCombat):
--   equip:rejected        : 놓을 수 없는 칸 — 붉은 거절 고리 + 짧은 흔들림 (안내 토스트는 시스템이 ui:message 로 낸다)
--   equip:routed          : 자동 배치 — 도착한 칸에 금빛 고리 + 안내 토스트 (장착 / 진열장 / 임시 거치대)
--   hero:gear_wear_warning / gear_worn_out : 주인공 장비 마모 경고 · 완전 마모 토스트
--   combat:hero_guard     : 방벽 앞에서 막아 낸 피해량 글자 / combat:hero_strike 의 반격 글자

local I18n = require("systems.I18n")
local Slots = require("ui.Slots")
local LaneHero = require("ui.LaneHero")
local HERO = require("data.hero")
local UI = require("data.ui")

local FeedbackHero = {}

local C = UI.color
local SIZE = UI.font_size
local GOLD = { 1.0, 0.84, 0.36 }

local function slot_center(area, index)
    if area == nil or not Slots.is_visible(area) then
        return nil
    end
    return Slots.center(area, index)
end

function FeedbackHero.subscribe(feedback)
    local fx, hud = feedback._fx, feedback._hud
    local function on(event, handler)
        feedback:_on(event, handler)
    end

    on("equip:rejected", function(p)
        local x, y = slot_center(p.area, p.index)
        if x ~= nil then
            fx:ring(x, y, C.danger, { from = 30, to = 44, life = 0.3, width = 4 })
        end
        fx:shake(0.18)
    end)
    on("equip:routed", function(p)
        local x, y = slot_center(p.area, p.index)
        if x ~= nil then
            fx:ring(x, y, GOLD, { from = 8, to = 46, life = 0.4, width = 3 })
        end
        local name = I18n.item_name(p.item)
        if p.area == "hero" then
            hud:toast(I18n.t("hero.fx.equipped", { name = name, slot = I18n.t("hero.slots." .. HERO.slots[p.index]) }), "good")
        else
            hud:toast(I18n.t(p.area == "grid" and "hero.fx.routed_grid" or "hero.fx.routed_rack", { name = name }), "info")
        end
    end)
    on("hero:gear_wear_warning", function(p)
        hud:toast(I18n.t("hero.fx.gear_warning", { name = I18n.item_name(p.item), slot = I18n.t("hero.slots." .. p.slot) }), "warn")
    end)
    on("hero:gear_worn_out", function(p)
        fx:shake(0.25)
        hud:toast(I18n.t("hero.fx.gear_worn_out", { name = I18n.item_name(p.item), slot = I18n.t("hero.slots." .. p.slot) }), "bad")
    end)
    on("combat:hero_guard", function(p)
        local x, ground_y, height = LaneHero.anchor()
        fx:float_text(x + 10, ground_y - height - 6, I18n.t("hero.fx.guard", { amount = string.format("%.1f", p.blocked) }), GOLD,
            { size = SIZE.small })
    end)
    on("combat:hero_strike", function(p)
        if p.counter then
            fx:float_text(p.x, p.y - 34, I18n.t("hero.fx.counter"), GOLD, { size = SIZE.small })
        end
    end)
end

return FeedbackHero
