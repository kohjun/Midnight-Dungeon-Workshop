-- ui/MonsterShapes.lua
-- 스프라이트가 없을 때 쓰는 몬스터 절차적 도형 (data/combat.lua 의 shape 이름). (x, y) 중심, r = 반경, step = 걷기 흔들림.
-- 색은 호출 측이 정한 몸통 색 body 를 쓴다. 눈·장식은 여기서 정한다. master = '스승의 흔적' 최종 보스(두건 대장장이 + 룬 망치).

local Draw = require("ui.Draw")

local MonsterShapes = {}

local LG = love.graphics
local EYE = { 1, 1, 1 }
local PUPIL = { 0.1, 0.05, 0.05 }
local RED_EYE = { 0.95, 0.25, 0.25 }
local STEEL = { 0.72, 0.74, 0.8 }
local BONE = { 0.9, 0.86, 0.74 }

local function eyes(x, y, r, color)
    Draw.set_color(color or EYE)
    LG.circle("fill", x - r * 0.45, y - r * 0.25, r * 0.16, 8)
    LG.circle("fill", x + r * 0.05, y - r * 0.25, r * 0.16, 8)
    if color == nil then
        Draw.set_color(PUPIL)
        LG.circle("fill", x - r * 0.5, y - r * 0.25, r * 0.08, 6)
        LG.circle("fill", x, y - r * 0.25, r * 0.08, 6)
    end
end

local SHAPES = {}

function SHAPES.slime(x, y, r, step, body)
    Draw.set_color(body)
    LG.ellipse("fill", x, y + step * 2, r * 1.1, r * (0.85 + step * 0.08), 20)
    eyes(x, y, r)
end

function SHAPES.goblin(x, y, r, step, body)
    Draw.set_color(body)
    LG.polygon("fill", x - r, y + r, x + r, y + r, x, y - r * 0.4)
    LG.circle("fill", x, y - r * 0.7 + step * 1.5, r * 0.55, 14)
    LG.polygon("fill", x - r * 0.5, y - r * 0.8, x - r * 1.1, y - r * 1.1, x - r * 0.4, y - r * 0.55)
    eyes(x, y - r * 0.5, r * 0.6, RED_EYE)
end

function SHAPES.ogre(x, y, r, step, body)
    Draw.set_color(body)
    LG.rectangle("fill", x - r, y - r * 0.8 + step, r * 2, r * 1.8, r * 0.4, r * 0.4)
    LG.circle("fill", x - r * 0.2, y - r * 1.05 + step, r * 0.45, 14)
    Draw.set_color({ 0.45, 0.3, 0.2 })
    LG.setLineWidth(5)
    LG.line(x - r * 0.9, y - r * 0.2, x - r * 1.5, y - r * 1.2 + step * 3)
    eyes(x, y, r)
end

function SHAPES.shield(x, y, r, step, body)          -- 중장갑 방패병: 앞에 든 큰 방패
    Draw.set_color(body)
    LG.rectangle("fill", x - r * 0.4, y - r * 0.9 + step, r * 1.2, r * 1.8, 4, 4)
    LG.circle("fill", x + r * 0.2, y - r * 1.1 + step, r * 0.4, 12)
    Draw.set_color(STEEL)
    LG.polygon("fill", x - r * 1.1, y - r * 0.9, x - r * 0.4, y - r * 1.0, x - r * 0.4, y + r * 0.9, x - r * 1.1, y + r * 0.7)
    Draw.set_color({ 0.3, 0.32, 0.38 })
    LG.setLineWidth(2)
    LG.line(x - r * 0.75, y - r * 0.8, x - r * 0.75, y + r * 0.7)
end

function SHAPES.assassin(x, y, r, step, body)        -- 그림자 암살자: 앞으로 숙인 날렵한 실루엣 + 단검
    Draw.set_color(body)
    LG.polygon("fill", x - r * 1.1, y - r * 0.2, x + r * 0.9, y - r * 0.6, x + r * 0.6, y + r, x - r * 0.4, y + r)
    LG.circle("fill", x - r * 0.8, y - r * 0.55 + step, r * 0.4, 12)
    Draw.set_color(STEEL)
    LG.setLineWidth(3)
    LG.line(x - r * 1.0, y + r * 0.2, x - r * 1.7, y + r * 0.05)
    eyes(x - r * 0.4, y - r * 0.4, r * 0.5, { 0.75, 0.6, 1.0 })
end

function SHAPES.skeleton(x, y, r, step, body)
    Draw.set_color(body)
    LG.circle("fill", x, y - r * 0.6 + step, r * 0.5, 12)
    LG.setLineWidth(3)
    LG.line(x, y - r * 0.1, x, y + r * 0.6)
    for i = 0, 2 do
        LG.line(x - r * 0.45, y + i * r * 0.22, x + r * 0.45, y + i * r * 0.22)
    end
    LG.line(x, y + r * 0.6, x - r * 0.4, y + r + step)
    LG.line(x, y + r * 0.6, x + r * 0.4, y + r - step)
    eyes(x + r * 0.2, y - r * 0.4, r * 0.5, { 0.1, 0.1, 0.1 })
end

function SHAPES.golem(x, y, r, step, body)           -- 던전 문지기 골렘: 바위 몸체 + 룬 눈
    Draw.set_color(body)
    LG.rectangle("fill", x - r, y - r * 0.9 + step, r * 2, r * 1.9, r * 0.3, r * 0.3)
    LG.rectangle("fill", x - r * 1.45, y - r * 0.5, r * 0.5, r * 1.3, 6, 6)
    LG.rectangle("fill", x + r * 0.95, y - r * 0.5, r * 0.5, r * 1.3, 6, 6)
    Draw.set_color({ 0.3, 0.28, 0.25 })
    LG.setLineWidth(2)
    LG.line(x - r * 0.6, y - r * 0.3, x + r * 0.2, y + r * 0.5)
    eyes(x, y, r, { 0.5, 0.9, 1.0 })
end

function SHAPES.raider(x, y, r, step, body)          -- 탐욕의 약탈자: 금화 자루를 멘 고블린 우두머리
    Draw.set_color({ 0.55, 0.38, 0.2 })
    LG.circle("fill", x + r * 0.7, y - r * 0.3, r * 0.75, 16)
    Draw.set_color(body)
    LG.polygon("fill", x - r, y + r, x + r * 0.6, y + r, x - r * 0.2, y - r * 0.6)
    LG.circle("fill", x - r * 0.3, y - r * 0.8 + step, r * 0.55, 14)
    Draw.set_color({ 1.0, 0.84, 0.3 })
    LG.circle("fill", x + r * 0.7, y - r * 1.0, r * 0.2, 10)
    eyes(x - r * 0.3, y - r * 0.6, r * 0.6, RED_EYE)
end

function SHAPES.necro(x, y, r, step, body)           -- 심연의 사령술사: 두건 로브 + 해골 지팡이
    Draw.set_color(body)
    LG.polygon("fill", x - r, y + r, x + r, y + r, x + r * 0.4, y - r * 0.7, x - r * 0.4, y - r * 0.7)
    LG.circle("fill", x, y - r * 0.85 + step, r * 0.5, 14)
    Draw.set_color({ 0.35, 0.25, 0.2 })
    LG.setLineWidth(4)
    LG.line(x - r * 1.1, y + r, x - r * 1.1, y - r * 1.4)
    Draw.set_color(BONE)
    LG.circle("fill", x - r * 1.1, y - r * 1.5, r * 0.22, 10)
    eyes(x, y - r * 0.6, r * 0.6, { 0.4, 1.0, 0.5 })
end

function SHAPES.rift(x, y, r, step, body)            -- 차원의 균열 군주: 균열이 갈라진 거대한 왕관 형체
    Draw.set_color(body)
    LG.polygon("fill", x - r, y + r, x + r, y + r, x + r * 0.8, y - r * 0.6, x - r * 0.8, y - r * 0.6)
    for i = -1, 1 do
        LG.polygon("fill", x + i * r * 0.55 - r * 0.2, y - r * 0.6, x + i * r * 0.55, y - r * 1.5 + step, x + i * r * 0.55 + r * 0.2, y - r * 0.6)
    end
    Draw.set_color({ 0.85, 0.6, 1.0 })
    LG.setLineWidth(3)
    LG.line(x - r * 0.2, y - r * 0.5, x + r * 0.1, y, x - r * 0.15, y + r * 0.5)
    eyes(x, y - r * 0.1, r * 0.8, { 1, 0.85, 1 })
end

function SHAPES.master(x, y, r, step, body)         -- 균열의 잔영: 두건 쓴 대장장이 + 왼쪽(방벽)으로 치켜든 룬 망치
    Draw.set_color(body)
    LG.polygon("fill", x - r * 0.95, y + r, x + r * 0.95, y + r, x + r * 0.5, y - r * 0.55, x - r * 0.5, y - r * 0.55)
    LG.circle("fill", x, y - r * 0.85 + step, r * 0.5, 14)
    Draw.set_color({ 0.30, 0.24, 0.22 })            -- 망치 자루
    LG.setLineWidth(r * 0.16)
    LG.line(x + r * 0.35, y + r * 0.15, x - r * 1.05, y - r * 0.95)
    local hx, hy = x - r * 1.15, y - r * 1.05        -- 망치 머리 (자루와 직각으로 기운 사각형)
    local ux, uy, vx, vy = 0.71 * r * 0.42, -0.71 * r * 0.42, 0.71 * r * 0.26, 0.71 * r * 0.26
    Draw.set_color({ 0.40, 0.36, 0.40 })
    LG.polygon("fill", hx - ux - vx, hy - uy - vy, hx + ux - vx, hy + uy - vy, hx + ux + vx, hy + uy + vy, hx - ux + vx, hy - uy + vy)
    Draw.set_color({ 0.85, 0.40, 1.0 })              -- 망치의 룬 · 망토 자락의 균열 빛
    LG.setLineWidth(2)
    LG.line(hx - ux * 0.5, hy - uy * 0.5, hx + ux * 0.5, hy + uy * 0.5)
    LG.line(x - r * 0.6, y + r * 0.6, x - r * 0.35, y + r * 0.95)
    LG.line(x + r * 0.55, y + r * 0.5, x + r * 0.7, y + r * 0.95)
    eyes(x, y - r * 0.7 + step, r * 0.55, { 0.85, 0.5, 1.0 })
end

function MonsterShapes.has(shape)
    return SHAPES[shape] ~= nil
end

function MonsterShapes.draw(shape, x, y, r, step, body)
    local fn = SHAPES[shape] or SHAPES.ogre
    fn(x, y, r, step, body)
end

return MonsterShapes
