-- ui/FurnaceView.lua
-- 작업대 아래 용광로 구역 (ui/WorkbenchView 가 부른다, 좌표 LAYOUT.day.furnace_*). 규칙 계산 없음 — systems/Forge 에 묻는다.
--   왼쪽 용광로 칸: 열기 · 바닥 모루(ui_anvil) · 강화 중이면 박자 맞춰 두드리는 망치와 불티 · 유물
--   오른쪽 안내판: "+4 → +5 강화"(다음 등급 색) · 지금 내구도 · 비용 칩(골드 · 연마석 보유량) ·
--                  결과 확률 막대(성공 초록 · 유지 회색 · 하락 호박 · 파괴 붉은색)와 수치 · "성공 시 내구도 100% 복구 · 실패 시 그대로"
--   빈 용광로: 단계 규칙 요약과 +1~+10 성공률 · +10: 불멸 각인 안내 · 강화 중: 진행 막대

local I18n = require("systems.I18n")
local Draw = require("ui.Draw")
local Frame = require("ui.Frame")
local Slots = require("ui.Slots")
local ItemRenderer = require("ui.ItemRenderer")
local ItemStatus = require("ui.ItemStatus")
local ForgeTier = require("ui.ForgeTier")
local SpriteBank = require("ui.SpriteBank")
local WorkbenchFlow = require("ui.WorkbenchFlow")
local ART = require("data.art")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local FurnaceView = {}

local C = UI.color
local SIZE = UI.font_size
local LG = love.graphics
local DAY = LAYOUT.day
local INK = { 0.03, 0.02, 0.02 }
local FURNACE_FILL = { 0.13, 0.06, 0.05, 0.95 }
local ODDS_ORDER = { "success", "keep", "down", "destroy" }
FurnaceView.ODDS_COLORS = { success = C.good, keep = { 0.66, 0.66, 0.70 }, down = { 0.96, 0.66, 0.28 }, destroy = C.danger }
local ODDS = FurnaceView.ODDS_COLORS

local function percent(ratio)
    return math.floor(ratio * 100 + 0.5)
end

local function slot_frame(input)
    local x, y, w, h = Slots.rect("furnace", 1)
    Frame.inset(x, y, w, h, 10, { 0.16, 0.08, 0.06 })
    if input:is_drop_candidate("furnace", 1) then
        local target = input:drop_target() == "furnace"
        Draw.set_color(target and C.slot_hover or C.good, target and 1 or 0.35 + 0.2 * math.sin(input.time * 6))
        LG.setLineWidth(target and 3 or 2)
        LG.rectangle("line", x - 2, y - 2, w + 4, h + 4, 12, 12)
    elseif input:hovered_slot() == "furnace" and input:hovered_item() ~= nil then
        Draw.set_color(C.accent, 0.5)
        LG.setLineWidth(2)
        LG.rectangle("line", x - 1, y - 1, w + 2, h + 2, 11, 11)
    end
end

-- 용광로 칸 바닥 가운데 모루 + 강화 중이면 망치가 박자에 맞춰 두드리고 불티가 튄다. 원화가 없으면 생략
local function draw_anvil(x, y, w, h, progress, time)
    local anvil, spec = SpriteBank.image("ui_anvil"), ART.anvil
    if anvil == nil then
        return
    end
    local s = w * spec.width / anvil:getWidth()
    local top = y + h - spec.bottom - anvil:getHeight() * s
    LG.setColor(0, 0, 0, 0.45)
    LG.ellipse("fill", x + w / 2, y + h - spec.bottom, w * spec.width * 0.5, 4, 24)
    LG.setColor(1, 1, 1, 1)
    LG.draw(anvil, x + (w - w * spec.width) / 2, top, 0, s, s)
    local hammer = SpriteBank.image("cursor_hammer")
    if progress == nil or hammer == nil then
        return
    end
    local beat = (time * spec.beat) % 1                     -- 들어 올렸다(0) → 내려찍음(0.55) → 다시 들어 올림
    local down = beat < 0.55 and beat / 0.55 or 1 - (beat - 0.55) / 0.45
    local hs = spec.hammer_size / hammer:getWidth()
    LG.push()
    LG.translate(x + w - 4, y + 18)
    LG.rotate(-0.9 + down * 0.75)
    LG.setColor(1, 1, 1, 1)
    LG.draw(hammer, -0.92 * hammer:getWidth() * hs, -0.92 * hammer:getHeight() * hs, 0, hs, hs)
    LG.pop()
    if beat > 0.5 and beat < 0.62 then                      -- 내려찍는 순간 금빛·백색 불티
        for i = 1, 4 do
            local a = -math.pi / 2 + (i - 2.5) * 0.5
            Draw.set_color(i % 2 == 0 and C.gold or { 1, 1, 1 }, 1 - (beat - 0.5) * 8)
            LG.circle("fill", x + w / 2 + math.cos(a) * 18, top + math.sin(a) * 14, 1.8, 6)
        end
    end
end

-- 결과 확률 막대: 성공 · 유지 · 하락 · 파괴 비율대로 칸을 나눈다
function FurnaceView.draw_odds(odds, x, y, w, h)
    Draw.set_color(INK)
    LG.rectangle("fill", x - 1, y - 1, w + 2, h + 2, 3, 3)
    local cx = x
    for _, key in ipairs(ODDS_ORDER) do
        local part = odds[key] * w
        if part > 0.5 then
            Draw.set_color(ODDS[key])
            LG.rectangle("fill", cx, y, part, h)
            cx = cx + part
        end
    end
end

-- 확률 수치 한 줄: 성공 · (유지 또는 하락) · 파괴 — 0% 인 칸은 흐리게
local function draw_odds_labels(odds, x, y, w)
    local parts = { { "success", odds.success } }
    if odds.keep > 0 or odds.down <= 0 then
        parts[#parts + 1] = { "keep", odds.keep }
    end
    if odds.down > 0 then
        parts[#parts + 1] = { "down", odds.down }
    end
    parts[#parts + 1] = { "destroy", odds.destroy }
    local cell = w / #parts
    for i, part in ipairs(parts) do
        local text = I18n.t("bench.forge_odds_" .. part[1], { pct = percent(part[2]) })
        Draw.label_text(text, x + (i - 1) * cell, y, cell, "left", Draw.fit_size(text, cell - 4, { SIZE.small, SIZE.tiny }),
            ODDS[part[1]], part[2] > 0 and 1 or 0.45)
    end
end

local function chip(text, x, y, color)
    local font = Draw.font(SIZE.small)
    WorkbenchFlow.price_tag(text, SIZE.small, x, y, color)
    Draw.label_text(text, x, y, font:getWidth(text) + 4, "left", SIZE.small, color)
    return font:getWidth(text) + 18
end

local function draw_item_panel(workshop, forge, item, info, time)
    local state = item:durability_state()
    Draw.label_text(I18n.t("bench.forge_durability", { pct = math.floor(item.durability + 0.5) }), info.x, info.y + 3, info.w,
        "right", "label", ItemStatus.gauge_color(item))
    local odds = forge:odds(item)
    if odds == nil then                                     -- +10 불멸 각인
        Draw.label_text(I18n.t("bench.forge_immortal"), info.x, info.y + 30, info.w, "left",
            Draw.fit_size(I18n.t("bench.forge_immortal"), info.w, { "button", SIZE.small }), C.gold)
        Draw.label_text(I18n.t("bench.forge_immortal_note"), info.x, info.y + 56, info.w, "left", SIZE.small, C.text_dim)
        return
    end
    local tier = ForgeTier.of(item.level + 1)
    local step = I18n.t("bench.forge_step", { from = item.level, to = item.level + 1 })
    Draw.label_text(step, info.x, info.y + 24, info.w, "left", "button", tier and tier.color or C.text)
    local gold, stones = forge:cost(item)
    local short_gold, short_stones = workshop.gold < gold, workshop.tempering_stones < stones
    local x = info.x + 7
    x = x + chip(I18n.t("bench.forge_cost_gold", { gold = gold }), x, info.y + 48, short_gold and C.danger or C.gold)
    if stones > 0 then
        chip(I18n.t("bench.forge_cost_stones", { stones = stones, have = workshop.tempering_stones }), x, info.y + 48,
            short_stones and C.danger or C.stone)
    end
    FurnaceView.draw_odds(odds, info.x, info.y + 74, info.w, 9)
    draw_odds_labels(odds, info.x, info.y + 86, info.w)
    local rule = I18n.t("bench.forge_rule")
    Draw.label_text(rule, info.x, info.y + 108, info.w, "left", Draw.fit_size(rule, info.w, { SIZE.small, SIZE.tiny }),
        state == "broken" and C.danger or C.link_boost)
end

local function draw_empty_panel(forge, info)
    local chances = {}
    for i, chance in ipairs(forge:chances()) do
        chances[i] = tostring(percent(chance))
    end
    local lines = {
        { I18n.t("bench.furnace_hint"), C.text_dim },
        { I18n.t("bench.furnace_rules_1"), C.text },
        { I18n.t("bench.furnace_rules_2"), FurnaceView.ODDS_COLORS.down },
        { I18n.t("bench.furnace_chances", { chances = table.concat(chances, "·") }), C.text_dim },
        { I18n.t("bench.forge_rule"), C.link_boost },
    }
    for i, line in ipairs(lines) do
        Draw.label_text(line[1], info.x, info.y + 4 + i * 21, info.w, "left", Draw.fit_size(line[1], info.w, { SIZE.small, SIZE.tiny }),
            line[2])
    end
end

function FurnaceView.draw(workshop, input, time, ambient)
    local section = DAY.furnace_section
    local forge = workshop.forge
    local progress = forge:progress()
    Frame.inset(section.x, section.y, section.w, section.h, 10, FURNACE_FILL)
    local x, y, w, h = Slots.rect("furnace", 1)
    local heat = 0.25 + 0.08 * math.sin(time * 3) + (progress or 0) * 0.6
    local shake = progress and math.sin(time * 70) * 4 * progress or 0
    LG.push()
    LG.translate(shake, 0)
    slot_frame(input)
    LG.setBlendMode("add")
    Draw.set_color(C.furnace, heat * 0.8)
    LG.rectangle("fill", x + 8, y + h * 0.58, w - 16, h * 0.36, 8, 8)
    Draw.set_color(C.furnace, heat * 0.35)
    LG.circle("fill", x + w / 2, y + h * 0.72, w * 0.5, 32)
    LG.setBlendMode("alpha")
    draw_anvil(x, y, w, h, progress, time)
    local item = forge:furnace_item()
    if item ~= nil and not input:is_dragging(item) then
        ItemRenderer.draw(item, x + w / 2, y + h / 2 + (ambient and ambient:hop(item) or 0), DAY.furnace_slot.item_size,
            { time = time })
    end
    LG.pop()

    local info = DAY.furnace_info
    Draw.text(I18n.t("bench.furnace"), info.x, info.y, info.w, "left", "item_name", C.furnace)
    if progress ~= nil then
        Draw.label_text(I18n.t("bench.forging"), info.x, info.y + 30, info.w, "left", "button", C.accent)
        Draw.bar(info.x, info.y + 112, info.w, 10, progress, C.furnace)
    elseif item == nil then
        draw_empty_panel(forge, info)
    else
        draw_item_panel(workshop, forge, item, info, time)
    end
end

return FurnaceView
