-- tools/SmokeTraceUI.lua
-- '스승의 흔적' 캠페인 스모크 검사 — 공방 안 UI (SmokeTest 가 SmokeMasterTrace 다음에 실행):
--   [수기 · 봉인진] 버튼(master_trace 런에서만 · 낮/밤 자리 · ko/en 글자 한 줄 · 진열장 제목/칸 · 밤 레인의 새벽 막대 · 중간 보스
--   바/배너 · 최종 보스 먹 띠 · 배속 토글과 겹침 없음) · [수기] 창(RunOverlays journal · 최근 편 · 카드 선택 · 봉인된 편 · ESC/[닫기]
--   · 안 읽은 수 배지) · HUD 포탈 간섭 배지 + 호버 · 작업대/보관함/UV 렌즈 속 은빛 인장(픽셀) · ui/FeedbackTrace 토스트 + 파티클.
--   --shots: smoke_trace_journal(_sealed · _final).png · smoke_trace_day.png · smoke_trace_uv.png · smoke_trace_night.png

local SmokeTraceUI = {}

local function check(condition, message)
    if not condition then
        error("SmokeTraceUI: " .. message, 2)
    end
end

local function overlaps(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

local function set_language(code)
    require("systems.Settings").set("language", code)
end

-- 1280x720 오프스크린에 그린다 (shots 면 filename 으로 저장). ImageData 를 돌려준다
local function offscreen(filename, shots, draw)
    local canvas = love.graphics.newCanvas(1280, 720)
    love.graphics.push("all")
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.origin()
    love.graphics.clear(0.06, 0.05, 0.06, 1)
    draw()
    love.graphics.setCanvas()
    love.graphics.pop()
    local data = canvas:newImageData()
    if shots then
        data:encode("png", filename)
    end
    return data
end

-- (x, y) 둘레 반경 radius 안에 은청색 픽셀이 있는지
local function silver_blue_near(data, x, y, radius)
    for dy = -radius, radius do
        for dx = -radius, radius do
            local r, g, b = data:getPixel(math.floor(x + dx), math.floor(y + dy))
            if b > 0.85 and g > 0.7 and b > r + 0.1 then
                return true
            end
        end
    end
    return false
end

-- 버튼 글자가 button_small 아래로 줄지 않고 한 줄에 드는지 (ui/Button 의 _draw_row: 아이콘 17 + 간격 6, 여백 8)
local function label_fits(button)
    return require("ui.Draw").font("button_small"):getWidth(button:label_text()) + 23 <= button.rect.w - 8
end

local function check_layout()
    local I18n, Draw, Grid, Slots = require("systems.I18n"), require("ui.Draw"), require("systems.Grid"), require("ui.Slots")
    local DayLayoutView = require("ui.DayLayoutView")
    local LAYOUT, UPGRADES, UI = require("data.layout"), require("data.upgrades"), require("data.ui")
    local B, section, lane = LAYOUT.buttons, LAYOUT.day.grid_section, LAYOUT.night.lane
    local gx, gy, gw, gh = Slots.grid_bounds("day")
    check(not overlaps(B.journal, { x = gx, y = gy, w = gw, h = gh }) and B.journal.y >= section.y
        and B.journal.x + B.journal.w <= section.x + section.w, "the day journal button sits in the showcase header, clear of cells")
    for _, code in ipairs({ "ko", "en" }) do
        set_language(code)
        for stage = 1, #UPGRADES.grid_stages do
            local title, width = I18n.t("grid.board", { stage = Grid.stage_label(stage) }), DayLayoutView.grid_title_width(true)
            check(Draw.font(Draw.fit_size(title, width, DayLayoutView.TITLE_SIZES)):getWidth(title) <= width       -- 좁으면 줄인 글자
                and section.x + 16 + width <= B.journal.x - 4, "the showcase title ends before the journal button (" .. code .. ", stage " .. stage .. ")")
        end
    end
    set_language("ko")
    local bar = require("ui.MidBossView").bar_rect(lane)
    check(not overlaps(B.journal_night, { x = bar.x - 10, y = bar.y - 22, w = bar.w + 20, h = bar.h + 30 }),
        "the night journal button clears the mid-boss bar box")
    check(B.journal_night.y >= lane.y + 20 + Draw.font(UI.font_size.tiny):getHeight(), "the night button is below the dawn label")
    check(not overlaps(B.journal_night, { x = lane.x + lane.w / 2 - 260, y = lane.y + 88, w = 520, h = 60 })
        and not overlaps(B.journal_night, { x = lane.x, y = lane.y + 172 - 67, w = lane.w, h = 134 }),
        "the night journal button clears the mid-boss banner (ui/MidBossView) and the final boss ink band (ui/MasterBossHud)")
    check(B.journal_night.x >= lane.x and B.journal_night.x + B.journal_night.w <= lane.x + lane.w
        and not overlaps(B.journal_night, B.speed), "the night journal button stays inside the lane, away from the speed toggle")
end

local function check_buttons(Workshop, WorkshopInput)
    local w = Workshop({ difficulty = "master_trace" })
    local requested = nil
    local input = WorkshopInput(w, function(kind) requested = kind end)
    local day, night = input:button("journal"), input:button("journal_night")
    check(day:is_visible() and not night:is_visible(), "the day [Journals] button shows by day only")
    for _, code in ipairs({ "ko", "en" }) do
        set_language(code)
        for _, journals in ipairs({ 0, 6 }) do
            w.master_trace.journals = journals
            local label = day:label_text()
            check(label ~= "" and not label:find("{", 1, true), "the journal button label is filled (" .. code .. ")")
            check(label_fits(day) and label_fits(night), "the journal button label fits on one line (" .. code .. "): " .. label)
        end
    end
    set_language("ko")
    w.master_trace.journals = 0
    day:press()
    check(requested == "journal", "pressing [Journals] by day requests the journal window")
    w.phase, requested = "night", nil
    check(night:is_visible() and not day:is_visible(), "the night button replaces the day button at night")
    night:press()
    check(requested == "journal", "pressing [Journals] at night requests the journal window")
    w.phase = "day"
    local broker = Workshop({ difficulty = "broker" })
    local other = WorkshopInput(broker, function() end)
    for _, phase in ipairs({ "day", "night" }) do
        broker.phase = phase
        check(not other:button("journal"):is_visible() and not other:button("journal_night"):is_visible(), "no journal button "
            .. "outside the master_trace contract (" .. phase .. ")")
    end
    other:destroy()
    broker:destroy()
    return w, input
end

-- 봉인 공명 슬롯 4칸에 +5 계열 유물 (점화)
local function light_sockets(w)
    local ItemFactory, MasterTrace = require("systems.ItemFactory"), require("systems.MasterTrace")
    local relics = { fire = "flame_sword", lightning = "storm_rod", curse = "cursed_dagger", gold = "golden_chalice" }
    for _, slot in ipairs(MasterTrace.SLOTS) do
        w.inventory:place(ItemFactory.make_ready(relics[slot.archetype], "rare", 5), "grid", slot.index)
    end
    check(w.master_trace:is_complete(), "four +5 relics of the right currents light the whole array")
end

-- [수기] 창: 열기 · 선택 · 봉인된 편 · 닫기 · 안 읽은 수 · 6/6 + 봉인진 완성 (영어)
local function check_journal(w, input, shots)
    local MasterJournalModal, trace = require("ui.MasterJournalModal"), w.master_trace
    check(MasterJournalModal.unread(w) == 0, "nothing unread at the start")
    trace.journals = 2
    check(MasterJournalModal.unread(w) == 2 and input:button("journal")._opts.badge() == 2, "the [Journals] badge counts unread")
    local overlays = require("ui.RunOverlays")(w, input, { restart = function() end, to_title = function() end })
    overlays:open("journal")
    local modal = overlays.menu
    check(modal ~= nil and modal.kind == "journal" and overlays:update_menu(1), "RunOverlays opens the journal as a pausing menu")
    check(modal:selected() == 2 and MasterJournalModal.unread(w) == 0, "opens on the newest journal and marks it read")
    offscreen("smoke_trace_journal.png", shots, function() modal:draw() end)
    local card = MasterJournalModal.card_rect(5)
    modal:mousepressed(card.x + 30, card.y + card.h / 2)
    check(modal:selected() == 5 and not modal:is_unlocked(5), "clicking a sealed card selects it")
    set_language("en")
    modal:update(1, card.x + 30, card.y + 10)
    offscreen("smoke_trace_journal_sealed.png", shots, function() modal:draw() end)
    card = MasterJournalModal.card_rect(3)
    modal:mousepressed(card.x + 30, card.y + 10)            -- 다음 편: 인장이 숨기 시작하는 날 안내
    modal:update(1, 0, 0)
    offscreen(nil, false, function() modal:draw() end)
    overlays:keypressed("escape")
    overlays:update_menu(0.016)
    check(overlays.menu == nil and not overlays:any_open(), "ESC closes the journal")
    trace.journals = 6
    light_sockets(w)
    local final = MasterJournalModal.open(w)
    final:update(1, 0, 0)
    check(final:selected() == 6, "the last journal opens first once all six are found")
    offscreen("smoke_trace_journal_final.png", shots, function() final:draw() end)    -- 가장 긴 본문 (영어)
    set_language("ko")
    offscreen(nil, false, function() final:draw() end)
    local close = MasterJournalModal.close_rect()
    final:mousepressed(close.x + close.w / 2, close.y + close.h / 2)
    check(final.closed and MasterJournalModal.unread(w) == 0, "[Close] closes the journal")
    trace.journals = 2
end

-- HUD 간섭 배지(둘째 줄 한 줄) · 날짜 카드 / [수기] 버튼 호버 문구
local function check_hud_and_hover(w)
    local I18n, Draw = require("systems.I18n"), require("ui.Draw")
    local LAYOUT = require("data.layout")
    w.day = 25
    local chip = require("ui.SeasonBadge").interference_width(6) + 4
    local detail, font, room = I18n.t("hud.badge_customers", { count = 3 }), Draw.font({ role = "ui", size = 12 }), LAYOUT.hud.badge.w - 38 - chip
    check(w:interference() == 3 and (font:getWidth(I18n.t("hud.badge_phase_day") .. " · " .. detail) <= room or font:getWidth(detail) <= room),
        "the date card keeps its second line on one line next to the interference badge")   -- 안 들면 HudStatus 가 내용만 쓴다
    local hover = require("ui.HoverTooltip")(w)
    local function hover_at(x, y)
        hover:update(0.5, { x = x, y = y }, false)
        hover:update(0.5, { x = x, y = y }, false)
        return hover:content()
    end
    local _, lines = hover_at(LAYOUT.hud.badge.x + 20, LAYOUT.hud.badge.y + 20)
    local level, body = lines[#lines - 1][1], lines[#lines][1]
    check(level == I18n.t("trace.interference.level", { level = 3 }) and body:find("+6", 1, true) and not body:find("{", 1, true),
        "the date card hover lists the interference level and its current effects: " .. body)
    local button = LAYOUT.buttons.journal
    check(hover_at(button.x + 10, button.y + 10) == I18n.t("trace.hover.journal_title") and hover:visible_id() == "journal",
        "the [Journals] button hover")
    hover:update(0, { x = 0, y = 0 }, false)
end

-- 작업대 은빛 인장 · 보관함 마름모 · UV 렌즈 속 인장 · 낮 화면
local function check_bench(w, input, shots)
    local Item, Slots, LAYOUT = require("entities.Item"), require("ui.Slots"), require("data.layout")
    local guest = Item("flame_sword", { grade = "rare", claimed_grade = "rare", contamination = 40,
        grime = { { x = -0.1, y = 0.1, r = 0.12 } } })
    guest.silver_seal, guest.revealed.seal, guest.revealed.grade = { x = 0.12, y = -0.1 }, true, true
    w.inventory:place(guest, "bench", 1)
    local mine = Item("storm_rod", { grade = "common" })
    mine.owned, mine.cleaned, mine.contamination = true, true, 0
    mine.silver_seal, mine.revealed.seal = { x = 0, y = 0, claimed = true }, true
    w.inventory:place(mine, "storage", 1)
    local hud = require("ui.Hud")()
    local function draw_day()
        require("ui.RoomBackdrop").draw("day")
        require("ui.DayLayoutView").draw(w, input, 0, nil)
        hud:draw(w, 0)
        input:draw()
    end
    input:update(0)
    local data = offscreen("smoke_trace_day.png", shots, draw_day)
    local cx, cy = Slots.center("bench", 1)
    local size, seal_r = LAYOUT.day.bench_slot.item_size, require("ui.ItemRenderer").SEAL_R
    local mark_x, mark_y = cx + 0.12 * size, cy - 0.1 * size
    check(silver_blue_near(data, mark_x + seal_r * size, mark_y, 3), "the found silver seal is drawn at its mark")
    local sx, sy = Slots.center("storage", 1)
    local half = LAYOUT.day.storage_slots.item_size / 2
    check(silver_blue_near(data, sx - half + 5.5, sy + half - 5.5, 2), "owned relics with a found seal show a silver dot")
    input.tool, w.appraisal.lens_on = "uv", true                  -- UV 렌즈 속에서도 인장이 빛난다
    input.pointer.x, input.pointer.y = mark_x, mark_y
    data = offscreen("smoke_trace_uv.png", shots, draw_day)
    check(silver_blue_near(data, mark_x + seal_r * size, mark_y, 3), "the UV lens shows the silver seal")
    input.tool, w.appraisal.lens_on, input.pointer.x, input.pointer.y = "none", false, 0, 0
    w.inventory:remove(mine)
    w.inventory:remove(guest)
end

-- 밤 화면: 레인 왼쪽 위 [수기] 버튼 + 중간 보스 바 + 점화된 봉인진 (겹침 육안 확인용)
local function render_night(w, input, shots)
    local Slots, LAYOUT = require("ui.Slots"), require("data.layout")
    local attacks = require("ui.AttackEffects")(require("ui.Effects")())
    w.combat:start(w.day)
    w.phase = "night"
    local lane, field = LAYOUT.night.lane, LAYOUT.night.field
    w.combat:summon("mid_vanguard", lane.x + lane.w - 160, field.y + field.h / 2)
    Slots.set_mode_provider(function() return "night" end)
    input:update(0)
    offscreen("smoke_trace_night.png", shots, function()
        require("ui.RoomBackdrop").draw("night")
        require("ui.NightLayoutView").draw(w, input, 1, { attacks = attacks })
        require("ui.Hud")():draw(w, 1)
        input:draw()
    end)
    Slots.set_mode_provider(nil)
    w.combat:end_night()
    w.phase = "day"
    attacks:destroy()
end

-- 연출: 이벤트마다 토스트 문구 + 파티클
local function check_feedback(w)
    local I18n, EventBus = require("systems.I18n"), require("core.EventBus")
    local fx, hud = require("ui.Effects")(), require("ui.Hud")()
    local feedback = require("ui.Feedback")(fx, hud, w)
    local guest = require("entities.Item")("frost_crossbow", {})
    guest.silver_seal, guest.revealed.seal = { x = 0.1, y = 0.1 }, true
    local fire = I18n.t("trace.resonance.archetypes.fire")
    local cases = {
        { "appraisal:seal_revealed", { item = guest, x = 300, y = 350 }, I18n.t("trace.seal.found") },
        { "master:journal_unlocked", { index = 1, total = 6, item = guest, x = 280, y = 370 },
            I18n.t("trace.journal.unlocked", { index = 1, title = I18n.t("trace.journal.entries.omen.title") }) },
        { "calendar:interference_rose", { level = 2, day = 11, workshop = w }, I18n.t("trace.interference.rose", { level = 2 }) },
        { "master:seal_lit", { index = 7, archetype = "fire", lit = 1, x = 0, y = 0 },
            I18n.t("trace.resonance.lit", { archetype = fire, lit = 1, slots = 4 }) },
        { "master:seal_dimmed", { index = 7, archetype = "fire", lit = 0, x = 0, y = 0 },
            I18n.t("trace.resonance.dimmed", { archetype = fire, lit = 0, slots = 4 }) },
        { "master:array_complete", { day = 30 }, I18n.t("trace.resonance.complete") },
    }
    for _, case in ipairs(cases) do
        local before = fx:particle_count()
        EventBus.emit(case[1], case[2])
        check(hud._toasts[1] ~= nil and hud._toasts[1].text == case[3], case[1] .. " toasts its message")
        check(not case[3]:find("{", 1, true) and fx:particle_count() > before, case[1] .. " bursts particles")
    end
    feedback:destroy()
end

function SmokeTraceUI.run(log, shots)
    local Workshop = require("systems.Workshop")
    local WorkshopInput = require("ui.WorkshopInput")
    require("core.RNG").set_seed(60606)
    check_layout()
    local w, input = check_buttons(Workshop, WorkshopInput)
    check_journal(w, input, shots)
    check_hud_and_hover(w)
    check_bench(w, input, shots)
    render_night(w, input, shots)
    check_feedback(w)
    input:destroy()
    w:destroy()
    log("trace ui ok ([Journals] buttons day/night only in master_trace, journal window open/select/sealed/close + unread badge, "
        .. "interference badge + hover, silver seal on the bench / lens / storage, trace feedback toasts)")
end

return SmokeTraceUI
