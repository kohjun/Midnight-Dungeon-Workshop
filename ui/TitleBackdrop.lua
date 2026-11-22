-- ui/TitleBackdrop.lua
-- 인트로·타이틀·난이도·결과 화면 공용 배경: 배경 그림(카메라 이동·확대) + 떠오르는 불티 + 흐르는 안개 + 번개 섬광.
-- 그림 파일(data/intro.lua 의 background)이 없으면 코드로 그린 밤하늘·달·관문·공방 실루엣으로 대체한다.
--   local backdrop = TitleBackdrop()
--   backdrop:update(dt) / backdrop:draw(camera { x, y, zoom }, dim 0~1) / backdrop:flash(strength)

local Class = require("lib.classic")
local RNG = require("core.RNG")
local Viewport = require("core.Viewport")
local Draw = require("ui.Draw")
local INTRO = require("data.intro")

local TitleBackdrop = Class:extend()

local LG = love.graphics
local EMBER_COLORS = { { 1.0, 0.62, 0.22 }, { 1.0, 0.82, 0.4 }, { 1.0, 0.4, 0.15 } }
local MAX_EMBERS = 90

local _image = nil
local _image_checked = false
local _soft = nil       -- 부드러운 원형 그라데이션 (안개·빛)

local function image()
    if not _image_checked then
        _image_checked = true
        if love.filesystem.getInfo(INTRO.background) ~= nil then
            local ok, loaded = pcall(LG.newImage, INTRO.background, { mipmaps = true })
            if ok then
                _image = loaded
                _image:setFilter("linear", "linear")
            else
                print("[TitleBackdrop] failed to load background: " .. tostring(loaded))
            end
        end
    end
    return _image
end

local function soft()
    if _soft == nil then
        local size = 64
        local data = love.image.newImageData(size, size)
        data:mapPixel(function(x, y)
            local d = math.sqrt((x - size / 2 + 0.5) ^ 2 + (y - size / 2 + 0.5) ^ 2) / (size / 2)
            local a = math.max(0, 1 - d)
            return 1, 1, 1, a * a
        end)
        _soft = LG.newImage(data)
        _soft:setFilter("linear", "linear")
    end
    return _soft
end

function TitleBackdrop.has_image()
    return image() ~= nil
end

function TitleBackdrop:new()
    self._rng = RNG.stream("fx")
    self._embers = {}
    self._spawn = 0
    self._time = 0
    self._flash = 0
    self._fog = {}
    for i = 1, INTRO.fog_layers do
        self._fog[i] = { x = self._rng:float(0, 1280), y = 560 + i * 34, w = self._rng:float(520, 820), speed = self._rng:float(8, 22) }
    end
end

function TitleBackdrop:flash(strength)
    self._flash = math.max(self._flash, strength or 1)
end

function TitleBackdrop:update(dt)
    self._time = self._time + dt
    self._flash = math.max(0, self._flash - dt * 2.2)
    self._spawn = self._spawn + dt * INTRO.embers_per_second
    local rng = self._rng
    while self._spawn >= 1 and #self._embers < MAX_EMBERS do
        self._spawn = self._spawn - 1
        self._embers[#self._embers + 1] = {
            x = rng:float(380, 1180), y = rng:float(430, 760), vy = -rng:float(18, 46), phase = rng:float(0, 6),
            life = rng:float(3, 6.5), size = rng:float(1, 2.6), color = rng:pick(EMBER_COLORS),
        }
    end
    for i = #self._embers, 1, -1 do
        local e = self._embers[i]
        e.life = e.life - dt
        e.y = e.y + e.vy * dt
        e.x = e.x + math.sin(self._time * 1.3 + e.phase) * 12 * dt
        if e.life <= 0 then
            table.remove(self._embers, i)
        end
    end
    for _, fog in ipairs(self._fog) do
        fog.x = fog.x + fog.speed * dt
        if fog.x - fog.w > 1280 then
            fog.x = -fog.w
        end
    end
end

local function draw_image(img, camera)
    local sw, sh = Viewport.width(), Viewport.height()
    local iw, ih = img:getDimensions()
    local scale = math.max(sw / iw, sh / ih) * (camera.zoom or 1)
    local ox = sw / 2 - camera.x * iw * scale
    local oy = sh / 2 - camera.y * ih * scale
    ox = math.min(0, math.max(sw - iw * scale, ox))     -- 그림이 화면을 항상 덮도록
    oy = math.min(0, math.max(sh - ih * scale, oy))
    LG.setColor(1, 1, 1, 1)
    LG.draw(img, ox, oy, 0, scale, scale)
end

-- 그림이 없을 때: 코드로 그린 밤 풍경
local function draw_fallback(time)
    local sw, sh = Viewport.width(), Viewport.height()
    for i = 0, 23 do
        local t = i / 23
        Draw.set_color({ 0.03 + 0.12 * t, 0.025 + 0.06 * t, 0.07 + 0.12 * t })
        LG.rectangle("fill", 0, i * sh / 24, sw, sh / 24 + 1)
    end
    Draw.set_color({ 0.97, 0.94, 0.80 }, 0.12)
    LG.circle("fill", 1040, 130, 120, 48)
    Draw.set_color({ 0.97, 0.94, 0.80 })
    LG.circle("fill", 1040, 130, 56, 48)
    Draw.set_color({ 0.07, 0.05, 0.10 })
    LG.polygon("fill", 900, 720, 980, 300, 1280, 240, 1280, 720)
    Draw.set_color({ 0.7, 0.15, 0.4 }, 0.35 + 0.1 * math.sin(time * 2))
    LG.ellipse("fill", 1130, 470, 70, 110, 32)
    Draw.set_color({ 0.05, 0.04, 0.07 })
    LG.rectangle("fill", 520, 400, 290, 320)
    LG.polygon("fill", 500, 405, 665, 280, 830, 405)
    Draw.set_color({ 1, 0.68, 0.32 }, 0.85 + 0.1 * math.sin(time * 7))
    LG.rectangle("fill", 560, 450, 50, 56)
    LG.rectangle("fill", 715, 450, 50, 56)
    LG.rectangle("fill", 560, 560, 110, 80)
    Draw.set_color({ 0.02, 0.02, 0.03 })
    LG.rectangle("fill", 0, 690, sw, 30)
end

-- camera: { x, y, zoom } (생략하면 전경), dim: 0~1 위에 덮는 어둠 (메뉴·카드 가독성)
function TitleBackdrop:draw(camera, dim)
    camera = camera or INTRO.title_camera
    local img = image()
    if img ~= nil then
        draw_image(img, camera)
    else
        draw_fallback(self._time)
    end
    local sw, sh = Viewport.width(), Viewport.height()
    local glow = soft()
    for _, fog in ipairs(self._fog) do
        LG.setColor(0.62, 0.58, 0.78, 0.07)
        LG.draw(glow, fog.x, fog.y - 60, 0, fog.w / 64, 120 / 64)
    end
    LG.setBlendMode("add")
    for _, e in ipairs(self._embers) do
        local a = math.min(1, e.life) * (0.55 + 0.45 * math.sin(self._time * 9 + e.phase))
        LG.setColor(e.color[1], e.color[2], e.color[3], a * 0.35)
        LG.draw(glow, e.x - e.size * 4, e.y - e.size * 4, 0, e.size * 8 / 64, e.size * 8 / 64)
        LG.setColor(e.color[1], e.color[2], e.color[3], a)
        LG.circle("fill", e.x, e.y, e.size * 0.6, 6)
    end
    LG.setBlendMode("alpha")
    if dim ~= nil and dim > 0 then
        LG.setColor(0.01, 0.01, 0.03, dim)
        LG.rectangle("fill", 0, 0, sw, sh)
    end
    if self._flash > 0 then
        LG.setColor(0.75, 0.8, 1.0, 0.55 * self._flash)
        LG.rectangle("fill", 0, 0, sw, sh)
    end
end

return TitleBackdrop
