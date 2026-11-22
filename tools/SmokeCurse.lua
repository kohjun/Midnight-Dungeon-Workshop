-- tools/SmokeCurse.lua
-- 저주 대가 · 최종일 보스 저주 비율 헤드리스 검사 (SmokeTest 가 SmokeWear 다음에 실행) — data/balance.lua 의 curse ·
-- systems/WorkshopEconomy(damage_hp) · systems/effects/CurseEffects(hp_for_gold) · CoreEffects(blood_price) · systems/Achievements:
--   밤의 저주 대가는 모두 합쳐 한 밤에 curse.night_cap 까지 — HP 1 당 골드가 큰 계약부터 쓴다 (핏빛 성배 → 피의 계약서 → 단검)
--     단검 + 계약서 + 성배: HP -상한 · 골드 = 성배 + 계약서, 두 진열 순서 모두 같다
--     계약서 2장: 두 번째 계약서는 남은 상한만큼만 바치고 골드도 그만큼 비례 (floor(gold × 바친 HP / hp_cost + 0.5))
--   대가만 있는 밤은 새벽 무피해 보너스 그대로(night_damage 0) · 다음 밤 상한 초기화 · 상한을 넘긴 대가는 0
--     · 밤의 몬스터 피해는 여전히 보너스를 없앤다 (대조군)
--   낮의 저주 피해(암시장 저주 폭탄 등)는 상한 없음
--   최종일(max_days) 월말 대보스 처치만 진열장 저주 유물 수 · 비율을 기록 (한 달 전 처치는 기록 없음) → 악몽 계약의 심연 장악 판정
--   엔딩 조건(ending.monopoly.condition) · 도감 기준 줄(compendium.ending_target_master) 문구(ko · en)에 채워지지 않은 자리표시자 없음
-- 끝나면 메타 진행도(보스 처치로 열린 업적)를 첫 실행 상태로 되돌린다.

local SmokeCurse = {}

local SEED = 5151
local CELLS = { 7, 8, 9, 12, 13 }          -- 시작 개방 칸(중앙 3x3) 중 다섯 칸
local WALL_HP = 1000                       -- 대가·피해가 런을 끝내지 않게 넉넉한 방벽

local function check(condition, message)
    if not condition then
        error("SmokeCurse: " .. message, 2)
    end
end

local function near(a, b)
    return a ~= nil and b ~= nil and math.abs(a - b) < 1e-9
end

-- 원형 id 의 효과 중 kind 종류 (data/items.lua)
local function effect_of(id, kind)
    for _, effect in ipairs(require("data.items").prototypes[id].effects or {}) do
        if effect.type == kind then
            return effect
        end
    end
    error("SmokeCurse: " .. id .. " has no '" .. kind .. "' effect")
end

-- 방벽을 넉넉히 둔 공방에 ids 를 CELLS 순서대로 진열한다 (특수 유물도 entities/Item 으로 직접 만든다)
local function display(ids, difficulty)
    local Item = require("entities.Item")
    local w = require("systems.Workshop")({ difficulty = difficulty or "broker" })
    w.max_hp, w.hp = WALL_HP, WALL_HP
    for i, id in ipairs(ids) do
        local item = Item(id, { contamination = 0 })
        item.owned = true
        w.inventory:place(item, "grid", CELLS[i])
    end
    return w
end

-- 밤을 시작하고 (깎인 HP, 늘어난 골드)
local function night(w)
    local hp, gold = w.hp, w.gold
    check(w:start_night(), "the night should start on day " .. w.day)
    return hp - w.hp, w.gold - gold
end

-- (a) 상한 · 진열 순서 무관, (c) 대가만 있는 밤의 새벽 보너스, (d) 다음 밤 상한 초기화
local function check_cap_and_order()
    local BALANCE = require("data.balance")
    local CAP, DAWN = BALANCE.curse.night_cap, BALANCE.dawn
    local dagger, scroll = effect_of("cursed_dagger", "blood_price"), effect_of("blood_pact_scroll", "hp_for_gold")
    local chalice = effect_of("bloodmoon_chalice", "hp_for_gold")
    check(dagger.hp_cost + scroll.hp_cost + chalice.hp_cost > CAP, "precondition: dagger + scroll + chalice tolls exceed the nightly cap")
    check(chalice.gold / chalice.hp_cost > scroll.gold / scroll.hp_cost and chalice.hp_cost + scroll.hp_cost == CAP,
        "precondition: the chalice pays more gold per HP and chalice + scroll fill the cap exactly")
    local pacts = chalice.gold + scroll.gold
    local orders = {
        { "cursed_dagger", "blood_pact_scroll", "bloodmoon_chalice" },      -- 단검이 먼저 구독돼도
        { "bloodmoon_chalice", "blood_pact_scroll", "cursed_dagger" },
    }
    local w = nil
    for i, order in ipairs(orders) do
        if w ~= nil then
            w:destroy()
        end
        w = display(order)
        local hp, gold = night(w)
        check(hp == CAP and gold == pacts and w.curse_paid == CAP, string.format("placement order %d: the cap goes to the best gold "
            .. "per HP first (HP -%d, gold +%d), got HP -%d, gold +%d", i, CAP, pacts, hp, gold))
    end
    local bonus = w:dawn_bonus()
    check(w.night_damage == 0 and bonus == DAWN.flawless_base + DAWN.flawless_per_day * w.day and bonus > 0,
        "curse tolls are not wall damage: a toll-only night keeps the flawless dawn bonus")
    check(w:claim_dawn_bonus() == bonus, "the toll-only night pays the flawless dawn bonus at dawn")
    require("systems.DayCycle").finish_night(w)                 -- 헤드리스 새벽 → 2일차 아침
    check(w.phase == "day" and w.day == 2 and w.result == nil, "the headless dawn leads to the next morning")
    local hp, gold = night(w)
    check(hp == CAP and gold == pacts and w.curse_paid == CAP, string.format("the toll cap resets every night "
        .. "(second night: HP -%d, gold +%d)", hp, gold))
    local before = w.hp
    check(w:damage_hp(1, "curse") == 0 and w.hp == before and w.curse_paid == CAP, "tolls past the nightly cap are not charged")
    check(w:damage_hp(2, "monster") == 2 and w.night_damage == 2 and w:dawn_bonus() == 0,
        "a monster hit at night still voids the flawless dawn bonus")
    w:destroy()
end

-- (b) 계약서 2장: 두 번째는 남은 상한만큼 비례 골드, (e) 낮의 저주 피해는 상한 없음
local function check_prorated_and_day()
    local CAP = require("data.balance").curse.night_cap
    local scroll = effect_of("blood_pact_scroll", "hp_for_gold")
    check(scroll.hp_cost < CAP and scroll.hp_cost * 2 > CAP, "precondition: two blood pact scrolls overflow the nightly cap")
    local w = display({ "blood_pact_scroll", "blood_pact_scroll" })
    local prorated = math.floor(scroll.gold * (CAP - scroll.hp_cost) / scroll.hp_cost + 0.5)
    local hp, gold = night(w)
    check(prorated > 0 and prorated < scroll.gold and hp == CAP and gold == scroll.gold + prorated, string.format("two scrolls: "
        .. "HP -%d, gold +%d (%d + prorated %d), got HP -%d, gold +%d", CAP, scroll.gold + prorated, scroll.gold, prorated, hp, gold))
    w:destroy()
    w = display({})
    local amount = CAP + 2
    local before = w.hp
    check(w.phase == "day" and w:damage_hp(amount, "curse") == amount and w.hp == before - amount and (w.curse_paid or 0) == 0,
        "day-phase curse damage (black market curse bomb) is not capped")
    w:destroy()
end

-- (f) 최종일 보스 처치만 저주 유물 수 · 비율을 기록한다
local function check_final_boss_share()
    local EventBus, Monster = require("core.EventBus"), require("entities.Monster")
    local WaveSpawner, Endings = require("systems.WaveSpawner"), require("systems.Endings")
    local ABYSS = require("data.endings").abyss
    local w = display({ "cursed_dagger", "cursed_dagger", "cursed_dagger", "cursed_dagger", "mana_crystal" }, ABYSS.difficulty)
    local cursed, shown = require("systems.Achievements").cursed_on_grid(w)
    check(cursed == 4 and shown == 5, "4 cursed daggers + 1 mana crystal on display, got " .. cursed .. " / " .. shown)
    local function boss_killed(day)
        w.day = day
        local id = WaveSpawner.boss_for(day)
        check(id ~= nil, "day " .. day .. " should bring a month-end boss")
        local boss = Monster(id, 900, 400)
        check(boss:is_boss(), id .. " should be a month-end boss")
        EventBus.emit("combat:monster_killed", { monster = boss, gold = 0, x = boss.x, y = boss.y })
    end
    boss_killed(w.max_days - 10)
    check(w.stats.final_boss_cursed == nil and w.stats.final_boss_share == nil and Endings.decide(w) ~= "abyss",
        "a month-end boss before the final day records no cursed count or share")
    boss_killed(w.max_days)
    check(w.stats.final_boss_cursed == 4 and near(w.stats.final_boss_share, 0.8), "the final-day boss kill records 4 cursed relics "
        .. "and a 0.8 share, got " .. tostring(w.stats.final_boss_cursed) .. " / " .. tostring(w.stats.final_boss_share))
    local abyss = 4 >= ABYSS.cursed and 0.8 >= ABYSS.share
    check((Endings.decide(w) == "abyss") == abyss, "the abyss ending follows the recorded cursed count and share")
    w:destroy()
end

-- (g) 마스터 장인 문구의 자리표시자 ({level} · {mult})가 ko · en 모두 채워진다
local function check_texts()
    local Text, I18n, Endings = require("lib.text"), require("systems.I18n"), require("systems.Endings")
    local vars = Endings.condition_vars()
    check(vars.level ~= nil and vars.mult ~= nil and vars.hp ~= nil, "Endings.condition_vars carries the master relic level and discount")
    local target = { gold = 12300, hp = vars.hp, level = vars.level }      -- ui/CompendiumModal:target_text 가 넘기는 값과 같은 키
    for _, code in ipairs(I18n.languages()) do
        local texts = require("data.locales." .. code .. ".collection")
        local cases = {
            { "ending.monopoly.condition", texts.ending.monopoly.condition, vars },
            { "compendium.ending_target_master", texts.compendium.ending_target_master, target },
        }
        for _, case in ipairs(cases) do
            check(type(case[2]) == "string", code .. ": missing text " .. case[1])
            local text = Text.fill(case[2], case[3])
            check(not text:find("{", 1, true), code .. ": unfilled placeholder in " .. case[1] .. ": " .. text)
        end
    end
end

function SmokeCurse.run(log)
    require("core.RNG").set_seed(SEED)
    check_cap_and_order()
    check_prorated_and_day()
    check_final_boss_share()
    check_texts()
    require("systems.MetaProgression").use_memory_only()     -- 보스 처치로 열린 업적을 지운다 (뒤 검사가 첫 실행 상태에서 돌도록)
    log("curse ok (nightly toll cap %d: best gold per HP first in any placement order, prorated pact gold, toll-only night keeps "
        .. "the dawn bonus, cap resets nightly, day curse uncapped; only the final-day boss records the cursed share; "
        .. "master-relic texts filled ko/en)", require("data.balance").curse.night_cap)
end

return SmokeCurse
