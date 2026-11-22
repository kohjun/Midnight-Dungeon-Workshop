-- ui/Modal.lua
-- 공용 모달 창: 제목·부제·행 목록(아이콘·설명·오른쪽 버튼)·하단 버튼. 길드 상점·공방 개조·암시장·영구 강화가 사용한다.
-- 문구는 그릴 때마다 조회하고, 언어가 바뀌면(I18n.revision) 행·버튼을 다시 만든다.
-- spec = {
--   title (str|fn), subtitle = fn() → string,
--   rows = fn() → { { title, text, color?, item?, button = { label (str|fn), on_click, enabled = fn, reason = fn } }, ... },
--   footer = { { label (str|fn), on_click, style }, ... } 또는 그런 목록을 반환하는 fn,
--   on_cancel = fn()   -- ESC (없으면 ESC 로 닫을 수 없는 모달)
-- }
-- 버튼 좌표는 Modal.row_button_rect / Modal.footer_rect 로도 얻을 수 있다 (스모크 테스트용).

local Class = require("lib.classic")
local Tween = require("lib.tween")
local Input = require("core.Input")
local Viewport = require("core.Viewport")
local I18n = require("systems.I18n")
local Button = require("ui.Button")
local Draw = require("ui.Draw")
local Frame = require("ui.Frame")
local Lettering = require("ui.Lettering")
local ItemRenderer = require("ui.ItemRenderer")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local Modal = Class:extend()

local C = UI.color
local SIZE = UI.font_size
local ICON_SIZE = 48

function Modal.row_rect(index)
    local m = LAYOUT.modal
    local y = m.y + m.row_top + (index - 1) * (m.row_h + m.row_gap)
    return { x = m.x + 20, y = y, w = m.w - 40, h = m.row_h }
end

function Modal.row_button_rect(index)
    local m = LAYOUT.modal
    local row = Modal.row_rect(index)
    return { x = row.x + row.w - m.button_w - 12, y = row.y + (row.h - m.button_h) / 2, w = m.button_w, h = m.button_h }
end

function Modal.footer_rect(index, count)
    local m = LAYOUT.modal
    local gap = 20
    local total = count * m.footer_w + (count - 1) * gap
    local x = m.x + (m.w - total) / 2 + (index - 1) * (m.footer_w + gap)
    return { x = x, y = m.y + m.h - m.footer_h - 16, w = m.footer_w, h = m.footer_h }
end

function Modal:new(spec)
    self._spec = spec
    self.closed = false
    self._anim = { scale = 0.92, alpha = 0 }
    self._tweens = Tween.Group()
    self._tweens:to(self._anim, 0.22, { scale = 1, alpha = 1 }):ease("out_back")
    self:refresh()
end

function Modal:close()
    self.closed = true
end

-- 행·버튼 재구성 (구매 등 상태가 바뀐 뒤)
function Modal:refresh()
    self._revision = I18n.revision()
    self._rows = self._spec.rows and self._spec.rows() or {}
    self._buttons = {}
    for i, row in ipairs(self._rows) do
        if row.button ~= nil then
            local spec = row.button
            self._buttons[#self._buttons + 1] = Button(Modal.row_button_rect(i), spec.label, {
                style = spec.style or "accent", enabled = spec.enabled, on_click = spec.on_click,
            })
        end
    end
    local footer = self._spec.footer or {}
    if type(footer) == "function" then
        footer = footer()
    end
    for i, spec in ipairs(footer) do
        self._buttons[#self._buttons + 1] = Button(Modal.footer_rect(i, #footer), spec.label, {
            style = spec.style, on_click = spec.on_click,
        })
    end
end

function Modal:update(dt, pointer_x, pointer_y)
    self._tweens:update(dt)
    if self._revision ~= I18n.revision() then
        self:refresh()   -- 언어가 바뀌었다: 행 문구를 다시 만든다
    end
    for _, button in ipairs(self._buttons) do
        button:update(dt, pointer_x, pointer_y)
    end
end

-- 모달이 열려 있으면 모든 클릭을 소비한다
function Modal:mousepressed(x, y)
    for _, button in ipairs(self._buttons) do
        if button:contains(x, y) then
            if button:press() and not self.closed then
                self:refresh()
            end
            return true
        end
    end
    return true
end

-- ESC 로 닫을 수 있는 모달인지
function Modal:can_cancel()
    return self._spec.on_cancel ~= nil
end

function Modal:keypressed(key)
    if Input.is_action(key, "back") and self._spec.on_cancel ~= nil then
        self._spec.on_cancel()
        if not self.closed then
            self:refresh()
        end
    end
end

function Modal:_draw_row(index, row)
    local rect = Modal.row_rect(index)
    Frame.inset(rect.x, rect.y, rect.w, rect.h, 8, { 0.11, 0.10, 0.13 })
    local text_x = rect.x + 14
    if row.item ~= nil then
        ItemRenderer.draw(row.item, rect.x + 12 + ICON_SIZE / 2, rect.y + rect.h / 2, ICON_SIZE, { badges = false })
        text_x = rect.x + ICON_SIZE + 24
    end
    local text_w = rect.w - (text_x - rect.x) - LAYOUT.modal.button_w - 30
    Draw.text(row.title, text_x, rect.y + 8, text_w, "left", "item_name", row.color or C.text)
    Draw.text(row.text or "", text_x, rect.y + 34, text_w, "left", SIZE.small, C.text_dim)
    local spec = row.button
    if spec ~= nil and spec.reason ~= nil and spec.enabled ~= nil and not spec.enabled() then
        local reason = spec.reason()
        if reason ~= nil then
            local button = Modal.row_button_rect(index)
            Draw.text(reason, button.x - 110, button.y + 12, 104, "right", SIZE.tiny, C.danger)
        end
    end
end

function Modal:draw()
    local m = LAYOUT.modal
    local alpha = self._anim.alpha
    love.graphics.setColor(0, 0, 0, 0.62 * alpha)
    love.graphics.rectangle("fill", 0, 0, Viewport.width(), Viewport.height())

    love.graphics.push()
    love.graphics.translate(m.x + m.w / 2, m.y + m.h / 2)
    love.graphics.scale(self._anim.scale)
    love.graphics.translate(-(m.x + m.w / 2), -(m.y + m.h / 2))
    Frame.panel(m.x, m.y, m.w, m.h, { style = "dark", texture = "stone", texture_alpha = 0.12 })
    local title = self._spec.title
    if type(title) == "function" then
        title = title()
    end
    Lettering.draw(title, m.x, m.y + 14, m.w, "center", "title", "gold")
    if self._spec.subtitle ~= nil then
        Draw.text(self._spec.subtitle(), m.x + 30, m.y + 54, m.w - 60, "center", SIZE.small, C.text)
    end
    for i, row in ipairs(self._rows) do
        self:_draw_row(i, row)
    end
    for _, button in ipairs(self._buttons) do
        button:draw()
    end
    love.graphics.pop()
end

return Modal
