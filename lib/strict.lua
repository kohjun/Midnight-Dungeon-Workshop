-- lib/strict.lua
-- _G 잠금: 프로젝트 코드에서의 전역 변수 대입과 미선언 전역 읽기를 런타임 에러로 만든다.
-- main.lua 최상단에서 한 번 enable() 한다.
-- 검사 대상은 파일에서 로드된 청크(source 가 "@" 로 시작)뿐이다. LÖVE 내장 스크립트는 건드리지 않는다.

local Strict = {}

local _enabled = false

-- level: 메타메서드를 유발한 코드의 스택 레벨
local function is_project_code(level)
    local info = debug.getinfo(level, "S")
    return info ~= nil and info.source:sub(1, 1) == "@"
end

local function on_assign(globals, name, value)
    if is_project_code(3) then
        error(string.format("[strict] implicit global assignment '%s' is forbidden - use local", tostring(name)), 2)
    end
    rawset(globals, name, value)
end

local function on_read(_, name)
    if is_project_code(3) then
        error(string.format("[strict] read of undeclared global '%s'", tostring(name)), 2)
    end
    return nil
end

function Strict.enable()
    if _enabled then
        return
    end
    _enabled = true

    local meta = getmetatable(_G)
    if meta == nil then
        meta = {}
        setmetatable(_G, meta)
    end
    meta.__newindex = on_assign
    meta.__index = on_read
end

function Strict.is_enabled()
    return _enabled
end

return Strict
