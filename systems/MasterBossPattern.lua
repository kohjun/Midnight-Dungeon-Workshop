-- systems/MasterBossPattern.lua
-- '스승의 흔적' 마지막 밤의 최종 보스 — 균열에 삼켜진 스승의 잔영(data/enemies.lua 의 boss_master, pattern "master") 기믹.
-- systems/BossPatterns 가 다른 패턴과 같은 수명주기(init · update · damaged)로 돌린다. 수치는 data/enemies.lua 의 boss_patterns.master.
--   공방 봉쇄     : lock_first 초 뒤부터 lock_interval / 기믹 강도 초마다, 무기가 놓인 진열장 행 또는 열 하나("combat" 난수)를
--                   lock_time 초 동안 룬 사슬로 묶는다 (Combat:lock_cells — 그 줄 무기는 사격 정지) → boss:lockdown
--   균열 아이기스 : 체력이 thresholds 비율 아래로 처음 내려갈 때마다 보랏빛 보호막 — 받는 피해 x (1 - reduction)
--                   (monster.damage_taken_mult, systems/DamageRules) → boss:aegis_raised. 문턱은 단계 관문이다: 다음 아이기스가
--                   서기 전에는 체력이 그 문턱 아래로 내려가지 않는다(monster.hp_floor) — 강한 진열장도 두 단계를 모두 치른다.
--                   과부하 레버를 켠 동안 준 피해(감쇄 전)가 최대 체력 x break_ratio 에 닿으면 깨진다 → boss:aegis_broken,
--                   groggy_time 초 그로기(제자리에 멈춤 · 받는 피해 x groggy_mult) → boss:groggy_ended
-- 등장하는 순간 boss:master_arrived (전용 경고 배너 · 조종 소리 — ui/FeedbackBoss · data/audio.lua).

local EventBus = require("core.EventBus")
local Grid = require("systems.Grid")
local ENEMIES = require("data.enemies")

local MasterBossPattern = {}

local DATA = ENEMIES.boss_patterns.master
local AXES = { "row", "col" }

local function intensity(monster)
    return monster.intensity or 1
end

-- 무기가 하나라도 놓인 행·열 후보 { axis, line, cells } (행 1~5 → 열 1~5 순서)
local function lock_candidates(inventory)
    local lines = {}
    for _, axis in ipairs(AXES) do
        for line = 1, Grid.ROWS do
            local cells, armed = {}, false
            for k = 1, Grid.COLS do
                local index = axis == "row" and Grid.to_index(line, k) or Grid.to_index(k, line)
                local item = inventory:get("grid", index)
                cells[#cells + 1] = index
                armed = armed or (item ~= nil and item:is_weapon())
            end
            if armed then
                lines[#lines + 1] = { axis = axis, line = line, cells = cells }
            end
        end
    end
    return lines
end

local function lockdown(self, monster)
    local pick = self._rng:pick(lock_candidates(self._workshop.inventory))
    if pick == nil then
        return
    end
    self._combat:lock_cells(pick.cells, DATA.lock_time)
    local x, y = Grid.cell_center(pick.cells[3])
    EventBus.emit("boss:lockdown", { axis = pick.axis, line = pick.line, cells = pick.cells, time = DATA.lock_time, x = x, y = y,
        from_x = monster.x, from_y = monster.y })
end

-- 다음 아이기스 문턱을 체력 하한으로 (더 없으면 하한 없음)
local function gate(monster, state)
    local threshold = DATA.thresholds[state.next]
    monster.hp_floor = threshold and monster.max_hp * threshold or nil
end

local function raise_aegis(monster, state)
    local threshold = DATA.thresholds[state.next]
    state.next = state.next + 1
    gate(monster, state)
    monster.aegis = { need = monster.max_hp * DATA.break_ratio, dealt = 0, threshold = threshold }
    monster.damage_taken_mult = 1 - DATA.reduction
    EventBus.emit("boss:aegis_raised", { monster = monster, threshold = threshold, x = monster.x, y = monster.y })
end

local function break_aegis(monster)
    monster.aegis = nil
    monster.groggy_time = DATA.groggy_time
    monster.damage_taken_mult = DATA.groggy_mult
    monster.boost_mult, monster.boost_time = 0, DATA.groggy_time        -- 그로기: 제자리에 멈춘다
    EventBus.emit("boss:aegis_broken", { monster = monster, groggy = DATA.groggy_time, x = monster.x, y = monster.y })
end

MasterBossPattern.PATTERNS = {
    master = {
        init = function(_, state, monster)
            state.lock = DATA.lock_first
            state.next = 1
            gate(monster, state)
            EventBus.emit("boss:master_arrived", { monster = monster, x = monster.x, y = monster.y })
        end,
        update = function(self, monster, state, dt)
            state.lock = state.lock - dt
            if state.lock <= 0 then
                state.lock = state.lock + DATA.lock_interval / intensity(monster)
                lockdown(self, monster)
            end
            if monster.groggy_time > 0 then
                monster.groggy_time = monster.groggy_time - dt
                if monster.groggy_time <= 0 then
                    monster.groggy_time, monster.damage_taken_mult = 0, 1
                    EventBus.emit("boss:groggy_ended", { monster = monster, x = monster.x, y = monster.y })
                end
            end
            local threshold = DATA.thresholds[state.next]
            if monster.aegis == nil and monster.groggy_time <= 0 and threshold ~= nil and monster.hp <= monster.max_hp * threshold then
                raise_aegis(monster, state)
            end
        end,
        damaged = function(self, monster, _, amount)
            local aegis = monster.aegis
            if aegis ~= nil and self._combat.overclock and amount > 0 then       -- 과부하로만 깰 수 있다
                aegis.dealt = aegis.dealt + amount / monster.damage_taken_mult
                if aegis.dealt >= aegis.need then
                    break_aegis(monster)
                end
            end
        end,
    },
}

-- 테스트·밸런스 AI 용: 지금 아이기스가 서 있는 최종 보스 (없으면 nil)
function MasterBossPattern.shielded(monsters)
    for _, monster in ipairs(monsters) do
        if not monster.dead and monster.aegis ~= nil then
            return monster
        end
    end
    return nil
end

return MasterBossPattern
