-- ui/TransitionManager.lua
-- 공방 도구·설비를 모티브로 한 화면 전환 (시간표·색은 data/transitions.lua, 그림은 ui/TransitionSeal · ui/TransitionShutter).
--
--   TransitionManager.start(mode, callback, options) → 시작했으면 true (이미 전환 중이면 false — 중복 클릭 차단)
--     mode     : "wax_seal" | "lens_iris" | "shutter_slam" | "dawn_candle"
--     callback : 화면을 완전히 덮은 순간 한 번 호출 (보통 StateManager.switch 나 밤 시작). nil 가능
--     options  : { x, y = 연출 중심(도장 찍는 곳·조리개 중심), wait = fn() → true 가 될 때까지 덮은 채 대기,
--                  on_done = 다 걷힌 뒤 호출 }
--   TransitionManager.is_active() : 전환 중이면 true — 이 동안 StateManager 가 누르는 입력(키·마우스 버튼·휠·텍스트)을 전부 잠근다
--
-- 순서: cover(덮기) → callback → hold(최소 시간 + wait 조건, 최대 max_hold) → reveal(걷기) → 끝.
-- StateManager 오버레이로 등록되어 모든 상태 위에 그리고, 흔들림은 화면 전체에 건다. 먼지 등 파티클은 전환이 끝나도 마저 흩날린다.

local StateManager = require("core.StateManager")
local Viewport = require("core.Viewport")
local Audio = require("systems.Audio")
local Effects = require("ui.Effects")
local TransitionSeal = require("ui.TransitionSeal")
local TransitionShutter = require("ui.TransitionShutter")
local TRANSITIONS = require("data.transitions")

local TransitionManager = {}

local MODES = {}
for _, module in ipairs({ TransitionSeal, TransitionShutter }) do
    for name, art in pairs(module.MODES) do
        assert(TRANSITIONS.modes[name] ~= nil, "TransitionManager: no data for mode '" .. name .. "'")
        MODES[name] = art
    end
end

local _current = nil        -- { mode, spec, art, phase, t, callback, options, x, y, time }
local _fx = nil
local _installed = false

local function fx()
    if _fx == nil then
        _fx = Effects()
    end
    return _fx
end

function TransitionManager.is_active()
    return _current ~= nil
end

-- 지금 전환 모드 (없으면 nil)
function TransitionManager.mode()
    return _current and _current.mode
end

function TransitionManager.phase()
    return _current and _current.phase
end

-- 그 모드가 화면을 다 덮는 데 걸리는 시간
function TransitionManager.cover_time(mode)
    return TRANSITIONS.modes[mode].cover
end

function TransitionManager.modes()
    local names = {}
    for name in pairs(MODES) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

local function play(name)
    if name ~= nil then
        Audio.play(name)
    end
end

-- art 의 단계 시작 훅 호출 (소리 등)
local function enter_phase(c, phase)
    c.phase, c.t = phase, 0
    local hook = c.art["on_" .. phase]
    if hook ~= nil then
        hook(c, fx(), play)
    end
end

function TransitionManager.update(dt)
    local effects = fx()
    effects:update(dt)
    local c = _current
    if c == nil then
        return
    end
    c.t, c.time = c.t + dt, c.time + dt
    if c.art.update ~= nil then
        c.art.update(c, dt, effects, play)
    end
    local spec = c.spec
    if c.phase == "cover" and c.t >= spec.cover then
        enter_phase(c, "hold")
        if c.callback ~= nil then
            c.callback()
        end
    elseif c.phase == "hold" and c.t >= spec.hold then
        local ready = c.options.wait == nil or c.options.wait() or c.t >= TRANSITIONS.max_hold
        if ready then
            enter_phase(c, "reveal")
        end
    elseif c.phase == "reveal" and c.t >= spec.reveal then
        _current = nil
        if c.options.on_done ~= nil then
            c.options.on_done()
        end
    end
end

function TransitionManager.draw()
    local c = _current
    if c ~= nil then
        c.art.draw(c, Viewport.width(), Viewport.height())
    end
    if _fx ~= nil then
        _fx:draw()
        _fx:draw_flash()
    end
end

local function install()
    if _installed then
        return
    end
    _installed = true
    StateManager.set_overlay({
        update = TransitionManager.update,
        draw = TransitionManager.draw,
        blocks_input = TransitionManager.is_active,
        push_transform = function() fx():push_shake() end,
        pop_transform = function() fx():pop_shake() end,
    })
end

function TransitionManager.start(mode, callback, options)
    install()
    if _current ~= nil then
        return false
    end
    local art, spec = MODES[mode], TRANSITIONS.modes[mode]
    assert(art ~= nil and spec ~= nil, "TransitionManager: unknown mode '" .. tostring(mode) .. "'")
    options = options or {}
    _current = {
        mode = mode, spec = spec, art = art, phase = "cover", t = 0, time = 0, callback = callback, options = options,
        x = options.x or Viewport.width() / 2, y = options.y or Viewport.height() / 2, sw = Viewport.width(), sh = Viewport.height(),
    }
    enter_phase(_current, "cover")
    return true
end

return TransitionManager
