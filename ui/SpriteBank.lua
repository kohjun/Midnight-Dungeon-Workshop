-- ui/SpriteBank.lua
-- assets/sprites/ 의 PNG(유물 아이콘 · 몬스터 · 모험가 초상 · 작업대 텍스처 · 장면 아트)를 지연 로드해 그린다.
--   어떤 이름을 어떤 보정값과 쓸지(원화 → 생성 스프라이트 → 없음)와 기대 이름 목록은 ui/SpriteCatalog.
--   그림은 가로세로 비율을 지킨 채 크기 1 상자에 맞춰 그린다 (정사각형이 아니어도 찌그러지지 않는다).
-- 유물: 그림자 + 등급별 테두리 글로우 + 발사 반동 / 몬스터: 피격 반동·흰색 점멸 — 반동은 kick(obj) 로 시작하는 트윈이다.
-- 파일이 없으면 image() 가 nil 을 반환하고, 호출 측(ItemRenderer · LaneView · 패널)은 기존 도형 렌더링으로 폴백한다.

local Tween = require("lib.tween")
local MeshDeformer = require("ui.MeshDeformer")

local SpriteBank = {}

local LG = love.graphics
local DIRECTORY = "assets/sprites/"
local MASK_THRESHOLD = 0.5          -- 스텐실용 실루엣 (불투명한 부분만)
local SILHOUETTE_THRESHOLD = 0.02
local GLOW_STEPS = 10
local KICK_TIME = 0.24
-- 텍스처 알파를 마스크로 쓰는 단색 실루엣 셰이더 (그림자 · 글로우 · 흰색 점멸 · 스텐실 · UV 투시)
local SILHOUETTE_SHADER = [[
    extern number threshold;
    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen)
    {
        number alpha = Texel(tex, uv).a;
        if (alpha < threshold) { discard; }
        return vec4(color.rgb, color.a * alpha);
    }
]]

local _images = {}      -- name -> Image | false (없음)
local _quads = {}
local _shader = nil
local _shader_failed = false
local _enabled = true
local _kicks = setmetatable({}, { __mode = "k" })   -- obj -> { value, job }
local _tweens = Tween.Group()
local NO_POSE = {}

local function shader()
    if _shader == nil and not _shader_failed then
        local ok, result = pcall(LG.newShader, SILHOUETTE_SHADER)
        if ok then
            _shader = result
        else
            _shader_failed = true
            print("[SpriteBank] silhouette shader unavailable - sprites disabled: " .. tostring(result))
        end
    end
    return _shader
end

-- name: 확장자 없는 파일 이름. 없거나 읽지 못하면 nil (한 번만 시도한다)
function SpriteBank.image(name)
    if not _enabled or shader() == nil then
        return nil
    end
    local image = _images[name]
    if image == nil then
        image = false
        local path = DIRECTORY .. name .. ".png"
        if love.filesystem.getInfo(path) ~= nil then
            local ok, loaded = pcall(LG.newImage, path, { mipmaps = true })
            if ok then
                image = loaded
                image:setFilter("linear", "linear")
            else
                print("[SpriteBank] failed to load " .. path .. ": " .. tostring(loaded))
            end
        end
        _images[name] = image
    end
    return image or nil
end

-- false 면 스프라이트를 쓰지 않는다 (도형 폴백 경로 검증용)
function SpriteBank.set_enabled(enabled)
    _enabled = enabled
end

-- 반동 시작: value 1 → 0 (out_back 이라 끝에서 살짝 되튄다). 유물 발사 · 몬스터 피격에 쓴다
-- dir_x, dir_y: 반동이 밀리는 방향 (단위 벡터, 생략하면 아래쪽) — 무기는 발사 반대 방향으로 밀린다
function SpriteBank.kick(obj, strength, dir_x, dir_y)
    local state = _kicks[obj]
    if state == nil then
        state = { value = 0 }
        _kicks[obj] = state
    end
    if state.job ~= nil then
        state.job:stop()
    end
    state.dx, state.dy = dir_x or 0, dir_y or 1
    state.value = strength or 1
    state.job = _tweens:to(state, KICK_TIME, { value = 0 }):ease("out_back")
end

-- 내려놓기 튕김: value 1 → 0 (out_elastic). 유물을 칸에 놓을 때 살짝 커졌다 자리 잡는다
function SpriteBank.pop(obj)
    SpriteBank.kick(obj, -0.9)
end

function SpriteBank.kick_value(obj)
    local state = _kicks[obj]
    return state and state.value or 0
end

-- 반동 방향 (단위 벡터, 기본 아래쪽)
function SpriteBank.kick_dir(obj)
    local state = _kicks[obj]
    return state and state.dx or 0, state and state.dy or 1
end

function SpriteBank.update(dt)
    _tweens:update(dt)
end

-- 크기 1 상자(원점 중심)에 비율을 지켜 맞춘다
local function draw_unit(image)
    local w, h = image:getDimensions()
    local s = 1 / math.max(w, h)
    LG.draw(image, -w * s / 2, -h * s / 2, 0, s, s)
end

SpriteBank.draw_unit = draw_unit

-- 장면용: (cx, cy) 중심, 긴 변이 size 가 되도록. opts: { alpha, flip, color }
function SpriteBank.draw_fit(image, cx, cy, size, opts)
    opts = opts or {}
    local color = opts.color or { 1, 1, 1 }
    LG.push()
    LG.translate(cx, cy)
    LG.scale(opts.flip and -size or size, size)
    LG.setColor(color[1], color[2], color[3], opts.alpha or 1)
    draw_unit(image)
    LG.pop()
end

-- 그림의 일부(정규화 사각형 region)를 (x, y, w, h) 에 그린다 (주인장 얼굴 초상 등)
function SpriteBank.draw_region(image, region, x, y, w, h, alpha)
    local iw, ih = image:getDimensions()
    local key = tostring(image) .. region.x .. region.y
    local quad = _quads[key]
    if quad == nil then
        quad = LG.newQuad(region.x * iw, region.y * ih, region.w * iw, region.h * ih, iw, ih)
        _quads[key] = quad
    end
    LG.setColor(1, 1, 1, alpha or 1)
    LG.draw(image, quad, x, y, 0, w / (region.w * iw), h / (region.h * ih))
end

-- 현재 색의 단색 실루엣 (크기 1, 원점 중심). mask = true 면 스텐실용으로 불투명한 부분만
function SpriteBank.draw_silhouette(image, mask)
    local effect = shader()
    effect:send("threshold", mask and MASK_THRESHOLD or SILHOUETTE_THRESHOLD)
    LG.setShader(effect)
    draw_unit(image)
    LG.setShader()
end

-- 유물 스프라이트 (크기 1, 원점 중심 — 호출 측이 translate/scale 을 건 상태). glow: 등급 색 {r,g,b} 또는 nil
function SpriteBank.draw_item(image, glow, glow_alpha)
    LG.setColor(0, 0, 0, 0.4)
    LG.push()
    LG.translate(0.035, 0.05)
    SpriteBank.draw_silhouette(image)
    LG.pop()
    if glow ~= nil then
        for i = 1, GLOW_STEPS do
            local angle = i / GLOW_STEPS * math.pi * 2
            local radius = (i % 2 == 0) and 0.03 or 0.055
            LG.setColor(glow[1], glow[2], glow[3], glow_alpha * ((i % 2 == 0) and 1 or 0.5))
            LG.push()
            LG.translate(math.cos(angle) * radius, math.sin(angle) * radius)
            SpriteBank.draw_silhouette(image)
            LG.pop()
        end
    end
    LG.setColor(1, 1, 1, 1)
    draw_unit(image)
end

-- 몬스터 스프라이트: (x, y) 중심·size 크기, tint 색 곱, flash 면 흰색 실루엣.
-- art: data/art.lua 의 보정 (flip · scale) 또는 nil.
-- pose: ui/EntityMotion 의 포즈 { dx, dy, rot, sx, sy, alpha, deform, time, glow_color, glow_alpha } 또는 nil.
--       deform 이 있으면 ui/MeshDeformer 로 격자 메시를 변형해 그린다 (뒤집기·흰 점멸 셰이더와 그대로 합쳐진다)
function SpriteBank.draw_monster(image, monster, x, y, size, tint, flash, art, pose)
    pose = pose or NO_POSE
    size = size * (art and art.scale or 1)
    local flip = (art and art.flip) and -1 or 1
    local function paint()
        if pose.deform ~= nil then
            MeshDeformer.draw(image, pose.deform, pose.time or 0, monster)
        else
            draw_unit(image)
        end
    end
    LG.push()
    LG.translate(x + (pose.dx or 0), y + (pose.dy or 0))
    LG.rotate(pose.rot or 0)
    LG.scale(flip * size * (pose.sx or 1), size * (pose.sy or 1))
    local alpha = pose.alpha or 1
    if flash then
        LG.setColor(1, 1, 1, alpha)
        LG.setShader(shader())
        shader():send("threshold", SILHOUETTE_THRESHOLD)
        paint()
        LG.setShader()
    else
        LG.setColor(tint[1], tint[2], tint[3], alpha)
        paint()
    end
    if (pose.glow_alpha or 0) > 0.01 then          -- 방벽 공격 예비 동작의 붉은 기운
        local glow = pose.glow_color
        LG.setBlendMode("add")
        LG.setColor(glow[1], glow[2], glow[3], 0.55 * pose.glow_alpha * alpha)
        paint()
        LG.setBlendMode("alpha")
    end
    LG.pop()
end

-- 둥근 사각형 영역을 반복 텍스처로 덮는다. 텍스처가 없으면 false (호출 측의 단색 패널이 그대로 보인다)
function SpriteBank.draw_texture(name, x, y, w, h, radius, alpha)
    local image = SpriteBank.image("tex_" .. name)
    if image == nil then
        return false
    end
    local key = name .. ":" .. w .. "x" .. h
    local quad = _quads[key]
    if quad == nil then
        image:setWrap("repeat", "repeat")
        quad = LG.newQuad(0, 0, w, h, image:getWidth(), image:getHeight())
        _quads[key] = quad
    end
    LG.stencil(function()
        LG.rectangle("fill", x, y, w, h, radius, radius)
    end, "replace", 1)
    LG.setStencilTest("greater", 0)
    LG.setColor(1, 1, 1, alpha or 1)
    LG.draw(image, quad, x, y)
    LG.setStencilTest()
    return true
end

return SpriteBank
