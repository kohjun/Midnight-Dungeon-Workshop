-- tools/SmokeAnimation.lua
-- 헤드리스 검사 (SmokeTest 가 SmokeTransitions 다음에 실행): 절차적 애니메이션.
--   ui/MeshDeformer : 4x6 격자(꼭짓점 35개) · 프리셋 4종 변형 · breathe/jelly 는 발바닥(맨 아래 줄) 고정, float_cape 는 전체 이동
--                     · 그림 일부(region) 메시 · 꺼졌을 때 love.graphics.draw 폴백 — 원화가 없어도 시험용 이미지를 만들어 검사
--   ui/EntityMotion : light/heavy 보행 포즈 차이 · heavy 발밑 먼지 · 방벽 직전 windup → lunge · 방벽 타격 잔상 · 피격 흰 점멸(0.06초)·넉백 복원
--   ui/AmbientEffects: 진열장 부유 위상 차이 · 충전 85% 이상 확대 · 세척 시 유물 튀어 오름 · 주인장 반응 포즈 · 포탈 소용돌이/먼지 그리기
--   뒤집기·흰 점멸 셰이더·포일과 함께 그려도 오류가 없는지 (오프스크린). --shots 면 몬스터·보스 도감(smoke_bestiary.png)

local SmokeAnimation = {}

local function check(condition, message)
    if not condition then
        error("SmokeAnimation: " .. message, 2)
    end
end

local function test_image()
    local data = love.image.newImageData(64, 96)
    data:mapPixel(function(x, y) return 0.6, 0.4 + y / 300, 0.3, (x > 4 and x < 60) and 1 or 0 end)
    return love.graphics.newImage(data)
end

local function check_deformer(canvas)
    local MeshDeformer = require("ui.MeshDeformer")
    local image = test_image()
    love.graphics.setCanvas({ canvas, stencil = true })
    for _, preset in ipairs({ "breathe", "jelly", "float_cape", "heavy_mech" }) do
        local key = {}
        MeshDeformer.draw(image, preset, 0, key)
        local first = {}
        for i, vert in ipairs(MeshDeformer.vertices(key)) do
            first[i] = { vert[1], vert[2] }
        end
        check(#first == MeshDeformer.vertex_count() and #first == 35, preset .. " uses a 4x6 grid (35 vertices)")
        MeshDeformer.draw(image, preset, 1.3, key)
        local verts, moved, bottom_moved = MeshDeformer.vertices(key), 0, 0
        for i, vert in ipairs(verts) do
            local d = math.abs(vert[1] - first[i][1]) + math.abs(vert[2] - first[i][2])
            moved = moved + (d > 1e-4 and 1 or 0)
            if i > #verts - 5 and d > 1e-6 then
                bottom_moved = bottom_moved + 1
            end
        end
        check(moved > 0, preset .. " should move vertices over time")
        if preset == "breathe" or preset == "jelly" then
            check(bottom_moved == 0, preset .. " keeps the feet (bottom row) pinned")
        elseif preset == "float_cape" then
            check(bottom_moved > 0, "float_cape floats without pinned feet")
        end
    end
    MeshDeformer.draw(image, "breathe", 2, {}, { x = 0.2, y = 0, w = 0.5, h = 0.4 })      -- 초상처럼 그림 일부
    MeshDeformer.set_enabled(false)
    MeshDeformer.draw(image, "jelly", 1, {})                                            -- 메시 없이 평면 폴백
    MeshDeformer.draw(image, "breathe", 1, {}, { x = 0.2, y = 0, w = 0.5, h = 0.4 })
    MeshDeformer.set_enabled(true)
    love.graphics.setCanvas()
    return image
end

local function check_motion(image, canvas)
    local EventBus = require("core.EventBus")
    local Monster = require("entities.Monster")
    local Workshop = require("systems.Workshop")
    local Effects = require("ui.Effects")
    local EntityMotion = require("ui.EntityMotion")
    local SpriteBank = require("ui.SpriteBank")
    local LAYOUT = require("data.layout")
    local ANIM = require("data.animations")
    local w = Workshop({ difficulty = "broker" })
    local fx = Effects()
    local motion = EntityMotion(fx, w)
    local wall_x = LAYOUT.night.wall.x + LAYOUT.night.wall.w
    local goblin, ogre = Monster("goblin", 900, 450, 1, 0.3, 1, 1.27), Monster("ogre", 1000, 470, 1, 0.3, 1, 1.27)
    local combat = { monsters = { goblin, ogre } }
    goblin.anim, ogre.anim = 0.2, 0.2
    local light, heavy = motion:pose(goblin, 1), nil
    local light_rot, light_dy = light.rot, light.dy
    heavy = motion:pose(ogre, 1)
    check(light_rot < 0 and heavy.rot ~= light_rot, "light gait tilts forward, heavy gait differs")
    check(light_dy < 0, "light gait hops")
    local particles = fx:particle_count()
    for _ = 1, 60 do
        ogre.anim = ogre.anim + 1 / 60
        motion:update(1 / 60, combat)
    end
    check(fx:particle_count() > particles, "heavy steps kick up dust")
    -- 방벽 직전: windup → lunge
    goblin.x = wall_x + goblin.radius + goblin.speed * (ANIM.wall.windup + ANIM.wall.lunge) * 0.9
    motion:update(1 / 60, combat)
    check(motion:state(goblin).phase == "windup", "monster winds up just before the wall")
    local anchored = motion:pose(goblin, 1)
    check(anchored.glow_alpha >= 0 and anchored.dx >= 0, "windup leans back with a red glow")
    for _ = 1, 15 do
        motion:update(1 / 60, combat)
    end
    check(motion:state(goblin).phase == "lunge", "windup turns into a lunge")
    EventBus.emit("combat:wall_hit", { monster = goblin, damage = 1, x = wall_x, y = goblin.y })
    check(#motion:ghosts() == 1, "wall hit leaves an impact ghost")
    motion:update(0.04, combat)
    local squash = motion:ghost_pose(motion:ghosts()[1], 1)
    check(squash.sx < 1 and squash.sy > 1, "the ghost squashes on impact")
    -- 피격: 흰 점멸 0.06초 + 넉백 후 복원
    EventBus.emit("combat:damage_dealt", { monster = ogre, amount = 3, x = ogre.x, y = ogre.y })
    check(motion:pose(ogre, 1).flash, "hit flashes white")
    for _ = 1, 5 do
        motion:update(1 / 60, combat)
    end
    check(not motion:pose(ogre, 1).flash and motion:state(ogre).push_x > 0.5, "flash ends after 0.06s, knockback pushes away")
    for _ = 1, 120 do
        motion:update(1 / 60, combat)
    end
    check(math.abs(motion:state(ogre).push_x) < 0.5, "knockback springs back")
    love.graphics.setCanvas({ canvas, stencil = true })     -- 뒤집기 + 흰 점멸 + 붉은 기운 + 메시를 함께 그린다
    for _, flash in ipairs({ false, true }) do
        local pose = motion:pose(goblin, 2)
        pose.flash, pose.glow_alpha = flash, 0.8
        SpriteBank.draw_monster(image, goblin, 400, 300, 80, { 1, 1, 1 }, flash, { flip = true, scale = 1.2 }, pose)
    end
    love.graphics.setCanvas()
    motion:destroy()
    w:destroy()
end

local function check_ambient(canvas)
    local EventBus = require("core.EventBus")
    local Item = require("entities.Item")
    local Effects = require("ui.Effects")
    local AmbientEffects = require("ui.AmbientEffects")
    local ItemRenderer = require("ui.ItemRenderer")
    local ambient = AmbientEffects(Effects())
    check(AmbientEffects.levitation(1, 2) ~= AmbientEffects.levitation(2, 2), "cells levitate with different phases")
    local scale = AmbientEffects.charge_pose(0.5)
    local charged = AmbientEffects.charge_pose(0.97)
    check(scale == 1 and charged > 1, "weapons swell when the cooldown is 85%+ charged")
    local item = Item("flame_sword", { grade = "rare" })
    EventBus.emit("appraisal:cleaned", { item = item, x = 300, y = 300 })
    ambient:update(0.1, "day")
    check(ambient:hop(item) < 0, "cleaned relic hops up")
    local rot, dx, dy = ambient:portrait_pose()
    check(rot ~= 0 or dx ~= 0 or dy ~= 0, "shopkeeper reacts to cleaning")
    ambient:update(0.5, "night")
    love.graphics.setCanvas({ canvas, stencil = true })
    ambient:draw_motes()
    AmbientEffects.draw_vortex(600, 300, 300, 1.5)
    item.level = 3                                       -- 포일 + 반동 + 충전 확대가 함께
    require("ui.SpriteBank").kick(item, 1, -1, 0)
    ItemRenderer.draw(item, 200, 200, 80, { time = 1, scale = 1.1 })
    love.graphics.setCanvas()
    ambient:destroy()
end

local function render_bestiary(filename)
    local Monster = require("entities.Monster")
    local SpriteBank = require("ui.SpriteBank")
    local LaneView = require("ui.LaneView")
    local ENEMIES = require("data.enemies")
    local ANIM = require("data.animations")
    local ids = {}
    for id in pairs(ENEMIES.monsters) do        -- 중간 보스도 원화(확대·색조)로 같이 그린다
        ids[#ids + 1] = id
    end
    table.sort(ids)
    local canvas = love.graphics.newCanvas(1280, 220)
    love.graphics.push("all")
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.clear(0.08, 0.07, 0.1, 1)
    for i, id in ipairs(ids) do
        local monster = Monster(id, 54 + (i - 1) * 90, 120)
        local image, art = require("ui.SpriteCatalog").monster_image(monster)
        if image ~= nil then
            SpriteBank.draw_monster(image, monster, monster.x, monster.y - monster.radius * 0.25,
                monster.radius * LaneView.SPRITE_SCALE, monster.spec.tint or { 1, 1, 1 }, false, art,
                { deform = ANIM.monsters[monster.art_id], time = 1 })
        end
    end
    love.graphics.setCanvas()
    love.graphics.pop()
    canvas:newImageData():encode("png", filename)
end

function SmokeAnimation.run(log, shots)
    local Viewport = require("core.Viewport")
    local canvas = love.graphics.newCanvas(Viewport.width(), Viewport.height())
    love.graphics.push("all")
    local image = check_deformer(canvas)
    check_motion(image, canvas)
    check_ambient(canvas)
    love.graphics.pop()
    if shots then
        render_bestiary("smoke_bestiary.png")
    end
    log("animation ok (mesh 4x6 · breathe/jelly pinned feet · float_cape drift · flat fallback; gaits, wall windup/lunge/ghost, "
        .. "hit flash + knockback spring; levitation, charge, bench hop, portrait reaction)")
end

return SmokeAnimation
