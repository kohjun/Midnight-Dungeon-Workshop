-- ui/FeedbackMaster.lua
-- '스승의 흔적' 최종 보스(균열의 잔영) 이벤트 → 연출. ui/FeedbackBoss.subscribe 가 붙인다 (feedback:_on / _fx / _hud).
-- 경고·결말 배너와 레인 아래 체력 띠는 ui/MasterBossView · ui/MasterBossHud(배너 시각은 ui/EntityMotion 이 기록),
-- 룬 사슬 덮개는 ui/RuneChainView, 효과음은 data/audio.lua 가 맡는다.
--   boss:master_arrived  : 보랏빛 섬광 · 흔들림 · 균열 고리 두 겹 · 은빛 불티 (출현 토스트는 combat:boss_arrived 의 기믹 안내)
--   boss:lockdown        : 보스에서 그 줄까지 검보라 채찍 궤적 → 칸마다 사슬이 꽂히는 먹·룬 파편 + 흔들림 + "N행/N열" 글자 · 토스트
--   boss:lockdown_ended  : 풀린 칸마다 은빛 해방 불꽃
--   boss:aegis_raised    : 보랏빛 고리 · "균열 아이기스" 글자 · 토스트(과부하로 파훼하라)
--   boss:aegis_broken    : 돔 파편이 산산이 흩어짐 + 흰 섬광 · 흔들림 · "아이기스 파훼! 그로기" 굵은 글자 · 토스트
--   boss:groggy_ended    : 옅은 보랏빛 고리
--   master:final_resolved: 봉인(은청) / 미봉인(검붉은) 섬광 · 흔들림 · 레인 가운데 불티

local I18n = require("systems.I18n")
local Slots = require("ui.Slots")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local FeedbackMaster = {}

local C = UI.color
local SIZE = UI.font_size
local NIGHT = LAYOUT.night
local INK = { 0.05, 0.03, 0.07 }
local WHITE = { 1, 1, 1 }
local VIOLET = { 0.62, 0.38, 1.00 }
local SILVER = { 0.82, 0.90, 1.00 }
local AMBER = { 1.00, 0.80, 0.30 }
local LASH_POINTS = 14

-- 몸통 가운데 (그림 크기 = 반경 × sprite_scale)
local function body_center(p)
    local r = p.monster.radius * NIGHT.sprite_scale
    return p.x, p.y - r * 0.5, r
end

local function line_name(axis, line)
    return I18n.t(axis == "row" and "trace.boss.row" or "trace.boss.col", { n = line })
end

function FeedbackMaster.subscribe(feedback)
    local fx, hud = feedback._fx, feedback._hud
    local function on(event, handler)
        feedback:_on(event, handler)
    end

    on("boss:master_arrived", function(p)
        local x, y = body_center(p)
        fx:flash(VIOLET, 0.5, 1.1)
        fx:shake(0.85)
        fx:ring(x, y, VIOLET, { from = 30, to = 300, life = 1.0, width = 9 })
        fx:ring(x, y, SILVER, { from = 10, to = 180, life = 0.7, width = 4 })
        fx:burst(x, y, { count = 48, colors = { VIOLET, SILVER, INK }, speed_min = 80, speed_max = 360, shape = "spark", life_max = 0.9 })
    end)
    on("boss:lockdown", function(p)
        for i = 0, LASH_POINTS do                     -- 보스에서 진열장 줄까지 뻗는 채찍 궤적
            local t = i / LASH_POINTS
            local lx = p.from_x + (p.x - p.from_x) * t
            local ly = p.from_y + (p.y - p.from_y) * t - math.sin(t * math.pi) * 60
            fx:burst(lx, ly, { count = 3, colors = { VIOLET, INK }, speed_min = 10, speed_max = 60, life_min = 0.25 + t * 0.2,
                life_max = 0.5 + t * 0.25, size_min = 2, size_max = 4 })
        end
        for _, index in ipairs(p.cells) do            -- 칸마다 사슬이 꽂히는 파편
            local x, y = Slots.center("grid", index)
            fx:burst(x, y, { count = 10, colors = { VIOLET, INK, SILVER }, speed_min = 60, speed_max = 220, shape = "square",
                gravity = 300, life_max = 0.55, size_min = 2, size_max = 5 })
            fx:ring(x, y, VIOLET, { from = 6, to = 44, life = 0.35, width = 3 })
        end
        local x, y = Slots.center("grid", p.cells[3])
        fx:shake(0.4)
        fx:float_text(x, y - 34, line_name(p.axis, p.line), VIOLET, { size = SIZE.large, life = 1.2, style = "crit" })
        hud:toast(I18n.t("trace.boss.lockdown", { line = line_name(p.axis, p.line) }), "bad")
    end)
    on("boss:lockdown_ended", function(p)
        for _, index in ipairs(p.cells) do
            local x, y = Slots.center("grid", index)
            fx:burst(x, y, { count = 7, colors = { SILVER, WHITE }, speed_min = 40, speed_max = 150, shape = "spark", life_max = 0.4 })
        end
    end)
    on("boss:aegis_raised", function(p)
        local x, y, r = body_center(p)
        fx:ring(x, y, VIOLET, { from = r * 0.6, to = r * 2.8, life = 0.7, width = 7 })
        fx:burst(x, y, { count = 26, colors = { VIOLET, SILVER }, speed_min = 60, speed_max = 240, shape = "spark", life_max = 0.6 })
        fx:float_text(x, y - r * 2, I18n.t("trace.boss.aegis"), VIOLET, { size = SIZE.large, life = 1.3, style = "crit" })
        fx:shake(0.3)
        hud:toast(I18n.t("trace.boss.aegis_hint"), "warn")
    end)
    on("boss:aegis_broken", function(p)
        local x, y, r = body_center(p)
        fx:burst(x, y, { count = 70, colors = { VIOLET, SILVER, WHITE }, speed_min = 160, speed_max = 520, gravity = 420,
            life_min = 0.5, life_max = 1.1, size_min = 3, size_max = 8, shape = "square" })
        fx:burst(x, y, { count = 30, colors = { SILVER, WHITE }, speed_min = 200, speed_max = 600, shape = "spark", life_max = 0.6 })
        fx:ring(x, y, WHITE, { from = r, to = r * 4, life = 0.6, width = 6 })
        fx:ring(x, y, VIOLET, { from = r * 0.5, to = r * 3, life = 0.9, width = 10 })
        fx:flash({ 0.92, 0.88, 1.0 }, 0.5, 0.5)
        fx:shake(0.7)
        fx:float_text(x, y - r * 2.2, I18n.t("trace.boss.aegis_broken"), AMBER, { size = SIZE.heading, life = 1.7, style = "crit" })
        hud:toast(I18n.t("trace.boss.aegis_broken"), "good")
    end)
    on("boss:groggy_ended", function(p)
        local x, y, r = body_center(p)
        fx:ring(x, y, VIOLET, { from = r, to = r * 1.8, life = 0.45, width = 3 })
    end)
    on("master:final_resolved", function(p)
        local sealed = p.slain and p.lit >= p.total
        local lane = NIGHT.lane
        local x, y = lane.x + lane.w / 2, lane.y + LAYOUT.master_boss.banner_y
        fx:flash(sealed and SILVER or C.danger, 0.55, 1.4)
        fx:shake(sealed and 0.6 or 0.9)
        fx:burst(x, y, { count = 60, colors = sealed and { SILVER, WHITE, VIOLET } or { C.danger, INK, VIOLET }, speed_min = 120,
            speed_max = 460, shape = "spark", life_max = 1.0 })
    end)
end

return FeedbackMaster
