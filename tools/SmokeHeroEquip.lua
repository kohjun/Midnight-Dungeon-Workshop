-- tools/SmokeHeroEquip.lua
-- 3분류 아이템 체계 · 주인공 장비창 · 임시 거치대 스모크 검사 (SmokeTest 가 SmokeLaneHero 다음에 실행):
--   ① 3분류 배치 제한: 원형 44종(유물·무기 32 + 방어구 12)의 category 가 weapon · armor · relic 뿐 · 방어구 → 진열장 차단 ·
--      유물 → 주인공 차단 · 부위가 다른 칸 차단 · 맞바꿈도 양쪽 검사 · 무기 → 진열장 · 주인공 양쪽 허용 · 거절 이벤트와 안내 문구
--   ② 매입 자동 라우팅: 무기·유물 → 진열장 첫 빈칸 → 임시 거치대 → (둘 다 가득) 매입 불가(골드 그대로) /
--      방어구 → 빈 부위 자동 장착 → 임시 거치대 → 매입 불가 · [자동 배치](auto_place) · 우클릭 빠른 교체(quick_move) ·
--      '스승의 흔적'은 봉인 공명 슬롯을 맨 나중에 채운다
--   ③ 방어구 규칙: 등장 비중 18~22% · 방어구 손님은 무료 손님 수를 쓰지 않는 덤 방문 · UV 위조/저주 감정 · 용광로 강화(성공 = 내구도 100%) · 주인공 스탯 반영(강화 ↑ ·
--      저주 x1.3 · 0% 마모 = 효과 없음 · 상한) · 방어구/주인공 툴팁 문구(ko · en, 빈 자리표시자 없음)
--   ④ 밤 전투 · 저장 · 화면은 tools/SmokeHeroEquipNight.lua

local SmokeHeroEquip = {}

local function check(condition, message)
    if not condition then
        error("SmokeHeroEquip: " .. message, 2)
    end
end

local function ready(id, grade, level)
    return require("systems.ItemFactory").make_ready(id, grade or "rare", level or 0)
end

-- 손님 유물 하나를 작업대에 올린다 (감정은 건너뛴 채 살 수 있다)
local function customer(w, id, spec)
    local item = require("entities.Item")(id, spec or { grade = "rare", contamination = 0 })
    w.appraisal:present_customer(item, false)
    return item
end

local function capture(event)
    local EventBus, seen = require("core.EventBus"), {}
    local token = EventBus.subscribe(event, function(p) seen[#seen + 1] = p end, { priority = -300 })
    return seen, function() EventBus.unsubscribe(token) end
end

local function check_classes()
    local ITEMS, ARMORS, Item, HeroEquip = require("data.items"), require("data.armors"), require("entities.Item"), require("systems.HeroEquip")
    local counts, per_slot = { weapon = 0, armor = 0, relic = 0 }, {}
    for _, catalog in ipairs({ ITEMS.prototypes, ARMORS.prototypes }) do
        for id, proto in pairs(catalog) do
            check(counts[proto.category] ~= nil, id .. " has no 3-way category")
            counts[proto.category] = counts[proto.category] + 1
            if proto.category == "armor" then
                per_slot[proto.equip_slot] = (per_slot[proto.equip_slot] or 0) + 1
                check(proto.tier >= 1 and proto.tier <= #ARMORS.tiers and proto.stats ~= nil, id .. " armor tier / stats")
            end
        end
    end
    check(counts.armor == 12 and per_slot.helmet == 4 and per_slot.chest == 4 and per_slot.boots == 4 and counts.weapon + counts.relic == 32,
        "12 armor pieces (4 per slot) beside the 32 weapons and relics")
    local crystal = Item("mana_crystal", {})
    check(crystal.category == "relic" and crystal:role() == "amplifier" and crystal.equip_slot == nil, "amplifiers are relics")
    check(Item("flame_sword", {}).equip_slot == "weapon" and Item("guild_plate", {}).equip_slot == "chest", "equip slots")
    for _, id in ipairs({ "rune_cuirass", "leather_jerkin", "guild_plate", "rift_carapace" }) do
        check(ARMORS.skills[ARMORS.prototypes[id].skill] ~= nil, id .. " carries an E skill")
    end

    local w = require("systems.Workshop")({ difficulty = "broker" })
    local helm, sword, relic = ready("guild_sallet"), ready("flame_sword"), ready("golden_chalice")
    w.inventory:place(helm, "storage", 1)
    w.inventory:place(sword, "storage", 2)
    w.inventory:place(relic, "storage", 3)
    local rejected, stop = capture("equip:rejected")
    local messages, stop_messages = capture("ui:message")
    check(not w:move_item("storage", 1, "grid", 13) and rejected[#rejected].reason == "msg.armor_not_on_grid",
        "armor cannot go on the showcase")
    check(not messages[#messages].text:find("{", 1, true) and messages[#messages].kind == "warn", "the refusal explains itself")
    check(not w:move_item("storage", 3, "hero", 1) and rejected[#rejected].reason == "msg.relic_not_on_hero", "the hero cannot wear a relic")
    check(not w:move_item("storage", 1, "hero", 1) and rejected[#rejected].reason == "msg.wrong_hero_slot"
        and not w:move_item("storage", 1, "hero", 3), "armor only fits its own slot")
    check(not w:move_item("storage", 2, "hero", 2), "a weapon does not fit the helmet slot")
    check(w:move_item("storage", 2, "grid", 13) and w:move_item("grid", 13, "hero", 1) and w:hero_gear().weapon == sword,
        "a weapon fits both the showcase and the hero")
    check(w:move_item("storage", 1, "hero", HeroEquip.slot_index("helmet")) and w:hero_gear().helmet == helm, "the helmet equips")
    check(w:move_item("storage", 3, "grid", 13), "a relic goes on the showcase")
    local before = #rejected
    check(not w:move_item("grid", 13, "hero", 2) and not w:move_item("hero", 2, "grid", 13) and #rejected == before + 2,
        "swaps are checked both ways (relic <-> helmet)")
    check(w:move_item("hero", 1, "grid", 12) and w.inventory:get("grid", 12) == sword and w:hero_gear().weapon ~= sword,
        "hero weapon swaps with the showcase weapon")
    check(HeroEquip.fits(helm, "bench", 1) and HeroEquip.fits(relic, "furnace", 1) and HeroEquip.fits(helm, "storage", 1),
        "bench, furnace and rack take anything")
    stop()
    stop_messages()
    w:destroy()
    return counts
end

local function check_routing()
    local Workshop, Grid = require("systems.Workshop"), require("systems.Grid")
    local w = Workshop({ difficulty = "broker" })
    w.gold = 100000
    local routed, stop = capture("equip:routed")
    local sword = customer(w, "frost_crossbow")
    check(w.appraisal:buy() and w.inventory:locate(sword) == "grid" and w.appraisal:bench_item() == nil,
        "a bought weapon goes to the first free showcase cell")
    local _, first = w.inventory:locate(sword)
    check(w:is_cell_open(first) and first == 7 and routed[#routed].item == sword, "first open cell is (2,2)")
    local relic = customer(w, "golden_chalice")
    check(w.appraisal:buy() and select(2, w.inventory:locate(relic)) == 8, "a bought relic takes the next cell")
    for index = 1, Grid.SIZE do                              -- 진열장을 가득 채운다
        if w:is_cell_open(index) and w.inventory:get("grid", index) == nil then
            w.inventory:place(ready("cursed_dagger"), "grid", index)
        end
    end
    local spare = customer(w, "storm_rod")
    check(w.appraisal:buy() and w.inventory:locate(spare) == "storage", "with the showcase full a weapon goes to the spare rack")
    w.inventory:place(ready("mana_crystal"), "storage", 2)
    w.inventory:place(ready("mana_crystal"), "storage", 3)
    local blocked = customer(w, "flame_sword")
    local gold = w.gold
    check(not w.appraisal:buy() and w.gold == gold and not blocked.owned and w.appraisal:bench_item() == blocked,
        "showcase and rack both full: the purchase is refused and no gold is spent")
    -- 방어구: 빈 부위 자동 장착 (거치대가 가득해도) → 거치대 → 매입 불가
    w.appraisal:dismiss()
    local chest = customer(w, "guild_plate")
    check(w.appraisal:buy() and w:hero_gear().chest == chest and routed[#routed].area == "hero", "armor auto-equips an empty slot")
    local second = customer(w, "leather_jerkin")
    gold = w.gold
    check(not w.appraisal:buy() and w.gold == gold, "slot worn and rack full: the armor purchase is refused")
    w.inventory:remove(w.inventory:get("storage", 3))
    check(w.appraisal:buy() and w.inventory:locate(second) == "storage", "a second chest piece waits on the rack")

    -- 우클릭 빠른 교체 · [자동 배치]
    local _, rack = w.inventory:locate(second)
    check(w:quick_move("storage", rack) and w:hero_gear().chest == second and w.inventory:get("storage", rack) == chest,
        "right-click swaps racked armor with the worn piece")
    check(w:quick_move("grid", first) and w:hero_gear().weapon == sword, "right-click equips a showcase weapon")
    check(w.inventory:get("grid", first) == nil and w:quick_move("hero", 1) and w.inventory:get("grid", first) == sword,
        "with the rack full an unequipped weapon returns to a free showcase cell")
    w.inventory:remove(w.inventory:get("storage", 2))
    check(w:quick_move("grid", first) and w:hero_gear().weapon == sword, "equip it again")
    check(w:quick_move("hero", 1) and w.inventory:locate(sword) == "storage", "right-click unequips to the rack")
    check(w:quick_move("storage", select(2, w.inventory:locate(sword))) and w:hero_gear().weapon == sword,
        "right-click equips a racked weapon into the empty weapon slot")
    local lantern = ready("ember_brazier")
    w.inventory:place(lantern, "bench", 1)
    check(w:auto_place("bench", 1) and w.inventory:locate(lantern) == "grid" and select(2, w.inventory:locate(lantern)) == first,
        "[auto-place] sends a bench relic to the free cell")
    check(w:quick_move("grid", first) and w.inventory:locate(lantern) == "storage", "right-click moves a showcase relic to the rack")
    stop()
    w:destroy()

    local trace = Workshop({ difficulty = "master_trace" })      -- 봉인 공명 슬롯 (2,2)(2,4)(4,2)(4,4) 은 맨 나중
    local cell = trace:free_grid_cell()
    check(trace.master_trace ~= nil and trace.master_trace.slot_at(cell) == nil and cell == 8, "the campaign keeps seal sockets for last")
    for index = 1, Grid.SIZE do
        if trace:is_cell_open(index) and trace.master_trace.slot_at(index) == nil then
            trace.inventory:place(ready("cursed_dagger"), "grid", index)
        end
    end
    check(trace.master_trace.slot_at(trace:free_grid_cell()) ~= nil, "seal sockets fill once the other cells are taken")
    trace:destroy()
end

local function check_armor_rules()
    local Workshop, ItemFactory, RNG = require("systems.Workshop"), require("systems.ItemFactory"), require("core.RNG")
    local HeroStats, ARMORS, HERO, LAYOUT = require("systems.HeroStats"), require("data.armors"), require("data.hero"), require("data.layout")
    local rng, armor, total = RNG.stream("customers"), 0, 6000
    for _ = 1, total do
        armor = armor + (ItemFactory.customer_item(rng, 12, nil, nil, nil):is_armor() and 1 or 0)
    end
    check(armor / total >= 0.18 and armor / total <= 0.22, string.format("armor share of the item pool %.3f (18~22%%)", armor / total))
    for _ = 1, 200 do
        check(not ItemFactory.ready_item(rng, "rare", 0, nil, false):is_armor(), "allow_armor = false never rolls armor")
    end

    -- 방어구 손님은 덤 방문: 하루 무료 손님 수를 쓰지 않는다 (무기·유물 손님은 1명씩 쓴다)
    local visits = Workshop({ difficulty = "broker" })
    visits.customers_left = 400
    local bonus, paid = 0, 0
    for _ = 1, 300 do
        local left = visits.customers_left
        check(visits.appraisal:new_customer(), "a guest should arrive")
        local guest = visits.appraisal:bench_item()
        check(visits.customers_left == left - (guest:is_armor() and 0 or 1), "armor guests are bonus visits")
        bonus, paid = bonus + (guest:is_armor() and 1 or 0), paid + (guest:is_armor() and 0 or 1)
        visits.appraisal:dismiss()
    end
    check(bonus > 30 and paid > 200, "both kinds of guests showed up")
    visits:destroy()

    -- UV 감정: 위조(전설이라 우기는 희귀) + 숨은 저주
    local w = Workshop({ difficulty = "broker" })
    w.gold = 5000
    local helm = customer(w, "rune_greathelm", { grade = "rare", claimed_grade = "legendary", flaw = "curse", contamination = 30,
        flaw_mark = { x = 0.1, y = -0.1 }, grime = {} })
    local full_price = helm:asking_price()
    local forgery, stop = capture("appraisal:forgery_revealed")
    local slot = LAYOUT.day.bench_slot
    for row = 0, 8 do
        for col = 0, 8 do
            w.appraisal:scan(slot.x + 10 + col * 22.5, slot.y + 10 + row * 22.5, 1 / 60, true)
        end
    end
    stop()
    check(#forgery == 1 and helm.revealed.flaw and helm:is_forgery_revealed() and helm:asking_price() < full_price * 0.6,
        "UV exposes a forged, cursed helmet and the price drops")
    check(w.appraisal:buy() and w:hero_gear().helmet == helm, "the appraised helmet is bought and worn")

    -- 스탯: 기본 → 장착 → 강화 → 0% 마모
    local base = HERO.base
    local stats = HeroStats.compute(w)
    local expect = ARMORS.prototypes.rune_greathelm.stats.crit * helm:gear_mult()
    check(math.abs(stats.crit - (base.crit + expect)) < 1e-9 and helm:gear_mult() > ARMORS.curse.stat_mult * 0.99,
        "the cursed helmet adds crit x1.3 (and its grade share)")
    check(helm:wear_mult() == ARMORS.curse.wear_mult, "cursed armor wears faster")
    local plate = ready("guild_plate", "common", 0)
    w.inventory:place(plate, "hero", 3)
    stats = HeroStats.compute(w)
    local m = plate:gear_mult()                               -- 일반 등급 · 세척 완료: 1 + (1.5 − 1) × stat_share
    check(math.abs(m - (1 + (plate:power_mult() - 1) * ARMORS.stat_share)) < 1e-9 and m > 1 and m < plate:power_mult(), "armor stat share")
    check(math.abs(stats.max_hp - (base.max_hp + 40 * m)) < 1e-9 and math.abs(stats.defense - 7 * m) < 1e-9
        and math.abs(stats.guard - 7 * m * HERO.guard.per_defense) < 1e-9 and stats.skills.e.id == "guild_bulwark",
        "chest armor: HP, defense, guard and its E skill")
    check(w:move_item("hero", 3, "furnace", 1), "armor goes into the furnace")
    plate.durability = 40
    w.tempering_stones = 20
    check(w.forge:start("success"), "the forge takes armor")
    for _ = 1, 600 do
        w:update(1 / 60)
        if w.forge.forging == nil then break end
    end
    check(plate.level == 1 and plate.durability == 100 and w:move_item("furnace", 1, "hero", 3), "forging armor: +1 and durability 100%")
    local forged = HeroStats.compute(w)
    check(forged.defense > 7 * m and forged.defense < 7 * plate:power_mult(), "+1 raises defense by the armor stat share only")
    plate.durability = 0
    local broken = HeroStats.compute(w)
    check(broken.defense == 0 and broken.max_hp == base.max_hp and broken.skills.e.id == HERO.skills.bare_chest.id and broken.gear[3].broken,
        "worn-out armor gives nothing")
    plate.durability, plate.level = 100, 10
    local boots = ready("rift_striders", "legendary", 10)
    w.inventory:place(boots, "hero", 4)
    local capped = HeroStats.compute(w)
    check(capped.defense <= HERO.caps.defense and capped.move_speed <= HERO.caps.move_speed and capped.guard <= HERO.guard.max
        and capped.strike_interval < HERO.melee.interval and capped.counter > HERO.counter.base, "caps hold; boots speed up strikes and counters")
    local sword = ready("flame_sword", "rare", 3)
    w.inventory:place(sword, "hero", 1)
    local armed = HeroStats.compute(w)
    check(math.abs(armed.attack - (base.attack + sword:attack() * HERO.weapon.attack_share)) < 1e-9 and armed.damage_type == "fire"
        and armed.skills.q.id == "ember_smash" and armed.skills.q.cooldown < HERO.skills.weapon.fire.cooldown,
        "the equipped weapon sets attack, damage type and the Q skill (helmet cuts cooldowns)")

    -- 툴팁 문구 (ko · en)
    local Tooltip, HeroText, I18n, Settings = require("ui.Tooltip"), require("ui.HeroText"), require("systems.I18n"), require("systems.Settings")
    for _, code in ipairs({ "ko", "en" }) do
        Settings.set("language", code)
        local title, lines = HeroText.tooltip(w)
        check(#lines >= 10 and not title:find("{", 1, true), "hero tooltip lines (" .. code .. ")")
        local joined = title
        for _, line in ipairs(lines) do
            check(type(line[1]) == "string" and not line[1]:find("{", 1, true), "hero tooltip has an unfilled line: " .. tostring(line[1]))
            joined = joined .. "\n" .. line[1]
        end
        check(joined:find(I18n.item_name(sword), 1, true) and joined:find("+3", 1, true) and joined:find("[Q]", 1, true)
            and joined:find("[E]", 1, true) and joined:find("[R]", 1, true) and joined:find("%%"), "hero tooltip lists gear +N, % and Q/E/R")
        local found_stat, found_place = false, false
        for _, line in ipairs(Tooltip.lines(plate, nil, w)) do
            check(not line.text:find("{", 1, true), "armor tooltip has an unfilled line: " .. line.text)
            found_stat = found_stat or line.text:find(I18n.t("hero.slots.chest"), 1, true) ~= nil
            found_place = found_place or line.text == I18n.t("hero.place.armor")
        end
        check(found_stat and found_place, "armor tooltip shows its slot and the hero-only note (" .. code .. ")")
        check(I18n.t("grid.core_title") ~= "grid.core_title" and I18n.t("grid.core_title"):lower():find(code == "ko" and "공명 회로" or "circuit"),
            "the centre cell is named the resonance circuit core (" .. code .. ")")
    end
    Settings.set("language", "ko")
    w:destroy()
end

function SmokeHeroEquip.run(log, shots, missing_assets)
    require("core.RNG").set_seed(4404)
    local counts = check_classes()
    check_routing()
    check_armor_rules()
    require("tools.SmokeHeroEquipNight").run(check, ready, capture, shots, missing_assets)
    log(string.format("hero equip ok (3 categories: %d weapons / %d armor / %d relics; showcase / hero placement rules + refusals; "
        .. "purchase auto-routing grid -> rack -> refused, armor auto-equip, right-click swaps, [auto-place]; armor share, UV, forge, "
        .. "stats, tooltips ko/en; hero strikes, guard, counter, gear wear; save v5 + v3/v4 migration; screens)",
        counts.weapon, counts.armor, counts.relic))
end

return SmokeHeroEquip
