-- ui/EndingScenes.lua
-- 엔딩 연출 장면 (states/EndingState 가 시간에 맞춰 그린다). 수치·색·그림 경로는 data/endings.lua.
-- 엔딩 일러스트(assets/endings/ending_*.png)가 있으면 그것을 은은한 줌·패닝(ui/KenBurns)으로 깔고 분위기 입자만 얹는다.
-- 일러스트가 없고 fallback 그림이 있으면 그것을 대신 깐다 (image_kind() = "fallback"). 둘 다 없으면 코드 연출
-- (building_workshop · building_portal · shopkeeper 스프라이트, 없으면 대체 도형):
--   relocation : 새벽 하늘 아래 성벽 도시 실루엣, 떠오르는 해, 가게 간판이 성벽 안에 다시 걸린다
--   monopoly   : 황금빛 밤, 공방과 포탈 위로 금화가 쏟아진다
--   abyss      : 핏빛 하늘, 거대한 포탈 앞 주인장 실루엣이 균열로 걸어 들어가고 붉은 벼락이 친다
--   '스승의 흔적' 캠페인 엔딩(spec.campaign — true_dawn · new_gatekeeper)은 ui/EndingScenesTrace 가 맡는다.
-- opts.force = "fallback" | "code" : 개발 도구(스모크 테스트)용 — 그림이 있어도 대체 그림 / 코드 연출 경로를 그린다.

local Class = require("lib.classic")
local RNG = require("core.RNG")
local Viewport = require("core.Viewport")
local Draw = require("ui.Draw")
local IntroBattle = require("ui.IntroBattle")
local KenBurns = require("ui.KenBurns")
local Kit = require("ui.EndingSceneKit")
local EndingScenesTrace = require("ui.EndingScenesTrace")
local ENDINGS = require("data.endings")

local EndingScenes = Class:extend()

local LG = love.graphics
local GROUND_Y = 600
local WALL_COLOR = { 0.10, 0.07, 0.10 }
local COIN = { { 1.0, 0.84, 0.3 }, { 1.0, 0.95, 0.6 }, { 0.8, 0.55, 0.15 } }
local EMBER = { { 0.95, 0.25, 0.3 }, { 0.75, 0.2, 0.95 } }
local smooth = Kit.smooth
local draw_sprite = Kit.sprite

local _shade = nil          -- 일러스트 위아래 그늘 메시 (한 번 만든다)

-- 그림 한 장 (경로가 없거나 파일이 없거나 읽지 못하면 nil)
local function load_image(path)
    if path == nil or love.filesystem.getInfo(path) == nil then
        return nil
    end
    local ok, image = pcall(LG.newImage, path, { mipmaps = true })
    if not ok then
        print("[EndingScenes] failed to load " .. path .. ": " .. tostring(image))
        return nil
    end
    image:setFilter("linear", "linear")
    return image
end

function EndingScenes:new(id, fx, opts)
    self.id = id
    self._spec = ENDINGS.list[id]
    assert(self._spec ~= nil, "EndingScenes: unknown ending '" .. tostring(id) .. "'")
    self._fx = fx
    self._rng = RNG.stream("fx")
    self._spawn = 0
    self._bolts = {}
    self._next_bolt = 2.5
    local force = opts and opts.force
    self._image, self._image_kind = nil, nil
    if force == nil then
        self._image = load_image(self._spec.image)
        self._image_kind = self._image and "illustration" or nil
    end
    if self._image == nil and force ~= "code" and self._spec.fallback ~= nil then
        self._image = load_image(self._spec.fallback.image)
        self._image_kind = self._image and "fallback" or nil
    end
    if self._spec.campaign ~= nil then
        self._trace = EndingScenesTrace({ id = id, spec = self._spec, fx = fx, rng = self._rng, kind = self._image_kind,
            illustrate = function(time, overlay) self:_draw_illustration(time, overlay) end })
    end
    self._towers = {}
    local x = -20
    while x < Viewport.width() + 40 do      -- 성벽 도시 실루엣 (탑 높이 무작위)
        local w = self._rng:float(50, 110)
        self._towers[#self._towers + 1] = { x = x, w = w, h = self._rng:float(90, 210), roof = self._rng:chance(0.6) }
        x = x + w + self._rng:float(-6, 20)
    end
end

function EndingScenes:update(dt, time)
    if self._trace ~= nil then
        self._trace:update(dt, time)
        return
    end
    self._spawn = self._spawn - dt
    local sw = Viewport.width()
    if self._spawn <= 0 then
        self._spawn = 1 / ENDINGS.particles_per_second
        if self.id == "monopoly" then         -- 하늘에서 쏟아지는 금화
            self._fx:burst(self._rng:float(0, sw), -10, { count = 3, colors = COIN, speed_max = 60, life_max = 2.4, gravity = 260 })
        elseif self.id == "abyss" then        -- 포탈에서 솟는 붉은 불티
            self._fx:burst(sw / 2 + self._rng:float(-180, 180), GROUND_Y - 40, { count = 2, colors = EMBER, speed_max = 90, life_max = 1.8 })
        else                                  -- 새벽 먼지
            self._fx:burst(self._rng:float(0, sw), GROUND_Y - self._rng:float(0, 200), { count = 1, colors = { self._spec.glow }, speed_max = 20, life_max = 2 })
        end
    end
    if self.id == "abyss" and self._image == nil and time >= self._next_bolt then   -- 붉은 벼락은 코드 연출에서만
        self._next_bolt = time + self._rng:float(2.2, 3.6)
        local x = sw / 2 + self._rng:float(-260, 260)
        self._bolts[#self._bolts + 1] = { points = IntroBattle.bolt_points(self._rng, x + self._rng:float(-60, 60), 20, x, GROUND_Y - 220, 8, 30), life = 0.45 }
        self._fx:flash({ 0.9, 0.2, 0.3 }, 0.35, 0.3)
        self._fx:shake(0.35)
    end
    for i = #self._bolts, 1, -1 do
        self._bolts[i].life = self._bolts[i].life - dt
        if self._bolts[i].life <= 0 then
            table.remove(self._bolts, i)
        end
    end
end

function EndingScenes:_draw_sky(time)
    self._sky = self._sky or Kit.sky_mesh(self._spec.sky[1], self._spec.sky[2])
    Kit.draw_mesh(self._sky)
    Kit.glow(Viewport.width() / 2, GROUND_Y, 560 + 20 * math.sin(time * 0.7), self._spec.glow, 0.45)
end

function EndingScenes:_draw_city(time)
    local sw = Viewport.width()
    local rise = smooth(time / 9)
    Kit.glow(sw * 0.7, GROUND_Y - 40 - 150 * rise, 200, { 1.0, 0.85, 0.55 }, 0.9)
    Draw.set_color({ 1.0, 0.88, 0.6 })
    LG.circle("fill", sw * 0.7, GROUND_Y - 40 - 150 * rise, 46, 40)
    for _, t in ipairs(self._towers) do
        Draw.set_color(WALL_COLOR)
        LG.rectangle("fill", t.x, GROUND_Y - t.h, t.w, t.h + 2)
        if t.roof then
            LG.polygon("fill", t.x - 6, GROUND_Y - t.h, t.x + t.w / 2, GROUND_Y - t.h - t.w * 0.7, t.x + t.w + 6, GROUND_Y - t.h)
        end
        Draw.set_color({ 1.0, 0.75, 0.4 }, 0.5 + 0.3 * math.sin(time * 2 + t.x))   -- 창문 불빛
        LG.rectangle("fill", t.x + t.w * 0.4, GROUND_Y - t.h * 0.6, 6, 9)
    end
    Draw.set_color({ 0.06, 0.04, 0.05 })
    LG.rectangle("fill", 0, GROUND_Y - 70, sw, 72)         -- 성벽
    for x = 0, sw, 34 do
        LG.rectangle("fill", x, GROUND_Y - 86, 20, 18)
    end
end

function EndingScenes:_draw_monopoly(time)
    local sw = Viewport.width()
    if not draw_sprite("building_portal", sw * 0.73, GROUND_Y - 190, 400, { color = { 1.0, 0.85, 0.5 } }) then
        Draw.set_color({ 0.8, 0.6, 0.2 })
        LG.ellipse("fill", sw * 0.73, GROUND_Y - 190, 110, 170, 32)
    end
    Kit.glow(sw * 0.36, GROUND_Y - 200, 300, { 1.0, 0.8, 0.3 }, 0.55 + 0.1 * math.sin(time * 2))
    if not draw_sprite("building_workshop", sw * 0.36, GROUND_Y - 220, 470) then
        Draw.set_color({ 0.3, 0.22, 0.15 })
        LG.rectangle("fill", sw * 0.36 - 150, GROUND_Y - 300, 300, 300)
    end
end

function EndingScenes:_draw_abyss(time)
    local sw = Viewport.width()
    local pulse = 0.6 + 0.2 * math.sin(time * 2.4)
    Kit.glow(sw / 2, GROUND_Y - 260, 520, { 0.75, 0.1, 0.35 }, pulse)
    if not draw_sprite("building_portal", sw / 2, GROUND_Y - 270, 620, { color = { 1.0, 0.7, 0.8 } }) then
        Draw.set_color({ 0.5, 0.1, 0.4 })
        LG.ellipse("fill", sw / 2, GROUND_Y - 270, 170, 260, 40)
    end
    local walk = smooth((time - 3) / 12)                    -- 주인장이 균열 쪽으로 걸어간다
    local x, size = sw * 0.24 + (sw * 0.26) * walk, 300 * (1 - 0.45 * walk)
    if not draw_sprite("shopkeeper", x, GROUND_Y - size * 0.45, size, { color = { 0.02, 0.0, 0.02 }, alpha = 1 - 0.6 * walk }) then
        Draw.set_color({ 0.02, 0.0, 0.02 }, 1 - 0.6 * walk)
        LG.polygon("fill", x - size * 0.2, GROUND_Y, x + size * 0.2, GROUND_Y, x, GROUND_Y - size * 0.8)
    end
end

-- 엔딩 자신의 일러스트를 쓰는지 (개발 도구·스모크 테스트용 — 대체 그림은 false)
function EndingScenes:has_image()
    return self._image_kind == "illustration"
end

-- 깔고 있는 그림: "illustration" | "fallback" | nil (코드 연출)
function EndingScenes:image_kind()
    return self._image_kind
end

-- 일러스트 + 덧그림(overlay(to_screen) — 그림 안 위치를 화면으로) + 아래쪽 그늘 (에필로그 글이 읽히도록)
function EndingScenes:_draw_illustration(time, overlay)
    local to_screen = KenBurns.draw(self._image, KenBurns.camera_at(self._spec.camera, time))
    if overlay ~= nil then
        overlay(to_screen)
    end
    _shade = _shade or Kit.shade_mesh(ENDINGS.shade)          -- 아래(에필로그 글 뒤) · 위(제목 뒤) 부드러운 그늘
    Kit.draw_mesh(_shade)
end

function EndingScenes:draw(time)
    local sw, sh = Viewport.width(), Viewport.height()
    if self._trace ~= nil then
        self._trace:draw(time)
        return
    end
    if self._image ~= nil then
        self:_draw_illustration(time)
        return
    end
    self:_draw_sky(time)
    if self.id == "relocation" then
        self:_draw_city(time)
    elseif self.id == "monopoly" then
        self:_draw_monopoly(time)
    else
        self:_draw_abyss(time)
    end
    Draw.set_color({ 0.03, 0.02, 0.03 })
    LG.rectangle("fill", 0, GROUND_Y, sw, sh - GROUND_Y)
    LG.setBlendMode("add")
    for _, bolt in ipairs(self._bolts) do
        local a = bolt.life / 0.45
        Draw.set_color({ 1.0, 0.3, 0.4 }, 0.6 * a)
        LG.setLineWidth(10 * a + 2)
        LG.line(bolt.points)
        Draw.set_color({ 1, 1, 1 }, a)
        LG.setLineWidth(2.5)
        LG.line(bolt.points)
    end
    LG.setBlendMode("alpha")
end

return EndingScenes
