-- ui/WorkbenchView.lua
-- 낮 화면 왼쪽 대형 작업대 렌더링 (규칙 계산 없음, 좌표는 LAYOUT.day):
--   손님 카운터(ui/CustomerCard — 모험가 프로필·대사·제시가, 거래 버튼은 WorkshopInput 이 그린다)
--   / 작업대 유물 + UV 렌즈·브러시(ui/BenchTools) / 감정 꼬리표(등급·결함·스캔·오염도) / 다음 행동 안내 띠
--   / 연금술 용광로(성공률 · +1 골드 제련 / +2 이상 연마석 오버클럭 비용).
-- 과부하 레버는 밤 화면(ui/NightLayoutView)에만 있다. 밤에는 그리지 않는다.
-- '스승의 흔적': 찾은 은빛 인장(item.silver_seal + revealed.seal)은 작업대 유물의 표식 자리에 은청색 인장(ui/SealSigil)으로,
-- 감정 꼬리표에는 다섯째 줄(은빛 인장 → 매입 시 수기 / 수기 확보)로, 손님 유물이면 안내 띠에 [매입] 안내로 보인다.

local I18n = require("systems.I18n")
local Draw = require("ui.Draw")
local Frame = require("ui.Frame")
local WorkbenchFlow = require("ui.WorkbenchFlow")
local Icons = require("ui.Icons")
local Slots = require("ui.Slots")
local ItemRenderer = require("ui.ItemRenderer")
local BenchTools = require("ui.BenchTools")
local CustomerCard = require("ui.CustomerCard")
local FurnaceView = require("ui.FurnaceView")
local SealSigil = require("ui.SealSigil")
local ART = require("data.art")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local WorkbenchView = {}

local C = UI.color
local SIZE = UI.font_size
local LG = love.graphics
local TAG_FILL = { 0.16, 0.12, 0.09, 0.95 }
local DAY = LAYOUT.day
local ROW_GAP, ROW_GAP_SEAL = 48, 41        -- 감정 꼬리표 줄 간격 (인장 줄이 있으면 다섯 줄을 좁혀 담는다)
local SEAL_FIT = { "button", "button_small", { role = "ui", size = 12 } }

-- 찾은 은빛 인장이 있는 유물인지
local function seal_shown(item)
    return item ~= nil and item.silver_seal ~= nil and item.revealed.seal == true
end

local function draw_slot_frame(area, input, fill)
    local x, y, w, h = Slots.rect(area, 1)
    Frame.inset(x, y, w, h, 10, fill)
    if input:is_drop_candidate(area, 1) then
        local target = input:drop_target() == area
        Draw.set_color(target and C.slot_hover or C.good, target and 1 or 0.35 + 0.2 * math.sin(input.time * 6))
        LG.setLineWidth(target and 3 or 2)
        LG.rectangle("line", x - 2, y - 2, w + 4, h + 4, 12, 12)
    elseif input:hovered_slot() == area and input:hovered_item() ~= nil then
        Draw.set_color(C.accent, 0.5)
        LG.setLineWidth(2)
        LG.rectangle("line", x - 1, y - 1, w + 2, h + 2, 11, 11)
    end
end

local function draw_bench(workshop, input, time, ambient)
    draw_slot_frame("bench", input)
    local item = workshop.appraisal:bench_item()
    local cx, cy = Slots.center("bench", 1)
    if item ~= nil and not input:is_dragging(item) then
        local bob = item.owned and 0 or math.sin(time * 2) * 3
        local y, size = cy + bob + (ambient and ambient:hop(item) or 0), DAY.bench_slot.item_size
        ItemRenderer.draw(item, cx, y, size, { time = time, seal_dot = false })
        if seal_shown(item) then                -- 찾은 은빛 인장: 표식 자리에 은은하게 맥동 (렌즈를 켜면 렌즈가 덮는다)
            local seal = item.silver_seal
            SealSigil.draw(cx + seal.x * size, y + seal.y * size, ItemRenderer.SEAL_R * size, 0.92, time)
        end
    end
    BenchTools.draw_lens(workshop, item, input, time)
end

-- 감정 꼬리표 다섯째 줄: 은빛 인장 (매입 시 수기 / 수기 확보) + 작은 인장 표식
local function draw_seal_row(item, tag, y, time)
    local x, w = tag.x + 6, tag.w - 40
    local pulse = 0.5 + 0.5 * math.sin(time * 3)
    Draw.set_color(SealSigil.COLOR, 0.10 + 0.08 * pulse)
    LG.rectangle("fill", tag.x + 3, y - 1, tag.w - 6, ROW_GAP_SEAL - 5, 6, 6)
    Draw.text(I18n.t("trace.seal.tag"), x, y, w, "left", "label", SealSigil.SILVER)
    local value = I18n.t(item.silver_seal.claimed and "trace.seal.claimed" or "trace.seal.tag_value")
    Draw.text(value, x, y + 14, w, "left", Draw.fit_size(value, w, SEAL_FIT), SealSigil.COLOR)
    SealSigil.draw(tag.x + tag.w - 20, y + 16, 11, 1, time, { glow = false })
end

-- 감정 꼬리표: 등급 · 결함 · 스캔 진행 · 오염도 (+ 찾은 은빛 인장)
local function draw_appraisal_tag(workshop, ambient, time)
    local tag = DAY.appraisal_tag
    local item = workshop.appraisal:bench_item()
    Frame.inset(tag.x, tag.y, tag.w, tag.h, 8, TAG_FILL)
    Draw.set_color({ 0.03, 0.02, 0.02 })
    LG.circle("fill", tag.x + tag.w / 2, tag.y + 9, 4, 10)
    local x, w = tag.x + 6, tag.w - 12
    if item == nil then
        Draw.text(I18n.t("bench.tag_empty"), x, tag.y + 60, w, "center", "label", C.text_dim)
        return
    end
    local grade = item.revealed.grade and I18n.grade(item.grade) or "?"
    if not item.owned and item:is_forgery_revealed() then
        grade = I18n.t("bench.tag_forged", { grade = grade })
    end
    local flaw, flaw_color = I18n.t("bench.flaw_unknown"), C.text_dim
    if item.flaw ~= nil and item.revealed.flaw then
        flaw, flaw_color = I18n.t("flaws." .. item.flaw .. ".name"), C.danger
    elseif item.revealed.complete then
        flaw, flaw_color = I18n.t("bench.flaw_none"), C.good
    end
    local coverage = workshop.appraisal:scan_coverage(item)
    local rows = {
        { I18n.t("bench.tag_grade"), grade, item.revealed.grade and item:grade_info().color or C.text_dim },
        { I18n.t("bench.tag_flaw"), flaw, flaw_color },
        { I18n.t("bench.tag_scan"), string.format("%d%%", math.floor(coverage * 100 + 0.5)), C.uv, coverage },
        { I18n.t("bench.tag_grime"), string.format("%d%%", math.ceil(item.contamination)), item.cleaned and C.good or C.accent,
            item.contamination / 100 },
    }
    local guest = ambient and ambient.guest
    local seal = seal_shown(item)
    local gap, top = seal and ROW_GAP_SEAL or ROW_GAP, tag.y + (seal and 16 or 20)
    for i, row in ipairs(rows) do
        local y = top + (i - 1) * gap
        local flash = (guest ~= nil and i <= 2) and guest:flash(item, i == 1 and "grade" or "flaw") or 0
        if flash > 0 then           -- 적발한 줄이 붉게 맥동한다 (ui/GuestReaction)
            Draw.set_color(C.danger, 0.45 * flash)
            LG.rectangle("fill", tag.x + 3, y - 4, tag.w - 6, gap - 4, 6, 6)
        end
        Draw.text(row[1], x, y, w, "left", "label", C.text_dim)
        Draw.text(row[2], x, y + 14, w, "left", "button", row[3])
        if row[4] ~= nil then
            Draw.bar(x, y + 35, w, 4, row[4], row[3])
        end
    end
    if seal then
        draw_seal_row(item, tag, top + #rows * gap, time)
    end
end

-- 지금 할 수 있는 다음 행동 안내 (튜토리얼 중에는 튜토리얼 띠가 대신한다)
local function hint_key(workshop, input)
    if not workshop:is_day() or (workshop.tutorial ~= nil and workshop.tutorial:is_active()) then
        return nil
    end
    local item = workshop.appraisal:bench_item()
    if item == nil then
        return workshop.customers_left > 0 and "hint.new_customer" or "hint.summon"
    elseif not item.owned then
        if seal_shown(item) then        -- 스승의 은빛 인장: 사면 수기가 열린다
            return "trace.seal.hint"
        end
        if not item.revealed.complete then
            return input.tool == "uv" and "hint.hold_uv" or "hint.scan"
        end
        return "hint.decide"
    elseif not item.cleaned then
        return input.tool == "brush" and "hint.scrub" or "hint.clean"
    end
    return "hint.place"
end

local function draw_hint(workshop, input, time)
    local key = hint_key(workshop, input)
    if key == nil then
        return
    end
    local strip = DAY.hint_strip
    local text = I18n.t(key)
    local size = Draw.fit_size(text, strip.w - 24, { SIZE.small, SIZE.tiny })
    local font = Draw.font(size)
    local pulse = 0.6 + 0.4 * math.sin(time * 4)
    if key == "trace.seal.hint" then            -- 은빛 인장 안내: 은청색 띠 + 인장 표식
        Draw.set_color(SealSigil.COLOR, 0.08 + 0.06 * pulse)
        LG.rectangle("fill", strip.x, strip.y + 2, strip.w, strip.h - 4, 6, 6)
        SealSigil.draw(strip.x + 10, strip.y + strip.h / 2, 7, 1, time, { glow = false })
        Draw.text(text, strip.x + 22, strip.y + (strip.h - font:getHeight()) / 2, strip.w - 24, "left", size, SealSigil.SILVER)
        return
    end
    Icons.draw("play", strip.x + 10, strip.y + strip.h / 2, 10, C.accent, pulse)
    Draw.text(text, strip.x + 22, strip.y + (strip.h - font:getHeight()) / 2, strip.w - 24, "left", size, C.text)
end

-- ambient: ui/AmbientEffects (주인장 반응 · 유물 튀어 오름, 없으면 정지 화면)
function WorkbenchView.draw(workshop, input, time, ambient)
    local area = DAY.workbench
    Frame.panel(area.x, area.y, area.w, area.h, {
        style = "wood", texture = "wood", texture_alpha = 0.3, fill_alpha = ART.panel_fill_alpha, title = I18n.t("bench.title", { name = workshop.owner_name }),
    })
    WorkbenchFlow.dividers()
    CustomerCard.draw(workshop, time, ambient)
    draw_bench(workshop, input, time, ambient)
    draw_appraisal_tag(workshop, ambient, time)
    draw_hint(workshop, input, time)
    FurnaceView.draw(workshop, input, time, ambient)          -- 용광로 구역 (ui/FurnaceView)
    WorkbenchFlow.ribbon(workshop, time)
    local x, y = input.pointer.x, input.pointer.y
    local over_bench = x >= area.x and x <= area.x + area.w and y >= area.y and y <= area.y + area.h
    if input.tool == "brush" and workshop:is_day() and over_bench then
        BenchTools.draw_brush(input, time)
    end
end

return WorkbenchView
