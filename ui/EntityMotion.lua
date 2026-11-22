-- ui/EntityMotion.lua
-- 밤 전투 몬스터의 절차적 모션 (수치 data/animations.lua). 규칙과 무관한 연출이라 몬스터 좌표(시스템)는 바꾸지 않고,
-- 그릴 때 쓰는 포즈(dx, dy, rot, sx, sy, flash, glow, deform)만 계산한다.
--   보행     : light = 통통 튀는 빠른 보폭 + 전방(방벽 쪽) 기울기 / heavy = 한 걸음마다 내려앉는 스쿼시 + 발밑 먼지
--             / float = 걷지 않는다 (float_cape 메시가 8자 부유)
--   방벽 공격: 닿기 직전 windup 초 동안 제자리에서 몸을 뒤로 젖히며 붉은 기운을 모으고 → lunge 초 만에 방벽으로 돌진.
--             부딪힌 순간(combat:wall_hit) 몬스터는 사라지므로 잔상(ghost)이 타격 스쿼시 → 뒤로 물러나며 사라지는 모습을 맡는다
--   피격     : combat:damage_dealt → hit.flash 초 흰 점멸 + 공격한 칸에서 먼 쪽으로 밀렸다가 스프링으로 복원
--   그로기   : 최종 보스(groggy_time > 0)는 걷지 않고 제자리에서 비틀거린다 (발밑 먼지도 없다)
-- 발밑 먼지는 넘겨받은 ui/Effects 로 뿌린다.
-- 공방 문 앞의 주인공(ui/LaneHero — 동조 투사 · 근접 내려찍기 · 방어 포즈)도 여기서 만들고(hero) 같은 걸음으로 갱신한다.
-- 최종 보스 배너('스승의 흔적'): boss:master_arrived · master:final_resolved 를 banner 에 기록하고, 처음 그려지는 순간의
-- 실시간(time)부터 잰다 (banner_at — ui/MasterBossHud 가 출현 경고 · 결말 배너를 그린다, 밤이 시작되면 지운다).

local Class = require("lib.classic")
local EventBus = require("core.EventBus")
local Grid = require("systems.Grid")
local LaneHero = require("ui.LaneHero")
local ANIM = require("data.animations")
local LAYOUT = require("data.layout")

local EntityMotion = Class:extend()

local GAITS, WALL, HIT = ANIM.gaits, ANIM.wall, ANIM.hit
local WALL_X = LAYOUT.night.wall.x + LAYOUT.night.wall.w
local DUST = { { 0.42, 0.37, 0.33 }, { 0.3, 0.27, 0.25 } }
local STAGGER = { tilt = 0.09, speed = 5.2, sway = 0.07, squash = 0.04 }    -- 그로기 비틀거림 (반경 배율 · 라디안)

local function ease(t)
    t = math.max(0, math.min(1, t))
    return t * t * (3 - 2 * t)
end

function EntityMotion:new(fx, workshop)
    self._fx = fx
    self._workshop = workshop
    self._states = setmetatable({}, { __mode = "k" })
    self._ghosts = {}
    self._pose = {}
    self.wall_hit, self.wall_hit_y = 0, nil        -- 방벽 피격 직후 1 → 0 (ui/LaneScenery: 공방 건물 흔들림·붉은 번쩍임·결계 파동)
    self.banner = nil                               -- 최종 보스 배너 { kind = "arrival" | "verdict", slain, lit, total, start }
    self.hero = LaneHero(fx, workshop)              -- 공방 문 앞의 주인공 (ui/LaneView 가 그린다)
    local function on(event, handler)
        EventBus.subscribe(event, handler, { owner = self, priority = -100 })
    end
    on("combat:damage_dealt", function(p) self:_hit(p) end)
    on("combat:wall_hit", function(p) self:_wall_hit(p) end)
    on("boss:master_arrived", function() self.banner = { kind = "arrival" } end)
    on("master:final_resolved", function(p)
        self.banner = { kind = "verdict", slain = p.slain, lit = p.lit, total = p.total }
    end)
    EventBus.subscribe("phase:night_started", function()
        self._ghosts, self.banner = {}, nil
    end, { owner = self })
end

-- 지금 배너와 처음 그려진 뒤 지난 실시간(초). 없으면 nil
function EntityMotion:banner_at(time)
    local banner = self.banner
    if banner == nil then
        return nil, 0
    end
    banner.start = banner.start or time
    return banner, math.max(0, time - banner.start)
end

function EntityMotion:destroy()
    self.hero:destroy()
    EventBus.unsubscribe_owner(self)
end

function EntityMotion.gait_of(monster)
    return ANIM.monster_gaits[monster.art_id or monster.type_id] or "light"
end

function EntityMotion:state(monster)
    local state = self._states[monster]
    if state == nil then
        state = { push_x = 0, push_y = 0, vel_x = 0, vel_y = 0, flash = 0, phase = "walk", timer = 0, step = 0 }
        self._states[monster] = state
    end
    return state
end

-- 피격: 흰 점멸 + 공격한 무기 칸에서 먼 쪽으로 넉백 (출처를 모르면 오른쪽)
function EntityMotion:_hit(p)
    local state = self:state(p.monster)
    state.flash = HIT.flash
    local dx, dy = 1, 0
    local area, index = nil, nil
    if p.item ~= nil then
        area, index = self._workshop.inventory:locate(p.item)
    end
    if area == "grid" then
        local cx, cy = Grid.cell_center(index)
        local length = math.max(1, math.sqrt((p.x - cx) ^ 2 + (p.y - cy) ^ 2))
        dx, dy = (p.x - cx) / length, (p.y - cy) / length
    end
    state.vel_x, state.vel_y = state.vel_x + dx * HIT.impulse, state.vel_y + dy * HIT.impulse * 0.5
end

-- 방벽 타격: 잔상이 돌진 끝 자세에서 스쿼시 → 물러나며 사라진다
function EntityMotion:_wall_hit(p)
    self.wall_hit, self.wall_hit_y = 1, p.y
    local monster = p.monster
    local state = self:state(monster)
    self._ghosts[#self._ghosts + 1] = {
        monster = monster, x = monster.x + (state.last_dx or 0), y = monster.y, t = 0, flip = state.flip,
    }
end

function EntityMotion:update(dt, combat)
    self.wall_hit = math.max(0, self.wall_hit - dt * 3)
    self.hero:update(dt)
    for _, monster in ipairs(combat.monsters) do
        local state = self:state(monster)
        state.flash = math.max(0, state.flash - dt)
        local ax = -HIT.stiffness * state.push_x - HIT.damping * state.vel_x     -- 넉백 스프링
        local ay = -HIT.stiffness * state.push_y - HIT.damping * state.vel_y
        state.vel_x, state.vel_y = state.vel_x + ax * dt, state.vel_y + ay * dt
        state.push_x, state.push_y = state.push_x + state.vel_x * dt, state.push_y + state.vel_y * dt
        local gait = EntityMotion.gait_of(monster)
        if gait == "heavy" and (monster.groggy_time or 0) <= 0 then     -- 한 걸음 내디딜 때마다 발밑 먼지 (그로기면 멈춰 있다)
            local step = math.floor(monster.anim * GAITS.heavy.tempo * 2)
            if step ~= state.step then
                state.step = step
                self._fx:burst(monster.x, monster.y + monster.radius, { count = GAITS.heavy.dust, colors = DUST,
                    speed_min = 20, speed_max = 80, angle = -math.pi / 2, spread = 1.2, gravity = 140, life_max = 0.5 })
            end
        end
        local speed = monster.speed * (monster.slow_factor or 1)
        local eta = (monster.x - monster.radius - WALL_X) / math.max(1, speed)
        if state.phase == "walk" and eta <= WALL.windup + WALL.lunge then
            state.phase, state.timer, state.anchor_x = "windup", 0, monster.x
        elseif state.phase ~= "walk" then
            state.timer = state.timer + dt
            if state.phase == "windup" and state.timer >= WALL.windup then
                state.phase, state.timer = "lunge", 0
            end
        end
    end
    for i = #self._ghosts, 1, -1 do
        local ghost = self._ghosts[i]
        ghost.t = ghost.t + dt
        if ghost.t >= WALL.impact + WALL.recover then
            table.remove(self._ghosts, i)
        end
    end
end

-- 보행 사이클: dy, rot, sx, sy
local function walk(monster, gait)
    local r = monster.radius
    if gait == "light" then
        local spec = GAITS.light
        local hop = math.abs(math.sin(monster.anim * spec.tempo * math.pi))
        return -hop * spec.hop * r, -spec.tilt * (0.6 + 0.4 * hop), 1 - 0.05 * hop, 1 + 0.07 * hop
    elseif gait == "heavy" then
        local spec = GAITS.heavy
        local cycle = (monster.anim * spec.tempo * 2) % 1
        local lift = math.sin(cycle * math.pi)
        local land = (1 - lift) ^ 4 * spec.squash
        return -lift * spec.lift * r, 0.03 * math.sin(monster.anim * spec.tempo * math.pi), 1 + land * 0.7, 1 - land
    end
    return 0, 0, 1, 1
end

-- 그릴 때 쓸 포즈 (같은 표를 다시 쓴다 — 바로 그려서 쓸 것)
function EntityMotion:pose(monster, time)
    local state = self:state(monster)
    local pose = self._pose
    local r = monster.radius
    local dy, rot, sx, sy = walk(monster, EntityMotion.gait_of(monster))
    local dx = 0
    if (monster.groggy_time or 0) > 0 then                     -- 그로기: 걷지 않고 제자리에서 비틀거린다
        local wobble = math.sin(time * STAGGER.speed)
        dy, rot, sx, sy = 0, wobble * STAGGER.tilt, 1 + STAGGER.squash * wobble, 1 - STAGGER.squash * math.abs(wobble)
        dx = math.sin(time * STAGGER.speed * 0.5) * STAGGER.sway * r
    end
    pose.glow_alpha = 0
    if state.phase == "windup" then                            -- 제자리에 멈춰 뒤로 젖히며 붉은 기운을 모은다
        local p = ease(state.timer / WALL.windup)
        dx = (state.anchor_x - monster.x) + WALL.lean_back * r * p
        rot = rot + WALL.lean_angle * p
        pose.glow_alpha = p
    elseif state.phase == "lunge" then                         -- 방벽으로 빠르게 돌진
        local p = math.min(1, state.timer / WALL.lunge)
        local from = (state.anchor_x - monster.x) + WALL.lean_back * r
        dx = from + (-WALL.overshoot * r - from) * p * p
        rot = rot + WALL.lean_angle * (1 - p) - 0.15 * p
        sx, sy = sx * (1 + 0.15 * p), sy * (1 - 0.08 * p)
        pose.glow_alpha = 1 - p * 0.5
    end
    state.last_dx = dx
    pose.dx, pose.dy = dx + state.push_x, dy + state.push_y
    pose.rot, pose.sx, pose.sy = rot, sx, sy
    pose.flash = state.flash > 0
    pose.glow_color = WALL.glow
    pose.deform = ANIM.monsters[monster.art_id or monster.type_id]
    pose.time = time + monster.anim * 0.37
    pose.alpha = 1
    return pose
end

function EntityMotion:ghosts()
    return self._ghosts
end

-- 잔상 포즈: 타격 스쿼시 → 뒤로 물러나며 옅어진다 (ghost.x 기준 상대 dx)
function EntityMotion:ghost_pose(ghost, time)
    local pose = self._pose
    local r = ghost.monster.radius
    pose.dy, pose.flash, pose.glow_color = 0, false, WALL.glow
    pose.deform = ANIM.monsters[ghost.monster.art_id or ghost.monster.type_id]
    pose.time = time
    if ghost.t < WALL.impact then
        local p = ghost.t / WALL.impact
        pose.dx, pose.rot, pose.sx, pose.sy = 0, -0.1, 1 - 0.22 * math.sin(p * math.pi), 1 + 0.16 * math.sin(p * math.pi)
        pose.glow_alpha, pose.alpha = 0.8, 1
    else
        local p = ease((ghost.t - WALL.impact) / WALL.recover)
        pose.dx, pose.rot, pose.sx, pose.sy = (WALL.overshoot + WALL.lean_back) * r * p, 0.1 * p, 1, 1
        pose.glow_alpha, pose.alpha = 0.5 * (1 - p), 1 - p
    end
    return pose
end

return EntityMotion
