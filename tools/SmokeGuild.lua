-- tools/SmokeGuild.lua
-- 헤드리스 검사 (SmokeTest 가 SmokeEconomy 다음에 실행): 길드 · 의뢰 · 모험가 · 연마석.
--   모험가 6인: 방문 분포 · 성향(카인 저주 · 리나 오염 · 세드릭 위조 · 토린 화염 선호 · 흥정 = 제시가 배율)
--   연마석: 시작 보유 · 보스 확정 · 드랍률(처치마다 새 밤: 엘리트 3000회 elite_chance ±40% · 일반 20000회 drop_chance x0.5~x1.6)
--           · 한 밤 무작위 드랍 상한(stones.night_cap) — 보스 확정분과 중간 보스 보상(midboss.reward.stones)은 상한을 넘긴 뒤에도
--           · 길드 상점 하루 daily_limit(1)개 → 아침 초기화
--   용광로 +10 비용: +1 골드만 / +2 부터 골드 + 연마석 (부족하면 시작 불가 · 사유 키) · 시작할 때 비용 차감
--   길드 의뢰 게시판은 tools/SmokeQuests
--   암시장 제안: [의뢰] 배지 수(길드 + 암시장) · 거절 시 상인 떠남 · 미수락 밤에 사라짐
--   UI: [길드] 창 연마석 구매 클릭 · [의뢰] 창 수락 클릭 · 손님 카운터 모험가 프로필 · 모험가 초상 6종(원화 또는 두건 폴백)
--       · HUD 연마석 · 배지 오프스크린 렌더

local SmokeGuild = {}

local ELITE_KILLS = 3000        -- 엘리트 드랍률 표본 (작성 시점 4% → 평균 120개, ±40% ≈ ±4.5σ)
local NORMAL_KILLS = 20000      -- 일반 드랍률 표본 (작성 시점 0.3% → 평균 60개, x0.5 ≈ -3.9σ · x1.6 ≈ +4.6σ)

local function check(condition, message)
    if not condition then
        error("SmokeGuild: " .. message, 2)
    end
end

local function new_workshop(difficulty)
    return require("systems.Workshop")({ difficulty = difficulty or "broker" })
end

local function check_adventurers()
    local RNG = require("core.RNG")
    local ItemFactory = require("systems.ItemFactory")
    local ADVENTURERS = require("data.adventurers")
    local I18n = require("systems.I18n")
    check(#ADVENTURERS.order == 6, "six unique adventurers")
    local rng, seen = RNG.stream("smoke_adventurers"), {}
    for _ = 1, 600 do
        local id = ItemFactory.pick_adventurer(rng, nil)
        seen[id] = (seen[id] or 0) + 1
    end
    for _, id in ipairs(ADVENTURERS.order) do
        check((seen[id] or 0) > 50, id .. " visits regularly")
        check(I18n.t("adventurers." .. id .. ".name") ~= "adventurers." .. id .. ".name", id .. " has a name")
    end
    local function sample(id, count, test)
        local hits = 0
        for _ = 1, count do
            local item = ItemFactory.customer_item(rng, 10, nil, nil, id)
            check(item.adventurer == id and item.ask_mult == ADVENTURERS.list[id].haggle, "items remember their adventurer")
            hits = hits + (test(item) and 1 or 0)
        end
        return hits
    end
    local function cursed(item) return item.flaw == "curse" end
    check(sample("kain", 300, cursed) > sample("bern", 300, cursed) * 2, "Kain carries far more cursed relics than Bern")
    check(sample("rina", 100, function(item) return item.contamination >= 60 end) == 100, "Rina's relics are filthy (60%+)")
    local function inflated(item) return item:claimed_grade_info().rank > item:grade_info().rank end
    check(sample("cedric", 300, inflated) > sample("thorin", 300, inflated) * 2, "Cedric inflates grades far more than Thorin")
    local function fire(item) return item.proto.archetype == "fire" end
    local thorin_fire, ellen_fire = sample("thorin", 600, fire), sample("ellen", 600, fire)
    check(thorin_fire > ellen_fire * 2, string.format("Thorin prefers fire relics (%d vs %d)", thorin_fire, ellen_fire))
    local Item = require("entities.Item")
    local plain, pricey = Item("flame_sword", { grade = "rare" }), Item("flame_sword", { grade = "rare", ask_mult = 1.3 })
    check(pricey:asking_price() > plain:asking_price(), "haggling raises the asking price")
end

local function check_stones_and_forge()
    local EventBus = require("core.EventBus")
    local Monster = require("entities.Monster")
    local ItemFactory = require("systems.ItemFactory")
    local BALANCE = require("data.balance")
    local w = new_workshop()
    check(w.tempering_stones == BALANCE.stones.start, "runs start with the base stone count")
    EventBus.emit("combat:monster_killed", { monster = Monster("gatekeeper_golem", 0, 0), gold = 0, x = 0, y = 0 })
    check(w.tempering_stones == BALANCE.stones.start + BALANCE.stones.boss_drop, "bosses always drop tempering stones")
    local function night()                -- 새 밤: 무작위 연마석 드랍 상한(stones.night_cap)이 초기화된다
        EventBus.emit("phase:night_started", { workshop = w, day = w.day })
    end
    local function rate(id, kills)        -- 처치마다 새 밤으로 쳐서 드랍 확률만 잰다
        local before = w.tempering_stones
        for _ = 1, kills do
            night()
            EventBus.emit("combat:monster_killed", { monster = Monster(id, 0, 0), gold = 0, x = 0, y = 0 })
        end
        return (w.tempering_stones - before) / kills
    end
    local STONES, MONSTERS = BALANCE.stones, require("data.enemies").monsters
    check(MONSTERS.ogre.elite and not MONSTERS.slime.elite and not MONSTERS.slime.boss and not MONSTERS.slime.midboss,
        "precondition: ogres are elite, slimes are plain monsters")
    local elite, normal = rate("ogre", ELITE_KILLS), rate("slime", NORMAL_KILLS)
    check(math.abs(elite - STONES.elite_chance) <= STONES.elite_chance * 0.4, string.format(
        "elites drop stones at %.2f%% (+-40%%), got %.2f%% over %d kills", STONES.elite_chance * 100, elite * 100, ELITE_KILLS))
    check(normal > STONES.drop_chance * 0.5 and normal < STONES.drop_chance * 1.6, string.format(
        "normal monsters drop stones at %.2f%% (x0.5~x1.6), got %.3f%% over %d kills", STONES.drop_chance * 100, normal * 100, NORMAL_KILLS))
    night()
    local before_night = w.tempering_stones
    for _ = 1, 400 do
        EventBus.emit("combat:monster_killed", { monster = Monster("ogre", 0, 0), gold = 0, x = 0, y = 0 })
    end
    check(w.tempering_stones - before_night == STONES.night_cap, "random stone drops stop at the nightly cap")
    EventBus.emit("combat:monster_killed", { monster = Monster("gatekeeper_golem", 0, 0), gold = 0, x = 0, y = 0 })
    check(w.tempering_stones - before_night == STONES.night_cap + STONES.boss_drop, "boss stones ignore the cap")
    -- 중간 보스 확정 보상(data/waves.lua 의 midboss.reward)도 상한과 무관하다 (상한이 막는 건 무작위 드랍뿐)
    local REWARD = require("data.waves").midboss.reward
    local vanguard, stones, gold = Monster("mid_vanguard", 0, 0), w.tempering_stones, w.gold
    check(vanguard:is_midboss() and not vanguard:is_boss() and REWARD.stones > 0, "precondition: the vanguard is a mid-boss with a stone reward")
    EventBus.emit("combat:monster_killed", { monster = vanguard, gold = 0, x = 0, y = 0 })
    local bonus = REWARD.gold + REWARD.gold_per_month * (require("systems.Calendar").month(w.day) - 1)
    check(w.tempering_stones - stones == REWARD.stones and w.gold - gold == bonus, string.format("a mid-boss still pays %d stone(s) "
        .. "and %d G after the nightly cap, got %d stone(s) and %d G", REWARD.stones, bonus, w.tempering_stones - stones, w.gold - gold))
    -- 길드 상점: 하루 daily_limit 개 한정, 아침에 초기화
    local LIMIT = require("data.shop").offers.tempering_stone.daily_limit
    w.gold, w.tempering_stones = 1000, 0
    for _ = 1, LIMIT do
        check(w.shop:buy("tempering_stone"), "a stone within the daily limit can be bought")
    end
    check(w.tempering_stones == LIMIT, "bought the daily limit of stones")
    local ok, reason = w.shop:availability("tempering_stone")
    check(not ok and reason ~= nil and not w.shop:buy("tempering_stone"), "one more stone is over the daily limit")
    w.shop:new_day()
    check(w.shop:remaining("tempering_stone") == LIMIT, "the daily limit resets in the morning")
    -- 용광로 +10 체계 비용: +1 골드만 · +2 부터 골드 + 연마석 (data/forge.lua) — 시작할 때 둘 다 낸다
    local FORGE = require("data.forge")
    local item = ItemFactory.make_ready("flame_sword", "common", 0)
    w.inventory:place(item, "furnace", 1)
    local gold = w.gold
    local g1, s1 = w.forge:cost(item)
    check(g1 == FORGE.levels[1].gold and s1 == 0 and w.forge:start() and w.gold == gold - g1, "+1 costs only gold")
    w.forge.forging = nil
    item.level, w.tempering_stones = 1, 0
    check(w.forge:is_risky(item) and not w.forge:can_forge(), "+2 needs a tempering stone")
    check(w.forge:cost_block(item) == "disabled.forge_no_stones", "missing stones give a reason")
    w.gold, w.tempering_stones = 1000, 3
    check(w.forge:start() and w.tempering_stones == 2 and w.gold == 1000 - FORGE.levels[2].gold, "+2 spends gold and one stone")
    w.forge.forging = nil
    item.level = 9
    local g10, s10 = w.forge:cost(item)
    check(g10 == FORGE.levels[10].gold and s10 == 6 and w.forge:cost_block(item) == "disabled.forge_no_stones", "+10 costs six stones")
    w:destroy()
end

local function check_ui()
    local Viewport = require("core.Viewport")
    local Item = require("entities.Item")
    local GuildModal = require("ui.GuildModal")
    local QuestModal = require("ui.QuestModal")
    local CustomerCard = require("ui.CustomerCard")
    local Hud = require("ui.Hud")
    local WorkshopInput = require("ui.WorkshopInput")
    local w = new_workshop()
    w.gold = 900
    local canvas = love.graphics.newCanvas(Viewport.width(), Viewport.height())
    love.graphics.push("all")
    love.graphics.setCanvas({ canvas, stencil = true })
    local guild = GuildModal.open(w)
    guild:update(1, 0, 0)
    local index = 0
    for i, id in ipairs(require("data.shop").day_offers) do
        index = id == "tempering_stone" and i or index
    end
    local r = GuildModal.buy_rect(index)
    guild:mousepressed(r.x + r.w / 2, r.y + r.h / 2)
    check(w.tempering_stones == 1, "the guild window sells tempering stones")
    guild:draw()
    w.quests:post("expose_fraud", 3)
    w.black_market:start_event("mystery_boxes")
    local quests = QuestModal.open(w)
    quests:update(1, 0, 0)
    check(quests:selected().source == "market", "pending black market offers are listed first")
    r = QuestModal.accept_rect()
    quests:mousepressed(r.x + r.w / 2, r.y + r.h / 2)
    check(w.black_market.accepted, "[Accept] accepts the selected offer")
    quests:update(0.1, 0, 0)
    quests:draw()
    r = QuestModal.card_rect(2)
    quests:mousepressed(r.x + 10, r.y + 10)
    quests:update(0.1, 0, 0)
    check(quests:selected().source == "guild", "clicking a card selects that quest")
    quests:draw()
    local item = Item("cursed_dagger", { grade = "rare", claimed_grade = "legendary", adventurer = "kain", ask_mult = 0.95 })
    w.appraisal:present_customer(item, false)
    check(CustomerCard.display_name("kain") ~= "" and CustomerCard.line(w, item):find(require("systems.I18n").item_name(item), 1, true),
        "the counter names the adventurer and quotes their line")
    CustomerCard.draw(w, 1, nil)
    local AdventurerPortrait = require("ui.AdventurerPortrait")
    local card = require("data.layout").day.customer_card
    for _, id in ipairs(require("data.adventurers").order) do      -- 6인 초상: 원화(breathe_soft 메시·뒤집기) 또는 두건 폴백
        local guest = Item("rune_tablet", { adventurer = id })
        AdventurerPortrait.draw(card, guest, 1)
        AdventurerPortrait.draw(card, guest, 2)
        check(AdventurerPortrait.has_art(id) == (require("ui.SpriteBank").image("adventurer_" .. id) ~= nil),
            id .. " portrait uses its art only when the file exists")
    end
    local input = WorkshopInput(w, function() end)
    check(input:button("quests")._opts.badge() == w.quests:pending_total(), "the [Quests] badge shows pending offers")
    for _, button in ipairs(input.buttons) do
        button:draw()
    end
    Hud():draw(w, 1)
    love.graphics.setCanvas()
    love.graphics.pop()
    input:destroy()
    w:destroy()
end

-- 모험가 6인 초상 검수: 원 꼭대기가 그림의 첫 불투명 줄(머리 꼭대기)보다 위인지(잘림 0) + --shots 면 6인 견본 smoke_portraits.png
local function check_portraits(shots)
    local ART = require("data.art")
    local Item = require("entities.Item")
    local AdventurerPortrait = require("ui.AdventurerPortrait")
    local canvas = love.graphics.newCanvas(6 * 120, 130)
    love.graphics.push("all")
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.clear(0.12, 0.1, 0.12, 1)
    love.graphics.origin()
    for i, id in ipairs(require("data.adventurers").order) do
        local path = "assets/sprites/adventurer_" .. id .. ".png"
        if love.filesystem.getInfo(path) ~= nil then
            local data, top = love.image.newImageData(path), nil
            for y = 0, data:getHeight() - 1 do
                for x = 0, data:getWidth() - 1, 2 do
                    if top == nil and select(4, data:getPixel(x, y)) > 0.3 then
                        top = y / data:getHeight()
                    end
                end
            end
            check(ART.adventurers[id].region.y <= top, id .. " portrait circle must start above the top of the head")
        end
        local guest = Item("rune_tablet", { adventurer = id })
        local card = { guest_x = 60 + (i - 1) * 120, guest_r = 50, y = 10, h = 110 }
        AdventurerPortrait.draw(card, guest, 0)
        AdventurerPortrait.draw(card, guest, 3)
    end
    love.graphics.pop()
    if shots then
        canvas:newImageData():encode("png", "smoke_portraits.png")
    end
end

function SmokeGuild.run(log, shots)
    check_portraits(shots)
    require("core.RNG").set_seed(4242)
    check_adventurers()
    check_stones_and_forge()
    check_ui()
    log("guild ok (6 adventurers & traits, stones: elite/normal drop rates, nightly cap, boss & mid-boss rewards past the cap, "
        .. "shop daily limit, forge costs, market accept/decline, "
        .. "[Guild]/[Quests] windows, counter profile, HUD badge)")
end

return SmokeGuild
