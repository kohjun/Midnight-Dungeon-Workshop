-- systems/NightClock.lua
-- 밤의 끝 판정 (Combat 믹스인 — CombatArea 처럼 install 로 메서드를 붙인다).
--   새벽 시각(night.duration)이 지나도 웨이브가 다 끝나야 밤이 끝난다: 더 나올 몬스터(스폰 창·보스)가 없고 살아 있는 몬스터도 없을 때.
--   새벽이 지났는데 몬스터가 남아 있으면 소탕 시간 — "combat:overtime" 을 한 번 발행하고 HUD 는 남은 몬스터 수를 보여 준다.
--   소탕 시간이 night.overtime_max 를 넘으면 안전장치로 끝내고, 남은 몬스터는 달아난다 (Combat:end_night → combat:monsters_fled).
--   화면이 있을 때(RunState)는 새벽 게이트를 켠다: 셔터(dawn_candle)가 화면을 다 덮은 순간 release_dawn() 해야 밤이 끝난다.
--   헤드리스(밸런스 시뮬·스모크 단위 검사)는 게이트 없이 조건이 맞는 즉시 끝난다.

local EventBus = require("core.EventBus")
local COMBAT = require("data.combat")

local NightClock = {}

local NIGHT = COMBAT.night

local function overtime_expired(combat)
    return combat.elapsed >= combat.duration + NIGHT.overtime_max
end

function NightClock.install(Combat)
    -- 밤 시작마다 (Combat:start)
    function Combat:_reset_clock()
        self.elapsed = 0
        self._dawn_released = false
        self._overtime_announced = false
    end

    -- 새벽 시각까지 남은 시간 (0 이면 새벽이 지났다)
    function Combat:time_left()
        return math.max(0, self.duration - self.elapsed)
    end

    function Combat:alive_count()
        local count = 0
        for _, monster in ipairs(self.monsters) do
            if not monster.dead then
                count = count + 1
            end
        end
        return count
    end

    -- 웨이브가 다 끝났다: 스폰 창이 지났고 보스도 나왔으며, 살아 있는 몬스터가 없다
    function Combat:wave_cleared()
        return self._spawner ~= nil and self._spawner:is_done() and self:alive_count() == 0
    end

    -- 새벽이 지났는데 아직 몬스터가 남아 있다 (소탕 시간)
    function Combat:in_overtime()
        return self.active and self.elapsed >= self.duration and not self:wave_cleared()
    end

    -- 밤이 끝나기까지 남은 게임 시간. 몬스터가 남아 있어 아직 알 수 없으면 nil (RunState 가 셔터를 내릴 때를 고른다)
    function Combat:time_to_dawn()
        if overtime_expired(self) then
            return 0
        end
        if not self:wave_cleared() then
            return nil
        end
        return self:time_left()
    end

    -- 화면이 있을 때만 켠다: 밤은 셔터가 화면을 다 덮은 뒤(release_dawn) 끝난다
    function Combat:set_dawn_gate(enabled)
        self._dawn_gate = enabled
    end

    function Combat:release_dawn()
        self._dawn_released = true
    end

    -- 새벽 정산창을 확인했다: 웨이브가 끝났으니 남은 고요한 시간을 건너뛰고 바로 새벽으로
    function Combat:skip_to_dawn()
        self.elapsed = math.max(self.elapsed, self.duration)
    end

    function Combat:is_finished()
        if self.elapsed < self.duration or not (self:wave_cleared() or overtime_expired(self)) then
            return false
        end
        return not self._dawn_gate or self._dawn_released
    end

    -- 매 프레임 끝 (Combat:update): 새벽이 지났는데 몬스터가 남았으면 소탕 시간 시작을 한 번 알린다
    function Combat:_check_overtime()
        if self._overtime_announced or self.elapsed < self.duration then
            return
        end
        local remaining = self:alive_count()
        if remaining > 0 then
            self._overtime_announced = true
            EventBus.emit("combat:overtime", { remaining = remaining })
        end
    end
end

return NightClock
