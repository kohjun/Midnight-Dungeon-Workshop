-- ui/KenBurns.lua
-- 일러스트 한 장을 화면에 꽉 채워(cover) 천천히 줌·패닝하는 카메라 (인트로 1단계 cut1 · 엔딩 일러스트).
--   KenBurns.camera_at(keys, t) : 키프레임 { { t, x, y, zoom }, ... } 사이를 부드럽게 보간한 카메라
--   KenBurns.draw(image, camera, alpha) : camera.x·y = 화면 가운데에 올 그림 안 정규화 위치(0~1), zoom ≥ 1
--                                         → 그림 좌표(u, v) 를 화면 좌표로 바꾸는 함수를 돌려준다
-- 카메라가 그림 밖을 비추지 않도록 가장자리에서 멈춘다.

local Viewport = require("core.Viewport")

local KenBurns = {}

local function smooth(t)
    t = math.max(0, math.min(1, t))
    return t * t * (3 - 2 * t)
end

function KenBurns.camera_at(keys, t)
    if t <= keys[1].t then
        return keys[1]
    end
    for i = 1, #keys - 1 do
        local a, b = keys[i], keys[i + 1]
        if t <= b.t then
            local k = smooth((t - a.t) / (b.t - a.t))
            return { x = a.x + (b.x - a.x) * k, y = a.y + (b.y - a.y) * k, zoom = a.zoom + (b.zoom - a.zoom) * k }
        end
    end
    return keys[#keys]
end

function KenBurns.draw(image, camera, alpha)
    local sw, sh = Viewport.width(), Viewport.height()
    local iw, ih = image:getDimensions()
    local scale = math.max(sw / iw, sh / ih) * math.max(1, camera.zoom)
    local ox = math.min(0, math.max(sw - iw * scale, sw / 2 - camera.x * iw * scale))
    local oy = math.min(0, math.max(sh - ih * scale, sh / 2 - camera.y * ih * scale))
    love.graphics.setColor(1, 1, 1, alpha or 1)
    love.graphics.draw(image, ox, oy, 0, scale, scale)
    return function(u, v)
        return ox + u * iw * scale, oy + v * ih * scale
    end
end

return KenBurns
