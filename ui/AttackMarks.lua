-- ui/AttackMarks.lua
-- ui/AttackEffects 의 짧은 표식: 무기 칸 정중앙 점화 플래시와 속성별 피격 이펙트(화염 고리 · 감전 스파크 고리 ·
-- 육각 서리 결정 · 흑백 잉크 베기 · 잉크 방울). 파티클은 넘겨받은 ui/Effects 로 뿌린다. 수치는 data/attacks.lua.

local Class = require("lib.classic")
local RNG = require("core.RNG")
local Draw = require("ui.Draw")
local ATTACKS = require("data.attacks")

local AttackMarks = Class:extend()

local LG = love.graphics
local STYLES = ATTACKS.styles
local INK = ATTACKS.ink

-- 종류의 대표 색
local function tone(style)
    local spec = STYLES[style]
    return spec.colors and spec.colors[1] or spec.core or spec.color
end

function AttackMarks:new(fx)
    self._fx = fx
    self._rng = RNG.stream("fx")
    self._marks = {}
end

function AttackMarks:_add(mark)
    mark.max_life = mark.life
    self._marks[#self._marks + 1] = mark
end

-- 점화 플래시: 칸 정중앙에서 발사 방향(dx, dy)으로 불꽃이 튄다
function AttackMarks:muzzle(style, x, y, dx, dy)
    local muzzle = ATTACKS.muzzle
    self:_add({ kind = "muzzle", style = style, x = x, y = y, life = muzzle.life })
    self._fx:burst(x + dx * 12, y + dy * 12, {
        count = muzzle.sparks, colors = { tone(style), { 1, 1, 1 } }, angle = math.atan2(dy, dx), spread = 0.45,
        speed_min = 140, speed_max = 340, life_max = 0.22, size_max = 3, shape = "spark",
    })
end

function AttackMarks:impact(style, x, y, radius)
    local spec = STYLES[style]
    local impact = spec.impact
    if style == "fire" then
        self._fx:burst(x, y, { count = impact.count, colors = spec.colors, speed_max = 260, life_max = 0.45, size_max = 5, gravity = -40 })
        self:_add({ kind = "ring", color = spec.colors[1], x = x, y = y, size = impact.ring, life = impact.life, width = 5 })
    elseif style == "lightning" then
        self:_add({ kind = "spark_ring", x = x, y = y, size = impact.ring, life = impact.life, spin = self._rng:float(0, 6) })
    elseif style == "frost" then
        self:_add({ kind = "hex", x = x, y = y, size = impact.radius, life = impact.life, spin = self._rng:float(0, 1) })
        self._fx:burst(x, y, { count = impact.shards, colors = { spec.color, spec.core }, speed_max = 200, life_max = 0.35,
            size_max = 3, shape = "square" })
    elseif style == "physical" then
        self:_add({ kind = "slash", x = x, y = y, size = impact.length, width = impact.width, life = impact.life,
            angle = self._rng:float(-1.0, -0.4) })
    else
        self._fx:burst(x, y, { count = impact.count, colors = spec.trail_colors, speed_max = 180, life_max = 0.5, size_max = 5,
            gravity = 120 })
        self:_add({ kind = "ring", color = spec.core, x = x, y = y, size = impact.ring, life = impact.life, width = 4 })
    end
end

function AttackMarks:update(dt)
    for i = #self._marks, 1, -1 do
        local mark = self._marks[i]
        mark.life = mark.life - dt
        if mark.life <= 0 then
            table.remove(self._marks, i)
        end
    end
end

local function draw_mark(mark)
    local t = mark.life / mark.max_life        -- 1 → 0
    local grow = 1 - t
    if mark.kind == "muzzle" then
        Draw.glow(mark.x, mark.y, ATTACKS.muzzle.radius * (0.6 + 0.6 * grow), tone(mark.style), 1.2 * t)
        LG.setBlendMode("add")
        Draw.set_color({ 1, 1, 1 }, t)
        LG.circle("fill", mark.x, mark.y, 6 * t + 2, 12)
        LG.setBlendMode("alpha")
    elseif mark.kind == "ring" then
        Draw.set_color(mark.color, t)
        LG.setLineWidth(mark.width * t + 1)
        LG.circle("line", mark.x, mark.y, 6 + mark.size * grow, 28)
    elseif mark.kind == "spark_ring" then
        local spec = STYLES.lightning
        LG.setBlendMode("add")
        Draw.set_color(spec.color, t)
        LG.setLineWidth(3 * t + 1)
        LG.circle("line", mark.x, mark.y, 6 + mark.size * grow, 24)
        Draw.set_color(spec.core, t)
        for i = 1, spec.impact.sparks do
            local a = mark.spin + i / spec.impact.sparks * math.pi * 2
            local r1, r2 = 4 + mark.size * grow * 0.6, 8 + mark.size * grow * 1.2
            LG.line(mark.x + math.cos(a) * r1, mark.y + math.sin(a) * r1, mark.x + math.cos(a + 0.3) * r2, mark.y + math.sin(a + 0.3) * r2)
        end
        LG.setBlendMode("alpha")
    elseif mark.kind == "hex" then
        local spec = STYLES.frost
        local points = {}
        for i = 0, 6 do
            local a = mark.spin + i / 6 * math.pi * 2
            local r = 6 + mark.size * grow
            points[#points + 1] = mark.x + math.cos(a) * r
            points[#points + 1] = mark.y + math.sin(a) * r
        end
        Draw.set_color(spec.color, 0.25 * t)
        LG.polygon("fill", points)
        Draw.set_color(spec.core, t)
        LG.setLineWidth(2.5 * t + 1)
        LG.line(points)
    elseif mark.kind == "slash" then
        local dx, dy = math.cos(mark.angle) * mark.size / 2, math.sin(mark.angle) * mark.size / 2
        local reach = 0.4 + 0.6 * math.min(1, grow * 3)
        for pass, color in ipairs({ INK, STYLES.physical.edge }) do
            Draw.set_color(color, t)
            LG.setLineWidth((pass == 1 and mark.width or mark.width * 0.35) * t + 1)
            LG.line(mark.x - dx * reach, mark.y - dy * reach, mark.x + dx * reach, mark.y + dy * reach)
            LG.line(mark.x - dy * 0.6 * reach, mark.y + dx * 0.6 * reach, mark.x + dy * 0.6 * reach, mark.y - dx * 0.6 * reach)
        end
    end
end

function AttackMarks:draw()
    for _, mark in ipairs(self._marks) do
        draw_mark(mark)
    end
end

return AttackMarks
