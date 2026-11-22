-- ui/Foil.lua
-- 강화 +5 이상 유물의 포일 광택 (셰이더 shaders/foil.glsl, 수치 data/ui.lua 의 foil) — 색은 강화 등급(data/forge.lua 의 tiers):
-- +5 황금 · +7 자홍 룬 · +9 심연 신화.
-- ItemRenderer 가 아이콘을 그린 직후(같은 변환 안에서) Foil.draw(paint, level) 를 부르면, paint 로 아이콘 모양을
-- 한 번 더 그리면서 셰이더 + 가산 혼합으로 흐르는 광택 띠를 얹는다. 셰이더를 못 만들면 조용히 건너뛴다.

local UI = require("data.ui")
local FORGE = require("data.forge")

local Foil = {}

local LG = love.graphics
local SHADER_PATH = "shaders/foil.glsl"
local FOIL = UI.foil

local _shader = nil
local _failed = false

local function shader()
    if _shader == nil and not _failed then
        local ok, result = pcall(LG.newShader, SHADER_PATH)
        if ok then
            _shader = result
        else
            _failed = true
            print("[Foil] foil shader unavailable - sheen disabled: " .. tostring(result))
        end
    end
    return _shader
end

function Foil.available()
    return shader() ~= nil
end

function Foil.applies(level)
    return (level or 0) >= FOIL.min_level
end

-- 강화 등급 색 (등급 미만이면 첫 등급 색)
function Foil.tint(level)
    local color = FORGE.tiers[1].color
    for _, tier in ipairs(FORGE.tiers) do
        if (level or 0) >= tier.from then
            color = tier.color
        end
    end
    return color
end

-- paint(): 현재 변환(아이콘 중심 원점, 크기 1)에서 아이콘 모양을 그리는 함수 (색은 바꾸지 않아야 한다)
function Foil.draw(paint, level)
    if not Foil.applies(level) then
        return
    end
    local effect = shader()
    if effect == nil then
        return
    end
    local ox, oy = LG.transformPoint(0, 0)
    local ux, uy = LG.transformPoint(1, 0)
    local size = math.max(1, math.sqrt((ux - ox) ^ 2 + (uy - oy) ^ 2))
    effect:send("time", love.timer.getTime())
    effect:send("origin", { ox, oy })
    effect:send("size", size)
    effect:send("strength", math.min(FOIL.max_strength, FOIL.strength + FOIL.per_level * (level - FOIL.min_level)))
    effect:send("speed", FOIL.speed)
    local tint = Foil.tint(level)
    effect:send("tint", { tint[1], tint[2], tint[3] })
    LG.setShader(effect)
    LG.setBlendMode("add")
    LG.setColor(1, 1, 1, 1)
    paint()
    LG.setBlendMode("alpha")
    LG.setShader()
end

return Foil
