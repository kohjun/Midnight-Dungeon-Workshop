-- tools/SmokeWear.lua
-- 유물 내구도 0~100% 헤드리스 검사 (SmokeTest 가 SmokeForge 다음에 실행) — data/durability.lua · systems/Wear:
--   새 유물 100% · 진열장만 닳는다(보관함 그대로) · 활성 1초 per_second %p + 발사 1회 per_shot %p (data/durability.lua)
--   · 실제 밤 한 번에 진열 무기가 대략 per_second × 밤 길이 ~ 그 4배만큼 닳는다
--   과부하: 견습 x1(가속 없음) · 브로커 ≈x1.78 · 냉각 핀이 가속분 절반 · 균열은 x1.6
--   0% 완전 마모: combat:item_worn_out · 진열장 스탯에서 빠짐(증폭 시너지 해제) · 효과 구독 해제 · 그 무기는 쏘지 않는다
--   강화: 실패(유지·하락)는 내구도 그대로 · 성공은 정확히 100% · +10 불멸은 아무리 닳게 해도 100%
--   게이지 색 · 툴팁 줄 · RunSave 왕복(소수 내구도) · 옛 저장(버전 2: 내구도 2/3 칸) → 66.7%

local SmokeWear = {}

local function check(condition, message)
    if not condition then
        error("SmokeWear: " .. message, 2)
    end
end

local function near(a, b, eps)
    return math.abs(a - b) < (eps or 1e-6)
end

local function ready(id, level, cell, w)
    local item = require("systems.ItemFactory").make_ready(id, "common", level or 0)
    if w ~= nil then
        w.inventory:place(item, "grid", cell)
    end
    return item
end

local function check_rates()
    local Workshop, Wear = require("systems.Workshop"), require("systems.Wear")
    local WEAR = require("data.durability").wear
    local tick = WEAR.per_second * 10                                   -- 활성 10초
    local w = Workshop({ difficulty = "broker" })
    local sword, spare = ready("flame_sword", 0, 13, w), ready("frost_crossbow")
    w.inventory:place(spare, "storage", 1)
    check(sword.durability == 100 and sword.max_durability == 100, "relics start at 100%")
    local wear = Wear(w)
    wear:update(10, false)
    check(near(sword.durability, 100 - tick) and spare.durability == 100, "only displayed relics wear: per_second %p per active second")
    wear:shot(sword, 13)
    check(near(sword.durability, 100 - tick - WEAR.per_shot), "each shot wears per_shot %p more")
    local before = sword.durability
    wear:update(10, true)
    check(near(before - sword.durability, tick * w:overclock_wear_mult(), 1e-4) and w:overclock_wear_mult() > 1.7,
        "broker overclock wears about x1.78 faster")
    w.inventory:place(ready("cooling_fins"), "grid", 14)               -- 냉각 핀: 과부하 가속분 x0.5
    before = sword.durability
    wear:update(10, true)
    check(near(before - sword.durability, tick * (1 + (w:overclock_wear_mult() - 1) * 0.5), 1e-4), "cooling fins halve the overclock extra")
    local cracked = require("entities.Item")("flame_sword", { flaw = "crack" })
    cracked.owned = true
    w.inventory:place(cracked, "grid", 12)
    wear:update(10, false)
    check(near(cracked.durability, 100 - tick * 1.6), "cracked relics wear x1.6")
    w:destroy()
    local apprentice = Workshop({ difficulty = "apprentice" })
    local blade = ready("flame_sword", 0, 13, apprentice)
    local calm = Wear(apprentice)
    calm:update(10, true)
    check(near(blade.durability, 100 - tick), "apprentice overclock adds no wear")
    apprentice:destroy()
end

-- 실제 밤 한 번 (헤드리스): 진열 무기가 per_second × 밤 길이 ~ 그 4배만큼 닳는다 (작성 시점 수치로 과부하 없이 약 6%)
local function check_night()
    local w = require("systems.Workshop")({ difficulty = "broker" })
    w.day, w.max_hp, w.hp = 3, 100000, 100000
    local weapons = { ready("flame_sword", 2, 12, w), ready("inferno_musket", 2, 13, w), ready("storm_rod", 2, 14, w) }
    check(w:start_night(), "the night should start")
    for _ = 1, 60 * 90 do
        w:update(1 / 60)
        if w.phase ~= "night" then
            break
        end
    end
    check(w.phase ~= "night", "the night should end")
    local low = require("data.durability").wear.per_second * require("data.combat").night.duration     -- 밤 30초 내내 활성
    for _, item in ipairs(weapons) do
        local used = 100 - item.durability
        check(used >= low - 0.05 and used <= low * 4, string.format("one night wears a weapon %.1f~%.1f%%, got %.1f", low, low * 4, used))
    end
    w:destroy()
end

local function check_worn_out()
    local EventBus, Wear = require("core.EventBus"), require("systems.Wear")
    local w = require("systems.Workshop")({ difficulty = "broker" })
    local sword, crystal = ready("flame_sword", 0, 13, w), ready("mana_crystal", 0, 12, w)
    check(w:grid_stats().stats[sword].attack_mult > 1 and w.effects:is_active(crystal), "the amplifier boosts its neighbour")
    local worn, probe = 0, {}
    EventBus.subscribe("combat:item_worn_out", function(p) worn = worn + (p.item == crystal and 1 or 0) end, { owner = probe })
    crystal.durability = 0.1
    Wear(w):update(1, false)
    check(worn == 1 and crystal.durability == 0 and crystal:is_worn_out(), "hitting 0% fires combat:item_worn_out once")
    check(w:grid_stats().stats[crystal] == nil and w:grid_stats().stats[sword].attack_mult == 1 and not w.effects:is_active(crystal),
        "a worn-out amplifier stops boosting (effects unsubscribed)")
    check(w.inventory:locate(crystal) == "grid", "worn-out relics stay on the display")
    -- 0% 무기는 쏘지 않는다
    local fired = 0
    EventBus.subscribe("combat:fired", function(p) fired = fired + (p.item == sword and 1 or 0) end, { owner = probe })
    sword.durability = 0
    w._grid_stats = nil
    w.max_hp, w.hp = 100000, 100000
    w:start_night()
    for _ = 1, 60 * 8 do
        w:update(1 / 60)
    end
    check(fired == 0, "a worn-out weapon never fires")
    EventBus.unsubscribe_owner(probe)
    w:destroy()
end

local function check_forge_and_immortal()
    local Wear = require("systems.Wear")
    local w = require("systems.Workshop")({ difficulty = "broker" })
    w.gold, w.tempering_stones = 100000, 99
    local sword = ready("flame_sword", 3)
    sword.durability = 40
    w.inventory:place(sword, "furnace", 1)
    for _, force in ipairs({ "keep", "down" }) do
        w.forge:start(force)
        while w.forge.forging ~= nil do
            w.forge:update(0.1)
        end
        check(sword.durability == 40, force .. " keeps the durability")
    end
    w.forge:start("success")
    while w.forge.forging ~= nil do
        w.forge:update(0.1)
    end
    check(sword.durability == 100, "a successful forge resets durability to exactly 100%")
    local seal = ready("storm_rod", 10, 13, w)
    Wear(w):update(3600, true)
    check(seal.durability == 100 and not seal:is_worn_out() and seal:durability_state() == "immortal", "+10 immortal relics never wear")
    w:destroy()
end

local function check_ui_and_save()
    local I18n = require("systems.I18n")
    local ItemStatus, Tooltip = require("ui.ItemStatus"), require("ui.Tooltip")
    local DURABILITY = require("data.durability")
    local item = ready("flame_sword")
    item.durability = 20
    check(item:durability_state() == "low" and ItemStatus.gauge_color(item) == DURABILITY.gauge.low, "30% or less is the red warning")
    item.durability = 45
    check(ItemStatus.gauge_color(item) == DURABILITY.gauge.mid, "31~59% is amber")
    item.durability = 0
    local RunSave, Workshop = require("systems.RunSave"), require("systems.Workshop")
    local w = Workshop({ difficulty = "broker" })
    local found = false
    for _, line in ipairs(Tooltip.lines(item, nil, w)) do
        found = found or line.text == I18n.t("tooltip.durability_broken", { pct = 0 })
    end
    check(found, "the tooltip shows the worn-out line")
    ready("flame_sword", 2, 13, w).durability = 42.5
    local data = RunSave.deserialize(RunSave.serialize(RunSave.snapshot(w)))
    w:destroy()
    local back = RunSave.resume(data, Workshop)
    check(back.inventory:get("grid", 13).durability == 42.5, "durability survives save/continue")
    local old = RunSave.snapshot(back)                                  -- 버전 2 저장: 내구도 2/3 칸
    back:destroy()
    old.version = 2
    for _, plain in ipairs(old.items) do
        plain.durability, plain.max_durability = 2, 3
    end
    local migrated = RunSave.deserialize(RunSave.serialize(old))
    check(migrated ~= nil and migrated.version == RunSave.VERSION, "version-2 saves can still be continued")
    local again = RunSave.resume(migrated, Workshop)
    local relic = again.inventory:get("grid", 13)
    check(near(relic.durability, 200 / 3, 1e-6) and relic.max_durability == 100, "old 2/3 durability becomes 66.7%")
    again:destroy()
    old.version = 1
    check(RunSave.deserialize(RunSave.serialize(old)) == nil, "saves older than version 2 are dropped")
end

function SmokeWear.run(log)
    require("core.RNG").set_seed(7171)
    check_rates()
    check_night()
    check_worn_out()
    check_forge_and_immortal()
    check_ui_and_save()
    log("wear ok (100%% start, display-only wear per_second/s + per_shot/shot from data, one night ~5~20%%, overclock x1.78 broker / x1 apprentice, "
        .. "cooling fins, crack x1.6, 0%% → no attack/synergy, forge keep/drop keep durability, success = 100%%, +10 immortal, "
        .. "save, v2 save 2/3 → 66.7%%)")
end

return SmokeWear
