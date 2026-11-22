-- tools/SmokeQuests.lua
-- 길드 의뢰 게시판 헤드리스 검사 (SmokeTest 가 SmokeGuild 다음에 실행) — 4분야 · 보상 · 위약금 · 이어하기:
--   1일차엔 없음 · 게시판 최대 3개 · [의뢰] 배지(길드 + 암시장) · 수락/거절
--   감정 적발: 손님 유물의 등급 위조·숨은 저주만 센다 (균열 X) → 골드·연마석
--   단조 납품: 조건(+강화 · 등급 — 브로커 희귀 +4) 미달이면 [납품] 불가 사유 → 맞는 유물을 넘기면 사라지고 다음 결계 유지비 -10%
--   정화 납품: 지정 속성 · 오염도 0% · 과부하 시험: 새벽에 그 밤 과부하 유지 시간 판정 · 보스 토벌: 보스 처치 + 긴급 수리
--   기한 초과: 위약금 즉시 차감, 모자란 몫은 다음 결계 유지비에 가산 · 미수락 제안은 밤에 내려감
--   이어하기(RunSave) 뒤에도 적발 구독이 그대로 동작 · [의뢰] 창 [납품] 클릭 · --shots 면 smoke_quests.png

local SmokeQuests = {}

local function check(condition, message)
    if not condition then
        error("SmokeQuests: " .. message, 2)
    end
end

local function emit(event, payload)
    require("core.EventBus").emit(event, payload)
end

local function find(w, id)
    for index, quest in ipairs(w.quests.board) do
        if quest.id == id then
            return quest, index
        end
    end
    return nil
end

local function check_board_and_expose(Workshop, Item)
    local w = Workshop({ difficulty = "broker" })
    check(w.quests:roll(1) == nil, "no guild quests on day 1")
    local expose = w.quests:post("expose_fraud", 3)
    check(expose.state == "pending" and expose.target == 3 and expose.deadline == 5 and expose.category == "appraisal",
        "broker sting: 3 exposures within 3 days")
    w.black_market:start_event("blood_moon")
    check(w.quests:pending_total() == 2 and w.black_market:decline() and w.quests:pending_total() == 1,
        "the badge counts guild quests and black market offers")
    local gold, stones = w.gold, w.tempering_stones
    check(w.quests:accept(1), "accept the sting")
    emit("appraisal:forgery_revealed", { item = Item("flame_sword", { claimed_grade = "rare" }), x = 0, y = 0 })
    emit("appraisal:flaw_revealed", { item = Item("cursed_dagger", { flaw = "curse" }), x = 0, y = 0 })
    emit("appraisal:flaw_revealed", { item = Item("flame_sword", { flaw = "crack" }), x = 0, y = 0 })
    local mine = Item("cursed_dagger", { flaw = "curse" })
    mine.owned = true
    emit("appraisal:flaw_revealed", { item = mine, x = 0, y = 0 })
    check(expose.progress == 2 and expose.state == "accepted", "only customer forgeries and hidden curses count (no cracks, no own relics)")
    emit("appraisal:forgery_revealed", { item = Item("storm_rod", { claimed_grade = "legendary" }), x = 0, y = 0 })
    check(expose.state == "done" and w.gold == gold + expose.reward.gold and w.tempering_stones == stones + expose.reward.stones,
        "the third exposure pays gold and stones")
    for _, id in ipairs({ "overclock_trial", "forge_delivery", "boss_hunt" }) do
        w.quests:post(id, 4)
    end
    check(w.quests:roll(4) == nil and #w.quests.board == 3, "the board holds at most 3 guild quests (finished ones are cleared)")
    w:destroy()
end

local function check_deliveries(Workshop, Item, ItemFactory)
    local w = Workshop({ difficulty = "broker" })
    local forge = w.quests:post("forge_delivery", 2)
    check(forge.level == 4 and forge.grade == "rare" and forge.reward.discount == 0.10, "broker forged delivery: rare +4 or better")
    check(w.quests:accept(1) and w.quests:delivery_block(forge) == "quest_ui.deliver_missing", "nothing to deliver yet")
    w.inventory:place(ItemFactory.make_ready("flame_sword", "rare", 3), "storage", 1)
    w.inventory:place(ItemFactory.make_ready("frost_crossbow", "legendary", 6), "grid", 13)
    check(w.quests:delivery_block(forge) == "quest_ui.deliver_missing", "+3 relics and display-case relics do not count")
    local good = ItemFactory.make_ready("storm_rod", "legendary", 4)
    w.inventory:place(good, "storage", 2)
    local before = w.tribute:amount_for(10)
    check(w.quests:deliver(1) and w.inventory:locate(good) == nil and forge.state == "done", "[Deliver] hands over the forged relic")
    check(w.tribute:amount_for(10) == before - math.floor(w.tribute:base_for(10) * 0.10 + 0.5), "reward: next upkeep -10%")

    local purify = w.quests:post("purify_delivery", 2, { element = "frost" })
    w.quests:accept(2)
    local dirty = Item("frost_crossbow", { contamination = 40 })
    dirty.owned = true
    w.inventory:place(dirty, "bench", 1)
    w.inventory:place(ItemFactory.make_ready("flame_sword", "common", 0), "storage", 3)
    check(w.quests:delivery_block(purify) == "quest_ui.deliver_missing", "grimy or wrong-element relics do not count")
    dirty.contamination, dirty.cleaned = 0, true
    check(w.quests:deliver(2) and purify.state == "done" and w.inventory:get("bench", 1) == nil, "a scrubbed frost relic is delivered")
    w:destroy()
end

local function check_combat_quests(Workshop, Monster)
    local w = Workshop({ difficulty = "veteran" })
    local trial = w.quests:post("overclock_trial", 2)
    check(trial.target == 18 and trial.reward.stones == 2, "veteran overclock trial: 18 s")
    w.quests:accept(1)
    w.combat.overclock_time = 12
    w.quests:settle_night()
    check(trial.state == "accepted" and trial.progress == 12, "12 s is not enough — try again tomorrow night")
    w.combat.overclock_time = 18.5
    w.quests:settle_night()
    check(trial.state == "done", "holding the lever long enough clears the trial at dawn")
    w.day = 9
    local hunt = w.quests:post("boss_hunt", 9)
    check(hunt.deadline == 10, "the boss hunt is due on the month-end boss night")
    w.quests:accept(#w.quests.board)
    w:damage_hp(40, "test")
    local hp = w.hp
    emit("combat:monster_killed", { monster = Monster("slime", 0, 0), gold = 0, x = 0, y = 0 })
    check(hunt.state == "accepted", "ordinary kills do not count")
    emit("combat:monster_killed", { monster = Monster("gatekeeper_golem", 0, 0), gold = 0, x = 0, y = 0 })
    check(hunt.state == "done" and w.hp > hp, "felling the boss pays out and repairs the wall")
    w:destroy()
end

local function check_penalty_and_expiry(Workshop)
    local w = Workshop({ difficulty = "broker" })
    local quest = w.quests:post("expose_fraud", 3)
    w.quests:accept(1)
    w.day, w.gold = quest.deadline, 10
    local before = w.tribute:amount_for(10)
    w.quests:settle_night()
    check(quest.state == "failed" and w.gold == 0 and quest.paid == 10, "overdue: the fine is paid at once")
    check(w.tribute:amount_for(10) == before + quest.penalty - 10, "the unpaid fine is added to the next upkeep")
    w.day = 6
    w.quests:roll(6)
    for _, posted in ipairs(w.quests.board) do
        check(posted ~= quest, "finished quests leave the board in the morning")
    end
    w.quests:post("purify_delivery", 6)
    w.black_market:start_event("fence_request")
    check(w:start_night() and #w.quests.board == 0 and w.black_market.event == nil, "unanswered offers expire at nightfall")
    w:destroy()
end

local function check_resume(Workshop, Item)
    local RunSave = require("systems.RunSave")
    local w = Workshop({ difficulty = "broker" })
    w.quests:post("expose_fraud", 3)
    w.quests:accept(1)
    local data = RunSave.deserialize(RunSave.serialize(RunSave.snapshot(w)))
    w:destroy()
    local resumed = RunSave.resume(data, Workshop)
    emit("appraisal:forgery_revealed", { item = Item("flame_sword", { claimed_grade = "rare" }), x = 0, y = 0 })
    check(resumed.quests.board[1].state == "accepted" and resumed.quests.board[1].progress == 1,
        "accepted quests keep counting after [Continue]")
    resumed:destroy()
end

local function check_modal(Workshop, ItemFactory, shots)
    local Viewport = require("core.Viewport")
    local QuestModal = require("ui.QuestModal")
    local w = Workshop({ difficulty = "veteran" })
    w.day = 13
    w.black_market:start_event("mystery_boxes")
    w.quests:post("forge_delivery", 12)
    w.quests:accept(1)
    w.quests:post("purify_delivery", 13, { element = "fire" })
    w.quests:post("boss_hunt", 13)
    w.inventory:place(ItemFactory.make_ready("flame_sword", "rare", 5), "storage", 1)       -- 베테랑 단조 납품: +5 이상
    local modal = QuestModal.open(w)
    modal:update(1, 0, 0)
    check(modal:selected().source == "market", "pending offers are selected first")
    local r = QuestModal.card_rect(2)
    modal:mousepressed(r.x + 20, r.y + 20)
    modal:update(0.1, 0, 0)
    check(modal:selected().id == "forge_delivery", "clicking a card selects that quest")
    local canvas = love.graphics.newCanvas(Viewport.width(), Viewport.height())
    love.graphics.push("all")
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.clear(0.06, 0.05, 0.06, 1)
    modal:draw()
    love.graphics.setCanvas()
    love.graphics.pop()
    if shots then
        canvas:newImageData():encode("png", "smoke_quests.png")
    end
    r = QuestModal.deliver_rect()
    modal:mousepressed(r.x + r.w / 2, r.y + r.h / 2)
    check(find(w, "forge_delivery").state == "done" and w.inventory:get("storage", 1) == nil, "[Deliver] in the quest board")
    w:destroy()
end

function SmokeQuests.run(log, shots)
    local Workshop = require("systems.Workshop")
    local Item = require("entities.Item")
    local ItemFactory = require("systems.ItemFactory")
    require("core.RNG").set_seed(5151)
    check_board_and_expose(Workshop, Item)
    check_deliveries(Workshop, Item, ItemFactory)
    check_combat_quests(Workshop, require("entities.Monster"))
    check_penalty_and_expiry(Workshop)
    check_resume(Workshop, Item)
    check_modal(Workshop, ItemFactory, shots)
    log("quests ok (board cap 3, sting counts forgeries/curses, forged & purified deliveries, overclock trial at dawn, "
        .. "boss hunt + repair, fine + upkeep surcharge, expiry, resume-safe, [Deliver] click)")
end

return SmokeQuests
