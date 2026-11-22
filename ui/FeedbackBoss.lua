-- ui/FeedbackBoss.lua
-- 보스 패턴·피해 규칙 이벤트 → 연출: 거미줄 봉인·해제, 골드 강탈·반환, 해골 소환, 붉은 보호막·반사, 면역 교대, 면역·방패 막힘 표시.
-- 중간 보스: 출현(섬광·흔들림·기믹 안내 토스트 — 경고 배너는 ui/MidBossView, 효과음 midboss_horn) · 돌파 · 돌진 · 역병 오라 ·
-- 처치 보상(연마석·보너스 골드). '스승의 흔적' 최종 보스(출현 · 룬 사슬 봉쇄 · 균열 아이기스 · 그로기 · 결말)는 ui/FeedbackMaster.
-- Feedback 이 생성 시 subscribe(feedback) 로 붙인다 (feedback:_on / _coins / _fx / _hud 사용).

local I18n = require("systems.I18n")
local MidBossView = require("ui.MidBossView")
local FeedbackMaster = require("ui.FeedbackMaster")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local FeedbackBoss = {}

local C = UI.color
local SIZE = UI.font_size
local WEB_COLOR = { 0.9, 0.9, 0.95 }
local IMMUNE_COLOR = { 0.75, 0.78, 0.9 }
local IMMUNE_TEXT_GAP = 0.35    -- 같은 몬스터의 "면역" 글자 최소 간격(초)

function FeedbackBoss.subscribe(feedback)
    local fx, hud = feedback._fx, feedback._hud
    local last_immune = setmetatable({}, { __mode = "k" })
    local function on(event, handler)
        feedback:_on(event, handler)
    end

    on("combat:boss_arrived", function(p)
        local pattern = p.monster.spec.pattern
        if pattern ~= nil then
            hud:toast(I18n.t("boss.hint_" .. pattern), "warn")
        end
    end)
    on("combat:midboss_arrived", function(p)
        local color = MidBossView.aura_color(p.monster)
        fx:flash(color, 0.28, 0.45)
        fx:shake(0.35)
        fx:ring(p.x, p.y, color, { from = 20, to = 160, life = 0.6, width = 6 })
        hud:toast(I18n.t("boss.hint_" .. p.monster.spec.pattern), "warn")
    end)
    on("combat:midboss_slain", function(p)
        feedback:_coins(p.x, p.y, 16)
        fx:burst(p.x, p.y, { count = 40, colors = { C.stone, C.gold, MidBossView.aura_color(p.monster) }, speed_max = 320, shape = "spark" })
        fx:float_text(p.x, p.y - 70, I18n.t("boss.midboss_reward", { gold = p.gold, stones = p.stones }), C.gold,
            { size = SIZE.large, life = 1.6 })
    end)
    on("boss:vanguard_charge", function(p)
        fx:ring(p.x, p.y, C.danger, { from = 10, to = 90, life = 0.4, width = 4 })
        fx:float_text(p.x, p.y - 60, I18n.t("boss.vanguard_charge"), C.danger, { size = SIZE.body })
    end)
    on("boss:raider_dash", function(p)
        fx:burst(p.x, p.y, { count = 14, color = C.gold, speed_max = 220, angle = 0, spread = 0.6, life_max = 0.4 })
        fx:float_text(p.x, p.y - 56, I18n.t("boss.raider_dash"), C.gold, { size = SIZE.body })
    end)
    on("boss:hex_pulse", function(p)
        fx:ring(p.x, p.y, { 0.5, 0.95, 0.4 }, { from = 12, to = p.radius, life = 0.6, width = 5 })
        fx:float_text(p.x, p.y - 60, I18n.t("boss.hex_pulse", { count = p.count }), { 0.62, 1.0, 0.52 }, { size = SIZE.body })
    end)
    on("boss:web_spun", function(p)
        fx:ring(p.x, p.y, WEB_COLOR, { from = 50, to = 6, life = 0.45, width = 3 })
        fx:burst(p.x, p.y, { count = 16, color = WEB_COLOR, speed_max = 120, life_max = 0.5, shape = "spark" })
        fx:float_text(p.x, p.y - 34, I18n.t("boss.web_spun"), C.danger, { size = SIZE.body })
        fx:shake(0.15)
    end)
    on("boss:web_struck", function(p)
        fx:burst(p.x, p.y, { count = 6, color = WEB_COLOR, speed_max = 140, life_max = 0.3, shape = "spark" })
    end)
    on("boss:web_cleared", function(p)
        fx:burst(p.x, p.y, { count = 22, color = WEB_COLOR, speed_min = 80, speed_max = 260, shape = "spark" })
        fx:float_text(p.x, p.y - 30, I18n.t("boss.web_cleared"), C.good, { size = SIZE.body })
    end)
    on("boss:gold_stolen", function(p)
        fx:float_text(p.x, p.y - 40, I18n.t("boss.gold_stolen", { amount = p.amount }), C.gold, { size = SIZE.small, life = 0.7 })
        hud:pulse_gold()
    end)
    on("boss:gold_returned", function(p)
        feedback:_coins(p.x, p.y, 40)
        fx:float_text(p.x, p.y - 50, string.format("+%d G", p.amount), C.gold, { size = SIZE.heading, life = 1.5 })
        hud:toast(I18n.t("boss.gold_returned", { amount = p.amount }), "good")
    end)
    on("boss:summoned", function(p)
        fx:burst(p.x, p.y, { count = 24, color = { 0.4, 1.0, 0.5 }, speed_max = 200, life_max = 0.6 })
        fx:ring(p.x, p.y, { 0.4, 1.0, 0.5 }, { from = 10, to = 80, life = 0.5 })
    end)
    on("boss:shield_raised", function(p)
        fx:ring(p.x, p.y, C.danger, { from = 20, to = 120, life = 0.6, width = 5 })
        fx:float_text(p.x, p.y - 60, I18n.t("boss.shield"), C.danger, { size = SIZE.body })
    end)
    on("boss:reflected", function(p)
        local wall = LAYOUT.night.wall
        fx:flash_rect(wall.x, wall.y, wall.w + 30, wall.h, C.danger, 0.2)
        fx:float_text(wall.x + 50, wall.y + wall.h / 2, I18n.t("boss.reflected", { amount = p.amount }), C.danger, { size = SIZE.small })
    end)
    on("boss:immunity_changed", function(p)
        local key = "boss.immune_" .. p.immunity
        fx:ring(p.x, p.y, IMMUNE_COLOR, { from = 20, to = 130, life = 0.6, width = 4 })
        hud:toast(I18n.t("boss.immunity_toast", { immunity = I18n.t(key) }), "bad")
    end)
    on("combat:immune", function(p)
        local now = love.timer.getTime()    -- 연출 빈도 제한용 실시간 (게임 규칙과 무관)
        if (last_immune[p.monster] or -1) + IMMUNE_TEXT_GAP <= now then
            last_immune[p.monster] = now
            fx:float_text(p.x, p.y - p.monster.radius, I18n.t("boss.immune"), IMMUNE_COLOR, { size = SIZE.small, life = 0.5, rise = 20 })
        end
    end)
    FeedbackMaster.subscribe(feedback)
end

return FeedbackBoss
