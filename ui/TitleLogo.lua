-- ui/TitleLogo.lua
-- 게임 제목 로고: 금박 장식 글자(ui/Lettering) + 아래 장식선(마름모·초승달) + 다른 언어 부제.
--   TitleLogo.draw(cx, top, width, alpha, scale) → 로고 블록의 아래 y

local I18n = require("systems.I18n")
local Draw = require("ui.Draw")
local Lettering = require("ui.Lettering")
local UI = require("data.ui")

local TitleLogo = {}

local LG = love.graphics
local C = UI.color
local SIZES = { 64, 56, 48 }

local function ornament(cx, y, half, alpha)
    Draw.set_color(C.accent, 0.75 * alpha)
    LG.setLineWidth(2)
    LG.line(cx - half, y, cx - 18, y)
    LG.line(cx + 18, y, cx + half, y)
    for _, side in ipairs({ -1, 1 }) do
        local x = cx + side * half
        LG.polygon("fill", x, y - 5, x + 5 * side, y, x, y + 5, x - 5 * side, y)
    end
    Draw.set_color(C.gold, alpha)
    LG.polygon("fill", cx, y - 8, cx + 8, y, cx, y + 8, cx - 8, y)
    Draw.set_color({ 0.05, 0.04, 0.07 }, alpha)
    LG.circle("fill", cx + 2, y - 1, 3.4, 12)
end

-- 제목이 한 줄에 들어가는 가장 큰 크기 (없으면 가장 작은 크기로 줄바꿈)
local function title_spec(text, width)
    for _, size in ipairs(SIZES) do
        local spec = { role = "display", size = size }
        if Draw.font(spec):getWidth(text) <= width then
            return spec
        end
    end
    return { role = "display", size = SIZES[#SIZES] }
end

function TitleLogo.draw(cx, top, width, alpha, scale)
    alpha, scale = alpha or 1, scale or 1
    local title = I18n.t("title.game_title")
    local spec = title_spec(title, width)
    local height = Lettering.height(title, width, spec)
    LG.push()
    LG.translate(cx, top + height / 2)
    LG.scale(scale)
    LG.translate(-cx, -(top + height / 2))
    Lettering.draw(title, cx - width / 2, top, width, "center", spec, "gold", alpha)
    local line_y = top + height + 12
    ornament(cx, line_y, math.min(width / 2 - 10, 230), alpha)
    Lettering.draw(I18n.t("title.subtitle"), cx - width / 2, line_y + 14, width, "center", "plate", "silver", alpha * 0.9)
    LG.pop()
    return line_y + 14 + Draw.font("plate"):getHeight()
end

return TitleLogo
