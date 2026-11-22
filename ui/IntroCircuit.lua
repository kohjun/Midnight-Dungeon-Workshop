-- ui/IntroCircuit.lua
-- 인트로 6장면 circuit — 스승이 진열장 아래 심어 둔 공명 회로 (시간표 data/intro.lua 의 circuit · 배치 data/circuit.lua 의 intro):
--   일러스트(assets/backgrounds/intro_circuit.png)가 있으면 켄 번스 + 은은한 황금 숨결과 떠도는 마력 먼지.
--   없으면 공방 실내 그림(fallback)을 어둡게 덮고 황금색 회로 틴트를 얹은 뒤, 코드로 그린 회로판을 보여 준다 —
--     25칸의 철제·황동 소켓이 상하좌우 마력 도선으로 이어져 가운데에서 바깥으로 점등되고,
--     두 번째 내레이션부터 그 마력이 문 앞의 주인공(공명 건틀릿과 망치 — ui/LaneHeroArt)에게 흘러든다.
--   그 그림도 없으면 어두운 바탕 위에 같은 회로판 (크래시 금지).

local Class = require("lib.classic")
local RNG = require("core.RNG")
local Viewport = require("core.Viewport")
local Draw = require("ui.Draw")
local KenBurns = require("ui.KenBurns")
local RoomBackdrop = require("ui.RoomBackdrop")
local LaneHeroArt = require("ui.LaneHeroArt")
local INTRO = require("data.intro")
local CIRCUIT = require("data.circuit")

local IntroCircuit = Class:extend()

local LG = love.graphics
local SCENE = INTRO.circuit
local SPEC = CIRCUIT.intro
local LINE = CIRCUIT.conduit
local SIZE = 5
local MOTES = 26
local PLATE = { 0.07, 0.055, 0.05 }
local IRON = { 0.20, 0.19, 0.21 }

local function clamp01(v)
    return math.max(0, math.min(1, v))
end

local function start_time()
    for _, stage in ipairs(INTRO.stages) do
        if stage.id == "circuit" then
            return stage.start
        end
    end
    return 0
end

function IntroCircuit:new()
    self._start = start_time()
    self._image = nil
    if love.filesystem.getInfo(SCENE.image) ~= nil then
        local ok, image = pcall(LG.newImage, SCENE.image, { mipmaps = true })
        if ok then
            image:setFilter("linear", "linear")
            self._image = image
        else
            print("[IntroCircuit] failed to load " .. SCENE.image .. ": " .. tostring(image))
        end
    end
    self._fallback = self._image == nil and RoomBackdrop.load(SCENE.fallback) or nil
    local rng = RNG.stream("fx")
    self._motes = {}
    for i = 1, MOTES do
        self._motes[i] = { u = rng:float(0.05, 0.95), v = rng:float(0.15, 0.8), speed = rng:float(0.01, 0.03), phase = rng:float(0, 6.28) }
    end
end

-- "illustration" | "fallback" | "code" (개발 도구용)
function IntroCircuit:kind()
    return self._image and "illustration" or (self._fallback and "fallback" or "code")
end

-- 떠도는 황금 마력 먼지 + 화면 가운데의 은은한 숨결
function IntroCircuit:_light(t, strength)
    local sw, sh = Viewport.width(), Viewport.height()
    Draw.glow(sw * 0.5, sh * 0.48, sh * 0.62, SPEC.tint, strength * (0.10 + 0.04 * math.sin(t * 1.8)))
    LG.setBlendMode("add")
    for i, mote in ipairs(self._motes) do
        local v = (mote.v - t * mote.speed) % 0.8 + 0.1
        local u = mote.u + math.sin(t * 0.7 + mote.phase) * 0.012
        Draw.set_color(LINE.mana, strength * (0.25 + 0.25 * math.sin(t * 2 + i)))
        LG.circle("fill", u * sw, v * sh, 1.6, 6)
    end
    LG.setBlendMode("alpha")
end

local function socket_at(row, col)
    local sw, sh = Viewport.width(), Viewport.height()
    local half = (SIZE + 1) / 2
    return sw * SPEC.board.x + (col - half) * SPEC.board.spacing, sh * SPEC.board.y + (row - half) * SPEC.board.spacing
end

-- 가운데 소켓에서 dist 칸 떨어진 곳이 켜진 정도 0~1
local function lit(t, dist)
    return clamp01((t - 0.5 - dist * SPEC.ignite_step) / 0.35)
end

local function dist_of(row, col)
    local half = (SIZE + 1) / 2
    return math.abs(row - half) + math.abs(col - half)
end

-- 코드 회로판: 받침판 → 도선 → 소켓
local function draw_board(t)
    local r = SPEC.board.socket
    local x0, y0 = socket_at(1, 1)
    local span = SPEC.board.spacing * (SIZE - 1)
    Draw.set_color({ 0, 0, 0 }, 0.5)
    LG.rectangle("fill", x0 - r * 2 + 6, y0 - r * 2 + 8, span + r * 4, span + r * 4, 14, 14)
    Draw.set_color(PLATE, 0.96)
    LG.rectangle("fill", x0 - r * 2, y0 - r * 2, span + r * 4, span + r * 4, 14, 14)
    Draw.set_color(LINE.brass, 0.8)
    LG.setLineWidth(3)
    LG.rectangle("line", x0 - r * 2, y0 - r * 2, span + r * 4, span + r * 4, 14, 14)
    local glows = {}
    for row = 1, SIZE do
        for col = 1, SIZE do
            local x, y = socket_at(row, col)
            for _, step in ipairs({ { 0, 1 }, { 1, 0 } }) do
                local nr, nc = row + step[1], col + step[2]
                if nr <= SIZE and nc <= SIZE then
                    local nx, ny = socket_at(nr, nc)
                    Draw.set_color(LINE.dark)
                    LG.setLineWidth(9)
                    LG.line(x, y, nx, ny)
                    Draw.set_color(LINE.brass)
                    LG.setLineWidth(5)
                    LG.line(x, y, nx, ny)
                    local on = lit(t, math.max(dist_of(row, col), dist_of(nr, nc)))
                    if on > 0 then
                        glows[#glows + 1] = { x, y, nx, ny, on, row * 5 + col + step[1] * 0.5 }
                    end
                end
            end
        end
    end
    LG.setBlendMode("add")
    for _, g in ipairs(glows) do                     -- 도선을 타고 흐르는 황금빛 마력
        local beat = 0.6 + 0.4 * math.sin(t * 3 + g[6])
        Draw.set_color(LINE.mana, 0.4 * g[5] * beat)
        LG.setLineWidth(13)
        LG.line(g[1], g[2], g[3], g[4])
        Draw.set_color({ 1, 0.96, 0.8 }, 0.9 * g[5] * beat)
        LG.setLineWidth(2.5)
        LG.line(g[1], g[2], g[3], g[4])
        local k = (t * 0.8 + g[6] * 0.37) % 1
        Draw.set_color({ 1, 1, 1 }, g[5])
        LG.circle("fill", g[1] + (g[3] - g[1]) * k, g[2] + (g[4] - g[2]) * k, 3.2, 8)
    end
    LG.setBlendMode("alpha")
    for row = 1, SIZE do
        for col = 1, SIZE do                         -- 철제 테 + 황동 소켓
            local x, y = socket_at(row, col)
            local on = lit(t, dist_of(row, col))
            Draw.set_color(LINE.dark)
            LG.circle("fill", x, y, r + 3, 24)
            Draw.set_color(IRON)
            LG.circle("fill", x, y, r, 24)
            Draw.set_color(LINE.brass)
            LG.setLineWidth(3)
            LG.circle("line", x, y, r * 0.62, 20)
            Draw.set_color(Draw.lerp_color(PLATE, LINE.mana, on), 1)
            LG.circle("fill", x, y, r * 0.42, 16)
            if on > 0 then
                Draw.glow(x, y, r * 2.1, LINE.mana, 0.5 * on * (0.75 + 0.25 * math.sin(t * 4 + row + col)))
            end
        end
    end
end

-- 문 앞의 주인공과, 회로판 오른쪽 줄에서 건틀릿으로 흘러드는 마력
local function draw_hero(t)
    local sw, sh = Viewport.width(), Viewport.height()
    local x, ground, height = sw * SPEC.hero.x, sh * SPEC.hero.ground, SPEC.hero.height
    local flow = clamp01((t - SPEC.flow_at) / 0.8)
    local appear = clamp01((t - 0.4) / 0.9)
    local gx, gy = LaneHeroArt.point("idle", "gauntlet", x, ground, height)
    if flow > 0 then
        LG.setBlendMode("add")
        for row = 1, SIZE do
            local sx, sy = socket_at(row, SIZE)
            local mx, my = (sx + gx) / 2, math.min(sy, gy) - 70 + row * 16          -- 가운데를 들어 올린 곡선
            local points = {}
            for i = 0, 16 do
                local k = i / 16
                local a, b, c = (1 - k) * (1 - k), 2 * k * (1 - k), k * k
                points[#points + 1] = a * sx + b * mx + c * gx
                points[#points + 1] = a * sy + b * my + c * gy
            end
            Draw.set_color(LINE.mana, 0.28 * flow)
            LG.setLineWidth(7)
            LG.line(points)
            Draw.set_color({ 1, 0.95, 0.75 }, 0.8 * flow)
            LG.setLineWidth(2)
            LG.line(points)
            local k = (t * 0.7 + row * 0.19) % 1
            local a, b, c = (1 - k) * (1 - k), 2 * k * (1 - k), k * k
            Draw.set_color({ 1, 1, 1 }, flow)
            LG.circle("fill", a * sx + b * mx + c * gx, a * sy + b * my + c * gy, 4, 10)
        end
        LG.setBlendMode("alpha")
    end
    LaneHeroArt.figure("idle", x, ground, height, t, { alpha = appear, aura = LINE.mana,
        breathe = 0.01 * math.sin(t * 1.7), flash = flow * (0.55 + 0.25 * math.sin(t * 5)) })
end

-- time: 인트로 시계 (data/intro.lua 의 stages 기준)
function IntroCircuit:draw(time)
    local sw, sh = Viewport.width(), Viewport.height()
    local t = time - self._start
    local camera = KenBurns.camera_at(SCENE.camera, time)
    if self._image ~= nil then
        KenBurns.draw(self._image, camera)
        self:_light(t, 1)
        return
    end
    if self._fallback ~= nil then                    -- 기존 공방 배경 + 어둠 + 황금색 회로 틴트
        KenBurns.draw(self._fallback, camera)
        LG.setColor(0.02, 0.015, 0.02, SCENE.dim)
        LG.rectangle("fill", 0, 0, sw, sh)
        LG.setBlendMode("add")
        Draw.set_color(SPEC.tint, SCENE.tint_alpha)
        LG.rectangle("fill", 0, 0, sw, sh)
        LG.setBlendMode("alpha")
    else
        Draw.clear({ 0.05, 0.04, 0.05 })
    end
    self:_light(t, 0.7)
    draw_board(t)
    draw_hero(t)
end

return IntroCircuit
