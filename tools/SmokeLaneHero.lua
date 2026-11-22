-- tools/SmokeLaneHero.lua
-- 공명 회로 세계관 연출 스모크 검사 (SmokeTest 가 SmokeTraceBattle 다음에 실행 — 그 파일의 kit 로 오프스크린에 그린다):
--   ① 인트로: 7장면(circuit 이 6번째) · 14비트 = 로케일 intro.lines 14줄(ko · en) · circuit 장면 종류(일러스트 / 공방 배경 + 황금 틴트 /
--      코드)와 회로판 점등 픽셀 (--shots: smoke_circuit_scene.png — 시나리오의 smoke_intro_circuit.png 는 내레이션이 얹힌 실제 장면)
--   ② 마력 도선(ui/ConduitView): 가로 20 + 세로 20 토막 · 낮에는 꺼짐 · 밤이 시작되면 정중앙에서 바깥으로 점등 ·
--      상태 sealed / idle / live / link · 켜진 도선의 황금빛 픽셀 · 과부하면 붉은 주황 (--shots: smoke_conduits_day.png)
--   ③ 중앙 코어 (3,3): 모서리 표식 픽셀 · 빈 칸 안내 상자 · 유물 툴팁 끝 줄 · 진열장 머리 호버 문구
--   ④ 레인의 주인공(ui/LaneHero): 방벽선 앞 배치 · 동조 유물(중앙 → 최고 강화 → 없음)과 오라 색 · combat:fired → 섬광 + 쿨타임마다
--      동조 투사 · combat:hero_strike(주인공의 실제 타격) → 근접 내려찍기 · combat:wall_hit → 방어 + 룬 방패(방어 중에는 투사 안 함,
--      반격은 방어 포즈 그대로) ·
--      밤이 시작되면 초기화 · 원화 3포즈가 같은 배율 · 원화 없이도 실루엣으로 그려짐
--      (--shots: smoke_hero_idle.png · smoke_hero_attack.png · smoke_hero_block.png)

local SmokeLaneHero = {}

local function kit()
    return require("tools.SmokeTraceBattle").kit
end

local function check(condition, message)
    if not condition then
        error("SmokeLaneHero: " .. message, 2)
    end
end

local function gold(r, g, b)
    return r > 0.6 and g > 0.42 and b < g and r >= g
end

local function check_intro(shots, missing_assets)
    local INTRO, I18n = require("data.intro"), require("systems.I18n")
    check(#INTRO.stages == 7 and INTRO.stages[6].id == "circuit" and INTRO.stages[7].id == "vow" and #INTRO.beats == 14,
        "the intro has 7 scenes (circuit before vow) and 14 beats")
    for _, code in ipairs({ "ko", "en" }) do
        require("systems.Settings").set("language", code)
        check(#I18n.list("intro.lines") == #INTRO.beats, "intro.lines matches the beats (" .. code .. ")")
    end
    require("systems.Settings").set("language", "ko")
    local scene = require("ui.IntroCircuit")()
    local has_art = love.filesystem.getInfo(INTRO.circuit.image) ~= nil
    local has_room = love.filesystem.getInfo(INTRO.circuit.fallback) ~= nil
    local expected = has_art and "illustration" or (has_room and "fallback" or "code")
    check(scene:kind() == expected and (not missing_assets or scene:kind() == "code"), "circuit scene kind: " .. scene:kind())
    local start = INTRO.stages[6].start
    local early = kit().render(nil, false, function() scene:draw(start + 0.2) end)
    local late = kit().render("smoke_circuit_scene.png", shots, function() scene:draw(start + 5.6) end)
    if scene:kind() ~= "illustration" then          -- 코드 회로판: 가운데 소켓이 황금빛으로 켜지고 화면이 밝아진다
        local board = require("data.circuit").intro.board
        local cx, cy = 1280 * board.x, 720 * board.y
        check(kit().any_pixel(late, cx, cy, 4, gold), "the centre socket is lit gold")
        check(kit().brightness(late, cx - 170, cy - 170, 340, 340) > kit().brightness(early, cx - 170, cy - 170, 340, 340) * 1.15,
            "the circuit board lights up over time")
    end
end

local function check_conduits(w, ui, shots)
    local ConduitView, Grid, Slots, CIRCUIT = require("ui.ConduitView"), require("systems.Grid"), require("ui.Slots"), require("data.circuit")
    local horizontal, vertical = 0, 0
    for _, segment in ipairs(ConduitView.SEGMENTS) do
        horizontal, vertical = horizontal + (segment.horizontal and 1 or 0), vertical + (segment.horizontal and 0 or 1)
        check(ConduitView.lit(w, segment) == 0, "conduits are unlit by day")
    end
    check(horizontal == 20 and vertical == 20, "20 horizontal + 20 vertical conduits link the 25 sockets")
    local function segment_of(a, b)
        for _, segment in ipairs(ConduitView.SEGMENTS) do
            if segment.a == a and segment.b == b then
                return segment
            end
        end
    end
    kit().ready(w, "flame_sword", 3, 12)             -- (3,2) 무기 — (3,3) 증폭기와 시너지
    kit().ready(w, "mana_crystal", 0, Grid.CORE)
    kit().ready(w, "storm_rod", 1, 18)               -- (4,3) 무기: 증폭기 아래
    kit().ready(w, "frost_crossbow", 0, 17)          -- (4,2) 무기: 18번과 나란히 (시너지 없음)
    local linked = {}
    for _, link in ipairs(w:grid_stats().links) do
        linked[math.min(link.from, link.to) * 100 + math.max(link.from, link.to)] = true
    end
    check(ConduitView.state(w, segment_of(12, 13), linked) == "link", "a synergy pair is a link conduit")
    check(ConduitView.state(w, segment_of(17, 18), linked) == "live", "two working relics make a live conduit")
    check(ConduitView.state(w, segment_of(7, 8), linked) == "idle" and ConduitView.state(w, segment_of(1, 2), linked) == "sealed",
        "empty cells idle, sealed cells dark")
    kit().render("smoke_conduits_day.png", shots, function()
        require("ui.DayLayoutView").draw(w, ui.input, 1.0)
        ui.hud:draw(w, 1.0)
    end)
    local data = kit().grid_only(w, ui, 1.0)         -- 중앙 코어 모서리 표식 (낮): 같은 자리의 다른 열린 칸보다 황금빛
    local function warmth(index)
        local x, y = Slots.rect("grid", index)
        local best = -1
        for dy = -1, 1 do
            for dx = -1, 1 do
                local r, _, b = data:getPixel(x + CIRCUIT.core_mark.inset + dx, y + CIRCUIT.core_mark.inset + dy)
                best = math.max(best, r - b)
            end
        end
        return best
    end
    check(warmth(Grid.CORE) > warmth(14) + 0.12, string.format("the centre core has golden corner marks (%.2f vs %.2f)", warmth(Grid.CORE), warmth(14)))
    return segment_of
end

local function check_core(w, ui)
    local ConduitView, Grid, Tooltip, I18n = require("ui.ConduitView"), require("systems.Grid"), require("ui.Tooltip"), require("systems.I18n")
    local lines = ConduitView.core_lines(Grid.CORE)
    check(lines ~= nil and #lines == 2 and ConduitView.core_lines(12) == nil, "only the centre cell is the core")
    kit().no_holes(lines, "core tooltip")
    local found = false
    for _, line in ipairs(Tooltip.lines(w.inventory:get("grid", Grid.CORE), nil, w)) do
        found = found or line.text == I18n.t("grid.core_title")
    end
    check(found, "a relic in the core gets the core line in its tooltip")
    local hover, header = require("ui.HoverTooltip")(w), require("data.layout").day.grid_section
    local pointer = { x = header.x + 40, y = header.y + 12 }
    for _ = 1, 3 do                                  -- 첫 프레임은 영역 진입, 그 뒤 0.35초를 넘겨야 뜬다
        hover:update(0.3, pointer, false)
    end
    local _, body = hover:content()
    check(hover:visible_id() == "grid" and body ~= nil and #body == 2 and body[2][1] == I18n.t("hover.grid.core"),
        "the showcase header hover explains the conduits and the centre core")
    kit().no_holes(body, "showcase hover")
end

local function check_night(w, ui, shots, segment_of)
    local ConduitView, LaneHero, Grid = require("ui.ConduitView"), require("ui.LaneHero"), require("systems.Grid")
    local Monster, EventBus, ITEMS = require("entities.Monster"), require("core.EventBus"), require("data.items")
    local ANIM, LAYOUT = require("data.animations").hero, require("data.layout")
    local wall_x = LAYOUT.night.wall.x + LAYOUT.night.wall.w
    local hero = ui.motion.hero
    local core = w.inventory:get("grid", Grid.CORE)
    check(LaneHero.focus(w) == core and hero:color() == ITEMS.elements[core.element].color, "the hero attunes to the core relic")
    w.inventory:remove(core)
    check(LaneHero.focus(w) == w.inventory:get("grid", 12), "an empty core falls back to the highest forged relic")
    w.inventory:place(core, "grid", Grid.CORE)
    w.max_hp, w.hp = 100000, 100000
    require("ui.Slots").set_mode_provider(function() return "night" end)
    check(w:start_night(), "the night should start")
    check(ConduitView.lit(w, segment_of(1, 2)) == 0, "conduits start dark at nightfall")
    ui.step(0.2)
    check(ConduitView.lit(w, segment_of(12, 13)) > 0 and ConduitView.lit(w, segment_of(1, 2)) == 0,
        "ignition spreads outward from the centre")
    ui.step(3)
    local x, ground_y, height = LaneHero.anchor()
    check(x > wall_x and x < wall_x + 80, "the hero stands just in front of the ward line")
    local lane = LAYOUT.night.lane
    check(ground_y > LAYOUT.night.field.y and ground_y < lane.y + lane.h and height > 80, "the hero stands on the road")
    for _, monster in ipairs(w.combat.monsters) do  -- 조용한 무대: 몬스터를 치우고 포즈를 직접 일으킨다
        monster.dead = true
    end
    w.combat.monsters = {}
    hero:reset()
    local draw = function(time)
        require("ui.NightLayoutView").draw(w, ui.input, time, { attacks = ui.attacks, motion = ui.motion })
        ui.hud:draw(w, time)
        ui.fx:draw()
    end
    local idle = kit().render("smoke_hero_idle.png", shots, function() draw(2.0) end)
    local a, b = segment_of(17, 18), segment_of(12, 13)
    local ax1, ay1, ax2, ay2 = ConduitView.segment_points(a)
    check(kit().any_pixel(kit().grid_only(w, ui, 2.0), (ax1 + ax2) / 2, (ay1 + ay2) / 2, 2, gold), "a live conduit glows gold at night")
    local bx1, by1, bx2 = ConduitView.segment_points(b)
    check(kit().brightness(idle, bx1, by1 - 8, bx2 - bx1, 16) > 0.9, "a link conduit shines between synergy cells")
    local px, py = math.floor((ax1 + ax2) / 2), math.floor((ay1 + ay2) / 2)
    local _, calm_g = kit().grid_only(w, ui, 2.0):getPixel(px, py)
    w.combat:set_overclock(true)
    local hot_r, hot_g = kit().grid_only(w, ui, 2.0):getPixel(px, py)
    check(hot_r > 0.7 and hot_g < calm_g - 0.05, string.format("overclock turns the conduits red-orange (g %.2f -> %.2f)", calm_g, hot_g))
    w.combat:set_overclock(false)
    -- 동조 투사
    local sword = w.inventory:get("grid", 12)
    local fired = { item = sword, x = 100, y = 300, tx = 900, ty = 460, color = { 1, 0.5, 0.2 }, combat = w.combat }
    EventBus.emit("combat:fired", fired)
    check(hero.pose == "attack" and hero.action == "cast" and #hero.waves == 1 and hero.flash == 1, "a relic shot makes the hero cast")
    EventBus.emit("combat:fired", fired)
    check(#hero.waves == 1, "casts wait for the cooldown")
    hero:update(ANIM.cast.cooldown_max + 0.01)
    check(hero.pose == "idle", "the cast pose ends")
    EventBus.emit("combat:fired", fired)
    check(#hero.waves == 2, "the next cast fires after 0.25~0.35 s")
    -- 근접 내려찍기
    hero:update(1)
    local near = Monster("goblin", wall_x + 96, 520, 1, 0, 1, LAYOUT.night.field_scale)
    local far = Monster("goblin", wall_x + 420, 470, 1, 0, 1, LAYOUT.night.field_scale)
    local function strike(monster, counter)          -- 실제 타격 판정은 systems/HeroCombat (SmokeHeroEquip 가 검사한다)
        EventBus.emit("combat:hero_strike", { monster = monster, damage = 5, crit = false, counter = counter == true, item = sword,
            x = monster.x, y = monster.y })
    end
    EventBus.emit("combat:damage_dealt", { monster = far, amount = 5, item = sword, x = far.x, y = far.y, armored = false,
        crit = false, damage_type = "fire" })
    check(#hero.smashes == 0, "showcase hits alone draw no hammer smash")
    strike(near)
    check(#hero.smashes == 1 and hero.action == "melee" and hero.pose == "attack", "a hero strike draws a hammer smash")
    w.combat.monsters = { near }
    EventBus.emit("combat:fired", fired)
    hero:update(0.1)
    ui.motion:update(0.1, w.combat)                  -- 피격 흰 점멸이 지나간 뒤의 장면
    ui.fx:update(0.1)
    kit().render("smoke_hero_attack.png", shots, function() draw(2.3) end)
    -- 방어
    hero:update(1)
    EventBus.emit("combat:wall_hit", { monster = near, damage = 5, x = wall_x, y = near.y })
    check(hero.pose == "block" and #hero.shields == 1, "a wall hit raises the block pose and a rune shield")
    local waves = #hero.waves
    EventBus.emit("combat:fired", fired)
    check(#hero.waves == waves and hero.flash == 1, "no cast while blocking (only the flash)")
    local smashes = #hero.smashes
    strike(near, true)
    check(hero.pose == "block" and #hero.smashes == smashes + 1, "a counter strike keeps the block pose and adds a smash arc")
    w.combat.monsters = {}
    hero:update(0.05)
    local block = kit().render("smoke_hero_block.png", shots, function() draw(2.6) end)
    local r = ANIM.block.shield_radius * 0.82
    check(kit().any_pixel(block, x + height * 0.2 - r * 0.45 + r, ground_y - height * 0.55, 8, gold), "the rune shield glows gold in front of the hero")
    hero:update(ANIM.block.pose_time + 0.1)
    check(hero.pose == "idle", "the block pose ends")
    EventBus.emit("phase:night_started", { workshop = w, day = w.day })
    check(#hero.waves == 0 and #hero.shields == 0 and hero.flash == 0, "nightfall resets the hero")
end

local function check_art(shots, missing_assets)
    local SpriteBank, LaneHeroArt, ART = require("ui.SpriteBank"), require("ui.LaneHeroArt"), require("data.art")
    if not missing_assets then
        local heights = {}
        for _, pose in ipairs(ART.hero.order) do
            local image = SpriteBank.image(ART.hero.poses[pose].sprite)
            check(image ~= nil, "protagonist sprite for " .. pose)
            heights[#heights + 1] = image:getHeight()
        end
        check(math.abs(heights[1] - heights[3]) / heights[1] < 0.06 and math.abs(heights[1] - heights[2]) / heights[1] < 0.06,
            "the three poses share one scale")
    end
    -- 포즈 견본: 위 = 원화(있으면) · 아래 = 코드 실루엣, 왼쪽부터 대기 · 공격(파동 · 내려찍기) · 방어(룬 방패). 모두 오른쪽(포탈)을 본다
    local function row(ground_y, height)
        for i, pose in ipairs(ART.hero.order) do
            local cx = 40 + i * 300
            local gx, gy = LaneHeroArt.figure(pose, cx, ground_y, height, 1.0, { aura = { 1.0, 0.48, 0.2 }, flash = pose == "attack" and 0.6 or 0 })
            if pose == "attack" then
                LaneHeroArt.wave(gx, gy, 0.45, { 1.0, 0.82, 0.36 }, 130)
                LaneHeroArt.smash(cx + 210, ground_y - 60, 44, 0.4, { 1.0, 0.48, 0.2 })
            elseif pose == "block" then
                LaneHeroArt.shield(cx + height * 0.2, ground_y - height * 0.55, 0.15, height * 0.5, 1.0)
            end
        end
    end
    local blank = kit().render(nil, false, function() end)
    local art = kit().render(nil, false, function() row(330, 250) end)
    SpriteBank.set_enabled(false)                    -- 원화 없이: 코드 실루엣
    local plain = kit().render(nil, false, function() row(660, 250) end)
    for i, pose in ipairs(ART.hero.order) do
        local _, _, _, _, image = LaneHeroArt.box(pose, 300, 500, 200)
        local cx = 40 + i * 300
        check(image == nil and math.abs(kit().brightness(plain, cx - 70, 420, 140, 230) - kit().brightness(blank, cx - 70, 420, 140, 230)) > 0.02,
            "the " .. pose .. " silhouette draws without art")
        if not missing_assets then
            check(math.abs(kit().brightness(art, cx - 70, 90, 140, 230) - kit().brightness(blank, cx - 70, 90, 140, 230)) > 0.02,
                "the " .. pose .. " art draws")
        end
    end
    kit().render("smoke_hero_poses.png", shots, function()
        SpriteBank.set_enabled(true)
        row(330, 250)
        SpriteBank.set_enabled(false)
        row(660, 250)
    end)
    SpriteBank.set_enabled(true)
end

function SmokeLaneHero.run(log, shots, missing_assets)
    require("core.RNG").set_seed(3303)
    check_intro(shots, missing_assets)
    local K = require("tools.SmokeTraceBattle").kit
    local w = require("systems.Workshop")({ difficulty = "broker" })
    local ui = K.attach_ui(w)
    require("ui.Slots").set_mode_provider(function() return "day" end)
    local segment_of = check_conduits(w, ui, shots)
    check_core(w, ui)
    check_night(w, ui, shots, segment_of)
    require("ui.Slots").set_mode_provider(nil)
    ui.destroy()
    w:destroy()
    check_art(shots, missing_assets)
    log("lane hero ok (intro 7 scenes / 14 beats + circuit scene, 40 mana conduits: dark by day, ignite from the centre at night, "
        .. "sealed/idle/live/link, overclock red; centre core mark + tooltip; hero: attune color, cast on shots with cooldown, "
        .. "melee smash near the wall, block + rune shield, reset, silhouettes without art)")
end

return SmokeLaneHero
