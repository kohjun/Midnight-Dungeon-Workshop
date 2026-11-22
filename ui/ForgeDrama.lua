-- ui/ForgeDrama.lua
-- 용광로 위험 강화(+2 ~ +10, 연마석) 극적 연출. 규칙 계산 없음 — Forge 가 발행한 이벤트(payload.overclock · outcome)만 본다.
--   가열(forge:started, 0.42초): 용광로 칸 위로 붉은 → 황금빛 맥동이 빨라지며 불티가 솟는다 (소리 forge_heat — systems/Audio)
--   대성공(forge:succeeded): 눈부신 황금 섬광 · 방사형 불꽃 충격파 고리 · 위로 솟는 불티 + 작업대 위 금빛 배너
--                           + "내구도 100% 복구!" (+10 이면 "+10 불멸 각인!") 짧은 줄
--                           (유물 튀어 오름은 ui/AmbientEffects, +5 이상 포일은 ui/Foil 이 바로 입힌다)
--   유지·하락(forge:failed, outcome keep/down): 회색 연기 · 식은 쇳가루 · 둔탁한 쇳소리(forge_dud) + 회색 배너
--   파괴(forge:failed, outcome destroyed): 유물 위로 번쩍이며 갈라지는 붉은 균열 · 강한 화면 흔들림 · 검붉은 파편과 재 · 파쇄음
-- ui/AmbientEffects 가 소유하고, ui/DayLayoutView 가 작업대 위에 그린다.

local Class = require("lib.classic")
local EventBus = require("core.EventBus")
local I18n = require("systems.I18n")
local Draw = require("ui.Draw")
local Lettering = require("ui.Lettering")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local ForgeDrama = Class:extend()

local C = UI.color
local LG = love.graphics
local DAY = LAYOUT.day
local HEAT_FROM, HEAT_TO = { 0.85, 0.12, 0.06 }, { 1.0, 0.78, 0.25 }
local SHARDS = { { 0.35, 0.05, 0.05 }, { 0.6, 0.1, 0.08 }, { 0.12, 0.1, 0.1 }, { 0.3, 0.28, 0.28 } }
local SPARKS = { C.gold, { 1, 1, 1 }, { 1.0, 0.6, 0.15 } }
local SMOKE = { { 0.42, 0.40, 0.42 }, { 0.58, 0.56, 0.56 }, { 0.30, 0.29, 0.31 } }
local DUD_BORDER = { 0.62, 0.62, 0.66 }
local BANNER_TIME = 1.7
local CRACK_TIME = 1.2
local CRACKS = 9

function ForgeDrama:new(fx)
    self._fx = fx
    self.state = nil        -- { phase = "heat" | "success" | "shatter", t, duration, level }
    self._ember_timer = 0
    local function on(event, fn)
        EventBus.subscribe(event, function(p)
            if p.overclock then
                fn(p)
            end
        end, { owner = self, priority = -100 })
    end
    on("forge:started", function(p)
        self.state = { phase = "heat", t = 0, duration = p.duration or 0.42, x = p.x, y = p.y }
    end)
    on("forge:succeeded", function(p)
        self.state = { phase = "success", t = 0, duration = BANNER_TIME, level = p.level, x = p.x, y = p.y, immortal = p.immortal }
        fx:flash(C.gold, 0.6, 0.55)
        fx:shake(0.7)
        for i, radius in ipairs({ 260, 180, 110 }) do
            fx:ring(p.x, p.y, i == 2 and { 1, 1, 1 } or C.gold, { from = 12, to = radius, life = 0.5 + i * 0.12, width = 9 - i * 2 })
        end
        fx:burst(p.x, p.y, { count = 90, colors = SPARKS, speed_min = 180, speed_max = 620, shape = "spark", life_max = 1.1 })
    end)
    on("forge:failed", function(p)
        if p.outcome ~= "destroyed" then           -- 유지 · 하락: 회색 연기와 둔탁한 쇳소리
            self.state = { phase = "dud", t = 0, duration = BANNER_TIME, x = p.x, y = p.y, from = p.from, level = p.level,
                outcome = p.outcome }
            fx:shake(0.25)
            fx:burst(p.x, p.y - 10, { count = 34, colors = SMOKE, speed_max = 120, angle = -math.pi / 2, spread = 1.2, gravity = -60,
                life_max = 1.5, size_min = 4, size_max = 11, drag = 1.4 })
            fx:burst(p.x, p.y + 10, { count = 12, colors = SMOKE, speed_max = 170, gravity = 420, shape = "square", size_max = 4,
                life_max = 0.8 })
            return
        end
        self.state = { phase = "shatter", t = 0, duration = CRACK_TIME, x = p.x, y = p.y }
        fx:shake(1.0)
        fx:flash({ 0.55, 0.05, 0.05 }, 0.55, 0.5)
        fx:burst(p.x, p.y, { count = 70, colors = SHARDS, speed_min = 140, speed_max = 560, gravity = 520, shape = "square",
            life_min = 0.6, life_max = 1.3, size_min = 3, size_max = 9 })
        fx:burst(p.x, p.y - 20, { count = 40, color = { 0.25, 0.23, 0.23 }, speed_max = 120, gravity = -40, life_max = 1.6,
            size_max = 6, drag = 1.2 })
    end)
end

function ForgeDrama:destroy()
    EventBus.unsubscribe_owner(self)
end

function ForgeDrama:update(dt)
    local state = self.state
    if state == nil then
        return
    end
    state.t = state.t + dt
    if state.phase == "heat" then          -- 가열 중 솟는 불티 (점점 잦아진다)
        self._ember_timer = self._ember_timer - dt
        if self._ember_timer <= 0 then
            self._ember_timer = 0.09 - 0.05 * math.min(1, state.t / state.duration)
            self._fx:burst(state.x, state.y + 20, { count = 3, colors = { HEAT_FROM, HEAT_TO }, speed_max = 160, angle = -math.pi / 2,
                spread = 0.5, gravity = -120, life_max = 0.5, size_max = 3 })
        end
    end
    if state.t >= state.duration + (state.phase == "heat" and 0.6 or 0) then
        self.state = nil
    end
end

local function draw_heat(state, time)
    local p = math.min(1, state.t / state.duration)
    local pulse = 0.5 + 0.5 * math.sin(time * (14 + 40 * p))
    local slot = DAY.furnace_slot
    local color = Draw.lerp_color(HEAT_FROM, HEAT_TO, p)
    LG.setBlendMode("add")
    Draw.set_color(color, (0.25 + 0.45 * p) * (0.6 + 0.4 * pulse))
    LG.rectangle("fill", slot.x - 6, slot.y - 6, slot.w + 12, slot.h + 12, 14, 14)
    Draw.glow(state.x, state.y, slot.w * (0.7 + 0.5 * p), color, 0.6 + 0.4 * pulse)
    LG.setBlendMode("alpha")
end

local function draw_cracks(state)
    local fade = math.max(0, 1 - state.t / 0.75)        -- 균열은 0.75초 안에 사라지고 배너만 남는다
    local flicker = (math.floor(state.t * 30) % 2 == 0) and 1 or 0.55
    LG.setLineWidth(3)
    for i = 1, CRACKS do
        local angle = i / CRACKS * math.pi * 2 + 0.4
        local length = 40 + (i % 3) * 18
        local x, y = state.x, state.y
        local mx, my = x + math.cos(angle) * length * 0.5 + math.sin(i * 7) * 8, y + math.sin(angle) * length * 0.5
        Draw.set_color({ 1.0, 0.18, 0.12 }, fade * flicker)
        LG.line(x, y, mx, my, x + math.cos(angle) * length, y + math.sin(angle) * length)
    end
end

-- 작업대 위 배너: 대성공 = 금빛 "강화 성공! +N" (+ 아래 내구도 복구 줄) / 유지·하락 = 회색 / 파괴 = 핏빛 "파괴!"
local function draw_banner(state, key, style, border, vars, subline)
    local t = state.t
    local alpha = math.min(1, t * 6) * math.min(1, (state.duration - t) * 3)
    local scale = 1 + 0.35 * math.exp(-t * 8) * math.cos(t * 20)
    local area = DAY.workbench
    local cx, cy = area.x + area.w / 2, DAY.bench_slot.y + 40
    Draw.set_color({ 0.05, 0.03, 0.01 }, 0.72 * alpha)
    LG.rectangle("fill", area.x + 40, cy - 34, area.w - 80, 68, 10, 10)
    Draw.set_color(border, alpha)
    LG.setLineWidth(2)
    LG.rectangle("line", area.x + 40, cy - 34, area.w - 80, 68, 10, 10)
    LG.push()
    LG.translate(cx, cy)
    LG.scale(scale)
    Lettering.draw(I18n.t(key, vars or { level = state.level }), -area.w / 2, -24, area.w, "center", "title", style, alpha)
    LG.pop()
    if subline ~= nil then
        Draw.set_color({ 0.03, 0.02, 0.02 }, 0.8 * alpha)
        LG.rectangle("fill", cx - 150, cy + 38, 300, 26, 8, 8)
        Draw.label_text(subline, cx - 150, cy + 42, 300, "center", "button", C.link_boost, alpha)
    end
end

-- 작업대 위에 그린다 (DayLayoutView)
function ForgeDrama:draw(time)
    local state = self.state
    if state == nil then
        return
    end
    if state.phase == "heat" then
        draw_heat(state, time)
    elseif state.phase == "shatter" then
        draw_cracks(state)
        draw_banner(state, "forge_fx.overclock_shatter", "blood", C.danger)
    elseif state.phase == "dud" then
        draw_banner(state, "forge_fx." .. state.outcome, "silver", DUD_BORDER, { from = state.from, level = state.level })
    elseif state.phase == "success" then
        draw_banner(state, "forge_fx.overclock_success", "gold", C.gold, nil,
            I18n.t(state.immortal and "forge_fx.immortal" or "forge_fx.restored"))
    end
end

return ForgeDrama
