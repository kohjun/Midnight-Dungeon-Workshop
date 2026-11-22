-- ui/TitleScene.lua
-- 타이틀 2.5D 배경 씬: shaders/title_scene.glsl 관리, 마우스 패럴랙스 감쇠, 나무 간판 피벗 진자 물리,
-- 돌길 물결 파동 버퍼, 포탈 근접 에너지. assets/title_fx/ 누락 또는 셰이더 미지원 시 정적 TitleBackdrop 폴백.

local Class = require("lib.classic")
local Viewport = require("core.Viewport")
local Audio = require("systems.Audio")
local TitleBackdrop = require("ui.TitleBackdrop")
local FX = require("data.title_fx")

local TitleScene = Class:extend()

local LG = love.graphics
local MAX_RIPPLES = FX.cobble.ripple_max

local _fx_enabled = true
local _res = nil        -- 지연 로드 캐시: { checked, ready, clean, depth, mask_env, mask_fx, sign, shader }

local function load_image(path)
    if love.filesystem.getInfo(path) == nil then
        return nil
    end
    local ok, img = pcall(LG.newImage, path)
    if not ok then
        return nil
    end
    img:setFilter("linear", "linear")
    img:setWrap("clamp", "clamp")
    return img
end

local function load_resources()
    if _res ~= nil then
        return _res
    end
    _res = { checked = true, ready = false }
    if not _fx_enabled then
        return _res
    end
    local a = FX.assets
    local clean = load_image(a.clean) or load_image(a.fallback)
    local depth = load_image(a.depth)
    local mask_env = load_image(a.mask_env)
    local mask_fx = load_image(a.mask_fx)
    local sign = load_image(a.sign)
    local shader = nil
    if love.filesystem.getInfo(a.shader) ~= nil then
        local ok, compiled = pcall(LG.newShader, a.shader)
        if ok then
            shader = compiled
        else
            print("[TitleScene] shader compile failed, falling back: " .. tostring(compiled))
        end
    end
    _res.clean, _res.depth, _res.mask_env, _res.mask_fx, _res.sign, _res.shader =
        clean, depth, mask_env, mask_fx, sign, shader
    _res.ready = (clean ~= nil and depth ~= nil and mask_env ~= nil and mask_fx ~= nil and shader ~= nil)
    return _res
end

function TitleScene.set_fx_enabled(enabled)
    _fx_enabled = enabled and true or false
    _res = nil
end

function TitleScene.reset_cache()
    _res = nil
end

function TitleScene:new()
    self._time = 0
    self._mouse_x, self._mouse_y = 0, 0
    self._target_x, self._target_y = 0, 0
    self._prev_px, self._prev_py = nil, nil
    self._sign_angle, self._sign_vel = 0, 0
    self._creak_cd = 0
    self._portal_energy = 0.65
    self._ripples = {}
    self._ripple_head = 1
    for i = 1, MAX_RIPPLES do
        self._ripples[i] = { 0, 0, 99, 0 }
    end
    self._fallback = TitleBackdrop()
    load_resources()
end

function TitleScene:is_shader_active()
    local r = load_resources()
    return _fx_enabled and r.ready
end

function TitleScene:depth_image()
    local r = load_resources()
    return (_fx_enabled and r.ready) and r.depth or nil
end

-- 화면 전체를 덮는 배경 이미지 직사각형 (1360x768 → 1280x720)
function TitleScene:image_rect()
    local sw, sh = Viewport.width(), Viewport.height()
    local iw, ih = FX.image.w, FX.image.h
    local scale = math.max(sw / iw, sh / ih)
    local dw, dh = iw * scale, ih * scale
    return (sw - dw) * 0.5, (sh - dh) * 0.5, dw, dh, scale
end

function TitleScene:screen_to_uv(sx, sy)
    local ox, oy, dw, dh = self:image_rect()
    local raw_x = (sx - ox) / dw
    local raw_y = (sy - oy) / dh
    local z = FX.parallax.zoom
    return (raw_x - 0.5) / z + 0.5, (raw_y - 0.5) / z + 0.5
end

-- 특정 깊이(depth)의 정규화 UV 를 현재 패럴랙스가 적용된 화면 좌표로 변환
function TitleScene:uv_to_screen(u, v, depth)
    local ox, oy, dw, dh = self:image_rect()
    local p = FX.parallax
    local d = (depth or 0.5) - 0.5
    local base_u = u - self._mouse_x * p.strength_x * d
    local base_v = v - self._mouse_y * p.strength_y * d
    local raw_u = (base_u - 0.5) * p.zoom + 0.5
    local raw_v = (base_v - 0.5) * p.zoom + 0.5
    return ox + raw_u * dw, oy + raw_v * dh
end

function TitleScene:add_ripple(u, v, strength)
    local idx = self._ripple_head
    self._ripples[idx] = { u, v, 0.001, strength or 0.85 }
    self._ripple_head = (idx % MAX_RIPPLES) + 1
end

function TitleScene:nudge_sign(vel)
    local s = FX.sign
    self._sign_vel = math.max(-s.max_vel, math.min(s.max_vel, self._sign_vel + vel))
    if math.abs(vel) >= s.creak_threshold and self._creak_cd <= 0 then
        self._creak_cd = s.creak_cooldown
        Audio.play("sign_creak")
    end
end

function TitleScene:portal_energy()
    return self._portal_energy
end

function TitleScene:mouse_offset()
    return self._mouse_x, self._mouse_y
end

function TitleScene:update(dt, px, py, pointer_moved)
    self._time = self._time + dt
    self._creak_cd = math.max(0, self._creak_cd - dt)
    if not self:is_shader_active() then
        self._fallback:update(dt)
    end

    -- 1. 감쇠된 마우스 패럴랙스 + 미세 호흡 유휴 움직임
    local sw, sh = Viewport.width(), Viewport.height()
    if px ~= nil and py ~= nil then
        self._target_x = math.max(-1, math.min(1, (px / sw) * 2 - 1))
        self._target_y = math.max(-1, math.min(1, (py / sh) * 2 - 1))
    end
    local p = FX.parallax
    local idle_x = math.sin(self._time * 0.34) * p.idle_x
    local idle_y = math.cos(self._time * 0.25) * p.idle_y
    local k = 1 - math.exp(-dt * p.damp)
    self._mouse_x = self._mouse_x + (self._target_x + idle_x - self._mouse_x) * k
    self._mouse_y = self._mouse_y + (self._target_y + idle_y - self._mouse_y) * k

    -- 2. 커서 속도 기반 나무 간판 스치기 + 포탈 근접도
    if px ~= nil and py ~= nil then
        local s = FX.sign
        local dx = self._prev_px and (px - self._prev_px) or 0
        if pointer_moved and math.abs(dx) > 0.5 then
            local bx, by = self:uv_to_screen(s.box.x, s.box.y, s.depth)
            local _, _, dw, dh = self:image_rect()
            local bw, bh = s.box.w * dw * p.zoom, s.box.h * dh * p.zoom
            if px >= bx - 10 and px <= bx + bw + 10 and py >= by - 6 and py <= by + bh + 10 then
                -- LÖVE 회전은 양수가 시계 방향(아랫부분 좌측 이동)이므로 우측 스와이프(+dx)는 음수 각속도
                self:nudge_sign(-dx * s.swipe_gain)
            end
        end
        local portal_x, portal_y = self:uv_to_screen(FX.portal.x, FX.portal.y, FX.portal.depth)
        local dist = math.sqrt((px - portal_x) ^ 2 + (py - portal_y) ^ 2)
        local prox = math.max(0, math.min(1, 1 - (dist - 70) / 220))
        local target_energy = 0.65 + prox * 1.15
        self._portal_energy = self._portal_energy + (target_energy - self._portal_energy) * math.min(1, dt * 4.5)
        self._prev_px, self._prev_py = px, py
    end

    -- 3. 나무 간판 감쇠 진자 물리 (밤바람 + 스치기 관성)
    local s = FX.sign
    local wind = math.sin(self._time * 1.15) * s.wind_amp
        + math.sin(self._time * 2.4 + 1.1) * (s.wind_amp * 0.55)
    local acc = -s.stiffness * self._sign_angle - s.damping * self._sign_vel + wind
    self._sign_vel = self._sign_vel + acc * dt
    self._sign_angle = self._sign_angle + self._sign_vel * dt
    if self._sign_angle > s.max_angle then
        self._sign_angle, self._sign_vel = s.max_angle, self._sign_vel * -0.35
    elseif self._sign_angle < -s.max_angle then
        self._sign_angle, self._sign_vel = -s.max_angle, self._sign_vel * -0.35
    end

    -- 4. 돌길 파동 경과 시간 갱신
    for i = 1, MAX_RIPPLES do
        local rip = self._ripples[i]
        if rip[4] > 0 then
            rip[3] = rip[3] + dt
            if rip[3] >= FX.cobble.ripple_life then
                rip[4] = 0
            end
        end
    end
end

function TitleScene:_send_uniforms(shader, lightning, l_u, l_v)
    local p = FX.parallax
    shader:send("u_depth", _res.depth)
    shader:send("u_mask_env", _res.mask_env)
    shader:send("u_mask_fx", _res.mask_fx)
    shader:send("u_time", self._time)
    shader:send("u_mouse", { self._mouse_x, self._mouse_y })
    shader:send("u_parallax", { p.strength_x, p.strength_y })
    shader:send("u_zoom", p.zoom)
    shader:send("u_aspect", FX.image.aspect)
    shader:send("u_lightning", lightning or 0)
    shader:send("u_lightning_pos", { l_u or 0.24, l_v or 0.32 })
    shader:send("u_portal_energy", self._portal_energy)
    shader:send("u_portal_center", { FX.portal.x, FX.portal.y })
    shader:send("u_brazier_left", { FX.portal.brazier_left.x, FX.portal.brazier_left.y })
    shader:send("u_brazier_right", { FX.portal.brazier_right.x, FX.portal.brazier_right.y })
    shader:send("u_moon_center", { FX.moon.x, FX.moon.y })
    shader:send("u_moon_radius", FX.moon.radius * FX.image.aspect)
    shader:send("u_win1", { FX.windows[1].x, FX.windows[1].y })
    shader:send("u_win2", { FX.windows[2].x, FX.windows[2].y })
    shader:send("u_ripples", unpack(self._ripples))
end

function TitleScene:draw_base(lightning, l_u, l_v)
    if not self:is_shader_active() then
        self._fallback:draw(nil, 0)
        return
    end
    local r = _res
    local ox, oy, _, _, scale = self:image_rect()
    self:_send_uniforms(r.shader, lightning, l_u, l_v)
    LG.setShader(r.shader)
    LG.setColor(1, 1, 1, 1)
    LG.draw(r.clean, ox, oy, 0, scale, scale)
    LG.setShader()
end

-- 상단 고리 피벗 기준 진자 회전 나무 간판 + 절벽 그림자
function TitleScene:draw_sign()
    if not self:is_shader_active() or _res.sign == nil then
        return
    end
    local s = FX.sign
    local _, _, _, _, scale = self:image_rect()
    local draw_scale = scale * FX.parallax.zoom
    local px, py = self:uv_to_screen(s.pivot.x, s.pivot.y, s.depth)
    local ox, oy = s.sprite_pivot.x, s.sprite_pivot.y

    -- 뒤쪽 절벽에 드리우는 은은한 그림자
    LG.setColor(0.02, 0.025, 0.04, 0.42)
    LG.draw(_res.sign, px - 5 + self._sign_angle * 10, py + 6, self._sign_angle * 0.92, draw_scale, draw_scale, ox, oy)
    -- 본체 (굵은 검은 잉크선 원형 유지)
    LG.setColor(1, 1, 1, 1)
    LG.draw(_res.sign, px, py, self._sign_angle, draw_scale, draw_scale, ox, oy)
end

-- 메뉴 가독성을 위한 은은한 암막 (번개 시 좌측 텍스트 가독성 보호 포함)
function TitleScene:draw_dim(dim)
    if dim == nil or dim <= 0 then
        return
    end
    LG.setColor(0.01, 0.012, 0.03, dim)
    LG.rectangle("fill", 0, 0, Viewport.width(), Viewport.height())
end

function TitleScene:get_state()
    local active_ripples = 0
    for i = 1, MAX_RIPPLES do
        if self._ripples[i][4] > 0 then
            active_ripples = active_ripples + 1
        end
    end
    return {
        shader_active = self:is_shader_active(),
        mouse_x = self._mouse_x,
        mouse_y = self._mouse_y,
        sign_angle = self._sign_angle,
        sign_vel = self._sign_vel,
        portal_energy = self._portal_energy,
        ripple_count = active_ripples,
    }
end

return TitleScene
