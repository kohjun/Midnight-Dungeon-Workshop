-- tools/Lint.lua
-- 정적 검사 (CLAUDE.md 규칙 강제):
--   1) 모든 .lua 파일 문법 (컴파일만, 실행 안 함)
--   2) 파일당 300줄 제한
--   3) core/RNG.lua 밖에서의 난수 API 직접 사용 금지
-- Lint.run() → problems(문자열 배열, 비어 있으면 통과), 검사한 파일 수

local Lint = {}

local MAX_LINES = 300
local SELF_PATH = "tools/Lint.lua"

local FORBIDDEN = {
    {
        pattern = "math%.random",
        message = "random API used directly - use core/RNG instead",
        allow = {},
    },
    {
        pattern = "newRandomGenerator",
        message = "random generator created outside core/RNG.lua",
        allow = { ["core/RNG.lua"] = true },
    },
}

local function collect_lua_files(directory, out)
    for _, item in ipairs(love.filesystem.getDirectoryItems(directory)) do
        local path = (directory == "") and item or (directory .. "/" .. item)
        local info = love.filesystem.getInfo(path)
        if info ~= nil and info.type == "directory" then
            if item:sub(1, 1) ~= "." then
                collect_lua_files(path, out)
            end
        elseif info ~= nil and info.type == "file" and item:match("%.lua$") then
            out[#out + 1] = path
        end
    end
    return out
end

local function count_lines(content)
    if content == "" then
        return 0
    end
    local _, newlines = content:gsub("\n", "")
    if content:sub(-1) ~= "\n" then
        newlines = newlines + 1
    end
    return newlines
end

local function syntax_error(path)
    local ok, chunk, message = pcall(love.filesystem.load, path)
    if not ok then
        return tostring(chunk)
    end
    if chunk == nil then
        return tostring(message)
    end
    return nil
end

-- 한 줄 주석(--)은 제외하고 검사한다
local function check_forbidden(path, content, problems)
    if path == SELF_PATH then
        return
    end
    local line_number = 0
    for line in (content .. "\n"):gmatch("(.-)\r?\n") do
        line_number = line_number + 1
        local code = line:gsub("%-%-.*$", "")
        for _, rule in ipairs(FORBIDDEN) do
            if not rule.allow[path] and code:find(rule.pattern) then
                problems[#problems + 1] = string.format("%s:%d: %s", path, line_number, rule.message)
            end
        end
    end
end

function Lint.run()
    local problems = {}
    local files = collect_lua_files("", {})
    table.sort(files)

    for _, path in ipairs(files) do
        local content = love.filesystem.read(path) or ""
        local lines = count_lines(content)
        if lines > MAX_LINES then
            problems[#problems + 1] = string.format("%s: %d lines (max %d) - split the module", path, lines, MAX_LINES)
        end
        local message = syntax_error(path)
        if message ~= nil then
            problems[#problems + 1] = string.format("%s: syntax error: %s", path, message)
        end
        check_forbidden(path, content, problems)
    end

    return problems, #files
end

return Lint
