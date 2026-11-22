-- lib/tween.lua
-- 경량 트위닝 유틸리티 (직접 작성).
-- 상태(State)마다 Tween.Group 하나를 두고 update(dt) 로 진행, exit() 에서 clear() 한다.
--
--   local tweens = Tween.Group()
--   tweens:to(obj, 0.5, { x = 100, alpha = 0 })
--       :ease("out_cubic"):delay(0.1)
--       :on_complete(function(target) ... end)
--   tweens:to(prompt, 0.8, { alpha = 0.2 }):ease("in_out_sine"):yoyo():loop()  -- 무한 왕복
--   tweens:update(dt)

local Class = require("lib.classic")

local BACK_OVERSHOOT = 1.70158
local HALF_PI = math.pi / 2
local ELASTIC_PERIOD = (2 * math.pi) / 3

-- 이징 함수: t ∈ [0, 1] → 진행률
local Easing = {}

function Easing.linear(t) return t end

function Easing.in_quad(t) return t * t end
function Easing.out_quad(t) return t * (2 - t) end
function Easing.in_out_quad(t)
    if t < 0.5 then return 2 * t * t end
    return -1 + (4 - 2 * t) * t
end

function Easing.in_cubic(t) return t * t * t end
function Easing.out_cubic(t)
    local u = t - 1
    return u * u * u + 1
end
function Easing.in_out_cubic(t)
    if t < 0.5 then return 4 * t * t * t end
    local u = 2 * t - 2
    return 0.5 * u * u * u + 1
end

function Easing.in_sine(t) return 1 - math.cos(t * HALF_PI) end
function Easing.out_sine(t) return math.sin(t * HALF_PI) end
function Easing.in_out_sine(t) return -(math.cos(math.pi * t) - 1) / 2 end

function Easing.in_back(t) return t * t * ((BACK_OVERSHOOT + 1) * t - BACK_OVERSHOOT) end
function Easing.out_back(t)
    local u = t - 1
    return u * u * ((BACK_OVERSHOOT + 1) * u + BACK_OVERSHOOT) + 1
end

function Easing.out_elastic(t)
    if t == 0 or t == 1 then return t end
    return 2 ^ (-10 * t) * math.sin((t * 10 - 0.75) * ELASTIC_PERIOD) + 1
end

-- 단일 트윈 작업. Group:to() 로만 생성한다.
local Job = Class:extend()

function Job:new(target, duration, properties)
    assert(type(target) == "table", "Tween: target must be a table")
    assert(type(duration) == "number" and duration >= 0, "Tween: duration must be a number >= 0")
    assert(type(properties) == "table", "Tween: properties must be a table")
    self._target = target
    self._duration = duration
    self._to = properties
    self._from = nil          -- 지연(delay)이 끝나는 시점에 캡처
    self._elapsed = 0
    self._delay_left = 0
    self._easing = Easing.linear
    self._yoyo = false
    self._reversed = false
    self._loops_left = 0      -- 남은 추가 반복 횟수, -1 = 무한
    self._on_update = nil
    self._on_complete = nil
    self._done = false
end

function Job:ease(easing)
    if type(easing) == "string" then
        assert(Easing[easing], "Tween: unknown easing '" .. easing .. "'")
        self._easing = Easing[easing]
    else
        assert(type(easing) == "function", "Tween: easing must be a name or a function")
        self._easing = easing
    end
    return self
end

function Job:delay(seconds)
    self._delay_left = seconds
    return self
end

-- 사이클이 끝날 때마다 방향을 뒤집는다 (loop 와 함께 사용)
function Job:yoyo(enabled)
    self._yoyo = enabled ~= false
    return self
end

-- count: 추가 반복 횟수. 생략하면 무한 반복
function Job:loop(count)
    self._loops_left = count or -1
    return self
end

function Job:on_update(callback)
    self._on_update = callback
    return self
end

function Job:on_complete(callback)
    self._on_complete = callback
    return self
end

-- on_complete 호출 없이 중단
function Job:stop()
    self._done = true
end

function Job:is_done()
    return self._done
end

function Job:_capture()
    local from = {}
    for key in pairs(self._to) do
        local value = self._target[key]
        assert(type(value) == "number", "Tween: target field '" .. tostring(key) .. "' is not a number")
        from[key] = value
    end
    self._from = from
end

function Job:_apply(progress)
    local eased
    if self._reversed then
        eased = self._easing(1 - progress)
    else
        eased = self._easing(progress)
    end
    local target, from = self._target, self._from
    for key, to_value in pairs(self._to) do
        target[key] = from[key] + (to_value - from[key]) * eased
    end
end

function Job:_step(dt)
    if self._done then return end

    if self._delay_left > 0 then
        self._delay_left = self._delay_left - dt
        if self._delay_left > 0 then return end
        dt = -self._delay_left
        self._delay_left = 0
    end
    if self._from == nil then
        self:_capture()
    end

    self._elapsed = self._elapsed + dt
    local progress = 1
    if self._duration > 0 then
        progress = math.min(self._elapsed / self._duration, 1)
    end
    self:_apply(progress)
    if self._on_update then
        self._on_update(self._target, progress)
    end
    if progress < 1 then return end

    if self._loops_left ~= 0 then
        if self._loops_left > 0 then
            self._loops_left = self._loops_left - 1
        end
        self._elapsed = math.max(self._elapsed - self._duration, 0)
        if self._yoyo then
            self._reversed = not self._reversed
        end
        return
    end

    self._done = true
    if self._on_complete then
        self._on_complete(self._target)
    end
end

-- 트윈 묶음. 수명은 소유자(보통 State)가 관리한다.
local Group = Class:extend()

function Group:new()
    self._jobs = {}
end

function Group:to(target, duration, properties)
    local job = Job(target, duration, properties)
    self._jobs[#self._jobs + 1] = job
    return job
end

function Group:update(dt)
    local jobs = self._jobs
    -- 이번 프레임 콜백에서 추가된 작업은 다음 프레임부터 진행
    local count = #jobs
    for i = 1, count do
        jobs[i]:_step(dt)
    end

    local write = 0
    local total = #jobs
    for read = 1, total do
        local job = jobs[read]
        if not job:is_done() then
            write = write + 1
            jobs[write] = job
        end
    end
    for i = total, write + 1, -1 do
        jobs[i] = nil
    end
end

function Group:clear()
    for i = 1, #self._jobs do
        self._jobs[i]:stop()
    end
    self._jobs = {}
end

function Group:count()
    return #self._jobs
end

local Tween = {
    Group = Group,
    Easing = Easing,
}

return Tween
