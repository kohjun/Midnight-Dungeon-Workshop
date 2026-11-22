-- ui/FeedbackTrace.lua
-- '스승의 흔적' 캠페인 이벤트 → 연출 (ui/Feedback 이 생성 시 subscribe(feedback) 로 붙인다 — feedback:_on(priority -100) ·
-- _fx(ui/Effects) · _hud(토스트) 를 쓰고, 정리는 Feedback 의 owner 해제가 한꺼번에 한다). 효과음은 data/audio.lua 의 events.
--   appraisal:seal_revealed   : 표식 자리에 은청색 잉크 파동 + 은빛 불티 + "스승의 은빛 인장" 글자 + 토스트(손님 유물이면 매입 안내)
--   master:journal_unlocked   : 양피지 조각이 흩날리는 펼침 + 수기 제목 글자 + 토스트 ([수기]에서 읽기)
--   calendar:interference_rose: 보라 화면 섬광 + HUD 날짜 카드에 균열 파동 + 토스트 (새 간섭 단계)
--   master:seal_lit / seal_dimmed / array_complete : 지금 화면의 그 진열 칸(ui/Slots)에서 계열 색 점화 폭발 / 꺼지는 재 /
--                               네 소켓 + 가운데 칸 은청색 공명 파동 — 토스트 (계열 이름 · 봉인진 N/4)

local I18n = require("systems.I18n")
local MasterTrace = require("systems.MasterTrace")
local Slots = require("ui.Slots")
local SealSigil = require("ui.SealSigil")
local Parchment = require("ui.Parchment")
local TRACE = require("data.master_trace")
local ITEMS = require("data.items")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local FeedbackTrace = {}

local SIZE = UI.font_size
local SILVER, BLUE, INK = SealSigil.SILVER, SealSigil.COLOR, SealSigil.INK
local WHITE = { 1, 1, 1 }
local PAPER = { 0.90, 0.82, 0.62 }
local PAPER_DARK = { 0.70, 0.58, 0.38 }
local ASH = { 0.30, 0.28, 0.32 }
local VIOLET = TRACE.interference.color
local BADGE = LAYOUT.hud.badge

local function archetype_name(id)
    return I18n.t("trace.resonance.archetypes." .. id)
end

local function journal_title(index)
    local entry = TRACE.journals[index]
    return entry and I18n.t("trace.journal.entries." .. entry.id .. ".title") or ""
end

function FeedbackTrace.subscribe(feedback)
    local fx, hud = feedback._fx, feedback._hud
    local function on(event, handler)
        feedback:_on(event, handler)
    end

    on("appraisal:seal_revealed", function(p)     -- 은청색 잉크 파동 (먹 고리 → 은청 고리 두 겹) + 은빛 불티
        fx:ring(p.x, p.y, INK, { from = 6, to = 84, life = 0.6, width = 10 })
        fx:ring(p.x, p.y, BLUE, { from = 4, to = 104, life = 0.75, width = 5 })
        fx:ring(p.x, p.y, SILVER, { from = 2, to = 46, life = 0.45, width = 3 })
        fx:burst(p.x, p.y, { count = 34, colors = { SILVER, BLUE, WHITE }, speed_min = 70, speed_max = 280, shape = "spark",
            life_max = 0.8 })
        fx:burst(p.x, p.y, { count = 12, colors = { BLUE, SILVER }, speed_max = 60, gravity = -50, life_min = 0.6, life_max = 1.2,
            size_min = 2, size_max = 4 })
        fx:shake(0.15)
        fx:float_text(p.x, p.y - 36, I18n.t("trace.seal.name"), BLUE, { size = SIZE.body, life = 1.4, style = "crit" })
        if not p.item.owned then            -- 내 유물에서 찾았다면 수기가 바로 열린다 (master:journal_unlocked 토스트)
            hud:toast(I18n.t("trace.seal.found"), "good")
        end
    end)

    on("master:journal_unlocked", function(p)    -- 양피지 펼침: 종이 조각이 흩날리고 먹 · 은청 고리
        fx:ring(p.x, p.y, PAPER, { from = 10, to = 150, life = 0.7, width = 8 })
        fx:ring(p.x, p.y, Parchment.INK, { from = 6, to = 96, life = 0.55, width = 3 })
        fx:ring(p.x, p.y, BLUE, { from = 4, to = 60, life = 0.5, width = 3 })
        fx:burst(p.x, p.y, { count = 26, colors = { PAPER, PAPER_DARK, PAPER }, speed_min = 90, speed_max = 300, gravity = 220,
            drag = 3.5, life_min = 0.7, life_max = 1.3, size_min = 3, size_max = 7, shape = "square" })
        fx:burst(p.x, p.y, { count = 16, colors = { SILVER, BLUE }, speed_max = 200, shape = "spark", life_max = 0.6 })
        local title = journal_title(p.index)
        fx:float_text(p.x, p.y - 86, I18n.t("trace.journal.entry", { index = p.index, title = title }), PAPER,
            { size = SIZE.large, life = 1.8, style = "crit" })
        hud:toast(I18n.t("trace.journal.unlocked", { index = p.index, title = title }), "good")
    end)

    on("calendar:interference_rose", function(p)  -- 새 달: 포탈 균열 간섭이 한 단계 오른다
        fx:flash(VIOLET, 0.3, 0.9)
        fx:shake(0.2)
        local x, y = BADGE.x + BADGE.w / 2, BADGE.y + BADGE.h / 2
        fx:ring(x, y, VIOLET, { from = 10, to = 110, life = 0.8, width = 5 })
        fx:burst(x + BADGE.w / 2 - 30, y + 10, { count = 18, colors = { VIOLET, WHITE }, speed_max = 160, shape = "spark",
            life_max = 0.7 })
        hud:toast(I18n.t("trace.interference.rose", { level = p.level }), "warn")
    end)

    on("master:seal_lit", function(p)
        local x, y = Slots.center("grid", p.index)
        local color = ITEMS.archetypes[p.archetype].color
        fx:ring(x, y, color, { from = 8, to = 90, life = 0.6, width = 6 })
        fx:ring(x, y, BLUE, { from = 4, to = 56, life = 0.5, width = 3 })
        fx:burst(x, y, { count = 30, colors = { color, SILVER, WHITE }, speed_min = 80, speed_max = 300, shape = "spark",
            life_max = 0.7 })
        hud:toast(I18n.t("trace.resonance.lit", { archetype = archetype_name(p.archetype), lit = p.lit,
            slots = #MasterTrace.SLOTS }), "good")
    end)

    on("master:seal_dimmed", function(p)
        local x, y = Slots.center("grid", p.index)
        fx:ring(x, y, ASH, { from = 40, to = 6, life = 0.45, width = 4 })
        fx:burst(x, y, { count = 18, colors = { ASH, ITEMS.archetypes[p.archetype].color }, speed_max = 120, gravity = 140,
            life_max = 0.8, size_max = 4, shape = "square" })
        hud:toast(I18n.t("trace.resonance.dimmed", { archetype = archetype_name(p.archetype), lit = p.lit,
            slots = #MasterTrace.SLOTS }), "bad")
    end)

    on("master:array_complete", function()        -- 네 소켓에서 가운데 칸으로 은청색 공명
        for _, slot in ipairs(MasterTrace.SLOTS) do
            local x, y = Slots.center("grid", slot.index)
            fx:ring(x, y, BLUE, { from = 6, to = 70, life = 0.8, width = 4 })
        end
        local x, y = Slots.center("grid", MasterTrace.CENTER)
        fx:ring(x, y, SILVER, { from = 10, to = 220, life = 1.0, width = 7 })
        fx:ring(x, y, BLUE, { from = 6, to = 150, life = 0.8, width = 4 })
        fx:burst(x, y, { count = 50, colors = { SILVER, BLUE, WHITE }, speed_min = 120, speed_max = 420, shape = "spark",
            life_max = 1.0 })
        fx:flash(BLUE, 0.22, 0.7)
        fx:shake(0.3)
        hud:toast(I18n.t("trace.resonance.complete"), "good")
    end)
end

return FeedbackTrace
