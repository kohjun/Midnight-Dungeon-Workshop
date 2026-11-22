-- ui/CursorManager.lua
-- 커스텀 마우스 커서 (도안 ui/CursorShapes, 수치 data/cursors). 운영체제 커서는 창에 포커스가 있는 동안 숨기고,
-- 포커스를 잃거나 게임을 끝낼 때 되돌린다.
--   CursorManager.request(name, priority)  매 프레임 update 중에 원하는 커서를 요청한다. 우선순위가 가장 높은 요청
--                                          (같으면 나중 요청)이 그 프레임의 커서가 되고, 요청이 없으면 "default".
--     name: "default" | "hover" | "grab" | "grabbing" | "appraise" | "web_cut" | "hidden"(브러시처럼 직접 그릴 때)
--     우선순위 관례: 버튼·메뉴·카드 호버 1 (ui/Button · MenuList · CompendiumModal) · 공방 화면 판정 2 (RunState)
--   CursorManager.clear()                  지금까지의 요청을 버린다 (모달이 화면을 덮었을 때)
-- StateManager 의 최상위 층(top layer)으로 등록되어 모든 상태 · 모달 · 화면 전환(TransitionManager)보다 나중에,
-- 레터박스 띠까지 덮도록 창 좌표에서 그린다. 입력은 전환 잠금보다 먼저 받는다 (포인터 위치 · 클릭 파동).
-- 연출: 이동 속도에 따른 기울기(sway) · 누르는 동안 눌림 · 상태가 바뀔 때 톡 튀는 확대 · 클릭 지점 금빛/잉크 파동.
-- 헤드리스(마우스·창 없음)에서도 조용히 동작한다.

local StateManager = require("core.StateManager")
local Viewport = require("core.Viewport")
local CursorShapes = require("ui.CursorShapes")
local CursorHammer = require("ui.CursorHammer")
local CURSORS = require("data.cursors")

local CursorManager = {}

local LG = love.graphics
local HIDDEN = "hidden"
local TWO_PI = math.pi * 2
local GOLDEN_TURN = 2.39996

local _installed = false
local _request, _priority = nil, nil
local _s = {
    name = "default", x = nil, y = nil, move_x = 0, velocity = 0, tilt = 0, press = 0, held = false,
    pop = 0, hover = 0, time = 0, focused = true, inside = true,
}
local _ripples = {}
local _turn = 0

local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

local function set_os_cursor(visible)
    if love.mouse ~= nil and love.mouse.setVisible ~= nil then
        pcall(love.mouse.setVisible, visible)
    end
end

local function window_focused()
    if love.window == nil or love.window.hasFocus == nil then
        return true
    end
    local ok, focused = pcall(love.window.hasFocus)
    return not ok or focused == true
end

function CursorManager.install()
    if _installed then
        return
    end
    _installed = true
    _s.focused = window_focused()
    if love.mouse ~= nil and love.mouse.getPosition ~= nil then
        local ok, x, y = pcall(Viewport.mouse_position)
        if ok then
            _s.x, _s.y = x, y
        end
    end
    StateManager.set_top_layer({
        update = CursorManager.update, draw = CursorManager.draw, input = CursorManager.input, quit = CursorManager.restore,
    })
    set_os_cursor(not _s.focused)
end

function CursorManager.request(name, priority)
    assert(name == HIDDEN or CURSORS.states[name] ~= nil, "CursorManager: unknown cursor '" .. tostring(name) .. "'")
    if not _installed then
        CursorManager.install()
    end
    priority = priority or 0
    if _request == nil or priority >= _priority then
        _request, _priority = name, priority
    end
end

function CursorManager.clear()
    _request, _priority = nil, nil
end

function CursorManager.current()
    return _s.name
end

-- 창 포커스: 잃으면 운영체제 커서를 되돌리고 커스텀 커서는 그리지 않는다
function CursorManager.set_focus(focused)
    _s.focused = focused and true or false
    set_os_cursor(not (_s.focused and _installed))
end

-- 게임 종료 등: 운영체제 커서를 되돌린다
function CursorManager.restore()
    set_os_cursor(true)
end

function CursorManager.is_visible()
    return _installed and _s.focused and _s.inside and _s.x ~= nil and _s.name ~= HIDDEN
end

-- 개발 도구(스모크 테스트)용 읽기 전용 스냅숏
function CursorManager.snapshot()
    return {
        name = _s.name, x = _s.x, y = _s.y, tilt = _s.tilt, press = _s.press, pop = _s.pop, hover = _s.hover,
        focused = _s.focused, inside = _s.inside, ripples = #_ripples, installed = _installed,
    }
end

local function spawn_ripple(x, y)
    local spec = CURSORS.states[_s.name] or CURSORS.states.default
    local ripple = CursorHammer.applies(_s.name) and CURSORS.hammer.ripple or spec.ripple     -- 망치: 작은 금빛·백색 타격 불티
    _turn = _turn + GOLDEN_TURN
    _ripples[#_ripples + 1] = { x = x, y = y, t = 0, spec = ripple, turn = _turn }
    while #_ripples > CURSORS.ripple.max do
        table.remove(_ripples, 1)
    end
end

-- StateManager 가 전환 잠금보다 먼저 넘겨 준다 (포인터 콜백은 논리 좌표)
function CursorManager.input(callback, a, b)
    if callback == "mousemoved" then
        if _s.x ~= nil then
            _s.move_x = _s.move_x + (a - _s.x)
        end
        _s.x, _s.y, _s.inside = a, b, true
    elseif callback == "mousepressed" then
        _s.x, _s.y, _s.held, _s.press = a, b, true, 1
        spawn_ripple(a, b)
        CursorHammer.press(_s.name, _s.time)            -- 망치: 내려찍기 + 버튼이 아닌 곳이면 톡 소리
    elseif callback == "mousereleased" then
        _s.held = false
    elseif callback == "focus" then
        CursorManager.set_focus(a)
    elseif callback == "mousefocus" then
        _s.inside = a and true or false
    end
end

local function resolve()
    local name = _request or "default"
    if StateManager.input_locked() then      -- 화면 전환 중에는 누를 것이 없다
        name = "default"
    end
    _request, _priority = nil, nil
    if name ~= _s.name then
        _s.name, _s.pop = name, 1
    end
end

function CursorManager.update(dt)
    resolve()
    CursorHammer.update(dt)
    local s, sway, press = _s, CURSORS.sway, CURSORS.press
    s.time = s.time + dt
    if dt > 0 then
        s.velocity = s.velocity + (s.move_x / dt - s.velocity) * math.min(1, dt * sway.smooth)
    end
    s.move_x = 0
    local target = clamp(-s.velocity * sway.per_speed, -sway.max, sway.max)    -- 끌려오는 쪽으로 기운다
    s.tilt = s.tilt + (target - s.tilt) * math.min(1, dt * sway.follow)
    if s.held then
        s.press = s.press + (1 - s.press) * math.min(1, dt * press.down_speed)
    else
        s.press = s.press * (1 - math.min(1, dt * press.up_speed))
    end
    s.pop = s.pop * (1 - math.min(1, dt * CURSORS.switch_speed))
    s.hover = s.hover + ((s.name == "hover" and 1 or 0) - s.hover) * math.min(1, dt * CURSORS.hover_speed)
    for i = #_ripples, 1, -1 do
        local ripple = _ripples[i]
        ripple.t = ripple.t + dt
        if ripple.t >= CURSORS.ripple.life then
            table.remove(_ripples, i)
        end
    end
end

-- 클릭 파동: 잉크 고리가 금빛(상태별 색) 고리를 뒤따르며 퍼지고, 짧은 불티가 튄다
local function draw_ripple(ripple)
    local cfg, spec = CURSORS.ripple, ripple.spec
    local p = ripple.t / cfg.life
    local radius = spec.radius * (0.25 + 0.75 * (1 - (1 - p) ^ 3))
    local alpha = 1 - p
    LG.setColor(spec.ink[1], spec.ink[2], spec.ink[3], 0.6 * alpha)
    LG.setLineWidth(cfg.width + 2)
    LG.circle("line", ripple.x, ripple.y, radius * 0.8, 32)
    LG.setColor(spec.color[1], spec.color[2], spec.color[3], alpha)
    LG.setLineWidth(cfg.width * (1 - 0.6 * p))
    LG.circle("line", ripple.x, ripple.y, radius, 32)
    local inner, outer = radius * 1.05, radius * 1.05 + cfg.spark_len * (1 - p)
    LG.setLineWidth(1.6)
    for i = 1, spec.sparks do
        local angle = ripple.turn + i / spec.sparks * TWO_PI
        local cx, cy = math.cos(angle), math.sin(angle)
        LG.line(ripple.x + cx * inner, ripple.y + cy * inner, ripple.x + cx * outer, ripple.y + cy * outer)
    end
end

function CursorManager.draw()
    if not _installed then
        return
    end
    LG.push("all")
    LG.setScissor()
    LG.setShader()
    LG.setBlendMode("alpha")
    local ox, oy = Viewport.to_window(0, 0)
    LG.translate(ox, oy)
    LG.scale(Viewport.scale())
    for _, ripple in ipairs(_ripples) do
        draw_ripple(ripple)
    end
    if CursorManager.is_visible() then
        local spec = CURSORS.states[_s.name]
        local scale = spec.size / CURSORS.unit * spec.scale * (1 + CURSORS.switch_pop * _s.pop)
            * (1 + (spec.click_scale - 1) * _s.press)
        LG.translate(_s.x, _s.y)
        LG.rotate(_s.tilt)
        if CursorHammer.applies(_s.name) then           -- 기본 · 호버 = 대장장이 망치 (원화가 없으면 단검 도안)
            LG.scale(spec.scale * (1 + CURSORS.switch_pop * _s.pop) * (1 + (spec.click_scale - 1) * _s.press * 0.5))
            CursorHammer.draw(_s.hover)
        else
            LG.scale(scale)
            CursorShapes.draw(_s.name, _s.time, _s.hover)
        end
    end
    LG.pop()
end

return CursorManager
