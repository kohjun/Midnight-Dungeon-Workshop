-- systems/WaveSpawner.lua
-- 밤 웨이브 스폰 스케줄 (data/waves.lua · 몬스터 스펙 data/enemies.lua).
--   일반 스폰: 실효 일차(wave_day = 1 + (일차-1) × 난이도 pace)에 따라 간격·체력·구성·동시 출현 수가 변한다
--   돌격 무리(Pack Burst): 밤 6 · 13 · 20초에 정해진 종류 중에서 여러 마리를 포탈에서 한꺼번에
--   월말(10·20·30…일) 대보스 · 월 중순(5·15·25…일) 중간 보스: 각각 4종을 차례로 돈다. 달이 지날수록 체력·기믹 강도 상승.
--   '스승의 흔적' 마지막 날(schedule.final.day)에는 월말 대보스 대신 최종 보스(schedule.final.type)
--     (monster.intensity — systems/BossPatterns · MidBossPatterns 가 간격·세기를 조절)
-- 중후반: 실효 일차 late.from 이후 그 밤의 체력 배율(우두머리 포함)이 late.hp 씩, 일반 몬스터(무리·소환 포함)의 방벽 피해가
--   late.damage 씩 오른다. 우두머리는 그 위에 달마다 escalation 체력 배율, 방벽 피해는 달별 배율만 받는다.
-- 하룻밤 상한(systems/WaveCrowd): 일반 스폰 + 돌격 무리가 crowd_cap 을 넘으면 마릿수를 줄이고 정예 비중·개별 체력으로 메운다
--   (self.crowd = { planned, cap, ratio, elite_mult, hp_mult }, self.spawned 는 상한을 넘지 않는다).
-- 수정자: 핏빛 달(체력·속도) · 겨울(체력·방어력 defense = 받는 피해 감소). make(type, x, y) 는 소환(해골·졸개)용.

local Class = require("lib.classic")
local Monster = require("entities.Monster")
local Calendar = require("systems.Calendar")
local WaveCrowd = require("systems.WaveCrowd")
local ENEMIES = require("data.enemies")
local WAVES = require("data.waves")
local LAYOUT = require("data.layout")

local WaveSpawner = Class:extend()

local PORTAL = LAYOUT.night.portal            -- 몬스터는 포탈 아치 중심에서 나온다
local FIELD = LAYOUT.night.field              -- 몬스터가 걷는 길 (스폰 Y 범위)
local FIELD_SCALE = LAYOUT.night.field_scale  -- 넓어진 밤 레인만큼 몬스터 크기·속도 배율

local function cycle_pick(list, day, spec)
    if day < math.max(1, spec.offset) or (day - spec.offset) % spec.every ~= 0 then
        return nil
    end
    local index = math.floor((day - spec.offset) / spec.every) + (spec.offset > 0 and 1 or 0)
    if index < 1 then
        return nil
    end
    return list[(index - 1) % #list + 1]
end

-- 그 일차의 월말 대보스 (10·20·30…일, 없으면 nil)
function WaveSpawner.boss_for(day)
    return cycle_pick(WAVES.boss_cycle, day, WAVES.boss)
end

-- 그 일차의 월 중순 중간 보스 (5·15·25…일, 없으면 nil)
function WaveSpawner.midboss_for(day)
    return cycle_pick(WAVES.midboss_cycle, day, WAVES.midboss)
end

-- 그 밤의 우두머리: 종류, "final" | "boss" | "midboss" (없으면 nil). final: { day, type } 캠페인 최종 보스 (없으면 nil)
function WaveSpawner.headliner(day, final)
    if final ~= nil and final.day == day then
        return final.type, "final"
    end
    local boss = WaveSpawner.boss_for(day)
    if boss ~= nil then
        return boss, "boss"
    end
    local midboss = WaveSpawner.midboss_for(day)
    return midboss, midboss and "midboss" or nil
end

-- 그 일차의 보스·중간 보스 기믹 강도 (1 = 첫 달)
function WaveSpawner.intensity(day)
    local esc = WAVES.escalation
    return math.min(esc.max, 1 + esc.per_month * (Calendar.month(day) - 1))
end

-- schedule: { boss = { at, hp_mult }, midboss = { at, hp_mult }, final = { day, type, at, hp_mult } } (없으면 우두머리 없음)
-- modifiers: { hp_mult, speed_mult, defense } (없으면 nil), wave_day: 웨이브 강도의 실효 일차 (생략하면 day)
function WaveSpawner:new(day, rng, schedule, modifiers, wave_day)
    modifiers = modifiers or {}
    wave_day = wave_day or day
    self._rng = rng
    self._headliner = nil
    local kind_type, kind = WaveSpawner.headliner(day, schedule and schedule.final)
    local rules = schedule and kind and schedule[kind]
    if rules ~= nil then
        local esc = WAVES.escalation
        local months = Calendar.month(day) - 1
        self._headliner = { at = rules.at, type = kind_type, kind = kind, intensity = WaveSpawner.intensity(day),
            hp_mult = (rules.hp_mult or 1) * (1 + esc.hp_per_month * months),
            damage_mult = (rules.damage_mult or 1) * (1 + (esc.damage_per_month or 0) * months) }
    end
    self._interval = WaveCrowd.interval(wave_day)
    self._timer = WAVES.first_delay
    self._elapsed = 0
    local late = math.max(0, wave_day - WAVES.late.from)
    self._hp_scale = (1 + WAVES.hp_growth * (wave_day - 1)) * (1 + WAVES.late.hp * late) * (modifiers.hp_mult or 1)
    self._damage_scale = (1 + WAVES.late.damage * late) * (modifiers.damage_mult or 1)
    self._speed_mult = modifiers.speed_mult or 1
    self._defense = modifiers.defense or 0
    self._group = WaveCrowd.group(wave_day)
    self._quota = 0                       -- 상한 때 일반 스폰 몫을 고르게 나누는 누적 몫 (난수 없음)
    self._wave_day = wave_day
    self._packs_done = 0
    self.spawned = 0                      -- 이번 밤에 나온 일반·무리 몬스터 수 (스모크 테스트·밸런스 보고)

    self._entries = {}
    for _, id in ipairs(ENEMIES.monster_order) do
        local spec = ENEMIES.monsters[id]
        if wave_day >= spec.min_day then
            self._entries[#self._entries + 1] = { id = id, weight = spec.weight + spec.weight_growth * (wave_day - 1) }
        end
    end
    self.crowd = WaveCrowd.apply(self._entries, wave_day)
end

function WaveSpawner:has_boss_pending()
    return self._headliner ~= nil
end

-- 이번 밤에 더 나올 몬스터가 없다 (스폰 창·돌격 무리가 지났고 우두머리도 나왔다). 소환(해골·졸개)은 우두머리가 살아 있는 동안만
function WaveSpawner:is_done()
    return self._headliner == nil and self._elapsed > WAVES.spawn_window and self._packs_done >= #WAVES.packs
end

-- 겨울 방어력 (받는 피해 감소, systems/DamageRules)
function WaveSpawner:_armor(monster)
    if self._defense > 0 then
        monster.defense = self._defense
    end
    return monster
end

-- damage_mult: 방벽 피해 배율 (생략하면 그 밤 일반 몬스터 배율, 우두머리는 달별 배율)
function WaveSpawner:_spawn(id, x, y, hp_mult, damage_mult)
    local monster = Monster(id, x, y, self._hp_scale * (hp_mult or 1), self._rng:float(0, math.pi * 2), self._speed_mult,
        FIELD_SCALE)
    monster.damage = monster.damage * (damage_mult or self._damage_scale)
    return self:_armor(monster)
end

-- 이번 프레임에 새로 등장한 몬스터 목록 (없으면 nil)
function WaveSpawner:update(dt)
    self._elapsed = self._elapsed + dt
    local spawned = {}
    local head = self._headliner
    if head ~= nil and self._elapsed >= head.at then
        self._headliner = nil
        local radius = ENEMIES.monsters[head.type].radius * FIELD_SCALE
        local monster = self:_spawn(head.type, PORTAL.x + radius * 0.5, FIELD.y + FIELD.h / 2, head.hp_mult, head.damage_mult)
        monster.intensity = head.intensity
        spawned[#spawned + 1] = monster
    end
    local pack = WAVES.packs[self._packs_done + 1]
    if pack ~= nil and self._elapsed >= pack.at then
        self._packs_done = self._packs_done + 1
        self:_spawn_pack(pack, spawned)
    end
    if self._elapsed <= WAVES.spawn_window then
        self._timer = self._timer - dt
        if self._timer <= 0 then
            self._timer = self._timer + self._interval
            self._quota = self._quota + self._group / self.crowd.ratio
            local count = math.floor(self._quota + 1e-9)
            self._quota = self._quota - count
            for order = 1, math.min(count, self.crowd.cap - self.spawned) do
                spawned[#spawned + 1] = self:_spawn_one(order)
            end
        end
    end
    return #spawned > 0 and spawned or nil
end

-- 돌격 무리: 정해진 종류 중 지금 나올 수 있는 것(없으면 웨이브 구성)에서 골라 포탈 앞에 한 줄로
function WaveSpawner:_spawn_pack(pack, out)
    local count = math.min(math.floor(WaveCrowd.pack_size(pack, self._wave_day) / self.crowd.ratio), self.crowd.cap - self.spawned)
    local pool = {}
    for _, entry in ipairs(self._entries) do
        for _, id in ipairs(pack.types) do
            if entry.id == id then
                pool[#pool + 1] = entry
            end
        end
    end
    if #pool == 0 then
        pool = self._entries
    end
    for i = 1, count do
        local id = self._rng:weighted_pick(pool).id
        local y = FIELD.y + FIELD.h * ((i - 0.5) / count) + self._rng:float(-8, 8)
        out[#out + 1] = self:_spawn(id, PORTAL.x + (i % 3) * WAVES.pack_spacing, y, self.crowd.hp_mult)
        self.spawned = self.spawned + 1
    end
end

-- 소환 몬스터 (같은 밤의 체력·속도 배율)
function WaveSpawner:make(type_id, x, y)
    assert(ENEMIES.monsters[type_id] ~= nil, "WaveSpawner: unknown monster '" .. tostring(type_id) .. "'")
    return self:_spawn(type_id, x, y)
end

function WaveSpawner:_spawn_one(order)
    local id = self._rng:weighted_pick(self._entries).id
    local radius = ENEMIES.monsters[id].radius * FIELD_SCALE
    local x = PORTAL.x + (order - 1) * radius * 2.5
    local y = self._rng:float(FIELD.y, FIELD.y + FIELD.h)
    self.spawned = self.spawned + 1
    return self:_spawn(id, x, y, self.crowd.hp_mult)
end

return WaveSpawner
