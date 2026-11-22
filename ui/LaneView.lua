-- ui/LaneView.lua
-- 밤 화면 오른쪽 와이드 전투 레인 (LAYOUT.night.lane): 별 하늘·먼 산·달, 지평선 아래 돌길(몬스터가 걷는 field),
-- 오른쪽 던전 포탈(portal 스프라이트, 몬스터가 여기서 나온다), 왼쪽 공방 방벽(내구도 색), 몬스터, 새벽까지 진행 막대.
-- 몬스터는 스프라이트(원화 → 생성 스프라이트, 피격 반동·점멸)가 있으면 그것, 없으면 ui/MonsterShapes 도형.
-- 감전 스파크와 보스 상태(보호막·면역·강탈 골드·이름·체력)를 겹쳐 그린다. 투사체·광선은 ui/AttackEffects.
-- 움직임은 ui/EntityMotion 의 포즈(보행·방벽 공격 예비 동작/돌진·피격 점멸·넉백, 메시 변형 프리셋)를 받아 그리고,
-- 방벽에 부딪힌 몬스터의 잔상(타격 스쿼시 → 물러나며 사라짐)도 여기서 그린다. 포탈에는 마나 소용돌이(ui/AmbientEffects).
-- '스승의 흔적' 최종 보스는 ui/MasterBossView (균열 오라 · 아이기스 돔 · 그로기 · 레인 아래 전용 체력 띠 · 경고/결말 배너).
-- 공방 문 앞 결계선에는 주인공(motion.hero — ui/LaneHero)이 선다: 몸은 몬스터보다 먼저, 마력 파동·망치 궤적·룬 방패는 몬스터 위에.

local Viewport = require("core.Viewport")
local I18n = require("systems.I18n")
local Draw = require("ui.Draw")
local SpriteBank = require("ui.SpriteBank")
local SpriteCatalog = require("ui.SpriteCatalog")
local Frame = require("ui.Frame")
local MonsterShapes = require("ui.MonsterShapes")
local AmbientEffects = require("ui.AmbientEffects")
local LaneScenery = require("ui.LaneScenery")
local MidBossView = require("ui.MidBossView")
local MasterBossView = require("ui.MasterBossView")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local LaneView = {}

local C = UI.color
local SIZE = UI.font_size
local LG = love.graphics
local NIGHT = LAYOUT.night
local STAR_COUNT = 70
local HILLS = { 0.0, 0.42, 0.12, 0.55, 0.26, 0.38, 0.4, 0.6, 0.55, 0.36, 0.7, 0.5, 0.86, 0.34, 1.0, 0.48 }
local PORTAL_GLOW = { 0.72, 0.3, 0.95 }
local BURN_COLOR = { 1.0, 0.5, 0.15 }
local SLOW_COLOR = { 0.55, 0.85, 1.0 }
local SHOCK_COLOR = { 0.6, 0.8, 1.0 }
local IMMUNITY_COLORS = { physical = { 0.8, 0.8, 0.85 }, elemental = { 0.55, 0.75, 1.0 } }
local WHITE = { 1, 1, 1 }
local SPRITE_SCALE = 2.9     -- 스프라이트 한 변 = 몬스터 반경 × 배율

local function draw_sky(workshop, lane, time)
    local horizon = NIGHT.horizon_y
    for i = 0, 11 do
        Draw.set_color(Draw.lerp_color(C.night_sky, { 0.13, 0.08, 0.2 }, i / 11))
        LG.rectangle("fill", lane.x, lane.y + i * (horizon - lane.y) / 12, lane.w, (horizon - lane.y) / 12 + 1)
    end
    for i = 1, STAR_COUNT do
        Draw.set_color({ 1, 1, 1 }, 0.2 + 0.25 * math.sin(time * 2 + i))
        LG.circle("fill", lane.x + (i * 97) % lane.w, lane.y + (i * 53) % (horizon - lane.y - 30), 1.3, 6)
    end
    local blood_moon = workshop.combat.modifiers ~= nil and workshop.combat.modifiers.blood_moon
    local mx, my = lane.x + lane.w * 0.62, lane.y + 70
    Draw.glow(mx, my, 90, blood_moon and C.danger or { 0.95, 0.93, 0.8 }, 0.35)
    Draw.set_color(blood_moon and { 0.9, 0.2, 0.15 } or { 0.95, 0.93, 0.8 })
    LG.circle("fill", mx, my, 30, 32)
    Draw.set_color({ 0.05, 0.04, 0.09 })                 -- 먼 산 실루엣
    local points = {}
    for i = 1, #HILLS, 2 do
        points[#points + 1] = lane.x + HILLS[i] * lane.w
        points[#points + 1] = horizon - HILLS[i + 1] * 120
    end
    for i = 1, #points - 2, 2 do
        LG.polygon("fill", points[i], horizon, points[i], points[i + 1], points[i + 2], points[i + 3], points[i + 2], horizon)
    end
    if blood_moon then
        Draw.set_color(C.danger, 0.1)
        LG.rectangle("fill", lane.x, lane.y, lane.w, horizon - lane.y)
    end
end

local function draw_ground(lane)
    local horizon, field = NIGHT.horizon_y, NIGHT.field
    local bottom = lane.y + lane.h
    for i = 0, 9 do
        Draw.set_color(Draw.lerp_color({ 0.12, 0.1, 0.12 }, { 0.04, 0.03, 0.05 }, i / 9))
        LG.rectangle("fill", lane.x, horizon + i * (bottom - horizon) / 10, lane.w, (bottom - horizon) / 10 + 1)
    end
    local top, base = field.y - 24, field.y + field.h + 34     -- 몬스터가 걷는 돌길
    Draw.set_color({ 0.2, 0.17, 0.17 }, 0.9)
    LG.rectangle("fill", lane.x, top, lane.w, base - top)
    Draw.set_color({ 0, 0, 0 }, 0.35)
    for x = lane.x, lane.x + lane.w, 46 do
        LG.line(x, top, x - 18, base)
    end
    Draw.set_color({ 0.03, 0.02, 0.03 })
    LG.setLineWidth(3)
    LG.line(lane.x, top, lane.x + lane.w, top)
    LG.line(lane.x, base, lane.x + lane.w, base)
end

-- 오른쪽 던전 포탈 (몬스터가 여기서 쏟아져 나온다)
local function draw_portal(time)
    local portal, field = NIGHT.portal, NIGHT.field
    local cy = field.y + field.h / 2 - portal.size * 0.18
    Draw.glow(portal.x, cy, portal.size * 0.75, PORTAL_GLOW, 0.55 + 0.15 * math.sin(time * 3))
    local image = SpriteBank.image("building_portal")
    if image ~= nil then
        SpriteBank.draw_fit(image, portal.x, cy, portal.size)
    else
        Draw.set_color(PORTAL_GLOW, 0.9)
        LG.ellipse("fill", portal.x, cy, portal.size * 0.22, portal.size * 0.36, 32)
    end
    AmbientEffects.draw_vortex(portal.x, cy + portal.size * 0.06, portal.size, time)
end

local function draw_wall(workshop)
    local wall = NIGHT.wall
    local ratio = workshop.hp / workshop.max_hp
    Draw.set_color(Draw.lerp_color(C.danger, C.wall, ratio))
    LG.rectangle("fill", wall.x, wall.y + 30, wall.w, wall.h - 30)
    for x = wall.x, wall.x + wall.w - 10, 16 do                -- 총안
        LG.rectangle("fill", x, wall.y + 12, 10, 20)
    end
    Draw.set_color({ 0, 0, 0 }, 0.35)
    for row = 0, math.floor(wall.h / 18) - 2 do
        local y = wall.y + 30 + row * 18
        LG.line(wall.x, y, wall.x + wall.w, y)
        LG.line(wall.x + (row % 2) * 9 + 6, y, wall.x + (row % 2) * 9 + 6, y + 18)
    end
    Draw.set_color({ 0.03, 0.02, 0.025 })
    LG.setLineWidth(4)
    LG.line(wall.x + wall.w, wall.y + 30, wall.x + wall.w, wall.y + wall.h)
end

local function body_color(monster)
    if monster.flash > 0 then
        return { 1, 1, 1 }
    end
    local color = monster.spec.color
    if monster:is_slowed() then
        color = Draw.lerp_color(color, SLOW_COLOR, 0.5)
    end
    if monster:is_burning() then
        color = Draw.lerp_color(color, BURN_COLOR, 0.35)
    end
    return color
end

-- 스프라이트용 색 곱: 평소 흰색, 둔화·화상·감전이면 물든다
local function sprite_tint(monster)
    local color = monster.spec.tint or WHITE          -- 중간 보스 고유 색조
    if monster:is_slowed() then
        color = Draw.lerp_color(color, SLOW_COLOR, 0.5)
    end
    if monster:is_burning() then
        color = Draw.lerp_color(color, BURN_COLOR, 0.4)
    end
    if monster:is_shocked() then
        color = Draw.lerp_color(color, SHOCK_COLOR, 0.3)
    end
    return color
end

-- 감전: 몸 둘레로 튀는 푸른 스파크
local function draw_shock(monster, time)
    local r = monster.radius * NIGHT.sprite_scale
    LG.setBlendMode("add")
    Draw.set_color(SHOCK_COLOR, 0.8)
    LG.setLineWidth(1.5)
    for i = 0, 2 do
        local a = time * 9 + i * 2.1 + monster.anim
        local x1, y1 = monster.x + math.cos(a) * r, monster.y + math.sin(a) * r
        LG.line(x1, y1, x1 + math.cos(a + 1.3) * r * 0.5, y1 + math.sin(a + 1.3) * r * 0.5)
    end
    LG.setBlendMode("alpha")
end

-- 보스 상태: 붉은 보호막 · 면역 오라와 표식 · 강탈한 골드 · 이름과 체력 막대
local function draw_boss_status(monster, time)
    local r, x, y = monster.radius * NIGHT.sprite_scale, monster.x, monster.y
    if monster.shield_time > 0 then
        local pulse = 0.5 + 0.3 * math.sin(time * 10)
        Draw.set_color(C.danger, 0.18 * pulse + 0.1)
        LG.circle("fill", x, y, r * 1.55, 32)
        Draw.set_color(C.danger, pulse)
        LG.setLineWidth(3)
        LG.circle("line", x, y, r * 1.55, 32)
    end
    if monster.immunity ~= nil then
        local color = IMMUNITY_COLORS[monster.immunity]
        Draw.set_color(color, 0.22 + 0.1 * math.sin(time * 4))
        LG.circle("fill", x, y, r * 1.35, 28)
        Draw.shadow_text(I18n.t("boss.immune_" .. monster.immunity), x - 70, y - r * 2.9, 140, "center", "label", color)
    end
    local state = monster.pattern
    if state ~= nil and state.stolen ~= nil and state.stolen > 0 then
        Draw.shadow_text(I18n.t("boss.stolen", { amount = state.stolen }), x - 70, y - r * 2.9, 140, "center", "label", C.gold)
    end
    Draw.text(I18n.t("monsters." .. monster.type_id), x - 70, y + r + 6, 140, "center", SIZE.tiny, C.danger)
    Draw.bar(x - r, y - r * 2.2, r * 2, 6, monster.hp / monster.max_hp, C.danger)
end

-- 그림 크기 = 충돌 반경 × sprite_scale (밸런스와 무관하게 크게 보이도록). pose: ui/EntityMotion 포즈 또는 nil
local function draw_body(monster, x, y, r, pose)
    local image, art = SpriteCatalog.monster_image(monster)
    if image ~= nil then
        local flash = pose and pose.flash or monster.flash > 0
        SpriteBank.draw_monster(image, monster, x, y - r * 0.25, r * SPRITE_SCALE, sprite_tint(monster), flash, art, pose)
        return
    end
    LG.push()                                   -- 도형 폴백도 같은 포즈(위치·기울기·스쿼시)를 따른다
    LG.translate(x + (pose and pose.dx or 0), y + (pose and pose.dy or 0))
    LG.rotate(pose and pose.rot or 0)
    LG.scale(pose and pose.sx or 1, pose and pose.sy or 1)
    local color = (pose and pose.flash) and { 1, 1, 1 } or body_color(monster)
    MonsterShapes.draw(monster.spec.shape, 0, 0, r, math.sin(monster.anim * 9), color)
    LG.pop()
end

local function draw_monster(monster, time, motion)
    local r = monster.radius * NIGHT.sprite_scale
    local x, y = monster.x, monster.y
    local boss, final = monster:is_boss(), monster.spec.final
    local pose = motion and motion:pose(monster, time)
    local px = x + (pose and pose.dx or 0)
    Draw.set_color({ 0, 0, 0 }, 0.3)
    LG.ellipse("fill", px, y + r * 0.95, r * (pose and pose.sx or 1), r * 0.3, 16)
    if final then                                     -- 최종 보스: 보랏빛 균열 오라 (ui/MasterBossView)
        MasterBossView.aura(monster, px, y, r, time)
    elseif boss then
        Draw.set_color(C.danger, 0.14 + 0.08 * math.sin(time * 4))
        LG.circle("fill", px, y, r * 1.6, 28)
    end
    if monster:is_midboss() then                      -- 중간 보스: 붉은/보라 잉크 오라 (ui/MidBossView)
        MidBossView.aura(monster, px, y, r, time)
    end
    if pose and pose.glow_alpha > 0.01 then           -- 방벽 공격 예비 동작: 붉은 기운
        Draw.glow(px, y, r * 1.8, pose.glow_color, 0.7 * pose.glow_alpha)
    end
    draw_body(monster, x, y, r, pose)
    if monster:is_shocked() then
        draw_shock(monster, time)
    end
    if final then                                     -- 균열 아이기스 돔 · 그로기 별 (체력은 레인 아래 전용 띠)
        MasterBossView.status(monster, px, y, r, time, SPRITE_SCALE)
    elseif boss then
        draw_boss_status(monster, time)
    elseif monster.hp < monster.max_hp then
        Draw.bar(x - r, y - r * 1.6, r * 2, 4, monster.hp / monster.max_hp, C.danger)
    end
end

-- 방벽에 부딪힌 몬스터의 잔상: 타격 스쿼시 → 물러나며 사라진다
local function draw_ghosts(motion, time)
    for _, ghost in ipairs(motion:ghosts()) do
        local pose = motion:ghost_pose(ghost, time)
        local r = ghost.monster.radius * NIGHT.sprite_scale
        Draw.glow(ghost.x + pose.dx, ghost.y, r * 1.6, pose.glow_color, 0.6 * pose.glow_alpha)
        draw_body(ghost.monster, ghost.x, ghost.y, r, pose)
    end
end

-- motion: ui/EntityMotion (없으면 포즈 없이 정지 그림)
function LaneView.draw(workshop, time, motion)
    local lane = NIGHT.lane
    local combat = workshop.combat
    Viewport.set_scissor(lane.x, lane.y, lane.w, lane.h)
    if not LaneScenery.draw_background(lane) then      -- 원화 배경·건물(ui/LaneScenery), 없으면 코드 배경
        draw_sky(workshop, lane, time)
        draw_ground(lane)
    end
    if not LaneScenery.draw_portal(time) then
        draw_portal(time)
    end
    local hit = motion and motion.wall_hit or 0
    local building = LaneScenery.draw_workshop(time, hit)
    local hero = motion and motion.hero
    if hero then hero:draw(time) end
    for _, monster in ipairs(combat.monsters) do
        draw_monster(monster, time, motion)
    end
    if motion ~= nil then
        draw_ghosts(motion, time)
        hero:draw_effects(time)
    end
    MidBossView.draw_overlay(combat, lane, time)        -- 중간 보스 전용 이름·체력 바 + 출현 경고 배너
    MasterBossView.draw_overlay(combat, lane, time, motion)   -- 최종 보스 전용 체력 띠 · 출현 경고 · 결말 배너
    if building then
        LaneScenery.draw_ward(time, hit, motion and motion.wall_hit_y)
    else
        draw_wall(workshop)
    end
    Viewport.set_scissor()
    Frame.border(lane.x, lane.y, lane.w, lane.h, "iron")
    -- 새벽까지 진행 막대 (오른쪽 위는 배속 토글 자리). 새벽이 지났는데 몬스터가 남았으면 소탕 시간 — 붉게 맥동하며 남은 수
    local overtime = combat:in_overtime()
    local fill = overtime and Draw.lerp_color(C.danger, { 1, 0.85, 0.7 }, 0.3 + 0.3 * math.sin(time * 6)) or C.link_boost
    local bar_x = NIGHT.wall.x + NIGHT.wall.w + 14                  -- 방벽(공방 건물) 오른쪽부터 배속 토글 앞까지
    local bar_w = lane.x + lane.w - 120 - bar_x
    Draw.bar(bar_x, lane.y + 10, bar_w, 7, math.min(1, combat.elapsed / combat.duration), fill)
    local label = overtime and I18n.t("lane.overtime", { count = combat:alive_count() }) or I18n.t("lane.until_dawn")
    Draw.label_text(label, bar_x, lane.y + 20, bar_w, "left", SIZE.tiny, overtime and C.danger or C.text)
    local speed = LAYOUT.buttons.speed                           -- 밤 전투 중 설정을 열면 전투가 멈춘다는 안내
    Draw.label_text(I18n.t("lane.pause_hint"), lane.x, speed.y + speed.h + 4, lane.w - 8, "right", SIZE.tiny, C.text_dim)
end

LaneView.SPRITE_SCALE = SPRITE_SCALE     -- 개발 도구(스모크 도감 이미지)용

return LaneView
