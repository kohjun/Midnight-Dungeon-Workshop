-- ui/ItemShapesExtra.lua
-- 확장 유물 14종 도형 (화염·번개·저주·황금 아키타입). 규칙은 ui/ItemShapes.lua 와 같다.
-- 다각형은 모두 볼록(convex)해야 한다 (love.graphics.polygon "fill" 제약).

local ItemShapes = require("ui.ItemShapes")

local LG = love.graphics
local paint, circle = ItemShapes.paint, ItemShapes.circle
local METAL, DARK, SHINE = ItemShapes.METAL, ItemShapes.DARK, ItemShapes.SHINE
local GOLD = { 1.0, 0.82, 0.3 }

local Extra = {}

function Extra.musket(p, s)
    paint(p.primary, s)
    LG.polygon("fill", -0.42, 0.18, -0.12, 0.06, -0.06, 0.2, -0.36, 0.34)
    paint(METAL, s)
    LG.polygon("fill", -0.14, 0.04, 0.44, -0.3, 0.48, -0.22, -0.08, 0.14)
    paint(p.accent, s)
    circle("fill", 0.46, -0.27, 0.06)
    paint(DARK, s)
    LG.rectangle("fill", -0.16, 0.08, 0.1, 0.12)
end

function Extra.brazier(p, s)
    paint(p.primary, s)
    LG.polygon("fill", -0.34, -0.06, 0.34, -0.06, 0.24, 0.22, -0.24, 0.22)
    LG.rectangle("fill", -0.05, 0.22, 0.1, 0.14)
    LG.polygon("fill", -0.22, 0.44, 0.22, 0.44, 0.1, 0.34, -0.1, 0.34)
    paint(p.accent, s)
    LG.polygon("fill", -0.22, -0.06, -0.1, -0.4, 0.0, -0.06)
    LG.polygon("fill", -0.04, -0.06, 0.08, -0.46, 0.2, -0.06)
    paint(GOLD, s)
    LG.polygon("fill", -0.08, -0.06, 0.02, -0.26, 0.12, -0.06)
end

function Extra.feather(p, s)
    paint(p.primary, s)
    LG.polygon("fill", 0.0, -0.46, 0.2, -0.2, 0.14, 0.18, -0.02, 0.32, -0.14, 0.12, -0.16, -0.22)
    paint(p.accent, s)
    LG.polygon("fill", 0.0, -0.3, 0.1, -0.12, 0.04, 0.12, -0.08, -0.1)
    paint(METAL, s)
    LG.setLineWidth(0.025)
    LG.line(0.02, -0.4, -0.04, 0.46)
end

function Extra.core(p, s)
    paint(DARK, s)
    LG.polygon("fill", -0.3, -0.1, 0.0, -0.4, 0.3, -0.1, 0.3, 0.2, 0.0, 0.42, -0.3, 0.2)
    paint(p.primary, s)
    circle("fill", 0, 0.03, 0.26)
    paint(p.accent, s)
    circle("fill", 0, 0.03, 0.15)
    paint(GOLD, s)
    circle("fill", -0.05, -0.03, 0.06)
end

function Extra.rod(p, s)
    paint(METAL, s)
    LG.rectangle("fill", -0.035, -0.28, 0.07, 0.72)
    paint(p.primary, s)
    LG.polygon("fill", 0, -0.48, 0.09, -0.3, -0.09, -0.3)
    LG.rectangle("fill", -0.12, 0.36, 0.24, 0.08, 0.02, 0.02)
    paint(p.accent, s)
    LG.setLineWidth(0.03)
    LG.line(-0.18, -0.36, -0.1, -0.24, -0.2, -0.16, -0.12, -0.04)
    LG.line(0.18, -0.36, 0.1, -0.24, 0.2, -0.16, 0.12, -0.04)
end

function Extra.coil(p, s)
    paint(DARK, s)
    LG.rectangle("fill", -0.06, -0.44, 0.12, 0.88, 0.03, 0.03)
    paint(p.primary, s)
    for i = 0, 4 do
        LG.rectangle("fill", -0.26, -0.36 + i * 0.16, 0.52, 0.08, 0.04, 0.04)
    end
    paint(p.accent, s)
    circle("fill", 0, -0.44, 0.07)
    circle("fill", 0, 0.44, 0.07)
end

function Extra.fins(p, s)
    paint(p.primary, s)
    LG.rectangle("fill", -0.36, 0.22, 0.72, 0.14, 0.03, 0.03)
    for i = 0, 4 do
        LG.rectangle("fill", -0.32 + i * 0.15, -0.38, 0.08, 0.6)
    end
    paint(p.accent, s)
    LG.rectangle("fill", -0.36, -0.06, 0.72, 0.05)
    paint(SHINE, s)
    LG.rectangle("fill", -0.3, -0.36, 0.03, 0.3)
end

function Extra.idol(p, s)
    paint(p.primary, s)
    LG.polygon("fill", -0.2, 0.44, 0.2, 0.44, 0.16, -0.06, -0.16, -0.06)
    circle("fill", 0, -0.22, 0.2)
    paint(p.accent, s)
    circle("fill", -0.07, -0.24, 0.045)
    circle("fill", 0.07, -0.24, 0.045)
    LG.polygon("fill", -0.08, 0.1, 0.08, 0.1, 0, 0.26)
    paint(DARK, s)
    LG.rectangle("fill", -0.28, 0.38, 0.56, 0.08, 0.02, 0.02)
end

function Extra.scythe(p, s)
    paint(DARK, s)
    LG.polygon("fill", -0.06, 0.46, 0.0, 0.46, 0.14, -0.4, 0.08, -0.4)
    paint(METAL, s)
    LG.polygon("fill", 0.08, -0.44, 0.14, -0.36, -0.2, -0.2, -0.36, -0.12)
    paint(p.accent, s)
    LG.polygon("fill", -0.2, -0.22, -0.08, -0.28, -0.3, -0.14)
    circle("fill", 0.05, 0.1, 0.04)
end

function Extra.lantern(p, s)
    paint(DARK, s)
    LG.rectangle("fill", -0.2, -0.3, 0.4, 0.06)
    LG.rectangle("fill", -0.22, 0.32, 0.44, 0.08)
    paint(p.primary, s)
    LG.rectangle("fill", -0.18, -0.24, 0.36, 0.56, 0.04, 0.04)
    paint(p.accent, s)
    circle("fill", 0, 0.06, 0.12)
    paint(METAL, s)
    LG.setLineWidth(0.03)
    LG.arc("line", "open", 0, -0.32, 0.12, math.pi, math.pi * 2, 12)
end

function Extra.scroll(p, s)
    paint(p.primary, s)
    LG.rectangle("fill", -0.28, -0.32, 0.56, 0.64)
    paint(DARK, s)
    LG.rectangle("fill", -0.34, -0.4, 0.68, 0.1, 0.05, 0.05)
    LG.rectangle("fill", -0.34, 0.3, 0.68, 0.1, 0.05, 0.05)
    paint(p.accent, s)
    LG.setLineWidth(0.03)
    LG.line(-0.18, -0.18, 0.18, -0.18)
    LG.line(-0.18, -0.06, 0.12, -0.06)
    circle("fill", 0.1, 0.14, 0.08)
end

function Extra.gauntlet(p, s)
    paint(p.primary, s)
    LG.polygon("fill", -0.24, 0.0, 0.24, 0.0, 0.2, 0.3, -0.2, 0.3)
    LG.rectangle("fill", -0.18, 0.3, 0.36, 0.16, 0.03, 0.03)
    for i = 0, 3 do
        LG.rectangle("fill", -0.22 + i * 0.115, -0.38, 0.09, 0.4, 0.04, 0.04)
    end
    paint(p.accent, s)
    LG.rectangle("fill", -0.2, 0.34, 0.4, 0.04)
    paint(SHINE, s)
    circle("fill", 0, 0.14, 0.06)
end

function Extra.scale(p, s)
    paint(p.primary, s)
    LG.rectangle("fill", -0.03, -0.38, 0.06, 0.74)
    LG.rectangle("fill", -0.36, -0.3, 0.72, 0.05)
    LG.polygon("fill", -0.16, 0.44, 0.16, 0.44, 0.06, 0.34, -0.06, 0.34)
    paint(p.accent, s)
    LG.polygon("fill", -0.44, 0.02, -0.2, 0.02, -0.26, 0.1, -0.38, 0.1)
    LG.polygon("fill", 0.2, 0.02, 0.44, 0.02, 0.38, 0.1, 0.26, 0.1)
    paint(METAL, s)
    LG.setLineWidth(0.015)
    LG.line(-0.34, -0.26, -0.42, 0.02)
    LG.line(-0.34, -0.26, -0.22, 0.02)
    LG.line(0.34, -0.26, 0.22, 0.02)
    LG.line(0.34, -0.26, 0.42, 0.02)
end

function Extra.golem(p, s)
    paint(p.primary, s)
    LG.rectangle("fill", -0.22, -0.12, 0.44, 0.42, 0.06, 0.06)
    LG.rectangle("fill", -0.14, -0.38, 0.28, 0.24, 0.05, 0.05)
    LG.rectangle("fill", -0.36, -0.08, 0.12, 0.3, 0.04, 0.04)
    LG.rectangle("fill", 0.24, -0.08, 0.12, 0.3, 0.04, 0.04)
    LG.rectangle("fill", -0.18, 0.3, 0.13, 0.16)
    LG.rectangle("fill", 0.05, 0.3, 0.13, 0.16)
    paint(p.accent, s)
    circle("fill", 0, 0.08, 0.1)
    circle("fill", -0.06, -0.27, 0.03)
    circle("fill", 0.06, -0.27, 0.03)
end

return Extra
