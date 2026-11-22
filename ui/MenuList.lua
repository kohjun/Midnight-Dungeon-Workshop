-- ui/MenuList.lua
-- 세로 한 줄 메뉴 (타이틀): 마우스 호버 또는 ↑↓ / W·S 로 초점 이동, Enter·Space·클릭으로 실행.
-- 초점 항목은 금빛 띠·마름모 표식·금박 글자로 강조되고 오른쪽으로 살짝 밀려난다.
--   items = { { id, label = fn → string, icon, on_activate = fn, enabled = fn? }, ... }
--   MenuList.item_rect(layout, i) — 항목 i 의 화면 영역 (스모크 테스트도 같은 좌표를 쓴다)

local Class = require("lib.classic")
local EventBus = require("core.EventBus")
local Draw = require("ui.Draw")
local CursorManager = require("ui.CursorManager")
local Icons = require("ui.Icons")
local Lettering = require("ui.Lettering")
local UI = require("data.ui")

local MenuList = Class:extend()

local LG = love.graphics
local C = UI.color
local SLIDE = 14
local ICON = 20
local HOVER_SCALE = 0.03       -- 호버·포커스 확대 (1.0 → 1.03)
local HOVER_PRIORITY = 1
local UP_KEYS = { up = true, w = true }
local DOWN_KEYS = { down = true, s = true }
local ACTIVATE_KEYS = { ["return"] = true, kpenter = true, space = true }

local _fade = nil    -- 왼쪽에서 오른쪽으로 옅어지는 띠 (1px 높이 가로 그라데이션)

local function fade_image()
    if _fade == nil then
        local data = love.image.newImageData(64, 1)
        data:mapPixel(function(x)
            return 1, 1, 1, (1 - x / 63) ^ 1.5
        end)
        _fade = LG.newImage(data)
        _fade:setFilter("linear", "linear")
    end
    return _fade
end

-- layout: { x, y, w, h, gap }
function MenuList.item_rect(layout, index)
    return { x = layout.x, y = layout.y + (index - 1) * (layout.h + layout.gap), w = layout.w, h = layout.h }
end

function MenuList:new(layout, items)
    self._layout = layout
    self.items = items
    self.focus = 1
    self._slide = {}
    for i = 1, #items do
        self._slide[i] = 0
    end
end

function MenuList:_enabled(index)
    local fn = self.items[index].enabled
    return fn == nil or fn()
end

function MenuList:index_of(id)
    for i, item in ipairs(self.items) do
        if item.id == id then
            return i
        end
    end
    return nil
end

function MenuList:_hit(x, y)
    for i = 1, #self.items do
        local r = MenuList.item_rect(self._layout, i)
        if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
            return i
        end
    end
    return nil
end

function MenuList:update(dt, pointer_x, pointer_y, pointer_moved)
    local hit = self:_hit(pointer_x, pointer_y)
    if pointer_moved and hit ~= nil then
        self.focus = hit
    end
    if hit ~= nil and self:_enabled(hit) then
        CursorManager.request("hover", HOVER_PRIORITY)       -- 커스텀 커서 (ui/CursorManager)
    end
    local speed = math.min(1, dt * 14)
    for i = 1, #self.items do
        local target = (i == self.focus) and 1 or 0
        self._slide[i] = self._slide[i] + (target - self._slide[i]) * speed
    end
end

function MenuList:activate(index)
    index = index or self.focus
    local item = self.items[index]
    local enabled = self:_enabled(index)
    EventBus.emit("ui:button_pressed", { enabled = enabled })
    if enabled then
        item.on_activate()
    end
    return enabled
end

function MenuList:mousepressed(x, y)
    local hit = self:_hit(x, y)
    if hit == nil then
        return false
    end
    self.focus = hit
    self:activate(hit)
    return true
end

function MenuList:keypressed(key)
    if UP_KEYS[key] then
        self.focus = (self.focus - 2) % #self.items + 1
    elseif DOWN_KEYS[key] then
        self.focus = self.focus % #self.items + 1
    elseif ACTIVATE_KEYS[key] then
        self:activate()
    else
        return false
    end
    return true
end

function MenuList:draw(alpha)
    alpha = alpha or 1
    local font = Draw.font("menu")
    for i, item in ipairs(self.items) do
        local r = MenuList.item_rect(self._layout, i)
        local slide = self._slide[i]
        local enabled = self:_enabled(i)
        LG.push()                       -- 호버·포커스: 1.0 → 1.03 확대 + 금빛 테두리
        LG.translate(r.x + r.w / 2, r.y + r.h / 2)
        LG.scale(1 + HOVER_SCALE * slide)
        LG.translate(-(r.x + r.w / 2), -(r.y + r.h / 2))
        if slide > 0.01 then
            LG.setColor(C.accent[1], C.accent[2], C.accent[3], 0.26 * slide * alpha)
            LG.draw(fade_image(), r.x, r.y + 4, 0, r.w / 64, r.h - 8)
            Draw.set_color(C.accent, slide * alpha)
            LG.rectangle("fill", r.x, r.y + 4, 3, r.h - 8)
            local dx, dy = r.x + 14, r.y + r.h / 2
            LG.polygon("fill", dx, dy - 6 * slide, dx + 6 * slide, dy, dx, dy + 6 * slide, dx - 6 * slide, dy)
        end
        local x = r.x + 30 + slide * SLIDE
        local color = enabled and (slide > 0.5 and C.text or C.text_dim) or { 0.35, 0.35, 0.4 }
        if item.icon ~= nil then
            Icons.draw(item.icon, x + ICON / 2, r.y + r.h / 2, ICON, slide > 0.5 and C.gold or color, alpha)
            x = x + ICON + 14
        end
        local y = r.y + (r.h - font:getHeight()) / 2
        if slide > 0.5 and enabled then
            Lettering.draw(item.label(), x, y, r.w - (x - r.x), "left", "menu", "gold", alpha)
        else
            Draw.text(item.label(), x, y, r.w - (x - r.x), "left", "menu", color, alpha)
        end
        if slide > 0.01 and enabled then
            Draw.set_color(C.gold, 0.75 * slide * alpha)
            LG.setLineWidth(2)
            LG.rectangle("line", r.x - 2, r.y + 2, r.w + 4, r.h - 4, 6, 6)
        end
        LG.pop()
    end
end

return MenuList
