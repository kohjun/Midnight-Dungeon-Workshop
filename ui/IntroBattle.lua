-- ui/IntroBattle.lua
-- 인트로 3단계 연출용 작은 전투: 포탈에서 고블린·슬라임이 쏟아져 나오고, 공방 앞 화염검(불꽃탄)과 번개 오브(연쇄 번개)가 격퇴한다.
-- 게임 규칙(Combat)과 무관한 순수 연출이다. 난수는 RNG.stream("fx"). 위치·속도는 data/intro.lua.

local Class = require("lib.classic")
local RNG = require("core.RNG")
local Audio = require("systems.Audio")
local Item = require("entities.Item")
local Draw = require("ui.Draw")
local SpriteBank = require("ui.SpriteBank")
local MonsterShapes = require("ui.MonsterShapes")
local ItemRenderer = require("ui.ItemRenderer")
local ART = require("data.art")
local ENEMIES = require("data.enemies")
local INTRO = require("data.intro")

local IntroBattle = Class:extend()

local LG = love.graphics
local FIRE = { { 1.0, 0.55, 0.15 }, { 1.0, 0.85, 0.3 }, { 0.9, 0.25, 0.1 } }
local BOLT = { 0.72, 0.55, 1.0 }
local BEAM_LIFE = 0.18

function IntroBattle:new(fx)
    self._fx = fx
    self._rng = RNG.stream("fx")
    self._monsters = {}
    self._shots = {}
    self._beams = {}
    self._spawn = 0
    self._cooldowns = { flame_sword = 0.3, lightning_orb = 0.6 }
    self._weapons = {}
    for id in pairs(INTRO.weapons) do
        local item = Item(id, { grade = "rare" })
        item.revealed.grade = true
        self._weapons[id] = item
    end
end

local function nearest(list, x)
    local best, best_d = nil, math.huge
    for _, m in ipairs(list) do
        if not m.dead and math.abs(m.x - x) < best_d then
            best, best_d = m, math.abs(m.x - x)
        end
    end
    return best
end

-- 지그재그 번개 선 (x1,y1 → x2,y2)
function IntroBattle.bolt_points(rng, x1, y1, x2, y2, segments, jitter)
    local points = { x1, y1 }
    for i = 1, segments - 1 do
        local t = i / segments
        points[#points + 1] = x1 + (x2 - x1) * t + rng:float(-jitter, jitter)
        points[#points + 1] = y1 + (y2 - y1) * t + rng:float(-jitter * 0.4, jitter * 0.4)
    end
    points[#points + 1] = x2
    points[#points + 1] = y2
    return points
end

function IntroBattle:_hurt(monster, amount)
    monster.hp = monster.hp - amount
    monster.flash = 0.12
    if monster.hp <= 0 and not monster.dead then
        monster.dead = true
        local color = ENEMIES.monsters[monster.kind].color
        self._fx:burst(monster.x, monster.y, { count = 22, colors = { color, { 1, 1, 1 } }, speed_max = 260, life_max = 0.6 })
        self._fx:ring(monster.x, monster.y, { 1, 0.9, 0.6 }, { from = 8, to = 70, life = 0.35 })
        Audio.play("monster_hit")
    end
end

function IntroBattle:update(dt, time)
    local spec = INTRO.monsters
    self._spawn = self._spawn - dt
    if time < INTRO.defense_spawn_stop and self._spawn <= 0 then
        self._spawn = spec.spawn_every
        self._monsters[#self._monsters + 1] = {
            kind = self._rng:pick(spec.kinds), x = INTRO.portal.x - 30, y = INTRO.ground_y - spec.size * 0.3 + self._rng:float(-14, 14),
            hp = spec.hp, flash = 0, phase = self._rng:float(0, 6),
        }
    end
    for i = #self._monsters, 1, -1 do
        local m = self._monsters[i]
        m.flash = math.max(0, m.flash - dt)
        m.phase = m.phase + dt
        if m.dead or m.x < INTRO.pawnshop.x + 120 then
            table.remove(self._monsters, i)
        else
            m.x = m.x - spec.speed * dt
        end
    end
    self:_update_weapons(dt)
    for i = #self._shots, 1, -1 do
        local shot = self._shots[i]
        local target = shot.target
        if target.dead then
            table.remove(self._shots, i)
        else
            local dx, dy = target.x - shot.x, target.y - shot.y
            local d = math.sqrt(dx * dx + dy * dy)
            if d < 18 then
                table.remove(self._shots, i)
                self._fx:burst(target.x, target.y, { count = 10, colors = FIRE, speed_max = 180, life_max = 0.4 })
                self:_hurt(target, 1)
            else
                local speed = INTRO.weapons.flame_sword.speed
                shot.x, shot.y = shot.x + dx / d * speed * dt, shot.y + dy / d * speed * dt
                self._fx:burst(shot.x, shot.y, { count = 1, colors = FIRE, speed_max = 40, life_max = 0.25, size_max = 4 })
            end
        end
    end
    for i = #self._beams, 1, -1 do
        self._beams[i].life = self._beams[i].life - dt
        if self._beams[i].life <= 0 then
            table.remove(self._beams, i)
        end
    end
end

function IntroBattle:_update_weapons(dt)
    for id, cfg in pairs(INTRO.weapons) do
        self._cooldowns[id] = self._cooldowns[id] - dt
        local target = nearest(self._monsters, cfg.x)
        if self._cooldowns[id] <= 0 and target ~= nil and target.x < INTRO.portal.x - 60 then
            self._cooldowns[id] = 1 / cfg.rate
            SpriteBank.kick(self._weapons[id])
            if id == "flame_sword" then
                self._shots[#self._shots + 1] = { x = cfg.x + 30, y = cfg.y - 10, target = target }
                Audio.play("shoot_bullet")
            else
                local chained = { target }
                local second = nil
                for _, m in ipairs(self._monsters) do
                    if not m.dead and m ~= target and (second == nil or math.abs(m.x - target.x) < math.abs(second.x - target.x)) then
                        second = m
                    end
                end
                chained[2] = second
                local fx, fy = cfg.x, cfg.y
                for _, m in ipairs(chained) do
                    self._beams[#self._beams + 1] = {
                        points = IntroBattle.bolt_points(self._rng, fx, fy, m.x, m.y, 7, 16), life = BEAM_LIFE,
                    }
                    fx, fy = m.x, m.y
                    self:_hurt(m, 1)
                end
                Audio.play("shoot_laser")
            end
        end
    end
end

local function draw_monster(m)
    local spec = INTRO.monsters
    local bob = math.sin(m.phase * 9) * 3
    local image = SpriteBank.image(m.kind)
    local art = image and ART.monsters[m.kind] or nil
    local color = m.flash > 0 and { 2, 2, 2 } or { 1, 1, 1 }
    Draw.set_color({ 0, 0, 0 }, 0.35)
    LG.ellipse("fill", m.x, m.y + spec.size * 0.35, spec.size * 0.35, 7, 16)
    if image ~= nil then
        SpriteBank.draw_fit(image, m.x, m.y + bob, spec.size * (art and art.scale or 1) * 0.75, { flip = art and art.flip, color = color })
    else
        MonsterShapes.draw(ENEMIES.monsters[m.kind].shape, m.x, m.y + bob, spec.size * 0.3, bob / 3, ENEMIES.monsters[m.kind].color)
    end
end

function IntroBattle:draw(time)
    for id, cfg in pairs(INTRO.weapons) do
        local glow = id == "flame_sword" and FIRE[1] or BOLT
        Draw.glow(cfg.x, cfg.y, cfg.size * 0.85, glow, 0.45 + 0.15 * math.sin(time * 5))
        ItemRenderer.draw(self._weapons[id], cfg.x, cfg.y + math.sin(time * 2 + cfg.y) * 6, cfg.size, { time = time, badges = false })
    end
    for _, m in ipairs(self._monsters) do
        draw_monster(m)
    end
    for _, shot in ipairs(self._shots) do
        Draw.set_color(FIRE[2])
        LG.circle("fill", shot.x, shot.y, 6, 12)
    end
    LG.setBlendMode("add")
    for _, beam in ipairs(self._beams) do
        local a = beam.life / BEAM_LIFE
        Draw.set_color(BOLT, 0.5 * a)
        LG.setLineWidth(7 * a + 1)
        LG.line(beam.points)
        Draw.set_color({ 1, 1, 1 }, a)
        LG.setLineWidth(2)
        LG.line(beam.points)
    end
    LG.setBlendMode("alpha")
end

return IntroBattle
