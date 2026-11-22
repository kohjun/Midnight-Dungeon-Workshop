-- ui/MeshDeformer.lua
-- 원화 한 장을 4x6 격자 버텍스 메시(love.graphics.newMesh)로 나눠 꼭짓점을 실시간으로 움직인다 (수치 data/animations.lua).
--   MeshDeformer.draw(image, preset, time, key, region)
--     크기 1 상자(원점 중심)에 비율을 지켜 그린다 — SpriteBank.draw_unit 과 같은 좌표계라 뒤집기·반동·셰이더(흰 점멸 실루엣)와
--     그대로 합쳐진다. key = 메시를 따로 가질 대상(몬스터·초상 등, 약한 참조), region = 그림 일부(정규화 사각형, 생략하면 전체).
--   프리셋: breathe(호흡) · jelly(젤리 탄성) · float_cape(8자 부유 + 망토 물결) · heavy_mech(기계 진동 + 룬 명멸 가산 한 겹)
-- 메시를 만들 수 없거나 꺼져 있으면(set_enabled(false)) love.graphics.draw 로 그대로 그린다.

local ANIM = require("data.animations")

local MeshDeformer = {}

local LG = love.graphics
local COLS, ROWS = ANIM.mesh.cols, ANIM.mesh.rows
local PRESETS = ANIM.presets
local FULL = { x = 0, y = 0, w = 1, h = 1 }

local _meshes = setmetatable({}, { __mode = "k" })     -- key -> { image, region, mesh, verts, w, h }
local _quads = {}       -- 메시 없이 그림 일부를 그릴 때의 Quad
local _enabled = true
local _failed = false

function MeshDeformer.set_enabled(enabled)
    _enabled = enabled
end

function MeshDeformer.available()
    return _enabled and not _failed and LG.newMesh ~= nil
end

function MeshDeformer.vertex_count()
    return (COLS + 1) * (ROWS + 1)
end

local function bump(v, center, width)
    local d = (v - center) / width
    return math.exp(-d * d)
end

-- 꼭짓점 (격자 위치 u, v ∈ 0~1, v 는 위 0 → 아래 1) 의 이동량. w, h = 그림 크기(긴 변 1)
local DEFORM = {}

function DEFORM.breathe(spec, u, v, w, h, t)
    local s = math.sin(t * spec.speed)
    local lift = 1 - v                                      -- 발바닥(v = 1)은 움직이지 않는다
    local chest = bump(v, spec.chest, spec.chest_width) * lift
    local dx = (u - 0.5) * w * spec.swell * s * chest
    local dy = -spec.rise * h * (s * 0.5 + 0.5) * lift
    local head = math.max(0, 0.32 - v) / 0.32               -- 위쪽(머리)만 끄덕인다
    dx = dx + spec.nod * math.sin(t * spec.speed - 0.7) * head * h
    dy = dy + spec.nod * 0.5 * math.max(0, math.sin(t * spec.speed - 0.7)) * head * h
    return dx, dy
end

DEFORM.breathe_soft = DEFORM.breathe          -- 같은 동작, 작은 수치 (data/animations.lua)

function DEFORM.jelly(spec, u, v, w, h, t)
    local lift = 1 - v
    local dx = spec.sway * math.sin(t * spec.speed - lift * spec.lag) * lift * w
    local squash = spec.squash * math.sin(t * spec.speed * 2)
    return dx + (u - 0.5) * w * squash * lift * 0.8, squash * lift * h * 0.6
end

function DEFORM.float_cape(spec, u, v, w, h, t)
    local a = t * spec.speed
    local dx, dy = spec.drift_x * math.sin(a), spec.drift_y * math.sin(a * 2) * 0.5   -- 8자 궤적
    if v > spec.cape_from then
        local k = ((v - spec.cape_from) / (1 - spec.cape_from)) ^ 2
        dx = dx + spec.cape * math.sin(t * spec.wave + u * 3 + v * 4) * k * w
        dy = dy + spec.cape * 0.3 * math.sin(t * spec.wave * 0.7 + u * 5) * k * h
    end
    return dx, dy
end

function DEFORM.heavy_mech(spec, u, v, w, h, t)
    local lift = 1 - v
    local jx = spec.jitter * math.sin(t * spec.speed * 7.3 + v * 3) * lift
    local jy = spec.jitter * math.sin(t * spec.speed * 5.1 + u * 2)
    return jx * w, (jy - spec.settle * math.max(0, math.sin(t * spec.speed * 0.25)) * lift) * h
end

function MeshDeformer.has_preset(name)
    return DEFORM[name] ~= nil and PRESETS[name] ~= nil
end

local function build(image, region)
    local iw, ih = image:getDimensions()
    local rw, rh = region.w * iw, region.h * ih
    local s = 1 / math.max(rw, rh)
    local w, h = rw * s, rh * s
    local verts, map = {}, {}
    for r = 0, ROWS do
        for c = 0, COLS do
            local u, v = c / COLS, r / ROWS
            verts[#verts + 1] = { (u - 0.5) * w, (v - 0.5) * h, region.x + u * region.w, region.y + v * region.h, 1, 1, 1, 1 }
        end
    end
    for r = 0, ROWS - 1 do
        for c = 0, COLS - 1 do
            local i = r * (COLS + 1) + c + 1
            local below = i + COLS + 1
            map[#map + 1], map[#map + 2], map[#map + 3] = i, i + 1, below
            map[#map + 1], map[#map + 2], map[#map + 3] = i + 1, below + 1, below
        end
    end
    local ok, mesh = pcall(LG.newMesh, verts, "triangles", "stream")
    if not ok then
        _failed = true
        print("[MeshDeformer] mesh unavailable - drawing sprites flat: " .. tostring(mesh))
        return nil
    end
    mesh:setVertexMap(map)
    mesh:setTexture(image)
    return { image = image, region = region, mesh = mesh, verts = verts, w = w, h = h }
end

local function draw_flat(image, region)
    local iw, ih = image:getDimensions()
    local rw, rh = region.w * iw, region.h * ih
    local s = 1 / math.max(rw, rh)
    if region == FULL then
        LG.draw(image, -rw * s / 2, -rh * s / 2, 0, s, s)
    else
        local key = tostring(image) .. region.x .. ":" .. region.y
        local quad = _quads[key] or LG.newQuad(region.x * iw, region.y * ih, rw, rh, iw, ih)
        _quads[key] = quad
        LG.draw(image, quad, -rw * s / 2, -rh * s / 2, 0, s, s)
    end
end

-- 변형한 메시를 지금 색·셰이더로 그린다. heavy_mech 은 룬 명멸을 가산 혼합으로 한 겹 더 그린다
function MeshDeformer.draw(image, preset, time, key, region)
    region = region or FULL
    local spec, deform = PRESETS[preset], DEFORM[preset]
    if not MeshDeformer.available() or spec == nil or deform == nil then
        draw_flat(image, region)
        return
    end
    local entry = _meshes[key or image]
    if entry == nil or entry.image ~= image or entry.region ~= region then
        entry = build(image, region)
        if entry == nil then
            draw_flat(image, region)
            return
        end
        _meshes[key or image] = entry
    end
    local verts, w, h = entry.verts, entry.w, entry.h
    for r = 0, ROWS do
        for c = 0, COLS do
            local vert = verts[r * (COLS + 1) + c + 1]
            local u, v = c / COLS, r / ROWS
            local dx, dy = deform(spec, u, v, w, h, time)
            vert[1], vert[2] = (u - 0.5) * w + dx, (v - 0.5) * h + dy
        end
    end
    entry.mesh:setVertices(verts)
    LG.draw(entry.mesh)
    if spec.glow ~= nil then
        local r, g, b, a = LG.getColor()
        local pulse = 0.5 + 0.5 * math.sin(time * spec.glow_speed) * math.sin(time * spec.glow_speed * 2.7 + 1)
        LG.setBlendMode("add")
        LG.setColor(spec.glow_color[1], spec.glow_color[2], spec.glow_color[3], a * spec.glow * pulse)
        LG.draw(entry.mesh)
        LG.setBlendMode("alpha")
        LG.setColor(r, g, b, a)
    end
end

-- 개발 도구(스모크 테스트)용: key 의 지금 꼭짓점 좌표 목록 (메시가 없으면 nil)
function MeshDeformer.vertices(key)
    local entry = _meshes[key]
    return entry and entry.verts
end

return MeshDeformer
