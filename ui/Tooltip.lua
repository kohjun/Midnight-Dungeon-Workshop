-- ui/Tooltip.lua
-- 유물 호버 툴팁: 이름·등급·분류·공격력·연사·강화·내구도·오염·결함·시너지 보너스·가격/일일 수익.
-- '스승의 흔적' 캠페인의 봉인 공명 슬롯(ui/ResonanceView): 슬롯 위 유물이면 슬롯 이름·점화 상태·조건 줄을 덧붙이고,
-- 빈 슬롯이면 슬롯 안내만 담은 작은 상자를 띄운다.

local Viewport = require("core.Viewport")
local I18n = require("systems.I18n")
local Draw = require("ui.Draw")
local ItemStatus = require("ui.ItemStatus")
local ResonanceView = require("ui.ResonanceView")
local ConduitView = require("ui.ConduitView")
local HeroText = require("ui.HeroText")
local BALANCE = require("data.balance")
local ITEMS = require("data.items")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local Tooltip = {}

local C = UI.color
local SEAL_COLOR = { 0.70, 0.84, 1.0 }      -- 스승의 은빛 인장 줄 (은청색)
local SIZE = UI.font_size
local LINE_GAP = 3

local function percent_bonus(mult)
    local percent = math.floor((mult - 1) * 100 + 0.5)
    if percent == 0 then
        return ""
    end
    return string.format(" (%+d%%)", percent)
end

local function add(lines, text, color, size)
    lines[#lines + 1] = { text = text, color = color or C.text, size = size or SIZE.small }
end

local function grade_line(item)
    if item.revealed.grade then
        return I18n.t("tooltip.grade", { grade = I18n.grade(item.grade) }), item:grade_info().color
    end
    return I18n.t("tooltip.grade_unknown", { grade = I18n.grade(item.claimed_grade) }), C.text_dim
end

local function flaw_line(item)
    local flaw = item:flaw_info()
    if flaw ~= nil and item.revealed.flaw and item:is_armor() then      -- 방어구의 결함은 효과가 다르다
        return I18n.t("hero.flaws." .. item.flaw), C.danger
    elseif flaw ~= nil and item.revealed.flaw then
        local prefix = "flaws." .. item.flaw
        return I18n.t("tooltip.flaw", { name = I18n.t(prefix .. ".name"), summary = I18n.t(prefix .. ".summary") }), C.danger
    elseif item.revealed.complete then
        return I18n.t("tooltip.flaw_none"), C.good
    end
    return I18n.t("tooltip.flaw_unknown"), C.text_dim
end

local function combat_lines(lines, item, stat)
    if not item:is_weapon() then
        return
    end
    local attack = stat and stat.attack or item:attack()
    local rate = stat and stat.fire_rate or item:fire_rate()
    add(lines, I18n.t("tooltip.attack", {
        value = string.format("%.1f", attack), bonus = stat and percent_bonus(stat.attack_mult) or "",
    }))
    add(lines, I18n.t("tooltip.fire_rate", {
        value = string.format("%.2f", rate), bonus = stat and percent_bonus(stat.rate_mult) or "",
    }))
end

-- stat: 그리드 위 유물이면 Grid.compute_stats 결과 항목, 아니면 nil. workshop: 판매가 계산용
function Tooltip.lines(item, stat, workshop)
    local lines = {}
    local name_color = item.revealed.grade and item:grade_info().color or C.text
    local name = I18n.item_name(item)
    if item.level > 0 then
        name = I18n.t("tooltip.name_level", { name = name, level = item.level })
    end
    add(lines, name, name_color, "tooltip_name")
    add(lines, grade_line(item))
    if item:is_armor() then
        add(lines, HeroText.category_line(item), C.text_dim)
    else
        add(lines, I18n.t("tooltip.category", {
            category = I18n.t("categories." .. item:role()), element = I18n.t("elements." .. item.element),
        }), C.text_dim)
    end
    local archetype = ITEMS.archetypes[item.proto.archetype]
    if archetype ~= nil then
        add(lines, I18n.t("tooltip.archetype", { name = I18n.t("archetypes." .. item.proto.archetype) }), archetype.color)
    end
    combat_lines(lines, item, stat)
    for _, line in ipairs(item:is_armor() and HeroText.armor_lines(item) or {}) do
        add(lines, line.text, line.color)
    end
    if item.owned then          -- 내구도 72% + 상태 (마모 위험 · 완전 마모 · 불멸)
        local state = item:durability_state()
        add(lines, I18n.t("tooltip.durability_" .. state, { pct = math.floor(item.durability + 0.5) }),
            ItemStatus.gauge_color(item))
    end
    if item.cleaned then
        local mult = item.clean_mult or BALANCE.appraisal.clean_mult
        add(lines, I18n.t("tooltip.cleaned", { mult = string.format("%.2g", mult) }), C.good)
    else
        add(lines, I18n.t("tooltip.contamination", { percent = math.ceil(item.contamination) }), C.accent)
    end
    add(lines, flaw_line(item))
    if item.silver_seal ~= nil and item.revealed.seal then        -- '스승의 흔적' 은빛 인장 (UV 로 찾은 것만)
        add(lines, I18n.t("trace.seal.tag") .. " · " .. I18n.t(item.silver_seal.claimed and "trace.seal.claimed"
            or "trace.seal.tag_value"), SEAL_COLOR)
    end
    add(lines, I18n.item_description(item), C.text_dim)
    add(lines, HeroText.place_line(item), C.text_dim)       -- 3분류 배치 안내
    if stat ~= nil then
        for _, bonus in ipairs(stat.bonuses) do
            add(lines, I18n.t("tooltip.bonus", { text = bonus }), C.link_boost)
        end
    end
    if not item.owned then
        add(lines, I18n.t("tooltip.asking_price", { price = item:asking_price() }), C.gold, SIZE.body)
    elseif item:is_armor() then
        add(lines, I18n.t("tooltip.sale_only", { price = workshop:sale_price(item) }), C.gold)
    else
        local income = stat and stat.income or item:base_income()
        local key = stat and "tooltip.sale_income" or "tooltip.sale_income_shelf"
        add(lines, I18n.t(key, { price = workshop:sale_price(item), income = income }), C.gold)
    end
    local area, index = nil, nil
    if workshop ~= nil then
        area, index = workshop.inventory:locate(item)
    end
    for _, line in ipairs(area == "grid" and ResonanceView.slot_lines(workshop, index, item) or {}) do
        add(lines, line.text, line.color, line.size)     -- 봉인 공명 슬롯 위 유물: 슬롯 · 점화 상태 · 조건
    end
    for _, line in ipairs(area == "grid" and ConduitView.core_lines(index) or {}) do
        add(lines, line.text, line.color, line.size)     -- 정중앙 직접 동조 슬롯 (중앙 코어)
    end
    return lines
end

function Tooltip.draw(item, stat, pointer_x, pointer_y, workshop)
    local accent = item.revealed.grade and ITEMS.grades[item.grade].color or C.panel_border
    Tooltip.draw_box(Tooltip.lines(item, stat, workshop), pointer_x, pointer_y, accent)
end

-- 줄 목록 { text, color, size } 을 커서 옆 상자에 (accent = 위 띠·테두리 색). 화면 밖으로 나가지 않게 옮긴다
function Tooltip.draw_box(lines, pointer_x, pointer_y, accent)
    local layout = LAYOUT.tooltip
    local width, pad = layout.width, layout.padding
    local inner = width - pad * 2

    local height = pad * 2
    for _, line in ipairs(lines) do
        local font = Draw.font(line.size)
        local _, wrapped = font:getWrap(line.text, inner)
        line.height = math.max(1, #wrapped) * font:getHeight()
        height = height + line.height + LINE_GAP
    end

    local screen_w, screen_h = Viewport.width(), Viewport.height()
    local x = pointer_x + layout.offset
    local y = pointer_y + layout.offset
    if x + width > screen_w - 8 then
        x = pointer_x - layout.offset - width
    end
    y = math.max(8, math.min(y, screen_h - height - 8))

    Draw.set_color({ 0, 0, 0 }, 0.45)
    love.graphics.rectangle("fill", x + 4, y + 6, width, height, 8, 8)
    Draw.set_color({ 0.05, 0.04, 0.06 }, 0.96)
    love.graphics.rectangle("fill", x, y, width, height, 8, 8)
    Draw.set_color(accent, 0.35)
    love.graphics.rectangle("fill", x, y, width, 4, 2, 2)
    Draw.set_color(accent)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1, 8, 8)
    Draw.set_color({ 0, 0, 0 }, 0.6)
    love.graphics.rectangle("line", x + 3.5, y + 3.5, width - 7, height - 7, 6, 6)

    local cursor = y + pad
    for _, line in ipairs(lines) do
        Draw.text(line.text, x + pad, cursor, inner, "left", line.size, line.color)
        cursor = cursor + line.height + LINE_GAP
    end
end

-- 입력 컨트롤러가 가리키는 유물이 있으면 툴팁 표시 (빈 봉인 공명 슬롯이면 슬롯 안내 상자)
function Tooltip.draw_hovered(workshop, input)
    local item, area, index = input:hovered_item()
    if item == nil then
        local lines, accent = nil, nil
        if area == "grid" and workshop:is_cell_open(index) then
            lines, accent = ResonanceView.slot_lines(workshop, index)
            if lines == nil then
                lines, accent = ConduitView.core_lines(index)      -- 빈 중앙 코어: 직접 동조 슬롯 안내
            end
        end
        if lines ~= nil then
            Tooltip.draw_box(lines, input.pointer.x, input.pointer.y, accent)
        end
        return
    end
    local stat = nil
    if area == "grid" then
        stat = workshop:grid_stats().stats[item]
    end
    Tooltip.draw(item, stat, input.pointer.x, input.pointer.y, workshop)
end

return Tooltip
