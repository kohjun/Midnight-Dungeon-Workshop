-- core/StateManager.lua
-- 싱글톤 화면 상태 관리자 (스택 기반).
--
--   StateManager.switch("RunState", { seed = 42 })  -- 스택 전체 교체
--   StateManager.push("PauseState")                  -- 위에 쌓기 (아래 상태는 pause)
--   StateManager.pop()                               -- 최상단 제거 (아래 상태는 resume)
--
-- 상태는 "states.<이름>" 모듈을 지연 require 하므로 상태끼리 서로 require 하지 않는다.
-- 전환 요청은 큐에 쌓였다가 다음 update 시작 시 적용된다 (콜백 도중 상태가 바뀌지 않음).
-- 상태 메서드는 정의된 것만 호출: enter/exit/pause/resume/update/draw/quit + LÖVE 입력 콜백.
-- 그리기와 마우스 좌표는 core/Viewport 의 논리 해상도(1280x720) 기준으로 변환해서 넘긴다.
-- 오버레이(화면 전환, ui/TransitionManager 가 등록): 모든 상태 위에 그리고, 활성 중에는 누르는 입력을 잠근다.
--   overlay = { update(dt), draw(), blocks_input() → bool, push_transform(), pop_transform() }  (core 는 ui 를 모른다)
-- 최상위 층(커스텀 커서, ui/CursorManager 가 등록): 오버레이보다 나중에 갱신하고, 레터박스 띠까지 덮도록 Viewport 밖에서
-- 그린다. 입력은 잠금 검사 전에 먼저 받는다 (포인터 콜백은 논리 좌표). 종료가 확정되면 quit() 을 부른다.
--   top = { update(dt), draw(), input(callback, ...), quit() }

local Viewport = require("core.Viewport")

local StateManager = {}

local STATE_MODULE_PREFIX = "states."
local MAX_TRANSITIONS_PER_FRAME = 16
local POINTER_CALLBACKS = { mousepressed = true, mousereleased = true, mousemoved = true }
-- 오버레이가 잠그는 입력: 누르는 입력만 (떼기·이동은 통과시켜 눌린 상태가 남지 않게 한다)
local LOCKED_CALLBACKS = {
    keypressed = true, textinput = true, textedited = true, mousepressed = true, wheelmoved = true,
    gamepadpressed = true,
}

local _stack = {}   -- { { name = string, instance = table }, ... } (아래 → 위)
local _queue = {}   -- 대기 중인 전환 요청
local _overlay = nil
local _top = nil

local function invoke(state, method, ...)
    local fn = state[method]
    if fn ~= nil then
        return fn(state, ...)
    end
    return nil
end

local function top_entry()
    return _stack[#_stack]
end

local function instantiate(name, params)
    local StateClass = require(STATE_MODULE_PREFIX .. name)
    local entry = { name = name, instance = StateClass() }
    -- enter() 안에서 current_name() 이 자신을 가리키도록 먼저 스택에 올린다
    _stack[#_stack + 1] = entry
    invoke(entry.instance, "enter", params)
end

local function exit_top()
    local entry = table.remove(_stack)
    if entry ~= nil then
        invoke(entry.instance, "exit")
    end
end

local APPLY = {
    switch = function(request)
        while #_stack > 0 do
            exit_top()
        end
        instantiate(request.name, request.params)
    end,
    push = function(request)
        local current = top_entry()
        if current ~= nil then
            invoke(current.instance, "pause")
        end
        instantiate(request.name, request.params)
    end,
    pop = function(request)
        assert(#_stack > 1, "StateManager.pop: cannot pop the last state (use switch)")
        exit_top()
        invoke(top_entry().instance, "resume", request.params)
    end,
}

local function flush_queue()
    local applied = 0
    while #_queue > 0 do
        applied = applied + 1
        if applied > MAX_TRANSITIONS_PER_FRAME then
            error("StateManager: too many transitions in one frame (transition loop?)")
        end
        local request = table.remove(_queue, 1)
        APPLY[request.kind](request)
    end
end

local function validate_name(name)
    assert(type(name) == "string" and name ~= "", "StateManager: state name must be a non-empty string")
end

-- 최초 상태를 즉시 진입시킨다 (love.load 에서 한 번).
function StateManager.init(name, params)
    validate_name(name)
    assert(#_stack == 0, "StateManager.init: already initialized")
    _queue = { { kind = "switch", name = name, params = params } }
    flush_queue()
end

-- 스택 전체를 새 상태로 교체. 대기 중인 다른 요청은 무시된다.
function StateManager.switch(name, params)
    validate_name(name)
    _queue = { { kind = "switch", name = name, params = params } }
end

function StateManager.push(name, params)
    validate_name(name)
    _queue[#_queue + 1] = { kind = "push", name = name, params = params }
end

-- params 는 아래 상태의 resume(params) 로 전달된다.
function StateManager.pop(params)
    _queue[#_queue + 1] = { kind = "pop", params = params }
end

function StateManager.current()
    local entry = top_entry()
    return entry and entry.instance
end

function StateManager.current_name()
    local entry = top_entry()
    return entry and entry.name
end

function StateManager.depth()
    return #_stack
end

function StateManager.set_overlay(overlay)
    _overlay = overlay
end

function StateManager.set_top_layer(layer)
    _top = layer
end

-- 오버레이가 지금 입력을 잠그고 있는지
function StateManager.input_locked()
    return _overlay ~= nil and _overlay.blocks_input()
end

function StateManager.update(dt)
    flush_queue()
    local entry = top_entry()
    if entry ~= nil then
        invoke(entry.instance, "update", dt)
    end
    if _overlay ~= nil then
        _overlay.update(dt)
    end
    if _top ~= nil then
        _top.update(dt)
    end
end

-- 오버레이를 위해 스택 전체를 아래 → 위 순서로 그린다. 화면 전환 오버레이는 맨 위 (흔들림은 화면 전체에 건다).
function StateManager.draw()
    Viewport.push()
    if _overlay ~= nil then
        _overlay.push_transform()
    end
    for i = 1, #_stack do
        invoke(_stack[i].instance, "draw")
    end
    if _overlay ~= nil then
        _overlay.pop_transform()
        _overlay.draw()
    end
    Viewport.pop()
    if _top ~= nil then
        _top.draw()      -- 커스텀 커서: 모달 · 화면 전환 · 레터박스 띠보다 위
    end
end

-- 마우스 콜백 인자의 창 좌표(와 mousemoved 의 이동량)를 논리 좌표로 바꾼다
local function to_logical_args(callback, x, y, a, b, ...)
    local lx, ly = Viewport.to_logical(x, y)
    if callback == "mousemoved" then
        local scale = Viewport.scale()
        return lx, ly, a / scale, b / scale, ...
    end
    return lx, ly, a, b, ...
end

-- 입력 등 LÖVE 콜백을 최상단 상태에 전달한다.
function StateManager.dispatch(callback, ...)
    if _top ~= nil then
        if POINTER_CALLBACKS[callback] then
            _top.input(callback, to_logical_args(callback, ...))
        else
            _top.input(callback, ...)
        end
    end
    local entry = top_entry()
    if entry == nil then
        return nil
    end
    if callback == "resize" then
        Viewport.configure()
    end
    if LOCKED_CALLBACKS[callback] and StateManager.input_locked() then
        return nil      -- 화면 전환 중: 중복 클릭·키 입력 차단
    end
    if POINTER_CALLBACKS[callback] then
        return invoke(entry.instance, callback, to_logical_args(callback, ...))
    end
    return invoke(entry.instance, callback, ...)
end

-- true 를 반환하면 종료 취소
function StateManager.quit()
    local entry = top_entry()
    local cancelled = entry ~= nil and invoke(entry.instance, "quit") == true
    if not cancelled and _top ~= nil then
        _top.quit()      -- 운영체제 커서 복구
    end
    return cancelled
end

return StateManager
