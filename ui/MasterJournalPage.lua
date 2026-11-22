-- ui/MasterJournalPage.lua
-- [수기] 창(ui/MasterJournalModal)의 그리기 조각 — 양피지 위 먹 · 은청색 인장 스타일. 규칙 계산 없음.
--   array(trace, rect, time)                    : 봉인진 상자 — 진열장 5x5 축소도(봉인 공명 슬롯 4칸 = 계열 색, 점화 = 빛남,
--                                                가운데 칸 = 4칸 완성 시 공명선) + "봉인진 N/4" + 소켓 자리 그대로 2x2 계열 이름
--                                                (점화 = 빛나는 점 · 진한 먹 / 소등 = 빈 고리 · 옅은 먹, 완성이면 완성 문구)
--   card(rect, index, info, selected, hovered, time) : 수기 카드 (info = { unlocked, new })
--   page(rect, index, alpha, time, text_top)    : 열린 편 본문 — 제목 · 문단(줄바꿈, 넘치면 글자를 줄인다) · 서명 + 인장 도장
--   sealed(rect, index, workshop, alpha, time)  : 봉인된 편 — 자물쇠 + 찾는 법 (다음 편이면 인장이 숨기 시작하는 날짜)
--   label(index, unlocked)                      : "N편 · 제목" / "N편 · 봉인된 수기"

local I18n = require("systems.I18n")
local Grid = require("systems.Grid")
local MasterTrace = require("systems.MasterTrace")
local Draw = require("ui.Draw")
local Icons = require("ui.Icons")
local Parchment = require("ui.Parchment")
local SealSigil = require("ui.SealSigil")
local CalendarText = require("ui.CalendarText")
local TRACE = require("data.master_trace")
local ITEMS = require("data.items")
local UI = require("data.ui")

local MasterJournalPage = {}

local LG = love.graphics
local INK, RED, EDGE = Parchment.INK, Parchment.RED_INK, Parchment.EDGE
local DEEP_BLUE = { 0.14, 0.27, 0.48 }          -- 양피지 위 은빛 인장 관련 글자 (은청색은 종이 위에서 대비가 낮다)
local BOX_FILL = { 0.74, 0.64, 0.45 }
local CARD_FILL = { 0.80, 0.70, 0.50 }
local CARD_SELECTED = { 0.95, 0.87, 0.64 }
local LOCKED_FILL = { 0.62, 0.53, 0.37 }
local LOCKED_SELECTED = { 0.72, 0.62, 0.44 }
local PAPER_DIM = { 0.80, 0.72, 0.55 }
local MINI_CELL, MINI_GAP = 11, 3
local TEXT_SIZES = { { role = "story", size = 18 }, { role = "story", size = 17 }, { role = "story", size = 16 },
    { role = "body", size = 15 }, { role = "body", size = 14 } }
local TITLE_FIT = { "item_name", { role = "display", size = 16 } }
local TITLE_WRAP = { role = "display", size = 15 }      -- 한 줄에 안 드는 긴 제목(영어)은 이 크기로 두 줄
local HEADING_FIT = { "card_title", { role = "display", size = 21 }, "item_name" }
local PARA_GAP = 9
local SIGNATURE_GAP = 6
local STAMP_R = 17

function MasterJournalPage.entry_id(index)
    local entry = TRACE.journals[index]
    return entry and entry.id
end

function MasterJournalPage.label(index, unlocked)
    local title = unlocked and I18n.t("trace.journal.entries." .. MasterJournalPage.entry_id(index) .. ".title")
        or I18n.t("trace.journal.locked")
    return I18n.t("trace.journal.entry", { index = index, title = title })
end

-- ── 봉인진 상자 ───────────────────────────────────────────────
local function mini_cell(index, gx, gy)
    local row, col = Grid.to_row_col(index)
    return gx + (col - 1) * (MINI_CELL + MINI_GAP), gy + (row - 1) * (MINI_CELL + MINI_GAP)
end

local function draw_mini_grid(trace, gx, gy, time)
    local complete = trace ~= nil and trace:is_complete()
    local half = MINI_CELL / 2
    local cx, cy = mini_cell(MasterTrace.CENTER, gx, gy)
    if complete then                            -- 4칸 완성: 소켓에서 가운데 칸으로 은청색 공명선
        local pulse = 0.6 + 0.4 * math.sin(time * 4)
        for _, slot in ipairs(MasterTrace.SLOTS) do
            local sx, sy = mini_cell(slot.index, gx, gy)
            Draw.set_color(DEEP_BLUE, pulse)
            LG.setLineWidth(2)
            LG.line(sx + half, sy + half, cx + half, cy + half)
        end
    end
    for index = 1, Grid.SIZE do
        local x, y = mini_cell(index, gx, gy)
        local slot = MasterTrace.slot_at(index)
        if slot ~= nil then
            local color = ITEMS.archetypes[slot.archetype].color
            if trace ~= nil and trace:is_lit(index) then
                Draw.glow(x + half, y + half, MINI_CELL * 1.3, color, 0.9)
                Draw.set_color(color)
                LG.rectangle("fill", x, y, MINI_CELL, MINI_CELL, 3, 3)
            end
            Draw.set_color(INK)
            LG.setLineWidth(1.5)
            LG.rectangle("line", x, y, MINI_CELL, MINI_CELL, 3, 3)
            Draw.set_color(color, 0.9)
            LG.circle("line", x + half, y + half, half - 2.5, 12)
        elseif index == MasterTrace.CENTER then
            Draw.set_color(complete and DEEP_BLUE or EDGE, complete and 1 or 0.55)
            LG.polygon("fill", x + half, y, x + MINI_CELL, y + half, x + half, y + MINI_CELL, x, y + half)
        else
            Draw.set_color(EDGE, 0.45)
            LG.setLineWidth(1)
            LG.rectangle("line", x + 0.5, y + 0.5, MINI_CELL - 1, MINI_CELL - 1, 2, 2)
        end
    end
end

function MasterJournalPage.array(trace, rect, time)
    Draw.set_color(BOX_FILL, 0.9)
    LG.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 8, 8)
    Draw.set_color(INK, 0.8)
    LG.setLineWidth(1.5)
    LG.rectangle("line", rect.x, rect.y, rect.w, rect.h, 8, 8)
    local size = 5 * MINI_CELL + 4 * MINI_GAP
    local gx, gy = rect.x + 12, rect.y + (rect.h - size) / 2
    draw_mini_grid(trace, gx, gy, time)
    local x = gx + size + 14
    local w = rect.x + rect.w - 10 - x
    local lit = trace and trace:lit_count() or 0
    local complete = lit >= #MasterTrace.SLOTS
    Draw.text(I18n.t("trace.journal.array", { lit = lit, slots = #MasterTrace.SLOTS }), x, rect.y + 7, w, "left", "item_name",
        complete and DEEP_BLUE or INK)
    if complete then                            -- 4칸 완성: 은빛 인장 + 완성 문구
        local text = I18n.t("trace.journal.array_complete")
        SealSigil.draw(x + 10, rect.y + 54, 9, 1, time, { glow = true })
        Draw.text(text, x + 26, rect.y + 46, w - 26, "left", Draw.fit_size(text, w - 26, { "label", { role = "ui", size = 12 } }),
            DEEP_BLUE)
        return
    end
    local col_w = w / 2
    local center_row, center_col = Grid.to_row_col(MasterTrace.CENTER)
    for _, slot in ipairs(MasterTrace.SLOTS) do           -- 소켓 자리 그대로 2x2 (가운데 칸 기준 위/아래 · 왼/오른쪽): 점화 = 빛나는 점
        local on = trace ~= nil and trace:is_lit(slot.index)
        local sx = x + (slot.col > center_col and col_w or 0)
        local sy = rect.y + 38 + (slot.row > center_row and 22 or 0)
        local color = ITEMS.archetypes[slot.archetype].color
        if on then
            Draw.glow(sx + 5, sy + 8, 14, color, 0.9)
        end
        Draw.set_color(INK, on and 1 or 0.7)
        LG.circle("fill", sx + 5, sy + 8, 6, 14)
        Draw.set_color(color)
        if on then
            LG.circle("fill", sx + 5, sy + 8, 4.5, 14)
        else
            LG.setLineWidth(1.5)
            LG.circle("line", sx + 5, sy + 8, 3.5, 14)
        end
        local text = I18n.t("trace.resonance.archetypes." .. slot.archetype)
        Draw.text(text, sx + 15, sy, col_w - 17, "left", Draw.fit_size(text, col_w - 17, { "label", { role = "ui", size = 12 } }),
            on and INK or EDGE)
    end
end

-- ── 수기 카드 ─────────────────────────────────────────────────
function MasterJournalPage.card(r, index, info, selected, hovered, time)
    local fill = info.unlocked and (selected and CARD_SELECTED or CARD_FILL) or (selected and LOCKED_SELECTED or LOCKED_FILL)
    if hovered and not selected then
        fill = Draw.lerp_color(fill, { 1, 0.95, 0.8 }, 0.18)
    end
    Draw.set_color(INK, 0.35)
    LG.rectangle("fill", r.x + 2, r.y + 3, r.w, r.h, 8, 8)
    Draw.set_color(fill, 0.95)
    LG.rectangle("fill", r.x, r.y, r.w, r.h, 8, 8)
    local mx, my = r.x + 26, r.y + r.h / 2
    if info.unlocked then
        SealSigil.draw(mx, my, 14, 1, time + index, { glow = selected })
    else
        Draw.set_color(INK, 0.85)
        LG.circle("fill", mx, my, 16, 24)
        Icons.draw("lock", mx, my, 16, PAPER_DIM)
    end
    local new_w = 0
    if info.new then                            -- 지난번에 창을 연 뒤 새로 열린 편: 붉은 밀랍 꼬리표
        local text = I18n.t("trace.journal.new")
        local font = Draw.font("label")
        local tw, th = font:getWidth(text) + 12, font:getHeight() + 2
        local tx, ty = r.x + r.w - tw - 7, r.y + 6
        new_w = tw + 6
        Draw.set_color(RED, 0.85 + 0.15 * math.sin(time * 5))
        LG.rectangle("fill", tx, ty, tw, th, 4, 4)
        Draw.set_color(INK, 0.6)
        LG.setLineWidth(1)
        LG.rectangle("line", tx + 0.5, ty + 0.5, tw - 1, th - 1, 4, 4)
        Draw.text(text, tx, ty + 1, tw, "center", "label", CARD_SELECTED)
    end
    local label = MasterJournalPage.label(index, info.unlocked)
    local w = r.w - 58 - new_w
    local spec, count = Draw.fit_size(label, w, TITLE_FIT)
    if count > 1 then
        spec = TITLE_WRAP
        count = #select(2, Draw.font(spec):getWrap(label, w))
    end
    local h = count * Draw.font(spec):getHeight()
    Draw.text(label, r.x + 50, r.y + (r.h - h) / 2, w, "left", spec, info.unlocked and INK or EDGE)
    Draw.set_color(info.unlocked and INK or EDGE, selected and 1 or 0.6)
    LG.setLineWidth(selected and 3 or 1.5)
    LG.rectangle("line", r.x, r.y, r.w, r.h, 8, 8)
end

-- ── 본문 ──────────────────────────────────────────────────────
-- 제목 + 먹선 (빨간 마름모 머리). 본문이 시작할 y 를 돌려준다
local function heading(rect, text, alpha, faded)
    local spec = Draw.fit_size(text, rect.w, HEADING_FIT)
    Draw.text(text, rect.x + 1, rect.y + 1, rect.w, "left", spec, EDGE, 0.45 * alpha)      -- 종이에 스민 먹 번짐
    Draw.text(text, rect.x, rect.y, rect.w, "left", spec, faded and EDGE or INK, alpha)
    local y = rect.y + 40
    Draw.set_color(INK, 0.7 * alpha)
    LG.setLineWidth(2)
    LG.line(rect.x + 12, y, rect.x + rect.w, y)
    Draw.set_color(RED, alpha)
    LG.polygon("fill", rect.x, y, rect.x + 6, y - 6, rect.x + 12, y, rect.x + 6, y + 6)
    return y
end

-- 문단들이 height 안에 들어가는 가장 큰 글자 (안 되면 가장 작은 것)
local function fit_text(lines, width, height)
    local spec, line_h = nil, 0
    for _, candidate in ipairs(TEXT_SIZES) do
        local font = Draw.font(candidate)
        spec, line_h = candidate, font:getHeight() * font:getLineHeight()
        local total = line_h + SIGNATURE_GAP
        for _, text in ipairs(lines) do
            total = total + #select(2, font:getWrap(text, width)) * line_h + PARA_GAP
        end
        if total <= height then
            break
        end
    end
    return spec, line_h
end

-- rect = 본문 쪽 (x, y = 제목 위치, w, h = 쪽 전체 높이)
function MasterJournalPage.page(rect, index, alpha, time, text_top)
    local id = MasterJournalPage.entry_id(index)
    SealSigil.draw(rect.x + rect.w - 70, rect.y + rect.h - 80, 58, 0.07 * alpha, 0, { glow = false, ink = false })   -- 물에 비친 인장
    heading(rect, MasterJournalPage.label(index, true), alpha)
    local lines = I18n.list("trace.journal.entries." .. id .. ".lines")
    local top = rect.y + text_top
    local spec, line_h = fit_text(lines, rect.w, rect.y + rect.h - top)
    local font = Draw.font(spec)
    local y = top
    for _, text in ipairs(lines) do
        Draw.text(text, rect.x, y, rect.w, "left", spec, INK, alpha)
        y = y + #select(2, font:getWrap(text, rect.w)) * line_h + PARA_GAP
    end
    local signature = I18n.t("trace.journal.signature")
    local sig_y = y + SIGNATURE_GAP - PARA_GAP
    Draw.text(signature, rect.x, sig_y, rect.w - STAMP_R * 2 - 12, "right", spec, RED, alpha)
    SealSigil.draw(rect.x + rect.w - STAMP_R, sig_y + line_h / 2, STAMP_R, alpha, time)     -- 서명 옆 은빛 인장 도장
end

-- 봉인된 편: 자물쇠 + 찾는 법 (다음 편이면 인장이 숨기 시작하는 날 · 지금 숨을 수 있는지 / 아니면 순서 안내)
function MasterJournalPage.sealed(rect, index, workshop, alpha, time)
    heading(rect, MasterJournalPage.label(index, false), alpha, true)
    local cx, cy = rect.x + rect.w / 2, rect.y + 150
    SealSigil.draw(cx, cy, 64, 0.16 * alpha, time, { glow = false, ink = false, color = EDGE })
    Draw.set_color(INK, 0.8 * alpha)
    LG.circle("fill", cx, cy, 38, 32)
    Icons.draw("lock", cx, cy + 2, 40, PAPER_DIM, alpha)
    local y = cy + 84
    local hint = I18n.t("trace.journal.locked_hint")
    Draw.text(hint, rect.x + 30, y, rect.w - 60, "center", "story", INK, alpha)
    y = y + #select(2, Draw.font("story"):getWrap(hint, rect.w - 60)) * Draw.font("story"):getHeight() + 14
    local trace = workshop.master_trace
    local journals = trace and trace.journals or 0
    local text
    if index == journals + 1 then
        local opens = TRACE.journals[index].opens
        text = workshop.day < opens and I18n.t("trace.journal.opens_hint", { date = CalendarText.date(opens) })
            or I18n.t("trace.journal.seeking_hint")
    else
        text = I18n.t("trace.journal.order_hint")
    end
    Draw.text(text, rect.x + 30, y, rect.w - 60, "center", UI.font_size.body, index == journals + 1 and DEEP_BLUE or EDGE, alpha)
end

return MasterJournalPage
