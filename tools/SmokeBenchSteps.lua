-- tools/SmokeBenchSteps.lua
-- 스모크 스텝 확장 (SmokeSteps.new 가 install 한다): 작업대 몸짓 — UV 렌즈 훑기(sweep_bench) · 세척 브러시 문지르기(scrub).

local SmokeBenchSteps = {}

local SWEEP_STEPS = 9      -- UV 훑기 격자 한 변의 점 수

function SmokeBenchSteps.install(S, step, push_move)
    local StateManager = require("core.StateManager")
    local TransitionManager = require("ui.TransitionManager")
    local Slots = require("ui.Slots")
    local LAYOUT = require("data.layout")

    function S.sweep_bench(keep_holding)
        local x, y, w, h = Slots.rect("bench", 1)
        local steps = { S.input("begin UV sweep (hold left button)", function()
            S.clear_events()
            push_move(x + 10, y + 10)
            love.event.push("mousepressed", x + 10, y + 10, 1, false, 1)
        end) }
        -- 두 번 훑는다 (두 번째는 거꾸로): 테스트 창 위에서 실제 마우스가 움직이면 같은 이벤트 큐로 들어와
        -- 몇 프레임 포인터를 빼앗을 수 있다 — 한 번 놓친 지점은 두 번째 훑기에서 다시 지나간다
        local points = {}
        for row = 0, SWEEP_STEPS - 1 do
            for col = 0, SWEEP_STEPS - 1 do
                points[#points + 1] = {
                    math.floor(x + 10 + col * (w - 20) / (SWEEP_STEPS - 1)),
                    math.floor(y + 10 + row * (h - 20) / (SWEEP_STEPS - 1)),
                }
            end
        end
        for pass = 1, 2 do
            for i = 1, #points do
                local point = points[pass == 1 and i or (#points + 1 - i)]
                steps[#steps + 1] = S.move(point[1], point[2])
            end
        end
        local last = points[1]
        if not keep_holding then
            steps[#steps + 1] = S.release(last[1], last[2])
        end
        return steps
    end

    -- 브러시로 작업대 문지르기: 누르기 → 지그재그 moves 번 → (release 가 true 면) 놓기
    function S.scrub(moves, press, release)
        local cx, cy = Slots.center("bench", 1)
        local steps = {}
        if press then
            steps[#steps + 1] = S.input("brush down", function()
                S.clear_events()
                push_move(cx, cy)
                love.event.push("mousepressed", cx, cy, 1, false, 1)
            end)
        end
        for i = 1, moves do
            local dx = (i % 2 == 0) and -60 or 60
            steps[#steps + 1] = S.move(cx + dx, cy - 50 + (i % 5) * 25)
        end
        if release then
            steps[#steps + 1] = S.call("brush up", function()
                love.event.push("mousereleased", cx, cy, 1, false, 1)
            end)
        end
        return steps
    end

end

return SmokeBenchSteps
