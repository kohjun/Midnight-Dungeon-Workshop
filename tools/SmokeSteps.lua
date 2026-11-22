-- tools/SmokeSteps.lua
-- 스모크 시나리오용 스텝 생성기: 입력 이벤트 주입(클릭·드래그·키·문지르기·UV 홀드 훑기), 상태·이벤트 대기, 스크린샷.
-- 스텝 = { label, run(frame) → true | 건너뛸 스텝 수, timeout(실시간 초), quiet }.
-- 화면 전환(ui/TransitionManager) 중에는 누르는 입력이 잠기므로, 입력 스텝(S.input 기반)과 S.expect_state 는 전환이 끝날 때까지 기다린다.
-- SmokeSteps.new(ctx) → S (스텝 생성 함수 모음), script (빈 목록), add(...) (스텝/스텝 목록 추가)

local SmokeSteps = {}


local function step(label, run, timeout)
    return { label = label, run = run, timeout = timeout }
end

function SmokeSteps.new(ctx)
    local StateManager = require("core.StateManager")
    local TransitionManager = require("ui.TransitionManager")
    local Slots = require("ui.Slots")
    local LAYOUT = require("data.layout")
    local S = {}

    -- 이후 expect_event 가 이 동작 뒤의 이벤트만 보도록 카운터 초기화
    function S.clear_events()
        for name in pairs(ctx.events) do
            ctx.events[name] = 0
        end
    end

    local function push_move(x, y)
        love.event.push("mousemoved", x, y, 0, 0, false)
    end

    function S.expect_state(name, timeout)
        return step("expect state " .. name, function()
            return StateManager.current_name() == name and not TransitionManager.is_active()
        end, timeout)
    end

    -- 진행 중인 화면 전환이 끝날 때까지
    function S.wait_transition(timeout)
        return step("wait for screen transition", function()
            return not TransitionManager.is_active()
        end, timeout)
    end

    function S.expect_event(name, timeout)
        return step("expect event " .. name, function()
            return (ctx.events[name] or 0) > 0
        end, timeout)
    end

    -- 튜토리얼이 해당 단계에 도달할 때까지 대기
    function S.expect_tutorial(step_id)
        return step("expect tutorial step " .. step_id, function()
            local last = ctx.last["tutorial:step_changed"]
            return last ~= nil and last.step == step_id
        end)
    end

    function S.wait(frames)
        return step("wait " .. frames .. " frames", function(frame)
            return frame >= frames
        end, math.huge)
    end

    -- 실시간 대기 (타자기 효과처럼 프레임 수와 무관하게 진행되는 연출용)
    function S.wait_seconds(seconds)
        local started = nil
        return step(string.format("wait %.1fs", seconds), function()
            started = started or love.timer.getTime()
            if love.timer.getTime() - started >= seconds then
                started = nil
                return true
            end
            return false
        end, seconds + 5)
    end

    function S.check(label, fn)
        return step("check " .. label, function()
            assert(fn(), "smoke check failed: " .. label)
            return true
        end)
    end

    -- 커서(ui/CursorManager)가 name 이 될 때까지 기다린다. x, y: 매 프레임 포인터를 다시 옮긴다 (실제 마우스 간섭 대비)
    function S.cursor(name, x, y)
        return step("expect cursor " .. name, function()
            if x ~= nil then push_move(x, y) end
            return require("ui.CursorManager").current() == name
        end, 3)
    end

    function S.call(label, fn)
        return step(label, function()
            fn()
            return true
        end)
    end

    -- 입력 주입: 화면 전환이 끝난 뒤에 넣는다 (전환 중 입력은 StateManager 가 버린다)
    function S.input(label, fn)
        return step(label, function()
            if TransitionManager.is_active() then
                return false
            end
            fn()
            return true
        end)
    end

    function S.move(x, y)
        local entry = S.call(string.format("move (%d, %d)", x, y), function()
            push_move(x, y)
        end)
        entry.quiet = true
        return entry
    end

    -- 조건이 거짓이면 다음 count 개 스텝을 건너뛴다
    function S.skip_unless(label, condition, count)
        return step("if " .. label, function()
            if condition() then
                return true
            end
            print(string.format("[SMOKE]      (condition false: skipping %d steps)", count))
            return count
        end)
    end

    local function press_at(x, y)
        S.clear_events()
        push_move(x, y)
        love.event.push("mousepressed", x, y, 1, false, 1)
        love.event.push("mousereleased", x, y, 1, false, 1)
    end

    function S.click(x, y, label)
        return S.input(label or string.format("click (%d, %d)", x, y), function() press_at(x, y) end)
    end

    function S.click_rect(rect, label)
        return S.click(math.floor(rect.x + rect.w / 2), math.floor(rect.y + rect.h / 2), label)
    end

    -- 실행 시점에 사각형을 구해 누른다 (자리가 바뀌는 튜토리얼 안내 띠 버튼 등)
    function S.click_at(label, rect_fn)
        return S.input(label, function()
            local rect = rect_fn()
            press_at(math.floor(rect.x + rect.w / 2), math.floor(rect.y + rect.h / 2))
        end)
    end

    function S.button(id)
        return S.click_rect(LAYOUT.buttons[id], "click button " .. id)
    end

    -- 난이도 선택 화면의 카드 (1부터, data/difficulties.lua 의 order — 위 줄 3장 · 아래 줄 2장)
    local function card_rect(index)
        return require("ui.ContractCards").rect(index)
    end

    function S.difficulty_card(index)
        return S.click_rect(card_rect(index), "click difficulty card " .. index)
    end

    function S.hover_card(index)
        local rect = card_rect(index)
        return S.move(math.floor(rect.x + rect.w / 2), math.floor(rect.y + rect.h / 2))
    end

    -- 타이틀 세로 메뉴 항목 (1 시작하기 · 2 영구 강화 · 3 유물 도감 · 4 튜토리얼 · 5 환경 설정 · 6 종료)
    -- 타이틀 메뉴 항목: 번호 또는 id ("continue" · "start" · "meta" · "compendium" · "settings" · "quit")
    function S.menu_item(which)
        return step("click title menu item " .. tostring(which), function()
            if TransitionManager.is_active() or StateManager.current_name() ~= "TitleState" then
                return false
            end
            local index = type(which) == "string" and assert(StateManager.current():menu_index(which), "no menu item " .. which) or which
            local rect = require("ui.MenuList").item_rect(LAYOUT.title.menu, index)
            press_at(math.floor(rect.x + rect.w / 2), math.floor(rect.y + rect.h / 2))
            return true
        end)
    end

    function S.press(key)
        return S.input("press " .. key, function()
            S.clear_events()
            love.event.push("keypressed", key, key, false)
            love.event.push("keyreleased", key, key)
        end)
    end

    -- 글자 입력 주입 (한 글자씩 textinput 이벤트)
    function S.type_text(text)
        return S.input("type '" .. text .. "'", function()
            local utf8 = require("utf8")
            for _, code in utf8.codes(text) do
                love.event.push("textinput", utf8.char(code))
            end
        end)
    end

    function S.shot(name)
        return S.call("screenshot " .. name, function()
            if ctx.shots then
                love.graphics.captureScreenshot("smoke_" .. name .. ".png")
            end
        end)
    end

    function S.speed(multiplier)
        return S.call("speed x" .. multiplier, function()
            ctx.speed = multiplier
        end)
    end

    -- 슬롯 → 슬롯 드래그 앤 드롭 (누르기 → 이동 2프레임 → 놓기)
    function S.drag(from_area, from_index, to_area, to_index)
        local x1, y1 = Slots.center(from_area, from_index)
        local x2, y2 = Slots.center(to_area, to_index)
        local label = string.format("drag %s#%d -> %s#%d", from_area, from_index, to_area, to_index)
        return {
            S.input(label, function()
                S.clear_events()
                push_move(x1, y1)
                love.event.push("mousepressed", x1, y1, 1, false, 1)
            end),
            S.move((x1 + x2) / 2, (y1 + y2) / 2),
            S.move(x2, y2),
            S.call("release", function()
                love.event.push("mousereleased", x2, y2, 1, false, 1)
            end),
        }
    end

    -- 왼쪽 버튼 놓기 (홀드 종료)
    function S.release(x, y)
        return S.call("release left button", function()
            love.event.push("mousereleased", x, y, 1, false, 1)
        end)
    end

    require("tools.SmokeBenchSteps").install(S, step, push_move)   -- 작업대 몸짓 (UV 훑기 · 브러시 문지르기)

    local script = {}
    local function add(...)
        for _, entry in ipairs({ ... }) do
            if entry.run ~= nil then
                script[#script + 1] = entry
            else
                for _, nested in ipairs(entry) do
                    script[#script + 1] = nested
                end
            end
        end
    end
    return S, script, add
end

return SmokeSteps
