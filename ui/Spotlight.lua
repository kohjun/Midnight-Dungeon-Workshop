-- ui/Spotlight.lua
-- 스포트라이트 암막: 설명 대상 사각형들만 스텐실로 뚫어 두고 나머지 화면 전체를 반투명 검정으로 덮은 뒤,
-- 뚫린 자리마다 굵은 잉크 선 + 은은하게 맥동하는 황금빛 테두리를 두른다 (ui/TutorialView). 입력은 건드리지 않는다.
--   Spotlight.draw(rects, time, dim) — rects: { {x, y, w, h}, ... } (논리 좌표, 이미 여백 포함), dim: 암막 알파 (0 이면 테두리만)

local Draw = require("ui.Draw")
local LAYOUT = require("data.layout")

local Spotlight = {}

local LG = love.graphics
local GOLD = { 1.0, 0.80, 0.34 }
local INK = { 0.03, 0.02, 0.02 }
local RADIUS = 10

Spotlight.DIM = 0.72

local function outline(r, width)
    LG.setLineWidth(width)
    LG.rectangle("line", r.x, r.y, r.w, r.h, RADIUS, RADIUS)
end

function Spotlight.draw(rects, time, dim)
    if dim > 0 and #rects > 0 then
        LG.stencil(function()
            for _, r in ipairs(rects) do
                LG.rectangle("fill", r.x, r.y, r.w, r.h, RADIUS, RADIUS)
            end
        end, "replace", 1)
        LG.setStencilTest("equal", 0)
        LG.setColor(0, 0, 0, dim)
        LG.rectangle("fill", 0, 0, LAYOUT.screen.w, LAYOUT.screen.h)
        LG.setStencilTest()
    end
    local pulse = 0.5 + 0.5 * math.sin(time * 5)
    for _, r in ipairs(rects) do
        Draw.set_color(GOLD, 0.12 + 0.16 * pulse)
        outline({ x = r.x - 3, y = r.y - 3, w = r.w + 6, h = r.h + 6 }, 8)
        Draw.set_color(INK, 0.9)
        outline(r, 4)
        Draw.set_color(GOLD, 0.6 + 0.4 * pulse)
        outline(r, 2.5)
    end
end

return Spotlight
