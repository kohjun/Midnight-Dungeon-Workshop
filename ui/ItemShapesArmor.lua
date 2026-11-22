-- ui/ItemShapesArmor.lua
-- 방어구 도형 폴백 3종 (투구 · 갑옷 · 신발 — data/armors.lua 의 shape). 원화 assets/sprites/armor_<id>.png 가 없을 때 쓴다.
-- 좌표·팔레트 규약은 ui/ItemShapes.lua 와 같다 (크기 1 기준 -0.5 ~ 0.5, p = { primary, accent }, s = 단색 실루엣).

local ItemShapes = require("ui.ItemShapes")

local LG = love.graphics
local paint, circle = ItemShapes.paint, ItemShapes.circle
local DARK, SHINE = ItemShapes.DARK, ItemShapes.SHINE
local VOID = { 0.05, 0.04, 0.05 }

local SHAPES = {}

function SHAPES.helmet(p, s)
    paint(p.primary, s)                                -- 둥근 투구 + 볼 가리개
    LG.arc("fill", "pie", 0, -0.04, 0.34, math.pi, math.pi * 2, 24)
    LG.polygon("fill", -0.34, -0.04, 0.34, -0.04, 0.30, 0.30, 0.12, 0.38, 0.06, 0.12, -0.06, 0.12, -0.12, 0.38, -0.30, 0.30)
    paint(VOID, s)                                     -- 눈 틈
    LG.rectangle("fill", -0.20, 0.0, 0.40, 0.07, 0.02, 0.02)
    paint(p.accent, s)                                 -- 테 · 콧등
    LG.rectangle("fill", -0.36, -0.08, 0.72, 0.05, 0.02, 0.02)
    LG.rectangle("fill", -0.025, -0.36, 0.05, 0.48)
    paint(SHINE, s)
    LG.arc("line", "open", 0, -0.04, 0.27, math.pi * 1.15, math.pi * 1.45, 10)
end

function SHAPES.chest(p, s)
    paint(DARK, s)                                     -- 속옷 소매
    LG.polygon("fill", -0.44, -0.20, -0.26, -0.30, -0.22, 0.02, -0.40, 0.08)
    LG.polygon("fill", 0.44, -0.20, 0.26, -0.30, 0.22, 0.02, 0.40, 0.08)
    paint(p.primary, s)                                -- 흉갑
    LG.polygon("fill", -0.28, -0.34, -0.10, -0.40, 0.10, -0.40, 0.28, -0.34, 0.26, 0.22, 0, 0.32, -0.26, 0.22)
    LG.polygon("fill", -0.26, 0.24, 0.26, 0.24, 0.30, 0.42, -0.30, 0.42)
    paint(VOID, s)                                     -- 목 구멍
    LG.ellipse("fill", 0, -0.37, 0.10, 0.045, 16)
    paint(p.accent, s)                                 -- 허리띠 · 가운데 문양
    LG.rectangle("fill", -0.28, 0.20, 0.56, 0.06, 0.02, 0.02)
    circle("fill", 0, -0.08, 0.06)
    LG.rectangle("fill", -0.012, -0.24, 0.024, 0.34)
    paint(SHINE, s)
    LG.line(-0.20, -0.28, -0.22, 0.10)
end

function SHAPES.boots(p, s)
    for _, x in ipairs({ -0.22, 0.20 }) do
        paint(p.primary, s)                            -- 목 긴 장화 한 켤레
        LG.polygon("fill", x - 0.13, -0.36, x + 0.11, -0.36, x + 0.11, 0.14, x + 0.24, 0.26, x + 0.24, 0.36, x - 0.15, 0.36)
        paint(VOID, s)
        LG.ellipse("fill", x - 0.01, -0.36, 0.11, 0.04, 14)
        paint(p.accent, s)                             -- 발목 띠 · 밑창
        LG.rectangle("fill", x - 0.14, -0.04, 0.26, 0.05)
        paint(DARK, s)
        LG.rectangle("fill", x - 0.16, 0.36, 0.42, 0.05)
        paint(SHINE, s)
        LG.line(x - 0.08, -0.28, x - 0.09, 0.02)
    end
end

return SHAPES
