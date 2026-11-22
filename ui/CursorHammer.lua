-- ui/CursorHammer.lua
-- 대장장이 망치 커서 (ui/CursorManager 가 부른다). data/cursors.lua 의 hammer.states 에 있는 커서 상태(기본 · 버튼 호버)를
-- 원화 cursor_hammer.png 로 그린다 — 그림이 없으면 false 를 돌려 기존 단검 도안(ui/CursorShapes)으로 폴백.
--   핫스팟 = 망치 머리 타격면 (hammer.hotspot, 그림 기준 정규화) — 실제 클릭 지점과 정확히 일치
--   클릭 : 자루 끝(grip)을 축으로 머리가 strike.time 초 동안 내려찍었다가 탄성 있게 복원 + 버튼이 아닌 곳이면 cursor_tap 효과음
--          (버튼은 자기 클릭음을 낸다, 쿨타임 tap_cooldown). 클릭 지점 불티는 CursorManager 의 클릭 파동(hammer.ripple)
--   호버 : 금빛 발광 한 겹 (가산)

local SpriteBank = require("ui.SpriteBank")
local Audio = require("systems.Audio")
local CURSORS = require("data.cursors")

local CursorHammer = {}

local LG = love.graphics
local H = CURSORS.hammer

local _strike = 0           -- 클릭 직후 1 → 0
local _last_tap = -math.huge

function CursorHammer.image()
    return SpriteBank.image(H.image)
end

-- 이 커서 상태를 망치로 그리는지
function CursorHammer.applies(name)
    return H.states[name] == true and CursorHammer.image() ~= nil
end

-- 클릭 (time = 커서 누적 시간). 망치로 그리는 상태면 true
function CursorHammer.press(name, time)
    if not CursorHammer.applies(name) then
        return false
    end
    _strike = 1
    if name == "default" and time - _last_tap >= H.tap_cooldown then
        _last_tap = time
        Audio.play(H.sound)
    end
    return true
end

function CursorHammer.update(dt)
    _strike = math.max(0, _strike - dt / H.strike.time)
end

-- 지금 내려찍은 정도 0~1 (빠르게 내려갔다 살짝 튕기며 돌아온다)
function CursorHammer.swing()
    local p = 1 - _strike
    if _strike <= 0 then
        return 0
    end
    return math.sin(math.min(1, p * 2.2) * math.pi) * (1 - p * 0.35) - 0.18 * math.sin(p * math.pi * 3) * (1 - p)
end

-- 지금 변환의 원점 = 포인터 (CursorManager 가 기울기·눌림 배율을 이미 걸었다). glow = 호버 0~1
function CursorHammer.draw(glow)
    local image = CursorHammer.image()
    local iw, ih = image:getDimensions()
    local s = H.size / iw
    local gx, gy = H.grip.x * iw, H.grip.y * ih
    LG.push()
    LG.scale(s)
    LG.translate(-H.hotspot.x * iw, -H.hotspot.y * ih)
    LG.translate(gx, gy)
    LG.rotate(-H.strike.angle * CursorHammer.swing())
    LG.translate(-gx, -gy)
    LG.setColor(0, 0, 0, CURSORS.shadow.alpha)
    LG.draw(image, CURSORS.shadow.x / s, CURSORS.shadow.y / s)
    LG.setColor(1, 1, 1, 1)
    LG.draw(image, 0, 0)
    if glow > 0.01 then
        LG.setBlendMode("add")
        LG.setColor(H.glow[1], H.glow[2], H.glow[3], 0.38 * glow)
        LG.draw(image, 0, 0)
        LG.setBlendMode("alpha")
    end
    LG.pop()
end

return CursorHammer
