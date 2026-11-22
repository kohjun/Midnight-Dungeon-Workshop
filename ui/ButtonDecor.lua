-- ui/ButtonDecor.lua
-- 버튼 장식 (ui/Button 이 쓴다, 좌표는 모두 버튼 중심 기준): 단축키 칩 · 숫자 알림 배지 · 아이콘(원화 스프라이트 → 코드 도형 폴백)
-- · 핵심 진행 버튼의 황동 이중 테두리 강조.

local Draw = require("ui.Draw")
local Icons = require("ui.Icons")
local SpriteBank = require("ui.SpriteBank")
local UI = require("data.ui")

local ButtonDecor = {}

local LG = love.graphics
local HINT_PAD = 3
local HINT_HEIGHT = 15
local BADGE_R = 9
local BRASS = { 0.86, 0.66, 0.30 }

ButtonDecor.HINT_INSET = 3

function ButtonDecor.hint_width(hint)
    return Draw.font("button_small"):getWidth(hint) + HINT_PAD * 2
end

-- 단축키 표시 (낮은 한 줄 버튼은 오른쪽 세로 중앙에 나란히 배치해 라벨 겹침을 막는다)
function ButtonDecor.key_hint(hint, r, enabled, inline)
    local colors = UI.color
    local font = Draw.font("button_small")
    local width = ButtonDecor.hint_width(hint)
    local x = r.w / 2 - width - ButtonDecor.HINT_INSET
    local y = inline and (-HINT_HEIGHT / 2) or (-r.h / 2 + ButtonDecor.HINT_INSET)
    Draw.set_color({ 0.03, 0.03, 0.05 }, enabled and 0.85 or 0.5)
    LG.rectangle("fill", x, y, width, HINT_HEIGHT, 4, 4)
    Draw.set_color(colors.accent, enabled and 0.7 or 0.25)
    LG.setLineWidth(1)
    LG.rectangle("line", x + 0.5, y + 0.5, width - 1, HINT_HEIGHT - 1, 4, 4)
    Draw.text(hint, x, y + (HINT_HEIGHT - font:getHeight()) / 2, width, "center", "button_small",
        enabled and colors.accent or colors.text_disabled, enabled and 1 or 0.6)
end

-- 오른쪽 위 모서리의 숫자 알림 배지 (살짝 맥동)
function ButtonDecor.badge(count, r)
    local colors = UI.color
    local text = count > 9 and "9+" or tostring(count)
    local font = Draw.font("button_small")
    local radius = math.max(BADGE_R, font:getWidth(text) / 2 + 4)
    local pulse = 1 + 0.08 * math.sin(love.timer.getTime() * 6)
    LG.push()
    LG.translate(r.w / 2 - 3, -r.h / 2 + 2)
    LG.scale(pulse)
    Draw.set_color({ 0.03, 0.02, 0.02 })
    LG.circle("fill", 0, 0, radius + 2, 20)
    Draw.set_color(colors.danger)
    LG.circle("fill", 0, 0, radius, 20)
    Draw.text(text, -radius, -font:getHeight() / 2, radius * 2, "center", "button_small", { 1, 1, 1 })
    LG.pop()
end

-- 아이콘: opts.sprite(원화 스프라이트, data/art.lua 의 ui_props)가 있으면 그것을, 없으면 opts.icon(ui/Icons 도형)
-- 원화는 도형보다 조금 크게 그린다. 비활성 버튼은 어둡게
function ButtonDecor.icon(opts, cx, cy, size, color, alpha)
    local image = opts.sprite and SpriteBank.image(opts.sprite)
    if image ~= nil then
        local shade = alpha < 1 and 0.55 or 1
        SpriteBank.draw_fit(image, cx, cy, size * 1.3, { alpha = alpha, color = { shade, shade, shade } })
    elseif opts.icon ~= nil then
        Icons.draw(opts.icon, cx, cy, size, color, alpha)
    end
end

-- 핵심 진행 버튼(opts.emphasis): 황동 이중 테두리 + 은은한 맥동 빛 (다른 메뉴 버튼과 한눈에 구분)
function ButtonDecor.emphasis(r, enabled, corner)
    local glow = enabled and (0.55 + 0.25 * math.sin(love.timer.getTime() * 3)) or 0.25
    Draw.set_color(BRASS, 0.18 * glow)
    LG.rectangle("fill", -r.w / 2 - 5, -r.h / 2 - 5, r.w + 10, r.h + 10, corner + 5, corner + 5)
    Draw.set_color({ 0.05, 0.03, 0.02 })
    LG.setLineWidth(3)
    LG.rectangle("line", -r.w / 2 - 3, -r.h / 2 - 3, r.w + 6, r.h + 6, corner + 3, corner + 3)
    Draw.set_color(BRASS, enabled and 0.95 or 0.4)
    LG.setLineWidth(2)
    LG.rectangle("line", -r.w / 2 - 1.5, -r.h / 2 - 1.5, r.w + 3, r.h + 3, corner + 2, corner + 2)
    Draw.set_color({ 1, 0.9, 0.6 }, (enabled and 0.45 or 0.15) * glow)
    LG.setLineWidth(1)
    LG.rectangle("line", -r.w / 2 + 2.5, -r.h / 2 + 2.5, r.w - 5, r.h - 5, corner - 2, corner - 2)
end

return ButtonDecor
