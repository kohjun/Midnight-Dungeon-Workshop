-- entities/Monster.lua
-- 전투 레인의 몬스터: 왼쪽(공방 방벽)으로 이동, 화상·둔화·감전 상태이상. 스펙은 data/enemies.lua (공통 규칙 data/combat.lua).
-- 보스·중간 보스 패턴(systems/BossPatterns · MidBossPatterns)이 쓰는 상태: pattern(타이머 등 패턴별 표), shield_time(붉은 보호막),
-- immunity(면역 종류), intensity(달별 기믹 강도), boost_time · boost_mult(돌파·돌진·주술 오라의 일시 가속 — 0 이면 멈춤),
-- damage_taken_mult(받는 피해 배율 — 최종 보스 균열 아이기스 · 그로기, systems/DamageRules), aegis · groggy_time(최종 보스),
-- hp_floor(체력이 이 아래로는 내려가지 않는다 — 최종 보스의 다음 아이기스 문턱, 그 아이기스가 서면 다음 문턱으로).
-- art_id: 그림을 고를 원화 id (중간 보스는 다른 몬스터 원화를 확대·색조로 다시 쓴다 — spec.sprite).

local Class = require("lib.classic")
local COMBAT = require("data.combat")
local ENEMIES = require("data.enemies")

local Monster = Class:extend()

-- hp_scale: 일차별 HP 배율, phase: 걷기 애니메이션 위상, speed_mult: 핏빛 달 등 속도 배율,
-- field_scale: 전투 필드 배율 (밤 레인이 넓어진 만큼 크기·속도를 키운다, 생략하면 1)
function Monster:new(type_id, x, y, hp_scale, phase, speed_mult, field_scale)
    local spec = ENEMIES.monsters[type_id]
    assert(spec ~= nil, "Monster: unknown type '" .. tostring(type_id) .. "'")
    self.type_id = type_id
    self.art_id = spec.sprite or type_id
    self.spec = spec
    self.x = x
    self.y = y
    self.radius = spec.radius * (field_scale or 1)
    self.max_hp = spec.hp * (hp_scale or 1)
    self.hp = self.max_hp
    self.speed = spec.speed * (speed_mult or 1) * (field_scale or 1)
    self.damage = spec.damage
    self.gold = spec.gold
    self.anim = phase or 0
    self.flash = 0
    self.burn_dps = 0
    self.burn_time = 0
    self.burn_stacks = 0      -- 화상 중첩 (폭염 화승총 폭발 조건)
    self.slow_factor = 1
    self.slow_time = 0
    self.shock_time = 0       -- 감전: 받는 피해 증가 (DamageRules)
    self.shield_time = 0      -- 사령술사 붉은 보호막 남은 시간
    self.immunity = nil       -- 균열 군주: "physical" | "elemental" | nil
    self.pattern = nil        -- 보스 패턴 상태 표 (BossPatterns 가 채운다)
    self.intensity = 1        -- 보스·중간 보스 기믹 강도 (WaveSpawner 가 달에 맞춰 채운다)
    self.boost_time = 0       -- 일시 가속 (선봉장 돌파 · 약탈 대장 돌진 · 주술사 오라)
    self.boost_mult = 1
    self.damage_taken_mult = 1  -- 받는 피해 배율 (균열 아이기스 x0.25 · 그로기 x1.5)
    self.aegis = nil          -- 최종 보스 균열 아이기스 { need, dealt, threshold } (systems/MasterBossPattern)
    self.groggy_time = 0      -- 아이기스가 깨진 뒤 그로기 남은 시간
    self.hp_floor = nil       -- 체력 하한 (최종 보스 단계 문턱)
    self.age = 0              -- 등장 뒤 지난 시간(초) — 중간 보스 출현 배너 (ui/MidBossView)
    self.dead = false
end

-- 이동·상태이상 갱신. 이번 프레임의 화상 피해량을 반환한다 (적용은 Combat 이 한다)
function Monster:update(dt)
    self.anim = self.anim + dt
    self.age = self.age + dt
    self.flash = math.max(0, self.flash - dt)

    local speed = self.speed
    if self.boost_time > 0 then
        speed = speed * self.boost_mult
        self.boost_time = self.boost_time - dt
    end
    if self.slow_time > 0 then
        speed = speed * self.slow_factor
        self.slow_time = self.slow_time - dt
        if self.slow_time <= 0 then
            self.slow_factor = 1
        end
    end
    self.x = self.x - speed * dt
    self.shock_time = math.max(0, self.shock_time - dt)
    self.shield_time = math.max(0, self.shield_time - dt)

    local burn = 0
    if self.burn_time > 0 then
        burn = self.burn_dps * math.min(dt, self.burn_time)
        self.burn_time = self.burn_time - dt
        if self.burn_time <= 0 then
            self.burn_dps = 0
            self.burn_stacks = 0
        end
    end
    return burn
end

-- 피해 적용. 죽었으면 true
function Monster:take_damage(amount)
    self.hp = math.max(self.hp_floor or -math.huge, self.hp - amount)
    self.flash = COMBAT.hit_flash
    return self.hp <= 0
end

function Monster:apply_burn(dps, duration)
    self.burn_stacks = math.min(COMBAT.area.max_burn_stacks, self.burn_stacks + 1)
    self.burn_dps = math.max(self.burn_dps, dps)
    self.burn_time = math.max(self.burn_time, duration)
end

function Monster:apply_slow(factor, duration)
    if self.spec.slow_immune then      -- 철갑 선봉장: 둔화·빙결 면역
        return
    end
    self.slow_factor = math.min(self.slow_factor, factor)
    self.slow_time = math.max(self.slow_time, duration)
end

-- 넉백: 오른쪽(포탈 쪽)으로 distance 만큼 밀린다. 정예·보스는 저항(data/combat.lua 의 knockback)만큼 덜 밀리고,
-- max_x 를 넘지 않는다. 실제로 밀린 거리를 반환한다
function Monster:knock_back(distance, max_x)
    local rules = COMBAT.knockback
    local resist = self.spec.knockback_resist or (self:is_boss() and rules.boss_resist or (self.spec.elite and rules.elite_resist or 0))
    local target = math.min(max_x or math.huge, self.x + distance * (1 - resist))
    local moved = math.max(0, target - self.x)
    self.x = self.x + moved
    return moved
end

function Monster:apply_shock(duration)
    self.shock_time = math.max(self.shock_time, duration)
end

function Monster:is_shocked()
    return self.shock_time > 0
end

function Monster:is_boss()
    return self.spec.boss == true
end

function Monster:is_midboss()
    return self.spec.midboss == true
end

-- 일시 가속 (더 센 쪽 · 더 긴 쪽을 남긴다)
function Monster:boost(mult, duration)
    self.boost_mult = self.boost_time > 0 and math.max(self.boost_mult, mult) or mult
    self.boost_time = math.max(self.boost_time, duration)
end

function Monster:is_burning()
    return self.burn_time > 0
end

function Monster:is_slowed()
    return self.slow_time > 0
end

return Monster
