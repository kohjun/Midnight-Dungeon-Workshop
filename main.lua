-- main.lua
-- LÖVE 진입점. 모든 콜백을 core/StateManager 에 위임만 한다. 게임 로직 금지.

require("lib.strict").enable()
require("tools.SmokeTest").install_if_requested(arg) -- `--smoke-test` 플래그가 있을 때만 동작

local StateManager = require("core.StateManager")

local INITIAL_STATE = "TitleState"   -- 인트로는 난이도 계약 뒤에 나온다 (DifficultyState → IntroState)

-- StateManager.dispatch 로 그대로 전달하는 LÖVE 콜백
local FORWARDED_CALLBACKS = {
    "keypressed", "keyreleased", "textinput", "textedited",
    "mousepressed", "mousereleased", "mousemoved", "wheelmoved",
    "gamepadpressed", "gamepadreleased",
    "resize", "focus", "mousefocus",
}

function love.load()
    StateManager.init(INITIAL_STATE)
end

function love.update(dt)
    StateManager.update(dt)
end

function love.draw()
    StateManager.draw()
end

-- true 를 반환하면 종료가 취소된다
function love.quit()
    return StateManager.quit()
end

for _, name in ipairs(FORWARDED_CALLBACKS) do
    love[name] = function(...)
        return StateManager.dispatch(name, ...)
    end
end
