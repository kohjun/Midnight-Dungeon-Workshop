-- systems/MidBossPatterns.lua
-- 월 중순 중간 보스 4종의 고유 패턴 (수치 data/enemies.lua 의 boss_patterns, 스펙의 pattern 이 이름).
-- systems/BossPatterns 가 PATTERNS 에 합쳐 같은 수명주기(init · update · damaged · killed)로 돌린다 — self = BossPatterns.
--   vanguard (철갑 선봉장) : interval 초마다 charge_time 초 돌파(이동 x charge_mult), 뒤따르는 ally_radius 안 아군도 x ally_mult
--   dash     (약탈 대장)   : 체력이 threshold 이하가 되면 interval 초마다 dash_time 초 돌진(이동 x dash_mult)
--   hex      (역병 주술사) : interval 초마다 radius 안 몬스터 이동 x speed_mult(speed_time 초) + 최대 체력의 heal 만큼 회복
--   stalker  (균열 추적자) : interval 초마다 소형 졸개 count 마리를 ahead px 앞쪽에 소환
-- 간격은 monster.intensity(달별 기믹 강도)로 나누고, 회복량·졸개 수·돌진 배율은 강도만큼 커진다. 결과는 "boss:*" 이벤트.

local EventBus = require("core.EventBus")
local ENEMIES = require("data.enemies")

local MidBossPatterns = {}

local DATA = ENEMIES.boss_patterns
local PATTERNS = {}

local function intensity(monster)
    return monster.intensity or 1
end

-- ── 철갑 선봉장: 아군을 이끌고 돌파 ──────────────────────────
PATTERNS.vanguard = {
    init = function(_, state)
        state.timer = DATA.vanguard.first
    end,
    update = function(self, monster, state, dt)
        local spec = DATA.vanguard
        state.timer = state.timer - dt
        if state.timer > 0 then
            return
        end
        state.timer = state.timer + spec.interval / intensity(monster)
        monster:boost(spec.charge_mult, spec.charge_time)
        local led = 0
        for _, ally in ipairs(self._combat.monsters) do
            local dx, dy = ally.x - monster.x, ally.y - monster.y
            if ally ~= monster and not ally.dead and dx >= 0 and dx * dx + dy * dy <= spec.ally_radius ^ 2 then
                ally:boost(spec.ally_mult, spec.charge_time)
                led = led + 1
            end
        end
        EventBus.emit("boss:vanguard_charge", { monster = monster, allies = led, x = monster.x, y = monster.y })
    end,
}

-- ── 약탈 대장: 궁지에 몰리면 돌진 ────────────────────────────
PATTERNS.dash = {
    init = function(_, state)
        state.timer = 0
    end,
    update = function(_, monster, state, dt)
        local spec = DATA.dash
        if monster.hp > monster.max_hp * spec.threshold then
            return
        end
        state.timer = state.timer - dt
        if state.timer <= 0 then
            state.timer = spec.interval / intensity(monster)
            monster:boost(spec.dash_mult * (1 + 0.3 * (intensity(monster) - 1)), spec.dash_time)
            EventBus.emit("boss:raider_dash", { monster = monster, x = monster.x, y = monster.y })
        end
    end,
}

-- ── 역병 주술사: 강화 오라 ──────────────────────────────────
PATTERNS.hex = {
    init = function(_, state)
        state.timer = DATA.hex.first
    end,
    update = function(self, monster, state, dt)
        local spec = DATA.hex
        state.timer = state.timer - dt
        if state.timer > 0 then
            return
        end
        state.timer = state.timer + spec.interval / intensity(monster)
        local count = 0
        for _, ally in ipairs(self._combat.monsters) do
            local dx, dy = ally.x - monster.x, ally.y - monster.y
            if not ally.dead and dx * dx + dy * dy <= spec.radius ^ 2 then
                ally:boost(spec.speed_mult, spec.speed_time)
                ally.hp = math.min(ally.max_hp, ally.hp + ally.max_hp * spec.heal * intensity(monster))
                count = count + 1
            end
        end
        EventBus.emit("boss:hex_pulse", { monster = monster, count = count, radius = spec.radius, x = monster.x, y = monster.y })
    end,
}

-- ── 균열 추적자: 졸개 소환 ──────────────────────────────────
PATTERNS.stalker = {
    init = function(_, state)
        state.timer = DATA.stalker.first
    end,
    update = function(self, monster, state, dt)
        local spec = DATA.stalker
        state.timer = state.timer - dt
        if state.timer > 0 then
            return
        end
        state.timer = state.timer + spec.interval / intensity(monster)
        local count, called = spec.count + math.floor((intensity(monster) - 1) / spec.per_count), 0
        for i = 1, count do
            local offset = (i - (count + 1) / 2) * monster.radius * 1.8
            called = called + (self._combat:summon(spec.summon_type, monster.x - spec.ahead, monster.y + offset) and 1 or 0)
        end
        if called > 0 then                        -- 그 밤 몬스터 상한에 막히면 연출도 없다
            EventBus.emit("boss:summoned", { count = called, x = monster.x - spec.ahead, y = monster.y, rift = true })
        end
    end,
}

MidBossPatterns.PATTERNS = PATTERNS

return MidBossPatterns
