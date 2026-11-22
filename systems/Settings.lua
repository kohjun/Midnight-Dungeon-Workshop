-- systems/Settings.lua
-- 환경 설정(언어·음량·음소거·화면 모드·흔들림 강도·밤 배속). 정의는 data/settings.lua.
-- 세이브 디렉토리의 save_settings.lua 에 자동 저장/로드한다 ("return { language = "ko", ... }" 형태, 빈 환경에서 실행).
-- 값이 바뀌면 "settings:changed" 를 발행한다 — I18n(언어) · Audio(음량) 가 구독한다.
-- 스모크 테스트는 use_memory_only() 로 실제 세이브와 창 모드를 건드리지 않는다.

local EventBus = require("core.EventBus")
local SETTINGS = require("data.settings")

local Settings = {}

local _data = nil
local _persist = true

local function definition(key)
    local option = SETTINGS.options[key]
    assert(option ~= nil, "Settings: unknown option '" .. tostring(key) .. "'")
    return option
end

local function contains(list, value)
    for _, entry in ipairs(list) do
        if entry == value then
            return true
        end
    end
    return false
end

-- 정의에 맞게 값 정리 (맞지 않으면 nil)
local function normalize(key, value)
    local option = definition(key)
    if option.kind == "toggle" then
        if type(value) == "boolean" then
            return value
        end
    elseif option.kind == "percent" then
        local number = tonumber(value)
        if number ~= nil then
            return math.max(0, math.min(100, math.floor(number + 0.5)))
        end
    elseif contains(option.choices, value) then
        return value
    end
    return nil
end

local function sanitize(raw)
    raw = type(raw) == "table" and raw or {}
    local data = {}
    for _, key in ipairs(SETTINGS.order) do
        local value = normalize(key, raw[key])
        if value == nil then
            value = SETTINGS.options[key].default
        end
        data[key] = value
    end
    return data
end

-- 저장 파일 읽기: 빈 환경(setfenv)에서 실행해 테이블만 받는다. 없거나 깨졌으면 기본값
function Settings.read_file(path)
    if love.filesystem.getInfo(path) == nil then
        return sanitize(nil)
    end
    local ok, chunk = pcall(love.filesystem.load, path)
    if not ok or chunk == nil then
        print("[Settings] failed to parse save: " .. tostring(chunk))
        return sanitize(nil)
    end
    setfenv(chunk, {})
    local success, raw = pcall(chunk)
    if not success then
        print("[Settings] failed to read save: " .. tostring(raw))
        return sanitize(nil)
    end
    return sanitize(raw)
end

function Settings.serialize(data)
    local lines = { "return {" }
    for _, key in ipairs(SETTINGS.order) do
        local value = data[key]
        local text = type(value) == "string" and string.format("%q", value) or tostring(value)
        lines[#lines + 1] = string.format("    %s = %s,", key, text)
    end
    lines[#lines + 1] = "}"
    return table.concat(lines, "\n") .. "\n"
end

-- 화면 모드 적용 (창모드 1280x720 ↔ 데스크톱 전체화면). 메모리 전용 모드에서는 창을 건드리지 않는다
local function apply_display(data)
    if not _persist or love.window == nil then
        return
    end
    if love.window.getFullscreen() ~= data.fullscreen then
        local ok, err = pcall(love.window.setFullscreen, data.fullscreen, "desktop")
        if not ok then
            print("[Settings] failed to change the display mode: " .. tostring(err))
        end
    end
end

local function load()
    if _data == nil then
        _data = _persist and Settings.read_file(SETTINGS.save_file) or sanitize(nil)
        apply_display(_data)
    end
    return _data
end

local function save()
    if not _persist then
        return
    end
    local ok, err = love.filesystem.write(SETTINGS.save_file, Settings.serialize(_data))
    if not ok then
        print("[Settings] failed to save: " .. tostring(err))
    end
end

-- 테스트용: 디스크를 읽지도 쓰지도 않고 기본값에서 시작한다
function Settings.use_memory_only()
    _persist = false
    _data = sanitize(nil)
end

function Settings.get(key)
    definition(key)
    return load()[key]
end

function Settings.definition(key)
    return definition(key)
end

function Settings.order()
    return SETTINGS.order
end

-- 값 변경 → 저장 → "settings:changed". 정의에 맞지 않거나 같은 값이면 false
function Settings.set(key, value)
    local data = load()
    local normalized = normalize(key, value)
    if normalized == nil or data[key] == normalized then
        return false
    end
    data[key] = normalized
    save()
    if key == "fullscreen" then
        apply_display(data)
    end
    EventBus.emit("settings:changed", { key = key, value = normalized })
    return true
end

-- percent 항목을 step 단위로 올리거나 내린다 (direction: +1 / -1)
function Settings.step(key, direction)
    local option = definition(key)
    assert(option.kind == "percent", "Settings.step: '" .. tostring(key) .. "' is not a percent option")
    return Settings.set(key, load()[key] + option.step * direction)
end

return Settings
