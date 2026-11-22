-- ui/IntroScenes.lua
-- 인트로 장면 그리기 (7장면 — 시간표·배치는 data/intro.lua, 진행은 states/IntroState):
--   peace   : cut1.png 켄 번스 + 흔들리는 촛불 빛 + 떠오르는 불티
--   storm   : 밤의 공방(building_workshop.png) 옆에 보라 벼락과 함께 포탈(building_portal.png)이 자라난다
--   defense : 같은 장면에서 ui/IntroBattle 의 방어 연출
--   circuit : 진열장 아래의 공명 회로 — ui/IntroCircuit (일러스트 또는 공방 배경 + 황금 틴트 + 코드 회로판)
--   vow     : 타이틀 배경(ui/TitleBackdrop)으로 줌아웃
-- 그림 파일이 없으면 코드로 그린 대체 도형을 쓴다 (크래시 금지).

local Class = require("lib.classic")
local RNG = require("core.RNG")
local Viewport = require("core.Viewport")
local Draw = require("ui.Draw")
local Parchment = require("ui.Parchment")
local RoomBackdrop = require("ui.RoomBackdrop")
local SpriteBank = require("ui.SpriteBank")
local TitleBackdrop = require("ui.TitleBackdrop")
local IntroBattle = require("ui.IntroBattle")
local IntroCircuit = require("ui.IntroCircuit")
local KenBurns = require("ui.KenBurns")
local INTRO = require("data.intro")
local ART = require("data.art")

local IntroScenes = Class:extend()

local LG = love.graphics
local CANDLE = { 1.0, 0.7, 0.35 }
local PORTAL_GLOW = { 0.72, 0.3, 0.95 }
local BOLT = { 0.8, 0.55, 1.0 }
local SKY_TOP, SKY_BOTTOM = { 0.03, 0.03, 0.08 }, { 0.14, 0.08, 0.2 }

local function smooth(t)
    t = math.max(0, math.min(1, t))
    return t * t * (3 - 2 * t)
end

-- 키프레임 카메라 보간 (ui/KenBurns)
IntroScenes.camera_at = KenBurns.camera_at

function IntroScenes:new(fx)
    self._fx = fx
    self._rng = RNG.stream("fx")
    self._embers = {}
    self._bolts = {}
    self._stars = {}
    for i = 1, 70 do
        self._stars[i] = { self._rng:float(0, Viewport.width()), self._rng:float(50, INTRO.ground_y - 160), self._rng:float(0.2, 0.8) }
    end
    self._cut = nil
    if love.filesystem.getInfo(INTRO.cut) ~= nil then
        local ok, image = pcall(LG.newImage, INTRO.cut, { mipmaps = true })
        self._cut = ok and image or nil
    end
    self.backdrop = TitleBackdrop()
    self.battle = IntroBattle(fx)
    self.circuit = IntroCircuit()
end

-- 보라 벼락 (x 위치로 하늘에서 내리친다)
function IntroScenes:strike(x, y)
    self._bolts[#self._bolts + 1] = { points = IntroBattle.bolt_points(self._rng, x + self._rng:float(-80, 80), 30, x, y, 9, 34), life = 0.4 }
end

function IntroScenes:update(dt, stage, time)
    if stage == "peace" and self._rng:chance(dt * 14) then
        local candle = self._rng:pick(INTRO.candles)
        self._embers[#self._embers + 1] = { u = candle.x + self._rng:float(-0.02, 0.02), v = candle.y, life = self._rng:float(1.2, 2.4),
            vu = self._rng:float(-0.004, 0.004), vv = -self._rng:float(0.03, 0.06) }
    end
    for i = #self._embers, 1, -1 do
        local e = self._embers[i]
        e.life = e.life - dt
        e.u, e.v = e.u + e.vu * dt + math.sin(time * 3 + i) * 0.002 * dt, e.v + e.vv * dt
        if e.life <= 0 then
            table.remove(self._embers, i)
        end
    end
    for i = #self._bolts, 1, -1 do
        self._bolts[i].life = self._bolts[i].life - dt
        if self._bolts[i].life <= 0 then
            table.remove(self._bolts, i)
        end
    end
    if stage == "defense" then
        self.battle:update(dt, time)
    elseif stage == "vow" then
        self.backdrop:update(dt)
    end
end

-- 4장면 vanish: cut1 을 차가운 푸른빛으로 덮고 촛불은 꺼져 간다 (빈 공방)
-- 5장면 contract: 어두운 바탕 위 양피지 계약서가 펼쳐지고 길드 밀랍 인장이 찍힌다
local function draw_contract(self, time)
    local cfg, sw, sh = INTRO.contract, Viewport.width(), Viewport.height()
    self.backdrop:draw(IntroScenes.camera_at(INTRO.vow_camera, INTRO.vow_camera[1].t), 0.62)
    local unroll = smooth((time - cfg.unroll_from) / cfg.unroll_time)
    local rect = { x = (sw - cfg.w) / 2, y = 150, w = cfg.w, h = cfg.h }
    Parchment.draw_paper(rect, unroll)
    Parchment.draw_rods(rect, unroll)
    if unroll >= 1 then
        Draw.set_color(Parchment.INK, 0.55)
        LG.setLineWidth(2)
        for i = 1, 5 do                                    -- 계약 조항 (잉크 줄)
            local y = rect.y + 44 + i * 34
            LG.line(rect.x + 60, y, rect.x + rect.w - 60 - (i % 2) * 70, y)
        end
    end
    local seal = smooth((time - cfg.seal_at) / 0.25)
    if seal > 0 then
        local cx, cy = rect.x + rect.w - 96, rect.y + rect.h - 70
        local size = 34 * (1.6 - 0.6 * seal)
        Draw.set_color({ 0.55, 0.06, 0.07 }, seal)
        LG.circle("fill", cx, cy, size, 28)
        Draw.set_color({ 0.85, 0.25, 0.22 }, seal * 0.8)
        LG.setLineWidth(3)
        LG.circle("line", cx, cy, size * 0.7, 24)
        LG.line(cx, cy - size * 0.45, cx, cy + size * 0.45)
        LG.line(cx - size * 0.3, cy - size * 0.1, cx + size * 0.3, cy - size * 0.1)
    end
end

function IntroScenes:_draw_peace(time, camera_keys, cold)
    local camera = IntroScenes.camera_at(camera_keys or INTRO.peace_camera, time)
    local sw, sh = Viewport.width(), Viewport.height()
    local to_screen
    local image = cold and RoomBackdrop.load(ART.room.image) or self._cut   -- 빈 공방 = 사람이 없는 공방 실내 그림 (없으면 cut1)
    if image ~= nil then
        to_screen = KenBurns.draw(image, camera)
    else
        Draw.clear({ 0.12, 0.07, 0.05 })
        to_screen = function(u, v) return u * sw, v * sh end
    end
    if cold then
        LG.setColor(0.02, 0.04, 0.10, 0.62)
    else
        LG.setColor(0.05, 0.02, 0.01, 0.25)
    end
    LG.rectangle("fill", 0, 0, sw, sh)
    LG.setBlendMode("add")
    local candles = INTRO.candles
    if cold then                                       -- 식어 가는 벽난로 불씨 하나만
        candles = image ~= self._cut and { INTRO.vanish_ember } or candles
    end
    for i, candle in ipairs(candles) do
        local x, y = to_screen(candle.x, candle.y)
        local flicker = (0.12 + 0.05 * math.sin(time * 11 + i * 2) + 0.03 * math.sin(time * 23 + i)) * (cold and 0.3 or 1)
        Draw.set_color(CANDLE, flicker)
        LG.circle("fill", x, y, 120 * camera.zoom, 40)
        Draw.set_color(CANDLE, flicker * 1.6)
        LG.circle("fill", x, y, 40 * camera.zoom, 24)
    end
    for _, e in ipairs(self._embers) do
        local x, y = to_screen(e.u, e.v)
        Draw.set_color(CANDLE, math.min(1, e.life))
        LG.circle("fill", x, y, 1.8, 6)
    end
    LG.setBlendMode("alpha")
end

-- 밤 장면: 하늘·땅·공방·(자라나는) 포탈
function IntroScenes:_draw_night(time)
    local sw, sh = Viewport.width(), Viewport.height()
    for i = 0, 15 do
        Draw.set_color(Draw.lerp_color(SKY_TOP, SKY_BOTTOM, i / 15))
        LG.rectangle("fill", 0, i * sh / 16, sw, sh / 16 + 1)
    end
    for _, star in ipairs(self._stars) do
        Draw.set_color({ 0.85, 0.8, 1.0 }, star[3] * (0.6 + 0.4 * math.sin(time * 2 + star[1])))
        LG.circle("fill", star[1], star[2], 1.2, 6)
    end
    local storm = math.max(0, math.min(1, (time - INTRO.stages[2].start) / 1.5))
    Draw.set_color(PORTAL_GLOW, 0.1 * storm + 0.05 * storm * math.sin(time * 3))
    LG.rectangle("fill", 0, 0, sw, sh)
    for i = 0, 7 do
        Draw.set_color(Draw.lerp_color({ 0.1, 0.07, 0.11 }, { 0.03, 0.02, 0.03 }, i / 7))
        LG.rectangle("fill", 0, INTRO.ground_y + i * (sh - INTRO.ground_y) / 8, sw, (sh - INTRO.ground_y) / 8 + 1)
    end
    local shop = SpriteBank.image("building_workshop")
    local shop_cfg = INTRO.pawnshop
    if shop ~= nil then
        SpriteBank.draw_fit(shop, shop_cfg.x, INTRO.ground_y - shop_cfg.size / 2 + 20, shop_cfg.size)
    else
        Draw.set_color({ 0.25, 0.18, 0.14 })
        LG.rectangle("fill", shop_cfg.x - 150, INTRO.ground_y - 300, 300, 300)
        LG.polygon("fill", shop_cfg.x - 170, INTRO.ground_y - 300, shop_cfg.x, INTRO.ground_y - 440, shop_cfg.x + 170, INTRO.ground_y - 300)
    end
    local cfg = INTRO.portal
    local grow = smooth((time - cfg.appear_at) / cfg.grow)
    if grow > 0 then
        local cx, cy = cfg.x, INTRO.ground_y - cfg.size / 2 + 20
        Draw.glow(cx, cy, cfg.size * 0.8 * grow, PORTAL_GLOW, (0.55 + 0.15 * math.sin(time * 4)) * grow)
        local portal = SpriteBank.image("building_portal")
        if portal ~= nil then
            SpriteBank.draw_fit(portal, cx, cy + (1 - grow) * cfg.size * 0.4, cfg.size * grow, { alpha = grow })
        else
            Draw.set_color(PORTAL_GLOW, grow)
            LG.ellipse("fill", cx, cy, cfg.size * 0.25 * grow, cfg.size * 0.4 * grow, 32)
        end
    end
end

function IntroScenes:_draw_bolts()
    LG.setBlendMode("add")
    for _, bolt in ipairs(self._bolts) do
        local a = bolt.life / 0.4
        Draw.set_color(BOLT, 0.55 * a)
        LG.setLineWidth(12 * a + 2)
        LG.line(bolt.points)
        Draw.set_color({ 1, 1, 1 }, a)
        LG.setLineWidth(3)
        LG.line(bolt.points)
    end
    LG.setBlendMode("alpha")
end

function IntroScenes:draw(stage, time)
    if stage == "peace" then
        self:_draw_peace(time)
    elseif stage == "vanish" then
        self:_draw_peace(time, INTRO.vanish_camera, true)
    elseif stage == "contract" then
        draw_contract(self, time)
    elseif stage == "circuit" then
        self.circuit:draw(time)
    elseif stage == "storm" or stage == "defense" then
        self:_draw_night(time)
        if stage == "defense" then
            self.battle:draw(time)
        end
    else
        self.backdrop:draw(IntroScenes.camera_at(INTRO.vow_camera, time), 0.1)
    end
    self:_draw_bolts()
end

return IntroScenes
