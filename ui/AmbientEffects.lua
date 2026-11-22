-- ui/AmbientEffects.lua
-- 화면 전체의 살아 있는 연출 루프 (수치 data/animations.lua 의 ambient). 규칙과 무관하다.
--   낮: 주인장 초상 반응(손님·감정·세척·강화 이벤트에 끄덕임·몸 기울임·들썩임·움찔) · 작업대/용광로 유물이 세척·강화 성공 때
--       공중으로 살짝 튀어 오르며 물방울·불꽃을 흩뿌린다 · 작업실에 은은한 금빛 먼지
--   밤: 진열장 유물의 칸별 위상이 다른 부유(levitation)와 발사 직전 충전(charge) 값 · 던전 포탈의 보라 마나 소용돌이 고리와 불티
-- 파티클은 넘겨받은 ui/Effects 로 뿌린다.

local Class = require("lib.classic")
local EventBus = require("core.EventBus")
local RNG = require("core.RNG")
local Viewport = require("core.Viewport")
local Draw = require("ui.Draw")
local ForgeDrama = require("ui.ForgeDrama")
local GuestReaction = require("ui.GuestReaction")
local ANIM = require("data.animations")
local LAYOUT = require("data.layout")

local AmbientEffects = Class:extend()

local LG = love.graphics
local AMBIENT = ANIM.ambient
local PORTRAIT, HOP = AMBIENT.portrait, AMBIENT.hop
local WATER = { { 0.55, 0.8, 1.0 }, { 0.85, 0.95, 1.0 } }
local SPARKS = { { 1.0, 0.75, 0.25 }, { 1.0, 0.95, 0.6 }, { 1.0, 0.45, 0.15 } }
local MANA = { { 0.72, 0.3, 0.95 }, { 0.95, 0.5, 1.0 }, { 1.0, 0.55, 0.2 } }

-- 주인장 반응 종류 (이벤트 → 동작)
local REACTIONS = {
    ["appraisal:customer_arrived"] = "nod", ["appraisal:grade_revealed"] = "lean", ["appraisal:flaw_revealed"] = "lean",
    ["appraisal:cleaned"] = "nod", ["appraisal:item_bought"] = "nod", ["appraisal:item_sold"] = "nod",
    ["forge:succeeded"] = "bounce", ["forge:failed"] = "recoil",
}

function AmbientEffects:new(fx)
    self._fx = fx
    self.forge_drama = ForgeDrama(fx)       -- 용광로 오버클럭(+2 · +3) 가열 → 대성공 / 파괴 연출
    self.guest = GuestReaction()            -- UV 결함·위조 적발 시 손님 모험가의 대사·움찔·꼬리표 강조
    self._rng = RNG.stream("fx")
    self._time = 0
    self._reaction = nil        -- { kind, t }
    self._hops = setmetatable({}, { __mode = "k" })
    self._embers = 0
    self._motes = {}
    local sw, sh = Viewport.width(), Viewport.height()
    for i = 1, AMBIENT.motes.count do
        self._motes[i] = { x = self._rng:float(0, sw), y = self._rng:float(70, sh), phase = self._rng:float(0, 6.28),
            speed = self._rng:float(0.4, 1.0) }
    end
    for event, kind in pairs(REACTIONS) do
        EventBus.subscribe(event, function(p) self:_react(kind, p, event) end, { owner = self, priority = -100 })
    end
end

function AmbientEffects:destroy()
    EventBus.unsubscribe_owner(self)
    self.forge_drama:destroy()
    self.guest:destroy()
end

-- 용광로 오버클럭 연출 (ui/ForgeDrama) — DayLayoutView 가 작업대 위에 그린다
function AmbientEffects:draw_forge(time)
    self.forge_drama:draw(time)
end

function AmbientEffects:_react(kind, p, event)
    self._reaction = { kind = kind, t = 0 }
    local hop = event == "appraisal:cleaned" or event == "forge:succeeded"
    if hop and p.item ~= nil then                              -- 유물이 튀어 오르며 물방울·불꽃을 흩뿌린다
        self._hops[p.item] = 0
        self._fx:burst(p.x, p.y, { count = 22, colors = event == "appraisal:cleaned" and WATER or SPARKS, speed_min = 80,
            speed_max = 260, angle = -math.pi / 2, spread = 1.3, gravity = 520, life_max = 0.8, size_max = 4 })
    end
end

-- 주인장 초상 포즈: rot, dx, dy
function AmbientEffects:portrait_pose()
    local reaction = self._reaction
    if reaction == nil then
        return 0, 0, 0
    end
    local t, decay = reaction.t, math.exp(-reaction.t * PORTRAIT.decay)
    if reaction.kind == "nod" then
        return 0, 0, PORTRAIT.bounce * 0.5 * math.max(0, math.sin(t * 14)) * decay
    elseif reaction.kind == "lean" then
        return -PORTRAIT.lean * math.min(1, t * 8) * decay, -PORTRAIT.recoil * 0.5 * decay, 0
    elseif reaction.kind == "bounce" then
        return PORTRAIT.nod * 0.3 * math.sin(t * 18) * decay, 0, -PORTRAIT.bounce * math.abs(math.sin(t * 12)) * decay
    end
    return PORTRAIT.lean * decay, PORTRAIT.recoil * decay, 0          -- recoil: 놀라 뒤로 움찔
end

-- 작업대·용광로 유물이 튀어 오른 높이 (px, 위로 음수)
function AmbientEffects:hop(item)
    local t = item and self._hops[item]
    if t == nil or t >= HOP.time then
        return 0
    end
    return -HOP.height * math.sin(t / HOP.time * math.pi)
end

-- 밤 진열장 칸별 부유 (px)
function AmbientEffects.levitation(index, time)
    local spec = AMBIENT.levitate
    return math.sin(time * spec.speed + index * spec.phase) * spec.height
end

-- 발사 직전 충전: charge(0~1) → 크기 배율, 빛 세기 (from 미만이면 1, 0)
function AmbientEffects.charge_pose(charge)
    local spec = AMBIENT.charge
    if charge < spec.from then
        return 1, 0
    end
    local k = (charge - spec.from) / (1 - spec.from)
    return 1 + spec.scale * k, spec.glow * k
end

function AmbientEffects:update(dt, phase)
    self._time = self._time + dt
    self.forge_drama:update(dt)
    self.guest:update(dt)
    if self._reaction ~= nil then
        self._reaction.t = self._reaction.t + dt
        if self._reaction.t > 1.5 then
            self._reaction = nil
        end
    end
    for item, t in pairs(self._hops) do
        self._hops[item] = t + dt
    end
    if phase == "night" then                                   -- 포탈에서 피어오르는 불티
        local portal, field = LAYOUT.night.portal, LAYOUT.night.field
        self._embers = self._embers + dt * AMBIENT.portal.embers_per_second
        while self._embers >= 1 do
            self._embers = self._embers - 1
            local a = self._rng:float(0, math.pi * 2)
            local cy = field.y + field.h / 2 - portal.size * 0.18
            self._fx:burst(portal.x + math.cos(a) * portal.size * 0.2, cy + math.sin(a) * portal.size * 0.3, {
                count = 1, colors = MANA, speed_min = 15, speed_max = 55, angle = -math.pi / 2, spread = 0.8,
                gravity = -50, drag = 0.5, life_min = 0.8, life_max = 1.6, size_max = 3,
            })
        end
    else
        local sw, sh = Viewport.width(), Viewport.height()
        for _, mote in ipairs(self._motes) do                -- 천천히 떠도는 금빛 먼지
            mote.y = mote.y - AMBIENT.motes.speed * mote.speed * dt
            mote.x = mote.x + math.sin(self._time * 0.6 + mote.phase) * 6 * dt
            if mote.y < 64 then
                mote.y, mote.x = sh, self._rng:float(0, sw)
            end
        end
    end
end

function AmbientEffects:draw_motes()
    local spec = AMBIENT.motes
    LG.setBlendMode("add")
    for _, mote in ipairs(self._motes) do
        Draw.set_color(spec.color, spec.alpha * (0.5 + 0.5 * math.sin(self._time * 1.3 + mote.phase)))
        LG.circle("fill", mote.x, mote.y, spec.size, 6)
    end
    LG.setBlendMode("alpha")
end

-- 포탈의 보라 마나 소용돌이: 안쪽으로 빨려 들며 도는 타원 고리
function AmbientEffects.draw_vortex(x, y, size, time)
    local spec = AMBIENT.portal
    LG.setBlendMode("add")
    for i = 1, spec.rings do
        local k = ((time * 0.35 + i / spec.rings) % 1)          -- 1 → 0 으로 줄어들며 사라진다
        local scale = 1 - k
        Draw.set_color(MANA[(i % 2) + 1], 0.35 * k)
        LG.setLineWidth(3 * k + 1)
        LG.push()
        LG.translate(x, y)
        LG.rotate(time * spec.spin * (i % 2 == 0 and 1 or -1) + i)
        LG.ellipse("line", 0, 0, size * 0.24 * scale + 4, size * 0.34 * scale + 6, 40)
        LG.pop()
    end
    LG.setBlendMode("alpha")
end

return AmbientEffects
