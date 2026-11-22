-- ui/TransitionSeal.lua
-- 화면 전환 그림 (ui/TransitionManager 가 MODES 를 합친다): 굵은 검은 잉크 외곽선의 다크 판타지 도구들.
--   wax_seal  : 황동 도장이 내리꽂혀 붉은 밀랍 인장을 찍고(타격음·흔들림·밀랍 파편), 인장에서 검은 잉크가 파동치며 번져 덮는다
--   lens_iris : 황동 감정 확대경 조리개(스텐실)가 중앙으로 닫히고, 암전 순간 UV 십자 눈금이 번쩍인 뒤 다시 열린다
-- 각 모드: on_<phase>(c, fx, play) · update(c, dt, fx, play) · draw(c, sw, sh). c = 전환 상태 (phase, t, spec, x, y, time)

local Draw = require("ui.Draw")
local TRANSITIONS = require("data.transitions")

local TransitionSeal = {}

local LG = love.graphics
local INK = TRANSITIONS.ink
local OUTLINE = TRANSITIONS.outline
local INK_BLOBS = 28
local SEAL_BUMPS = 11

local function clamp01(t)
    return math.max(0, math.min(1, t))
end

local function smooth(t)
    t = clamp01(t)
    return t * t * (3 - 2 * t)
end

-- 점에서 화면 가장 먼 모서리까지 거리
local function farthest(x, y, sw, sh)
    local dx, dy = math.max(x, sw - x), math.max(y, sh - y)
    return math.sqrt(dx * dx + dy * dy)
end

-- 채우기 + 잉크 외곽선
local function inked(color, draw_shape, alpha, width)
    Draw.set_color(color, alpha)
    draw_shape("fill")
    Draw.set_color(INK, alpha)
    LG.setLineWidth(width or OUTLINE * 0.8)
    draw_shape("line")
end

-- ── wax_seal ─────────────────────────────────────────────

local function draw_ink(x, y, radius, time, ripples, alpha)
    Draw.set_color(INK, alpha)
    LG.circle("fill", x, y, radius, 96)
    for i = 1, INK_BLOBS do            -- 번지는 가장자리의 잉크 방울 (가장자리가 꿈틀거린다)
        local angle = i / INK_BLOBS * math.pi * 2 + math.sin(i * 1.7) * 0.1
        local wobble = 0.04 + 0.025 * math.sin(time * 6 + i * 2.3)
        LG.circle("fill", x + math.cos(angle) * radius, y + math.sin(angle) * radius, radius * wobble + 6, 18)
    end
    for k = 1, ripples do              -- 앞쪽으로 퍼지는 파동 고리
        local ring = radius + k * 26 + (time * 90) % 26
        Draw.set_color(INK, alpha * 0.55 / k)
        LG.setLineWidth(math.max(1, 6 - k * 1.5))
        LG.circle("line", x, y, ring, 96)
    end
end

local function draw_seal(x, y, r, s, alpha)
    Draw.set_color(INK, 0.35 * alpha)
    LG.circle("fill", x + 4, y + 6, r * 1.05, 40)
    local function blob(extra, color)
        Draw.set_color(color, alpha)
        LG.circle("fill", x, y, r + extra, 40)
        for i = 1, SEAL_BUMPS do       -- 밀랍이 흘러 퍼진 불규칙한 가장자리
            local angle = i / SEAL_BUMPS * math.pi * 2 + math.sin(i * 2.1) * 0.25
            local size = r * (0.16 + 0.08 * math.sin(i * 3.7)) + extra
            LG.circle("fill", x + math.cos(angle) * r * 0.93, y + math.sin(angle) * r * 0.93, size, 16)
        end
    end
    blob(OUTLINE, INK)
    blob(0, s.wax)
    Draw.set_color(s.wax_dark, alpha)
    LG.setLineWidth(4)
    LG.circle("line", x, y, r * 0.72, 40)
    LG.setLineWidth(6)                  -- 문양: 공방 간판의 초승달 + 단검
    LG.arc("line", "open", x + r * 0.04, y, r * 0.42, math.pi * 0.55, math.pi * 1.55, 20)
    LG.setLineWidth(5)
    LG.line(x - r * 0.18, y + r * 0.34, x + r * 0.3, y - r * 0.36)
    LG.line(x - r * 0.04, y + r * 0.02, x + r * 0.14, y + r * 0.16)
    Draw.set_color({ 1, 0.85, 0.8 }, 0.28 * alpha)
    LG.setLineWidth(3)
    LG.arc("line", "open", x, y, r * 0.84, math.pi * 1.1, math.pi * 1.45, 12)
end

-- 옆에서 본 황동 도장 (밑면 중심이 0,0)
local function draw_stamp(x, y, scale, s, alpha)
    LG.push()
    LG.translate(x, y)
    LG.scale(scale)
    inked(s.brass_dark, function(mode) LG.rectangle(mode, -48, -14, 96, 14, 3, 3) end, alpha)
    inked(s.brass, function(mode) LG.polygon(mode, -38, -14, 38, -14, 28, -66, -28, -66) end, alpha)
    Draw.set_color({ 1, 0.92, 0.6 }, 0.45 * alpha)
    LG.polygon("fill", -24, -20, -16, -20, -12, -60, -18, -60)
    inked(s.brass_dark, function(mode) LG.rectangle(mode, -10, -92, 20, 28, 3, 3) end, alpha)
    inked(s.wood, function(mode) LG.circle(mode, 0, -112, 24, 28) end, alpha)
    Draw.set_color({ 1, 0.8, 0.6 }, 0.25 * alpha)
    LG.circle("fill", -8, -120, 7, 12)
    LG.pop()
end

local WAX = {}

function WAX.on_cover(c)
    c.impacted = false
end

function WAX.update(c, _, fx, play)
    local s = c.spec
    if c.phase == "cover" and not c.impacted and c.t >= s.drop then
        c.impacted = true
        play(s.sound)
        fx:shake(s.shake)
        fx:burst(c.x, c.y, { count = 26, colors = { s.wax, s.wax_dark }, speed_min = 90, speed_max = 280, life_max = 0.5, size_max = 5 })
        fx:ring(c.x, c.y, s.wax, { from = s.seal_radius * 0.8, to = s.seal_radius * 2.4, life = 0.35, width = 6 })
    end
end

function WAX.draw(c, sw, sh)
    local s = c.spec
    local cover_t = c.phase == "cover" and c.t or s.cover
    local fade = c.phase == "reveal" and 1 - smooth(c.t / s.reveal) or 1
    local grow = smooth((cover_t - s.ink_start) / (s.cover - s.ink_start))
    if grow > 0 and fade > 0 then
        local radius = (farthest(c.x, c.y, sw, sh) * 1.12 + 40) * grow ^ 1.3
        draw_ink(c.x, c.y, radius, c.time, s.ripples, fade)
    end
    if cover_t >= s.drop and fade > 0 then
        local since = cover_t - s.drop
        local squash = 1 + 0.22 * math.max(0, 1 - since / 0.14)
        draw_seal(c.x, c.y, s.seal_radius * squash * (c.phase == "reveal" and (1 - 0.2 * (1 - fade)) or 1), s, fade)
    end
    if c.phase == "cover" and c.t < s.drop + s.lift then
        local offset, scale, alpha
        if c.t < s.drop then
            local p = c.t / s.drop
            offset, scale, alpha = -150 * (1 - p * p), 1.5 - 0.5 * p * p, math.min(1, p * 3)
        else
            local p = (c.t - s.drop) / s.lift
            offset, scale, alpha = -170 * (1 - (1 - p) * (1 - p)), 1 + 0.08 * p, 1 - p
        end
        Draw.set_color(INK, 0.35 * alpha * (1 + offset / 170))
        LG.ellipse("fill", c.x, c.y + s.seal_radius * 0.3, 52 * s.stamp_size, 12, 24)
        draw_stamp(c.x, c.y + s.seal_radius * 0.3 + offset, scale * s.stamp_size, s, alpha)
    end
end

-- ── lens_iris ────────────────────────────────────────────

local function draw_ring(x, y, r, s)
    local mid = r + s.ring / 2
    Draw.set_color(INK)
    LG.setLineWidth(s.ring + OUTLINE * 2)
    LG.circle("line", x, y, mid, 96)
    Draw.set_color(s.brass)
    LG.setLineWidth(s.ring)
    LG.circle("line", x, y, mid, 96)
    Draw.set_color({ 1, 0.9, 0.55 }, 0.5)
    LG.setLineWidth(3)
    LG.circle("line", x, y, mid - s.ring * 0.25, 96)
    Draw.set_color(s.brass_dark)
    LG.setLineWidth(2)
    for i = 0, 47 do                    -- 눈금 새김
        local angle = i / 48 * math.pi * 2
        local inner = r + (i % 4 == 0 and 3 or s.ring * 0.45)
        LG.line(x + math.cos(angle) * inner, y + math.sin(angle) * inner,
            x + math.cos(angle) * (r + s.ring - 3), y + math.sin(angle) * (r + s.ring - 3))
    end
end

local function draw_reticle(x, y, s, alpha)
    LG.setBlendMode("add")
    for pass = 1, 2 do
        Draw.set_color(s.reticle, alpha * (pass == 1 and 0.3 or 0.9))
        LG.setLineWidth(pass == 1 and 7 or 2)
        LG.line(x - 300, y, x - 46, y)
        LG.line(x + 46, y, x + 300, y)
        LG.line(x, y - 220, x, y - 46)
        LG.line(x, y + 46, x, y + 220)
        LG.circle("line", x, y, 40, 40)
        LG.circle("line", x, y, 130, 64)
    end
    for i = -5, 5 do                    -- 눈금
        if i ~= 0 then
            LG.line(x + i * 52, y - 7, x + i * 52, y + 7)
            LG.line(x - 7, y + i * 40, x + 7, y + i * 40)
        end
    end
    LG.setBlendMode("alpha")
end

local IRIS = {}

function IRIS.on_cover(c, _, play)
    play(c.spec.sound)
end

function IRIS.on_reveal(c, _, play)
    play(c.spec.sound)
end

function IRIS.draw(c, sw, sh)
    local s = c.spec
    local open = 0
    if c.phase == "cover" then
        open = 1 - smooth(c.t / s.cover)
    elseif c.phase == "reveal" then
        open = smooth(c.t / s.reveal)
    end
    local r = (farthest(c.x, c.y, sw, sh) + 4) * open
    LG.stencil(function()
        if r > 0 then
            LG.circle("fill", c.x, c.y, r, 128)
        end
    end, "replace", 1)
    LG.setStencilTest("equal", 0)
    Draw.set_color(INK)
    LG.rectangle("fill", 0, 0, sw, sh)
    Draw.set_color(s.blade)
    LG.setLineWidth(4)
    local turn = (1 - open) * 1.4
    for i = 1, s.blades do              -- 조리개 날 경계선 (닫힐수록 돈다)
        local angle = i / s.blades * math.pi * 2 + turn
        LG.line(c.x + math.cos(angle) * r, c.y + math.sin(angle) * r,
            c.x + math.cos(angle + 0.9) * (r + 420), c.y + math.sin(angle + 0.9) * (r + 420))
    end
    LG.setStencilTest()
    if r > 1 then
        draw_ring(c.x, c.y, r, s)
    end
    if c.phase == "hold" then
        draw_reticle(c.x, c.y, s, math.sin(clamp01(c.t / s.flash) * math.pi))
    end
end

TransitionSeal.MODES = { wax_seal = WAX, lens_iris = IRIS }

-- 붉은 밀랍 인장 한 개 (wax_seal 색 — 계약서의 봉인된 계약 카드 등)
function TransitionSeal.draw_wax_seal(x, y, r, alpha)
    draw_seal(x, y, r, TRANSITIONS.modes.wax_seal, alpha or 1)
end

return TransitionSeal
