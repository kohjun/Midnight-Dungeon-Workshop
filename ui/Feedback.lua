-- ui/Feedback.lua
-- 게임 이벤트 → 손맛 연출 매핑. 시스템 코드는 연출을 모른다; 여기서 EventBus 를 구독해 Effects / Hud 를 호출한다.
-- 모든 구독은 priority -100 (수정자 구독자가 끝난 뒤의 최종 값을 표시). 문구는 systems/I18n 으로 조회한다.

local Class = require("lib.classic")
local EventBus = require("core.EventBus")
local I18n = require("systems.I18n")
local Slots = require("ui.Slots")
local SpriteBank = require("ui.SpriteBank")
local FeedbackEconomy = require("ui.FeedbackEconomy")
local FeedbackBoss = require("ui.FeedbackBoss")
local FeedbackTrace = require("ui.FeedbackTrace")       -- '스승의 흔적' (은빛 인장 · 수기 · 포탈 간섭 · 봉인진)
local FeedbackHero = require("ui.FeedbackHero")         -- 주인공 장비 · 3분류 배치 (거절 · 자동 배치 · 장비 마모 · 방어/반격)
local CalendarText = require("ui.CalendarText")
local ITEMS = require("data.items")
local COMBAT = require("data.combat")
local ATTACKS = require("data.attacks")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local Feedback = Class:extend()

-- 감정 적발 낙인: 퍼지는 검은 잉크 고리 + 색 고리 두 겹 + 스파크
local function brand(fx, x, y, color)
    fx:ring(x, y, { 0.03, 0.02, 0.03 }, { from = 6, to = 92, life = 0.55, width = 10 })
    fx:ring(x, y, color, { from = 4, to = 78, life = 0.5, width = 5 })
    fx:ring(x, y, color, { from = 2, to = 40, life = 0.35, width = 3 })
    fx:burst(x, y, { count = 26, colors = { color, { 1, 1, 1 } }, speed_min = 90, speed_max = 280, shape = "spark", life_max = 0.6 })
end

local PRIORITY = -100
local C = UI.color
local SIZE = UI.font_size
local COIN_COLORS = { C.gold, { 1.0, 0.95, 0.6 }, { 0.9, 0.6, 0.15 } }
local FIRE_COLORS = { { 1.0, 0.55, 0.15 }, { 1.0, 0.85, 0.3 }, { 0.9, 0.25, 0.1 }, { 0.35, 0.3, 0.3 } }
local DUST_COLORS = { { 0.55, 0.42, 0.28 }, { 0.8, 0.7, 0.55 }, { 0.95, 0.95, 1.0 } }
local WHITE = { 1, 1, 1 }
local ARMORED = { 0.6, 0.62, 0.7 }     -- 방패병에 깎인 피해 숫자
local CRIT_NUMBER = { 1.0, 0.8, 0.22 }  -- 치명타 숫자 (금빛) · 글자 (주황)
local CRIT_LABEL = { 1.0, 0.52, 0.1 }
local SHOCK_LABEL = { 0.66, 0.64, 1.0 } -- 감전! (전격 청보라)
local SPRITE_SCALE = LAYOUT.night.sprite_scale
local SPARKLE_COLORS = { { 1, 1, 1 }, { 0.75, 0.95, 1.0 }, C.gold }

-- workshop: 유물 위치 조회용 (읽기 전용)
function Feedback:new(fx, hud, workshop)
    self._fx = fx
    self._hud = hud
    self._workshop = workshop
    self:_subscribe_workbench()
    self:_subscribe_combat()
    self:_subscribe_flow()
    FeedbackEconomy.subscribe(self)
    FeedbackBoss.subscribe(self)
    FeedbackTrace.subscribe(self)
    FeedbackHero.subscribe(self)
end

function Feedback:destroy()
    EventBus.unsubscribe_owner(self)
end

function Feedback:_on(event, handler)
    EventBus.subscribe(event, handler, { owner = self, priority = PRIORITY })
end

function Feedback:_coins(x, y, count)
    self._fx:burst(x, y, { count = count, colors = COIN_COLORS, speed_min = 80, speed_max = 260, gravity = 420,
        life_min = 0.5, life_max = 0.9, size_min = 3, size_max = 6, shape = "square" })
end

function Feedback:_subscribe_workbench()
    local fx, hud = self._fx, self._hud

    self:_on("ui:message", function(p)
        hud:toast(p.text, p.kind)
    end)
    self:_on("appraisal:customer_arrived", function(p)
        local x, y = Slots.center("bench", 1)
        fx:ring(x, y, C.text_dim, { from = 20, to = 120, life = 0.5 })
        fx:burst(x, y, { count = 14, colors = DUST_COLORS, speed_max = 160, life_max = 0.6 })
        hud:toast(I18n.t("fx.customer_arrived", { item = I18n.item_name(p.item) }), "info")
    end)
    self:_on("appraisal:grade_revealed", function(p)
        local item = p.item
        local color = ITEMS.grades[item.grade].color
        local diff = item:grade_info().rank - item:claimed_grade_info().rank
        fx:ring(p.x, p.y, color, { from = 10, to = 110, life = 0.6, width = 4 })
        local key = "fx.grade_revealed"
        if not item.owned and diff > 0 then
            key = "fx.grade_bargain"
        elseif not item.owned and diff < 0 then
            key = "fx.grade_forgery"
        end
        fx:float_text(p.x, p.y - 40, I18n.t(key, { grade = I18n.grade(item.grade) }), color, { size = SIZE.large })
    end)
    self:_on("appraisal:flaw_revealed", function(p)    -- 잉크 낙인 파동: 검은 잉크 고리 + 저주 보라 / 균열 붉은 고리 + 스파크
        local color = p.item.flaw == "curse" and C.link_curse or C.danger
        brand(fx, p.x, p.y, color)
        fx:shake(0.25)
        local key = p.item.owned and "fx.flaw_found" or "fx.flaw_found_discount"
        fx:float_text(p.x, p.y - 26, I18n.t(key, { flaw = I18n.t("flaws." .. p.item.flaw .. ".name") }), C.danger,
            { size = SIZE.body })
    end)
    self:_on("appraisal:forgery_revealed", function(p)
        brand(fx, p.x, p.y + 20, C.danger)
        fx:float_text(p.x, p.y + 70, I18n.t("combat_fx.forgery_brand", { grade = I18n.grade(p.item.grade) }), C.danger,
            { size = SIZE.body, life = 1.3, style = "crit" })
    end)
    self:_on("appraisal:scan_complete", function(p)
        if p.flawless then
            fx:float_text(p.x, p.y + 60, I18n.t("fx.scan_flawless"), C.good, { size = SIZE.body })
        end
    end)
    self:_on("appraisal:scrubbed", function(p)
        if p.distance > 2 then
            fx:burst(p.x, p.y, { count = 2, colors = DUST_COLORS, speed_min = 40, speed_max = 160, gravity = 260,
                life_min = 0.25, life_max = 0.55, size_min = 2, size_max = 4 })
        end
    end)
    self:_on("appraisal:cleaned", function(p)
        fx:burst(p.x, p.y, { count = 40, colors = SPARKLE_COLORS, speed_min = 100, speed_max = 340, shape = "spark" })
        fx:ring(p.x, p.y, { 1, 1, 1 }, { from = 20, to = 140, life = 0.6, width = 5 })
        local mult = string.format("%.2g", p.item.clean_mult or 1)
        fx:float_text(p.x, p.y - 50, I18n.t("fx.cleaned", { mult = mult }), C.good, { size = SIZE.large })
    end)
    self:_on("appraisal:item_bought", function(p)
        self:_coins(p.x, p.y, 16)
        fx:float_text(p.x, p.y - 30, string.format("-%d G", p.price), C.gold, { size = SIZE.large })
        if p.discounted then
            hud:toast(I18n.t("fx.bought_discount"), "good")
        end
    end)
    self:_on("appraisal:item_sold", function(p)
        self:_coins(p.x, p.y, 26)
        fx:float_text(p.x, p.y - 30, string.format("+%d G", p.value), C.gold, { size = SIZE.large })
    end)
    self:_on("inventory:item_moved", function(p)
        SpriteBank.pop(p.item)
        local x, y = Slots.center(p.to_area, p.to_index)
        fx:ring(x, y, C.accent, { from = 10, to = 46, life = 0.3, width = 3 })
        fx:burst(x, y, { count = 6, color = C.accent, speed_max = 120, life_max = 0.4 })
    end)
    self:_on("economy:stones_changed", function()
        hud:pulse_stones()
    end)
    self:_on("economy:gold_changed", function()
        hud:pulse_gold()
    end)
end

function Feedback:_subscribe_combat()
    local fx, hud = self._fx, self._hud
    local wall = LAYOUT.night.wall

    self:_on("forge:started", function(p)
        fx:burst(p.x, p.y, { count = 20, colors = FIRE_COLORS, speed_max = 140, gravity = -160, life_max = 0.9 })
        fx:shake(0.1)
    end)
    self:_on("forge:succeeded", function(p)
        fx:burst(p.x, p.y, { count = 70, colors = { C.gold, { 1, 1, 1 }, ITEMS.grades[p.item.grade].color },
            speed_min = 120, speed_max = 460, shape = "spark", life_max = 1.0 })
        fx:ring(p.x, p.y, C.gold, { from = 10, to = 180, life = 0.7, width = 6 })
        fx:ring(p.x, p.y, { 1, 1, 1 }, { from = 10, to = 110, life = 0.45, width = 3 })
        fx:flash(C.gold, 0.35, 0.4)
        fx:shake(0.5)
        if not p.overclock then     -- 연마석 강화의 결과 배너는 ui/ForgeDrama (내구도 100% 복구 줄 포함)
            fx:float_text(p.x + 120, p.y - 40, I18n.t("fx.forge_success", { level = p.level }), C.gold, { size = SIZE.heading, life = 1.4 })
            fx:float_text(p.x + 120, p.y - 4, I18n.t("forge_fx.restored"), C.link_boost, { size = SIZE.body, life = 1.4 })
        end
    end)
    self:_on("forge:failed", function(p)
        if p.outcome ~= "destroyed" then           -- 유지 · 하락 (연기는 ui/ForgeDrama)
            fx:float_text(p.x + 120, p.y - 40, I18n.t(p.outcome == "down" and "fx.forge_down" or "fx.forge_keep"), C.text_dim,
                { size = SIZE.large, life = 1.2 })
            return
        end
        fx:burst(p.x, p.y, { count = 90, colors = FIRE_COLORS, speed_min = 100, speed_max = 520, gravity = 300,
            life_min = 0.5, life_max = 1.2, size_min = 3, size_max = 8 })
        fx:ring(p.x, p.y, C.overclock, { from = 10, to = 200, life = 0.6, width = 8 })
        fx:flash(C.danger, 0.5, 0.5)
        fx:shake(0.9)
        fx:float_text(p.x + 120, p.y - (p.overclock and 90 or 40), I18n.t("fx.forge_fail", { scrap = p.scrap }), C.danger,
            { size = SIZE.heading, life = 1.4 })
    end)
    self:_on("combat:damage_dealt", function(p)
        -- 피격 흰 점멸·넉백은 ui/EntityMotion, 발사·피격 이펙트는 ui/AttackEffects. 숫자는 몬스터 그림(반경 x sprite_scale) 위에
        local r = p.monster.radius * SPRITE_SCALE
        local amount = string.format("%d", math.floor(p.amount + 0.5))
        if p.crit then          -- 치명타: 큰 금빛 숫자 + 주황 "치명타!" (굵은 외곽선 · 바운스)
            fx:float_text(p.x, p.y - r * 1.15, amount, CRIT_NUMBER, { size = SIZE.heading, life = 0.85, rise = 34, style = "crit" })
            fx:float_text(p.x, p.y - r * 1.85, I18n.t("combat_fx.crit"), CRIT_LABEL,
                { size = SIZE.large, life = 0.85, rise = 38, style = "crit" })
            return
        end
        fx:float_text(p.x, p.y - r, amount, p.armored and ARMORED or WHITE, { size = SIZE.small, life = 0.6, rise = 30 })
    end)
    self:_on("combat:shocked", function(p)
        local r = p.monster.radius * SPRITE_SCALE
        fx:float_text(p.x + r * 0.55, p.y - r * 1.5, I18n.t("combat_fx.shock"), SHOCK_LABEL,
            { size = SIZE.body, life = 0.7, rise = 22, style = "shock" })
    end)
    self:_on("combat:knockback", function(p)      -- 밀려난 자리에 흙먼지
        local dust = ATTACKS.knockback
        fx:burst(p.x - p.monster.radius, p.y + p.monster.radius * 0.8, { count = dust.dust, color = dust.color, speed_max = 150,
            angle = math.pi, spread = 0.8, life_max = 0.45, size_max = 5 })
    end)
    self:_on("combat:monster_killed", function(p)
        fx:burst(p.x, p.y, { count = 16, color = p.monster.spec.color, speed_max = 240, life_max = 0.6, size_max = 6 })
        fx:float_text(p.x, p.y - 24, string.format("+%d G", math.floor(p.gold + 0.5)), C.gold, { size = SIZE.body })
    end)
    self:_on("combat:wall_hit", function(p)
        fx:shake(0.35)
        fx:flash_rect(wall.x, wall.y, wall.w + 30, wall.h, C.danger, 0.3)
        fx:burst(p.x, p.y, { count = 14, colors = { C.danger, C.wall }, speed_max = 200, angle = 0, spread = 1.2 })
        fx:float_text(p.x + 40, p.y, string.format("-%d", math.floor(p.damage + 0.5)), C.danger, { size = SIZE.large })
    end)
    self:_on("combat:item_wear_warning", function(p)       -- 내구도 30% 이하: 마모 위험
        fx:float_text(p.x, p.y - 30, I18n.t("fx.wear_warning"), C.accent, { size = SIZE.small })
    end)
    self:_on("combat:item_worn_out", function(p)           -- 0%: 완전 마모 — 작동 정지 (지워지지는 않는다)
        fx:burst(p.x, p.y, { count = 36, colors = { { 0.3, 0.28, 0.3 }, { 0.55, 0.5, 0.48 }, C.danger }, speed_max = 260,
            gravity = 200, life_max = 0.9, size_max = 6, shape = "square" })
        fx:shake(0.3)
        fx:float_text(p.x, p.y - 30, I18n.t("fx.worn_out"), C.danger, { size = SIZE.body })
        hud:toast(I18n.t("fx.item_worn_out", { item = I18n.item_name(p.item) }), "bad")
    end)
    self:_on("combat:overclock_changed", function(p)
        if p.enabled then
            fx:flash(C.overclock, 0.25, 0.3)
            fx:shake(0.3)
            local rules = self._workshop.overclock_rules
            hud:toast(I18n.t("fx.overclock_on", { rate = rules.rate_mult, gold = rules.gold_mult }), "bad")
        else
            hud:toast(I18n.t("fx.overclock_off"), "info")
        end
    end)
end

function Feedback:_subscribe_flow()
    local fx, hud = self._fx, self._hud

    self:_on("workshop:damaged", function(p)
        hud:pulse_hp()
        local area, index = nil, nil
        if p.item ~= nil then
            area, index = self._workshop.inventory:locate(p.item)
        end
        if p.reason == "curse" and area ~= nil then
            local x, y = Slots.center(area, index)
            fx:burst(x, y, { count = 20, color = C.link_curse, speed_max = 160 })
            fx:float_text(x, y - 30, I18n.t("fx.curse_cost", { amount = p.amount }), C.link_curse, { size = SIZE.body })
        end
    end)
    self:_on("phase:night_started", function(p)
        fx:flash({ 0.05, 0.08, 0.3 }, 0.45, 0.6)
        hud:toast(I18n.t("fx.night_started", { date = CalendarText.date(p.day), seconds = COMBAT.night.duration }), "bad")
    end)
    self:_on("combat:boss_arrived", function(p)
        fx:flash(C.danger, 0.35, 0.8)
        fx:shake(0.7)
        hud:toast(I18n.t("fx.boss_arrived", { name = I18n.t("monsters." .. p.monster.type_id) }), "bad")
    end)
    self:_on("tutorial:step_changed", function(p)
        if p.index > 1 then
            fx:flash(C.accent, 0.12, 0.3)
        end
    end)
    self:_on("combat:overtime", function(p)           -- 새벽이 지났는데 몬스터가 남았다: 다 잡아야 셔터를 내린다
        hud:toast(I18n.t("fx.overtime", { count = p.remaining }), "warn")
    end)
    self:_on("combat:monsters_fled", function(p)
        hud:toast(I18n.t("fx.monsters_fled", { count = p.count }), "info")
    end)
    self:_on("phase:day_started", function(p)
        fx:flash({ 1, 0.85, 0.55 }, 0.3, 0.6)
        if p.income > 0 then
            local x, y = LAYOUT.hud.gold.cx, LAYOUT.hud.gold.cy + 60
            self:_coins(x, y, 30)
            fx:float_text(x, y - 40, I18n.t("fx.daily_income", { amount = p.income }), C.gold, { size = SIZE.heading, life = 1.6 })
        end
        hud:toast(I18n.t("fx.morning", { date = CalendarText.date(p.day), address = self._workshop:address() }), "good")
    end)
end

return Feedback
