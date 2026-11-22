-- ui/EndingScenesTrace.lua
-- '스승의 흔적' 캠페인 엔딩 장면 (ui/EndingScenes 가 data/endings.lua 의 campaign 엔딩일 때 맡긴다):
--   true_dawn      : 새벽의 완전 봉인
--                    일러스트(ending_true.png — 정사각형도 KenBurns 가 화면을 덮게 자른다) 위에 해의 빛무리 · 빛살 ·
--                    은청색으로 은은히 숨 쉬는 봉인 룬석 · 떠오르는 따뜻한 새벽 먼지
--                    → 일러스트가 없으면 대체 그림(fallback — 낮 공방)에 황금빛 새벽 필터(fallback.tint · tint_alpha) + 창문 빛살
--                    → 그것도 없으면 코드 연출: 해돋이 하늘 · 먼 산 · 공방 실루엣 · 균열을 꿰매 닫은 룬석 다섯
--   new_gatekeeper : 새로운 문지기 — 코드 연출 (ui/EndingSceneGate)
-- opts = { id, spec, fx, rng, kind ("illustration" | "fallback" | nil), illustrate = function(time, overlay) }
--   illustrate: EndingScenes 의 일러스트 그리기 (그림 → overlay(to_screen) → 아래쪽 그늘). to_screen(u, v) = 그림 안 위치 → 화면

local Class = require("lib.classic")
local Viewport = require("core.Viewport")
local Draw = require("ui.Draw")
local RuneArt = require("ui.RuneArt")
local Kit = require("ui.EndingSceneKit")
local EndingSceneGate = require("ui.EndingSceneGate")

local EndingScenesTrace = Class:extend()

local LG = love.graphics
local GROUND_Y = 560
local WARM = { 1.0, 0.80, 0.50 }
local SUN = { 1.0, 0.93, 0.70 }
local SEAL_BLUE = { 0.66, 0.84, 1.0 }
local SEAL_CORE = { 0.42, 0.72, 1.0 }          -- 일러스트 룬석의 룬 빛 (주황빛 돌 위에서도 차갑게 보이도록 짙은 청색)
local DAWN_MOTES = { { 1.0, 0.86, 0.55 }, { 1.0, 0.95, 0.78 }, { 1.0, 0.72, 0.42 } }
local MOTE_RATE = 9                                         -- 초당 새벽 먼지
local ART_SUN = { 0.152, 0.565 }                            -- ending_true.png 안 해 (정규화)
local ART_STONES = { { 0.85, 0.386 }, { 0.77, 0.475 }, { 0.77, 0.526 }, { 0.938, 0.486 }, { 0.94, 0.535 } }   -- 룬석의 룬
local FALLBACK_WINDOW = { 0.222, 0.16 }                     -- 대체 그림(낮 공방) 안 창문
local FALLBACK_GRADE = { 1.0, 0.86, 0.62 }                  -- 대체 그림을 따뜻하게 물들이는 곱하기 색
-- 코드 연출의 룬석: x(화면 폭 비율) · 높이 · 폭 · 새긴 룬
local STONES = { { 0.70, 104, 44, 16 }, { 0.755, 146, 52, 10 }, { 0.815, 184, 60, 13 }, { 0.878, 156, 54, 11 }, { 0.935, 124, 48, 15 } }
local STONE_FACE, STONE_EDGE, CLIFF = { 0.36, 0.28, 0.27 }, { 0.62, 0.50, 0.44 }, { 0.20, 0.13, 0.14 }

function EndingScenesTrace:new(opts)
    self.id = opts.id
    self._spec = opts.spec
    self._fx = opts.fx
    self._rng = opts.rng
    self._kind = opts.kind
    self._illustrate = opts.illustrate
    self._spawn = 0
    if self.id == "new_gatekeeper" then
        self._gate = EndingSceneGate(self._rng)
    else
        self._far = Kit.ridge(self._rng, GROUND_Y - 150, 100, 70)
        self._near = Kit.ridge(self._rng, GROUND_Y - 50, 60, 60)
    end
end

function EndingScenesTrace:update(dt, time)
    if self._gate ~= nil then
        self._gate:update(dt, time, self._fx)
        return
    end
    local sw, sh = Viewport.width(), Viewport.height()
    self._spawn = self._spawn - dt
    while self._spawn <= 0 do                                -- 떠오르는 따뜻한 새벽 먼지
        self._spawn = self._spawn + 1 / MOTE_RATE
        self._fx:burst(self._rng:float(0, sw), self._rng:float(sh * 0.3, sh * 0.95), { count = 1, colors = DAWN_MOTES,
            speed_min = 8, speed_max = 26, angle = -math.pi / 2, spread = 0.8, life_min = 1.8, life_max = 3.6,
            size_min = 1.2, size_max = 2.8, drag = 0.3, gravity = -5 })
    end
end

-- 일러스트 위: 해의 빛무리와 빛살 · 은청색으로 숨 쉬는 봉인 룬석
function EndingScenesTrace:_dawn_overlay(time, to_screen)
    local left = to_screen(0, 0)
    local unit = to_screen(1, 0) - left                     -- 그림 폭 (화면 픽셀)
    local sx, sy = to_screen(ART_SUN[1], ART_SUN[2])
    Kit.rays(sx, sy, WARM, 0.05, time, { count = 9, from = -1.15, to = 0.3, length = 1600, width = 0.03 })
    Kit.glow(sx, sy, unit * 0.17 * (1 + 0.04 * math.sin(time * 0.8)), WARM, 0.6)
    for i, stone in ipairs(ART_STONES) do                    -- 봉인 룬이 은청색으로 숨 쉰다
        local x, y = to_screen(stone[1], stone[2])
        local breath = 0.5 + 0.5 * math.sin(time * 1.3 + i * 1.4)
        Kit.glow(x, y, unit * 0.05, SEAL_CORE, 0.36 + 0.26 * breath)
        Kit.glow(x, y, unit * 0.016, SEAL_BLUE, 0.25 + 0.2 * breath)
    end
end

-- 대체 그림 위: 황금빛 새벽 필터 (곱하기로 물들이고 · 더하기로 그늘을 들어 올리고 · 금빛 안개) + 창문 빛살
function EndingScenesTrace:_fallback_overlay(time, to_screen)
    local fallback = self._spec.fallback
    local sw, sh = Viewport.width(), Viewport.height()
    LG.setBlendMode("multiply", "premultiplied")
    LG.setColor(FALLBACK_GRADE[1], FALLBACK_GRADE[2], FALLBACK_GRADE[3], 1)
    LG.rectangle("fill", 0, 0, sw, sh)
    LG.setBlendMode("add")
    Draw.set_color(fallback.tint, fallback.tint_alpha * 0.45)
    LG.rectangle("fill", 0, 0, sw, sh)
    LG.setBlendMode("alpha")
    Draw.set_color(fallback.tint, fallback.tint_alpha * 0.3)
    LG.rectangle("fill", 0, 0, sw, sh)
    local wx, wy = to_screen(FALLBACK_WINDOW[1], FALLBACK_WINDOW[2])
    Kit.rays(wx, wy, WARM, 0.08, time, { count = 6, from = 0.7, to = 1.25, length = 1000, width = 0.05 })
    Kit.glow(wx, wy, 280, WARM, 0.7 + 0.1 * math.sin(time))
end

-- 균열을 꿰매 닫은 절벽과 룬석 다섯 (룬이 은청색으로 숨 쉰다)
function EndingScenesTrace:_draw_stones(time)
    local sw = Viewport.width()
    local cliff_x = sw * 0.66
    Draw.set_color(CLIFF)
    LG.polygon("fill", cliff_x, GROUND_Y, cliff_x + 70, GROUND_Y - 250, sw + 10, GROUND_Y - 330, sw + 10, GROUND_Y)
    local seam_x = sw * 0.845                                -- 꿰매 닫은 균열: 먹 금 + 은청색 바늘땀
    local seam = { seam_x, GROUND_Y - 300, seam_x - 9, GROUND_Y - 250, seam_x + 5, GROUND_Y - 205, seam_x - 4, GROUND_Y - 160 }
    LG.setLineWidth(3)
    Draw.set_color({ 0.04, 0.02, 0.03 })
    LG.line(seam)
    LG.setLineWidth(1.5)
    Draw.set_color(SEAL_BLUE, 0.4 + 0.12 * math.sin(time * 1.2))
    for k = 0, 5 do
        local y = GROUND_Y - 292 + k * 24
        local x = seam_x - 4 + (k % 2) * 6
        LG.line(x - 5, y - 2, x + 5, y + 2)
    end
    for i, stone in ipairs(STONES) do
        local x, h, w = sw * stone[1], stone[2], stone[3]
        local top = GROUND_Y - h
        Draw.set_color({ 0.02, 0.015, 0.02 })
        LG.polygon("fill", x - w / 2 - 3, GROUND_Y + 2, x - w / 2 + 2, top + 8, x + 4, top - 3, x + w / 2 + 3, top + 12, x + w / 2 + 3, GROUND_Y + 2)
        Draw.set_color(STONE_FACE)
        LG.polygon("fill", x - w / 2, GROUND_Y, x - w / 2 + 4, top + 10, x + 4, top, x + w / 2, top + 14, x + w / 2, GROUND_Y)
        Draw.set_color(STONE_EDGE, 0.55)
        LG.polygon("fill", x - w / 2 + 4, top + 10, x + 4, top, x + 4, top + 6, x - w / 2 + 6, top + 15)
        local glow = 0.45 + 0.25 * math.sin(time * 1.3 + i * 1.4)
        local gy = top + h * 0.38
        Kit.glow(x, gy, w * 0.8, SEAL_BLUE, glow * 0.75)
        LG.setLineWidth(3)
        Draw.set_color({ 0.12, 0.08, 0.08 })
        RuneArt.glyph(stone[4], x, gy, w * 0.55)
        LG.setLineWidth(1.6)
        Draw.set_color(SEAL_BLUE, glow + 0.3)
        RuneArt.glyph(stone[4], x, gy, w * 0.55)
    end
end

-- 두 그림이 모두 없을 때: 해돋이 하늘 · 먼 산 · 공방 · 봉인 룬석
function EndingScenesTrace:_draw_code(time)
    local sw, sh = Viewport.width(), Viewport.height()
    self._sky = self._sky or Kit.sky_mesh(self._spec.sky[1], self._spec.sky[2])
    Kit.draw_mesh(self._sky)
    local rise = Kit.smooth(time / 10)
    local sun_x, sun_y = sw * 0.2, GROUND_Y - 90 - 170 * rise
    Kit.rays(sun_x, sun_y, WARM, 0.06, time, { count = 9, from = -1.2, to = 0.3, length = 1600, width = 0.03 })
    Kit.glow(sun_x, sun_y, 340, WARM, 0.85)
    Draw.set_color(SUN)
    LG.circle("fill", sun_x, sun_y, 46, 48)
    Kit.draw_ridge(self._far, { 0.56, 0.34, 0.34 }, 0.85)
    LG.setBlendMode("add")                                   -- 골짜기 아침 안개
    for i = 0, 3 do
        Draw.set_color(WARM, 0.06 - i * 0.012)
        LG.rectangle("fill", 0, GROUND_Y - 120 + i * 22, sw, 30)
    end
    LG.setBlendMode("alpha")
    Kit.draw_ridge(self._near, { 0.30, 0.18, 0.19 }, 1)
    self:_draw_stones(time)
    if not Kit.sprite("building_workshop", sw * 0.43, GROUND_Y - 158, 330, { color = { 1.0, 0.88, 0.76 } }) then
        Kit.house(sw * 0.43, GROUND_Y + 2, 300, { body = { 0.30, 0.22, 0.19 }, roof = { 0.20, 0.13, 0.11 }, window = WARM,
            window_alpha = 0.9 })
    end
    Draw.set_color({ 0.09, 0.055, 0.06 })
    LG.rectangle("fill", 0, GROUND_Y, sw, sh - GROUND_Y)
    Draw.set_color(WARM, 0.25)                               -- 땅 윗선의 아침 햇빛
    LG.rectangle("fill", 0, GROUND_Y, sw, 2)
end

function EndingScenesTrace:draw(time)
    if self._gate ~= nil then
        self._gate:draw(time, self._spec)
    elseif self._kind == "illustration" then
        self._illustrate(time, function(to_screen) self:_dawn_overlay(time, to_screen) end)
    elseif self._kind == "fallback" then
        self._illustrate(time, function(to_screen) self:_fallback_overlay(time, to_screen) end)
    else
        self:_draw_code(time)
    end
end

return EndingScenesTrace
