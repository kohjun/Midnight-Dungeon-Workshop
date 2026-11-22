-- ui/LaneHero.lua
-- 밤 전투 레인의 주인공 (수치 data/animations.lua 의 hero · 배치 data/art.lua 의 hero, 그림 ui/LaneHeroArt).
-- 공방주는 검사가 아니다 — 진열장 공명 회로(ui/ConduitView)의 마력이 문 앞에서 공명 건틀릿과 망치를 든 주인공에게 흘러들고,
-- 주인공은 그 마력을 동조해 내보낸다. 주인공의 실제 전투(근접 타격 · 방어 · 반격 · 장비 마모)는 systems/HeroCombat 이
-- 하고, 여기서는 그 이벤트에 맞춰 포즈와 효과만 만든다 (ui/EntityMotion 이 소유 · 갱신, ui/LaneView 가 그린다).
--   대기      : protagonist_idle + 미세한 호흡. 장착한 무기(장비창 무기 칸) — 없으면 공명 회로 중앙 코어(systems/Grid.CORE)의
--               유물, 그것도 비었으면 진열장 최고 강화 유물 — 의 속성 색으로 망치 끝과 건틀릿에 오라가 감돈다 (focus)
--   동조 투사  : combat:fired 마다 황금 마력 섬광이 스치고, cast 쿨타임(0.25~0.35초)이 돌았으면 protagonist_attack 으로
--               마력 파동을 뿜는다
--   근접 내려찍기 : combat:hero_strike — 주인공이 장착 무기로 방벽 앞 마물을 실제로 칠 때 protagonist_attack 으로
--               그 마물에게 망치 궤적 호를 긋는다 (반격은 방어 포즈를 유지한 채 궤적만)
--   방어      : combat:wall_hit 이면 protagonist_block + 황금 룬 방패 파동
-- 원화가 없으면 코드 실루엣으로 같은 포즈·효과가 그대로 돈다.

local Class = require("lib.classic")
local EventBus = require("core.EventBus")
local RNG = require("core.RNG")
local Grid = require("systems.Grid")
local LaneHeroArt = require("ui.LaneHeroArt")
local ANIM = require("data.animations")
local ART = require("data.art")
local ITEMS = require("data.items")
local LAYOUT = require("data.layout")

local LaneHero = Class:extend()

local SPEC = ANIM.hero
local HERO = ART.hero
local NIGHT = LAYOUT.night
local WALL_X = NIGHT.wall.x + NIGHT.wall.w
local SPARKS = { { 1.0, 0.9, 0.55 }, { 1.0, 0.72, 0.3 }, { 1, 1, 1 } }

-- 발 중심 x, 발바닥 y, 키
function LaneHero.anchor()
    return WALL_X + HERO.x_offset, HERO.ground_y, HERO.height
end

-- 주인공이 동조하는 유물: 장착한 무기 → 공명 회로 중앙 코어의 작동 중인 유물 → 진열장에서 가장 높이 강화된 작동 중인 유물 (없으면 nil)
function LaneHero.focus(workshop)
    local inventory = workshop.inventory
    local weapon = workshop:hero_gear().weapon
    if weapon ~= nil and not weapon:is_worn_out() then
        return weapon
    end
    local core = inventory:get("grid", Grid.CORE)
    if core ~= nil and not core:is_worn_out() then
        return core
    end
    local best = nil
    for index = 1, Grid.SIZE do
        local item = inventory:get("grid", index)
        if item ~= nil and not item:is_worn_out() and (best == nil or item.level > best.level) then
            best = item
        end
    end
    return best
end

function LaneHero:new(fx, workshop)
    self._fx = fx
    self._workshop = workshop
    self._rng = RNG.stream("fx")
    self:reset()
    local function on(event, handler)
        EventBus.subscribe(event, handler, { owner = self, priority = -100 })
    end
    on("combat:fired", function(p) self:_fired(p) end)
    on("combat:hero_strike", function(p) self:_struck(p) end)
    on("combat:wall_hit", function(p) self:_guard(p) end)
    on("phase:night_started", function() self:reset() end)
end

function LaneHero:destroy()
    EventBus.unsubscribe_owner(self)
end

function LaneHero:reset()
    self.pose, self.action = "idle", nil          -- pose: "idle" | "attack" | "block" · action: "cast" | "melee" | "block"
    self._pose_time, self._pose_total = 0, 1
    self._cooldown, self._melee_cooldown = 0, 0
    self.flash = 0                                -- 유물이 쏠 때 스치는 황금 마력 섬광 1 → 0
    self.waves, self.smashes, self.shields = {}, {}, {}
end

-- 지금 오라 색 (동조하는 유물의 속성 색)
function LaneHero:color()
    local item = LaneHero.focus(self._workshop)
    return item and ITEMS.elements[item.element].color or SPEC.default_color
end

function LaneHero:_strike(pose, action, time)
    self.pose, self.action, self._pose_time, self._pose_total = pose, action, time, time
end

-- 진열장 유물이 쐈다: 황금 섬광 + (쿨타임이 돌았으면) 동조 투사
function LaneHero:_fired(p)
    self.flash = 1
    if self._cooldown > 0 or self.pose == "block" or self.action == "melee" then
        return
    end
    self._cooldown = self._rng:float(SPEC.cast.cooldown_min, SPEC.cast.cooldown_max)
    self:_strike("attack", "cast", SPEC.cast.pose_time)
    self.waves[#self.waves + 1] = { life = SPEC.cast.wave_time, color = p.color or self:color() }
end

-- 주인공이 방벽 앞 마물을 쳤다 (systems/HeroCombat): 근접 망치 내려찍기 궤적. 반격이면 방어 포즈는 그대로 둔다
function LaneHero:_struck(p)
    local monster = p.monster
    if not p.counter then
        self:_strike("attack", "melee", SPEC.melee.pose_time)
    end
    local size = monster.radius * NIGHT.sprite_scale
    self.smashes[#self.smashes + 1] = { x = monster.x, y = monster.y, size = size, life = SPEC.melee.arc_time, color = self:color() }
    self._fx:burst(monster.x, monster.y + size * 0.4, { count = 6, colors = SPARKS, speed_min = 60, speed_max = 190,
        angle = -math.pi / 2, spread = 1.3, gravity = 320, life_max = 0.4, size_max = 3.5 })
end

-- 방벽이 맞았다: 방어 포즈 + 황금 룬 방패
function LaneHero:_guard()
    self:_strike("block", "block", SPEC.block.pose_time)
    self.shields[#self.shields + 1] = { life = SPEC.block.shield_time }
end

local function age(list, dt)
    for i = #list, 1, -1 do
        list[i].life = list[i].life - dt
        if list[i].life <= 0 then
            table.remove(list, i)
        end
    end
end

function LaneHero:update(dt)
    self._cooldown = math.max(0, self._cooldown - dt)
    self._melee_cooldown = math.max(0, self._melee_cooldown - dt)
    self.flash = math.max(0, self.flash - dt / SPEC.flash)
    if self._pose_time > 0 then
        self._pose_time = self._pose_time - dt
        if self._pose_time <= 0 then
            self.pose, self.action = "idle", nil
        end
    end
    age(self.waves, dt)
    age(self.smashes, dt)
    age(self.shields, dt)
end

-- 포즈가 진행된 정도에 따른 앞뒤 밀림 (공격 = 앞으로 내딛고, 방어 = 뒤로 밀린다)
function LaneHero:_lean()
    if self.action == nil then
        return 0
    end
    local swing = math.sin(math.pi * (1 - math.max(0, self._pose_time) / self._pose_total))
    if self.action == "block" then
        return -SPEC.block.recoil * swing
    end
    return SPEC[self.action].lunge * swing
end

-- 몬스터보다 먼저 그린다 (공방 건물 앞)
function LaneHero:draw(time)
    local x, ground_y, height = LaneHero.anchor()
    local breathe = self.pose == "idle" and SPEC.breathe.amount * math.sin(time * SPEC.breathe.speed) or 0
    LaneHeroArt.figure(self.pose, x, ground_y, height, time, {
        dx = self:_lean(), breathe = breathe, aura = self:color(), flash = self.flash,
    })
end

-- 몬스터 위에 그린다: 마력 파동 · 망치 궤적 · 룬 방패
function LaneHero:draw_effects(time)
    local x, ground_y, height = LaneHero.anchor()
    local gx, gy = LaneHeroArt.point("attack", "gauntlet", x, ground_y, height)
    for _, wave in ipairs(self.waves) do
        LaneHeroArt.wave(gx, gy, 1 - wave.life / SPEC.cast.wave_time, wave.color, SPEC.cast.wave_reach)
    end
    for _, smash in ipairs(self.smashes) do
        LaneHeroArt.smash(smash.x, smash.y, smash.size, 1 - smash.life / SPEC.melee.arc_time, smash.color)
    end
    for _, shield in ipairs(self.shields) do
        LaneHeroArt.shield(x + height * 0.2, ground_y - height * 0.55, 1 - shield.life / SPEC.block.shield_time,
            SPEC.block.shield_radius, time)
    end
end

return LaneHero
