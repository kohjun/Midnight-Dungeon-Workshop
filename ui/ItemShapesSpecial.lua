-- ui/ItemShapesSpecial.lua
-- 업적 해금 특수 유물 8종 도형. 규칙은 ui/ItemShapes.lua 와 같다 (정규화 좌표 -0.5~0.5, 볼록 다각형만).
-- 스프라이트 도안 tools/sprite_art_special.py 와 실루엣이 같아야 한다.

local ItemShapes = require("ui.ItemShapes")

local LG = love.graphics
local paint, circle = ItemShapes.paint, ItemShapes.circle
local METAL, DARK, SHINE = ItemShapes.METAL, ItemShapes.DARK, ItemShapes.SHINE
local GOLD = { 1.0, 0.82, 0.3 }

local Special = {}

local function rect(x, y, w, h, r)
    LG.rectangle("fill", x, y, w, h, r or 0, r or 0)
end

function Special.hammer(p, s)
    paint(DARK, s)
    rect(-0.04, -0.12, 0.08, 0.56)
    paint(p.primary, s)
    rect(-0.34, -0.42, 0.68, 0.26, 0.04)
    circle("fill", 0, 0.45, 0.05)
    paint(p.accent, s)
    rect(-0.34, -0.42, 0.1, 0.26)
    rect(0.24, -0.42, 0.1, 0.26)
    paint(GOLD, s)
    circle("fill", 0, -0.29, 0.07)
end

function Special.goblet(p, s)
    paint(p.primary, s)
    LG.polygon("fill", -0.3, -0.36, 0.3, -0.36, 0.18, 0.04, -0.18, 0.04)
    rect(-0.04, 0.04, 0.08, 0.24)
    LG.polygon("fill", -0.22, 0.42, 0.22, 0.42, 0.1, 0.28, -0.1, 0.28)
    paint(p.accent, s)
    LG.polygon("fill", -0.26, -0.32, 0.26, -0.32, 0.22, -0.2, -0.22, -0.2)
    paint(GOLD, s)
    circle("fill", 0, -0.08, 0.09)
    paint(p.primary, s)
    circle("fill", 0.04, -0.1, 0.08)
end

function Special.crown(p, s)
    paint(p.primary, s)
    LG.polygon("fill", -0.36, 0.06, -0.3, -0.34, -0.16, 0.06)
    LG.polygon("fill", -0.12, 0.06, 0, -0.44, 0.12, 0.06)
    LG.polygon("fill", 0.16, 0.06, 0.3, -0.34, 0.36, 0.06)
    rect(-0.36, 0.04, 0.72, 0.22, 0.03)
    paint(p.accent, s)
    circle("fill", -0.22, 0.15, 0.05)
    circle("fill", 0, 0.15, 0.06)
    circle("fill", 0.22, 0.15, 0.05)
    circle("fill", 0, -0.4, 0.05)
end

function Special.heartstone(p, s)
    paint(DARK, s)
    LG.polygon("fill", 0, -0.44, 0.34, -0.18, 0.3, 0.22, 0, 0.44, -0.3, 0.22, -0.34, -0.18)
    paint(p.primary, s)
    circle("fill", -0.1, -0.06, 0.14)
    circle("fill", 0.1, -0.06, 0.14)
    LG.polygon("fill", -0.23, 0.0, 0.23, 0.0, 0, 0.28)
    paint(p.accent, s)
    circle("fill", 0, 0.0, 0.07)
end

function Special.sack(p, s)
    paint(p.primary, s)
    circle("fill", 0, 0.12, 0.3)
    LG.polygon("fill", -0.12, -0.2, 0.12, -0.2, 0.18, -0.06, -0.18, -0.06)
    LG.polygon("fill", -0.2, -0.36, 0.2, -0.36, 0.12, -0.2, -0.12, -0.2)
    paint(p.accent, s)
    rect(-0.16, -0.22, 0.32, 0.05)
    paint(GOLD, s)
    circle("fill", -0.32, 0.36, 0.08)
    circle("fill", 0.3, 0.38, 0.07)
    circle("fill", 0, 0.14, 0.09)
end

function Special.tome(p, s)
    paint(p.primary, s)
    rect(-0.3, -0.4, 0.6, 0.8, 0.04)
    paint(DARK, s)
    rect(-0.3, -0.4, 0.1, 0.8)
    paint(METAL, s)
    rect(0.26, -0.36, 0.06, 0.72)
    paint(p.accent, s)
    circle("fill", 0.04, -0.06, 0.13)
    rect(-0.02, 0.04, 0.12, 0.08)
    paint(DARK, s)
    circle("fill", -0.01, -0.07, 0.035)
    circle("fill", 0.09, -0.07, 0.035)
end

function Special.prism(p, s)
    paint(p.primary, s)
    LG.polygon("fill", 0, -0.44, 0.38, 0.32, -0.38, 0.32)
    paint(p.accent, s)
    LG.polygon("fill", 0, -0.44, 0.38, 0.32, 0.0, 0.1)
    paint(DARK, s)
    rect(-0.3, 0.32, 0.6, 0.1)
    paint(SHINE, s)
    LG.polygon("fill", -0.12, -0.1, -0.04, -0.26, -0.02, -0.04)
end

function Special.ledger(p, s)
    paint(p.primary, s)
    rect(-0.32, -0.38, 0.64, 0.76, 0.03)
    paint(GOLD, s)
    LG.polygon("fill", -0.32, -0.38, -0.18, -0.38, -0.32, -0.24)
    LG.polygon("fill", 0.32, -0.38, 0.32, -0.24, 0.18, -0.38)
    LG.polygon("fill", -0.32, 0.38, -0.32, 0.24, -0.18, 0.38)
    LG.polygon("fill", 0.32, 0.38, 0.18, 0.38, 0.32, 0.24)
    rect(0.26, -0.06, 0.1, 0.12)
    paint(p.accent, s)
    circle("fill", 0, 0, 0.13)
    paint(GOLD, s)
    circle("fill", 0, 0, 0.07)
end

return Special
