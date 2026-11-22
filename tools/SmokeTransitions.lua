-- tools/SmokeTransitions.lua
-- 헤드리스 검사 (SmokeTest 가 SmokeCollection 다음에 실행): 화면 전환 4종 (ui/TransitionManager).
--   콜백은 화면을 다 덮은 순간 정확히 한 번 · 전환 중 두 번째 start 거부(중복 클릭 차단) · 전환 중 StateManager 입력 잠금
--   · wait 조건이 참이 될 때까지 덮은 채 대기 · 모든 단계를 오프스크린(스텐실 포함)으로 그려도 오류 없음 · 끝나면 비활성

local SmokeTransitions = {}

local DT = 1 / 60
local MAX_STEPS = 60 * 12

local function check(condition, message)
    if not condition then
        error("SmokeTransitions: " .. message, 2)
    end
end

local function run_mode(mode, canvas)
    local StateManager = require("core.StateManager")
    local TransitionManager = require("ui.TransitionManager")
    local calls, ready = 0, false
    check(TransitionManager.start(mode, function() calls = calls + 1 end, {
        x = 300, y = 260, wait = function() return ready end,
    }), mode .. " should start")
    check(TransitionManager.is_active() and StateManager.input_locked(), mode .. " locks input while active")
    check(not TransitionManager.start("wax_seal", function() calls = calls + 100 end), "a second start is rejected while active")
    local phases, held = {}, 0
    for _ = 1, MAX_STEPS do
        TransitionManager.update(DT)
        local phase = TransitionManager.phase()
        if phase == nil then
            break
        end
        phases[phase] = true
        if phase == "hold" then
            held = held + 1
            ready = held > 30          -- 반 초 동안 wait 조건을 거짓으로 둔다
        end
        love.graphics.setCanvas({ canvas, stencil = true })
        love.graphics.clear(0.2, 0.3, 0.4, 1)
        StateManager.draw()
        love.graphics.setCanvas()
    end
    check(not TransitionManager.is_active() and not StateManager.input_locked(), mode .. " should finish and unlock input")
    check(calls == 1, mode .. " callback must run exactly once (ran " .. calls .. ")")
    check(phases.cover and phases.hold and phases.reveal, mode .. " goes through cover, hold and reveal")
    check(held > 30, mode .. " waits for its condition before revealing")
end

function SmokeTransitions.run(log)
    local Viewport = require("core.Viewport")
    local TransitionManager = require("ui.TransitionManager")
    local canvas = love.graphics.newCanvas(Viewport.width(), Viewport.height())
    love.graphics.push("all")
    local modes = TransitionManager.modes()
    for _, mode in ipairs(modes) do
        run_mode(mode, canvas)
    end
    love.graphics.pop()
    check(#modes == 4, "4 transition modes")
    log("transitions ok (%s: callback once, duplicate start blocked, input locked, wait/hold, all phases drawn)",
        table.concat(modes, " · "))
end

return SmokeTransitions
