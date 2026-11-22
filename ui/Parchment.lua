-- ui/Parchment.lua
-- 굵은 잉크 외곽선의 양피지 두루마리 (난이도 계약서). 위쪽 참나무 막대에 매달린 종이가 아래로 펼쳐진다.
--   Parchment.draw_paper(rect, unroll)  : 펼쳐진 만큼(unroll 0~1)의 종이
--   Parchment.draw_rods(rect, unroll)   : 위 막대 + 아래쪽 말린 종이 두루마리 (내용 위에 그린다)
--   Parchment.bottom(rect, unroll)      : 지금 펼쳐진 종이의 아래 끝 y (내용 시저용)

local Draw = require("ui.Draw")
local TRANSITIONS = require("data.transitions")

local Parchment = {}

local LG = love.graphics
local PAPER = { 0.86, 0.77, 0.58 }
local PAPER_EDGE = { 0.52, 0.37, 0.20 }
local WOOD = { 0.32, 0.19, 0.10 }
local WOOD_LIGHT = { 0.52, 0.34, 0.18 }
local INK = TRANSITIONS.ink
local OUTLINE = TRANSITIONS.outline
local ROD_H = 22
local ROLL_H = 30
local STAINS = { { 0.06, 0.88, 46 }, { 0.93, 0.12, 34 }, { 0.78, 0.82, 26 }, { 0.2, 0.18, 22 } }

Parchment.INK = { 0.20, 0.12, 0.07 }
Parchment.RED_INK = { 0.62, 0.12, 0.10 }
Parchment.EDGE = PAPER_EDGE

function Parchment.bottom(rect, unroll)
    return rect.y + rect.h * math.max(0, math.min(1, unroll))
end

function Parchment.draw_paper(rect, unroll)
    local h = Parchment.bottom(rect, unroll) - rect.y
    if h <= 0 then
        return
    end
    Draw.set_color(INK, 0.45)
    LG.rectangle("fill", rect.x + 12, rect.y + 14, rect.w, h)
    Draw.set_color(PAPER)
    LG.rectangle("fill", rect.x, rect.y, rect.w, h)
    for i = 1, 6 do                     -- 가장자리로 갈수록 그을린 종이
        Draw.set_color(PAPER_EDGE, 0.1)
        LG.setLineWidth(10)
        LG.rectangle("line", rect.x + i * 7, rect.y, rect.w - i * 14, h)
    end
    for _, stain in ipairs(STAINS) do
        local y = rect.y + rect.h * stain[2]
        if y < rect.y + h then
            Draw.set_color(PAPER_EDGE, 0.16)
            LG.circle("fill", rect.x + rect.w * stain[1], y, stain[3], 24)
        end
    end
    Draw.set_color(INK)
    LG.setLineWidth(OUTLINE)
    LG.line(rect.x, rect.y, rect.x, rect.y + h)
    LG.line(rect.x + rect.w, rect.y, rect.x + rect.w, rect.y + h)
end

local function rod(x, y, w, h, color)
    Draw.set_color(color)
    LG.rectangle("fill", x, y, w, h, h / 2, h / 2)
    Draw.set_color(WOOD_LIGHT, 0.6)
    LG.rectangle("fill", x + h / 2, y + 4, w - h, 4)
    Draw.set_color(INK)
    LG.setLineWidth(OUTLINE - 1)
    LG.rectangle("line", x, y, w, h, h / 2, h / 2)
end

local function knob(x, y)
    Draw.set_color(WOOD)
    LG.circle("fill", x, y, 15, 20)
    Draw.set_color(INK)
    LG.setLineWidth(OUTLINE - 1)
    LG.circle("line", x, y, 15, 20)
end

function Parchment.draw_rods(rect, unroll)
    rod(rect.x - 26, rect.y - ROD_H / 2, rect.w + 52, ROD_H, WOOD)
    knob(rect.x - 26, rect.y)
    knob(rect.x + rect.w + 26, rect.y)
    if unroll < 1 then                  -- 아직 말려 있는 종이 두루마리
        local y = Parchment.bottom(rect, unroll)
        rod(rect.x - 6, y - ROLL_H / 2, rect.w + 12, ROLL_H, PAPER)
        Draw.set_color(PAPER_EDGE, 0.5)
        LG.setLineWidth(2)
        LG.line(rect.x + 10, y + 4, rect.x + rect.w - 10, y + 4)
    else
        rod(rect.x - 26, rect.y + rect.h - ROD_H / 2, rect.w + 52, ROD_H, WOOD)
        knob(rect.x - 26, rect.y + rect.h)
        knob(rect.x + rect.w + 26, rect.y + rect.h)
    end
end

return Parchment
