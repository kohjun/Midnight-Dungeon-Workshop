-- ui/LaneHeroArt.lua
-- 밤 전투 레인 주인공의 그림 (ui/LaneHero 의 상태를 받아 그린다 · 인트로 circuit 장면도 같은 그림을 쓴다 — 규칙 계산 없음).
--   figure : 포즈 원화(protagonist_idle · attack · block — data/art.lua 의 hero, 세 포즈 같은 배율 · 발바닥 가운데 고정)
--            + 접지 그림자 + 망치 끝·건틀릿의 속성 오라 + 유물이 쏠 때 스치는 황금 마력 섬광. 원화가 없으면 코드 실루엣
--            (두건 · 가죽 앞치마 · 공명 건틀릿 · 룬 망치 — 같은 기준점으로 포즈를 잡는다)
--   wave   : 동조 투사 — 건틀릿에서 앞으로 퍼지는 마력 파동
--   smash  : 근접 내려찍기 — 마물 위에서 아래로 긋는 망치 궤적 호 + 충격 고리
--   shield : 방어 — 몸 앞에 서는 황금 룬 방패 파동
-- 좌표: x = 발 중심, ground_y = 발바닥, height = 대기 포즈의 키(px).

local Draw = require("ui.Draw")
local SpriteBank = require("ui.SpriteBank")
local ART = require("data.art")
local ANIM = require("data.animations")

local LaneHeroArt = {}

local LG = love.graphics
local HERO = ART.hero
local SPEC = ANIM.hero
local INK = { 0.04, 0.03, 0.04 }
local CLOTH = { 0.24, 0.17, 0.14 }
local APRON = { 0.40, 0.23, 0.16 }
local IRON = { 0.36, 0.36, 0.41 }
local BRASS = { 0.82, 0.64, 0.30 }
local SKIN = { 0.62, 0.45, 0.34 }
local WHITE = { 1, 1, 1 }

-- 그 포즈 그림이 화면에 놓이는 상자: left, top, w, h, image(없으면 nil), scale
function LaneHeroArt.box(pose, x, ground_y, height)
    local base = SpriteBank.image(HERO.poses.idle.sprite)
    local image = SpriteBank.image(HERO.poses[pose].sprite)
    if image == nil or base == nil then
        local w = height * HERO.aspect
        return x - w / 2, ground_y - height, w, height, nil, 1
    end
    local scale = height / (base:getHeight() - HERO.pad * 2)
    local w, h = image:getWidth() * scale, image:getHeight() * scale
    return x - w / 2, ground_y - h + HERO.pad * scale, w, h, image, scale
end

-- 포즈의 기준점("hammer" | "gauntlet") 화면 좌표
function LaneHeroArt.point(pose, name, x, ground_y, height)
    local left, top, w, h = LaneHeroArt.box(pose, x, ground_y, height)
    local spot = HERO.poses[pose][name]
    return left + spot.x * w, top + spot.y * h
end

local function quad(color, ...)
    Draw.set_color(color)
    LG.polygon("fill", ...)
end

-- 원화가 없을 때: 코드로 그린 감정사 (상자 left, top, w, h 안의 비율 좌표)
local function silhouette(pose, left, top, w, h)
    local function px(u) return left + u * w end
    local function py(v) return top + v * h end
    local spots = HERO.poses[pose]
    local hx, hy, gx, gy = px(spots.hammer.x), py(spots.hammer.y), px(spots.gauntlet.x), py(spots.gauntlet.y)
    local shoulder_x, shoulder_y = px(0.52), py(0.30)
    LG.setLineJoin("bevel")
    for pass = 1, 2 do                                -- 굵은 먹 외곽선 → 채움
        local ink = pass == 1
        local grow = ink and 3 or 0
        quad(ink and INK or CLOTH, px(0.30) - grow, py(0.62), px(0.46), py(0.62), px(0.42), py(1) + grow, px(0.20) - grow, py(1) + grow)
        quad(ink and INK or CLOTH, px(0.54), py(0.62), px(0.72) + grow, py(0.62), px(0.84) + grow, py(1) + grow, px(0.62), py(1) + grow)
        quad(ink and INK or CLOTH, px(0.26) - grow, py(0.26) - grow, px(0.74) + grow, py(0.26) - grow, px(0.78) + grow, py(0.68) + grow,
            px(0.24) - grow, py(0.68) + grow)
        quad(ink and INK or APRON, px(0.36) - grow, py(0.34), px(0.66) + grow, py(0.34), px(0.70) + grow, py(0.86) + grow, px(0.32) - grow,
            py(0.86) + grow)
        Draw.set_color(ink and INK or CLOTH)          -- 두건
        LG.circle("fill", px(0.52), py(0.15), h * 0.13 + grow, 20)
        LG.polygon("fill", px(0.40) - grow, py(0.16), px(0.50), py(0.0) - grow, px(0.66) + grow, py(0.20))
        Draw.set_color(ink and INK or CLOTH)          -- 팔 (어깨 → 건틀릿, 어깨 → 망치 자루)
        LG.setLineWidth(h * 0.085 + grow * 2)
        LG.line(shoulder_x, shoulder_y, gx, gy)
        LG.line(px(0.36), py(0.34), px(0.36) + (hx - px(0.36)) * 0.45, py(0.34) + (hy - py(0.34)) * 0.6)
        Draw.set_color(ink and INK or { 0.33, 0.22, 0.12 })     -- 망치 자루 + 머리
        LG.setLineWidth(h * 0.035 + grow * 2)
        LG.line(px(0.36) + (hx - px(0.36)) * 0.2, py(0.34) + (hy - py(0.34)) * 0.75, hx, hy)
        Draw.set_color(ink and INK or IRON)
        LG.rectangle("fill", hx - h * 0.075 - grow, hy - h * 0.055 - grow, h * 0.15 + grow * 2, h * 0.11 + grow * 2, 3, 3)
        Draw.set_color(ink and INK or BRASS)          -- 공명 건틀릿
        LG.circle("fill", gx, gy, h * 0.055 + grow, 14)
    end
    Draw.set_color(SKIN)
    LG.circle("fill", px(0.56), py(0.17), h * 0.055, 14)
    Draw.set_color({ 0.55, 0.95, 0.80 }, 0.9)         -- 건틀릿 · 망치의 룬
    LG.setLineWidth(1.5)
    LG.line(gx - 3, gy, gx + 3, gy)
    LG.line(hx - 3, hy - 3, hx + 3, hy + 3)
end

-- opts: { dx = 앞뒤 밀림, breathe = 호흡 세로 배율, aura = 속성 색, flash = 0~1 황금 섬광, alpha }
function LaneHeroArt.figure(pose, x, ground_y, height, time, opts)
    opts = opts or {}
    local alpha = opts.alpha or 1
    local cx = x + (opts.dx or 0)
    local left, top, w, h, image, scale = LaneHeroArt.box(pose, cx, ground_y, height)
    Draw.set_color({ 0, 0, 0 }, 0.5 * alpha)          -- 얇은 접지 그림자
    LG.ellipse("fill", cx, ground_y + 1, HERO.shadow_w * height / HERO.height * 0.5, 6 * height / HERO.height, 28)
    local hx, hy = LaneHeroArt.point(pose, "hammer", cx, ground_y, height)
    local gx, gy = LaneHeroArt.point(pose, "gauntlet", cx, ground_y, height)
    local aura = opts.aura or SPEC.default_color
    local pulse = SPEC.aura.alpha * (0.75 + 0.25 * math.sin(time * SPEC.aura.pulse)) * alpha
    Draw.glow(cx, ground_y - height * 0.52, height * SPEC.aura.back_radius, aura, SPEC.aura.back * alpha)   -- 어두운 돌길에서 떠 보이게
    Draw.glow(hx, hy, height * SPEC.aura.radius, aura, pulse)
    Draw.glow(gx, gy, height * SPEC.aura.radius * 0.85, aura, pulse)
    local breathe = 1 + (opts.breathe or 0)
    if image ~= nil then
        local iw, ih = image:getDimensions()
        LG.setColor(1, 1, 1, alpha)
        LG.draw(image, cx, ground_y + HERO.pad * scale, 0, scale, scale * breathe, iw / 2, ih)
        if (opts.flash or 0) > 0 then                 -- 황금 마력 섬광: 그림 전체가 잠깐 금빛으로
            LG.setBlendMode("add")
            Draw.set_color(SPEC.gold, 0.42 * opts.flash * alpha)
            LG.draw(image, cx, ground_y + HERO.pad * scale, 0, scale, scale * breathe, iw / 2, ih)
            LG.setBlendMode("alpha")
        end
    else
        silhouette(pose, left, top + h * (1 - breathe), w, h * breathe)
    end
    local front = pulse * SPEC.aura.front              -- 그림 위에 얹는 오라: 망치 끝과 건틀릿의 룬이 속성 색으로 빛난다
    Draw.glow(hx, hy, height * SPEC.aura.radius * 0.55, aura, front)
    Draw.glow(gx, gy, height * SPEC.aura.radius * 0.5, aura, front)
    if (opts.flash or 0) > 0 then                     -- 건틀릿 · 망치 끝에 맺히는 금빛
        Draw.glow(gx, gy, height * 0.26, SPEC.gold, 0.8 * opts.flash * alpha)
        Draw.glow(hx, hy, height * 0.2, SPEC.gold, 0.6 * opts.flash * alpha)
    end
    return gx, gy, hx, hy
end

-- 동조 투사 파동: (x, y) 에서 오른쪽으로 퍼지는 호. k = 0 → 1
function LaneHeroArt.wave(x, y, k, color, reach)
    local radius = 12 + reach * (1 - (1 - k) * (1 - k))
    local alpha = 1 - k
    LG.setBlendMode("add")
    for i = 0, 1 do
        local r = radius - i * 16
        if r > 6 then
            Draw.set_color(color, 0.5 * alpha * (1 - i * 0.45))
            LG.setLineWidth(7 - i * 3)
            LG.arc("line", "open", x - r * 0.25, y, r, -0.62, 0.62, 20)
            Draw.set_color(Draw.lerp_color(color, WHITE, 0.7), 0.85 * alpha * (1 - i * 0.45))
            LG.setLineWidth(2)
            LG.arc("line", "open", x - r * 0.25, y, r, -0.55, 0.55, 20)
        end
    end
    LG.setBlendMode("alpha")
end

-- 근접 망치 내려찍기: 마물 (x, y) 위에서 아래로 긋는 궤적 호 + 충격 고리. size = 마물 그림 반지름, k = 0 → 1
function LaneHeroArt.smash(x, y, size, k, color)
    local r = size * SPEC.melee.arc_radius
    local sweep = math.min(1, k / 0.45)                        -- 빠르게 내려긋고
    local alpha = k < 0.45 and 1 or 1 - (k - 0.45) / 0.55     -- 천천히 사라진다
    local from, to = -2.5, -2.5 + 2.9 * sweep
    LG.setBlendMode("add")
    Draw.set_color(color, 0.55 * alpha)
    LG.setLineWidth(11)
    LG.arc("line", "open", x - r * 0.35, y, r, from, to, 24)
    Draw.set_color(Draw.lerp_color(SPEC.gold, WHITE, 0.6), 0.95 * alpha)
    LG.setLineWidth(4)
    LG.arc("line", "open", x - r * 0.35, y, r, from, to, 24)
    if k > 0.3 then                                            -- 내려찍힌 자리의 충격 고리
        local ring = (k - 0.3) / 0.7
        Draw.set_color(SPEC.gold, 0.8 * (1 - ring))
        LG.setLineWidth(3)
        LG.ellipse("line", x, y + size * 0.55, size * (0.5 + 1.1 * ring), size * (0.18 + 0.3 * ring), 24)
    end
    LG.setBlendMode("alpha")
end

-- 황금 룬 방패 파동: (x, y) = 몸 앞 가슴 높이. k = 0 → 1
function LaneHeroArt.shield(x, y, k, radius, time)
    local alpha = (1 - k) * (1 - k)
    local r = radius * (0.82 + 0.3 * k)
    LG.setBlendMode("add")
    Draw.set_color(SPEC.gold, 0.16 * alpha)
    LG.arc("fill", "pie", x - r * 0.45, y, r, -1.15, 1.15, 24)
    Draw.set_color(SPEC.gold, 0.9 * alpha)
    LG.setLineWidth(5)
    LG.arc("line", "open", x - r * 0.45, y, r, -1.15, 1.15, 28)
    Draw.set_color(WHITE, 0.9 * alpha)
    LG.setLineWidth(2)
    LG.arc("line", "open", x - r * 0.45, y, r - 6, -1.0, 1.0, 28)
    for i = -2, 2 do                                  -- 방패 테두리의 룬 (작은 마름모)
        local a = i * 0.42 + math.sin(time * 2) * 0.03
        local rx, ry = x - r * 0.45 + math.cos(a) * (r + 9), y + math.sin(a) * (r + 9)
        Draw.set_color(SPEC.gold, alpha)
        LG.polygon("fill", rx, ry - 5, rx + 4, ry, rx, ry + 5, rx - 4, ry)
    end
    LG.setBlendMode("alpha")
end

return LaneHeroArt
