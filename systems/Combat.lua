-- systems/Combat.lua
-- 야간 전투: 몬스터 진격, 그리드 무기 자동 사격(유도탄/레이저), 피해·처치·방벽 충돌, 과부하(내구도 마모 가속은 systems/Wear).
-- 유물별 효과는 "combat:hit" / "combat:monster_killed" / "combat:wall_hit" 구독자(ItemEffects)가 처리한다.
-- 피해 보정(면역·감전·연사 경감)은 systems/DamageRules, 보스 고유 패턴은 systems/BossPatterns.
-- 밤의 끝(새벽 시각 + 웨이브 소탕 · 소탕 시간 · 새벽 게이트)은 systems/NightClock 믹스인,
-- 진열장 칸 봉인(골렘 거미줄 · 최종 보스 룬 사슬 — is_locked · lock_cells · hit_web)은 systems/CombatLocks 믹스인.
-- 효과용 공개 API: damage_monster, damage_area(폭발) · strike_all(낙뢰) · chain_from(연쇄) (systems/CombatArea),
--                  nearest_monster, summon(소환), hit_web(거미줄 클릭), weapon_rate.

local Class = require("lib.classic")
local EventBus = require("core.EventBus")
local RNG = require("core.RNG")
local Grid = require("systems.Grid")
local WaveSpawner = require("systems.WaveSpawner")
local Wear = require("systems.Wear")
local HeroCombat = require("systems.HeroCombat")
local Projectiles = require("systems.Projectiles")
local DamageRules = require("systems.DamageRules")
local BossPatterns = require("systems.BossPatterns")
local CombatArea = require("systems.CombatArea")
local NightClock = require("systems.NightClock")
local CombatLocks = require("systems.CombatLocks")
local BALANCE = require("data.balance")
local WAVES = require("data.waves")
local COMBAT = require("data.combat")
local ITEMS = require("data.items")
local LAYOUT = require("data.layout")

local Combat = Class:extend()
CombatArea.install(Combat)
NightClock.install(Combat)
CombatLocks.install(Combat)

local NIGHT = LAYOUT.night
local WALL_X = NIGHT.wall.x + NIGHT.wall.w
local TARGET_LIMIT_X = NIGHT.lane.x + NIGHT.lane.w - COMBAT.projectiles.target_margin * NIGHT.field_scale

function Combat:new(workshop)
    self._workshop = workshop
    self.active = false
    self.overclock = false
    self.elapsed = 0
    self.overclock_time = 0  -- 이번 밤 과부하를 켜 둔 시간(초) — 길드 의뢰 '과부하 시험' 판정
    self.duration = COMBAT.night.duration
    self.monsters = {}
    self.projectiles = {}
    self.beams = {}
    self.webs, self.chains = {}, {}     -- 봉인된 진열장 칸: 거미줄(→ 남은 클릭 수) · 룬 사슬(→ 남은 초) (systems/CombatLocks)
    self._cooldowns = setmetatable({}, { __mode = "k" })
    self._wear = Wear(workshop)     -- 진열장 유물의 점진 마모 (과열 판정 대체)
    self.hero = HeroCombat(workshop, self)      -- 공방 문 앞 주인공: 근접 타격 · 방어 · 반격 · 장착 장비 마모
end

-- modifiers: 핏빛 달·계절 { hp_mult, speed_mult, defense, blood_moon } (없으면 nil)
function Combat:start(day, modifiers)
    self.active = true
    self.modifiers = modifiers
    self.overclock = false
    self.overclock_time = 0
    self:_reset_clock()
    self.monsters, self.projectiles, self.beams, self.webs, self.chains = {}, {}, {}, {}, {}
    self.night_spawns = 0             -- 이번 밤 레인에 나온 몬스터 수 (웨이브 · 우두머리 · 소환 — 밸런스 보고)
    self._cooldowns = setmetatable({}, { __mode = "k" })
    self._rng = RNG.stream("combat")
    local wave_day = self._workshop.wave_day and self._workshop:wave_day(day) or day     -- 긴 계약은 완만하게 강해진다
    local schedule = { boss = self._workshop.boss_rules, midboss = self._workshop.midboss_rules, final = self._workshop.final_rules }
    self._spawner = WaveSpawner(day, RNG.stream("waves"), schedule, modifiers, wave_day)
    self._wear:reset()
    self.hero:reset()
    self._bosses = BossPatterns(self, self._workshop, self._rng)
end

-- 새벽: 거미줄은 걷히고, 소탕 시간 한도까지 남아 있던 몬스터는 달아난다
function Combat:end_night()
    local fled = 0
    for _, monster in ipairs(self.monsters) do
        if not monster.dead then
            fled = fled + 1
        end
    end
    if fled > 0 then
        EventBus.emit("combat:monsters_fled", { count = fled })
    end
    self:set_overclock(false)
    self.monsters, self.projectiles, self.webs, self.chains = {}, {}, {}, {}
    self.active = false
end

function Combat:set_overclock(enabled)
    if self.overclock == enabled or (enabled and not self.active) then
        return
    end
    self.overclock = enabled
    EventBus.emit("combat:overclock_changed", { enabled = enabled })
end

function Combat:_add_monster(monster)
    self.monsters[#self.monsters + 1] = monster
    self.night_spawns = self.night_spawns + 1
    if monster.spec.boss or monster.spec.midboss then        -- 대보스 · 중간 보스: 패턴 시작 + 등장 알림 (경고 배너·효과음)
        self._bosses:spawned(monster)
        EventBus.emit(monster.spec.boss and "combat:boss_arrived" or "combat:midboss_arrived", { monster = monster, x = monster.x, y = monster.y })
    end
end

-- 보스 패턴이 부르는 소환 (해골 등)
function Combat:summon(type_id, x, y)     -- 그 밤 레인 몬스터가 crowd_cap.total 이면 부르지 않는다 (안전 상한, 거절이면 nil)
    if self.night_spawns < WAVES.crowd_cap.total then
        local monster = self._spawner:make(type_id, x, y)
        self:_add_monster(monster)
        return monster
    end
end

function Combat:update(dt)
    if not self.active then
        return
    end
    self.elapsed = self.elapsed + dt
    for _, monster in ipairs(self._spawner:update(dt) or {}) do
        self:_add_monster(monster)
    end
    self._bosses:update(dt)
    self:update_locks(dt)
    self:_update_monsters(dt)
    self:_update_weapons(dt)
    self.hero:update(dt)
    Projectiles.update(self, dt, function(item, monster, damage)
        self:_hit(item, monster, damage)
    end)
    if self.overclock then
        self.overclock_time = self.overclock_time + dt
    end
    self._wear:update(dt, self.overclock)
    self:_remove_dead()
    self:_check_overtime()
end

-- (x, y)에서 가장 가까운 살아 있는 몬스터. exclude: 제외 집합, max_range: 최대 거리
function Combat:nearest_monster(x, y, exclude, max_range)
    local best, best_distance = nil, max_range and max_range * max_range or math.huge
    for _, monster in ipairs(self.monsters) do
        if not monster.dead and monster.x < TARGET_LIMIT_X and not (exclude and exclude[monster]) then
            local dx, dy = monster.x - x, monster.y - y
            local distance = dx * dx + dy * dy
            if distance < best_distance then
                best, best_distance = monster, distance
            end
        end
    end
    return best
end

function Combat:_update_monsters(dt)
    for _, monster in ipairs(self.monsters) do
        if not monster.dead then
            local burn = monster:update(dt)
            if burn > 0 then
                self:damage_monster(monster, burn, nil, true, "fire")
            end
            if not monster.dead and monster.x - monster.radius <= WALL_X then
                self:_hit_wall(monster)
            end
        end
    end
end

-- 그 무기의 지금 실제 연사(회/초): 시너지 배율 × 과부하
function Combat:weapon_rate(item)
    local stat = item and self._workshop:grid_stats().stats[item]
    if stat == nil then
        return 0
    end
    return stat.fire_rate * (self.overclock and self._workshop.overclock_rules.rate_mult or 1)
end

-- 다음 발사까지 충전 정도 0~1 (연출용: 발사 직전 에너지를 모으는 모습)
function Combat:charge(item)
    local cooldown, rate = self._cooldowns[item], self:weapon_rate(item)
    if cooldown == nil or rate <= 0 then
        return 0
    end
    return math.max(0, math.min(1, 1 - cooldown * rate))
end

function Combat:_update_weapons(dt)
    local grid_stats = self._workshop:grid_stats()
    local inventory = self._workshop.inventory
    local rate_mult = self.overclock and self._workshop.overclock_rules.rate_mult or 1
    for index = 1, Grid.SIZE do
        local item = inventory:get("grid", index)
        local stat = item and grid_stats.stats[item]
        if stat ~= nil and item:is_weapon() and stat.fire_rate > 0 and not self:is_locked(index) then
            local rate = stat.fire_rate * rate_mult
            local cooldown = (self._cooldowns[item] or self._rng:float(0, 1 / rate)) - dt
            if cooldown <= 0 then
                local x, y = Grid.cell_center(index)
                local target = self:nearest_monster(x, y)
                if target ~= nil then
                    self:_fire(item, x, y, target, stat.attack)
                    self._wear:shot(item, index)
                    cooldown = math.max(cooldown + 1 / rate, 0)
                else
                    cooldown = 0
                end
            end
            self._cooldowns[item] = cooldown
        end
    end
end

-- (x, y) = 그 무기가 놓인 진열장 칸의 정중앙
function Combat:_fire(item, x, y, target, damage)
    local color = ITEMS.elements[item.element].color
    if item.proto.projectile == "laser" then
        Projectiles.add_beam(self, x, y, target.x, target.y, color, nil, item)
        self:_hit(item, target, damage)
    else
        Projectiles.add_bullet(self, item, x, y, target, damage, color)
    end
    EventBus.emit("combat:fired", { item = item, x = x, y = y, tx = target.x, ty = target.y, color = color, combat = self })
end

function Combat:_hit(item, monster, damage)
    local mult, crit = DamageRules.roll_crit()     -- 치명타: 피해 x mult (data/combat.lua 의 crit)
    local hit = EventBus.emit("combat:hit", {
        item = item, monster = monster, damage = damage * mult, combat = self, chained = false, crit = crit,
    })
    self:damage_monster(monster, hit.damage, item, false, nil, true, crit)
end

-- silent: 화상처럼 숫자를 띄우지 않는 피해. damage_type: 생략하면 유물의 damage_type. direct: 무기의 직접 타격. crit: 치명타
function Combat:damage_monster(monster, amount, item, silent, damage_type, direct, crit)
    if monster.dead or amount <= 0 then
        return
    end
    local final, mark = DamageRules.apply(monster, amount, {
        item = item, damage_type = damage_type, direct = direct, rate = direct and self:weapon_rate(item) or 0,
    })
    if mark == "immune" then
        EventBus.emit("combat:immune", { monster = monster, item = item, x = monster.x, y = monster.y })
        return
    end
    self._bosses:damaged(monster, final)
    local killed = monster:take_damage(final)
    if not silent then
        EventBus.emit("combat:damage_dealt", {
            monster = monster, amount = final, item = item, x = monster.x, y = monster.y, armored = mark == "armored",
            crit = crit == true, damage_type = damage_type or DamageRules.type_of(item),
        })
    end
    if killed then
        self:_kill(monster, item)
    end
end

-- killer: 마지막 피해를 준 유물 (화상·폭발이면 nil 일 수 있음)
function Combat:_kill(monster, killer)
    monster.dead = true
    local mult = (self.overclock and self._workshop.overclock_rules.gold_mult or 1) * BALANCE.economy.kill_gold_mult
    local kill = EventBus.emit("combat:monster_killed", {
        monster = monster, gold = monster.gold * mult, x = monster.x, y = monster.y,
        item = killer, burning = monster:is_burning(), combat = self,
    })
    self._workshop:add_gold(math.floor(kill.gold + 0.5), "kill")
    if monster.spec.pattern ~= nil then
        self._bosses:killed(monster)
    end
end

function Combat:_hit_wall(monster)
    monster.dead = true
    local hit = EventBus.emit("combat:wall_hit", { monster = monster, damage = monster.damage, x = WALL_X, y = monster.y })
    local damage = self.hero:guard(monster, hit.damage)        -- 주인공이 방어력만큼 막고 반격한다
    self._workshop:damage_hp(math.max(1, math.floor(damage + 0.5)), "monster")
end

function Combat:_remove_dead()
    local alive = {}
    for _, monster in ipairs(self.monsters) do
        if not monster.dead then
            alive[#alive + 1] = monster
        end
    end
    self.monsters = alive
end

return Combat
