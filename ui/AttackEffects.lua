-- ui/AttackEffects.lua
-- 밤 전투 무기 공격 연출 (수치는 data/attacks.lua). 규칙 계산 없음 — Combat 의 projectiles / beams 를 읽고,
-- "combat:fired"(칸 정중앙 점화 플래시 + 발사 반대 방향 반동) · "combat:damage_dealt"(속성별 피격 이펙트)를 구독한다.
--   fire      : 초승달 화염 검기 / 불티 꼬리 화염탄 → 불꽃 파편 + 화염 고리
--   lightning : 여러 갈래 지그재그 전격 아크(매 프레임 새로 갈라진다) → 감전 스파크 고리
--   frost     : 고드름 창 / 얼음 광선 → 육각 서리 결정 파동
--   physical  : 회전하는 강철 도끼날 → 흑백 잉크 베기
--   curse     : 일렁이는 심연 구체 + 검은 잉크 궤적 → 잉크 방울
-- 진열장·레인보다 위에 그린다 (투사체가 칸 정중앙에서 바로 보이도록).

local Class = require("lib.classic")
local EventBus = require("core.EventBus")
local RNG = require("core.RNG")
local Draw = require("ui.Draw")
local SpriteBank = require("ui.SpriteBank")
local AttackMarks = require("ui.AttackMarks")
local ATTACKS = require("data.attacks")

local AttackEffects = Class:extend()

local LG = love.graphics
local STYLES = ATTACKS.styles
local INK = ATTACKS.ink

-- 유물의 공격 연출 종류
function AttackEffects.style(item)
    if item == nil then
        return "lightning"
    end
    local proto = item.proto
    if proto.attack_style ~= nil then
        return proto.attack_style
    end
    local kind = proto.damage_type or "physical"
    if kind == "physical" and proto.archetype == "curse" then
        return "curse"
    end
    return STYLES[kind] and kind or "physical"
end

function AttackEffects:new(fx)
    self._fx = fx
    self._rng = RNG.stream("fx")
    self._marks = AttackMarks(fx)
    self._time = 0
    EventBus.subscribe("combat:fired", function(p) self:_on_fired(p) end, { owner = self, priority = -100 })
    EventBus.subscribe("combat:splash", function(p)          -- 화염 스플래시: 퍼지는 충격 고리 두 겹 + 불티 파편
        local splash = ATTACKS.splash
        fx:ring(p.x, p.y, splash.colors[1], { from = 6, to = p.radius, life = splash.life, width = 6 })
        fx:ring(p.x, p.y, splash.colors[3], { from = 2, to = p.radius * 0.7, life = splash.life * 0.8, width = 3 })
        fx:burst(p.x, p.y, { count = splash.embers, colors = splash.colors, speed_min = 80, speed_max = 260, gravity = -90,
            life_max = 0.55, size_max = 4, shape = "spark" })
    end, { owner = self, priority = -100 })
    EventBus.subscribe("combat:damage_dealt", function(p)
        if p.item ~= nil then
            self._marks:impact(AttackEffects.style(p.item), p.x, p.y, p.monster.radius)
        end
    end, { owner = self, priority = -100 })
end

function AttackEffects:destroy()
    EventBus.unsubscribe_owner(self)
end

-- 칸 정중앙 점화 플래시 + 발사 반대 방향 반동
function AttackEffects:_on_fired(p)
    local dx, dy = (p.tx or p.x) - p.x, (p.ty or p.y - 1) - p.y
    local length = math.max(1e-3, math.sqrt(dx * dx + dy * dy))
    dx, dy = dx / length, dy / length
    SpriteBank.kick(p.item, ATTACKS.recoil, -dx, -dy)
    self._marks:muzzle(AttackEffects.style(p.item), p.x, p.y, dx, dy)
end

function AttackEffects:update(dt, combat)
    self._time = self._time + dt
    self._marks:update(dt)
    for _, shot in ipairs(combat.projectiles) do          -- 화염탄 불티 · 심연 구체 잉크 궤적
        local style = AttackEffects.style(shot.item)
        local spec = STYLES[style]
        if spec.trail_per_second ~= nil and self._rng:chance(math.min(1, spec.trail_per_second * dt)) then
            self._fx:burst(shot.x, shot.y, {
                count = 1, colors = spec.trail_colors or spec.colors, speed_max = 30, life_max = 0.45, size_max = 4,
                gravity = style == "fire" and -60 or 20,
            })
        end
    end
end

local function zigzag(rng, x1, y1, x2, y2, segments, jitter)
    local points = { x1, y1 }
    local dx, dy = x2 - x1, y2 - y1
    local length = math.max(1, math.sqrt(dx * dx + dy * dy))
    local nx, ny = -dy / length, dx / length
    for i = 1, segments - 1 do
        local t, offset = i / segments, rng:float(-jitter, jitter)
        points[#points + 1] = x1 + dx * t + nx * offset
        points[#points + 1] = y1 + dy * t + ny * offset
    end
    points[#points + 1] = x2
    points[#points + 1] = y2
    return points
end

function AttackEffects:_draw_beam(beam)
    local t = beam.life / beam.max_life
    local style = beam.item and AttackEffects.style(beam.item) or "lightning"
    LG.setBlendMode("add")
    if style == "frost" then                               -- 얼음 광선: 곧은 빛 + 하얀 심
        local spec = STYLES.frost
        Draw.set_color(spec.color, 0.45 * t)
        LG.setLineWidth(12 * t + 2)
        LG.line(beam.x1, beam.y1, beam.x2, beam.y2)
        Draw.set_color(spec.core, t)
        LG.setLineWidth(3)
        LG.line(beam.x1, beam.y1, beam.x2, beam.y2)
    else                                                   -- 전격 아크: 여러 갈래 지그재그 (매 프레임 다시 갈라진다)
        local spec = STYLES.lightning
        for strand = 1, spec.strands do
            local points = zigzag(self._rng, beam.x1, beam.y1, beam.x2, beam.y2, spec.segments, spec.jitter * (strand == 1 and 0.6 or 1))
            Draw.set_color(beam.item and spec.color or beam.color, (strand == 1 and 0.55 or 0.25) * t)
            LG.setLineWidth((strand == 1 and 9 or 4) * t + 1)
            LG.line(points)
            if strand == 1 then
                Draw.set_color(spec.core, t)
                LG.setLineWidth(2)
                LG.line(points)
            end
        end
    end
    LG.setBlendMode("alpha")
end

-- 투사체 한 발: 진행 방향으로 돌려 종류별 모양을 그린다
function AttackEffects:_draw_shot(shot)
    local style = AttackEffects.style(shot.item)
    local spec = STYLES[style]
    local angle = math.atan2(shot.vy, shot.vx)
    LG.push()
    LG.translate(shot.x, shot.y)
    if style == "fire" then
        local crescent = spec.crescent_shapes[shot.item.proto.shape]
        LG.rotate(angle)
        Draw.glow(0, 0, crescent and spec.crescent_radius * 1.8 or spec.ball_radius * 2.4, spec.colors[1], 0.8)
        if crescent then
            for i, color in ipairs({ spec.colors[3], spec.colors[1], spec.colors[2] }) do
                Draw.set_color(color)
                LG.setLineWidth(8 - i * 2)
                LG.arc("line", "open", -spec.crescent_radius * 0.6, 0, spec.crescent_radius, -1.2, 1.2, 16)
            end
        else
            Draw.set_color(spec.colors[1])
            LG.circle("fill", 0, 0, spec.ball_radius, 14)
            Draw.set_color(spec.colors[2])
            LG.circle("fill", 2, 0, spec.ball_radius * 0.55, 12)
        end
    elseif style == "frost" then
        local l, w = spec.shard_length, spec.shard_width
        LG.rotate(angle)
        Draw.set_color(INK)
        LG.polygon("fill", l + 3, 0, 0, w + 3, -l * 0.7 - 3, 0, 0, -w - 3)
        Draw.set_color(spec.color)
        LG.polygon("fill", l, 0, 0, w, -l * 0.7, 0, 0, -w)
        Draw.set_color(spec.core)
        LG.setLineWidth(1.5)
        LG.line(-l * 0.5, 0, l * 0.8, 0)
    elseif style == "curse" then
        local wobble = 1 + 0.18 * math.sin(self._time * 14 + shot.x * 0.05)
        Draw.glow(0, 0, spec.radius * 2.6, spec.core, 0.6)
        Draw.set_color(INK)
        LG.circle("fill", 0, 0, spec.radius * wobble + 2, 16)
        Draw.set_color(spec.color)
        LG.circle("fill", 0, 0, spec.radius * wobble, 16)
        Draw.set_color(spec.core)
        LG.circle("fill", 1, -1, spec.radius * 0.4, 10)
    else                                                   -- physical: 회전하는 강철 도끼날
        local r = spec.blade_radius
        LG.rotate(self._time * spec.spin)
        for _, side in ipairs({ 1, -1 }) do
            Draw.set_color(INK)
            LG.polygon("fill", 0, 0, side * (r + 3), -r * 0.8 - 3, side * (r + 3), r * 0.8 + 3)
            Draw.set_color(spec.color)
            LG.polygon("fill", 0, 0, side * r, -r * 0.8, side * r, r * 0.8)
            Draw.set_color(spec.edge)
            LG.setLineWidth(2)
            LG.line(side * r, -r * 0.8, side * r, r * 0.8)
        end
        Draw.set_color(INK)
        LG.circle("fill", 0, 0, 4, 10)
    end
    LG.pop()
end

function AttackEffects:draw(combat)
    for _, beam in ipairs(combat.beams) do
        self:_draw_beam(beam)
    end
    for _, shot in ipairs(combat.projectiles) do
        self:_draw_shot(shot)
    end
    self._marks:draw()
end

return AttackEffects
