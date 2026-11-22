-- ui/WorkbenchFlow.lua
-- 낮 작업대의 시선 흐름 보조 (ui/WorkbenchView 가 부른다, 규칙 계산 없음 — 작업대 유물 상태만 읽는다):
--   · 구역 구분선: 손님 카운터 / 감정 줄 / 안내 띠 / 용광로 사이의 먹선 + 황동선
--   · 흐름 리본: 카운터와 감정 줄 사이 "1 손님 › 2 UV 감정 › 3 세척 › 4 강화" 상태 배지
--     (끝남 = 초록 체크 · 지금 할 일 = 금빛 맥동 · 아직 = 흐림)
--   · 가격표: 용광로 비용 줄 뒤에 어두운 칩을 깔아 금액 대비를 높인다

local I18n = require("systems.I18n")
local Draw = require("ui.Draw")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local WorkbenchFlow = {}

local C = UI.color
local DAY = LAYOUT.day
local LG = love.graphics
local INK = { 0.03, 0.02, 0.02 }
local BRASS = { 0.78, 0.60, 0.30 }
local STEPS = { "customer", "appraise", "clean", "forge" }
local CHIP_H = 18
local CHIP_GAP = 18

-- 단계별 상태: "done" | "now" | "todo"
local function states(workshop)
    local item = workshop.appraisal:bench_item()
    local furnace = workshop.forge:furnace_item()
    local result = { customer = "now", appraise = "todo", clean = "todo", forge = "todo" }
    if furnace ~= nil then
        return { customer = "done", appraise = "done", clean = "done", forge = "now" }
    elseif item == nil then
        return result
    end
    result.customer = "done"
    local scanned = item.owned or workshop.appraisal:scan_coverage(item) >= 1 or item.revealed.grade
    result.appraise = scanned and "done" or "now"
    if item.owned then
        result.clean = item.cleaned and "done" or "now"
        result.forge = item.cleaned and item:can_forge() and "now" or "todo"
    end
    return result
end

local function divider(y)
    local x1, x2 = DAY.workbench.x + 16, DAY.workbench.x + DAY.workbench.w - 16
    Draw.set_color(INK, 0.7)
    LG.setLineWidth(2)
    LG.line(x1, y, x2, y)
    Draw.set_color(BRASS, 0.45)
    LG.setLineWidth(1)
    LG.line(x1, y + 1.5, x2, y + 1.5)
end

function WorkbenchFlow.dividers()
    divider(DAY.bench_slot.y - 5)
    divider(DAY.hint_strip.y - 3)
    divider(DAY.furnace_section.y - 4)
end

function WorkbenchFlow.ribbon(workshop, time)
    local current = states(workshop)
    local labels, widths, total = {}, {}, 0
    local font = Draw.font("label")
    for i, id in ipairs(STEPS) do
        labels[i] = string.format("%d  %s", i, I18n.t("bench.flow_" .. id))
        widths[i] = font:getWidth(labels[i]) + (current[id] == "done" and 30 or 18)
        total = total + widths[i] + (i > 1 and CHIP_GAP or 0)
    end
    local area = DAY.workbench
    local x = area.x + (area.w - total) / 2
    local y = DAY.bench_slot.y - 5 - CHIP_H / 2
    for i, id in ipairs(STEPS) do
        local state, w = current[id], widths[i]
        local pulse = state == "now" and (0.6 + 0.4 * math.sin(time * 4)) or 1
        Draw.set_color(INK)
        LG.rectangle("fill", x - 1.5, y - 1.5, w + 3, CHIP_H + 3, 9, 9)
        Draw.set_color(state == "now" and { 0.32, 0.22, 0.08 } or { 0.10, 0.09, 0.09 })
        LG.rectangle("fill", x, y, w, CHIP_H, 8, 8)
        local edge = state == "done" and C.good or (state == "now" and C.gold or C.panel_border)
        Draw.set_color(edge, state == "todo" and 0.6 or pulse)
        LG.setLineWidth(state == "now" and 2 or 1)
        LG.rectangle("line", x + 0.5, y + 0.5, w - 1, CHIP_H - 1, 8, 8)
        local text_color = state == "todo" and C.text_disabled or (state == "now" and C.gold or C.text)
        Draw.label_text(labels[i], x + 9, y + (CHIP_H - font:getHeight()) / 2, w, "left", "label", text_color)
        if state == "done" then
            Draw.set_color(C.good)
            LG.setLineWidth(2)
            LG.line(x + w - 19, y + 9, x + w - 15, y + 13, x + w - 9, y + 5)
        end
        if i < #STEPS then
            Draw.label_text("›", x + w, y + (CHIP_H - font:getHeight()) / 2, CHIP_GAP, "center", "label", BRASS)
        end
        x = x + w + CHIP_GAP
    end
end

-- 용광로 비용 줄 뒤 가격표 칩
function WorkbenchFlow.price_tag(text, size, x, y, color)
    local font = Draw.font(size)
    local w, h = font:getWidth(text) + 14, font:getHeight() + 4
    Draw.set_color(INK, 0.85)
    LG.rectangle("fill", x - 7, y - 2, w, h, 5, 5)
    Draw.set_color(color, 0.7)
    LG.setLineWidth(1)
    LG.rectangle("line", x - 6.5, y - 1.5, w - 1, h - 1, 5, 5)
end

return WorkbenchFlow
