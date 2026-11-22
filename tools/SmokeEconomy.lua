-- tools/SmokeEconomy.lua
-- 2단계 경제·메타 규칙 헤드리스 검사: 결계 유지비 월말 일정·파산, 길드 상점, 자원 소모(x1.8)·보충, 모험가 호출비,
-- 공방 개조(그리드 봉인·방벽·렌즈 자동 탐지), 암시장 3종, 장인 명성 정산·강화·저장 형식, 난이도 규칙.
-- 5단계 난이도 · 달력 · 계절 · 과열 차등은 tools/SmokeContracts.

local SmokeEconomy = {}

local DT = 1 / 60
local NIGHT = require("data.combat").night
local NIGHT_STEPS = 60 * (NIGHT.duration + NIGHT.overtime_max + 2)     -- 웨이브를 다 소탕해야 끝난다 (소탕 시간 한도까지)

local function check(condition, message)
    assert(condition, "SmokeEconomy: " .. message)
end

local function run_night(workshop)
    check(workshop:start_night(), "night should start on day " .. workshop.day)
    -- 무기 없는 진열장: 웨이브를 다 소탕해야 밤이 끝나므로 남은 몬스터가 모두 방벽에 닿는다 — 경제 검사가 패배로 끝나지 않게
    local hp = workshop.hp
    workshop.hp = 1000000
    for _ = 1, NIGHT_STEPS do
        workshop:update(DT)
        if workshop.phase ~= "night" or workshop.result ~= nil then
            break
        end
    end
    workshop.hp = math.min(hp, workshop.hp)
end

local function bench_center()
    local slot = require("data.layout").day.bench_slot
    return slot.x + slot.w / 2, slot.y + slot.h / 2
end

-- 결계 유지비: 매달 말일(10일마다) · 난이도 배율 · 할인 · 경고 · 미납 파산
local function check_tribute()
    local Workshop = require("systems.Workshop")
    local amounts = require("data.balance").tribute.amounts
    local DIFFICULTIES = require("data.difficulties")
    local broker = Workshop({ difficulty = "broker" })
    local tribute, mult = broker.tribute, DIFFICULTIES.modes.broker.tribute_mult
    local function due(index)
        return math.floor(amounts[index] * mult + 0.5)
    end
    check(tribute:amount_for(5) == nil and tribute:amount_for(10) == due(1) and tribute:amount_for(20) == due(2)
        and #tribute:schedule() == 6, "broker upkeep is collected at every month-end (10 days) x" .. mult)
    broker.gold = 50
    check(tribute:collect(10) == false and broker.gold == 50, "short tribute must fail without taking gold")
    broker.gold = due(1) + 150
    check(tribute:collect(10) == true and broker.gold == 150 and broker.stats.tributes_paid == 1, "tribute payment")
    tribute:discount_next(11, 250)
    check(tribute:amount_for(20) == due(2) - 250, "blood moon discount should lower the next tribute")
    check(tribute:warning(9) ~= nil and tribute:warning(8) == nil, "warning banner only from D-1")
    broker:destroy()

    local apprentice = Workshop({ difficulty = "apprentice" })
    local easy = DIFFICULTIES.modes.apprentice.tribute_mult
    check(apprentice.tribute:amount_for(30) == math.floor(amounts[3] * easy + 0.5) and apprentice.tribute:amount_for(40) == nil,
        "apprentice tribute x" .. easy .. " within 30 days")
    apprentice:destroy()

    local bankrupt = Workshop({ difficulty = "broker" })
    bankrupt.day, bankrupt.gold = 10, 10
    run_night(bankrupt)
    check(bankrupt.result == "bankrupt", "missing the month-end upkeep must bankrupt the run")
    bankrupt:destroy()
end

local function check_shop_and_supplies()
    local Workshop = require("systems.Workshop")
    local w = Workshop({ difficulty = "broker" })
    w.day, w.gold = 10, 3200
    run_night(w)
    check(w.phase == "shop" and w.shop.relic ~= nil, "paying the tribute should open the guild shop")
    check(not w.shop:buy("uv_pack"), "full UV battery should block the pack")
    w.supplies:spend("uv", 90)
    check(w.shop:buy("uv_pack") and math.floor(w.supplies.uv + 0.5) == 70, "UV pack adds 60%")
    w:damage_hp(40, "test")
    local damaged_hp = w.hp
    check(w.shop:buy("repair_kit") and w.hp == math.min(w.max_hp, damaged_hp + 30), "repair kit heals 30")
    check(w.shop:buy("appraisal_scroll") and w.scrolls == 1, "scroll purchase")
    local shop_relic = w.shop.relic
    check(w.shop:buy("rare_relic") and w.shop.relic == nil and w.inventory:locate(shop_relic) ~= nil
        and w.inventory:locate(shop_relic) ~= "bench", "the shop relic is auto-placed (showcase / hero / rack)")
    local uv_before = w.supplies.uv
    w:close_shop()
    check(w.phase == "day" and w.day == 11 and w.supplies.uv == math.min(100, uv_before + 20), "next morning refills supplies by 20%")

    -- 손님 호출비: 무료 3명 이후에도 유료로 부를 수 있고 같은 날 비싸진다
    check(w.appraisal:summon_cost() == 25, "first summon costs 25 G")
    check(w.appraisal:summon_customer(), "summon should succeed")
    check(w.appraisal:summon_cost() == 40, "second summon costs 40 G")
    -- 즉시 감정 주문서
    check(w.appraisal:use_scroll() and w.appraisal:bench_item().revealed.complete, "scroll reveals everything")
    w:destroy()

    -- UV 배터리: 움직이기만 하면 소모 없음, 버튼 홀드 중 초당 10.8% · 정화수: 오염도 10% 당 3.6% (예전의 x1.8)
    local Item = require("entities.Item")
    local s = Workshop({ difficulty = "broker" })
    local item = Item("flame_sword", { contamination = 100, grime = {} })
    item.owned = true
    s.inventory:place(item, "bench", 1)
    local cx, cy = bench_center()
    for _ = 1, 60 do
        s.appraisal:scan(cx, cy, DT, false)
    end
    check(s.supplies.uv == 100 and not s.appraisal.lens_on and not item.revealed.grade,
        "hovering in UV mode without holding must not scan or drain")
    check(s.appraisal:scan(cx - 400, cy, DT, true) == "idle" and s.supplies.uv == 100, "holding outside the bench keeps the lens off")
    for _ = 1, 60 do
        s.appraisal:scan(cx, cy, DT, true)
    end
    check(s.appraisal.lens_on and item.revealed.grade, "holding the button turns the lens on and scans")
    check(math.abs(s.supplies.uv - (100 - 10.8)) < 0.5, "held lens drains 10.8% per second, got " .. s.supplies.uv)
    s.supplies:spend("uv", 100)
    check(s.appraisal:scan(cx, cy, DT, true) == "empty" and not s.appraisal.lens_on, "dead battery keeps the lens off")
    for _ = 1, 400 do
        s.appraisal:scrub(cx, cy, 30)
    end
    check(item.cleaned and math.abs(s.supplies.water - 64) < 0.5, "full clean of 100% grime costs 36% water, left " .. s.supplies.water)
    s.supplies:spend("water", 100)
    item.cleaned, item.contamination = false, 20
    check(s.appraisal:scrub(cx, cy, 30) == "no_water", "empty water blocks scrubbing")
    s:destroy()
end

local function check_upgrades()
    local Workshop = require("systems.Workshop")
    local Item = require("entities.Item")
    local w = Workshop({ difficulty = "broker" })
    w.gold = 5000
    check(not w:is_cell_open(1) and w:is_cell_open(13) and not w:is_cell_open(11), "start with the 3x3 center open")
    local item = Item("flame_sword", {})
    item.owned = true
    w.inventory:place(item, "storage", 1)
    check(not w:move_item("storage", 1, "grid", 11), "sealed cells reject items")
    check(w.upgrades:buy("grid") and w:is_cell_open(11), "grid expansion opens 3x4")
    check(w:move_item("storage", 1, "grid", 11), "newly opened cell accepts items")
    local hp = w.max_hp
    check(w.upgrades:buy("wall") and w.max_hp == hp + 20 and w.hp == w.max_hp, "wall upgrade raises max HP")
    for _ = 1, 3 do
        w.upgrades:buy("lens")
    end
    local cursed = Item("flame_sword", { flaw = "crack" })
    w.appraisal:present_customer(cursed, false)
    check(cursed.revealed.flaw, "lens level 3 auto-detects a flaw")
    w:destroy()
end

local function check_black_market()
    local Workshop = require("systems.Workshop")
    local Item = require("entities.Item")
    local w = Workshop({ difficulty = "broker" })
    w.gold = 2000
    check(w.black_market:roll(3) ~= nil, "every third day guarantees a black market event")

    w.black_market:start_event("mystery_boxes")       -- 제안은 [의뢰]에서 수락해야 상자를 열 수 있다
    check(w.black_market:is_pending() and not w.black_market:open_box(1), "boxes stay sealed until the offer is accepted")
    check(w.black_market:accept() and w.black_market:open_box(1) and w.black_market.opened[1], "mystery box opens")
    check(not w.black_market:open_box(1), "a box opens only once")

    local flawed = Item("flame_sword", { flaw = "crack" })
    local normal_price = w:sale_price(flawed)
    w.black_market:start_event("fence_request")
    check(w:sale_price(flawed) == normal_price, "the fence pays nothing extra before the offer is accepted")
    w.black_market:accept()
    check(w:sale_price(flawed) == math.floor(normal_price * 2.5 + 0.5), "fence buys flawed items at x2.5")
    check(w.black_market:decline() == false, "an accepted offer cannot be declined")

    w.black_market:start_event("blood_moon")
    check(w.black_market:accept_blood_moon() and w.black_market:night_modifiers().hp_mult == 1.5, "blood moon buffs monsters")
    local before = w.tribute:amount_for(10)
    w.black_market:settle_night()
    check(w.tribute:amount_for(10) == before - 250, "surviving the blood moon discounts the tribute")
    w:destroy()
end

local function check_meta()
    local MetaProgression = require("systems.MetaProgression")
    local Workshop = require("systems.Workshop")
    MetaProgression.use_memory_only()
    local rp = MetaProgression.compute({ reason = "victory", difficulty = "broker", days_survived = 20, tributes_paid = 4, kills = 250 })
    check(rp.total == 1125, "RP formula (20x15 + 4x50 + 250/5 + 200) x1.5 = 1125, got " .. rp.total)
    MetaProgression.award({ reason = "victory", difficulty = "broker", days_survived = 20, tributes_paid = 4, kills = 250 })
    check(MetaProgression.upgrade("start_capital") and MetaProgression.rp() == 1085, "upgrade spends RP")
    for _ = 1, 3 do
        MetaProgression.upgrade("workshop_design")
    end
    local bonuses = MetaProgression.bonuses()
    check(bonuses.start_gold == 40 and bonuses.grid_stage == 2 and bonuses.max_hp == 30, "meta bonuses aggregate")
    local w = Workshop({ difficulty = "broker", meta = bonuses })
    check(w.gold == 220 and w.max_hp == 130 and w:is_cell_open(11), "meta bonuses apply to a new run (3x4 start)")
    w:destroy()

    -- save_meta.lua 형식 왕복 (임시 파일)
    local path = "smoke_meta_roundtrip.lua"
    love.filesystem.write(path, MetaProgression.serialize({ rp = 77, levels = { trade = 2, alchemy = 9 } }))
    local loaded = MetaProgression.read_file(path)
    love.filesystem.remove(path)
    check(loaded.rp == 77 and loaded.levels.trade == 2 and loaded.levels.alchemy == 4, "save file round trip (levels clamped)")
    MetaProgression.use_memory_only()
end

-- 난이도: 악몽 보스, 악몽 저주 비율, 견습 용광로 보정, 해금 조건
local function check_difficulties()
    local RNG = require("core.RNG")
    local Workshop = require("systems.Workshop")
    local WaveSpawner = require("systems.WaveSpawner")
    local ItemFactory = require("systems.ItemFactory")
    local Item = require("entities.Item")
    local DIFFICULTIES = require("data.difficulties")

    local abyss = Workshop({ difficulty = "abyss" })
    local spawner = WaveSpawner(10, RNG.stream("smoke_boss"), { boss = abyss.boss_rules, midboss = abyss.midboss_rules })
    local boss_found = false
    for _ = 1, 60 * 12 do
        for _, monster in ipairs(spawner:update(DT) or {}) do
            boss_found = boss_found or monster.spec.boss == true
        end
    end
    check(boss_found, "abyss month-end (day 10) should spawn its boss by 8s")
    abyss:destroy()

    local function cursed_count(rules)
        local rng, count = RNG.stream("smoke_customers"), 0
        for _ = 1, 200 do
            if ItemFactory.customer_item(rng, 1, rules).flaw == "curse" then
                count = count + 1
            end
        end
        return count
    end
    local abyss_cursed = cursed_count(DIFFICULTIES.modes.abyss.customer)
    local apprentice_cursed = cursed_count(DIFFICULTIES.modes.apprentice.customer)
    check(abyss_cursed > apprentice_cursed * 1.5, "abyss should bring far more cursed items")

    local apprentice = Workshop({ difficulty = "apprentice" })
    local blade = Item("flame_sword", {})
    blade.level = 3                              -- +4 기본 64% + 견습 10%p
    check(math.abs(apprentice.forge:chance(blade) - 0.74) < 1e-9 and apprentice.forge:chance(Item("flame_sword", {})) == 1,
        "apprentice forge bonus: +4 74%, +1 stays 100%")
    apprentice:destroy()
    return abyss_cursed, apprentice_cursed
end

-- 자원 드랍: 일반 몬스터 18% 확률로 +12%
local function check_drops()
    local EventBus = require("core.EventBus")
    local Workshop = require("systems.Workshop")
    local Monster = require("entities.Monster")
    local w = Workshop({ difficulty = "broker" })
    w.supplies:spend("uv", 100)
    w.supplies:spend("water", 100)
    local drops, amount = 0, nil
    local probe = {}
    EventBus.subscribe("supplies:dropped", function(p)
        if p.kind ~= "stone" then          -- 연마석 드랍은 tools/SmokeGuild 가 따로 센다
            drops, amount = drops + 1, p.amount
        end
    end, { owner = probe })
    local kills = 2000
    for _ = 1, kills do
        EventBus.emit("combat:monster_killed", { monster = Monster("slime", 0, 0), gold = 0, x = 0, y = 0 })
        w.supplies:spend("uv", 100)
        w.supplies:spend("water", 100)
    end
    EventBus.unsubscribe_owner(probe)
    w:destroy()
    check(amount == 12, "a drop restores 12%")
    check(drops > kills * 0.14 and drops < kills * 0.22, "drop chance should be about 18%, got " .. drops .. " / " .. kills)
    return drops / kills
end

function SmokeEconomy.run(log)
    require("core.RNG").set_seed(9090)
    check_tribute()
    check_shop_and_supplies()
    check_upgrades()
    check_black_market()
    check_meta()
    local abyss_cursed, apprentice_cursed = check_difficulties()
    local drop_rate = check_drops()
    log("economy & meta ok (tribute/bankrupt, shop, supplies, UV hold scan, summon, upgrades, black market, RP; "
        .. "cursed per 200: abyss %d, apprentice %d; drop rate %.1f%%)", abyss_cursed, apprentice_cursed, drop_rate * 100)
end

return SmokeEconomy
