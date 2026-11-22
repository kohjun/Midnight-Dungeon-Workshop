-- tools/SmokeSim.lua
-- 헤드리스 시뮬레이션: 진열장을 5x5 로 넓히고 24종 유물을 모두 깔아 과부하 밤 전투를 끝까지 돌린다.
-- 원본 10종으로 인접 시너지 수치를 검증한 뒤 확장 14종을 추가해 모든 효과 핸들러
-- (증폭·저주·화상·폭발·연쇄·낙뢰·둔화·골드·방벽·수익·대가·흡혈·판매가)와 과열, 일일 수익, 용광로를 실행한다.
-- --shots 이면 유물 도감(smoke_catalog.png, 도형 폴백은 smoke_catalog_shapes.png)과 시뮬레이션 전투 장면(smoke_sim_night.png)을 저장한다.

local SmokeSim = {}

local SEED = 4242
local DT = 1 / 60
local NIGHT_STEPS = 60 * 32
local SCENE_SHOT_AFTER = 60 * 3   -- 이 스텝 이후 몬스터와 탄이 함께 보이는 첫 순간을 촬영
-- 시너지가 보이도록 배치: 수정(8) ↔ 검(7)·오브(9), 소리굽쇠(13) ↔ 석궁(12)·단검(14), 석판(17) ↔ 석궁(12)·성배(18)
local PLACEMENT = {
    greed_pouch = 3, flame_sword = 7, mana_crystal = 8, lightning_orb = 9, frost_crossbow = 12,
    tuning_fork = 13, cursed_dagger = 14, rune_tablet = 17, golden_chalice = 18, guardian_crest = 19,
}

local function render_to_file(width, height, filename, draw)
    local canvas = love.graphics.newCanvas(width, height)
    love.graphics.push("all")
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.origin()
    draw()
    love.graphics.setCanvas()
    love.graphics.pop()
    canvas:newImageData():encode("png", filename)
end

-- filename: 저장할 파일 이름 (스프라이트 도감 / 도형 폴백 도감)
local function render_catalog(ids, filename)
    local Item = require("entities.Item")
    local I18n = require("systems.I18n")
    local ItemRenderer = require("ui.ItemRenderer")
    local Draw = require("ui.Draw")
    local ITEMS = require("data.items")
    local UI = require("data.ui")
    local per_row = 12
    render_to_file(1280, 840, filename, function()
        Draw.clear(UI.color.background)
        for i, id in ipairs(ids) do
            local row, col = math.floor((i - 1) / per_row), (i - 1) % per_row
            local top = row * 280
            local flaw = (i % 3 == 0) and "crack" or ((i % 4 == 0) and "curse" or nil)
            local item = Item(id, {
                grade = ITEMS.grade_order[i % 3 + 1], flaw = flaw, flaw_mark = { x = 0.1, y = -0.1 },
                contamination = (i % 2 == 0) and 70 or 0,
                grime = { { x = -0.2, y = -0.1, r = 0.15 }, { x = 0.15, y = 0.2, r = 0.12 } },
            })
            item.revealed.grade, item.revealed.flaw, item.level = true, true, i % 3
            local x = 56 + col * 106
            ItemRenderer.draw(item, x, top + 60, 84, { time = i })
            Draw.text(I18n.item_name(item), x - 52, top + 108, 104, "center", UI.font_size.tiny, UI.color.text)
            Draw.set_color(UI.color.uv_tint)
            love.graphics.rectangle("fill", x - 50, top + 140, 100, 100, 8, 8)
            ItemRenderer.draw_xray(item, x, top + 190, 84, i)
        end
    end)
end

-- 밤 화면(진열장 · 와이드 레인 · 무기 공격 연출)을 그린다. shots 면 파일로, 아니면 오프스크린에만 (그리기 경로 검사)
local function render_scene(workshop, ui, shots)
    local NightLayoutView = require("ui.NightLayoutView")
    local Slots = require("ui.Slots")
    local Draw = require("ui.Draw")
    local UI = require("data.ui")
    local function draw()
        Draw.clear(UI.color.background)
        NightLayoutView.draw(workshop, ui.input, 9, { attacks = ui.attacks, motion = ui.motion })
        ui.hud:draw(workshop, 9)
        ui.input:draw()
        ui.fx:draw()
        ui.hud:draw_overlay()
    end
    Slots.set_mode_provider(function() return "night" end)
    if shots then
        render_to_file(1280, 720, "smoke_sim_night.png", draw)
    else
        local canvas = love.graphics.newCanvas(1280, 720)
        love.graphics.push("all")
        love.graphics.setCanvas({ canvas, stencil = true })
        draw()
        love.graphics.setCanvas()
        love.graphics.pop()
    end
    Slots.set_mode_provider(nil)
end

-- 실제 런과 같은 연출 계층(Effects·Hud·Feedback·입력)을 붙여 Feedback 핸들러까지 실행한다
local function attach_ui(workshop)
    local Effects = require("ui.Effects")
    local Hud = require("ui.Hud")
    local Feedback = require("ui.Feedback")
    local WorkshopInput = require("ui.WorkshopInput")
    local ui = { fx = Effects(), hud = Hud(), input = WorkshopInput(workshop) }
    ui.input.pointer.x, ui.input.pointer.y = 0, 0
    ui.feedback = Feedback(ui.fx, ui.hud, workshop)
    ui.attacks = require("ui.AttackEffects")(ui.fx)
    ui.motion = require("ui.EntityMotion")(ui.fx, workshop)
    return ui
end

local function step_world(workshop, ui)
    workshop:update(DT)
    ui.attacks:update(DT, workshop.combat)
    ui.motion:update(DT, workshop.combat)
    require("ui.SpriteBank").update(DT)
    ui.fx:update(DT)
    ui.hud:update(DT)
end

-- 등급을 부풀린 균열 유물: 스캔 → 가격 인하 확인 → 매입 → 세척 → 판매
local function check_appraisal(workshop)
    local Item = require("entities.Item")
    local LAYOUT = require("data.layout")
    local appraisal = workshop.appraisal
    local item = Item("frost_crossbow", {
        grade = "rare", claimed_grade = "legendary", flaw = "crack", flaw_mark = { x = 0.1, y = 0.1 },
        contamination = 40, grime = { { x = 0, y = 0, r = 0.1 } },
    })
    workshop.inventory:place(item, "bench", 1)
    local full_price = item:asking_price()
    local slot = LAYOUT.day.bench_slot
    for row = 0, 8 do
        for col = 0, 8 do
            appraisal:scan(slot.x + 10 + col * 22.5, slot.y + 10 + row * 22.5, DT, true)   -- held: 버튼 홀드
        end
    end
    assert(item.revealed.grade and item.revealed.flaw and item.revealed.complete, "SmokeSim: full sweep should reveal all")
    assert(item:asking_price() < full_price, "SmokeSim: exposed forgery and flaw should lower the price")
    assert(appraisal:buy(), "SmokeSim: purchase should succeed")
    local bought_area, bought_index = workshop.inventory:locate(item)       -- 매입 = 자동 배치 (무기 → 진열장 첫 빈칸)
    assert(bought_area == "grid", "SmokeSim: a bought weapon should be auto-placed on the showcase")
    assert(workshop:move_item(bought_area, bought_index, "bench", 1), "SmokeSim: showcase -> bench move should succeed")
    for _ = 1, 40 do
        appraisal:scrub(slot.x + slot.w / 2, slot.y + slot.h / 2, 30)
    end
    assert(item.cleaned, "SmokeSim: scrubbing should clean the item")
    assert(appraisal:sell(), "SmokeSim: instant sale should succeed")
end

-- original = true 면 PLACEMENT 의 원본 10종만, false 면 나머지(확장 14종)를 빈 칸에
local function place_items(workshop, ids, original)
    local Item = require("entities.Item")
    for _, id in ipairs(ids) do
        if (PLACEMENT[id] ~= nil) == original then
            local item = Item(id, { grade = "rare", contamination = 0 })
            item.owned = true
            workshop.inventory:place(item, "grid", PLACEMENT[id] or workshop.inventory:find_empty("grid"))
        end
    end
end

-- 진열장 5x5 개방 (공방 개조 API 경로로)
local function open_full_grid(workshop)
    workshop.gold = workshop.gold + 5000
    while workshop.upgrades:next_level("grid") ~= nil do
        assert(workshop.upgrades:buy("grid"), "SmokeSim: grid expansion purchase failed")
    end
    assert(workshop:is_cell_open(1) and workshop:is_cell_open(25), "SmokeSim: grid should be fully open")
end

local function find_on_grid(workshop, proto_id)
    for index = 1, workshop.inventory:size("grid") do
        local item = workshop.inventory:get("grid", index)
        if item ~= nil and item.proto_id == proto_id then
            return item
        end
    end
    return nil
end

local function check_synergy(workshop)
    local stats = workshop:grid_stats()
    assert(#stats.links >= 6, "SmokeSim: expected synergy links, got " .. #stats.links)
    local sword = stats.stats[find_on_grid(workshop, "flame_sword")]
    assert(math.abs(sword.attack_mult - 1.5) < 1e-9, "SmokeSim: crystal should boost adjacent sword x1.5")
    local orb = stats.stats[find_on_grid(workshop, "lightning_orb")]
    assert(math.abs(orb.attack_mult - 1.125) < 1e-9, "SmokeSim: orb should get crystal x1.5 and dagger curse x0.75")
end

local function check_forge(workshop, ui)
    local Item = require("entities.Item")
    local item = Item("flame_sword", { grade = "common" })
    item.owned = true
    workshop.inventory:place(item, "furnace", 1)
    assert(workshop.forge:start(), "SmokeSim: forge should start")
    for _ = 1, 90 do
        step_world(workshop, ui)
    end
    assert(workshop.forge.forging == nil, "SmokeSim: forge should resolve")
end

function SmokeSim.run(shots, log)
    local RNG = require("core.RNG")
    local Workshop = require("systems.Workshop")
    local ItemFactory = require("systems.ItemFactory")
    RNG.set_seed(SEED)
    local ids = ItemFactory.base_ids()
    if shots then
        local SpriteBank = require("ui.SpriteBank")
        render_catalog(ItemFactory.prototype_ids(), "smoke_catalog.png")
        SpriteBank.set_enabled(false)       -- 스프라이트가 없을 때의 도형 폴백 도감
        render_catalog(ItemFactory.prototype_ids(), "smoke_catalog_shapes.png")
        SpriteBank.set_enabled(true)
    end

    local EventBus = require("core.EventBus")
    local workshop = Workshop()
    local ui = attach_ui(workshop)
    open_full_grid(workshop)
    place_items(workshop, ids, true)
    check_synergy(workshop)
    check_appraisal(workshop)
    check_forge(workshop, ui)
    place_items(workshop, ids, false)
    assert(workshop.inventory:count("grid") >= 24, "SmokeSim: all 24 artifacts should be on the grid")
    local sample = workshop.inventory:get("grid", 7)
    assert(workshop:sale_price(sample) > sample:sale_value(), "SmokeSim: merchant scale should raise sale prices")

    local counters = { explosion = 0, thunder = 0, leech = 0 }
    local probe = {}
    EventBus.subscribe("combat:explosion", function() counters.explosion = counters.explosion + 1 end, { owner = probe })
    EventBus.subscribe("combat:thunder", function() counters.thunder = counters.thunder + 1 end, { owner = probe })
    EventBus.subscribe("workshop:healed", function() counters.leech = counters.leech + 1 end, { owner = probe })
    local hit_items = {}
    EventBus.subscribe("combat:hit", function(p)
        hit_items[p.item.proto_id] = true
    end, { owner = probe, priority = -100 })
    local max_projectiles = 0
    EventBus.subscribe("combat:fired", function()
        max_projectiles = math.max(max_projectiles, #workshop.combat.projectiles)
    end, { owner = probe })

    -- 1일차 웨이브는 레이저가 즉사시켜 탄환이 닿지 않으므로, 체력·밀도가 높은 9일차 밤으로 시험한다
    workshop.day = 9
    local hp_before, gold_before = workshop.hp, workshop.gold
    assert(workshop:start_night(), "SmokeSim: night should start")
    local ITEMS, CURSE = require("data.items").prototypes, require("data.balance").curse
    local dagger, pact = ITEMS.cursed_dagger.effects[1].hp_cost, ITEMS.blood_pact_scroll.effects[1]
    local toll = math.min(CURSE.night_cap, dagger + pact.hp_cost)
    local paid = math.min(pact.hp_cost, CURSE.night_cap - math.min(CURSE.night_cap, dagger))
    assert(workshop.hp == hp_before - toll, "SmokeSim: dagger + blood pact (night cap " .. CURSE.night_cap .. ") should cost "
        .. toll .. " HP, got " .. (hp_before - workshop.hp))
    assert(workshop.gold == gold_before + math.floor(pact.gold * paid / pact.hp_cost + 0.5), "SmokeSim: blood pact pays for the HP it took")
    workshop:set_overclock(true)
    assert(workshop.combat.overclock, "SmokeSim: overclock should turn on at night")
    local captured = false
    for step = 1, NIGHT_STEPS do
        step_world(workshop, ui)
        local combat = workshop.combat
        if not captured and step >= SCENE_SHOT_AFTER and #combat.monsters > 0
            and #combat.projectiles + #combat.beams > 0 then
            render_scene(workshop, ui, shots)
            captured = true
        end
        if workshop.phase == "day" or workshop.result ~= nil then
            break
        end
    end
    EventBus.unsubscribe_owner(probe)
    assert(workshop.result == nil and workshop.day == 10, "SmokeSim: should survive night 9 into day 10")
    assert(workshop.stats.kills > 0, "SmokeSim: weapons should kill monsters")
    local ITEMS = require("data.items")
    local bullet_hits = false
    for id in pairs(hit_items) do
        bullet_hits = bullet_hits or ITEMS.prototypes[id].projectile == "bullet"
    end
    assert(bullet_hits and max_projectiles > 0, "SmokeSim: homing bullets should fly and land hits")
    assert(counters.thunder > 0, "SmokeSim: storm rod should call down thunder")
    assert(counters.explosion > 0, "SmokeSim: burn detonation / magma blast should explode")
    log("simulation ok (24 artifacts, kills %d, thunder %d, explosions %d, leech %d, gold %d, hp %d, particles %d)",
        workshop.stats.kills, counters.thunder, counters.explosion, counters.leech, workshop.gold, workshop.hp,
        ui.fx:particle_count())
    assert(captured, "SmokeSim: the night scene with shots in flight should have been drawn")
    ui.attacks:destroy()
    ui.motion:destroy()
    ui.feedback:destroy()
    ui.input:destroy()
    workshop:destroy()
end

return SmokeSim
