-- ui/EndingSceneKit.lua
-- 엔딩 연출 공용 도구 (ui/EndingScenes · ui/EndingScenesTrace · ui/EndingSceneGate — 원화가 없을 때도 그릴 수 있게 도형만):
--   Kit.smooth(t)                         : 0~1 부드러운 계단
--   Kit.sky_mesh(top, bottom)             : 위→아래 두 색 하늘 (꼭짓점 색 그라데이션 메시 — 띠 줄무늬 없음) → Kit.draw_mesh(mesh)
--   Kit.shade_mesh(alpha)                 : 일러스트 위아래 그늘 (위 22% 는 0.6 배, 아래 55% 는 alpha 까지 제곱으로 짙어진다)
--   Kit.glow(x, y, radius, color, alpha)  : 부드러운 원형 빛 (가산, 동심원 계단 없는 메시)
--   Kit.ridge(rng, base_y, amp, step)     : 먼 산등성이 꼭짓점 목록 (연출 난수) → Kit.draw_ridge(points, color, alpha)
--   Kit.rays(x, y, color, alpha, time, opts) : 한 점에서 퍼지는 가산 빛살 (해 · 창문 빛)
--   Kit.sprite(name, x, y, size, opts)    : 장면 스프라이트 (없으면 false — 호출 측이 도형으로 대신 그린다)
--   Kit.house(cx, ground, size, opts)     : 공방 실루엣 (building_workshop 스프라이트가 없을 때) — 불 켜진 창 · 간판

local Viewport = require("core.Viewport")
local Draw = require("ui.Draw")
local SpriteBank = require("ui.SpriteBank")

local Kit = {}

local LG = love.graphics
local SKY_ROWS = 24
local GLOW_SEGMENTS = 48
local GLOW_RINGS = { { 0, 1 }, { 0.18, 0.7 }, { 0.4, 0.36 }, { 0.65, 0.12 }, { 1, 0 } }     -- (반지름 비율, 세기) ≈ (1 - r)²
local _glow_mesh = nil

function Kit.smooth(t)
    t = math.max(0, math.min(1, t))
    return t * t * (3 - 2 * t)
end

-- 줄 단위 그라데이션 메시: rows = { { y, r, g, b, a }, ... } (위에서 아래로)
local function strip(rows)
    local sw, vertices = Viewport.width(), {}
    for _, row in ipairs(rows) do
        vertices[#vertices + 1] = { 0, row[1], 0, 0, row[2], row[3], row[4], row[5] }
        vertices[#vertices + 1] = { sw, row[1], 1, 0, row[2], row[3], row[4], row[5] }
    end
    return LG.newMesh(vertices, "strip", "static")
end

function Kit.sky_mesh(top, bottom)
    local sh, rows = Viewport.height(), {}
    for i = 0, SKY_ROWS do
        local c = Draw.lerp_color(top, bottom, (i / SKY_ROWS) ^ 1.4)
        rows[#rows + 1] = { i / SKY_ROWS * sh, c[1], c[2], c[3], 1 }
    end
    return strip(rows)
end

function Kit.shade_mesh(alpha)
    local sh, rows = Viewport.height(), {}
    for i = 0, 8 do
        local k = i / 8
        rows[#rows + 1] = { k * sh * 0.22, 0, 0, 0, alpha * 0.6 * (1 - k) ^ 2 }
    end
    for i = 0, 12 do
        local k = i / 12
        rows[#rows + 1] = { sh * 0.45 + k * sh * 0.55, 0, 0, 0, alpha * k * k }
    end
    return strip(rows)
end

function Kit.draw_mesh(mesh, alpha)
    LG.setColor(1, 1, 1, alpha or 1)
    LG.draw(mesh)
end

local function glow_mesh()
    local vertices = {}
    local function add(radius, power, angle)
        vertices[#vertices + 1] = { math.cos(angle) * radius, math.sin(angle) * radius, 0, 0, 1, 1, 1, power }
    end
    for ring = 1, #GLOW_RINGS - 1 do
        local inner, outer = GLOW_RINGS[ring], GLOW_RINGS[ring + 1]
        for s = 0, GLOW_SEGMENTS - 1 do
            local a0, a1 = s / GLOW_SEGMENTS * math.pi * 2, (s + 1) / GLOW_SEGMENTS * math.pi * 2
            add(inner[1], inner[2], a0)
            add(outer[1], outer[2], a0)
            add(outer[1], outer[2], a1)
            add(inner[1], inner[2], a0)
            add(outer[1], outer[2], a1)
            add(inner[1], inner[2], a1)
        end
    end
    return LG.newMesh(vertices, "triangles", "static")
end

function Kit.glow(x, y, radius, color, alpha)
    _glow_mesh = _glow_mesh or glow_mesh()
    LG.setBlendMode("add")
    LG.setColor(color[1], color[2], color[3], alpha)
    LG.draw(_glow_mesh, x, y, 0, radius, radius)
    LG.setBlendMode("alpha")
end

function Kit.ridge(rng, base_y, amp, step)
    local points, x = {}, -40
    while x < Viewport.width() + 80 do
        points[#points + 1] = { x = x, y = base_y - rng:float(0.15, 1) * amp }
        x = x + rng:float(step * 0.6, step * 1.4)
    end
    return points
end

-- 꼭짓점 사이를 바닥까지 사다리꼴로 채운다 (오목한 다각형을 피하려고)
function Kit.draw_ridge(points, color, alpha)
    local bottom = Viewport.height()
    Draw.set_color(color, alpha)
    for i = 1, #points - 1 do
        local a, b = points[i], points[i + 1]
        LG.polygon("fill", a.x, a.y, b.x, b.y, b.x, bottom, a.x, bottom)
    end
end

-- opts: { count, from, to (각도 범위, 라디안), length, width (빛살 하나의 각도 폭) }
function Kit.rays(x, y, color, alpha, time, opts)
    opts = opts or {}
    local count, from, to = opts.count or 7, opts.from or -0.6, opts.to or 0.6
    local length, width = opts.length or 1100, opts.width or 0.05
    LG.setBlendMode("add")
    for i = 1, count do
        local angle = from + (to - from) * (i - 0.5) / count + 0.04 * math.sin(time * 0.3 + i * 1.7)
        local a = alpha * (0.55 + 0.45 * math.sin(time * 0.7 + i * 2.1))
        local cx, cy = x + math.cos(angle) * length, y + math.sin(angle) * length
        local nx, ny = -math.sin(angle) * length * width, math.cos(angle) * length * width
        Draw.set_color(color, math.max(0, a))
        LG.polygon("fill", x, y, cx + nx, cy + ny, cx - nx, cy - ny)       -- 바깥으로 갈수록 넓어지는 빛살
    end
    LG.setBlendMode("alpha")
end

-- opts: SpriteBank.draw_fit 와 같다 { alpha, flip, color }
function Kit.sprite(name, x, y, size, opts)
    local image = SpriteBank.image(name)
    if image == nil then
        return false
    end
    SpriteBank.draw_fit(image, x, y, size, opts)
    return true
end

-- 공방 실루엣: 돌 몸체 · 지붕 · 굴뚝 · 매달린 간판 · 불 켜진 창 (cx = 가운데, ground = 바닥 y, size = 높이)
-- opts: { body, roof, edge (외곽선), window (창 불빛 색), window_alpha, alpha }
function Kit.house(cx, ground, size, opts)
    local s, alpha = size / 100, opts.alpha or 1
    local edge = opts.edge or { 0.02, 0.015, 0.02 }
    local left, right, eave = cx - 34 * s, cx + 30 * s, ground - 58 * s
    Draw.set_color(edge, alpha)
    LG.rectangle("fill", left - 2, eave - 2, right - left + 4, ground - eave + 2)
    LG.polygon("fill", left - 10 * s, eave + 2, cx - 2 * s, ground - 100 * s, right + 10 * s, eave + 2)
    LG.rectangle("fill", left + 6 * s, ground - 98 * s, 12 * s, 30 * s)
    Draw.set_color(opts.body, alpha)
    LG.rectangle("fill", left, eave, right - left, ground - eave)
    LG.rectangle("fill", left + 8 * s, ground - 96 * s, 8 * s, 28 * s)
    Draw.set_color(opts.roof, alpha)
    LG.polygon("fill", left - 7 * s, eave, cx - 2 * s, ground - 96 * s, right + 7 * s, eave)
    Draw.set_color(edge, alpha)                                       -- 간판 걸이와 간판
    LG.setLineWidth(math.max(1, 1.6 * s))
    LG.line(right, eave + 6 * s, right + 16 * s, eave + 6 * s)
    LG.rectangle("fill", right + 6 * s, eave + 8 * s, 13 * s, 15 * s)
    for _, window in ipairs({ { -18, -44 }, { 6, -44 }, { -16, -22 } }) do
        local wx, wy = cx + window[1] * s, ground + window[2] * s
        Kit.glow(wx + 4 * s, wy + 6 * s, 20 * s, opts.window, (opts.window_alpha or 1) * 0.6 * alpha)
        Draw.set_color(opts.window, (opts.window_alpha or 1) * alpha)
        LG.rectangle("fill", wx, wy, 8 * s, 12 * s)
    end
    Draw.set_color(edge, alpha)                                       -- 문
    LG.rectangle("fill", cx + 8 * s, ground - 26 * s, 12 * s, 26 * s)
end

return Kit
