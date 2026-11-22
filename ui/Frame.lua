-- ui/Frame.lua
-- 공방 분위기의 틀: 나무/철 테두리 패널(그림자·베벨·모서리 리벳·질감), 간판(제목 판), 오목한 슬롯.
--   Frame.panel(x, y, w, h, { style = "wood"|"iron"|"ember"|"dark", title, texture, texture_alpha, alpha })
--   Frame.plate(text, cx, y, { style, min_w })    — 위 테두리에 걸친 이름표 (가운데 x 기준)
--   Frame.inset(x, y, w, h, radius, fill)          — 오목하게 파인 칸 (슬롯·게이지 홈)

local Draw = require("ui.Draw")
local Lettering = require("ui.Lettering")
local SpriteBank = require("ui.SpriteBank")
local UI = require("data.ui")

local Frame = {}

local LG = love.graphics
local C = UI.color
local RADIUS = 10
local BAND = 5              -- 테두리 띠 두께
local PLATE_H = 26
local PLATE_PAD = 22
-- 테두리 띠·내부 색 (순수 표현용)
local STYLES = {
    wood = { band = { 0.30, 0.19, 0.11 }, edge = { 0.07, 0.04, 0.03 }, fill = { 0.10, 0.08, 0.09 }, rivet = { 0.62, 0.52, 0.36 } },
    iron = { band = { 0.24, 0.24, 0.29 }, edge = { 0.05, 0.05, 0.07 }, fill = { 0.09, 0.09, 0.12 }, rivet = { 0.66, 0.68, 0.74 } },
    ember = { band = { 0.34, 0.14, 0.08 }, edge = { 0.08, 0.03, 0.02 }, fill = { 0.12, 0.06, 0.05 }, rivet = { 0.85, 0.55, 0.25 } },
    dark = { band = { 0.16, 0.14, 0.20 }, edge = { 0.03, 0.03, 0.05 }, fill = { 0.06, 0.06, 0.09 }, rivet = { 0.80, 0.65, 0.30 } },
}

local INK = { 0.03, 0.02, 0.02 }
local BRASS = { 0.84, 0.64, 0.30 }

local function style_of(name)
    local style = STYLES[name or "wood"]
    assert(style ~= nil, "Frame: unknown style '" .. tostring(name) .. "'")
    return style
end

local function rivet(x, y, color, alpha)
    Draw.set_color({ 0, 0, 0 }, 0.6 * alpha)
    LG.circle("fill", x + 1, y + 1.5, 4.2, 12)
    Draw.set_color(INK, alpha)
    LG.circle("fill", x, y, 4.2, 12)
    Draw.set_color(color, alpha)
    LG.circle("fill", x, y, 3.3, 12)
    Draw.set_color({ 1, 1, 1 }, 0.45 * alpha)
    LG.circle("fill", x - 1, y - 1, 1.1, 6)
end

function Frame.panel(x, y, w, h, opts)
    opts = opts or {}
    local style = style_of(opts.style)
    local alpha = opts.alpha or 1
    Draw.set_color({ 0, 0, 0 }, 0.45 * alpha)                         -- 그림자
    LG.rectangle("fill", x + 4, y + 6, w, h, RADIUS, RADIUS)
    Draw.set_color(INK, alpha)                                        -- 굵은 먹칠 외곽선
    LG.rectangle("fill", x - 3, y - 3, w + 6, h + 6, RADIUS + 3, RADIUS + 3)
    Draw.set_color(style.band, alpha)
    LG.rectangle("fill", x, y, w, h, RADIUS, RADIUS)
    Draw.set_color({ 1, 1, 1 }, 0.10 * alpha)                         -- 띠 윗면 반사
    LG.rectangle("fill", x + 3, y + 1, w - 6, 2, 1, 1)
    local ix, iy, iw, ih = x + BAND, y + BAND, w - BAND * 2, h - BAND * 2
    Draw.set_color(style.edge, alpha)
    LG.rectangle("fill", ix - 1, iy - 1, iw + 2, ih + 2, RADIUS - 3, RADIUS - 3)
    Draw.set_color(opts.fill or style.fill, alpha * (opts.fill_alpha or 1))
    LG.rectangle("fill", ix, iy, iw, ih, RADIUS - 4, RADIUS - 4)
    if opts.texture ~= nil then
        SpriteBank.draw_texture(opts.texture, ix, iy, iw, ih, RADIUS - 4, (opts.texture_alpha or 0.35) * alpha)
    end
    Draw.set_color({ 0, 0, 0 }, 0.35 * alpha)                         -- 안쪽 위 그늘
    LG.rectangle("fill", ix, iy, iw, 6, RADIUS - 4, RADIUS - 4)
    for _, corner in ipairs({ { x + 7, y + 7 }, { x + w - 7, y + 7 }, { x + 7, y + h - 7 }, { x + w - 7, y + h - 7 } }) do
        rivet(corner[1], corner[2], BRASS, alpha)                     -- 모든 패널 모서리는 황동 리벳
    end
    if opts.title ~= nil then
        Frame.plate(opts.title, x + (opts.title_cx or w / 2), y - PLATE_H + 9, { style = opts.style, alpha = alpha })
    end
end

-- 간판: 가운데 x(cx), 위쪽 y. 금박 글자
function Frame.plate(text, cx, y, opts)
    opts = opts or {}
    local style = style_of(opts.style)
    local alpha = opts.alpha or 1
    local font = Draw.font("plate")
    local w = math.max(opts.min_w or 0, font:getWidth(text) + PLATE_PAD * 2)
    local x = math.floor(cx - w / 2)
    Draw.set_color({ 0, 0, 0 }, 0.5 * alpha)
    LG.rectangle("fill", x + 2, y + 3, w, PLATE_H, 5, 5)
    Draw.set_color(style.edge, alpha)
    LG.polygon("fill", x - 8, y + PLATE_H / 2, x, y, x + w, y, x + w + 8, y + PLATE_H / 2, x + w, y + PLATE_H, x, y + PLATE_H)
    Draw.set_color(style.band, alpha)
    LG.rectangle("fill", x + 1, y + 1, w - 2, PLATE_H - 2, 4, 4)
    Draw.set_color(C.accent, 0.55 * alpha)
    LG.setLineWidth(1)
    LG.rectangle("line", x + 3.5, y + 3.5, w - 7, PLATE_H - 7, 3, 3)
    Lettering.draw(text, x, y + (PLATE_H - font:getHeight()) / 2, w, "center", "plate", "gold", alpha)
    return w
end

-- 내용 위에 테두리 띠만 (전투 레인처럼 시저로 그린 영역을 감쌀 때)
function Frame.border(x, y, w, h, style_name)
    local style = style_of(style_name)
    Draw.set_color(style.edge)
    LG.setLineWidth(8)
    LG.rectangle("line", x - 2, y - 2, w + 4, h + 4, 8, 8)
    Draw.set_color(style.band)
    LG.setLineWidth(4)
    LG.rectangle("line", x - 2, y - 2, w + 4, h + 4, 8, 8)
    for _, corner in ipairs({ { x + 2, y + 2 }, { x + w - 2, y + 2 }, { x + 2, y + h - 2 }, { x + w - 2, y + h - 2 } }) do
        rivet(corner[1], corner[2], style.rivet, 1)
    end
end

-- 오목한 칸
function Frame.inset(x, y, w, h, radius, fill, alpha)
    radius = radius or 6
    alpha = alpha or 1
    Draw.set_color(fill or C.slot, alpha)
    LG.rectangle("fill", x, y, w, h, radius, radius)
    Draw.set_color({ 0, 0, 0 }, 0.45 * alpha)
    LG.setLineWidth(2)
    LG.line(x + radius, y + 1, x + w - radius, y + 1)
    LG.line(x + 1, y + radius, x + 1, y + h - radius)
    Draw.set_color({ 1, 1, 1 }, 0.07 * alpha)
    LG.line(x + radius, y + h - 1, x + w - radius, y + h - 1)
    LG.line(x + w - 1, y + radius, x + w - 1, y + h - radius)
    Draw.set_color(C.slot_border, 0.6 * alpha)
    LG.setLineWidth(1)
    LG.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, radius, radius)
end

return Frame
