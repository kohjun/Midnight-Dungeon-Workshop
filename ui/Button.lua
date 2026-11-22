-- ui/Button.lua
-- 클릭 버튼: 베벨(윗면 반사·아랫면 그늘)·아이콘·호버 확대·누를 때 눌림(스케일 트윈 + 베벨 반전)·비활성 클릭 시 흔들림 + 사유 안내.
-- 비활성(enabled 가 false) 버튼은 어둡게 그리고 클릭을 차단한다. 누를 때마다 "ui:button_pressed" 를 발행한다 (효과음).
-- 누를 수 있는 버튼 위에 포인터가 있으면 update 가 커스텀 커서 "hover" 를 요청한다 (ui/CursorManager, 우선순위 1).
-- label 은 문자열 또는 문자열을 반환하는 함수 (언어 전환에 바로 반응하려면 함수).
-- opts: { on_click, enabled = fn, active = fn, visible = fn, style = "normal"|"accent"|"danger"|"tool",
--         hidden = bool (그리기는 다른 뷰가 담당), disabled_message = string | fn → string,
--         key_hint = string (모서리 단축키), icon = ui/Icons 이름,
--         layout = "row"(기본: 아이콘 + 글자 한 줄) | "tile"(큰 아이콘 위 · 글자 아래 — 도구 선반),
--         gauge = fn → 값(0~1), 색   (tile 아래쪽 자원 게이지), text = 글자 유형 (기본 "button"),
--         badge = fn → 숫자 (1 이상이면 오른쪽 위 모서리에 붉은 숫자 알림 배지),
--         sprite = 원화 아이콘 스프라이트 이름 (있으면 icon 도형 대신 — 상단 바 icon_*),
--         emphasis = bool (핵심 진행 버튼: 황동 이중 테두리 강조) }
-- 단축키 칩·배지·아이콘·강조 테두리는 ui/ButtonDecor.

local Class = require("lib.classic")
local Tween = require("lib.tween")
local EventBus = require("core.EventBus")
local Draw = require("ui.Draw")
local CursorManager = require("ui.CursorManager")
local Icons = require("ui.Icons")
local ButtonDecor = require("ui.ButtonDecor")
local UI = require("data.ui")

local Button = Class:extend()

local STYLE_COLORS = {
    normal = "button",
    accent = "button_accent",
    danger = "button_danger",
    tool = "button_tool",
}
local SHAKE_PIXELS = 6
local CORNER = 7
local COMPACT_H = 44
local DISABLED_SHADE = 0.32
local ICON_SIZE = 17
local TILE_ICON = 34
local GAUGE_H = 7
local HOVER_PRIORITY = 1

function Button:new(rect, label, opts)
    self.rect = rect
    self.label = label
    self._opts = opts or {}
    self._anim = { scale = 1, hover = 0, shake = 0, press = 0 }
    self._tweens = Tween.Group()
    self.hovered = false
end

function Button:is_enabled()
    local fn = self._opts.enabled
    return fn == nil or (fn() and true or false)
end

function Button:is_active()
    local fn = self._opts.active
    return fn ~= nil and fn()
end

function Button:label_text()
    if type(self.label) == "function" then
        return self.label()
    end
    return self.label
end

function Button:key_hint()
    return self._opts.key_hint
end

-- opts.visible(fn) 이 false 면 그리지도 클릭되지도 않는다
function Button:is_visible()
    local fn = self._opts.visible
    return fn == nil or fn()
end

function Button:contains(x, y)
    if not self:is_visible() then
        return false
    end
    local r = self.rect
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

-- 호버 확대: 기본 +4%, opts.hover_scale 로 조절 (타이틀 계열 화면은 +3%)
function Button:scale()
    return self._anim.scale * (1 + (self._opts.hover_scale or 0.04) * self._anim.hover)
end

function Button:update(dt, pointer_x, pointer_y)
    self.hovered = self:contains(pointer_x, pointer_y)
    local target = (self.hovered and self:is_enabled()) and 1 or 0
    if target == 1 then
        CursorManager.request("hover", HOVER_PRIORITY)
    end
    local speed = math.min(1, dt * UI.anim.button_hover_speed)
    self._anim.hover = self._anim.hover + (target - self._anim.hover) * speed
    self._tweens:update(dt)
end

-- 클릭 처리. 비활성이면 흔들림 + 사유 안내 메시지 (동작은 차단)
function Button:press()
    self._tweens:clear()
    local enabled = self:is_enabled()
    EventBus.emit("ui:button_pressed", { enabled = enabled })
    if not enabled then
        self._anim.shake = 1
        self._tweens:to(self._anim, 0.3, { shake = 0 }):ease("out_quad")
        local message = self._opts.disabled_message
        if type(message) == "function" then
            message = message()
        end
        if message ~= nil then
            EventBus.emit("ui:message", { text = message, kind = "warn" })
        end
        return false
    end
    self._anim.scale, self._anim.press = 0.9, 1
    self._tweens:to(self._anim, UI.anim.button_press, { scale = 1, press = 0 }):ease("out_back")
    if self._opts.on_click ~= nil then
        self._opts.on_click()
    end
    return true
end

-- 몸체: 바탕 + 베벨. pressed(0~1)면 베벨이 뒤집혀 눌린 느낌
local function draw_body(r, fill, border, pressed, enabled)
    local x, y, w, h = -r.w / 2, -r.h / 2, r.w, r.h
    Draw.set_color({ 0, 0, 0 }, 0.4)
    love.graphics.rectangle("fill", x + 1, y + 3 - pressed * 2, w, h, CORNER, CORNER)
    Draw.set_color(fill)
    love.graphics.rectangle("fill", x, y, w, h, CORNER, CORNER)
    local top, bottom = 0.16 * (1 - pressed), 0.28 * (1 - pressed) + 0.1
    Draw.set_color({ 1, 1, 1 }, enabled and top * 0.6 or 0.03)
    love.graphics.rectangle("fill", x + 2, y + 2, w - 4, h * 0.45, CORNER - 2, CORNER - 2)
    Draw.set_color({ 0, 0, 0 }, pressed > 0 and 0.25 or bottom)
    love.graphics.rectangle("fill", x + 2, y + h - 4, w - 4, 3, 2, 2)
    Draw.set_color(border, enabled and 1 or 0.4)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, CORNER, CORNER)
end

function Button:_draw_row(r, text_color, alpha)
    local spec = self._opts.text or "button"
    local font = Draw.font(spec)
    local label = self:label_text()
    local icon = self._opts.icon or self._opts.sprite
    local reserve = 0
    if self._opts.key_hint ~= nil and r.h <= COMPACT_H then
        reserve = ButtonDecor.hint_width(self._opts.key_hint) + ButtonDecor.HINT_INSET + 3
    end
    local avail = r.w - reserve
    local icon_w = icon and (reserve > 0 and 14 or ICON_SIZE) or 0
    local gap = icon and (reserve > 0 and 4 or 6) or 0
    local text_w = font:getWidth(label)
    if text_w + icon_w + gap > avail - 10 then     -- 언어·단축키 여백에 맞춰 작은 글자로 한 줄에
        spec = "button_small"
        font = Draw.font(spec)
        text_w = font:getWidth(label)
    end
    if text_w + icon_w + gap > avail - 8 then      -- 좁은 다국어 버튼도 줄바꿈 없이 한 줄 유지
        spec = { role = "ui", size = 11 }
        font = Draw.font(spec)
        text_w = font:getWidth(label)
    end
    local content = text_w + icon_w + gap
    local zone_left = -r.w / 2 + 5
    local zone_right = r.w / 2 - reserve - 2
    local center = (zone_left + zone_right) / 2
    local left = math.max(zone_left, center - content / 2)
    if icon ~= nil then
        ButtonDecor.icon(self._opts, left + icon_w / 2, 0, icon_w, text_color, alpha)
        left = left + icon_w + gap
    end
    Draw.label_text(label, left, -font:getHeight() / 2, math.max(text_w + 2, zone_right - left), "left", spec, text_color, alpha)
end

function Button:_draw_tile(r, text_color, alpha)
    local icon = self._opts.icon
    local gauge = self._opts.gauge
    local top = -r.h / 2
    if icon ~= nil then
        Icons.draw(icon, 0, top + 12 + TILE_ICON / 2, TILE_ICON, text_color, alpha)
    end
    local font = Draw.font("button_small")
    Draw.label_text(self:label_text(), -r.w / 2 + 2, top + TILE_ICON + 20, r.w - 4, "center", "button_small", text_color, alpha)
    if gauge ~= nil then
        local value, color = gauge()
        local bar_w, bar_y = r.w - 16, r.h / 2 - GAUGE_H - 7
        Draw.bar(-bar_w / 2, bar_y, bar_w, GAUGE_H, value, color)
        Draw.label_text(string.format("%d%%", math.floor(value * 100 + 0.5)), -r.w / 2, bar_y - font:getHeight() - 1, r.w - 8,
            "right", "button_small", color, alpha)
    end
end

function Button:draw()
    if self._opts.hidden or not self:is_visible() then
        return
    end
    local r = self.rect
    local enabled = self:is_enabled()
    local active = self:is_active()
    local shake = self._anim.shake
    local offset_x = math.sin(shake * 28) * SHAKE_PIXELS * shake
    local colors = UI.color

    local fill = colors[STYLE_COLORS[self._opts.style or "normal"]]
    if active then
        fill = colors.button_active
    elseif not enabled then
        fill = colors.button_disabled
    end
    fill = Draw.lerp_color(fill, { 1, 1, 1 }, 0.12 * self._anim.hover)

    love.graphics.push()
    love.graphics.translate(r.x + r.w / 2 + offset_x, r.y + r.h / 2 + self._anim.press * 1.5)
    love.graphics.scale(self:scale())
    draw_body(r, fill, active and colors.accent or colors.panel_border, active and 0.6 or self._anim.press, enabled or active)
    local text_color = (enabled or active) and colors.text or colors.text_disabled
    local alpha = (enabled or active) and 1 or 0.55
    if self._opts.layout == "tile" then
        self:_draw_tile(r, text_color, alpha)
    else
        self:_draw_row(r, text_color, alpha)
    end
    if not enabled and not active then
        love.graphics.setColor(0, 0, 0, DISABLED_SHADE)
        love.graphics.rectangle("fill", -r.w / 2, -r.h / 2, r.w, r.h, CORNER, CORNER)
    end
    if self._opts.emphasis then
        ButtonDecor.emphasis(r, enabled, CORNER)
    end
    if self._opts.gold_hover and self._anim.hover > 0.01 then     -- 호버 시 금빛 테두리
        Draw.set_color(colors.gold, self._anim.hover)
        love.graphics.setLineWidth(2.5)
        love.graphics.rectangle("line", -r.w / 2 - 2, -r.h / 2 - 2, r.w + 4, r.h + 4, CORNER + 2, CORNER + 2)
    end
    if self._opts.key_hint ~= nil then
        local inline = self._opts.layout ~= "tile" and r.h <= COMPACT_H
        ButtonDecor.key_hint(self._opts.key_hint, r, enabled or active, inline)
    end
    local count = self._opts.badge and self._opts.badge() or 0
    if count > 0 then
        ButtonDecor.badge(count, r)
    end
    love.graphics.pop()
end

return Button
