-- ui/ItemShapes.lua
-- 절차적 유물 도형 (원본 10종). 크기 1 기준 정규화 좌표(-0.5 ~ 0.5), p = { primary, accent } 팔레트.
-- s(silhouette) 가 true 면 색을 바꾸지 않는다 (스텐실/투시용 단색 실루엣).
-- 확장 도형은 ui/ItemShapesExtra.lua. 공용 색·도우미는 ItemShapes.METAL/DARK/SHINE/paint/circle.

local ItemShapes = {}

local LG = love.graphics
local SEGMENTS = 28
local METAL = { 0.82, 0.84, 0.88 }
local DARK = { 0.22, 0.18, 0.16 }
local SHINE = { 1, 1, 1, 0.55 }

-- silhouette 모드에서는 색을 바꾸지 않는다 (스텐실/투시용 단색 실루엣)
local function paint(color, silhouette)
    if not silhouette then
        LG.setColor(color)
    end
end

local function circle(mode, x, y, r)
    LG.circle(mode, x, y, r, SEGMENTS)
end

local SHAPES = {}

function SHAPES.sword(p, s)
    paint(METAL, s)
    LG.polygon("fill", 0, -0.47, 0.075, -0.36, 0.075, 0.16, -0.075, 0.16, -0.075, -0.36)
    paint(p.accent, s)
    LG.polygon("fill", 0, -0.40, 0.025, -0.33, 0.025, 0.12, -0.025, 0.12, -0.025, -0.33)
    paint(p.primary, s)
    LG.rectangle("fill", -0.22, 0.16, 0.44, 0.07, 0.02, 0.02)
    paint(DARK, s)
    LG.rectangle("fill", -0.04, 0.23, 0.08, 0.16)
    paint(p.primary, s)
    circle("fill", 0, 0.43, 0.055)
end

function SHAPES.dagger(p, s)
    LG.push()
    LG.translate(0, 0.06)
    LG.scale(0.78)
    SHAPES.sword(p, s)
    LG.pop()
end

function SHAPES.orb(p, s)
    paint(DARK, s)
    LG.polygon("fill", -0.2, 0.45, 0.2, 0.45, 0.13, 0.28, -0.13, 0.28)
    paint(p.primary, s)
    circle("fill", 0, -0.04, 0.33)
    paint(p.accent, s)
    circle("fill", 0, -0.04, 0.2)
    paint(SHINE, s)
    circle("fill", -0.11, -0.16, 0.07)
end

function SHAPES.crystal(p, s)
    paint(p.primary, s)
    LG.polygon("fill", 0, -0.47, 0.24, -0.2, 0.24, 0.2, 0, 0.47, -0.24, 0.2, -0.24, -0.2)
    paint(p.accent, s)
    LG.polygon("fill", 0, -0.47, 0.24, -0.2, 0, -0.05, -0.24, -0.2)
    paint(DARK, s)
    LG.polygon("fill", 0, -0.05, 0.24, 0.2, 0, 0.47)
end

function SHAPES.chalice(p, s)
    paint(p.primary, s)
    LG.polygon("fill", -0.32, -0.38, 0.32, -0.38, 0.2, 0.02, -0.2, 0.02)
    LG.rectangle("fill", -0.045, 0.02, 0.09, 0.24)
    LG.polygon("fill", -0.24, 0.42, 0.24, 0.42, 0.12, 0.26, -0.12, 0.26)
    paint(p.accent, s)
    LG.rectangle("fill", -0.32, -0.38, 0.64, 0.07)
    circle("fill", 0, -0.17, 0.065)
end

function SHAPES.crossbow(p, s)
    paint(DARK, s)
    LG.rectangle("fill", -0.055, -0.3, 0.11, 0.74, 0.03, 0.03)
    paint(p.primary, s)
    LG.setLineWidth(0.07)
    LG.arc("line", "open", 0, 0.05, 0.42, math.pi * 1.15, math.pi * 1.85, 24)
    paint(METAL, s)
    LG.setLineWidth(0.018)
    LG.line(-0.344, -0.19, 0, 0.0, 0.344, -0.19)
    paint(p.accent, s)
    LG.rectangle("fill", -0.016, -0.38, 0.032, 0.4)
    LG.polygon("fill", 0, -0.48, 0.055, -0.38, -0.055, -0.38)
end

function SHAPES.fork(p, s)
    paint(METAL, s)
    LG.rectangle("fill", -0.17, -0.44, 0.08, 0.42)
    LG.rectangle("fill", 0.09, -0.44, 0.08, 0.42)
    LG.rectangle("fill", -0.17, -0.06, 0.34, 0.08)
    LG.rectangle("fill", -0.04, 0.02, 0.08, 0.3)
    paint(p.primary, s)
    circle("fill", 0, 0.38, 0.075)
    paint(p.accent, s)
    LG.setLineWidth(0.03)
    LG.arc("line", "open", 0.17, -0.25, 0.12, -0.6, 0.6, 10)
    LG.arc("line", "open", 0.17, -0.25, 0.2, -0.6, 0.6, 12)
end

function SHAPES.crest(p, s)
    paint(p.primary, s)
    LG.polygon("fill", -0.34, -0.4, 0.34, -0.4, 0.34, 0.04, 0, 0.46, -0.34, 0.04)
    paint(DARK, s)
    LG.polygon("fill", -0.26, -0.32, 0.26, -0.32, 0.26, 0.02, 0, 0.36, -0.26, 0.02)
    paint(p.accent, s)
    LG.rectangle("fill", -0.05, -0.26, 0.1, 0.5)
    LG.rectangle("fill", -0.18, -0.12, 0.36, 0.1)
end

function SHAPES.pouch(p, s)
    paint(p.primary, s)
    circle("fill", 0, 0.12, 0.32)
    LG.polygon("fill", -0.13, -0.18, 0.13, -0.18, 0.2, -0.34, -0.2, -0.34)
    paint(p.accent, s)
    circle("fill", 0.13, -0.38, 0.075)
    circle("fill", -0.06, -0.41, 0.075)
    LG.rectangle("fill", -0.17, -0.23, 0.34, 0.07, 0.02, 0.02)
    paint(DARK, s)
    LG.rectangle("fill", -0.03, 0.0, 0.06, 0.24)
end

function SHAPES.tablet(p, s)
    paint(p.primary, s)
    LG.rectangle("fill", -0.3, -0.42, 0.6, 0.84, 0.08, 0.08)
    paint(DARK, s)
    LG.rectangle("fill", -0.24, -0.36, 0.48, 0.72, 0.05, 0.05)
    paint(p.accent, s)
    LG.setLineWidth(0.035)
    LG.line(-0.15, -0.26, -0.05, -0.16, -0.15, -0.06)
    LG.line(0.04, -0.26, 0.15, -0.26, 0.09, -0.1)
    LG.line(-0.13, 0.07, 0.13, 0.07)
    LG.line(0, 0.0, 0, 0.27)
    LG.line(-0.1, 0.2, 0.1, 0.28)
end

ItemShapes.SHAPES = SHAPES
ItemShapes.METAL = METAL
ItemShapes.DARK = DARK
ItemShapes.SHINE = SHINE
ItemShapes.paint = paint
ItemShapes.circle = circle

return ItemShapes
