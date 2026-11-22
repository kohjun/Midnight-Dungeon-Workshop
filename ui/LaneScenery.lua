-- ui/LaneScenery.lua
-- 밤 전투 레인의 원화 무대 (ui/LaneView 가 부른다, 규칙 계산 없음). 원화가 없으면 false 를 돌려 LaneView 의 코드 배경으로 폴백.
--   background : assets/backgrounds/night_lane.png 를 비율 그대로 data/art.lua 의 night_lane.scale 배로 그리고,
--                원본 돌길 윗선(road_src_y)을 화면 road_y(몬스터 보행 띠 LAYOUT.night.field 바로 위)에 맞춘다. 가로는 anchor_x 기준 자르기
--   workshop   : 왼쪽 끝 building_workshop — 오른쪽 벽면(face_x)이 방벽 충돌선(LAYOUT.night.wall 오른쪽)에 닿게 돌길 위에 세우고 접지 그림자.
--                방벽 피격(ui/EntityMotion 의 wall_hit)이면 짧게 흔들리며 붉게 번쩍인다
--   ward       : 방벽 충돌선 앞의 옅은 푸른 결계 막 — 피격 순간 파동이 퍼진다 (몬스터 위에 그린다)
--   portal     : 오른쪽 끝 building_portal — 아치 안쪽 중심(arch)이 LAYOUT.night.portal.x · 보행 띠 가운데(= 몬스터 스폰 지점)에 온다.
--                보라 마나 소용돌이·불티(AmbientEffects.draw_vortex)도 그 아치 중심에 정렬한다

local Draw = require("ui.Draw")
local SpriteBank = require("ui.SpriteBank")
local RoomBackdrop = require("ui.RoomBackdrop")
local AmbientEffects = require("ui.AmbientEffects")
local ART = require("data.art")
local LAYOUT = require("data.layout")

local LaneScenery = {}

local LG = love.graphics
local NIGHT = LAYOUT.night
local WALL_X = NIGHT.wall.x + NIGHT.wall.w
local PORTAL_GLOW = { 0.72, 0.3, 0.95 }
local WARD = { 0.45, 0.78, 1.0 }
local SEAM = 10             -- 이어 붙인 돌길 이음매를 덮는 그늘 띠 높이

local _fill = nil           -- 이어 붙일 돌길 조각 { quad, height }

local function shadow(cx, y, w)
    LG.setColor(0, 0, 0, 0.5)
    LG.ellipse("fill", cx, y, w * 0.5, 9, 32)
    LG.setColor(0, 0, 0, 0.25)
    LG.ellipse("fill", cx, y, w * 0.62, 14, 32)
end

function LaneScenery.draw_background(lane)
    local spec = ART.night_lane
    local image = RoomBackdrop.load(spec.image)
    if image == nil then
        return false
    end
    local iw, ih = image:getDimensions()
    local s = spec.scale
    local x = lane.x - (iw * s - lane.w) * spec.anchor_x
    local y = spec.road_y - spec.road_src_y * s
    LG.setColor(1, 1, 1, 1)
    LG.draw(image, x, y, 0, s, s)
    local bottom, lane_bottom = y + ih * s, lane.y + lane.h
    if bottom < lane_bottom then        -- 원본이 레인 바닥까지 안 닿으면 원본 돌길 아랫부분을 이어 붙인다 (비율 그대로)
        local src_h = math.min(ih - spec.road_src_y, (lane_bottom - bottom) / s)
        if _fill == nil or _fill.height ~= src_h then
            _fill = { height = src_h, quad = LG.newQuad(0, ih - src_h, iw, src_h, iw, ih) }
        end
        LG.draw(image, _fill.quad, x, bottom, 0, s, s)
        LG.setColor(0, 0, 0, spec.fill_shade)
        LG.rectangle("fill", lane.x, bottom, lane.w, lane_bottom - bottom)
        for i = 0, SEAM - 1 do
            LG.setColor(0, 0, 0, 0.3 * (1 - math.abs(i - SEAM / 2) / (SEAM / 2)))
            LG.rectangle("fill", lane.x, bottom - SEAM / 2 + i, lane.w, 1)
        end
    end
    LG.setColor(0.02, 0.02, 0.06, spec.dim)
    LG.rectangle("fill", lane.x, lane.y, lane.w, lane.h)
    return true
end

-- 그림 크기: 높이 height 로 맞춘 배율 · 너비
local function fit(image, height)
    local iw, ih = image:getDimensions()
    local s = height / ih
    return s, iw * s
end

-- hit: 방벽 피격 직후 1 → 0
function LaneScenery.draw_workshop(time, hit)
    local spec = ART.buildings.workshop
    local image = SpriteBank.image(spec.sprite)
    if image == nil then
        return false
    end
    local s, w = fit(image, spec.height)
    local x = WALL_X - spec.face_x * w + (hit > 0 and math.sin(time * 90) * 4 * hit or 0)
    local y = spec.ground_y - spec.base * spec.height
    shadow(x + w * 0.55, spec.ground_y, w)
    LG.setColor(1, 1 - 0.35 * hit, 1 - 0.4 * hit, 1)
    LG.draw(image, x, y, 0, s, s)
    if hit > 0 then                                             -- 붉은 번쩍임 (가산)
        LG.setBlendMode("add")
        LG.setColor(1, 0.18, 0.1, 0.45 * hit)
        LG.draw(image, x, y, 0, s, s)
        LG.setBlendMode("alpha")
    end
    return true
end

-- 방벽 앞 결계 막 + 피격 파동 (몬스터 위에 그린다). 건물 원화가 있을 때만
function LaneScenery.draw_ward(time, hit, hit_y)
    if SpriteBank.image(ART.buildings.workshop.sprite) == nil then
        return
    end
    local field = NIGHT.field
    local breathe = 0.5 + 0.5 * math.sin(time * 2)
    LG.setBlendMode("add")
    Draw.set_color(WARD, 0.05 + 0.03 * breathe + 0.25 * hit)
    LG.rectangle("fill", WALL_X - 2, field.y - 30, 7, field.h + 60, 3, 3)
    local cy = hit_y or (field.y + field.h / 2)
    for k = 1, 3 do
        local radius = 18 + k * 16 + (1 - hit) * 26
        Draw.set_color(WARD, (0.10 + 0.5 * hit) * (1 - k / 4))
        LG.setLineWidth(2)
        LG.arc("line", "open", WALL_X, cy, radius, -1.1, 1.1, 24)
    end
    LG.setBlendMode("alpha")
end

function LaneScenery.draw_portal(time)
    local spec = ART.buildings.portal
    local image = SpriteBank.image(spec.sprite)
    if image == nil then
        return false
    end
    local portal, field = NIGHT.portal, NIGHT.field
    local cy = field.y + field.h / 2
    local s, w = fit(image, portal.size)
    local x, y = portal.x - spec.arch.x * w, cy - spec.arch.y * portal.size
    shadow(portal.x, y + spec.base * portal.size, w)
    Draw.glow(portal.x, cy, portal.size * 0.5, PORTAL_GLOW, 0.45 + 0.15 * math.sin(time * 3))
    LG.setColor(1, 1, 1, 1)
    LG.draw(image, x, y, 0, s, s)
    AmbientEffects.draw_vortex(portal.x, cy, portal.size * 0.62, time)
    return true
end

return LaneScenery
