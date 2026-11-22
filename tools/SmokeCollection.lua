-- tools/SmokeCollection.lua
-- 헤드리스 검사 (SmokeTest 가 SmokeBosses 다음에 실행): 특수 유물·업적·엔딩·도감.
--   특수 유물은 해금 전에는 손님·상점에 절대 나오지 않고, 해금 후에는 나온다
--   업적 8종 중 대표 판정 (용광로 +7 · 고정 골드 문턱(Achievements.gold_line) · 핏빛 달 · 저주 4개 보스 · 골렘) → 런 해금 목록에 즉시
--   엔딩 판정 (data/endings.lua 의 수치를 읽는다): 상권 독점 기준 = 공식 · 난이도 계단, 기준 - 1 G · 방벽 미달 → 무사 이주,
--     +master_level 보유 유물 → 기준 x master_mult, 심연 장악 = 악몽 계약 + 저주 유물 cursed 개 · share 이상
--   도감 엔딩 카드 문구(조건 · 숨은 결말 · 봉인 안내 · 훈장, ko/en)가 두 줄 안 · 자리표시자가 모두 채워지는지 · save_meta.lua 왕복
--   유물 도감 모달 · 엔딩 장면 5종을 오프스크린으로 그리고 클릭·ESC 처리 (일러스트는 있을 때만, 없는 엔딩은 대체 그림 / 코드 연출)
-- 끝나면 메타 진행도를 첫 실행 상태로 되돌린다 (시나리오가 결정론적으로 돌도록). 캠페인 화면은 tools/SmokeTraceScreens.

local SmokeCollection = {}

local SAMPLES = 400
local CURSED_CELLS = { 7, 8, 9, 12 }      -- 시작 개방 칸(중앙 3x3) 중 4칸
local SCALED_CONTRACTS = { "apprentice", "broker", "veteran", "abyss" }     -- 난이도 순서 (상권 독점 기준 계단)

local function check(condition, message)
    if not condition then
        error("SmokeCollection: " .. message, 2)
    end
end

local function contract(difficulty)
    local Workshop = require("systems.Workshop")
    local MetaProgression = require("systems.MetaProgression")
    return Workshop({ difficulty = difficulty, meta = MetaProgression.bonuses() })
end

local function count_specials(unlocked)
    local RNG = require("core.RNG")
    local ItemFactory = require("systems.ItemFactory")
    local rng = RNG.stream("customers")
    local count = 0
    for _ = 1, SAMPLES do
        local item = ItemFactory.customer_item(rng, 12, nil, unlocked)
        local ready = ItemFactory.ready_item(rng, "rare", 0, unlocked)
        count = count + (item.proto.special and 1 or 0) + (ready.proto.special and 1 or 0)
    end
    return count
end

local function check_unlock_filter()
    local ITEMS = require("data.items")
    local ItemFactory = require("systems.ItemFactory")
    check(#ItemFactory.base_ids() == 24 and #ItemFactory.prototype_ids() == 32, "24 base + 8 special prototypes")
    check(count_specials(nil) == 0, "special relics must never appear before they are unlocked")
    local all = {}
    for id, proto in pairs(ITEMS.prototypes) do
        if proto.special then
            all[id] = true
        end
    end
    check(count_specials(all) > 0, "unlocked special relics should appear")
end

local function boss(type_id)
    local Monster = require("entities.Monster")
    local monster = Monster(type_id, 900, 180)
    assert(monster:is_boss(), "SmokeCollection: " .. type_id .. " should be a boss")
    return monster
end

-- 골드 업적: 데이터 문턱(Achievements.gold_line — 고정 금액 또는 상권 독점 기준 비례)에서 정확히 열린다
local function check_tycoon(w)
    local MetaProgression = require("systems.MetaProgression")
    local line = require("systems.Achievements").gold_line("tycoon", w)
    check(line > w.gold + 1, "the tycoon line is above the starting gold")
    w:add_gold(line - 1 - w.gold, "smoke")
    check(not MetaProgression.has_achievement("tycoon"), "1 G short of the tycoon line keeps the ledger sealed")
    w:add_gold(1, "smoke")
    check(MetaProgression.has_achievement("tycoon") and w.unlocked_relics.tycoon_ledger,
        "holding the tycoon line (" .. line .. " G) unlocks the ledger")
end

local function check_achievements()
    local EventBus = require("core.EventBus")
    local Item = require("entities.Item")
    local MetaProgression = require("systems.MetaProgression")
    MetaProgression.use_memory_only()
    local w = contract("broker")
    check(next(w.unlocked_relics) == nil, "fresh profile has no special relics")
    EventBus.emit("forge:succeeded", { item = Item("flame_sword", {}), level = 6, x = 0, y = 0 })
    check(not MetaProgression.has_achievement("forge_master"), "+6 is not enough for the forge achievement")
    EventBus.emit("forge:succeeded", { item = Item("flame_sword", {}), level = 7, x = 0, y = 0 })
    check(MetaProgression.has_achievement("forge_master") and w.unlocked_relics.starforge_hammer, "+7 forge unlocks the hammer")
    check_tycoon(w)
    EventBus.emit("blackmarket:blood_moon_cleared", { discount = 250, due = 0 })
    check(MetaProgression.has_achievement("blood_moon"), "surviving the blood moon unlocks the chalice")
    for _, index in ipairs(CURSED_CELLS) do
        local item = Item("cursed_dagger", { grade = "rare", contamination = 0 })
        item.owned = true
        w.inventory:place(item, "grid", index)
    end
    w.day = w.max_days
    EventBus.emit("combat:monster_killed", { monster = boss("gatekeeper_golem"), gold = 0, x = 0, y = 0 })
    check(MetaProgression.has_achievement("cursed_quartet") and MetaProgression.has_achievement("golem_slayer"),
        "boss kill with 4 cursed relics unlocks the crown and the golem heart")
    local cursed, shown = require("systems.Achievements").cursed_on_grid(w)
    check(w.stats.final_boss_cursed == 4 and cursed == 4 and shown >= 4 and w.stats.final_boss_share == cursed / shown,
        "final-day boss kill records the cursed count and the cursed share of the display")
    check(not MetaProgression.has_achievement("rift_slayer"), "other boss achievements stay locked")
    w:destroy()
    local fresh = contract("broker")
    check(fresh.unlocked_relics.abyss_crown and fresh.unlocked_relics.golem_heart, "next run starts with the unlocked relics")
    fresh:destroy()
end

-- 상권 독점 기준: 공식 그대로(난이도 경제 규모 scale 포함)이고, 기준 금액은 난이도 순서대로 계단 (scale 전 기준은 계약이 길수록 크다)
local function check_monopoly_scale()
    local Endings, M = require("systems.Endings"), require("data.endings").monopoly
    local lines, bases = {}, {}
    for _, id in ipairs(SCALED_CONTRACTS) do
        local w = contract(id)
        local upkeep = w.tribute:base_for(w.max_days)
        check(upkeep ~= nil and upkeep > 0, id .. ": the last contract day collects the ward upkeep")
        local base = M.per_day * w.max_days + M.upkeep_mult * upkeep          -- 난이도 경제 규모를 곱하기 전
        local expected = math.floor(base * (M.scale and M.scale[id] or 1) / M.round + 0.5) * M.round
        lines[#lines + 1], bases[#bases + 1] = Endings.monopoly_gold(w), base
        check(lines[#lines] == expected, string.format("%s: monopoly line %s should be %d", id, tostring(lines[#lines]), expected))
        w:destroy()
    end
    check(bases[1] < bases[2] and bases[2] < bases[3] and lines[1] < lines[2] and lines[2] < lines[3] and lines[3] < lines[4],
        "monopoly lines form a staircase in difficulty order: " .. table.concat(lines, " < "))
end

-- 상권 독점: 골드와 방벽 기준을 모두 넘어야 하고, +master_level 보유 유물이 있으면 기준이 내려간다
local function check_monopoly_gate()
    local Item = require("entities.Item")
    local Endings = require("systems.Endings")
    local M = require("data.endings").monopoly
    local w = contract("broker")
    local plain = Endings.status(w)
    check(plain.need == plain.base_need and not plain.master and plain.best_level == 0, "no master relic: the full line applies")
    w.gold, w.hp = plain.need - 1, w.max_hp
    check(Endings.decide(w) == "relocation", "1 G short of the monopoly line is the relocation ending")
    w.gold = plain.need
    check(Endings.decide(w) == "monopoly", "the monopoly line with a full wall is the monopoly ending")
    local gate = math.ceil(w.max_hp * M.min_hp_ratio)
    w.hp = gate - 1
    check(Endings.status(w).hp_ratio < M.min_hp_ratio and Endings.decide(w) == "relocation", "a rich run below the wall gate relocates")
    w.hp = gate
    check(Endings.decide(w) == "monopoly", "the wall exactly at the gate keeps the monopoly ending")

    local guest = Item("flame_sword", { grade = "rare" })
    guest.level = M.master_level                   -- 손님 유물(owned = false)은 보유 유물이 아니다
    w.inventory:place(guest, "bench", 1)
    check(not Endings.status(w).master, "a customer's relic does not count as the master relic")
    w.inventory:remove(guest)
    local relic = Item("flame_sword", { grade = "rare" })
    relic.owned, relic.level = true, M.master_level - 1
    w.inventory:place(relic, "storage", 1)
    check(not Endings.status(w).master, "+" .. (M.master_level - 1) .. " is not the master relic")
    relic.level = M.master_level
    local master = Endings.status(w)
    local expected = math.floor(plain.base_need * M.master_mult / M.round + 0.5) * M.round
    check(master.master and master.best_level == M.master_level and master.need == expected and master.need < plain.need,
        "a +" .. M.master_level .. " relic lowers the line to " .. expected)
    w.gold = master.need - 1
    check(Endings.decide(w) == "relocation", "1 G short of the master line is the relocation ending")
    w.gold = master.need
    check(Endings.decide(w) == "monopoly", "the master line is enough for the monopoly ending")
    w.stats.final_boss_cursed, w.stats.final_boss_share = 99, 1
    check(Endings.decide(w) == "monopoly", "abyss ending needs the abyss contract")
    w:destroy()
end

-- 심연 장악: 악몽 계약 + 최종일 보스 처치 때 진열장의 share 이상(최소 cursed 개)이 저주 유물
local function check_abyss()
    local Endings = require("systems.Endings")
    local A = require("data.endings").abyss
    local w = contract(A.difficulty)
    w.gold = 0
    w.stats.final_boss_cursed, w.stats.final_boss_share = A.cursed - 1, 1
    check(Endings.decide(w) == "relocation", (A.cursed - 1) .. " cursed relics at the final boss is not the abyss ending")
    w.stats.final_boss_cursed, w.stats.final_boss_share = A.cursed + 12, A.share - 0.01
    check(Endings.decide(w) == "relocation", "a display less than " .. A.share * 100 .. "% cursed is not the abyss ending")
    w.stats.final_boss_share = A.share
    check(Endings.decide(w) == "abyss", "abyss contract + a " .. A.share * 100 .. "% cursed display at the final boss is the abyss ending")
    w:destroy()
end

-- 도감 엔딩 카드 문구(조건 값 채운 뒤 · 숨은 결말 · 봉인 안내 · 훈장)가 카드 안에서 두 줄을 넘지 않는지 — ko · en, 다섯 엔딩 모두
local function check_condition_fit()
    local Draw, Text = require("ui.Draw"), require("lib.text")
    local I18n, Endings = require("systems.I18n"), require("systems.Endings")
    local width = require("ui.CompendiumEndings").text_width()
    local font = Draw.font(require("data.ui").font_size.tiny)
    for _, code in ipairs(I18n.languages()) do
        local texts = require("data.locales." .. code .. ".collection")
        local c = texts.compendium
        local cards = { hidden_condition = c.hidden_condition, campaign_locked = c.campaign_locked, medal_earned = c.medal_earned,
            medal_locked = c.medal_locked }
        for _, id in ipairs(require("data.endings").order) do
            cards["ending." .. id .. ".condition"] = Text.fill(texts.ending[id].condition, Endings.condition_vars())
        end
        for key, text in pairs(cards) do
            local _, lines = font:getWrap(text, width)
            check(#lines <= 2, code .. ": " .. key .. " wraps to " .. #lines .. " lines in a compendium card: " .. text)
        end
    end
end

-- 조건 문구의 자리표시자가 모든 언어에서 남김없이 채워지는지 (lib/text 는 모르는 {x} 를 그대로 남긴다)
local function check_placeholders()
    local Text, I18n = require("lib.text"), require("systems.I18n")
    local Endings, Achievements = require("systems.Endings"), require("systems.Achievements")
    local ACHIEVEMENTS, ENDINGS = require("data.achievements"), require("data.endings")
    for _, code in ipairs(I18n.languages()) do
        local texts = require("data.locales." .. code .. ".collection")
        local function filled(template, vars, label)
            local text = Text.fill(template, vars)
            check(not text:find("{", 1, true), code .. ": unfilled placeholder in " .. label .. ": " .. text)
        end
        for _, id in ipairs(ENDINGS.order) do
            filled(texts.ending[id].condition, Endings.condition_vars(), "ending." .. id .. ".condition")
        end
        for _, id in ipairs(ACHIEVEMENTS.order) do
            filled(texts.achievements[id].condition, Achievements.condition_vars(id), "achievements." .. id .. ".condition")
        end
        filled(texts.compendium.ending_target, { gold = 1, hp = 1 }, "compendium.ending_target")
        filled(texts.compendium.campaign_target, { lit = 1, slots = 4, journals = 1, total = 6 }, "compendium.campaign_target")
    end
end

local function check_endings()
    local MetaProgression = require("systems.MetaProgression")
    check_monopoly_scale()
    check_monopoly_gate()
    check_abyss()
    check_condition_fit()
    check_placeholders()
    check(MetaProgression.record_ending("monopoly") and not MetaProgression.record_ending("monopoly"), "endings record once")

    local path = "smoke_meta_roundtrip.lua"
    local data = { rp = 7, levels = {}, achievements = { tycoon = true, rift_slayer = true }, endings = { abyss = true } }
    assert(love.filesystem.write(path, MetaProgression.serialize(data)))
    local back = MetaProgression.read_file(path)
    love.filesystem.remove(path)
    check(back.rp == 7 and back.achievements.tycoon and back.achievements.rift_slayer and not back.achievements.blood_moon
        and back.endings.abyss and not back.endings.monopoly, "save_meta.lua round trip keeps achievements and endings")
end

local function draw_frames(modal, frames, x, y)
    for _ = 1, frames do
        modal:update(0.2, x, y)
        modal:draw()
    end
end

local function check_views(missing_assets)
    local Viewport, CompendiumModal = require("core.Viewport"), require("ui.CompendiumModal")
    local Effects, EndingScenes = require("ui.Effects"), require("ui.EndingScenes")
    local Endings, ENDINGS = require("systems.Endings"), require("data.endings")
    local canvas = love.graphics.newCanvas(Viewport.width(), Viewport.height())
    love.graphics.push("all")
    love.graphics.setCanvas({ canvas, stencil = true })
    local modal = CompendiumModal.open()
    check(modal:target_text() == nil, "the title-menu compendium shows only the generic ending conditions")
    draw_frames(modal, 3, 0, 0)
    local cell = CompendiumModal.cell_rect(4, 9)
    modal:mousepressed(cell.x + 5, cell.y + 5)
    draw_frames(modal, 1, cell.x + 5, cell.y + 5)
    modal:keypressed("escape")
    check(modal.closed, "ESC closes the compendium")
    local w = contract("broker")
    local in_run = CompendiumModal.open(w)
    local target = in_run:target_text()
    check(target ~= nil and target:find(tostring(Endings.status(w).need), 1, true) ~= nil,
        "the in-run compendium shows this contract's monopoly line")
    draw_frames(in_run, 2, 0, 0)
    w:destroy()
    for _, id in ipairs(ENDINGS.order) do
        local fx = Effects()
        local scene = EndingScenes(id, fx)
        local spec = ENDINGS.list[id]       -- 일러스트가 없는 엔딩은 대체 그림(fallback), 그것도 없으면 코드 연출
        local art = not missing_assets and (spec.image ~= nil and "illustration" or (spec.fallback ~= nil and "fallback")) or nil
        check(scene:image_kind() == art and scene:has_image() == (art == "illustration"),
            "ending " .. id .. " should draw " .. tostring(art or "the code scene") .. ", got " .. tostring(scene:image_kind()))
        for step = 1, 30 do
            scene:update(0.2, step * 0.2)
            fx:update(0.2)
        end
        scene:draw(6)
        fx:draw()
    end
    love.graphics.setCanvas()
    love.graphics.pop()
end

function SmokeCollection.run(log, missing_assets)
    check_unlock_filter()
    check_achievements()
    check_endings()
    check_views(missing_assets)
    require("systems.MetaProgression").use_memory_only()
    log("collection ok (8 special relics gated by achievements, contract-scaled monopoly line + wall gate, endings %s, "
        .. "save_meta round trip, compendium)", missing_assets and "(code scenes)" or "(illustrations)")
end

return SmokeCollection
