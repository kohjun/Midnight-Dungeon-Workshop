-- tools/SmokeTraceScreens.lua
-- '스승의 흔적' 캠페인 스모크 검사 — 런 밖 화면 (SmokeTest 가 SmokeMasterTrace 다음에 실행, 오프스크린 렌더 · --shots 면 PNG):
--   계약서 5번째 카드: 첫 실행은 봉인 '???'(face = veiled) → 베테랑 · 악몽 클리어 뒤 진엔딩 캠페인 카드(campaign, 훈장 없음)
--     → Progress.record_ending("true_dawn") (두 번째는 false) 뒤 오른쪽 위 훈장 원판이 금빛 (픽셀 검사)
--     smoke_trace_contract.png (계약서 화면 전체 — 훈장) · smoke_trace_cards.png (봉인 / 캠페인 / 훈장 + 호버)
--   도감 엔딩 두 줄: 봉인 중엔 캠페인 세 칸 모두 ??? + 봉인 안내, 해금 뒤 숨은 결말은 ??? + "숨겨진 결말" → 보면 이름 · 조건,
--     훈장 칸은 받는 법 → 받은 칭호. 인게임 '스승의 흔적' 공방은 상권 독점 기준 대신 봉인진 · 수기 진행 한 줄
--     smoke_trace_compendium.png (인게임 캠페인) · smoke_trace_compendium_veiled.png (타이틀 · 봉인 중)
--   엔딩 장면: true_dawn = 일러스트(에셋이 없으면 코드 연출) · new_gatekeeper = 언제나 코드 연출. 에필로그(다섯 줄 · 긴 이름 · ko/en)가
--     아래 레터박스 위에 든다. 대체 그림 · 코드 연출 · 스프라이트 없는 도형 경로도 강제로 그려 본다
--     smoke_trace_ending_true.png · smoke_trace_ending_gatekeeper.png (+ _true_fallback · _true_code · _gatekeeper_shapes)
--   결과 화면: 진엔딩 훈장 획득 줄 (smoke_trace_gameover.png)
-- 끝나면 진행도 · 메타 진행도 · 언어 · 스프라이트를 처음 상태로 되돌린다 (뒤의 시나리오는 첫 실행 상태를 기대한다).

local SmokeTraceScreens = {}

local LONG_NAME = "가나다라마바사아자차"         -- 서명 최대 길이(10자) — 에필로그 줄이 가장 길어지는 경우

local function check(condition, message)
    if not condition then
        error("SmokeTraceScreens: " .. message, 2)
    end
end

local function set_language(code)
    local Settings = require("systems.Settings")
    if Settings.get("language") ~= code then
        Settings.set("language", code)
    end
end

-- 1280x720 오프스크린에 그린다 (shots 면 filename 으로 저장). ImageData 를 돌려준다
local function offscreen(filename, shots, draw)
    local Viewport = require("core.Viewport")
    local canvas = love.graphics.newCanvas(Viewport.width(), Viewport.height())
    love.graphics.push("all")
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.origin()
    love.graphics.clear(0.06, 0.05, 0.07, 1)
    draw()
    love.graphics.setCanvas()
    love.graphics.pop()
    local data = canvas:newImageData()
    if shots and filename ~= nil then
        data:encode("png", filename)
    end
    return data, canvas:getDPIScale()
end

local function pixel(data, dpi, x, y)
    local r, g, b = data:getPixel(math.floor(x * dpi), math.floor(y * dpi))
    return r, g, b
end

-- 계약서 카드 한 장 (rect 를 주면 그 자리에)
local function contract_card(index, rect)
    local DIFFICULTIES = require("data.difficulties")
    local id = DIFFICULTIES.order[index]
    local button = require("ui.Button")(rect or require("ui.ContractCards").rect(index), "", { hidden = true })
    return { id = id, mode = DIFFICULTIES.modes[id], button = button }
end

local function check_contract(shots)
    local Progress, ContractCards = require("systems.Progress"), require("ui.ContractCards")
    local CARDS = require("data.layout").difficulty.cards
    Progress.use_memory_only()
    local index = #require("data.difficulties").order
    local card = contract_card(index)
    check(card.id == "master_trace" and ContractCards.face(card.id) == "veiled", "first run: the 5th contract is the veiled ??? card")
    local positions = {}
    for k = 1, 3 do
        positions[k] = { x = 40 + (k - 1) * 410, y = 250, w = CARDS.w, h = CARDS.rows[2].h }
    end
    local veiled = contract_card(index, positions[1])
    Progress.mark_cleared("veteran")
    Progress.mark_cleared("abyss")
    check(ContractCards.face(card.id) == "campaign" and not ContractCards.has_medal(card.id), "an abyss clear opens the campaign card")
    local opened = contract_card(index, positions[2])
    local data, dpi = offscreen(nil, false, function() ContractCards.draw(index, opened, 1) end)
    local mx, my = ContractCards.medal_center(positions[2])
    local r = pixel(data, dpi, mx, my - 6)
    check(r < 0.6, "no medal on the campaign card before the true ending")
    check(Progress.record_ending("true_dawn") and not Progress.record_ending("true_dawn") and ContractCards.has_medal(card.id),
        "the true ending medal is recorded once and shown on the campaign card")
    local medal = contract_card(index, positions[3])
    medal.button._anim.hover = 1
    data, dpi = offscreen("smoke_trace_cards.png", shots, function()
        Progress.use_memory_only()
        ContractCards.draw(index, veiled, 1.5)
        Progress.mark_cleared("veteran")
        Progress.mark_cleared("abyss")
        ContractCards.draw(index, opened, 1.5)
        Progress.record_ending("true_dawn")
        ContractCards.draw(index, medal, 1.5)
    end)
    local rect, scale = positions[3], medal.button:scale()        -- 호버: 카드 가운데 기준 확대 + 4px 들림
    mx, my = ContractCards.medal_center(rect)
    local cx, cy = rect.x + rect.w / 2, rect.y + rect.h / 2
    local g, b
    r, g, b = pixel(data, dpi, cx + (mx - cx) * scale, cy + (my - 6 - cy) * scale - 4)
    check(r > 0.75 and g > 0.5 and b < 0.55, string.format("the campaign card shows a golden medal (%.2f %.2f %.2f)", r, g, b))
    local state = require("states.DifficultyState")()
    state:enter()
    local fifth = ContractCards.rect(index)
    state:mousemoved(fifth.x + fifth.w / 2, fifth.y + fifth.h / 2)      -- 진엔딩 카드 호버 (보랏빛 번짐 · 확대)
    for _ = 1, 12 do
        state:update(0.1)
    end
    offscreen("smoke_trace_contract.png", shots, function() state:draw() end)
    state:exit()
    Progress.use_memory_only()
end

local function entry(id)
    for _, card in ipairs(require("ui.CompendiumEndings").entries()) do
        if card.id == id then
            return card
        end
    end
    error("SmokeTraceScreens: no compendium card " .. id)
end

local function draw_modal(modal)
    for _ = 1, 3 do
        modal:update(0.2, 0, 0)
    end
    modal:draw()
end

local function check_compendium(shots)
    local I18n, Progress = require("systems.I18n"), require("systems.Progress")
    local MetaProgression, Endings = require("systems.MetaProgression"), require("systems.Endings")
    local CompendiumModal, CompendiumEndings = require("ui.CompendiumModal"), require("ui.CompendiumEndings")
    Progress.use_memory_only()
    MetaProgression.use_memory_only()
    local unknown, locked = I18n.t("compendium.ending_unknown"), I18n.t("compendium.campaign_locked")
    check(CompendiumEndings.is_veiled(), "first run: the campaign ending row is veiled")
    for _, id in ipairs({ "true_dawn", "new_gatekeeper", "medal" }) do
        local card = entry(id)
        check(card.veiled and card.name == unknown and card.text == locked, "veiled campaign card " .. id .. " shows ??? + the sealed notice")
    end
    offscreen("smoke_trace_compendium_veiled.png", shots, function() draw_modal(CompendiumModal.open()) end)
    Progress.mark_cleared("veteran")
    Progress.mark_cleared("abyss")
    local vars = Endings.condition_vars()
    check(not CompendiumEndings.is_veiled() and entry("true_dawn").name == unknown
        and entry("true_dawn").text == I18n.t("ending.true_dawn.condition", vars), "an unseen true ending shows ??? + its condition")
    check(entry("new_gatekeeper").name == unknown and entry("new_gatekeeper").text == I18n.t("compendium.hidden_condition"),
        "the hidden ending keeps its name and condition hidden until seen")
    check(not entry("medal").earned and entry("medal").text == I18n.t("compendium.medal_locked"), "the medal card explains how to earn it")
    MetaProgression.record_ending("new_gatekeeper")
    check(entry("new_gatekeeper").name == I18n.t("ending.new_gatekeeper.name")
        and entry("new_gatekeeper").text == I18n.t("ending.new_gatekeeper.condition", vars), "a seen hidden ending reveals itself")
    MetaProgression.record_ending("true_dawn")
    Progress.record_ending("true_dawn")
    check(entry("medal").earned and entry("medal").text == I18n.t("compendium.medal_earned"), "an earned medal shows its title")
    MetaProgression.record_ending("monopoly")
    local w = require("systems.Workshop")({ difficulty = "master_trace" })
    local relic = require("entities.Item")("flame_sword", { grade = "rare", contamination = 0 })
    relic.owned, relic.level = true, 5
    w.inventory:place(relic, "grid", require("systems.MasterTrace").SLOTS[1].index)
    w.master_trace.journals = 3
    local modal = CompendiumModal.open(w)
    local status = w.master_trace:status()
    check(status.lit == 1 and modal:target_text() == I18n.t("compendium.campaign_target", { lit = status.lit, slots = status.slots,
        journals = status.journals, total = status.journal_total }), "the in-run master_trace compendium shows the seal/journal line")
    offscreen("smoke_trace_compendium.png", shots, function() draw_modal(modal) end)
    w:destroy()
end

-- EndingState 를 띄운다. settle 이면 마지막 줄이 다 찍힌 뒤까지 진행 (결과 화면으로 넘어가는 lines_end + 3초 전까지만 —
-- 넘어가면 StateManager 에 전환이 쌓여 뒤의 시나리오가 깨진다)
local function ending_state(id, name, settle)
    local ENDINGS = require("data.endings")
    local state = require("states.EndingState")()
    state:enter({ reason = "victory", ending = id, name = name, medal_new = id == "true_dawn" })
    local seconds = settle and (ENDINGS.lines_at + #state:get_lines() * ENDINGS.line_time + 1) or 0
    for _ = 1, math.floor(seconds / 0.1) do
        state:update(0.1)
    end
    return state
end

local function check_lines_fit()
    local ENDINGS, Viewport = require("data.endings"), require("core.Viewport")
    for _, code in ipairs({ "ko", "en" }) do
        set_language(code)
        for _, id in ipairs(ENDINGS.campaign) do
            local lines = ending_state(id, LONG_NAME, false):get_lines()
            local last = lines[#lines]
            check(#lines >= 4 and last.y + last.height <= Viewport.height() - 40, string.format(
                "%s: %s epilogue (%d lines) must end above the letterbox (bottom %d)", code, id, #lines, last.y + last.height))
            check(lines[1].y > 130, code .. ": " .. id .. " epilogue must stay below the title")
        end
    end
    set_language("ko")
end

-- 장면만 그린다 (opts.force: 대체 그림 / 코드 연출 경로)
local function scene_shot(filename, shots, id, opts)
    local Effects, EndingScenes = require("ui.Effects"), require("ui.EndingScenes")
    local fx = Effects()
    local scene = EndingScenes(id, fx, opts)
    for step = 1, 40 do
        scene:update(0.15, step * 0.15)
        fx:update(0.15)
    end
    offscreen(filename, shots, function()
        scene:draw(8)
        fx:draw()
    end)
    return scene
end

local function check_endings(shots, missing_assets)
    local SpriteBank = require("ui.SpriteBank")
    local true_dawn = scene_shot(nil, false, "true_dawn")
    check(true_dawn:image_kind() == (not missing_assets and "illustration" or nil), "true_dawn uses its illustration only when present")
    check(scene_shot(nil, false, "new_gatekeeper"):image_kind() == nil, "new_gatekeeper is always a code scene")
    local fallback = scene_shot("smoke_trace_ending_true_fallback.png", shots, "true_dawn", { force = "fallback" })
    check(fallback:image_kind() == (not missing_assets and "fallback" or nil), "without its illustration true_dawn uses the fallback art")
    check(scene_shot("smoke_trace_ending_true_code.png", shots, "true_dawn", { force = "code" }):image_kind() == nil,
        "true_dawn has a code scene when no art exists")
    SpriteBank.set_enabled(false)
    scene_shot("smoke_trace_ending_gatekeeper_shapes.png", shots, "new_gatekeeper")
    SpriteBank.set_enabled(true)
    check_lines_fit()
    for id, filename in pairs({ true_dawn = "smoke_trace_ending_true.png", new_gatekeeper = "smoke_trace_ending_gatekeeper.png" }) do
        local state = ending_state(id, "모험왕", true)
        check(state:get_ending() == id, "EndingState plays " .. id)
        offscreen(filename, shots, function() state:draw() end)
    end
end

local function check_gameover(shots)
    local state = require("states.GameOverState")()
    state:enter({ reason = "victory", ending = "true_dawn", ending_new = true, medal_new = true, difficulty = "master_trace",
        name = "모험왕", day = 60, days_survived = 60, tributes_paid = 6, gold = 3120, gold_earned = 48210, kills = 912,
        items_lost = 2, seed = 4242, unlocked = {}, rp = { total = 1806, days = 900, tributes = 300, kills = 182, clear = 200, mult = 3 } })
    for _ = 1, 10 do
        state:update(0.1)
    end
    offscreen("smoke_trace_gameover.png", shots, function() state:draw() end)
    state:exit()
end

function SmokeTraceScreens.run(log, shots, missing_assets)
    check_contract(shots)
    check_compendium(shots)
    check_endings(shots, missing_assets)
    check_gameover(shots)
    require("systems.Progress").use_memory_only()
    require("systems.MetaProgression").use_memory_only()
    set_language("ko")
    log("trace screens ok (veiled ??? -> campaign card -> medal, compendium 2 ending rows + campaign target, "
        .. "true_dawn %s + fallback/code, new_gatekeeper code scene, 5-line epilogue fits, game over medal)",
        missing_assets and "(code scene)" or "(illustration)")
end

return SmokeTraceScreens
