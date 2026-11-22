-- systems/BossPatterns.lua
-- 월말 대보스의 고유 패턴 (수치는 data/enemies.lua 의 boss_patterns, 보스 스펙의 pattern 이 이름) — 중간 보스 4종의
-- 패턴(systems/MidBossPatterns)도 여기 합쳐 같은 수명주기로 돌린다. 간격은 monster.intensity(달별 기믹 강도)로 나누고
-- 강탈액·소환 수·반사 상한은 강도만큼 커진다.
--   web   (던전 문지기 골렘)   : interval 초마다 무기가 놓인 진열장 칸 하나를 거미줄로 봉인 → 그 칸 무기는 사격 불가.
--                                플레이어가 그 칸을 clicks 번 클릭하면 해제 (Combat:hit_web)
--   greed (탐욕의 고블린 약탈자): 살아 있는 동안 interval 초마다 골드 steal 강탈. 처치하면 강탈액 x refund_mult 반환
--   necro (심연의 사령술사)     : 해골 소환 + shield_time 초 동안 받는 피해의 reflect 비율을 방벽 내구도로 반사하는 붉은 보호막
--                                  (보호막 하나당 반사 상한 reflect_cap)
--   rift  (차원의 균열 군주)    : interval 초마다 물리 면역 ↔ 원소 면역 교대 (DamageRules 가 면역을 적용)
-- '스승의 흔적' 최종 보스(균열의 잔영)의 공방 봉쇄 · 균열 아이기스는 systems/MasterBossPattern 이 정의해 여기 합친다.
-- Combat 이 생성·갱신·피해·처치·도주 시점을 알려 준다. 결과는 "boss:*" 이벤트로 발행한다 (연출은 ui/FeedbackBoss).

local Class = require("lib.classic")
local EventBus = require("core.EventBus")
local Grid = require("systems.Grid")
local MidBossPatterns = require("systems.MidBossPatterns")
local MasterBossPattern = require("systems.MasterBossPattern")
local ENEMIES = require("data.enemies")

local BossPatterns = Class:extend()

local DATA = ENEMIES.boss_patterns
local PATTERNS = {}

local function intensity(monster)
    return monster.intensity or 1
end

-- ── 문지기 골렘: 거미줄 ──────────────────────────────────────
PATTERNS.web = {
    init = function(_, state)
        state.timer = DATA.web.first
    end,
    update = function(self, monster, state, dt)
        state.timer = state.timer - dt
        if state.timer > 0 then
            return
        end
        state.timer = state.timer + DATA.web.interval / intensity(monster)
        local combat, inventory = self._combat, self._workshop.inventory
        local candidates = {}
        for index = 1, Grid.SIZE do
            local item = inventory:get("grid", index)
            if item ~= nil and combat.webs[index] == nil then
                candidates[#candidates + 1] = index
            end
        end
        local index = self._rng:pick(candidates)
        if index ~= nil then
            combat.webs[index] = DATA.web.clicks
            local x, y = Grid.cell_center(index)
            EventBus.emit("boss:web_spun", { index = index, x = x, y = y, clicks = DATA.web.clicks, from_x = monster.x, from_y = monster.y })
        end
    end,
}

-- ── 탐욕의 약탈자: 골드 강탈 ──────────────────────────────────
PATTERNS.greed = {
    init = function(_, state)
        state.timer = DATA.greed.interval
        state.stolen = 0
    end,
    update = function(self, monster, state, dt)
        state.timer = state.timer - dt
        while state.timer <= 0 do
            state.timer = state.timer + DATA.greed.interval
            local workshop = self._workshop
            local amount = math.min(math.floor(DATA.greed.steal * intensity(monster) + 0.5), workshop.gold)
            if amount > 0 and workshop:spend_gold(amount, "stolen") then
                state.stolen = state.stolen + amount
                EventBus.emit("boss:gold_stolen", { amount = amount, total = state.stolen, x = monster.x, y = monster.y })
            end
        end
    end,
    killed = function(self, monster, state)
        if state.stolen > 0 then
            local refund = state.stolen * DATA.greed.refund_mult
            self._workshop:add_gold(refund, "refund")
            EventBus.emit("boss:gold_returned", { amount = refund, stolen = state.stolen, x = monster.x, y = monster.y })
        end
    end,
}

-- ── 심연의 사령술사: 해골 소환 + 반사 보호막 ──────────────────
PATTERNS.necro = {
    init = function(_, state)
        state.summon = DATA.necro.summon_interval
        state.shield = DATA.necro.shield_first
    end,
    update = function(self, monster, state, dt)
        state.summon = state.summon - dt
        if state.summon <= 0 then
            state.summon = state.summon + DATA.necro.summon_interval / intensity(monster)
            local count, raised = DATA.necro.summon_count + math.floor((intensity(monster) - 1) * 2), 0
            for i = 1, count do
                local offset = (i - (count + 1) / 2) * monster.radius * 1.6
                raised = raised + (self._combat:summon(DATA.necro.summon_type, monster.x + monster.radius, monster.y + offset) and 1 or 0)
            end
            if raised > 0 then                    -- 그 밤 몬스터 상한에 막히면 연출도 없다
                EventBus.emit("boss:summoned", { count = raised, x = monster.x, y = monster.y })
            end
        end
        state.shield = state.shield - dt
        if state.shield <= 0 then
            state.shield = state.shield + DATA.necro.shield_interval
            monster.shield_time = DATA.necro.shield_time
            state.reflect_left = DATA.necro.reflect_cap * intensity(monster)     -- 보호막 하나가 반사할 수 있는 내구도 상한
            EventBus.emit("boss:shield_raised", { monster = monster, time = DATA.necro.shield_time, x = monster.x, y = monster.y })
        end
    end,
    damaged = function(self, monster, state, amount)
        if monster.shield_time > 0 and amount > 0 and (state.reflect_left or 0) > 0 then
            local reflected = math.min(amount * DATA.necro.reflect, state.reflect_left)
            state.reflect_left = state.reflect_left - reflected
            self._reflected = self._reflected + reflected
            if self._reflected >= 1 then    -- 내구도는 정수로 깎는다 (남는 소수는 다음 피해에 더한다)
                local whole = math.floor(self._reflected)
                self._reflected = self._reflected - whole
                self._workshop:damage_hp(whole, "reflect")
                EventBus.emit("boss:reflected", { amount = whole, x = monster.x, y = monster.y })
            end
        end
    end,
}

-- ── 차원의 균열 군주: 면역 교대 ────────────────────────────────
PATTERNS.rift = {
    init = function(_, state, monster)
        state.timer = DATA.rift.interval
        monster.immunity = DATA.rift.first
    end,
    update = function(_, monster, state, dt)
        state.timer = state.timer - dt
        if state.timer <= 0 then
            state.timer = state.timer + DATA.rift.interval / intensity(monster)
            monster.immunity = monster.immunity == "physical" and "elemental" or "physical"
            EventBus.emit("boss:immunity_changed", { monster = monster, immunity = monster.immunity, x = monster.x, y = monster.y })
        end
    end,
}

for _, extra in ipairs({ MidBossPatterns.PATTERNS, MasterBossPattern.PATTERNS }) do       -- 중간 보스 4종 · 최종 보스
    for name, pattern in pairs(extra) do
        assert(PATTERNS[name] == nil, "BossPatterns: duplicate pattern '" .. name .. "'")
        PATTERNS[name] = pattern
    end
end

function BossPatterns.names()
    local names = {}
    for name in pairs(PATTERNS) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

function BossPatterns:new(combat, workshop, rng)
    self._combat = combat
    self._workshop = workshop
    self._rng = rng
    self._reflected = 0
end

local function pattern_of(monster)
    local name = monster.spec.pattern
    if name == nil then
        return nil
    end
    local pattern = PATTERNS[name]
    assert(pattern ~= nil, "BossPatterns: unknown pattern '" .. tostring(name) .. "'")
    return pattern
end

function BossPatterns:spawned(monster)
    local pattern = pattern_of(monster)
    if pattern ~= nil then
        monster.pattern = {}
        pattern.init(self, monster.pattern, monster)
        if monster.immunity ~= nil then
            EventBus.emit("boss:immunity_changed", { monster = monster, immunity = monster.immunity, x = monster.x, y = monster.y })
        end
    end
end

function BossPatterns:update(dt)
    for _, monster in ipairs(self._combat.monsters) do
        local pattern = not monster.dead and pattern_of(monster)
        if pattern and pattern.update ~= nil then
            pattern.update(self, monster, monster.pattern, dt)
        end
    end
end

function BossPatterns:damaged(monster, amount)
    local pattern = pattern_of(monster)
    if pattern ~= nil and pattern.damaged ~= nil then
        pattern.damaged(self, monster, monster.pattern, amount)
    end
end

function BossPatterns:killed(monster)
    local pattern = pattern_of(monster)
    if pattern ~= nil and pattern.killed ~= nil then
        pattern.killed(self, monster, monster.pattern)
    end
end

return BossPatterns
