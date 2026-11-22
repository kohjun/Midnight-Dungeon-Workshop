-- ui/WorkshopInput.lua
-- 공방 화면 입력 컨트롤러: 버튼·단축키, 도구 모드(UV / 브러시), 드래그 앤 드롭, 포인터 상태.
-- 포인터는 love.mouse 폴링이 아니라 콜백으로 받은 좌표·버튼 상태를 쓴다 (스모크 테스트 주입 입력과 같은 경로).
-- 입력 우선순위: 버튼 > 도구(UV 홀드 스캔 · 브러시 문지르기) > 드래그. 도구가 켜져 있으면 작업대 유물을 집지 않는다.
--   UV 모드  : 작업대 유물 위에서 왼쪽 버튼을 누르고 있는 동안에만 렌즈가 켜진다 (움직이기만 하면 꺼져 있다)
--   단축키   : 1 UV · 2 브러시 · 3 매입 · 4 용광로 강화 · Space 낮에는 영업 마감(밤 시작) / 밤에는 과부하 레버
--   낮 오른쪽 패널은 보관함(위)과 진열장(아래)이 함께 보이므로 보관함 ↔ 진열장 ↔ 작업대·용광로 사이로 바로 끌어 옮긴다.

local Class = require("lib.classic")
local EventBus = require("core.EventBus")
local Input = require("core.Input")
local Viewport = require("core.Viewport")
local I18n = require("systems.I18n")
local Button = require("ui.Button")
local WorkshopButtons = require("ui.WorkshopButtons")
local Slots = require("ui.Slots")
local ItemRenderer = require("ui.ItemRenderer")
local WorkshopCursor = require("ui.WorkshopCursor")
local HeroEquip = require("systems.HeroEquip")
local LAYOUT = require("data.layout")

local WorkshopInput = Class:extend()

local DRAG_SCALE = 1.18
local SCRUB_LINGER = 0.14   -- 마지막으로 문지른 뒤 이 시간(초) 동안은 "세척 중"으로 본다 (세척 루프음)
local TOOLS = { uv = true, brush = true }
-- 키 액션 → 누를 버튼 id (phase_action 은 페이즈에 따라 달라진다)
local KEY_BUTTONS = {
    { "tool_uv", "uv" }, { "tool_brush", "brush" }, { "buy", "buy" }, { "forge", "forge" },
    { "start_night", "start_night" }, { "overclock", "overclock" }, { "speed_toggle", "speed" },
}

-- open_modal(kind): 버튼이 창("upgrades" | "guild" | "quests" | "compendium" | "menu")을 요청할 때 호출 (없으면 무시)
function WorkshopInput:new(workshop, open_modal)
    self._workshop = workshop
    self._open_modal = open_modal
    local x, y = Viewport.mouse_position()
    self.pointer = { x = x, y = y, down = false }
    self.tool = "none"
    self.drag = nil
    self.time = 0
    self._scrub_warned = false
    self._scrub_timer = 0
    self.buttons = {}
    self._by_id = {}
    self:_create_buttons()
    EventBus.subscribe("phase:night_started", function()
        self:set_tool("none")
        self.drag = nil
    end, { owner = self })
end

function WorkshopInput:destroy()
    EventBus.unsubscribe_owner(self)
end

function WorkshopInput:_add(id, label, opts)
    local button = Button(LAYOUT.buttons[id], label, opts)
    self.buttons[#self.buttons + 1] = button
    self._by_id[id] = button
end

function WorkshopInput:_create_buttons()
    for _, spec in ipairs(WorkshopButtons.build(self, self._workshop)) do
        self:_add(spec[1], spec[2], spec[3])
    end
end

function WorkshopInput:request_modal(kind)
    if self._open_modal ~= nil then
        self:set_tool("none")
        self._open_modal(kind)
    end
end

function WorkshopInput:button(id)
    return self._by_id[id]
end

function WorkshopInput:set_tool(tool)
    assert(tool == "none" or TOOLS[tool], "WorkshopInput: unknown tool '" .. tostring(tool) .. "'")
    if self.tool ~= tool then
        self.tool = tool
        EventBus.emit("ui:tool_changed", { tool = tool })
    end
end

function WorkshopInput:toggle_tool(tool)
    self:set_tool(self.tool == tool and "none" or tool)
end

function WorkshopInput:is_dragging(item)
    return self.drag ~= nil and self.drag.item == item
end

-- 방금까지 브러시로 문지르고 있었는지 (세척 루프음용)
function WorkshopInput:is_scrubbing()
    return self._scrub_timer > 0
end

-- 누르고 있던 버튼·드래그를 놓은 것으로 처리한다 (모달·시스템 메뉴가 열릴 때)
function WorkshopInput:release()
    self.pointer.down = false
    self.drag = nil
    self._scrub_timer = 0
    self._workshop.appraisal:scan(self.pointer.x, self.pointer.y, 0, false)
end

-- 드래그 중 포인터 아래 슬롯 (area, index)
function WorkshopInput:drop_target()
    if self.drag == nil then
        return nil
    end
    return Slots.at(self.pointer.x, self.pointer.y)
end

-- 드래그 중이면 (area, index) 가 놓을 수 있는 칸인지 (봉인 칸·자기 자리 제외) — 뷰가 후보 칸을 강조한다
function WorkshopInput:is_drop_candidate(area, index)
    local drag = self.drag
    if drag == nil or (area == drag.area and index == drag.index) then
        return false
    end
    if area == "grid" and not self._workshop:is_cell_open(index) then
        return false
    end
    return (HeroEquip.fits(drag.item, area, index))        -- 3분류: 방어구는 진열장에, 유물은 주인공에게 놓을 수 없다
end

-- 포인터 아래 슬롯 (area, index)
function WorkshopInput:hovered_slot()
    return Slots.at(self.pointer.x, self.pointer.y)
end

-- 지금 보여 줄 마우스 커서 (ui/WorkshopCursor)
function WorkshopInput:cursor_name()
    return WorkshopCursor.name(self, self._workshop)
end

-- 툴팁 대상: item, area, index
function WorkshopInput:hovered_item()
    if self.drag ~= nil or (self.tool ~= "none" and Slots.at(self.pointer.x, self.pointer.y) == "bench") then
        return nil
    end
    local area, index = Slots.at(self.pointer.x, self.pointer.y)
    if area == nil then
        return nil
    end
    local item = self._workshop.inventory:get(area, index)
    return item, area, index
end

function WorkshopInput:update(dt)
    self.time = self.time + dt
    self._scrub_timer = math.max(0, self._scrub_timer - dt)
    for _, button in ipairs(self.buttons) do
        button:update(dt, self.pointer.x, self.pointer.y)
    end
    -- UV 홀드 스캔: UV 모드 + 왼쪽 버튼 누름 + 드래그 중 아님. 그 외에는 렌즈가 꺼진다
    local w = self._workshop
    local held = self.tool == "uv" and self.pointer.down and self.drag == nil and w:is_day()
    if w.appraisal:scan(self.pointer.x, self.pointer.y, dt, held) == "empty" then
        self:set_tool("none")
        EventBus.emit("ui:message", { text = I18n.t("msg.uv_dead"), kind = "bad" })
    end
end

function WorkshopInput:mousemoved(x, y)
    local dx, dy = x - self.pointer.x, y - self.pointer.y
    self.pointer.x, self.pointer.y = x, y
    local w = self._workshop
    if self.tool == "brush" and self.pointer.down and self.drag == nil and w:is_day() then
        local status = w.appraisal:scrub(x, y, math.sqrt(dx * dx + dy * dy))
        if status == "ok" then
            self._scrub_timer = SCRUB_LINGER
        elseif (status == "not_owned" or status == "no_water") and not self._scrub_warned then
            self._scrub_warned = true
            local key = status == "no_water" and "msg.water_dead" or "msg.buy_before_scrub"
            EventBus.emit("ui:message", { text = I18n.t(key), kind = "warn" })
        end
    end
end

function WorkshopInput:mousepressed(x, y, button)
    self.pointer.x, self.pointer.y = x, y
    if Input.is_mouse_action(button, "cancel") then
        if self.tool ~= "none" then
            self:set_tool("none")
            return
        end
        local area, index = Slots.at(x, y)                  -- 도구가 꺼져 있을 때의 우클릭 = 빠른 교체 (장착 · 벗기 · 진열)
        if area ~= nil and self.drag == nil and self._workshop:is_day() then
            self._workshop:quick_move(area, index)
        end
        return
    end
    if not Input.is_mouse_action(button, "primary") then
        return
    end
    self._scrub_warned = false
    for _, candidate in ipairs(self.buttons) do
        if candidate:contains(x, y) then
            candidate:press()
            return
        end
    end
    self.pointer.down = true   -- 버튼이 아닌 곳을 눌렀을 때만: 도구 홀드(UV·브러시) 또는 드래그 시작

    local w = self._workshop
    local area, index = Slots.at(x, y)
    if w.phase == "night" and area == "grid" then
        w.combat:hit_web(index)     -- 밤: 거미줄 칸을 연타해 걷어 낸다
        return
    end
    if not w:is_day() then
        return
    end
    if area == nil or (area == "bench" and self.tool ~= "none") then
        return   -- 도구 사용 중에는 작업대 유물을 집지 않는다 (드래그는 도구가 꺼져 있을 때만)
    end
    local item = w.inventory:get(area, index)
    if item ~= nil and item.owned and not w.forge:is_locked(item) then
        local cx, cy = Slots.center(area, index)
        self.drag = { item = item, area = area, index = index, offset_x = cx - x, offset_y = cy - y }
    end
end

function WorkshopInput:mousereleased(x, y, button)
    self.pointer.x, self.pointer.y = x, y
    if not Input.is_mouse_action(button, "primary") then
        return
    end
    self.pointer.down = false
    local drag = self.drag
    if drag == nil then
        return
    end
    self.drag = nil
    local area, index = Slots.at(x, y)
    if area ~= nil and not (area == drag.area and index == drag.index) then
        self._workshop:move_item(drag.area, drag.index, area, index)
    end
end

function WorkshopInput:keypressed(key)
    if Input.is_action(key, "phase_action") then
        self:_press(self._workshop.phase == "night" and "overclock" or "start_night")
        return
    end
    for _, binding in ipairs(KEY_BUTTONS) do
        if Input.is_action(key, binding[1]) then
            self:_press(binding[2])
            return
        end
    end
end

function WorkshopInput:_press(id)
    self._by_id[id]:press()
end

function WorkshopInput:draw()
    for _, button in ipairs(self.buttons) do
        button:draw()
    end
    local drag = self.drag
    if drag ~= nil then
        local x, y = self.pointer.x + drag.offset_x, self.pointer.y + drag.offset_y
        local size = Slots.item_size(drag.area) * DRAG_SCALE
        love.graphics.setColor(0, 0, 0, 0.35)
        love.graphics.ellipse("fill", x + 6, y + size * 0.48, size * 0.4, size * 0.1, 20)
        ItemRenderer.draw(drag.item, x, y - 4 + math.sin(self.time * 8) * 2, size, { time = self.time })
    end
end

return WorkshopInput
