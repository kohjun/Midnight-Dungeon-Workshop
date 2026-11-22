-- ui/ResonanceSigil.lua
-- 봉인 공명 슬롯의 문양 · 공명선 · 중심 봉인 문장 (ui/ResonanceView 가 쓴다, 규칙 계산 없음 — MasterTrace 상태를 읽기만 한다).
--   glyph(archetype, cx, cy, size, color, alpha) : 계열 문양 — 화염(불꽃) · 번개(벼락) · 저주(눈) · 황금(마름모 금화), 굵은 먹 외곽선
--   lines(trace, time, complete) : 점화된 슬롯 → 가운데 칸으로 옅은 계열 색 점선 / 4칸 완성이면 은청색 공명선 + 흐르는 빛 알갱이
--   center(trace, time, complete): 가운데 칸 봉인 문장 — 슬롯 방향 마름모 4개가 점화된 만큼 계열 색으로 켜지고,
--                                  완성되면 은청 빛 + 도는 이중 고리 + 팔각 별
-- 좌표는 지금 화면 모드의 진열장 칸 (ui/Slots). 문양 모양은 단위 좌표(-0.5 ~ 0.5)의 다각형을 한 번 삼각 분할해 둔다.

local MasterTrace = require("systems.MasterTrace")
local Draw = require("ui.Draw")
local Slots = require("ui.Slots")
local ITEMS = require("data.items")

local ResonanceSigil = {}

local LG = love.graphics
local INK = { 0.03, 0.02, 0.03 }
local WHITE = { 1, 1, 1 }
local SILVER = { 0.80, 0.92, 1.00 }
local OUTLINE = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -0.7, -0.7 }, { 0.7, -0.7 }, { -0.7, 0.7 }, { 0.7, 0.7 } }

local function ellipse_points(rx, ry, count, out)
    out = out or {}
    for i = 0, count - 1 do
        local a = i / count * math.pi * 2
        out[#out + 1] = math.cos(a) * rx
        out[#out + 1] = math.sin(a) * ry
    end
    return out
end

local function almond()                       -- 저주의 눈: 위·아래 눈꺼풀 호
    local points = {}
    for i = 0, 10 do
        local t = i / 10
        points[#points + 1], points[#points + 2] = -0.46 + 0.92 * t, -0.27 * math.sin(math.pi * t)
    end
    for i = 9, 1, -1 do
        local t = i / 10
        points[#points + 1], points[#points + 2] = -0.46 + 0.92 * t, 0.27 * math.sin(math.pi * t)
    end
    return points
end

-- 계열별 다각형: body(계열 색) · inner(밝은 심 또는 먹 문양)
local POLYGONS = {
    fire = { body = { 0, -0.5, 0.2, -0.18, 0.32, 0.1, 0.26, 0.32, 0.1, 0.44, -0.1, 0.44, -0.26, 0.32, -0.32, 0.1, -0.2, -0.18 },
        inner = { 0, -0.06, 0.12, 0.12, 0.1, 0.3, -0.1, 0.3, -0.12, 0.12 }, inner_light = true },
    lightning = { body = { 0.08, -0.5, 0.32, -0.5, 0.1, -0.1, 0.28, -0.1, -0.16, 0.5, -0.02, 0.04, -0.22, 0.04 } },
    curse = { body = almond(), inner = ellipse_points(0.15, 0.15, 14) },
    gold = { body = ellipse_points(0.4, 0.4, 18), inner = { 0, -0.2, 0.14, 0, 0, 0.2, -0.14, 0 } },
}
local _triangles = {}

local function triangles(name, part)
    local key = name .. ":" .. part
    if _triangles[key] == nil then
        local polygon = POLYGONS[name][part]
        _triangles[key] = polygon and love.math.triangulate(polygon) or false
    end
    return _triangles[key] or nil
end

local function fill(list)
    for _, tri in ipairs(list) do
        LG.polygon("fill", tri)
    end
end

function ResonanceSigil.glyph(archetype, cx, cy, size, color, alpha)
    local body, inner = triangles(archetype, "body"), triangles(archetype, "inner")
    LG.push()
    LG.translate(cx, cy)
    LG.scale(size)
    local o = 2.2 / size
    Draw.set_color(INK, 0.9 * alpha)
    for _, d in ipairs(OUTLINE) do
        LG.push()
        LG.translate(d[1] * o, d[2] * o)
        fill(body)
        LG.pop()
    end
    Draw.set_color(color, alpha)
    fill(body)
    if inner ~= nil then
        Draw.set_color(POLYGONS[archetype].inner_light and Draw.lerp_color(color, WHITE, 0.65) or INK, 0.9 * alpha)
        fill(inner)
    end
    if archetype == "curse" then                  -- 세로 동공
        Draw.set_color(color, alpha)
        LG.ellipse("fill", 0, 0, 0.045, 0.12, 10)
    elseif archetype == "gold" then               -- 금화 테두리
        Draw.set_color(INK, 0.8 * alpha)
        LG.setLineWidth(0.05)
        LG.circle("line", 0, 0, 0.3, 18)
    end
    LG.pop()
end

-- 은청색 공명선: 먹 그림자 + 빛번짐 + 심 + 꼬이며 흐르는 은실 두 가닥 + 가운데로 흐르는 빛 알갱이 (반짝이는 마름모)
local function beam(sx, sy, ex, ey, time, order)
    local pulse = 0.6 + 0.4 * math.sin(time * 3 + order)
    local dx, dy = ex - sx, ey - sy
    local length = math.max(1, math.sqrt(dx * dx + dy * dy))
    local nx, ny = -dy / length, dx / length
    Draw.set_color(INK, 0.45)                     -- 밝은 타일 위에서도 선이 떠 보이게 먹 그림자
    LG.setLineWidth(6)
    LG.line(sx + dx * 0.3, sy + dy * 0.3, ex, ey)
    LG.setBlendMode("add")
    for i = 0, 5 do                               -- 유물에서 피어나듯 슬롯 쪽은 옅게
        local a, b = i / 6, (i + 1) / 6
        local x1, y1 = sx + dx * a, sy + dy * a
        local x2, y2 = sx + dx * b, sy + dy * b
        local k = 0.35 + 0.65 * b
        Draw.set_color(SILVER, 0.22 * k * pulse)
        LG.setLineWidth(12)
        LG.line(x1, y1, x2, y2)
        Draw.set_color(SILVER, 0.6 * k)
        LG.setLineWidth(3.6)
        LG.line(x1, y1, x2, y2)
        Draw.set_color(WHITE, 0.85 * k * pulse)
        LG.setLineWidth(1.4)
        LG.line(x1, y1, x2, y2)
    end
    for strand = -1, 1, 2 do                      -- 꼬이며 흐르는 은실
        local points = {}
        for i = 0, 14 do
            local t = i / 14
            local off = strand * 3.2 * math.sin(t * math.pi * 3 - time * 5 + order)
            points[#points + 1], points[#points + 2] = sx + dx * t + nx * off, sy + dy * t + ny * off
        end
        Draw.set_color(SILVER, 0.55)
        LG.setLineWidth(1.1)
        LG.line(points)
    end
    for k = 0, 2 do
        local t = (time * 0.55 + k / 3 + order * 0.21) % 1
        local px, py = sx + (ex - sx) * t, sy + (ey - sy) * t
        local s = 2.4 + 2.2 * math.sin(math.pi * t)
        Draw.set_color(SILVER, 0.4 * math.sin(math.pi * t))
        LG.circle("fill", px, py, s * 2.4, 12)
        Draw.set_color(WHITE, 0.95)
        LG.polygon("fill", px, py - s, px + s * 0.6, py, px, py + s, px - s * 0.6, py)
    end
    LG.setBlendMode("alpha")
end

-- 아직 완성 전: 점화된 슬롯에서 가운데로 향하는 옅은 계열 색 점선 (천천히 흐른다)
local function dotted(sx, sy, ex, ey, color, time)
    local dx, dy = ex - sx, ey - sy
    local length = math.sqrt(dx * dx + dy * dy)
    local step = 8
    for d = (time * 12) % step, length, step do
        local t = d / length
        local x, y = sx + dx * t, sy + dy * t
        Draw.set_color(INK, 0.55)
        LG.circle("fill", x, y, 2.8, 8)
        Draw.set_color(color, 0.45 + 0.45 * t)
        LG.circle("fill", x, y, 1.8, 8)
    end
end

-- 가운데 칸 중심 · 문장 고리 반지름
local function heart()
    local x, y, w, h = Slots.rect("grid", MasterTrace.CENTER)
    return x + w / 2, y + h / 2, w * 0.46
end

function ResonanceSigil.lines(trace, time, complete)
    local cx, cy, ring = heart()
    for _, slot in ipairs(MasterTrace.SLOTS) do
        if complete or trace:is_lit(slot.index) then
            local sx, sy = Slots.center("grid", slot.index)
            local dx, dy = cx - sx, cy - sy
            local length = math.max(1, math.sqrt(dx * dx + dy * dy))
            local ex, ey = cx - dx / length * ring, cy - dy / length * ring
            if complete then
                beam(sx, sy, ex, ey, time, slot.order)
            else
                dotted(sx, sy, ex, ey, ITEMS.archetypes[slot.archetype].color, time)
            end
        end
    end
end

-- 마름모 하나 (먹 테두리)
local function node(x, y, s, color, alpha)
    Draw.set_color(INK, 0.9 * alpha)
    LG.polygon("fill", x, y - s - 2, x + s + 2, y, x, y + s + 2, x - s - 2, y)
    Draw.set_color(color, alpha)
    LG.polygon("fill", x, y - s, x + s, y, x, y + s, x - s, y)
end

function ResonanceSigil.center(trace, time, complete)
    local cx, cy, ring = heart()
    local pulse = 0.5 + 0.5 * math.sin(time * 2.6)
    if complete then
        Draw.glow(cx, cy, ring * 2.1, SILVER, 0.5 + 0.25 * pulse)
    end
    local spin = time * (complete and 0.7 or 0.25)
    for i = 0, 11 do                              -- 바깥 고리: 끊어진 룬 호 (완성되면 은청, 아니면 먹빛)
        local a = spin + i * math.pi / 6
        Draw.set_color(INK, 0.65)
        LG.setLineWidth(4)
        LG.arc("line", "open", cx, cy, ring, a, a + 0.32, 4)
        Draw.set_color(complete and SILVER or { 0.55, 0.6, 0.68 }, complete and 0.9 or 0.35 + 0.1 * trace:lit_count())
        LG.setLineWidth(1.6)
        LG.arc("line", "open", cx, cy, ring, a, a + 0.32, 4)
    end
    if complete then
        LG.setBlendMode("add")
        Draw.set_color(SILVER, 0.55 + 0.3 * pulse)
        LG.setLineWidth(1.2)
        LG.circle("line", cx, cy, ring * 0.8, 36)
        for i = 0, 7 do                           -- 팔각 별: 마주 보는 꼭짓점을 잇는 가는 선
            local a = -spin * 0.6 + i * math.pi / 4
            local b = a + math.pi * 3 / 4
            LG.line(cx + math.cos(a) * ring * 0.78, cy + math.sin(a) * ring * 0.78, cx + math.cos(b) * ring * 0.78,
                cy + math.sin(b) * ring * 0.78)
        end
        LG.setBlendMode("alpha")
    end
    for _, slot in ipairs(MasterTrace.SLOTS) do   -- 슬롯 방향 마름모: 점화된 계열만 색으로 켜진다
        local sx, sy = Slots.center("grid", slot.index)
        local dx, dy = sx - cx, sy - cy
        local length = math.max(1, math.sqrt(dx * dx + dy * dy))
        local lit = trace:is_lit(slot.index)
        local color = lit and ITEMS.archetypes[slot.archetype].color or { 0.3, 0.3, 0.34 }
        node(cx + dx / length * ring, cy + dy / length * ring, lit and 4.5 or 3.5, complete and Draw.lerp_color(color, SILVER, 0.35) or color,
            lit and 1 or 0.7)
    end
end

return ResonanceSigil
