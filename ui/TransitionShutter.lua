-- ui/TransitionShutter.lua
-- 화면 전환 그림 (ui/TransitionManager 가 MODES 를 합친다): 참나무 널판 + 연철 띠의 방범 셔터 (굵은 잉크 외곽선).
--   shutter_slam : 위·아래 셔터가 가속해 내려와 중앙에서 쾅 맞물림(흔들림·먼지) → 틈새로 보라 포탈 빛이 스민 뒤 열린다
--   dawn_candle  : 셔터가 내려와 빗장이 걸린 채 정산을 기다리다 → 빗장이 옆으로 풀리고 → 셔터가 위로 걷히며 호박색 햇살·먼지
-- 각 모드: on_<phase>(c, fx, play) · update(c, dt, fx, play) · draw(c, sw, sh).

local Draw = require("ui.Draw")
local TRANSITIONS = require("data.transitions")

local TransitionShutter = {}

local LG = love.graphics
local INK = TRANSITIONS.ink
local OUTLINE = TRANSITIONS.outline
local STRAP_W = 30
local STRAPS = { 0.16, 0.84 }
local EDGE_H = 28
local BOLT_W, BOLT_H = 380, 30
local BRACKET_GAP = 130
local RAY_LAYERS = 7
local SHADE_STEPS = 6

local function clamp01(t)
    return math.max(0, math.min(1, t))
end

local function smooth(t)
    t = clamp01(t)
    return t * t * (3 - 2 * t)
end

local function rivet(x, y, s)
    Draw.set_color(INK)
    LG.circle("fill", x, y, 6, 12)
    Draw.set_color(s.iron_light)
    LG.circle("fill", x - 1, y - 1, 4, 10)
end

-- 셔터 한 짝: (0, y0) ~ (sw, y0 + h). edge = 맞물리는 쪽 ("bottom" | "top")
local function draw_panel(y0, h, sw, s, edge)
    local slat_h = (h - EDGE_H) / s.slats
    local top = edge == "top" and y0 + EDGE_H or y0
    for i = 1, s.slats do
        local y = top + (i - 1) * slat_h
        Draw.set_color(Draw.lerp_color(s.oak, s.oak_dark, (i % 2) * 0.35))
        LG.rectangle("fill", 0, y, sw, slat_h)
        Draw.set_color(s.oak_dark, 0.7)
        LG.setLineWidth(1.5)
        for k = 1, 3 do                 -- 나뭇결
            local gy = y + slat_h * k / 4 + math.sin(i * 3.1 + k) * 2
            LG.line(0, gy, sw * 0.3 + k * 90, gy + 1, sw * 0.7, gy - 1, sw, gy)
        end
        Draw.set_color(INK)
        LG.setLineWidth(3)
        LG.line(0, y, sw, y)
    end
    for _, ratio in ipairs(STRAPS) do   -- 연철 띠 + 리벳
        local x = sw * ratio - STRAP_W / 2
        Draw.set_color(s.iron)
        LG.rectangle("fill", x, top, STRAP_W, h - EDGE_H)
        Draw.set_color(s.iron_light, 0.6)
        LG.rectangle("fill", x + 4, top, 4, h - EDGE_H)
        Draw.set_color(INK)
        LG.setLineWidth(3)
        LG.rectangle("line", x, top, STRAP_W, h - EDGE_H)
        for i = 1, s.slats do
            rivet(x + STRAP_W / 2, top + (i - 0.5) * slat_h, s)
        end
    end
    for k = 1, SHADE_STEPS do           -- 맞물리는 쪽에서 멀어질수록 어두운 그늘
        local band = (h - EDGE_H) / SHADE_STEPS
        local y = edge == "top" and (y0 + h - k * band) or (y0 + (k - 1) * band)
        Draw.set_color(INK, 0.07 * k)
        LG.rectangle("fill", 0, y, sw, band)
    end
    local edge_y = edge == "top" and y0 or y0 + h - EDGE_H
    Draw.set_color(s.iron)                 -- 맞물리는 쪽 무거운 철 테두리
    LG.rectangle("fill", 0, edge_y, sw, EDGE_H)
    Draw.set_color(s.iron_light, 0.55)
    LG.rectangle("fill", 0, edge_y + 4, sw, 3)
    for x = 40, sw, 90 do
        rivet(x, edge_y + EDGE_H / 2, s)
    end
    Draw.set_color(INK)
    LG.setLineWidth(OUTLINE)
    LG.rectangle("line", -OUTLINE, edge_y, sw + OUTLINE * 2, EDGE_H)
end

-- closed: 0(열림) ~ 1(맞물림). lift: 둘을 함께 위로 걷어 올린 거리(px)
local function draw_shutters(sw, sh, s, closed, lift)
    local half = sh / 2
    lift = lift or 0
    draw_panel(-half + half * closed - lift, half, sw, s, "bottom")
    draw_panel(sh - half * closed - lift, half, sw, s, "top")
end

local function slam_burst(c, fx, play, sound, shake)
    local s = c.spec
    play(sound)
    fx:shake(shake)
    local sw, sh = c.sw, c.sh
    for i = 0, 11 do
        fx:burst(sw * (i + 0.5) / 12, sh / 2, {
            count = math.floor(s.dust / 12), colors = s.dust_colors, speed_min = 30, speed_max = 200,
            angle = (i % 2 == 0) and -math.pi / 2 or math.pi / 2, spread = math.pi * 0.45, gravity = 240, life_max = 0.9, size_max = 4,
        })
    end
end

-- ── shutter_slam ─────────────────────────────────────────

local SLAM = {}

function SLAM.on_hold(c, fx, play)
    slam_burst(c, fx, play, c.spec.sound, c.spec.shake)
end

local function portal_seam(sw, sh, s, alpha, time)
    LG.setBlendMode("add")
    local flicker = 0.75 + 0.25 * math.sin(time * 23) * math.sin(time * 7)
    Draw.set_color(s.portal, 0.55 * alpha * flicker)
    LG.rectangle("fill", 0, sh / 2 - 3, sw, 6)
    Draw.set_color(s.portal, 0.18 * alpha * flicker)
    LG.rectangle("fill", 0, sh / 2 - 14, sw, 28)
    for k = 1, RAY_LAYERS do            -- 틈새에서 위아래로 번지는 빛 (겹친 띠로 만든 부드러운 그라데이션)
        local reach = k * 16
        Draw.set_color(s.portal, 0.06 * alpha * flicker * (1 - k / (RAY_LAYERS + 1)))
        LG.rectangle("fill", 0, sh / 2 - reach, sw, reach * 2)
    end
    LG.setBlendMode("alpha")
end

function SLAM.draw(c, sw, sh)
    local s = c.spec
    if c.phase == "cover" then
        local p = clamp01(c.t / s.cover)
        draw_shutters(sw, sh, s, p * p)       -- 가속도를 받아 내려온다
    elseif c.phase == "hold" then
        draw_shutters(sw, sh, s, 1)
        portal_seam(sw, sh, s, clamp01(c.t / (s.hold * 0.6)), c.time)
    else
        local p = smooth(c.t / s.reveal)
        LG.setBlendMode("add")
        Draw.set_color(s.portal, 0.35 * (1 - p))
        LG.rectangle("fill", 0, 0, sw, sh)
        LG.setBlendMode("alpha")
        draw_shutters(sw, sh, s, 1 - p)
        portal_seam(sw, sh, s, 1 - p, c.time)
    end
end

-- ── dawn_candle ──────────────────────────────────────────

local function draw_bolt(sw, y, s, offset)
    local cx = sw / 2
    local x = cx - BOLT_W / 2 + offset
    Draw.set_color(s.iron)
    LG.rectangle("fill", x, y - BOLT_H / 2, BOLT_W, BOLT_H, 6, 6)
    Draw.set_color(s.iron_light, 0.7)
    LG.rectangle("fill", x + 8, y - BOLT_H / 2 + 5, BOLT_W - 16, 4)
    Draw.set_color(INK)
    LG.setLineWidth(OUTLINE)
    LG.rectangle("line", x, y - BOLT_H / 2, BOLT_W, BOLT_H, 6, 6)
    Draw.set_color(s.iron)              -- 손잡이 고리
    LG.circle("fill", x + BOLT_W - 4, y + 24, 16, 20)
    Draw.set_color(INK)
    LG.circle("line", x + BOLT_W - 4, y + 24, 16, 20)
    for _, bx in ipairs({ cx - BRACKET_GAP, cx + BRACKET_GAP }) do   -- 셔터에 박힌 고정 쇠
        Draw.set_color(s.iron)
        LG.rectangle("fill", bx - 18, y - 30, 36, 60, 4, 4)
        Draw.set_color(INK)
        LG.rectangle("line", bx - 18, y - 30, 36, 60, 4, 4)
        rivet(bx, y - 20, s)
        rivet(bx, y + 20, s)
    end
end

local DAWN = {}

function DAWN.on_hold(c, fx, play)
    slam_burst(c, fx, play, c.spec.sound_cover, c.spec.shake)
end

function DAWN.on_reveal(c, _, play)
    play(c.spec.sound)
end

function DAWN.update(c, dt, fx)
    local s = c.spec
    if c.phase == "reveal" and c.t > s.unbar then
        c.dust = (c.dust or 0) + dt * s.dust
        local lift = smooth((c.t - s.unbar) / (s.reveal - s.unbar)) * c.sh
        while c.dust >= 1 do            -- 걷히는 셔터 아래로 햇살 속 먼지
            c.dust, c.dust_n = c.dust - 1, (c.dust_n or 0) + 1
            fx:burst((c.dust_n * 211.7 + c.t * 97) % c.sw, c.sh - lift + 6, {
                count = 1, colors = s.dust_colors, speed_min = 10, speed_max = 60, angle = math.pi / 2, spread = math.pi,
                gravity = -12, drag = 0.6, life_min = 1.2, life_max = 2.6, size_min = 1.5, size_max = 3.5,
            })
        end
    end
end

function DAWN.draw(c, sw, sh)
    local s = c.spec
    if c.phase == "cover" then
        local p = clamp01(c.t / s.cover)
        draw_shutters(sw, sh, s, p * p)
        return
    end
    if c.phase == "hold" or c.t < s.unbar then
        local slide = c.phase == "hold" and 0 or smooth(c.t / s.unbar) * s.bolt_travel
        draw_shutters(sw, sh, s, 1)
        draw_bolt(sw, sh / 2, s, slide)
        if c.phase == "reveal" then        -- 빗장이 풀리며 틈새로 새는 첫 햇살
            LG.setBlendMode("add")
            Draw.set_color(s.amber, 0.4 * smooth(c.t / s.unbar))
            LG.rectangle("fill", 0, sh / 2 - 2, sw, 4)
            LG.setBlendMode("alpha")
        end
        return
    end
    local p = smooth((c.t - s.unbar) / (s.reveal - s.unbar))
    local lift = p * sh
    LG.setBlendMode("add")                  -- 드러난 아래쪽으로 쏟아지는 호박색 햇살
    for i = 0, 11 do
        local y = sh - lift + i * lift / 12
        Draw.set_color(Draw.lerp_color(s.amber_light, s.amber, i / 11), 0.32 * (1 - p) * (1 - i / 14))
        LG.rectangle("fill", 0, y, sw, lift / 12 + 1)
    end
    Draw.set_color(s.amber_light, 0.5 * (1 - p))
    LG.rectangle("fill", 0, sh - lift, sw, 10)
    LG.setBlendMode("alpha")
    draw_shutters(sw, sh, s, 1, lift)
    draw_bolt(sw, sh / 2 - lift, s, s.bolt_travel)
end

TransitionShutter.MODES = { shutter_slam = SLAM, dawn_candle = DAWN }

return TransitionShutter
