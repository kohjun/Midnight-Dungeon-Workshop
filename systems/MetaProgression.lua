-- systems/MetaProgression.lua
-- 장인 명성(RP) 영구 재화와 6종 영구 능력치, 업적(특수 유물 해금)·엔딩 수집 기록. 세이브 디렉토리의 save_meta.lua 에
-- 자동 저장/로드한다. 형식은 "return { rp = N, levels = { ... }, achievements = { id, ... }, endings = { id, ... } }" 이며
-- 빈 환경(setfenv)에서 실행해 읽는다.
-- 스모크 테스트는 use_memory_only() 로 실제 세이브를 건드리지 않는다.

local EventBus = require("core.EventBus")
local META = require("data.meta")
local DIFFICULTIES = require("data.difficulties")
local ACHIEVEMENTS = require("data.achievements")
local ENDINGS = require("data.endings")

local MetaProgression = {}

local _data = nil
local _persist = true

local function defaults()
    return { rp = 0, levels = {}, achievements = {}, endings = {} }
end

-- 저장된 id 목록 → 집합 (알려진 id 만)
local function read_set(list, known)
    local set = {}
    for _, id in ipairs(type(list) == "table" and list or {}) do
        if known[id] ~= nil then
            set[id] = true
        end
    end
    return set
end

-- 저장 데이터 정규화: 모든 스탯 레벨을 0~max 로 채운다 (raw 가 nil 이어도 — 첫 실행)
local function sanitize(raw)
    local data = defaults()
    raw = type(raw) == "table" and raw or {}
    local levels = type(raw.levels) == "table" and raw.levels or {}
    data.rp = math.max(0, math.floor(tonumber(raw.rp) or 0))
    for _, id in ipairs(META.order) do
        local level = tonumber(levels[id]) or 0
        data.levels[id] = math.max(0, math.min(META.stats[id].max, math.floor(level)))
    end
    data.achievements = read_set(raw.achievements, ACHIEVEMENTS.list)
    data.endings = read_set(raw.endings, ENDINGS.list)
    return data
end

-- 저장 파일 읽기: 빈 환경(setfenv)에서 실행해 테이블만 받는다. 없거나 깨졌으면 기본값
function MetaProgression.read_file(path)
    if love.filesystem.getInfo(path) == nil then
        return sanitize(nil)
    end
    local ok, chunk = pcall(love.filesystem.load, path)
    if not ok or chunk == nil then
        print("[MetaProgression] failed to parse save: " .. tostring(chunk))
        return sanitize(nil)
    end
    setfenv(chunk, {})
    local success, raw = pcall(chunk)
    if not success then
        print("[MetaProgression] failed to read save: " .. tostring(raw))
        return sanitize(nil)
    end
    return sanitize(raw)
end

local function serialize_set(lines, name, set, order)
    local ids = {}
    for _, id in ipairs(order) do
        if set[id] then
            ids[#ids + 1] = string.format("%q", id)
        end
    end
    lines[#lines + 1] = string.format("    %s = { %s },", name, table.concat(ids, ", "))
end

-- 저장 형식: "return { rp = N, levels = { id = n, ... }, achievements = { ... }, endings = { ... } }"
function MetaProgression.serialize(data)
    local lines = { "return {", string.format("    rp = %d,", data.rp), "    levels = {" }
    for _, id in ipairs(META.order) do
        lines[#lines + 1] = string.format("        %s = %d,", id, data.levels[id] or 0)
    end
    lines[#lines + 1] = "    },"
    serialize_set(lines, "achievements", data.achievements or {}, ACHIEVEMENTS.order)
    serialize_set(lines, "endings", data.endings or {}, ENDINGS.order)
    lines[#lines + 1] = "}"
    return table.concat(lines, "\n") .. "\n"
end

local function load()
    if _data ~= nil then
        return _data
    end
    _data = _persist and MetaProgression.read_file(META.save_file) or sanitize(nil)
    return _data
end

local function save()
    if not _persist then
        return
    end
    local ok, err = love.filesystem.write(META.save_file, MetaProgression.serialize(_data))
    if not ok then
        print("[MetaProgression] failed to save: " .. tostring(err))
    end
end

function MetaProgression.use_memory_only()
    _persist = false
    _data = sanitize(nil)
end

function MetaProgression.rp()
    return load().rp
end

function MetaProgression.level(id)
    assert(META.stats[id] ~= nil, "MetaProgression: unknown stat '" .. tostring(id) .. "'")
    return load().levels[id] or 0
end

-- 다음 레벨 비용 (최대면 nil)
function MetaProgression.next_cost(id)
    local level = MetaProgression.level(id)
    return META.stats[id].costs[level + 1]
end

function MetaProgression.can_upgrade(id)
    local cost = MetaProgression.next_cost(id)
    return cost ~= nil and load().rp >= cost
end

function MetaProgression.upgrade(id)
    if not MetaProgression.can_upgrade(id) then
        return false
    end
    local data = load()
    local cost = MetaProgression.next_cost(id)
    data.rp = data.rp - cost
    data.levels[id] = data.levels[id] + 1
    save()
    EventBus.emit("meta:upgraded", { id = id, level = data.levels[id], cost = cost, rp = data.rp })
    return true
end

function MetaProgression.has_achievement(id)
    return load().achievements[id] == true
end

-- 업적 달성 기록 (처음이면 저장 + "meta:achievement_unlocked", true 반환)
function MetaProgression.unlock_achievement(id)
    local spec = ACHIEVEMENTS.list[id]
    assert(spec ~= nil, "MetaProgression: unknown achievement '" .. tostring(id) .. "'")
    local data = load()
    if data.achievements[id] then
        return false
    end
    data.achievements[id] = true
    save()
    EventBus.emit("meta:achievement_unlocked", { id = id, relic = spec.relic })
    return true
end

-- 해금된 특수 유물 id 집합
function MetaProgression.unlocked_relics()
    local relics = {}
    for id in pairs(load().achievements) do
        relics[ACHIEVEMENTS.list[id].relic] = true
    end
    return relics
end

function MetaProgression.has_ending(id)
    return load().endings[id] == true
end

-- 엔딩 수집 기록 (처음 본 엔딩이면 true)
function MetaProgression.record_ending(id)
    assert(ENDINGS.list[id] ~= nil, "MetaProgression: unknown ending '" .. tostring(id) .. "'")
    local data = load()
    if data.endings[id] then
        return false
    end
    data.endings[id] = true
    save()
    return true
end

-- 레벨 합산 보너스 → Workshop options.meta (relics = 해금된 특수 유물 집합)
function MetaProgression.bonuses()
    local bonuses = { grid_stage = 1, relics = MetaProgression.unlocked_relics() }
    for _, id in ipairs(META.order) do
        local stat = META.stats[id]
        local level = MetaProgression.level(id)
        for key, amount in pairs(stat.per_level) do
            bonuses[key] = (bonuses[key] or 0) + amount * level
        end
        if stat.grid_stage_at_max ~= nil and level >= stat.max then
            bonuses.grid_stage = math.max(bonuses.grid_stage, stat.grid_stage_at_max)
        end
    end
    return bonuses
end

-- result: { reason, difficulty, days_survived, tributes_paid, kills }
function MetaProgression.compute(result)
    local formula = META.rp
    local mode = DIFFICULTIES.modes[result.difficulty or DIFFICULTIES.default]
    local breakdown = {
        days = (result.days_survived or 0) * formula.per_day,
        tributes = (result.tributes_paid or 0) * formula.per_tribute,
        kills = math.floor((result.kills or 0) / formula.kills_divisor),
        clear = result.reason == "victory" and formula.clear_bonus or 0,
        mult = mode.rp_mult or 1,
    }
    breakdown.total = math.floor((breakdown.days + breakdown.tributes + breakdown.kills + breakdown.clear) * breakdown.mult)
    return breakdown
end

-- 런 종료 정산: RP 적립 후 저장, 내역 반환
function MetaProgression.award(result)
    local breakdown = MetaProgression.compute(result)
    local data = load()
    data.rp = data.rp + breakdown.total
    save()
    EventBus.emit("meta:awarded", { amount = breakdown.total, rp = data.rp })
    return breakdown
end

return MetaProgression
