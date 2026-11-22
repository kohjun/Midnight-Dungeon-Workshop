-- systems/Progress.lua
-- 영구 진행도: 클리어한 난이도(해금 판정 — 베테랑 클리어 → 악몽, 악몽 클리어 → 5단계 스승의 흔적), 튜토리얼 완료 여부,
-- 계약서에 서명한 이름, 진엔딩 훈장(data/endings.lua 의 medal 엔딩을 본 기록). 세이브 디렉토리의 progress.txt 에 저장한다.
-- 장막에 가려진 계약(veiled, 5단계)은 해금 전까지 '???' 봉인 카드로 보인다 (ui/ContractCards).
-- 스모크 테스트는 use_memory_only() 로 실제 세이브를 건드리지 않는다.

local Text = require("lib.text")
local DIFFICULTIES = require("data.difficulties")
local ENDINGS = require("data.endings")
local STORY = require("data.story")

local Progress = {}

local FILE = "progress.txt"

local _data = nil
local _persist = true

local function defaults()
    return { cleared = {}, tutorial_done = false, player_name = nil, medals = {} }
end

local function load()
    if _data ~= nil then
        return _data
    end
    _data = defaults()
    if _persist and love.filesystem.getInfo(FILE) ~= nil then
        for line in love.filesystem.lines(FILE) do
            local key, value = line:match("^([%w_]+)=(.*)$")
            if key == "tutorial_done" then
                _data.tutorial_done = value == "1"
            elseif key == "player_name" and value ~= "" then
                _data.player_name = Text.sanitize_name(value, STORY.contract.name_max_chars)
            elseif key == "cleared" or key == "medals" then
                for id in value:gmatch("[%w_]+") do
                    _data[key][id] = true
                end
            end
        end
    end
    return _data
end

local function save()
    if not _persist then
        return
    end
    local cleared, medals = {}, {}
    for _, id in ipairs(DIFFICULTIES.order) do
        if _data.cleared[id] then
            cleared[#cleared + 1] = id
        end
    end
    for _, id in ipairs(ENDINGS.order) do
        if _data.medals[id] then
            medals[#medals + 1] = id
        end
    end
    local text = string.format("tutorial_done=%s\ncleared=%s\nplayer_name=%s\nmedals=%s\n",
        _data.tutorial_done and "1" or "0", table.concat(cleared, ","), _data.player_name or "", table.concat(medals, ","))
    local ok, err = love.filesystem.write(FILE, text)
    if not ok then
        print("[Progress] failed to save: " .. tostring(err))
    end
end

-- 테스트용: 디스크를 읽지도 쓰지도 않는다
function Progress.use_memory_only()
    _persist = false
    _data = defaults()
end

function Progress.is_cleared(id)
    return load().cleared[id] == true
end

-- 해금 조건 난이도 id 목록 (unlock_after 는 id 하나 또는 목록 — 목록이면 하나만 클리어해도 해금)
function Progress.unlock_requirements(id)
    local mode = DIFFICULTIES.modes[id]
    assert(mode ~= nil, "Progress: unknown difficulty '" .. tostring(id) .. "'")
    local requirement = mode.unlock_after
    if requirement == nil then
        return {}
    end
    return type(requirement) == "table" and requirement or { requirement }
end

function Progress.is_unlocked(id)
    local requirements = Progress.unlock_requirements(id)
    if #requirements == 0 then
        return true
    end
    for _, required in ipairs(requirements) do
        if Progress.is_cleared(required) then
            return true
        end
    end
    return false
end

-- 장막에 가려진 계약이 아직 잠겨 있다 (그을린 '???' 봉인 카드로 보인다 — 5단계 스승의 흔적, 악몽 클리어 전)
function Progress.is_veiled(id)
    local mode = DIFFICULTIES.modes[id]
    return mode ~= nil and mode.veiled == true and not Progress.is_unlocked(id)
end

-- 클리어 기록. 이번에 새로 해금된 난이도 id 목록을 반환한다
function Progress.mark_cleared(id)
    local locked_before = {}
    for _, other in ipairs(DIFFICULTIES.order) do
        locked_before[other] = not Progress.is_unlocked(other)
    end
    load().cleared[id] = true
    save()
    local unlocked = {}
    for _, other in ipairs(DIFFICULTIES.order) do
        if locked_before[other] and Progress.is_unlocked(other) then
            unlocked[#unlocked + 1] = other
        end
    end
    return unlocked
end

-- 저장된 이름 (서명한 적 없으면 nil)
function Progress.player_name()
    return load().player_name
end

-- 이름 저장. 정리 후 빈 문자열이면 저장하지 않고 nil 반환
function Progress.set_player_name(name)
    local cleaned = Text.sanitize_name(name or "", STORY.contract.name_max_chars)
    if cleaned == "" then
        return nil
    end
    load().player_name = cleaned
    save()
    return cleaned
end

-- 진엔딩 훈장 (data/endings.lua 의 medal 엔딩 id)
function Progress.has_medal(id)
    return load().medals[id] == true
end

-- 본 엔딩 기록: 훈장이 걸린 엔딩이면 영구 기록한다. 이번에 처음 받은 훈장이면 true
function Progress.record_ending(id)
    local spec = id and ENDINGS.list[id]
    if spec == nil or not spec.medal or load().medals[id] then
        return false
    end
    _data.medals[id] = true
    save()
    return true
end

function Progress.tutorial_done()
    return load().tutorial_done
end

function Progress.mark_tutorial_done()
    if not load().tutorial_done then
        _data.tutorial_done = true
        save()
    end
end

return Progress
