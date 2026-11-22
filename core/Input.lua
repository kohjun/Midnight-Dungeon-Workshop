-- core/Input.lua
-- data/controls.lua 의 바인딩으로 키/마우스 입력을 액션 이름으로 해석한다.
--
--   function SomeState:keypressed(key)
--       if Input.is_action(key, "confirm") then ... end
--   end
--   local dx = Input.axis("move_left", "move_right")   -- -1, 0, 1

local CONTROLS = require("data.controls")

local Input = {}

local function lookup(group, action)
    local bindings = CONTROLS[group][action]
    if bindings == nil then
        error(string.format("Input: unknown %s action '%s'", group, tostring(action)), 3)
    end
    return bindings
end

local function contains(list, value)
    for i = 1, #list do
        if list[i] == value then
            return true
        end
    end
    return false
end

-- keypressed 콜백의 key 가 action 에 바인딩되어 있는지
function Input.is_action(key, action)
    return contains(lookup("keys", action), key)
end

-- mousepressed 콜백의 button 이 action 에 바인딩되어 있는지
function Input.is_mouse_action(button, action)
    return contains(lookup("mouse", action), button)
end

-- action 의 키 중 하나라도 눌려 있는지 (폴링)
function Input.is_down(action)
    return love.keyboard.isDown(unpack(lookup("keys", action)))
end

-- 두 액션으로 -1 / 0 / 1 축 값
function Input.axis(negative_action, positive_action)
    local value = 0
    if Input.is_down(negative_action) then
        value = value - 1
    end
    if Input.is_down(positive_action) then
        value = value + 1
    end
    return value
end

return Input
