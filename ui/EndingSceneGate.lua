-- ui/EndingSceneGate.lua
-- '새로운 문지기' 엔딩 코드 연출 (ui/EndingScenesTrace 가 그린다 — 일러스트 없음, 수치·색은 data/endings.lua 의 new_gatekeeper):
--   차가운 보랏빛 밤하늘 · 깜빡이는 별 · 가는 초승달 · 먼 절벽 · 왼쪽 멀리 창에 불이 켜진 공방(새 견습생)
--   · 가운데 포탈(building_portal, 없으면 돌 아치)과 아치 안 소용돌이
--   · 그 앞을 지키는 두건 쓴 그림자 (boss_master 를 거의 검게 + 보랏빛 윤곽 · 눈 두 점, 없으면 망치를 쥔 두건 도형)
--   · 포탈 둘레를 천천히 도는 희미한 은빛 룬 · 느리게 피어오르는 보라·은 불티.
-- 그림은 모두 SpriteBank 로 불러 보고, 없으면 도형으로 대신 그린다 (크래시 없음).

local Class = require("lib.classic")
local Viewport = require("core.Viewport")
local Draw = require("ui.Draw")
local SpriteBank = require("ui.SpriteBank")
local RuneArt = require("ui.RuneArt")
local Kit = require("ui.EndingSceneKit")

local EndingSceneGate = Class:extend()

local LG = love.graphics
local GROUND_Y = 540
local PORTAL = { x = 0.6, y = 330, size = 430 }     -- 포탈 그림 가운데(x 는 화면 폭 비율) · 높이
local ARCH = { x = 0.5, y = 0.6, rx = 0.17, ry = 0.3 }   -- building_portal 그림 안 아치 안쪽 (정규화 중심 · 반지름)
local KEEPER = { size = 215, feet = 0.41 }         -- 문지기 높이 · 발 위치(포탈 가운데에서 포탈 높이 비율만큼 아래)
local EYES = { { 0.535, 0.093 }, { 0.567, 0.093 } }  -- boss_master 그림 안 눈 (정규화)
local HOUSE = { x = 0.15, size = 220, windows = { { 0.565, 0.375 }, { 0.245, 0.755 } } }  -- 먼 공방 · 그림 안 창문
local RING = { rx = 262, ry = 196, count = 10, size = 16 }  -- 포탈 둘레 은빛 룬
local VIOLET = { 0.62, 0.40, 1.0 }
local VIOLET_DEEP = { 0.22, 0.08, 0.40 }
local SILVER = { 0.84, 0.88, 1.0 }
local SHADOW = { 0.035, 0.025, 0.05 }
local STONE = { 0.16, 0.13, 0.19 }
local WINDOW = { 1.0, 0.70, 0.36 }
local MOON = { 0.88, 0.90, 1.0 }
local EMBERS = { { 0.72, 0.52, 1.0 }, { 0.86, 0.88, 1.0 }, { 0.56, 0.32, 0.92 } }
local EMBER_RATE = 7

function EndingSceneGate:new(rng)
    self._rng = rng
    self._spawn = 0
    self._stars = {}
    for i = 1, 90 do
        self._stars[i] = { x = rng:float(0, Viewport.width()), y = rng:float(30, 400), r = rng:float(0.6, 1.8), phase = rng:float(0, 6.3) }
    end
    self._far = Kit.ridge(rng, GROUND_Y - 120, 120, 70)
    self._near = Kit.ridge(rng, GROUND_Y - 20, 40, 60)
end

function EndingSceneGate:update(dt, _, fx)
    self._spawn = self._spawn - dt
    while self._spawn <= 0 do
        self._spawn = self._spawn + 1 / EMBER_RATE
        fx:burst(Viewport.width() * PORTAL.x + self._rng:float(-160, 160), GROUND_Y - self._rng:float(0, 50), { count = 1,
            colors = EMBERS, speed_min = 10, speed_max = 30, angle = -math.pi / 2, spread = 0.45, life_min = 2.4, life_max = 4.2,
            size_min = 1.2, size_max = 2.6, drag = 0.25, gravity = -5 })
    end
end

local function draw_sky(spec, sky, stars, time)
    local sw = Viewport.width()
    Kit.draw_mesh(sky)
    for _, star in ipairs(stars) do
        Draw.set_color(SILVER, 0.35 + 0.45 * (0.5 + 0.5 * math.sin(time * 1.3 + star.phase)))
        LG.circle("fill", star.x, star.y, star.r, 6)
    end
    local mx, my = sw * 0.16, 132                            -- 가는 초승달 (하늘색 원으로 가린 뒤 빛무리를 함께 덮는다)
    Draw.set_color(MOON)
    LG.circle("fill", mx, my, 28, 40)
    Draw.set_color(Draw.lerp_color(spec.sky[1], spec.sky[2], (my / Viewport.height()) ^ 1.4))
    LG.circle("fill", mx + 11, my - 7, 26, 40)
    Kit.glow(mx, my, 100, MOON, 0.3)
end

-- 먼 공방: 차갑게 가라앉은 그림 + 창에만 따뜻한 불 (새 견습생)
local function draw_house(time)
    local x, size = Viewport.width() * HOUSE.x, HOUSE.size
    local image = SpriteBank.image("building_workshop")
    if image == nil then
        Kit.house(x, GROUND_Y + 4, size * 0.8, { body = { 0.12, 0.11, 0.18 }, roof = { 0.08, 0.07, 0.12 }, window = WINDOW,
            window_alpha = 0.85 + 0.15 * math.sin(time * 2.1) })
        return
    end
    local y = GROUND_Y + 4 - size / 2
    SpriteBank.draw_fit(image, x, y, size, { color = { 0.34, 0.34, 0.52 } })
    local w, h = image:getDimensions()
    local s = size / math.max(w, h)
    for i, window in ipairs(HOUSE.windows) do
        Kit.glow(x + (window[1] - 0.5) * w * s, y + (window[2] - 0.5) * h * s, 30, WINDOW, 0.6 + 0.12 * math.sin(time * 2 + i))
    end
end

-- 포탈 (그림 또는 돌 아치) → 아치 안 중심 · 반지름을 돌려준다
local function draw_portal(time)
    local px, py, size = Viewport.width() * PORTAL.x, PORTAL.y, PORTAL.size
    Kit.glow(px, py + 30, 430, VIOLET, 0.42 + 0.12 * math.sin(time * 1.2))
    local cx, cy, rx, ry = px + (ARCH.x - 0.5) * size, py + (ARCH.y - 0.5) * size, ARCH.rx * size, ARCH.ry * size
    if not Kit.sprite("building_portal", px, py, size, { color = { 0.62, 0.56, 0.86 } }) then
        local top = cy - ry
        Draw.set_color({ 0.02, 0.015, 0.03 })
        LG.rectangle("fill", cx - rx - 48, top, rx * 2 + 96, GROUND_Y - top + 4)
        LG.circle("fill", cx, top, rx + 48, 40)
        Draw.set_color(STONE)
        LG.rectangle("fill", cx - rx - 44, top, rx * 2 + 88, GROUND_Y - top)
        LG.circle("fill", cx, top, rx + 44, 40)
        Draw.set_color(VIOLET_DEEP)
        LG.rectangle("fill", cx - rx, top, rx * 2, GROUND_Y - top)
        LG.circle("fill", cx, top, rx, 40)
    end
    LG.push()                                                -- 아치 안 소용돌이 (가산 호)
    LG.translate(cx, cy)
    LG.scale(1, ry / rx)
    LG.setBlendMode("add")
    for i = 1, 6 do
        local angle = time * (0.35 + i * 0.07) + i * 1.9
        Draw.set_color(VIOLET, 0.16 + 0.05 * math.sin(time * 1.7 + i))
        LG.setLineWidth(3)
        LG.arc("line", "open", 0, 0, rx * (0.25 + i * 0.11), angle, angle + 2.1, 24)
    end
    LG.setBlendMode("alpha")
    LG.pop()
    return cx, cy
end

-- 두건 쓴 문지기 그림자 (스프라이트가 없을 때): 두건 · 망토 · 해진 자락 · 비스듬히 쥔 망치
local function keeper_shape(x, feet, h)
    local s = h / 215
    local top = feet - h
    LG.polygon("fill", x - 23 * s, top + 44 * s, x - 13 * s, top + 8 * s, x + 2 * s, top, x + 16 * s, top + 12 * s, x + 25 * s, top + 46 * s)
    LG.polygon("fill", x - 30 * s, top + 40 * s, x + 32 * s, top + 40 * s, x + 60 * s, feet, x - 58 * s, feet)
    for k = 0, 5 do
        local hx = x - 58 * s + k * 23 * s
        LG.polygon("fill", hx, feet - 2, hx + 23 * s, feet - 2, hx + 11 * s, feet + 9 * s)
    end
    LG.setLineWidth(9 * s)
    LG.line(x - 64 * s, top + 52 * s, x + 26 * s, top + 128 * s)
    LG.push()
    LG.translate(x - 70 * s, top + 46 * s)
    LG.rotate(0.7)
    LG.rectangle("fill", -26 * s, -16 * s, 52 * s, 32 * s, 3 * s, 3 * s)
    LG.pop()
end

local function draw_keeper(cx, time)
    local feet = PORTAL.y + KEEPER.feet * PORTAL.size
    local h = KEEPER.size * (1 + 0.006 * math.sin(time * 1.1))          -- 숨 쉬듯 아주 조금
    local y = feet - h / 2
    Kit.glow(cx, y, 180, VIOLET, 0.5)
    local image = SpriteBank.image("boss_master")
    local eyes = {}
    if image ~= nil then
        LG.push()                                            -- 보랏빛 윤곽: 조금 큰 단색 실루엣을 먼저
        LG.translate(cx, y)
        LG.scale(h * 1.035, h * 1.02)
        Draw.set_color(VIOLET, 0.55)
        SpriteBank.draw_silhouette(image)
        LG.pop()
        SpriteBank.draw_fit(image, cx, y, h, { color = SHADOW })
        local w, ih = image:getDimensions()
        local s = h / math.max(w, ih)
        for i, eye in ipairs(EYES) do
            eyes[i] = { cx + (eye[1] - 0.5) * w * s, y + (eye[2] - 0.5) * ih * s }
        end
    else
        Draw.set_color(VIOLET, 0.5)
        LG.push()
        LG.translate(cx, feet)
        LG.scale(1.05, 1.03)
        keeper_shape(0, 0, h)
        LG.pop()
        Draw.set_color(SHADOW)
        keeper_shape(cx, feet, h)
        eyes = { { cx - 4, feet - h + 25 }, { cx + 6, feet - h + 25 } }
    end
    local glint = 0.55 + 0.45 * math.sin(time * 0.9) ^ 2
    for _, eye in ipairs(eyes) do
        Draw.glow(eye[1], eye[2], 9, VIOLET, glint)
        Draw.set_color({ 0.92, 0.84, 1.0 }, glint)
        LG.circle("fill", eye[1], eye[2], 1.5, 8)
    end
end

-- 포탈 둘레를 천천히 도는 은빛 룬 (멀리 있는 쪽은 더 흐리다)
local function draw_runes(cx, cy, time)
    LG.setLineWidth(1.6)
    for i = 1, RING.count do
        local angle = i / RING.count * math.pi * 2 + time * 0.07
        local x, y = cx + math.cos(angle) * RING.rx, cy + math.sin(angle) * RING.ry
        local alpha = (0.2 + 0.32 * (0.5 + 0.5 * math.sin(time * 1.1 + i * 1.7))) * (0.75 + 0.25 * math.sin(angle))
        Draw.glow(x, y, RING.size * 1.3, SILVER, alpha * 0.6)
        Draw.set_color(SILVER, alpha)
        RuneArt.glyph(i * 3, x, y, RING.size)
    end
end

function EndingSceneGate:draw(time, spec)
    local sw, sh = Viewport.width(), Viewport.height()
    self._sky = self._sky or Kit.sky_mesh(spec.sky[1], spec.sky[2])
    draw_sky(spec, self._sky, self._stars, time)
    Kit.draw_ridge(self._far, { 0.10, 0.07, 0.17 }, 1)
    Kit.draw_ridge(self._near, { 0.05, 0.035, 0.08 }, 1)
    draw_house(time)
    local cx, cy = draw_portal(time)
    draw_runes(cx, cy, time)
    draw_keeper(cx, time)
    Draw.set_color({ 0.03, 0.02, 0.05 })
    LG.rectangle("fill", 0, GROUND_Y + 6, sw, sh - GROUND_Y - 6)
    LG.setBlendMode("add")                                   -- 땅을 덮는 옅은 보랏빛 안개
    for i = 0, 3 do
        Draw.set_color(VIOLET_DEEP, 0.07 - i * 0.012)
        LG.rectangle("fill", 0, GROUND_Y - 30 + i * 16, sw, 26)
    end
    LG.setBlendMode("alpha")
end

return EndingSceneGate
