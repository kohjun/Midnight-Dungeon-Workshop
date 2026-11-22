-- ui/MidBossView.lua
-- 월 중순 중간 보스의 레인 표현 (ui/LaneView 가 부른다, 규칙 계산 없음 — 수치는 data/enemies.lua 의 aura · tint · scale).
--   aura(monster, x, y, r, time) : 몸 아래 붉은/보라 잉크 오라 — 번지는 먹 얼룩 + 색 테두리 맥동 + 흩날리는 잉크 방울
--   draw_overlay(combat, lane, time): 레인 위쪽 전용 이름·체력 바 (살아 있는 중간 보스) + 출현 직후 경고 배너
--                                    (monster.age 로 시간을 잰다 — 효과음·토스트는 combat:midboss_arrived 구독자가 낸다)
-- 원화 확대(1.35배)는 스펙의 큰 반경, 색조는 ui/LaneView 의 sprite_tint 가 spec.tint 로 시작한다.

local I18n = require("systems.I18n")
local Draw = require("ui.Draw")
local Lettering = require("ui.Lettering")
local UI = require("data.ui")

local MidBossView = {}

local C = UI.color
local LG = love.graphics
local INK = { 0.04, 0.02, 0.04 }
local AURA_COLORS = { red = { 0.86, 0.12, 0.16 }, purple = { 0.62, 0.20, 0.92 } }
local BANNER_TIME = 2.2
local BAR_W, BAR_H = 400, 12

function MidBossView.aura_color(monster)
    return AURA_COLORS[monster.spec.aura] or AURA_COLORS.red
end

function MidBossView.aura(monster, x, y, r, time)
    local color = MidBossView.aura_color(monster)
    local pulse = 0.5 + 0.5 * math.sin(time * 3.4 + monster.anim)
    Draw.set_color(INK, 0.42)                      -- 먹 얼룩: 몸 아래로 번진 잉크
    LG.ellipse("fill", x, y + r * 0.2, r * 1.75, r * 1.25, 28)
    for i = 0, 5 do
        local a = i / 6 * math.pi * 2 + time * 0.6
        LG.circle("fill", x + math.cos(a) * r * 1.55, y + r * 0.2 + math.sin(a) * r * 1.05, r * (0.22 + 0.06 * math.sin(time * 2 + i)), 12)
    end
    LG.setBlendMode("add")
    Draw.set_color(color, 0.16 + 0.12 * pulse)
    LG.ellipse("fill", x, y, r * 1.6, r * 1.35, 28)
    LG.setBlendMode("alpha")
    Draw.set_color(color, 0.55 + 0.35 * pulse)
    LG.setLineWidth(2.5)
    LG.ellipse("line", x, y + r * 0.2, r * 1.7, r * 1.2, 28)
    for i = 0, 3 do                                -- 흩날리는 잉크 방울 (위로 솟았다 사라진다)
        local t = (time * 0.7 + i * 0.25) % 1
        Draw.set_color(i % 2 == 0 and INK or color, 0.8 * (1 - t))
        LG.circle("fill", x + math.sin(i * 2.3 + time) * r * 0.9, y - r * (0.4 + t * 1.6), 2.5 + i % 2, 8)
    end
end

-- 살아 있는 첫 중간 보스 (없으면 nil)
function MidBossView.alive(combat)
    for _, monster in ipairs(combat.monsters) do
        if not monster.dead and monster:is_midboss() then
            return monster
        end
    end
    return nil
end

-- 레인 위쪽 전용 바 좌표 (스모크 테스트용)
function MidBossView.bar_rect(lane)
    return { x = lane.x + (lane.w - BAR_W) / 2, y = lane.y + 44, w = BAR_W, h = BAR_H }
end

local function draw_banner(monster, lane, time)
    local t = monster.age or BANNER_TIME
    if t >= BANNER_TIME then
        return
    end
    local alpha = math.min(1, t * 5) * math.min(1, (BANNER_TIME - t) * 2.5)
    local scale = 1 + 0.3 * math.exp(-t * 7) * math.cos(t * 18)
    local cx, cy = lane.x + lane.w / 2, lane.y + 118
    local color = MidBossView.aura_color(monster)
    Draw.set_color(INK, 0.78 * alpha)
    LG.rectangle("fill", cx - 260, cy - 30, 520, 60, 10, 10)
    Draw.set_color(color, alpha * (0.7 + 0.3 * math.sin(time * 12)))
    LG.setLineWidth(3)
    LG.rectangle("line", cx - 260, cy - 30, 520, 60, 10, 10)
    LG.push()
    LG.translate(cx, cy)
    LG.scale(scale)
    Lettering.draw(I18n.t("boss.midboss_banner", { name = I18n.t("monsters." .. monster.type_id) }), -260, -20, 520, "center",
        "item_name", "blood", alpha)
    LG.pop()
end

function MidBossView.draw_overlay(combat, lane, time)
    local monster = MidBossView.alive(combat)
    if monster == nil then
        return
    end
    local r = MidBossView.bar_rect(lane)
    local color = MidBossView.aura_color(monster)
    Draw.set_color(INK, 0.72)
    LG.rectangle("fill", r.x - 10, r.y - 22, r.w + 20, r.h + 30, 8, 8)
    Draw.set_color(color, 0.8)
    LG.setLineWidth(2)
    LG.rectangle("line", r.x - 10, r.y - 22, r.w + 20, r.h + 30, 8, 8)
    local label = I18n.t("boss.midboss_bar", { name = I18n.t("monsters." .. monster.type_id) })
    Draw.label_text(label, r.x, r.y - 20, r.w, "left", Draw.fit_size(label, r.w - 90, { "label", { role = "ui", size = 12 } }), color)
    Draw.label_text(string.format("%d / %d", math.max(0, math.ceil(monster.hp)), math.ceil(monster.max_hp)), r.x, r.y - 20, r.w,
        "right", "label", C.text)
    Draw.bar(r.x, r.y, r.w, r.h, math.max(0, monster.hp) / monster.max_hp, color)
    if (monster.boost_time or 0) > 0 then          -- 돌파·돌진·오라 가속 중: 바 테두리 번쩍
        Draw.set_color({ 1, 1, 1 }, 0.5 + 0.5 * math.sin(time * 20))
        LG.rectangle("line", r.x - 1, r.y - 1, r.w + 2, r.h + 2, 3, 3)
    end
    draw_banner(monster, lane, time)
end

return MidBossView
