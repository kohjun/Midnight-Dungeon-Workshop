-- tools/SmokeCursor.lua
-- 헤드리스 검사 (SmokeTest 가 SmokeAnimation 다음에 실행): 커스텀 마우스 커서 (ui/CursorManager · ui/CursorShapes).
--   요청 우선순위(높은 쪽 · 같으면 나중 · 없으면 default · clear) · 화면 전환 중에는 default · 모르는 이름은 오류
--   · 누르는 동안 눌림 → 떼면 복귀 · 클릭 파동이 생겼다 사라짐 · 오른쪽으로 빠르게 움직이면 기울었다가 돌아옴
--   · 상태가 바뀌면 톡 튀는 확대 · hover 발광 · 포커스를 잃으면 운영체제 커서 복구 / 얻으면 숨김 (StateManager 경유)
--   · 종료(StateManager.quit)하면 운영체제 커서 복구 · 6종 도안이 핫스팟 위에 그려짐 (오프스크린 픽셀 검사)
--   · 화면 전환(셔터)이 화면을 다 덮은 순간에도 커서가 그 위에 그려짐 (StateManager.draw 맨 마지막)
--   · 공방 판정(ui/WorkshopCursor): 보관함 유물 grab · 버튼 hover · 작업대 유물 appraise · 브러시 hidden
--     · 드래그 grabbing · 밤 거미줄 칸 web_cut
--   --shots 면 6종 도안 견본(smoke_cursors.png)

local SmokeCursor = {}

local DT = 1 / 60
local NAMES = { "default", "hover", "grab", "grabbing", "appraise", "web_cut" }
local SHEET_SCALE = 3

local function check(condition, message)
    if not condition then
        error("SmokeCursor: " .. message, 2)
    end
end

local function settle(CursorManager, frames)
    for _ = 1, frames do
        CursorManager.update(DT)
    end
end

local function check_requests(CursorManager)
    CursorManager.request("hover", 1)
    CursorManager.request("appraise", 2)
    CursorManager.request("grab", 1)
    CursorManager.update(DT)
    check(CursorManager.current() == "appraise", "the highest priority request wins")
    CursorManager.request("grab", 2)
    CursorManager.request("web_cut", 2)
    CursorManager.update(DT)
    check(CursorManager.current() == "web_cut", "equal priority: the later request wins")
    CursorManager.update(DT)
    check(CursorManager.current() == "default", "no request falls back to default")
    CursorManager.request("hover", 1)
    CursorManager.clear()
    CursorManager.update(DT)
    check(CursorManager.current() == "default", "clear drops earlier requests")
    check(not pcall(CursorManager.request, "no_such_cursor"), "unknown cursor names are rejected")
    CursorManager.request("hover", 1)
    CursorManager.update(DT)
    check(CursorManager.snapshot().pop > 0.5, "switching state pops the cursor")
    for _ = 1, 30 do
        CursorManager.request("hover", 1)
        CursorManager.update(DT)
    end
    check(CursorManager.snapshot().hover > 0.9 and CursorManager.snapshot().pop < 0.05, "hover glow fades in, pop settles")
end

local function check_motion(CursorManager)
    CursorManager.input("mousemoved", 400, 300)
    settle(CursorManager, 60)
    local ripples = CursorManager.snapshot().ripples
    CursorManager.input("mousepressed", 400, 300, 1)
    check(CursorManager.snapshot().press > 0.99, "pressing squeezes the cursor")
    check(CursorManager.snapshot().ripples == ripples + 1, "a click spawns a ripple")
    settle(CursorManager, 10)
    check(CursorManager.snapshot().press > 0.95, "stays pressed while held")
    CursorManager.input("mousereleased", 400, 300, 1)
    settle(CursorManager, 40)
    local snap = CursorManager.snapshot()
    check(snap.press < 0.05, "release springs back")
    check(snap.ripples == 0, "ripples fade out")
    for i = 1, 12 do                           -- 빠르게 오른쪽으로: 끌려오듯 기운다
        CursorManager.input("mousemoved", 400 + i * 24, 300)
        CursorManager.update(DT)
    end
    check(CursorManager.snapshot().tilt < -0.05, "moving right sways the cursor")
    settle(CursorManager, 150)
    check(math.abs(CursorManager.snapshot().tilt) < 0.01, "sway settles when the pointer stops")
end

local function check_focus(CursorManager)
    local StateManager = require("core.StateManager")
    StateManager.dispatch("focus", false)
    check(love.mouse.isVisible() and not CursorManager.is_visible(), "losing focus restores the OS cursor")
    StateManager.dispatch("focus", true)
    check(not love.mouse.isVisible() and CursorManager.is_visible(), "regaining focus hides the OS cursor")
    StateManager.dispatch("mousefocus", false)
    check(not CursorManager.is_visible(), "the cursor is not drawn while the mouse is outside the window")
    StateManager.dispatch("mousefocus", true)
    check(not StateManager.quit() and love.mouse.isVisible(), "quitting restores the OS cursor")
    CursorManager.set_focus(true)
end

-- 6종 도안: 핫스팟 근처에 그림이 있고, 충분한 면적이 그려진다
local function check_shapes(CursorShapes, shots)
    local size = 200
    local canvas = love.graphics.newCanvas(size, size)
    local sheet = shots and love.graphics.newCanvas(size * #NAMES, size) or nil
    for i, name in ipairs(NAMES) do
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.push()
        love.graphics.translate(size / 2, size / 2)
        love.graphics.scale(SHEET_SCALE)
        CursorShapes.draw(name, 1.3, 1)
        love.graphics.pop()
        love.graphics.setCanvas()
        local data = canvas:newImageData()
        local filled, near = 0, 0
        for y = 0, size - 1, 2 do
            for x = 0, size - 1, 2 do
                local _, _, _, a = data:getPixel(x, y)
                filled = filled + (a > 0.5 and 1 or 0)
                if math.abs(x - size / 2) <= 6 and math.abs(y - size / 2) <= 6 and a > 0.2 then
                    near = near + 1
                end
            end
        end
        check(filled > 300, name .. " cursor draws a solid shape")
        check(near > 0, name .. " cursor is drawn over its hotspot")
        if sheet ~= nil then
            love.graphics.setCanvas(sheet)
            love.graphics.setColor(0.10, 0.08, 0.12, 1)
            love.graphics.rectangle("fill", (i - 1) * size, 0, size, size)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(canvas, (i - 1) * size, 0)
            love.graphics.setCanvas()
        end
    end
    if sheet ~= nil then
        sheet:newImageData():encode("png", "smoke_cursors.png")
    end
end

-- 셔터가 화면을 다 덮은 순간(hold)에도 커서는 그 위에 그려진다. 전환 중에는 hover 를 요청해도 default.
local function check_draw_order(CursorManager)
    local StateManager = require("core.StateManager")
    local TransitionManager = require("ui.TransitionManager")
    local Viewport = require("core.Viewport")
    local canvas = love.graphics.newCanvas(Viewport.width(), Viewport.height())
    local done = false
    check(TransitionManager.start("shutter_slam", nil, { wait = function() return done end }), "shutter transition starts")
    for _ = 1, 600 do
        TransitionManager.update(DT)
        if TransitionManager.phase() == "hold" then
            break
        end
    end
    check(TransitionManager.phase() == "hold", "shutter reaches hold")
    CursorManager.input("mousemoved", 640, 360)
    for _ = 1, 40 do
        CursorManager.request("hover", 1)
        CursorManager.update(DT)
    end
    check(CursorManager.current() == "default", "transitions force the default cursor")
    local function render()
        love.graphics.setCanvas({ canvas, stencil = true })
        love.graphics.clear(0, 0, 0, 1)
        StateManager.draw()
        love.graphics.setCanvas()
        return canvas:newImageData(1, 1, 630, 350, 50, 50)
    end
    local shown = render()
    CursorManager.set_focus(false)
    local hidden = render()
    CursorManager.set_focus(true)
    local diff = 0
    for y = 0, 49 do
        for x = 0, 49 do
            local r1, g1, b1 = shown:getPixel(x, y)
            local r2, g2, b2 = hidden:getPixel(x, y)
            diff = diff + math.abs(r1 - r2) + math.abs(g1 - g2) + math.abs(b1 - b2)
        end
    end
    check(diff > 20, "cursor is drawn above the closed shutter (diff " .. string.format("%.1f", diff) .. ")")
    done = true
    for _ = 1, 600 do
        TransitionManager.update(DT)
        if not TransitionManager.is_active() then
            break
        end
    end
    check(not TransitionManager.is_active(), "shutter finishes")
end

local function check_workshop()
    local Workshop = require("systems.Workshop")
    local WorkshopInput = require("ui.WorkshopInput")
    local Slots = require("ui.Slots")
    local Item = require("entities.Item")
    local w = Workshop({ difficulty = "broker" })
    local input = WorkshopInput(w, function() end)
    local mode = "day"
    Slots.set_mode_provider(function() return mode end)
    local function at(x, y)
        input.pointer.x, input.pointer.y = x, y
        return input:cursor_name()
    end
    local function owned(id)
        local item = Item(id, { grade = "rare" })
        item.owned = true
        return item
    end
    local r = input:button("new_customer").rect
    check(at(r.x + r.w / 2, r.y + r.h / 2) == "hover", "enabled buttons show hover")
    w.inventory:place(owned("flame_sword"), "storage", 1)
    local sx, sy = Slots.center("storage", 1)
    check(at(sx, sy) == "grab", "storage relics show the open glove")
    input:mousepressed(sx, sy, 1)
    check(input.drag ~= nil and input:cursor_name() == "grabbing", "dragging shows the gripping glove")
    input:mousereleased(sx, sy, 1)
    w.inventory:place(owned("lightning_orb"), "bench", 1)
    local bx, by = Slots.center("bench", 1)
    check(at(bx, by) == "appraise", "the workbench relic shows the magnifier")
    input.tool = "brush"
    check(at(bx, by) == "hidden", "the scrub brush is drawn instead of a cursor")
    input.tool = "none"
    w.phase, mode = "night", "night"
    w.combat.webs[13] = 5
    local gx, gy = Slots.center("grid", 13)
    check(at(gx, gy) == "web_cut", "web-sealed cells show the silver dagger at night")
    w.combat.webs[13] = nil
    check(at(gx, gy) == "default", "plain night cells show the default pointer")
    w.phase = "day"
    Slots.set_mode_provider(nil)
    input:destroy()
    w:destroy()
end

function SmokeCursor.run(log, shots)
    local CursorManager = require("ui.CursorManager")
    local CursorShapes = require("ui.CursorShapes")
    CursorManager.install()
    check(CursorManager.snapshot().installed, "cursor manager installs as the top layer")
    love.graphics.push("all")
    check_requests(CursorManager)
    check_motion(CursorManager)
    check_focus(CursorManager)
    check_shapes(CursorShapes, shots)
    check_draw_order(CursorManager)
    love.graphics.pop()
    check_workshop()
    log("cursor ok (priority requests · press · ripple · sway · pop · focus/quit OS cursor · 6 shapes on hotspot · "
        .. "drawn above transitions · workshop grab/grabbing/appraise/hidden/web_cut)")
end

return SmokeCursor
