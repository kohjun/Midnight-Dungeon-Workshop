-- ui/TitleWeather.lua
-- 타이틀 환경·날씨 레이어: 좌측 갈래 번개(자동 6~14초 + 좌측 하늘 클릭 + 0.4~1.2초 시차 천둥),
-- 배경/전경 2계층 밤비 & 돌길 물보라, 굴뚝 잉크 연기, 좌측 계곡 안개, 포탈·화로 보라 마나 불티.

local Class = require("lib.classic")
local RNG = require("core.RNG")
local Viewport = require("core.Viewport")
local Audio = require("systems.Audio")
local FX = require("data.title_fx")

local TitleWeather = Class:extend()
local LG = love.graphics
local BOLT_SHADER_PATH = "shaders/title_bolt.glsl"
local BOLT_PASSES = {
    { w = 5.6, c = { 0.56, 0.44, 0.92 }, a = 0.28 },
    { w = 3.0, c = { 0.80, 0.70, 1.00 }, a = 0.68 },
    { w = 1.5, c = { 1.00, 0.99, 1.00 }, a = 0.98 },
}
local _soft, _occ_shader, _occ_checked = nil, nil, false

local function soft_circle()
    if _soft == nil then
        local data = love.image.newImageData(48, 48)
        data:mapPixel(function(x, y)
            local a = math.max(0, 1 - math.sqrt((x - 23.5) ^ 2 + (y - 23.5) ^ 2) / 24)
            return 1, 1, 1, a * a
        end)
        _soft = LG.newImage(data)
        _soft:setFilter("linear", "linear")
    end
    return _soft
end

local function bolt_shader()
    if not _occ_checked then
        _occ_checked = true
        if love.filesystem.getInfo(BOLT_SHADER_PATH) ~= nil then
            local ok, sh = pcall(LG.newShader, BOLT_SHADER_PATH)
            _occ_shader = ok and sh or nil
        end
    end
    return _occ_shader
end

local function build_chain(rng, x0, y0, x1, y1, steps, jitter)
    local pts = {}
    for i = 0, steps do
        local t = i / steps
        local x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        if i > 0 and i < steps then
            local amp = jitter * math.sin(t * math.pi)
            x, y = x + rng:float(-amp, amp), y + rng:float(-amp * 0.4, amp * 0.4)
        end
        pts[#pts + 1] = { x, y }
    end
    return pts
end

function TitleWeather:new(scene)
    self._scene, self._rng = scene, RNG.stream("fx")
    self._time, self._strikes, self._flash = 0, 0, 0
    self._bolt, self._bolt_u, self._bolt_v = nil, 0.24, 0.30
    self._next_bolt = self._rng:float(FX.lightning.first_min, FX.lightning.first_max)
    self._thunders, self._smoke, self._embers, self._splashes = {}, {}, {}, {}
    self._smoke_acc, self._ember_acc, self._ripple_acc, self._cursor_rip_cd = 0, 0, 0, 0
    self:_init_layers()
end

function TitleWeather:_init_layers()
    local sw, sh, rng = Viewport.width(), Viewport.height(), self._rng
    self._rain_bg, self._rain_fg, self._mist = {}, {}, {}
    local function fill_rain(list, n, lmin, lmax, spd, amin, amax)
        for i = 1, n do
            list[i] = { x = rng:float(0, sw), y = rng:float(0, sh), len = rng:float(lmin, lmax),
                speed = spd * rng:float(0.84, 1.18), alpha = rng:float(amin, amax) }
        end
    end
    fill_rain(self._rain_bg, FX.rain.bg_count, 12, 22, FX.rain.speed_bg, 0.11, 0.22)
    fill_rain(self._rain_fg, FX.rain.fg_count, 20, 34, FX.rain.speed_fg, 0.20, 0.36)
    local m, ch = FX.mist, FX.chimney
    for i = 1, m.count do
        self._mist[i] = { u = rng:float(-0.12, m.x_max), v = rng:float(m.y_min, m.y_max), w = rng:float(220, 420),
            h = rng:float(52, 92), speed = rng:float(0.008, 0.018), alpha = rng:float(0.06, 0.13) }
    end
    for i = 1, 10 do
        local f = i / 10
        self._smoke[i] = { u = ch.x + f * 0.06 + rng:float(-0.008, 0.008), v = ch.y - f * 0.18,
            vu = rng:float(0.007, 0.013), vv = -rng:float(0.024, 0.036), age = f * 5.2, life = 5.2, r0 = 10, r1 = 36 }
    end
end

function TitleWeather:trigger_lightning(u_opt)
    local L, rng = FX.lightning, self._rng
    local ox = u_opt and math.max(L.bolt_x_min, math.min(L.bolt_x_max, u_opt)) or rng:float(L.bolt_x_min, L.bolt_x_max)
    local ex = math.max(0.06, math.min(0.46, ox + rng:float(-0.06, 0.06)))
    local main_pts = build_chain(rng, ox, -0.01, ex, rng:float(L.bolt_end_y_min, L.bolt_end_y_max), 11, 0.026)
    local branches, forks = { { pts = main_pts, order = 0 } }, rng:int(4, 5)
    for f = 1, forks do
        local idx = math.min(#main_pts - 2, math.max(2, math.floor(2 + (f / (forks + 1)) * (#main_pts - 3))))
        local root, dir = main_pts[idx], (f % 2 == 0) and 1 or -1
        local fp = build_chain(rng, root[1], root[2], math.max(0.03, math.min(0.50, root[1] + dir * rng:float(0.04, 0.085))),
            math.min(0.76, root[2] + rng:float(0.12, 0.22)), 5, 0.014)
        branches[#branches + 1] = { pts = fp, order = 1 }
        if rng:chance(0.6) and #fp >= 3 then
            local sr = fp[3]
            branches[#branches + 1] = { pts = build_chain(rng, sr[1], sr[2],
                math.max(0.03, math.min(0.50, sr[1] + dir * rng:float(0.02, 0.045))),
                math.min(0.76, sr[2] + rng:float(0.06, 0.11)), 3, 0.008), order = 2 }
        end
    end
    self._bolt = { branches = branches, age = 0, dur = rng:float(L.duration_min, L.duration_max), env = 1 }
    self._bolt_u, self._bolt_v, self._flash = (ox + ex) * 0.5, 0.30, 1.0
    self._strikes = self._strikes + 1
    self._next_bolt = rng:float(L.interval_min, L.interval_max)
    self._thunders[#self._thunders + 1] = rng:float(L.thunder_delay_min, L.thunder_delay_max)
    return true
end

function TitleWeather:try_click_lightning(x, y, blocked)
    if blocked then return false end
    local u, v = self._scene:screen_to_uv(x, y)
    local sc = FX.lightning.sky_click
    return (u >= sc.x_min and u <= sc.x_max and v >= sc.y_min and v <= sc.y_max) and self:trigger_lightning(u) or false
end

function TitleWeather:lightning_state() return self._flash, self._bolt_u, self._bolt_v end
function TitleWeather:strike_count() return self._strikes end
function TitleWeather:pending_thunder_count() return #self._thunders end

function TitleWeather:_spawn_splash(u, v, strength)
    self._scene:add_ripple(u, v, strength)
    for _ = 1, 2 do
        if #self._splashes < 48 then
            self._splashes[#self._splashes + 1] = { u = u, v = v, vu = self._rng:float(-0.028, 0.028),
                vv = -self._rng:float(0.042, 0.072), age = 0, life = self._rng:float(0.22, 0.36) }
        end
    end
end

function TitleWeather:_update_lightning(dt)
    self._next_bolt = self._next_bolt - dt
    if self._next_bolt <= 0 then self:trigger_lightning() end
    for i = #self._thunders, 1, -1 do
        self._thunders[i] = self._thunders[i] - dt
        if self._thunders[i] <= 0 then table.remove(self._thunders, i); Audio.play("title_thunder") end
    end
    local b = self._bolt
    if b == nil then self._flash = math.max(0, self._flash - dt * 5.2); return end
    b.age = b.age + dt
    local t = b.age / b.dur
    if t >= 1 then self._bolt = nil; self._flash = math.max(0, self._flash - dt * 5.2); return end
    if t < 0.24 then b.env = 1.0 - t * 0.8
    elseif t < 0.42 then b.env = 0.16
    elseif t < 0.72 then b.env = 0.94 - (t - 0.42) * 0.5
    else b.env = 0.78 * (1 - (t - 0.72) / 0.28) ^ 1.5 end
    self._flash = math.max(b.env * 0.95, self._flash - dt * 4.2)
end

function TitleWeather:update(dt, px, py, pointer_moved)
    self._time = self._time + dt
    self:_update_lightning(dt)
    local sw, sh, rng, cb = Viewport.width(), Viewport.height(), self._rng, FX.cobble
    for _, list in ipairs({ self._rain_bg, self._rain_fg }) do
        for _, r in ipairs(list) do
            r.y, r.x = r.y + r.speed * dt, r.x + r.speed * FX.rain.slant * dt
            if r.y > sh + 20 then r.y, r.x = -20, rng:float(-40, sw + 80) end
            if r.x < -60 then r.x = sw + 40 end
        end
    end
    self._ripple_acc = self._ripple_acc + dt * cb.rain_ripple_rate
    while self._ripple_acc >= 1 do
        self._ripple_acc = self._ripple_acc - 1
        self:_spawn_splash(rng:float(cb.x + 0.08, cb.x + cb.w - 0.04), rng:float(cb.y + 0.04, cb.y + cb.h - 0.02), 0.7)
    end
    self._cursor_rip_cd = math.max(0, self._cursor_rip_cd - dt)
    if pointer_moved and px ~= nil and py ~= nil and self._cursor_rip_cd <= 0 then
        local u, v = self._scene:screen_to_uv(px, py)
        if u >= cb.x and u <= cb.x + cb.w and v >= cb.y and v <= cb.y + cb.h then
            self._cursor_rip_cd = cb.cursor_ripple_cd
            self:_spawn_splash(u, v, 0.95)
        end
    end
    for _, m in ipairs(self._mist) do
        m.u = m.u + m.speed * dt
        if m.u > FX.mist.x_max + 0.12 then m.u = -0.18 end
    end
    self._smoke_acc = self._smoke_acc + dt * FX.chimney.rate
    while self._smoke_acc >= 1 and #self._smoke < 34 do
        self._smoke_acc = self._smoke_acc - 1
        self._smoke[#self._smoke + 1] = { u = FX.chimney.x + rng:float(-0.008, 0.008), v = FX.chimney.y,
            vu = rng:float(0.006, 0.013), vv = -rng:float(0.022, 0.036), age = 0, life = rng:float(4.5, 6.8),
            r0 = rng:float(9, 13), r1 = rng:float(32, 46) }
    end
    self._ember_acc = self._ember_acc + dt * FX.portal.ember_rate * self._scene:portal_energy()
    while self._ember_acc >= 1 and #self._embers < 72 do
        self._ember_acc = self._ember_acc - 1
        local roll = rng:random()
        local src = roll < 0.34 and FX.portal.brazier_left or (roll < 0.68 and FX.portal.brazier_right or FX.portal)
        local sp = (src == FX.portal) and 0.045 or 0.012
        self._embers[#self._embers + 1] = { u = src.x + rng:float(-sp, sp), v = src.y + rng:float(-sp, sp),
            vu = rng:float(-0.012, 0.012), vv = -rng:float(0.032, 0.068), age = 0, life = rng:float(1.2, 2.5),
            size = rng:float(2.0, 4.2), phase = rng:float(0, 6.28) }
    end
    local function step_pool(list, grav, sway)
        for i = #list, 1, -1 do
            local p = list[i]
            p.age = p.age + dt
            if grav ~= 0 then p.vv = p.vv + grav * dt end
            p.u = p.u + (p.vu + (sway and math.sin(self._time * 3.8 + p.phase) * 0.012 or 0)) * dt
            p.v = p.v + p.vv * dt
            if p.age >= p.life then table.remove(list, i) end
        end
    end
    step_pool(self._smoke, 0, false); step_pool(self._embers, 0, true); step_pool(self._splashes, 0.24, false)
end

function TitleWeather:_draw_bolt()
    local b = self._bolt
    if b == nil or b.env <= 0.01 then return end
    local depth_img = self._scene:depth_image()
    local sh = depth_img and bolt_shader() or nil
    if sh ~= nil then
        local ox, oy, dw, dh = self._scene:image_rect()
        local rx, ry, rw, rh = ox, oy, dw, dh
        if LG.getCanvas() == nil then
            rx, ry = Viewport.to_window(ox, oy); rw, rh = dw * Viewport.scale(), dh * Viewport.scale()
        end
        local mx, my = self._scene:mouse_offset()
        sh:send("u_depth", depth_img); sh:send("u_rect", { rx, ry, rw, rh }); sh:send("u_mouse", { mx, my })
        sh:send("u_parallax", { FX.parallax.strength_x, FX.parallax.strength_y })
        sh:send("u_zoom", FX.parallax.zoom); sh:send("u_bolt_depth", FX.lightning.depth)
        LG.setShader(sh)
    end
    LG.setLineJoin("miter")
    for _, pass in ipairs(BOLT_PASSES) do
        for _, br in ipairs(b.branches) do
            local gain, coords = br.order == 0 and 1.0 or (br.order == 1 and 0.68 or 0.44), {}
            for _, pt in ipairs(br.pts) do
                local sx, sy = self._scene:uv_to_screen(pt[1], pt[2], FX.lightning.depth)
                coords[#coords + 1], coords[#coords + 2] = sx, sy
            end
            LG.setLineWidth(pass.w * gain)
            LG.setColor(pass.c[1], pass.c[2], pass.c[3], pass.a * b.env * gain)
            LG.line(coords)
        end
    end
    if sh ~= nil then LG.setShader() end
end

function TitleWeather:draw_background()
    self:_draw_bolt()
    local glow = soft_circle()
    for _, m in ipairs(self._mist) do
        local sx, sy = self._scene:uv_to_screen(m.u, m.v, 0.16)
        local boost = 1 + self._flash * 0.7
        LG.setColor(0.24 * boost, 0.29 * boost, 0.42 * boost, m.alpha)
        LG.draw(glow, sx - m.w * 0.5, sy - m.h * 0.5, 0, m.w / 48, m.h / 48)
    end
    LG.setLineWidth(1.0)
    for _, r in ipairs(self._rain_bg) do
        LG.setColor(0.56, 0.64, 0.78, r.alpha)
        LG.line(r.x, r.y, r.x + r.len * FX.rain.slant, r.y + r.len)
    end
end

function TitleWeather:draw_foreground()
    local glow = soft_circle()
    for _, p in ipairs(self._smoke) do
        local t = p.age / p.life
        local r = p.r0 + (p.r1 - p.r0) * t
        local sx, sy = self._scene:uv_to_screen(p.u, p.v, FX.chimney.depth)
        LG.setColor(0.28, 0.32, 0.40, math.min(1, t / 0.18) * ((1 - t) ^ 1.4) * 0.34)
        LG.draw(glow, sx - r, sy - r, 0, (r * 2) / 48, (r * 2) / 48)
    end
    LG.setBlendMode("add")
    for _, e in ipairs(self._embers) do
        local t = e.age / e.life
        local a = math.min(1, t / 0.15) * (1 - t) * (0.72 + 0.28 * math.sin(self._time * 10 + e.phase))
        local sx, sy = self._scene:uv_to_screen(e.u, e.v, FX.portal.depth + 0.15)
        LG.setColor(0.68, 0.22, 0.78, a * 0.42)
        LG.draw(glow, sx - e.size * 2.8, sy - e.size * 2.8, 0, (e.size * 5.6) / 48, (e.size * 5.6) / 48)
        LG.setColor(0.96, 0.60, 0.94, a * 0.85)
        LG.circle("fill", sx, sy, e.size * 0.5, 6)
    end
    LG.setBlendMode("alpha")
    for _, s in ipairs(self._splashes) do
        local sx, sy = self._scene:uv_to_screen(s.u, s.v, 0.72)
        LG.setColor(0.80, 0.84, 0.92, (1 - s.age / s.life) * 0.65)
        LG.circle("fill", sx, sy, 1.8, 5)
    end
    LG.setLineWidth(1.25)
    for _, r in ipairs(self._rain_fg) do
        LG.setColor(0.64, 0.72, 0.86, r.alpha)
        LG.line(r.x, r.y, r.x + r.len * FX.rain.slant, r.y + r.len)
    end
end

return TitleWeather
