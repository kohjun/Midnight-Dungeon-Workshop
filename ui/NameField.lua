-- ui/NameField.lua
-- 한 줄 텍스트 입력 칸 (이름 서명용). love.textinput / textedited(IME 조합 중 글자)를 받아 UTF-8 로 편집한다.
-- 활성화하면 love.keyboard.setTextInput 으로 IME 후보 창 위치를 칸에 맞춘다.

local Class = require("lib.classic")
local Tween = require("lib.tween")
local Text = require("lib.text")
local Viewport = require("core.Viewport")
local Draw = require("ui.Draw")
local UI = require("data.ui")

local NameField = Class:extend()

local PADDING = 8
local SHAKE_PIXELS = 7

-- opts: { text, max_chars, placeholder, font_size, ink = 글자색, line = 밑줄색 }
function NameField:new(rect, opts)
    self.rect = rect
    self.text = opts.text or ""
    self.active = false
    self._max = opts.max_chars
    self._placeholder = opts.placeholder or ""
    self._font_size = opts.font_size or UI.font_size.body
    self._ink = opts.ink or UI.color.text
    self._line = opts.line or UI.color.text_dim
    self._composition = ""
    self._time = 0
    self._anim = { shake = 0 }
    self._tweens = Tween.Group()
end

function NameField:set_active(enabled)
    self.active = enabled
    self._composition = ""
    local r = self.rect
    local x, y = Viewport.to_window(r.x, r.y)      -- IME 후보 창은 실제 창 좌표 기준
    local scale = Viewport.scale()
    love.keyboard.setTextInput(enabled, x, y, r.w * scale, r.h * scale)
end

function NameField:value()
    return Text.sanitize_name(self.text, self._max)
end

function NameField:textinput(text)
    if not self.active then
        return
    end
    self._composition = ""
    self.text = Text.prefix(self.text .. text:gsub("%c", ""), self._max)
end

-- IME 조합 중인 글자 (확정 전 미리보기)
function NameField:textedited(text)
    if self.active then
        self._composition = text
    end
end

function NameField:backspace()
    if self.active and self._composition == "" then
        self.text = Text.pop(self.text)
    end
end

-- 빈 이름으로 서명하려 할 때 흔들림
function NameField:nudge()
    self._anim.shake = 1
    self._tweens:clear()
    self._tweens:to(self._anim, 0.35, { shake = 0 }):ease("out_quad")
end

function NameField:update(dt)
    self._time = self._time + dt
    self._tweens:update(dt)
end

function NameField:draw()
    local r = self.rect
    local font = Draw.font(self._font_size)
    local offset = math.sin(self._anim.shake * 30) * SHAKE_PIXELS * self._anim.shake
    local text_y = r.y + (r.h - font:getHeight()) / 2
    local x = r.x + PADDING + offset

    if self.active then
        Draw.set_color(self._ink, 0.08 + 0.04 * math.sin(self._time * 4))
        love.graphics.rectangle("fill", r.x + offset, r.y, r.w, r.h, 4, 4)
    end
    Draw.set_color(self._line, self.active and 1 or 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.line(r.x + offset, r.y + r.h, r.x + r.w + offset, r.y + r.h)

    if self.text == "" and self._composition == "" then
        Draw.text(self._placeholder, x, text_y, r.w - PADDING * 2, "left", self._font_size, self._line, 0.7)
    else
        Draw.text(self.text, x, text_y, r.w * 2, "left", self._font_size, self._ink)
    end
    local caret_x = x + font:getWidth(self.text)
    if self._composition ~= "" then
        Draw.text(self._composition, caret_x, text_y, r.w, "left", self._font_size, self._ink, 0.6)
        local width = font:getWidth(self._composition)
        love.graphics.line(caret_x, text_y + font:getHeight(), caret_x + width, text_y + font:getHeight())
        caret_x = caret_x + width
    end
    if self.active and math.sin(self._time * 8) > 0 then
        Draw.set_color(self._ink)
        love.graphics.rectangle("fill", caret_x + 1, text_y + 2, 2, font:getHeight() - 4)
    end
end

return NameField
