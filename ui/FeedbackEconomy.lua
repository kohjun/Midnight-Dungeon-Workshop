-- ui/FeedbackEconomy.lua
-- 2단계 확장 이벤트 → 연출: 상납/파산, 자원·연마석 드랍·방전, 길드 상점, 공방 개조, 암시장, 길드 의뢰, 폭발·낙뢰, 방벽 회복.
-- Feedback 이 생성 시 subscribe(feedback) 로 붙인다 (feedback:_on / _coins / _fx / _hud / _workshop 사용).

local I18n = require("systems.I18n")
local Calendar = require("systems.Calendar")
local CalendarText = require("ui.CalendarText")
local QuestText = require("ui.QuestText")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local FeedbackEconomy = {}

local C = UI.color
local SIZE = UI.font_size
local SUPPLY_KEYS = { uv = "fx.supply_uv", water = "fx.supply_water", both = "fx.supply_both", stone = "fx.supply_stone" }
local SUPPLY_COLORS = { water = C.link_boost, stone = C.stone }
local QUEST_TOASTS = {     -- 의뢰 상태 변화 → 토스트 문구 키 · 종류
    posted = { "fx.quest_posted", "info" }, accepted = { "fx.quest_accepted", "info" },
    declined = { "fx.quest_declined", "info" }, expired = { "fx.quest_expired", "warn" },
}
local GOLD = LAYOUT.hud.gold   -- 상단 HUD 의 보유 골드 위치

function FeedbackEconomy.subscribe(feedback)
    local fx, hud, workshop = feedback._fx, feedback._hud, feedback._workshop
    local on = function(event, handler)
        feedback:_on(event, handler)
    end

    on("economy:tribute_paid", function(p)
        feedback:_coins(GOLD.cx, GOLD.cy + 4, 24)
        fx:float_text(GOLD.cx, GOLD.cy + 40, I18n.t("fx.tribute_float", { amount = p.amount }), C.gold, { size = SIZE.large, life = 1.4 })
        hud:toast(I18n.t("fx.tribute_paid", { address = workshop:address(), date = CalendarText.date(p.day), amount = p.amount }), "good")
    end)
    on("economy:tribute_missed", function(p)
        fx:flash(C.danger, 0.55, 1.0)
        fx:shake(1)
        hud:toast(I18n.t("fx.tribute_missed", { amount = p.amount, shortfall = p.shortfall }), "bad")
    end)
    on("supplies:dropped", function(p)
        local text = I18n.t(SUPPLY_KEYS[p.kind], { amount = p.amount })
        local color = SUPPLY_COLORS[p.kind] or C.uv
        local colors = p.kind == "stone" and { C.stone, { 1, 1, 1 } } or { C.uv, C.link_boost, { 1, 1, 1 } }
        fx:burst(p.x, p.y, { count = p.boss and 40 or 12, colors = colors, speed_max = 200 })
        fx:float_text(p.x, p.y - 44, text, color, { size = p.boss and SIZE.large or SIZE.small, life = 1.2 })
    end)
    on("supplies:depleted", function(p)
        hud:toast(I18n.t(p.kind == "uv" and "fx.uv_depleted" or "fx.water_depleted"), "bad")
    end)
    on("supplies:low", function(p)           -- 25% 아래로: 경고 토스트 (경고음은 data/audio.lua, 게이지 맥동은 ui/WorkshopButtons)
        hud:toast(I18n.t(p.kind == "uv" and "fx.uv_low" or "fx.water_low", { value = math.floor(p.value + 0.5) }), "warn")
    end)
    on("calendar:season_changed", function(p)  -- 사계절 계약: 새 계절 효과 안내
        fx:flash(Calendar.season_color(p.season), 0.22, 0.7)
        hud:toast(I18n.t("fx.season_started", { season = CalendarText.season_name(p.season),
            effect = CalendarText.season_effect(p.workshop.rules, p.day) }), "warn")
    end)
    on("appraisal:summoned", function(p)
        local slot = LAYOUT.day.bench_slot
        fx:float_text(slot.x + slot.w / 2, slot.y + 20, I18n.t("fx.summon_cost", { cost = p.cost }), C.gold, { size = SIZE.body })
    end)
    on("appraisal:scroll_used", function(p)
        fx:ring(p.x, p.y, C.uv, { from = 20, to = 150, life = 0.6, width = 5 })
        fx:flash(C.uv, 0.15, 0.3)
    end)
    on("phase:shop_opened", function()
        hud:toast(I18n.t("fx.shop_opened"), "good")
    end)
    on("shop:purchased", function(p)
        feedback:_coins(640, 300, 14)
        hud:toast(I18n.t("fx.shop_purchased", { name = I18n.t("shop." .. p.id .. ".name"), price = p.price }), "info")
    end)
    on("upgrades:purchased", function(p)
        fx:flash(C.accent, 0.2, 0.4)
        fx:shake(0.15)
        hud:toast(I18n.t("fx.upgrade_purchased", { name = I18n.t("upgrades." .. p.id .. ".name"), level = p.level }), "good")
    end)
    on("blackmarket:event_started", function(p)
        hud:toast(I18n.t("fx.market_appeared", { name = I18n.t("events." .. p.id .. ".name") }), "bad")
    end)
    on("blackmarket:box_opened", function(p)
        local x, y = 640, 360
        if p.success then
            fx:burst(x, y, { count = 60, colors = { C.gold, { 1, 1, 1 } }, speed_max = 420, shape = "spark" })
            hud:toast(I18n.t("fx.box_success", { item = I18n.item_name(p.item), level = p.item.level }), "good")
        else
            fx:burst(x, y, { count = 60, color = C.link_curse, speed_max = 360, gravity = 200 })
            fx:shake(0.6)
            local text = p.victim and I18n.t("fx.box_bomb_item", { item = I18n.item_name(p.victim) }) or I18n.t("fx.box_bomb_wall")
            hud:toast(text, "bad")
        end
    end)
    -- 의뢰(길드 의뢰 · 암시장 제안): 이름은 source 에 따라 quests.<id>.name / events.<id>.name
    local function quest_name(p)
        if p.source == "market" or p.quest == nil then
            return I18n.t("events." .. p.id .. ".name")
        end
        return QuestText.name(p.quest)
    end
    for state, toast in pairs(QUEST_TOASTS) do
        on("quest:" .. state, function(p)
            if state ~= "accepted" or p.source == "guild" then       -- 핏빛 달 수락은 전용 연출이 있다
                hud:toast(I18n.t(toast[1], { name = quest_name(p) }), toast[2])
            end
        end)
    end
    on("quest:completed", function(p)
        local cx, cy = GOLD.cx, GOLD.cy + 4
        feedback:_coins(cx, cy, 12)
        fx:burst(LAYOUT.hud.stones.cx, LAYOUT.hud.stones.cy, { count = 24, colors = { C.stone, C.gold }, speed_max = 260 })
        hud:toast(I18n.t("fx.quest_completed", { name = quest_name(p), reward = QuestText.payout_text(p) }), "good")
    end)
    on("quest:failed", function(p)            -- 기한 초과: 위약금 (모자란 몫은 다음 결계 유지비에 가산)
        local key = (p.surcharge or 0) > 0 and "fx.quest_failed_surcharge" or ((p.paid or 0) > 0 and "fx.quest_failed_fine"
            or "fx.quest_failed")
        fx:shake(0.15)
        hud:toast(I18n.t(key, { name = quest_name(p), paid = p.paid or 0, surcharge = p.surcharge or 0 }), "bad")
    end)
    on("blackmarket:blood_moon_accepted", function()
        fx:flash(C.danger, 0.35, 0.8)
        hud:toast(I18n.t("fx.blood_moon_accepted"), "bad")
    end)
    on("blackmarket:blood_moon_cleared", function(p)
        hud:toast(I18n.t("fx.blood_moon_cleared", { discount = p.discount }), "good")
    end)
    on("combat:explosion", function(p)
        fx:burst(p.x, p.y, { count = 26, colors = { { 1.0, 0.6, 0.15 }, { 1.0, 0.9, 0.4 }, { 0.6, 0.15, 0.1 } }, speed_max = 260 })
        fx:ring(p.x, p.y, { 1.0, 0.55, 0.15 }, { from = 6, to = p.radius, life = 0.35, width = 5 })
        fx:shake(0.12)
    end)
    on("combat:thunder", function()
        fx:flash({ 0.8, 0.9, 1.0 }, 0.3, 0.25)
        fx:shake(0.3)
    end)
    on("meta:achievement_unlocked", function(p)       -- 업적 달성 → 특수 유물 해금
        local cx, cy = LAYOUT.screen.w / 2, LAYOUT.screen.h / 2
        fx:flash(C.gold, 0.3, 0.6)
        fx:ring(cx, cy, C.gold, { from = 10, to = 220, life = 0.7, width = 6 })
        fx:burst(cx, cy, { count = 40, colors = { C.gold, { 1, 1, 1 } }, speed_max = 320, life_max = 1.0 })
        hud:toast(I18n.t("achievements.unlocked_toast", {
            name = I18n.t("achievements." .. p.id .. ".name"), relic = I18n.t("items." .. p.relic .. ".name"),
        }), "good")
    end)
    on("workshop:healed", function(p)
        if p.reason ~= "shop" then
            fx:float_text(LAYOUT.night.wall.x + 50, LAYOUT.night.field.y, string.format("+%d", p.amount), C.good, { size = SIZE.small })
        end
    end)
end

return FeedbackEconomy
