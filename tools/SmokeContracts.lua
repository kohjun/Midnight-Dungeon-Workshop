-- tools/SmokeContracts.lua
-- 5단계 계약 · 장기 달력 · 계절 · 과열 차등 · 에너지 소모 헤드리스 검사 (tools/SmokeTest 가 부른다):
--   계약 5장(위 3 · 아래 2) · 악몽은 베테랑 클리어로만 해금 · ??? 는 무엇을 클리어해도 봉인 (공방도 만들 수 없다)
--   달력 "M개월 D일" · 30일 계절 · 계절 효과(여름 과열 · 가을 위조 · 겨울 체력·방어력·유지비) · 웨이브 실효 일차 · 보스 순환
--   과부하 마모 배율(과열 위험 계수 → systems/Wear): 견습 x1 · 브로커 ≈x1.8 · 베테랑 여름 ≈x2.8
--     · 악몽 여름 = 1 + 위험 계수 × per_risk ≈x3.597 (상한 max_mult x3.6 바로 아래) · 위험 계수를 0.2 로 올리면 정확히 상한
--   UV·정화수 소모: 난이도 배율 · 25% 경고(supplies:low) 한 번 · 처치 골드 배율 · 새벽 무피해 보너스
--   달력 HUD(베테랑 여름 · 악몽 겨울 밤 과부하 · 견습 단계 글자) + 새벽 정산창 계절 배지 오프스크린 렌더 (--shots 면 smoke_calendar.png)

local SmokeContracts = {}

local DT = 1 / 60

local function check(condition, message)
    assert(condition, "SmokeContracts: " .. message)
end

local function near(a, b)
    return math.abs(a - b) < 1e-6
end

local function check_unlocks()
    local Progress = require("systems.Progress")
    local DIFFICULTIES = require("data.difficulties")
    local ContractCards = require("ui.ContractCards")
    check(#DIFFICULTIES.order == 5 and DIFFICULTIES.rows[1] == 3 and DIFFICULTIES.rows[2] == 2, "five contracts in rows of 3 + 2")
    local first, fourth = ContractCards.rect(1), ContractCards.rect(4)
    check(fourth.y > first.y + first.h and ContractCards.rect(5).x > fourth.x, "bottom row sits below the top row")
    Progress.use_memory_only()
    for _, id in ipairs({ "apprentice", "broker", "veteran" }) do
        check(Progress.is_unlocked(id), id .. " is open from the start")
    end
    check(not Progress.is_unlocked("abyss") and not Progress.is_unlocked("master_trace") and Progress.is_veiled("master_trace"),
        "abyss and the veiled ??? (master_trace) start locked")
    check(#Progress.mark_cleared("apprentice") == 0 and #Progress.mark_cleared("broker") == 0 and not Progress.is_unlocked("abyss"),
        "clearing apprentice or broker does not unlock abyss")
    local unlocked = Progress.mark_cleared("veteran")
    check(unlocked[1] == "abyss" and Progress.is_unlocked("abyss"), "clearing veteran unlocks abyss permanently")
    check(Progress.is_veiled("master_trace"), "the ??? card stays veiled after a veteran clear")
    unlocked = Progress.mark_cleared("abyss")
    check(unlocked[1] == "master_trace" and Progress.is_unlocked("master_trace") and not Progress.is_veiled("master_trace"),
        "clearing abyss unveils The Master's Trace permanently")
    Progress.use_memory_only()
end

local function check_calendar()
    local Calendar = require("systems.Calendar")
    local DIFFICULTIES = require("data.difficulties")
    local WaveSpawner = require("systems.WaveSpawner")
    local m, d = Calendar.date(1)
    local m2, d2 = Calendar.date(11)
    local m3, d3 = Calendar.date(120)
    check(m == 1 and d == 1 and m2 == 2 and d2 == 1 and m3 == 12 and d3 == 10, "1 month = 10 days")
    local veteran, apprentice = DIFFICULTIES.modes.veteran, DIFFICULTIES.modes.apprentice
    check(Calendar.season(apprentice, 25) == nil and Calendar.season(veteran, 30) == "spring" and Calendar.season(veteran, 31) == "summer"
        and Calendar.season(veteran, 61) == "autumn" and Calendar.season(veteran, 120) == "winter", "four 30-day seasons on 1-year contracts")
    check(Calendar.season_started(veteran, 31) == "summer" and Calendar.season_started(veteran, 32) == nil, "season change on day 31")
    local winter, WINTER = Calendar.modifiers(veteran, 100), require("data.calendar").seasons.winter
    check(near(winter.monster_hp_mult, WINTER.monster_hp_mult) and near(winter.monster_defense, WINTER.monster_defense)
        and near(winter.tribute_mult, WINTER.tribute_mult) and winter.monster_hp_mult > 1 and winter.monster_defense > 0,
        "veteran winter: tougher monsters (HP · defense) · upkeep up")
    local abyss_winter = Calendar.modifiers(DIFFICULTIES.modes.abyss, 100)
    check(abyss_winter.monster_hp_mult > winter.monster_hp_mult and abyss_winter.tribute_mult > winter.tribute_mult,
        "abyss seasons are more extreme")
    local bosses, mids = {}, {}
    for i = 1, 5 do
        bosses[i], mids[i] = WaveSpawner.boss_for(i * 10), WaveSpawner.midboss_for(i * 10 - 5)
    end
    check(bosses[1] == "gatekeeper_golem" and bosses[4] == "rift_lord" and bosses[5] == "gatekeeper_golem"
        and WaveSpawner.boss_for(5) == nil and WaveSpawner.midboss_for(10) == nil,
        "month-end bosses cycle the four big bosses")
    check(mids[1] == "mid_vanguard" and mids[2] == "mid_raider" and mids[3] == "mid_hexer" and mids[4] == "mid_stalker"
        and mids[5] == "mid_vanguard" and select(2, WaveSpawner.headliner(15)) == "midboss", "mid-month mid-bosses cycle the four")
    check(WaveSpawner.intensity(1) == 1 and WaveSpawner.intensity(111) > WaveSpawner.intensity(51), "gimmicks escalate by month")
end

local function check_risks()
    local Workshop = require("systems.Workshop")
    local function make(id, day)
        local w = Workshop({ difficulty = id })
        w.day = day or 1
        return w
    end
    local apprentice = make("apprentice")
    check(apprentice:overheat_chance() == 0 and apprentice:overclock_wear_mult() == 1, "apprentice overclock adds no wear (x1)")
    apprentice:destroy()
    local broker = make("broker")
    check(near(broker:overheat_chance(), 0.035) and math.abs(broker:overclock_wear_mult() - 1.78) < 0.01,
        "broker overclock wear about x1.8")
    broker:destroy()
    local veteran = make("veteran", 45)
    check(near(veteran:overheat_chance(), 0.08) and veteran:season() == "summer" and veteran:overclock_wear_mult() > 2.7,
        "veteran summer: overheat risk 6% + 2% → wear about x2.8")
    veteran.day = 75
    local base = require("data.difficulties").modes.veteran.customer.honest_chance
    check(near(veteran:customer_rules().honest_chance, base * 0.7), "veteran autumn brings more forgers")
    veteran.day = 95
    local night, WINTER = veteran:night_modifiers({ hp_mult = 1.5, blood_moon = true }), require("data.calendar").seasons.winter
    check(near(night.hp_mult, 1.5 * WINTER.monster_hp_mult) and near(night.defense, WINTER.monster_defense) and night.blood_moon,
        "winter stacks with the blood moon")
    check(near(veteran:wave_day(120), 1 + 119 * require("data.difficulties").modes.veteran.pace) and veteran:wave_day(120) < 30,
        "long contracts grow the waves slowly (pace)")
    veteran:destroy()
    local abyss, OC = make("abyss", 40), require("data.durability").overclock
    local ABYSS, SUMMER = require("data.difficulties").modes.abyss, require("data.calendar").seasons.summer
    local summer, base = abyss:overheat_chance(), abyss.overclock_rules.overheat_chance
    local raw = 1 + summer * OC.per_risk
    check(abyss:season() == "summer" and near(summer, base + SUMMER.overheat_add * ABYSS.season_scale)
        and near(abyss:overclock_wear_mult(), raw) and raw < OC.max_mult and raw > 3.5,
        string.format("abyss summer: overheat risk %.3f (9%% + extreme summer) -> wear x%.4f, just under the cap x%.1f",
            summer, raw, OC.max_mult))
    abyss.overclock_rules.overheat_chance = 0.2                -- 상한: 위험 계수가 크면 정확히 max_mult 에서 멈춘다
    local capped, uncapped = abyss:overclock_wear_mult(), 1 + abyss:overheat_chance() * OC.per_risk
    abyss.overclock_rules.overheat_chance = base
    check(uncapped > OC.max_mult and capped == OC.max_mult, string.format("the overclock wear multiplier clamps at exactly x%.1f "
        .. "(unclamped x%.2f), got x%.4f", OC.max_mult, uncapped, capped))
    check(near(abyss:overclock_wear_mult(), raw), "restoring the overheat chance restores the summer multiplier")
    abyss.day = 1
    check(math.abs(abyss:overclock_wear_mult() - 3.0) < 0.01, "abyss spring overclock wear x3.0")
    abyss:destroy()
end

local function check_energy()
    local Workshop = require("systems.Workshop")
    local EventBus = require("core.EventBus")
    local Monster = require("entities.Monster")
    local broker, abyss = Workshop({ difficulty = "broker" }), Workshop({ difficulty = "abyss" })
    check(near(broker.appraisal:lens_drain_per_second(), 10.8) and near(abyss.appraisal:lens_drain_per_second(), 10.8 * 1.2),
        "UV drain is 1.8x (10.8%/s) and grows on harder contracts")
    check(near(broker.appraisal:water_per_point(), 0.36) and abyss.appraisal:water_per_point() > 0.36, "water use is 1.8x (3.6% per 10%)")
    local lows, probe = 0, {}
    EventBus.subscribe("supplies:low", function(p) lows = lows + (p.kind == "uv" and 1 or 0) end, { owner = probe })
    broker.supplies:spend("uv", 70)
    broker.supplies:spend("uv", 3)
    broker.supplies:spend("uv", 3)
    check(lows == 1, "crossing 25% warns exactly once")
    local gold = nil
    EventBus.subscribe("combat:monster_killed", function(p) gold = p.gold end, { owner = probe, priority = -300 })
    broker.combat:start(1)
    local slime = Monster("slime", 900, 400)
    broker.combat:_kill(slime)
    check(near(gold, slime.gold * require("data.balance").economy.kill_gold_mult), "night kill gold is scaled down (x0.45)")
    broker.combat:end_night()
    broker.phase, broker.night_damage, broker.day = "night", 0, 7
    check(broker:dawn_bonus() == 5 + 2 * 7, "flawless dawn bonus halved (5 + 2 x day)")
    EventBus.unsubscribe_owner(probe)
    broker:destroy()
    abyss:destroy()
end

-- 달력 HUD 세 줄(위: 베테랑 여름 낮 · 가운데: 새벽 정산 · 아래: 악몽 겨울 밤 과부하 / 견습)을 한 장에 그린다
local function check_render(shots)
    local Viewport = require("core.Viewport")
    local Workshop = require("systems.Workshop")
    local Hud = require("ui.Hud")
    local DawnSummary = require("ui.DawnSummary")
    local veteran, abyss, apprentice = Workshop({ difficulty = "veteran" }), Workshop({ difficulty = "abyss" }), Workshop({ difficulty = "apprentice" })
    veteran.day, veteran.gold = 45, 1280
    abyss.day, abyss.gold = 97, 18400
    apprentice.day = 9
    local hud = Hud()
    local summary = DawnSummary(veteran, hud)
    summary:_open()
    check(veteran:season() == "summer" and abyss:season() == "winter" and apprentice:season() == nil, "season ids for the HUD badge")
    local frosty = require("entities.Monster")("slime", 900, 400)
    frosty.defense = 0.12
    local shown = false
    for _, line in ipairs(require("ui.MonsterTooltip").traits(frosty)) do
        shown = shown or line == require("systems.I18n").t("monster_tip.trait_winter", { pct = 12 })
    end
    check(shown, "winter defense is listed in the monster tooltip")
    local canvas = love.graphics.newCanvas(Viewport.width(), Viewport.height())
    love.graphics.push("all")
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.clear(0.1, 0.09, 0.1, 1)
    hud:draw(veteran, 1)
    summary:draw()
    abyss.combat:start(abyss.day)
    abyss.phase = "night"
    abyss.combat:set_overclock(true)
    love.graphics.translate(0, 560)
    Hud():draw(abyss, 1)
    love.graphics.translate(0, 80)
    Hud():draw(apprentice, 1)
    love.graphics.setCanvas()
    love.graphics.pop()
    if shots then
        canvas:newImageData():encode("png", "smoke_calendar.png")
    end
    summary:destroy()
    abyss.combat:end_night()
    for _, w in ipairs({ veteran, abyss, apprentice }) do
        w:destroy()
    end
end

-- 계약서 카드의 요약 줄은 가장 작은 글자 크기에서도 한 줄 (ko · en). 배포 글꼴이 있을 때만 (없으면 대체 글꼴 폭이 다르다)
local function check_card_text()
    if love.filesystem.getInfo("assets/fonts/body.ttf") == nil then
        return
    end
    local I18n, Draw, ContractCards = require("systems.I18n"), require("ui.Draw"), require("ui.ContractCards")
    local font, width = Draw.font(require("data.ui").font_size.tiny), ContractCards.inner_width()
    for _, code in ipairs(I18n.languages()) do
        local texts = require("data.locales." .. code .. ".game").difficulty
        for _, id in ipairs(require("data.difficulties").order) do
            for _, line in ipairs(texts[id] and texts[id].summary or {}) do
                check(font:getWidth("· " .. line) <= width, code .. ": difficulty." .. id .. " summary overflows the card: " .. line)
            end
        end
    end
end

function SmokeContracts.run(log, shots)
    check_card_text()
    check_unlocks()
    check_calendar()
    check_risks()
    check_energy()
    check_render(shots)
    log("contracts ok (5 cards 3+2, abyss via veteran, ??? sealed; 10-day months, 4 seasons, boss cycle; "
        .. "overclock wear x1/x1.8/x2.8 summer/x3.0 abyss spring/x3.597 abyss summer just under the x3.6 clamp; "
        .. "UV 10.8%%/s, water 3.6%% per 10%%, low warning once; kill gold x0.45)")
end

return SmokeContracts
