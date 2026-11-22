-- ui/RoomBackdrop.lua
-- 공방 화면 맨 뒤에 깔리는 실내 그림 (data/art.lua 의 room: 낮 = assets/backgrounds/day_workshop.png, 밤 = assets/intro/cut1.png).
-- 화면을 덮도록 비율을 지켜 확대해 그린 뒤 은은하게 어둡게(낮 / 밤 정도가 다르다) 덮고 가장자리에 암막 비네팅을 건다.
-- 패널 사이 틈과 살짝 투명한 패널 바탕으로 공방 실내 분위기가 비친다. 그림이 없으면 단색 바탕.

local Viewport = require("core.Viewport")
local Draw = require("ui.Draw")
local ART = require("data.art")
local UI = require("data.ui")

local RoomBackdrop = {}

local LG = love.graphics
local VIGNETTE_W, VIGNETTE_H = 64, 36

local _images = {}      -- path -> Image | false
local _vignette = nil

-- 배경 그림 (없거나 못 읽으면 nil — 단색 폴백). 밤 전투 레인 배경(ui/LaneView)도 여기서 읽는다
function RoomBackdrop.load(path)
    local cached = _images[path]
    if cached == nil then
        cached = false
        if love.filesystem.getInfo(path) ~= nil then
            local ok, loaded = pcall(LG.newImage, path, { mipmaps = true })
            if ok then
                loaded:setFilter("linear", "linear")
                cached = loaded
            else
                print("[RoomBackdrop] failed to load " .. path .. ": " .. tostring(loaded))
            end
        end
        _images[path] = cached
    end
    return cached or nil
end

local function image(phase)
    return RoomBackdrop.load(phase == "night" and ART.room.night_image or ART.room.image)
end

-- 가운데는 투명, 가장자리로 갈수록 검게 (작게 만들어 늘려 그린다)
local function vignette()
    if _vignette == nil then
        local data = love.image.newImageData(VIGNETTE_W, VIGNETTE_H)
        data:mapPixel(function(x, y)
            local dx = (x + 0.5) / VIGNETTE_W * 2 - 1
            local dy = (y + 0.5) / VIGNETTE_H * 2 - 1
            local d = math.min(1, math.sqrt(dx * dx * 0.8 + dy * dy))
            return 0, 0, 0, d ^ 2.2
        end)
        _vignette = LG.newImage(data)
        _vignette:setFilter("linear", "linear")
    end
    return _vignette
end

function RoomBackdrop.has_image()
    return image("day") ~= nil
end

-- phase: "day" | "night" | "shop"
function RoomBackdrop.draw(phase)
    local sw, sh = Viewport.width(), Viewport.height()
    Draw.clear(UI.color.background)
    local img = image(phase)
    if img == nil then
        return
    end
    local iw, ih = img:getDimensions()
    local scale = math.max(sw / iw, sh / ih)
    LG.setColor(1, 1, 1, 1)
    LG.draw(img, (sw - iw * scale) / 2, (sh - ih * scale) / 2, 0, scale, scale)
    local night = phase == "night"
    local tint = night and { 0.02, 0.03, 0.08 } or { 0.04, 0.025, 0.02 }
    LG.setColor(tint[1], tint[2], tint[3], night and ART.room.dim_night or ART.room.dim_day)
    LG.rectangle("fill", 0, 0, sw, sh)
    local v = vignette()
    LG.setColor(1, 1, 1, ART.room.vignette)
    LG.draw(v, 0, 0, 0, sw / VIGNETTE_W, sh / VIGNETTE_H)
end

return RoomBackdrop
