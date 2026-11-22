-- core/FixedStep.lua
-- 배속 시뮬레이션용 고정 서브스텝: 한 프레임의 시뮬레이션 시간(dt × speed)을 max_step 이하의 같은 크기 조각으로 나눠
-- fn(step) 을 여러 번 부른다. 2배속·3배속에서도 한 번에 진행하는 시간이 1/60초를 넘지 않아 투사체가 몬스터를 뚫고 지나가거나
-- 보스 패턴 타이머가 한 프레임에 두 번 건너뛰는 일이 없다. 1배속 dt = 1/60 을 3번 돌린 것과 3배속 1번이 같은 결과를 낸다.
--   FixedStep.run(dt, speed, fn, max_step?, max_frame?) → 부른 횟수
--   max_frame: 프레임이 멈췄다 돌아왔을 때 한꺼번에 따라잡는 실제 시간 상한 (기본 0.1초)

local FixedStep = {}

local DEFAULT_STEP = 1 / 60
local DEFAULT_MAX_FRAME = 0.1
local EPSILON = 1e-9

function FixedStep.run(dt, speed, fn, max_step, max_frame)
    local total = math.min(dt, max_frame or DEFAULT_MAX_FRAME) * (speed or 1)
    if total <= 0 then
        return 0
    end
    local count = math.max(1, math.ceil(total / (max_step or DEFAULT_STEP) - EPSILON))
    local step = total / count
    for _ = 1, count do
        fn(step)
    end
    return count
end

return FixedStep
