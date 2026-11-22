-- ui/CursorShapes.lua
-- 커스텀 커서 도안 (코드로 그린다, 그림 파일 없음). 다크 판타지 그래픽노블 화풍:
-- 그림자 → 옅은 테두리(halo, 어두운 배경에서도 보이게) → 부위마다 [굵은 검은 잉크 외곽선 → 채우기] → 세부 선.
-- 뒤에 그린 부위의 잉크선이 앞 부위 위에 겹쳐서 부위 사이에도 잉크 경계가 남는다.
--   default  : 흑요석 날 + 황동 코등이 단검 포인터 (끝 = 핫스팟)
--   hover    : default + 금빛 외곽 발광 (확대는 data/cursors 의 scale)
--   grab     : 펼친 가죽 장갑 / grabbing : 보라 유물을 쥔 가죽 장갑
--   appraise : UV 보라 십자 눈금이 옅게 비치는 황동 확대경 (렌즈 중심 = 핫스팟)
--   web_cut  : 은제 단검 (거미줄 끊기)
-- 좌표는 32 단위 도안 상자. CursorShapes.draw 는 핫스팟을 원점에 두고 그린다 (배율·기울기는 ui/CursorManager).
-- 다각형은 모두 볼록 다각형이다 (love.graphics.polygon "fill").

local Draw = require("ui.Draw")
local CURSORS = require("data.cursors")

local CursorShapes = {}

local LG = love.graphics

local function poly(fill, pts) return { kind = "poly", fill = fill, pts = pts } end
local function circle(fill, x, y, r) return { kind = "circle", fill = fill, x = x, y = y, r = r } end
local function rrect(fill, cx, cy, w, h, r, angle)
    return { kind = "rrect", fill = fill, cx = cx, cy = cy, w = w, h = h, r = r, angle = angle or 0 }
end
local function ring(fill, x, y, r, w) return { kind = "ring", fill = fill, x = x, y = y, r = r, w = w } end
local function line(color, width, pts, alpha) return { kind = "line", color = color, width = width, pts = pts, alpha = alpha } end
local function dot(color, x, y, r, alpha) return { kind = "dot", color = color, x = x, y = y, r = r, alpha = alpha } end

-- 단검: 끝이 (0,0), 몸통이 +y 방향
local function dagger(origin, rotate)
    return {
        origin = origin, rotate = rotate,
        parts = {
            poly("blade", { 0, 0, 3.3, 8.5, 3.0, 16.5, -3.0, 16.5, -3.3, 8.5 }),
            rrect("grip", 0, 23.4, 4.4, 7.4, 1.2),
            circle("pommel", 0, 28.6, 2.6),
            circle("guard_dark", -8.1, 18.1, 1.8),
            circle("guard_dark", 8.1, 18.1, 1.8),
            poly("guard", { -8, 16.3, 8, 16.3, 6.6, 19.9, -6.6, 19.9 }),
        },
        details = {
            line("sheen", 1.1, { 0, 2.6, 0, 15.2 }),
            line("edge", 0.8, { 1.1, 3.6, 2.3, 9, 2.1, 15 }, 0.85),
            line("halo", 0.8, { -6.2, 17.3, 6.2, 17.3 }, 0.45),
            line("grip_dark", 0.9, { -2.2, 21.0, 2.2, 22.3 }),
            line("grip_dark", 0.9, { -2.2, 23.3, 2.2, 24.6 }),
            line("grip_dark", 0.9, { -2.2, 25.6, 2.2, 26.8 }),
            dot("glint", 0, 28.6, 1.0),
        },
    }
end

local function glove_cuff(parts, details, cy)
    parts[#parts + 1] = rrect("cuff", 16, cy, 13.5, 6, 1.5)
    for _, x in ipairs({ 11.5, 16, 20.5 }) do
        details[#details + 1] = dot("stud", x, cy, 1.15)
    end
end

local function open_glove()
    local parts = {
        rrect("leather", 11.2, 9.8, 4.2, 11, 2.1, -0.12),
        rrect("leather", 15.4, 8.4, 4.4, 12.5, 2.2, -0.03),
        rrect("leather", 19.6, 9.4, 4.2, 11.4, 2.1, 0.08),
        rrect("leather", 23.4, 12.2, 3.6, 8.6, 1.8, 0.22),
        rrect("leather", 7.2, 19.6, 4.4, 9.5, 2.2, -0.85),
        poly("leather", { 9, 15, 23, 15, 23.6, 22, 20.5, 26.5, 11.5, 26.5, 8.5, 22 }),
    }
    local details = {
        line("leather_dark", 0.9, { 13.2, 15.4, 13.2, 19 }, 0.8),
        line("leather_dark", 0.9, { 17.6, 15.4, 17.6, 19 }, 0.8),
        line("stitch", 0.7, { 10.5, 21.5, 12, 21.6 }, 0.75), line("stitch", 0.7, { 13.5, 21.7, 15, 21.8 }, 0.75),
        line("stitch", 0.7, { 16.5, 21.8, 18, 21.7 }, 0.75), line("stitch", 0.7, { 19.5, 21.6, 21, 21.4 }, 0.75),
    }
    glove_cuff(parts, details, 28.6)
    return { origin = { 0, 0 }, rotate = 0, parts = parts, details = details }
end

local function fist_glove()
    local parts = {
        poly("relic", { 16, 2.6, 21.6, 8.8, 16, 15.5, 10.4, 8.8 }),
        poly("leather", { 8.5, 14.5, 24.5, 14.5, 24, 23, 20.5, 27, 11.5, 27, 8.5, 22.5 }),
        rrect("leather", 10.7, 15.0, 4.6, 6.4, 2.2),
        rrect("leather", 14.9, 14.2, 4.6, 6.6, 2.2),
        rrect("leather", 19.1, 14.4, 4.6, 6.4, 2.2),
        rrect("leather", 23.0, 16.0, 4.2, 5.6, 2.0),
        rrect("leather", 13.4, 20.4, 10.5, 4.3, 2.1, 0.14),
    }
    local details = {
        line("relic_rim", 0.9, { 10.4, 8.8, 16, 2.6, 21.6, 8.8 }),
        line("relic_light", 0.8, { 12.6, 8.8, 16, 4.8, 19.4, 8.8 }, 0.8),
        line("relic_light", 0.7, { 16, 4.8, 16, 11 }, 0.55),
        line("stitch", 0.7, { 10.5, 24.4, 12, 24.6 }, 0.7), line("stitch", 0.7, { 13.5, 24.7, 15, 24.8 }, 0.7),
        line("stitch", 0.7, { 16.5, 24.8, 18, 24.7 }, 0.7), line("stitch", 0.7, { 19.5, 24.5, 21, 24.2 }, 0.7),
    }
    glove_cuff(parts, details, 28.8)
    return { origin = { 0, 0 }, rotate = 0, parts = parts, details = details }
end

local function magnifier()
    local glass = circle("glass", 13, 13, 8)
    glass.alpha, glass.halo, glass.ink = 0.42, false, false
    return {
        origin = { 0, 0 }, rotate = 0,
        parts = {
            rrect("handle", 25.4, 25.4, 4.8, 11.2, 2.0, -0.785),
            rrect("ferrule", 20.9, 20.9, 6.2, 3.6, 1.0, -0.785),
            glass,
            ring("rim", 13, 13, 9.6, 3.4),
        },
        details = {
            line("handle_dark", 0.9, { 22.6, 26.1, 26.1, 22.6 }, 0.85),
            line("handle_dark", 0.9, { 24.6, 28.1, 28.1, 24.6 }, 0.85),
            line("rim_dark", 0.8, { 4.6, 13, 6.0, 13 }, 0.8),
            line("rim_dark", 0.8, { 20.0, 13, 21.4, 13 }, 0.8),
            line("rim_dark", 0.8, { 13, 4.6, 13, 6.0 }, 0.8),
            line("rim_dark", 0.8, { 13, 20.0, 13, 21.4 }, 0.8),
        },
    }
end

local SHAPES = {
    default = dagger({ 3, 2 }, -0.52),
    grab = open_glove(),
    grabbing = fist_glove(),
    appraise = magnifier(),
    web_cut = dagger({ 3, 3 }, -0.78),
}
SHAPES.hover = SHAPES.default

local _shadow = nil      -- 그림자 패스: 모든 색을 이 알파의 검정으로

local function set_color(pal, key, alpha)
    if _shadow ~= nil then
        LG.setColor(0, 0, 0, _shadow)
        return
    end
    local c = pal[key] or pal.ink
    LG.setColor(c[1], c[2], c[3], alpha or 1)
end

local function draw_rrect(mode, p)
    LG.push()
    LG.translate(p.cx, p.cy)
    LG.rotate(p.angle)
    LG.rectangle(mode, -p.w / 2, -p.h / 2, p.w, p.h, p.r, p.r)
    LG.pop()
end

local function fill_part(p)
    if p.kind == "poly" then
        LG.polygon("fill", p.pts)
    elseif p.kind == "circle" then
        LG.circle("fill", p.x, p.y, p.r, 24)
    elseif p.kind == "rrect" then
        draw_rrect("fill", p)
    else
        LG.setLineWidth(p.w)
        LG.circle("line", p.x, p.y, p.r, 40)
    end
end

-- inner: 고리의 안쪽 가장자리도 그을지 (잉크 패스만)
local function outline_part(p, width, inner)
    LG.setLineWidth(width)
    if p.kind == "poly" then
        LG.polygon("line", p.pts)
    elseif p.kind == "circle" then
        LG.circle("line", p.x, p.y, p.r, 24)
    elseif p.kind == "rrect" then
        draw_rrect("line", p)
    else
        LG.circle("line", p.x, p.y, p.r + p.w / 2, 40)
        if inner then
            LG.circle("line", p.x, p.y, p.r - p.w / 2, 40)
        end
    end
end

local function draw_details(shape, pal)
    for _, d in ipairs(shape.details) do
        set_color(pal, d.color, d.alpha)
        if d.kind == "line" then
            LG.setLineWidth(d.width)
            LG.line(d.pts)
        else
            LG.circle("fill", d.x, d.y, d.r, 12)
        end
    end
end

local function draw_body(shape, pal)
    if _shadow ~= nil then          -- 그림자는 채우기만 (겹친 선 때문에 얼룩지지 않게)
        set_color(pal, "ink")
        for _, p in ipairs(shape.parts) do
            fill_part(p)
        end
        return
    end
    set_color(pal, "halo", 0.55)
    for _, p in ipairs(shape.parts) do
        if p.halo ~= false then
            outline_part(p, CURSORS.halo_width, false)
        end
    end
    for _, p in ipairs(shape.parts) do
        if p.ink ~= false then
            set_color(pal, "ink")
            outline_part(p, CURSORS.ink_width, true)
        end
        set_color(pal, p.fill, p.alpha)
        fill_part(p)
    end
    draw_details(shape, pal)
end

-- 움직이는 세부: 금빛 발광 · UV 십자 눈금 · 날끝 반짝임 · 유물 반짝임 (상자 좌표, 회전 전)
local EXTRAS = {
    hover = function(pal, time, glow)
        Draw.glow(14, 15, 21, CURSORS.states.hover.glow, (0.55 + 0.2 * math.sin(time * 5)) * glow)
    end,
    appraise = function(pal, time)
        local pulse = 0.4 + 0.25 * math.sin(time * 4)
        set_color(pal, "uv", pulse)
        LG.setLineWidth(0.9)
        LG.line(6.2, 13, 11.4, 13)
        LG.line(14.6, 13, 19.8, 13)
        LG.line(13, 6.2, 13, 11.4)
        LG.line(13, 14.6, 13, 19.8)
        LG.circle("line", 13, 13, 3.4, 20)
        set_color(pal, "shine", 0.55)
        LG.setLineWidth(1.1)
        LG.arc("line", "open", 13, 13, 6, 3.6, 4.6, 10)
    end,
    grabbing = function(pal, time)
        local twinkle = 0.5 + 0.5 * math.sin(time * 6)
        set_color(pal, "relic_light", 0.4 + 0.5 * twinkle)
        LG.setLineWidth(0.8)
        LG.line(19.5, 3.2, 19.5, 6.6)
        LG.line(17.8, 4.9, 21.2, 4.9)
    end,
}

local function tip_glint(pal, time)
    local twinkle = math.max(0, math.sin(time * 3.1))
    if twinkle > 0.05 then
        set_color(pal, "glint", 0.7 * twinkle)
        LG.setLineWidth(0.8)
        LG.line(-2.6 * twinkle, 1.2, 2.6 * twinkle, 1.2)
        LG.line(0, 1.2 - 2.6 * twinkle, 0, 1.2 + 2.6 * twinkle)
    end
end

function CursorShapes.has(name)
    return SHAPES[name] ~= nil
end

-- name: data/cursors 의 상태 이름, time: 초(움직이는 세부), glow: hover 발광 0~1
function CursorShapes.draw(name, time, glow)
    local shape, spec = SHAPES[name], CURSORS.states[name]
    assert(shape ~= nil and spec ~= nil, "CursorShapes: unknown cursor '" .. tostring(name) .. "'")
    local pal = spec.palette
    LG.push("all")
    LG.setLineJoin("bevel")
    LG.translate(-spec.hotspot[1], -spec.hotspot[2])
    if name == "hover" then
        EXTRAS.hover(pal, time, glow or 1)
    end
    for pass = 1, 2 do
        _shadow = pass == 1 and CURSORS.shadow.alpha or nil
        LG.push()
        if pass == 1 then
            LG.translate(CURSORS.shadow.x, CURSORS.shadow.y)
        end
        LG.translate(shape.origin[1], shape.origin[2])
        LG.rotate(shape.rotate)
        draw_body(shape, pal)
        if pass == 2 and (name == "default" or name == "hover" or name == "web_cut") then
            tip_glint(pal, time)
        end
        LG.pop()
    end
    _shadow = nil
    if EXTRAS[name] ~= nil and name ~= "hover" then
        EXTRAS[name](pal, time)
    end
    LG.pop()
end

return CursorShapes
