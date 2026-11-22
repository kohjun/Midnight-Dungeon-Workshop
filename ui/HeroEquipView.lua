-- ui/HeroEquipView.lua
-- 낮 화면 오른쪽 위 (예전 보관함 자리, LAYOUT.day.storage_section): 주인공 4부위 장비창 + 임시 거치대 3칸.
--   왼쪽  : 주인공 장비 — 무기 · 투구 · 갑옷 · 신발 칸 (Inventory "hero" 1~4, systems/HeroEquip). 빈 칸에는 그 부위의
--           실루엣, 칸 아래에 부위 라벨, 그 아래 핵심 스탯 요약 줄 (HP / 공격력 / 방어력 / 이동속도 — systems/HeroStats)
--   오른쪽: 임시 거치대 3칸 (Inventory "storage") — 방어구 교체 · 강화 대기 · 진열장 만석 때 잠시 두는 곳
-- 칸 그리기(타일 · 유물 · 내구도 게이지 · 놓을 칸 강조)는 ui/GridView.draw_slot 을 그대로 쓴다. 좌표는 ui/Slots.
-- 주인공 전용 툴팁(스탯 · 4부위 · 스킬)은 ui/HoverTooltip 의 "hero" 영역 (제목 줄 · 스탯 요약 줄).

local I18n = require("systems.I18n")
local HeroStats = require("systems.HeroStats")
local HeroEquip = require("systems.HeroEquip")
local Draw = require("ui.Draw")
local Frame = require("ui.Frame")
local Slots = require("ui.Slots")
local GridView = require("ui.GridView")
local HeroText = require("ui.HeroText")
local ItemShapes = require("ui.ItemShapes")
local ItemShapesArmor = require("ui.ItemShapesArmor")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local HeroEquipView = {}

local LG = love.graphics
local C = UI.color
local SIZE = UI.font_size
local DAY = LAYOUT.day
local SECTION_FILL = { 0.08, 0.07, 0.09, 0.92 }
local GHOST = { 0.62, 0.56, 0.46 }
local SILHOUETTE = {
    weapon = ItemShapes.SHAPES.sword, helmet = ItemShapesArmor.helmet, chest = ItemShapesArmor.chest, boots = ItemShapesArmor.boots,
}
local PALETTE = { primary = GHOST, accent = GHOST }

-- 빈 칸: 그 부위의 흐린 실루엣
local function draw_ghost(slot, x, y, w, h)
    LG.push()
    LG.translate(x + w / 2, y + h / 2)
    LG.scale(w * 0.66)
    Draw.set_color(GHOST, 0.38)
    SILHOUETTE[slot](PALETTE, true)
    LG.pop()
end

-- 스탯 요약 줄이 놓이는 사각형 (HoverTooltip 의 주인공 툴팁 영역)
function HeroEquipView.stats_rect()
    return DAY.hero_stats
end

function HeroEquipView.draw(workshop, input, time)
    local section = DAY.storage_section
    Frame.inset(section.x, section.y, section.w, section.h, 10, SECTION_FILL)
    local hero, rack = DAY.hero_slots, DAY.storage_slots
    local hero_w = #HeroEquip.SLOTS * (hero.size + hero.gap) - hero.gap
    local rack_w = Slots.storage_count() * (rack.size + rack.gap) - rack.gap
    Draw.text(I18n.t("hero.panel_title"), hero.x, section.y + 5, hero_w, "left", "item_name", C.text)
    local rack_title = I18n.t("hero.rack_title", { count = workshop.inventory:count("storage"), max = Slots.storage_count() })
    Draw.text(rack_title, rack.x, section.y + 8, rack_w, "left", Draw.fit_size(rack_title, rack_w, { SIZE.small, SIZE.tiny }), C.text_dim)

    Draw.set_color(C.panel_border, 0.55)                 -- 장비창 | 거치대 구분선
    LG.setLineWidth(1)
    local divider = (hero.x + hero_w + rack.x) / 2
    LG.line(divider, section.y + 26, divider, section.y + section.h - 12)

    for index, slot in ipairs(HeroEquip.SLOTS) do
        GridView.draw_slot("hero", index, workshop, input, time, nil, "tile")
        local x, y, w, h = Slots.rect("hero", index)
        local item = workshop.inventory:get("hero", index)
        if item == nil or input:is_dragging(item) then
            draw_ghost(slot, x, y, w, h)
        end
        GridView.draw_slot("hero", index, workshop, input, time, nil, "item")
        Draw.text(I18n.t("hero.slots." .. slot), x - 4, y + h + 2, w + 8, "center", SIZE.tiny,
            item ~= nil and item:grade_info().color or C.text_dim)
    end
    for index = 1, Slots.storage_count() do
        GridView.draw_slot("storage", index, workshop, input, time)
    end
    local _, rack_y, _, rack_h = Slots.rect("storage", 1)
    Draw.text(I18n.t("hero.rack_hint"), rack.x, rack_y + rack_h + 2, rack_w, "center", SIZE.tiny, C.text_dim)

    local box = DAY.hero_stats
    local summary = HeroText.summary(HeroStats.compute(workshop))
    Draw.text(summary, box.x, box.y, box.w, "center", Draw.fit_size(summary, box.w, { SIZE.small, SIZE.tiny }), C.accent)
end

return HeroEquipView
