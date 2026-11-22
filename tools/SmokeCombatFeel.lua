-- tools/SmokeCombatFeel.lua
-- 헤드리스 검사 (SmokeTest 가 SmokeCursor 다음에 실행): 전투 쾌적성·타격감·연출 폴리싱.
--   배속 고정 서브스텝: 3배속 1프레임 = 1배속 3프레임 (같은 시드면 경과·처치·몬스터 위치·방벽이 같다) · 프레임 정지 따라잡기 상한
--   넉백: 일반 전부 · 정예 50% · 보스 15%만 밀리고 조준 구역 밖으로는 안 밀린다 / 화염 스플래시: 주변 적만 피해 비율만큼
--   치명타 확률 · 히트스톱(번개·치명타, 재발동 쿨타임 0.18초, 멈춘 시간 합)
--   몬스터 툴팁: 호버 판정 · 상태이상(감전) · 특성(중장갑·보스 기믹) · 화면 밖으로 안 잘림 (오프스크린)
--   용광로 오버클럭: 가열 시간 0.42초 · 대성공/파괴 연출 상태 전환 · +1 제련은 연출 없음
--   UV 적발: 위조 이벤트 · 원래 요구가 > 할인가 · 모험가 반응 대사·움찔·꼬리표 강조
--   오디오 장면 크로스페이드 (소리 파일이 있을 때): 밤으로 바꾸면 밤 배경음이 오르고 낮 배경음이 내려간다

local SmokeCombatFeel = {}

local DT = 1 / 60

local function check(condition, message)
    if not condition then
        error("SmokeCombatFeel: " .. message, 2)
    end
end

local function stocked_night(speed, frames)
    local RNG = require("core.RNG")
    local FixedStep = require("core.FixedStep")
    local Item = require("entities.Item")
    RNG.set_seed(31337)
    local w = require("systems.Workshop")({ difficulty = "broker", starter = true })
    w.day = 6
    local orb = Item("lightning_orb", { grade = "rare" })
    orb.owned = true
    w.inventory:place(orb, "grid", 13)
    w:start_night()
    for _ = 1, frames do
        FixedStep.run(DT, speed, function(step) w:update(step) end)
    end
    local snapshot = { elapsed = w.combat.elapsed, kills = w.stats.kills, hp = w.hp, count = #w.combat.monsters, x = 0 }
    for _, monster in ipairs(w.combat.monsters) do
        snapshot.x = snapshot.x + monster.x
    end
    w:destroy()
    return snapshot
end

local function check_fixed_step()
    local FixedStep = require("core.FixedStep")
    local calls = 0
    check(FixedStep.run(DT, 3, function() calls = calls + 1 end) == 3 and calls == 3, "3x speed runs three 1/60 substeps")
    check(FixedStep.run(0.5, 1, function() end) == 6, "a frame hitch catches up at most 0.1s of real time")
    local slow, fast = stocked_night(1, 360), stocked_night(3, 120)
    check(math.abs(slow.elapsed - fast.elapsed) < 1e-6, "same simulated time at 1x and 3x")
    check(slow.kills == fast.kills and slow.hp == fast.hp and slow.count == fast.count and math.abs(slow.x - fast.x) < 1e-3,
        "3x speed gives exactly the same battle as 1x (kills, wall, monsters)")
    return slow.kills
end

local function check_impacts()
    local EventBus = require("core.EventBus")
    local Item = require("entities.Item")
    local Monster = require("entities.Monster")
    local LAYOUT = require("data.layout")
    local w = require("systems.Workshop")({ difficulty = "broker" })
    local scale = LAYOUT.night.field_scale
    local hammer, sword = Item("starforge_hammer", { grade = "rare" }), Item("flame_sword", { grade = "rare" })
    hammer.owned, sword.owned = true, true
    w.inventory:place(hammer, "grid", 13)
    w.inventory:place(sword, "grid", 12)
    w:start_night()                     -- 보스 패턴·전투 상태가 준비된 밤
    local slime, ogre, golem = Monster("slime", 700, 450, 1, 0, 1, scale), Monster("ogre", 700, 470, 1, 0, 1, scale),
        Monster("gatekeeper_golem", 700, 430, 1, 0, 1, scale)
    local pushed = {}
    for _, monster in ipairs({ slime, ogre, golem }) do
        local before = monster.x
        EventBus.emit("combat:hit", { item = hammer, monster = monster, damage = 1, combat = w.combat, chained = false })
        pushed[monster.type_id] = monster.x - before
    end
    check(pushed.slime > 0 and math.abs(pushed.ogre - pushed.slime * 0.5) < 0.01 and math.abs(pushed.gatekeeper_golem - pushed.slime * 0.15) < 0.01,
        "knockback: normal full, elite 50%, boss 15%")
    local far = Monster("slime", 1300, 450, 1, 0, 1, scale)
    EventBus.emit("combat:hit", { item = hammer, monster = far, damage = 1, combat = w.combat, chained = false })
    check(far.x == 1300, "monsters outside the aim zone are not pushed further")
    -- 화염 스플래시: 맞은 적 주변만
    local target, near, distant = Monster("slime", 800, 450, 1, 0, 1, scale), Monster("slime", 830, 460, 1, 0, 1, scale),
        Monster("slime", 1100, 450, 1, 0, 1, scale)
    w.combat.monsters = { target, near, distant }
    local splashes = 0
    local probe = {}
    EventBus.subscribe("combat:splash", function() splashes = splashes + 1 end, { owner = probe })
    EventBus.emit("combat:hit", { item = sword, monster = target, damage = 10, combat = w.combat, chained = false })
    EventBus.unsubscribe_owner(probe)
    check(splashes == 1 and near.hp < near.max_hp and distant.hp == distant.max_hp and target.hp == target.max_hp,
        "fire splash hits only nearby monsters (the target takes the main hit separately)")
    w:destroy()
end

local function check_crit_and_hitstop()
    local EventBus = require("core.EventBus")
    local DamageRules = require("systems.DamageRules")
    local COMBAT = require("data.combat")
    local crits = 0
    for _ = 1, 5000 do
        crits = crits + (select(2, DamageRules.roll_crit()) and 1 or 0)
    end
    check(math.abs(crits / 5000 - COMBAT.crit.chance) < 0.015, "crit chance should match data, got " .. crits / 5000)
    local HitStop = require("ui.HitStop")
    local stop = HitStop(nil)
    local monster = require("entities.Monster")("slime", 0, 0)
    EventBus.emit("combat:damage_dealt", { monster = monster, amount = 1, damage_type = "lightning", x = 0, y = 0 })
    EventBus.emit("combat:damage_dealt", { monster = monster, amount = 1, damage_type = "lightning", x = 0, y = 0 })
    check(stop.triggered == 1 and stop:is_frozen(), "lightning hitstop fires once, the second hit is inside the cooldown")
    local frozen = stop:consume(0.1)
    check(math.abs(frozen - require("data.attacks").hitstop.lightning) < 1e-9 and not stop:is_frozen(), "hitstop freezes ~0.03s")
    stop:consume(0.2)
    EventBus.emit("combat:damage_dealt", { monster = monster, amount = 1, damage_type = "fire", crit = true, x = 0, y = 0 })
    check(stop.triggered == 2, "crits trigger hitstop again after the 0.18s cooldown")
    EventBus.emit("combat:damage_dealt", { monster = monster, amount = 1, damage_type = "fire", x = 0, y = 0 })
    check(stop.triggered == 2, "plain fire hits do not stop the battle")
    stop:destroy()
end

local function check_tooltip(canvas)
    local Monster = require("entities.Monster")
    local MonsterTooltip = require("ui.MonsterTooltip")
    local LAYOUT = require("data.layout")
    local shield = Monster("shield_bearer", 900, 450, 1, 0, 1, LAYOUT.night.field_scale)
    shield:apply_shock(2)
    local combat = { monsters = { shield } }
    check(MonsterTooltip.hovered(combat, 900, 445) == shield and MonsterTooltip.hovered(combat, 600, 300) == nil, "hover hit test")
    check(#MonsterTooltip.statuses(shield) >= 1 and #MonsterTooltip.traits(shield) >= 2, "shocked shieldbearer lists status and traits")
    local boss = Monster("rift_lord", 1000, 450)
    check(MonsterTooltip.tier(boss) == "boss" and #MonsterTooltip.traits(boss) >= 2, "bosses show knockback resistance and gimmick")
    love.graphics.setCanvas({ canvas, stencil = true })
    for _, pointer in ipairs({ { 900, 445 }, { 1270, 710 }, { 5, 5 } }) do
        local bx, by, w, h = MonsterTooltip.draw(boss, pointer[1], pointer[2])
        check(bx >= 0 and by >= 0 and bx + w <= LAYOUT.screen.w and by + h <= LAYOUT.screen.h, "tooltip stays on screen")
    end
    love.graphics.setCanvas()
end

local function check_forge_and_uv(canvas)
    local EventBus = require("core.EventBus")
    local Item = require("entities.Item")
    local ItemFactory = require("systems.ItemFactory")
    local Scanner = require("systems.Scanner")
    local FORGE = require("data.forge")
    local w = require("systems.Workshop")({ difficulty = "broker" })
    local drama = require("ui.ForgeDrama")(require("ui.Effects")())
    local relic = ItemFactory.make_ready("flame_sword", "rare", 1)
    w.inventory:place(relic, "furnace", 1)
    w.tempering_stones = 3
    check(w.forge:start() and w.forge.forging.duration == FORGE.risky_anticipation and drama.state.phase == "heat",
        "stone forging (+2) heats for 0.42s")
    love.graphics.setCanvas({ canvas, stencil = true })
    drama:update(0.2)
    drama:draw(1)
    EventBus.emit("forge:succeeded", { item = relic, level = 2, x = 100, y = 600, overclock = true })
    check(drama.state.phase == "success", "overclock success shows the gold banner")
    drama:draw(1)
    EventBus.emit("forge:failed", { item = relic, outcome = "keep", from = 1, level = 1, x = 100, y = 600, overclock = true })
    check(drama.state.phase == "dud", "a kept level shows grey smoke")
    drama:draw(1)
    EventBus.emit("forge:failed", { item = relic, outcome = "down", from = 4, level = 3, x = 100, y = 600, overclock = true })
    check(drama.state.phase == "dud" and drama.state.outcome == "down", "a dropped level shows grey smoke")
    EventBus.emit("forge:failed", { item = relic, outcome = "destroyed", scrap = 5, x = 100, y = 600, overclock = true })
    check(drama.state.phase == "shatter", "a shattered relic cracks red")
    drama:draw(1)
    love.graphics.setCanvas()
    drama.state = nil
    EventBus.emit("forge:succeeded", { item = relic, level = 1, x = 100, y = 600, overclock = false })
    check(drama.state == nil, "+1 refine has no overclock drama")
    drama:destroy()
    w.forge.forging = nil
    -- UV 적발: 위조 이벤트 · 할인 · 모험가 반응
    local reaction = require("ui.GuestReaction")()
    local item = Item("golden_chalice", { grade = "rare", claimed_grade = "legendary", flaw = "curse", adventurer = "cedric",
        ask_mult = 1.3 })
    w.inventory:remove(relic)
    w.appraisal:present_customer(item, false)
    local forged = 0
    local probe = {}
    EventBus.subscribe("appraisal:forgery_revealed", function() forged = forged + 1 end, { owner = probe })
    local list = item:list_price()
    Scanner.reveal_grade(item, 100, 100)
    check(forged == 1 and item:asking_price() < list and reaction:line(item) ~= nil, "forgery exposed: event, discount, Cedric reacts")
    reaction:update(0.05)
    local dx, rot = reaction:pose(item)
    check((dx ~= 0 or rot ~= 0) and reaction:flash(item, "grade") > 0, "portrait flinches, grade row flashes")
    local before = item:asking_price()
    Scanner.reveal_flaw(item, 100, 100, 200)
    check(item:asking_price() < before and reaction:flash(item, "flaw") > 0, "curse mark exposed: further discount, flaw row flashes")
    EventBus.unsubscribe_owner(probe)
    reaction:destroy()
    w:destroy()
end

local function check_audio_scenes()
    local Audio = require("systems.Audio")
    if Audio.loop_level("night_bgm") == nil then
        return false                -- 소리 파일이 없는 실행 (--missing-assets)
    end
    Audio.set_scene("day")
    for _ = 1, 40 do
        Audio.update(0.05)
    end
    local day = Audio.loop_level("day_bgm")
    Audio.set_scene("night")
    Audio.update(0.5)
    check(Audio.loop_level("night_bgm") > 0 and Audio.loop_level("day_bgm") < day, "day -> night crossfades the music")
    Audio.stop_loops()
    check(Audio.is_bgm_playing(), "pausing (stop_loops) keeps the scene music")
    Audio.set_scene("menu")
    return true
end

function SmokeCombatFeel.run(log)
    local Viewport = require("core.Viewport")
    local canvas = love.graphics.newCanvas(Viewport.width(), Viewport.height())
    love.graphics.push("all")
    local kills = check_fixed_step()
    check_impacts()
    check_crit_and_hitstop()
    check_tooltip(canvas)
    check_forge_and_uv(canvas)
    love.graphics.pop()
    local audio = check_audio_scenes()
    log("combat feel ok (1x == 3x fixed substeps, %d kills; knockback resist; fire splash; crit; hitstop cooldown; tooltip; "
        .. "forge overclock drama; UV forgery discount + reaction%s)", kills, audio and "; audio crossfade" or "")
end

return SmokeCombatFeel
