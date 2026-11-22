-- core/RNG.lua
-- 싱글톤 시드 기반 결정론적 난수 생성기. 게임 내 모든 난수는 이 모듈을 거친다.
--
--   RNG.set_seed(12345)                  -- 런 시작 시 한 번
--   local loot_rng = RNG.stream("loot")  -- 도메인별 독립 스트림
--   loot_rng:int(1, 6)                   -- [1, 6] 정수
--   RNG.chance(0.25)                     -- "default" 스트림 단축 호출
--
-- 스트림 시드 = 마스터 시드 ⊕ 스트림 이름 해시.
-- 따라서 한 도메인의 난수 소비량이 바뀌어도 다른 도메인의 결과는 바뀌지 않는다.

local bit = require("bit")
local Class = require("lib.classic")

local RNG = {}

local UINT32 = 4294967296
local MAX_SEED = 9007199254740991          -- 2^53 - 1
local MAX_GENERATED_SEED = 2147483646
local DEFAULT_STREAM = "default"
local STREAM_METHODS = { "random", "int", "float", "chance", "pick", "shuffle", "weighted_pick" }

-- 독립 난수 스트림 (LÖVE RandomGenerator 래퍼: 플랫폼 간 결정론 보장)
local Stream = Class:extend()

function Stream:new(name, seed_low, seed_high)
    self.name = name
    self._generator = love.math.newRandomGenerator(seed_low, seed_high)
end

-- [0, 1) 실수
function Stream:random()
    return self._generator:random()
end

-- [min, max] 정수 (양 끝 포함)
function Stream:int(min, max)
    assert(min % 1 == 0 and max % 1 == 0 and min <= max, "RNG:int expects integers with min <= max")
    return self._generator:random(min, max)
end

-- [min, max) 실수
function Stream:float(min, max)
    return min + (max - min) * self._generator:random()
end

function Stream:chance(probability)
    return self._generator:random() < probability
end

-- 리스트에서 균등 확률로 하나 (빈 리스트면 nil)
function Stream:pick(list)
    local count = #list
    if count == 0 then
        return nil
    end
    return list[self._generator:random(1, count)]
end

-- Fisher–Yates 제자리 셔플
function Stream:shuffle(list)
    for i = #list, 2, -1 do
        local j = self._generator:random(1, i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

-- entries: { { weight = 3, ... }, ... } — 가중치 비례로 항목 하나 반환 (전부 0 이면 nil)
function Stream:weighted_pick(entries, weight_key)
    weight_key = weight_key or "weight"
    local total = 0
    for i = 1, #entries do
        total = total + (entries[i][weight_key] or 0)
    end
    if total <= 0 then
        return nil
    end

    local roll = self._generator:random() * total
    local last_valid = nil
    for i = 1, #entries do
        local weight = entries[i][weight_key] or 0
        if weight > 0 then
            last_valid = entries[i]
            roll = roll - weight
            if roll < 0 then
                return entries[i]
            end
        end
    end
    return last_valid -- 부동소수 오차 대비
end

function Stream:get_state()
    return self._generator:getState()
end

function Stream:set_state(state)
    self._generator:setState(state)
end

local _seed = 0
local _streams = {}

-- djb2 문자열 해시 (32-bit, 모든 연산이 2^53 이내라 정확함)
local function hash_name(name)
    local hash = 5381
    for i = 1, #name do
        hash = (hash * 33 + name:byte(i)) % UINT32
    end
    return hash
end

local function validate_seed(seed)
    assert(type(seed) == "number" and seed % 1 == 0 and seed >= 0 and seed <= MAX_SEED,
        "RNG: seed must be an integer in [0, 2^53)")
end

-- 마스터 시드 설정. 기존 스트림은 모두 폐기되고 필요 시 새 시드로 재생성된다.
function RNG.set_seed(seed)
    validate_seed(seed)
    _seed = seed
    _streams = {}
end

function RNG.get_seed()
    return _seed
end

-- 새 런용 시드 생성 (시각 기반 엔트로피, [1, 2^31 - 1])
function RNG.generate_seed()
    local micros = math.floor((love.timer.getTime() % 1) * 1000000)
    return (os.time() + micros) % MAX_GENERATED_SEED + 1
end

-- 이름별 독립 스트림 (생략 시 "default")
function RNG.stream(name)
    name = name or DEFAULT_STREAM
    local stream = _streams[name]
    if stream == nil then
        local seed_low = bit.bxor(_seed % UINT32, hash_name(name)) % UINT32
        local seed_high = math.floor(_seed / UINT32) % UINT32
        stream = Stream(name, seed_low, seed_high)
        _streams[name] = stream
    end
    return stream
end

-- 세이브용 스냅샷: { seed = number, streams = { [name] = state_string } }
function RNG.get_state()
    local streams = {}
    for name, stream in pairs(_streams) do
        streams[name] = stream:get_state()
    end
    return { seed = _seed, streams = streams }
end

function RNG.set_state(state)
    RNG.set_seed(state.seed)
    for name, stream_state in pairs(state.streams or {}) do
        RNG.stream(name):set_state(stream_state)
    end
end

-- RNG.random(), RNG.int(...) 등: "default" 스트림 단축 호출
for _, method in ipairs(STREAM_METHODS) do
    RNG[method] = function(...)
        local stream = RNG.stream(DEFAULT_STREAM)
        return stream[method](stream, ...)
    end
end

return RNG
