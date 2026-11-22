-- tools/SmokeHeroEquipNight.lua
-- tools/SmokeHeroEquip.lua 의 뒷부분 (300줄 제한으로 나눔) — 밤 전투 · 저장 · 화면:
--   ④ 일반 밤 레인 실전: 주인공이 방벽 앞 사거리의 가장 앞선 마물만 친다(먼 마물은 아님) · 피해 = 주인공 공격력(치명타 배율) ·
--      타격 간격 · 맨손 기본 공격 · 방어구의 방벽 피격 경감(guard) · 반격 · 장착 장비 마모(무기 = 타격, 방어구 = 방어, +10 면역) ·
--      실제 밤 한 번이 오류 없이 돈다
--   ⑤ 저장: v5 왕복(주인공 4부위 · 거치대 3칸 · 강화 · 내구도) · v4 / v3 저장(보관함 4칸)의 4번 칸 유물이 진열장으로 안전
--      마이그레이션 · 자리가 없으면 작업대 → 판매가 환급
--   ⑥ 화면: 낮 장비창 + 거치대(빈 부위 실루엣 · 스탯 요약) · 주인공 툴팁(낮 장비창 / 밤 레인 스프라이트) · 놓을 칸 후보 ·
--      우클릭 입력 · 방어구 12종 견본 (--shots: smoke_hero_equip_day.png · smoke_hero_tooltip.png · smoke_hero_night.png ·
--      smoke_armor_contact.png)

local SmokeHeroEquipNight = {}

local DT = 1 / 60

local function check_combat(check, ready, capture)
    local Workshop, Monster, HeroStats = require("systems.Workshop"), require("entities.Monster"), require("systems.HeroStats")
    local HERO, LAYOUT = require("data.hero"), require("data.layout")
    local wall_x = LAYOUT.night.wall.x + LAYOUT.night.wall.w
    local scale = LAYOUT.night.field_scale
    local w = Workshop({ difficulty = "broker" })            -- 진열장은 비어 있다: 피해를 주는 것은 주인공뿐
    w.max_hp, w.hp = 5000, 5000
    local sword = ready("flame_sword", "rare", 3)
    w.inventory:place(sword, "hero", 1)
    check(w:start_night(), "the night should start")
    local combat, hero = w.combat, w.combat.hero
    local near = Monster("ogre", wall_x + 70, 470, 50, 0, 1, scale)
    local far = Monster("ogre", wall_x + 520, 470, 50, 0, 1, scale)
    combat.monsters = { far, near }
    local strikes, stop = capture("combat:hero_strike")
    local near_hp, far_hp = near.hp, far.hp
    for _ = 1, 600 do                                         -- 10초
        hero:update(DT)
    end
    local stats = HeroStats.compute(w)
    local dealt, expected = near_hp - near.hp, 0
    for _, strike in ipairs(strikes) do
        expected = expected + strike.damage
        check(strike.monster == near and strike.item == sword and not strike.counter, "the hero strikes the front monster at the wall")
        check(math.abs(strike.damage - stats.attack) < 1e-6 or math.abs(strike.damage - stats.attack * stats.crit_mult) < 1e-6,
            "strike damage = hero attack (x crit)")
    end
    local rate = 10 / stats.strike_interval
    check(#strikes >= rate - 1.5 and #strikes <= rate + 1.5, string.format("one strike per %.2f s (%d in 10 s)", stats.strike_interval, #strikes))
    check(dealt > 0 and math.abs(dealt - expected) < 1e-4 and far.hp == far_hp, "the equipped weapon really damages monsters in melee range only")
    check(sword.durability < 100 and hero.strikes == #strikes, "the equipped weapon wears with every strike")
    w.inventory:remove(sword)
    local count = #strikes
    for _ = 1, 150 do
        hero:update(DT)
    end
    check(#strikes > count and (strikes[#strikes].damage == HERO.base.attack or strikes[#strikes].damage == HERO.base.attack * HERO.base.crit_mult)
        and strikes[#strikes].item == nil, "bare-handed strikes use the base attack")

    -- 방어 · 반격 · 방어구 마모
    local raider = Monster("goblin", wall_x + 20, 470, 1, 0, 1, scale)
    raider.damage = 100
    local hp = w.hp
    combat:_hit_wall(raider)
    check(hp - w.hp == 100, "without armor the wall takes the full hit")
    local plate, immortal = ready("rift_carapace", "legendary", 5), ready("rift_striders", "rare", 10)
    w.inventory:place(plate, "hero", 3)
    w.inventory:place(immortal, "hero", 4)
    w.inventory:place(sword, "hero", 1)
    stats = HeroStats.compute(w)
    check(stats.guard > 0.05 and stats.guard <= HERO.guard.max, "armor grants a guard ratio")
    local guards, stop_guards = capture("combat:hero_guard")
    raider = Monster("goblin", wall_x + 20, 470, 1, 0, 1, scale)
    raider.damage = 100
    hp, count, near_hp = w.hp, #strikes, near.hp
    local plate_before = plate.durability
    combat:_hit_wall(raider)
    check(hp - w.hp == math.max(1, math.floor(100 * (1 - stats.guard) + 0.5)) and #guards == 1
        and math.abs(guards[1].blocked - 100 * stats.guard) < 1e-6 and hero.blocked > 0, "the hero blocks part of a wall hit")
    check(#strikes == count + 1 and strikes[#strikes].counter and strikes[#strikes].monster == near and near.hp < near_hp,
        "and counters the front monster")
    check(plate.durability < plate_before and immortal.durability == 100, "blocking wears armor (+10 is immune)")
    plate_before = plate.durability
    for _ = 1, 300 do
        hero:update(DT)
    end
    check(plate.durability < plate_before and immortal.durability == 100, "equipped gear wears slowly through the night")
    local worn, stop_worn = capture("hero:gear_worn_out")
    plate.durability = 0.001
    hero:update(DT)
    check(#worn == 1 and worn[1].slot == "chest" and plate:is_worn_out() and HeroStats.compute(w).guard == 0, "0% armor stops guarding")
    stop()
    stop_guards()
    stop_worn()
    w:destroy()

    local real = Workshop({ difficulty = "broker", starter = true })      -- 실제 밤: 진열장 무기 + 주인공이 함께 싸운다
    real.inventory:place(ready("frost_crossbow", "rare", 2), "hero", 1)
    real.inventory:place(ready("guild_plate", "rare", 0), "hero", 3)
    check(real:start_night(), "a real night should start")
    for _ = 1, 60 * 20 do
        real:update(DT)
    end
    check(real.phase == "night" or real.result == nil, "a real night runs with the hero in it")
    real:destroy()
end

local function check_save(check, ready)
    local RunSave, Workshop, Grid = require("systems.RunSave"), require("systems.Workshop"), require("systems.Grid")
    local w = Workshop({ difficulty = "broker" })
    local sword = ready("flame_sword", "rare", 2)
    sword.durability = 71.5
    w.inventory:place(sword, "hero", 1)
    w.inventory:place(ready("guild_sallet", "common", 1), "hero", 2)
    w.inventory:place(ready("rift_striders", "legendary", 0), "hero", 4)
    w.inventory:place(ready("golden_chalice"), "storage", 2)
    w.inventory:place(ready("leather_jerkin"), "storage", 3)
    w.inventory:place(ready("frost_crossbow"), "grid", 13)
    local data = RunSave.deserialize(RunSave.serialize(RunSave.snapshot(w)))
    check(RunSave.VERSION == 5 and data ~= nil and data.version == 5, "saves are version 5")
    local back = RunSave.resume(data, Workshop)
    local gear = back:hero_gear()
    check(gear.weapon ~= nil and gear.weapon.proto_id == "flame_sword" and gear.weapon.level == 2 and gear.weapon.durability == 71.5
        and gear.weapon.equip_slot == "weapon", "the hero weapon resumes (+2, 71.5%)")
    check(gear.helmet.proto_id == "guild_sallet" and gear.helmet.level == 1 and gear.helmet:is_armor() and gear.chest == nil
        and gear.boots.proto_id == "rift_striders" and gear.boots:gear_stats().move_speed > 0, "helmet and boots resume as armor")
    check(back.inventory:get("storage", 1) == nil and back.inventory:get("storage", 2).proto_id == "golden_chalice"
        and back.inventory:get("storage", 3).proto_id == "leather_jerkin" and back.inventory:get("grid", 13).proto_id == "frost_crossbow",
        "the spare rack and the showcase resume slot for slot")
    back:destroy()

    for _, version in ipairs({ 4, 3 }) do                    -- 예전 저장: 보관함 4칸 · 장비창 없음
        local old = RunSave.snapshot(w)
        old.version = version
        old.slots.storage[4] = old.slots.hero[1]             -- 4번 칸에 있던 화염 검
        old.slots.hero = nil
        local migrated = RunSave.deserialize(RunSave.serialize(old))
        check(migrated ~= nil and migrated.version == 5, "a version " .. version .. " save still loads")
        local again = RunSave.resume(migrated, Workshop)
        local found = nil
        for index = 1, Grid.SIZE do
            local item = again.inventory:get("grid", index)
            if item ~= nil and item.proto_id == "flame_sword" then
                found = index
            end
        end
        check(found ~= nil and again:is_cell_open(found) and again.inventory:get("grid", found).level == 2
            and again.inventory:count("storage") == 2 and again.inventory:count("hero") == 0,
            "the relic from the old 4th storage slot moves onto the showcase (v" .. version .. ")")
        again:destroy()
    end

    for index = 1, Grid.SIZE do                              -- 자리가 없을 때: 작업대 → 판매가 환급
        if w:is_cell_open(index) and w.inventory:get("grid", index) == nil then
            w.inventory:place(ready("cursed_dagger"), "grid", index)
        end
    end
    w.inventory:place(ready("mana_crystal"), "storage", 1)
    local first, second = ready("storm_rod"), ready("hex_scythe")
    check(RunSave.rehome(w, first) == "bench" and w.inventory:get("bench", 1) == first, "no cell or rack slot: the relic waits on the bench")
    local gold = w.gold
    check(RunSave.rehome(w, second) == "refunded" and w.gold == gold + second:sale_value(), "no room at all: refunded at its sale value")
    w:destroy()
end

local function check_screens(check, ready, shots, missing_assets)
    local K = require("tools.SmokeTraceBattle").kit
    local Workshop, Slots, LAYOUT = require("systems.Workshop"), require("ui.Slots"), require("data.layout")
    local HoverTooltip, Tooltip, ItemRenderer = require("ui.HoverTooltip"), require("ui.Tooltip"), require("ui.ItemRenderer")
    local SpriteCatalog, SpriteBank, ARMORS = require("ui.SpriteCatalog"), require("ui.SpriteBank"), require("data.armors")
    local w = Workshop({ difficulty = "broker", starter = true })
    local ui = K.attach_ui(w)
    Slots.set_mode_provider(function() return "day" end)
    local sword, helm = ready("flame_sword", "rare", 3), ready("guild_sallet", "rare", 1)
    sword.durability = 82
    w.inventory:place(sword, "hero", 1)
    w.inventory:place(ready("rift_striders", "legendary", 5), "hero", 4)
    w.inventory:place(helm, "storage", 1)
    w.inventory:place(ready("rune_cuirass", "rare", 0), "storage", 2)
    local function day(extra)
        return function()
            require("ui.DayLayoutView").draw(w, ui.input, 1.0)
            ui.hud:draw(w, 1.0)
            if extra ~= nil then extra() end
        end
    end
    local blank = K.render(nil, false, function() end)
    local shot = K.render("smoke_hero_equip_day.png", shots, day())
    local stats, cx, cy = LAYOUT.day.hero_stats, Slots.center("hero", 3)
    check(K.brightness(shot, stats.x, stats.y, stats.w, 18) > K.brightness(blank, stats.x, stats.y, stats.w, 18) + 0.05,
        "the stat summary line is drawn under the hero slots")
    local x4 = Slots.rect("hero", 4)
    local x1, y1, size = Slots.rect("storage", 1)
    check(x4 + size < x1 and x1 + (size + LAYOUT.day.storage_slots.gap) * 3 <= LAYOUT.day.storage_section.x + LAYOUT.day.storage_section.w
        and y1 + size < LAYOUT.day.hero_stats.y, "four hero slots and three rack slots fit side by side above the stat line")
    check(Slots.at(cx, cy) == "hero" and select(2, Slots.at(cx, cy)) == 3 and Slots.at(x1 + 5, y1 + 5) == "storage", "slot hit testing")
    ui.input.drag = { item = helm, area = "storage", index = 1, offset_x = 0, offset_y = 0 }
    check(ui.input:is_drop_candidate("hero", 2) and not ui.input:is_drop_candidate("hero", 1) and not ui.input:is_drop_candidate("grid", 13)
        and ui.input:is_drop_candidate("storage", 3), "drop candidates follow the 3-way rule")
    ui.input.drag = nil
    ui.input:mousepressed(x1 + 20, y1 + 20, 2)                -- 우클릭: 거치대의 투구 장착
    check(w:hero_gear().helmet == helm and w.inventory:get("storage", 1) == nil, "right-click on the rack equips the helmet")
    local hover, title = HoverTooltip(w), LAYOUT.day.hero_title
    local pointer = { x = title.x + 30, y = title.y + 10 }
    for _ = 1, 3 do
        hover:update(0.3, pointer, false)
    end
    local head, body = hover:content()
    check(hover:visible_id() == "hero" and head ~= nil and #body >= 10, "hovering the hero panel shows the hero tooltip")
    K.no_holes(body, "hero hover")
    K.render("smoke_hero_tooltip.png", shots, day(function()
        hover:draw()
        Tooltip.draw(w.inventory:get("storage", 2), nil, 760, 300, w)
    end))

    Slots.set_mode_provider(function() return "night" end)
    w.max_hp, w.hp = 100000, 100000
    check(w:start_night(), "the night should start")
    ui.step(4)
    local hx, ground_y, height = require("ui.LaneHero").anchor()
    pointer = { x = hx, y = ground_y - height * 0.5 }
    local night_hover = HoverTooltip(w)
    for _ = 1, 3 do
        night_hover:update(0.3, pointer, false)
    end
    check(night_hover:visible_id() == "hero", "hovering the hero on the night lane shows the same tooltip")
    K.render("smoke_hero_night.png", shots, function()
        require("ui.NightLayoutView").draw(w, ui.input, 4.0, { attacks = ui.attacks, motion = ui.motion })
        ui.hud:draw(w, 4.0)
        ui.fx:draw()
        night_hover:draw()
    end)
    Slots.set_mode_provider(nil)
    ui.destroy()
    w:destroy()

    local function contact()                                  -- 방어구 12종 견본 (어두운 슬롯 색 배경)
        love.graphics.setColor(0.10, 0.09, 0.13, 1)
        love.graphics.rectangle("fill", 0, 0, 1280, 720)
        for i, id in ipairs(ARMORS.order) do
            ItemRenderer.draw(ready(id, "rare", (i - 1) % 4 == 3 and 5 or 0), 200 + ((i - 1) % 4) * 290, 130 + math.floor((i - 1) / 4) * 230,
                190, { time = 1.0 })
        end
    end
    if not missing_assets then
        for _, id in ipairs(ARMORS.order) do
            check(SpriteCatalog.item_image(ready(id)) ~= nil, "armor art for " .. id)
        end
    end
    local sheet = K.render("smoke_armor_contact.png", shots, contact)
    SpriteBank.set_enabled(false)
    local shapes = K.render(nil, false, contact)
    SpriteBank.set_enabled(true)
    for i = 1, 12 do
        local x, y = 200 + ((i - 1) % 4) * 290, 130 + math.floor((i - 1) / 4) * 230
        local empty = K.brightness(blank, x - 60, y - 60, 120, 120)
        check(math.abs(K.brightness(shapes, x - 60, y - 60, 120, 120) - empty) > 0.03
            and math.abs(K.brightness(sheet, x - 60, y - 60, 120, 120) - empty) > 0.03, "armor " .. i .. " draws (art or shape)")
    end
end

function SmokeHeroEquipNight.run(check, ready, capture, shots, missing_assets)
    check_combat(check, ready, capture)
    check_save(check, ready)
    check_screens(check, ready, shots, missing_assets)
end

return SmokeHeroEquipNight
