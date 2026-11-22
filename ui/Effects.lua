-- ui/Effects.lua
-- 손맛 연출 엔진: 화면 흔들림(trauma), 파티클, 확산 링, 떠오르는 텍스트, 화면/영역 플래시.
-- 게임 규칙과 무관하다. 무엇을 언제 보여줄지는 ui/Feedback.lua 가 결정한다.
-- 화면 흔들림은 환경 설정의 강도(100% / 50% / 끄기)를 곱해 적용한다.

local Class = require("lib.classic")
local RNG = require("core.RNG")
local Viewport = require("core.Viewport")
local Settings = require("systems.Settings")
local Draw = require("ui.Draw")
local UI = require("data.ui")

local Effects = Class:extend()

local INK = { 0.02, 0.015, 0.02 }
-- 굵은 검은 외곽선 (crit · shock 글자): 8 방향 2px
local OUTLINE = { { -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 }, { -2, -2 }, { 2, -2 }, { -2, 2 }, { 2, 2 } }

function Effects:new()
    self._rng = RNG.stream("fx")
    self._particles = {}
    self._rings = {}
    self._texts = {}
    self._rect_flashes = {}
    self._flash = { color = { 1, 1, 1 }, alpha = 0, decay = 1 }
    self._trauma = 0
    self.offset_x, self.offset_y = 0, 0
end

-- amount: 0~1 누적 (제곱으로 체감 강도 결정)
function Effects:shake(amount)
    self._trauma = math.min(1, self._trauma + amount)
end

-- opts: count, color | colors, speed_min/max, life_min/max, size_min/max, gravity, drag, angle, spread, shape
function Effects:burst(x, y, opts)
    local rng = self._rng
    local limit = UI.fx.max_particles
    local spread = opts.spread or math.pi
    for _ = 1, opts.count or 12 do
        if #self._particles >= limit then
            break
        end
        local angle = (opts.angle or 0) + rng:float(-spread, spread)
        local speed = rng:float(opts.speed_min or 60, opts.speed_max or 220)
        local life = rng:float(opts.life_min or 0.35, opts.life_max or 0.8)
        local color = opts.colors and rng:pick(opts.colors) or opts.color or { 1, 1, 1 }
        self._particles[#self._particles + 1] = {
            x = x, y = y,
            vx = math.cos(angle) * speed, vy = math.sin(angle) * speed,
            life = life, max_life = life,
            size = rng:float(opts.size_min or 2, opts.size_max or 5),
            color = color, gravity = opts.gravity or 0, drag = opts.drag or 2.5,
            shape = opts.shape or "circle",
        }
    end
end

-- 확산 링: opts: from, to, life, width
function Effects:ring(x, y, color, opts)
    opts = opts or {}
    local life = opts.life or 0.45
    self._rings[#self._rings + 1] = {
        x = x, y = y, color = color, from = opts.from or 8, to = opts.to or 60,
        life = life, max_life = life, width = opts.width or 3,
    }
end

-- 떠오르는 텍스트: opts: size, life, rise
function Effects:float_text(x, y, text, color, opts)
    opts = opts or {}
    local life = opts.life or UI.fx.float_life
    self._texts[#self._texts + 1] = {
        x = x, y = y, text = text, color = color, size = opts.size or UI.font_size.body,
        life = life, max_life = life, rise = opts.rise or UI.fx.float_rise, style = opts.style,
    }
end

-- 화면 전체 플래시
function Effects:flash(color, alpha, duration)
    if alpha >= self._flash.alpha then
        self._flash.color = color
        self._flash.alpha = alpha
        self._flash.decay = alpha / math.max(duration, 0.01)
    end
end

-- 영역 플래시 (방벽 피격 등)
function Effects:flash_rect(x, y, w, h, color, duration)
    self._rect_flashes[#self._rect_flashes + 1] = { x = x, y = y, w = w, h = h, color = color, life = duration, max_life = duration }
end

local function age(list, dt)
    for i = #list, 1, -1 do
        local entry = list[i]
        entry.life = entry.life - dt
        if entry.life <= 0 then
            list[i] = list[#list]
            list[#list] = nil
        end
    end
end

function Effects:update(dt)
    for _, p in ipairs(self._particles) do
        local damping = math.max(0, 1 - p.drag * dt)
        p.vx = p.vx * damping
        p.vy = p.vy * damping + p.gravity * dt
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
    end
    age(self._particles, dt)
    age(self._rings, dt)
    age(self._texts, dt)
    age(self._rect_flashes, dt)

    self._flash.alpha = math.max(0, self._flash.alpha - self._flash.decay * dt)
    self._trauma = math.max(0, self._trauma - UI.fx.shake_decay * dt)
    local power = self._trauma * self._trauma * UI.fx.max_shake * Settings.get("shake")
    self.offset_x = power * self._rng:float(-1, 1)
    self.offset_y = power * self._rng:float(-1, 1)
end

function Effects:push_shake()
    love.graphics.push()
    love.graphics.translate(self.offset_x, self.offset_y)
end

function Effects:pop_shake()
    love.graphics.pop()
end

-- 떠오르는 글자. style: nil(그림자) | "crit"(굵은 검은 외곽선 + 크게 튀었다 자리 잡는 바운스)
--                      | "shock"(외곽선 + 지직거리는 떨림)
local function draw_text(text)
    local t = 1 - text.life / text.max_life
    local alpha = math.min(1, (1 - t) * 2.2)
    local pop, dx, dy = 1 + 0.35 * math.max(0, 1 - t * 6), 0, 0
    if text.style == "crit" then
        pop = 1 + 0.75 * math.exp(-t * 9) * math.cos(t * 24)
    elseif text.style == "shock" and t < 0.7 then
        dx, dy = math.sin(text.life * 97) * 2.4, math.cos(text.life * 71) * 1.6
    end
    love.graphics.push()
    love.graphics.translate(text.x + dx, text.y + dy - text.rise * (1 - (1 - t) * (1 - t)))
    love.graphics.scale(pop)
    local height = Draw.font(text.size):getHeight()
    if text.style ~= nil then
        for _, o in ipairs(OUTLINE) do
            Draw.text(text.text, -200 + o[1], -height / 2 + o[2], 400, "center", text.size, INK, alpha)
        end
        Draw.text(text.text, -200, -height / 2, 400, "center", text.size, text.color, alpha)
    else
        Draw.shadow_text(text.text, -200, -height / 2, 400, "center", text.size, text.color, alpha)
    end
    love.graphics.pop()
end

function Effects:draw()
    for _, f in ipairs(self._rect_flashes) do
        Draw.set_color(f.color, f.life / f.max_life * 0.7)
        love.graphics.rectangle("fill", f.x, f.y, f.w, f.h)
    end
    for _, p in ipairs(self._particles) do
        local t = p.life / p.max_life
        Draw.set_color(p.color, t)
        local size = p.size * (0.4 + 0.6 * t)
        if p.shape == "square" then
            love.graphics.rectangle("fill", p.x - size / 2, p.y - size / 2, size, size)
        elseif p.shape == "spark" then
            love.graphics.setLineWidth(math.max(1, size * 0.5))
            love.graphics.line(p.x, p.y, p.x - p.vx * 0.04, p.y - p.vy * 0.04)
        else
            love.graphics.circle("fill", p.x, p.y, size, 10)
        end
    end
    for _, r in ipairs(self._rings) do
        local t = 1 - r.life / r.max_life
        local eased = 1 - (1 - t) * (1 - t)
        Draw.set_color(r.color, 1 - t)
        love.graphics.setLineWidth(r.width * (1 - t) + 0.5)
        love.graphics.circle("line", r.x, r.y, r.from + (r.to - r.from) * eased, 40)
    end
    for _, text in ipairs(self._texts) do
        draw_text(text)
    end
end

-- 흔들림과 무관한 화면 전체 플래시 (가장 마지막에 그린다)
function Effects:draw_flash()
    if self._flash.alpha > 0 then
        Draw.set_color(self._flash.color, self._flash.alpha)
        love.graphics.rectangle("fill", 0, 0, Viewport.width(), Viewport.height())
    end
end

function Effects:particle_count()
    return #self._particles
end

return Effects
