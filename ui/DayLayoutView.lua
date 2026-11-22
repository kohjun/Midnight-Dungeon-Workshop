-- ui/DayLayoutView.lua
-- 낮(영업) 화면 배치 (좌표 LAYOUT.day). 전투 레인·과부하 레버는 없다 (레버는 밤 화면에만).
--   왼쪽 55%  : 대형 작업대 (ui/WorkbenchView — 손님 카운터(모험가 프로필)·감정·세척·용광로)
--   오른쪽 45%: 탭 없이 한 화면 — 위 공방 보관함 4칸 / 아래 5x5 진열장(ui/GridView) + 시너지 미리보기 띠.
--              보관함 ↔ 진열장 ↔ 작업대·용광로 사이로 바로 끌어 옮긴다.
-- 길드 보급 상점·결계 유지비 현황은 [길드] 창(ui/GuildModal), 암시장·길드 의뢰는 [의뢰] 창(ui/QuestModal).
-- 규칙 계산 없음: 시스템 상태(grid_stats)를 읽기만 한다.

local I18n = require("systems.I18n")
local Draw = require("ui.Draw")
local Frame = require("ui.Frame")
local Slots = require("ui.Slots")
local GridView = require("ui.GridView")
local WorkbenchView = require("ui.WorkbenchView")
local Grid = require("systems.Grid")
local ART = require("data.art")
local LAYOUT = require("data.layout")
local UI = require("data.ui")
local HeroEquipView = require("ui.HeroEquipView")

local DayLayoutView = {}

local C = UI.color
local SIZE = UI.font_size
local DAY = LAYOUT.day
local SECTION_FILL = { 0.08, 0.07, 0.09, 0.92 }

-- 시너지 미리보기 띠: 가리킨 진열 유물의 유효 스탯·보너스, 아니면 진열장 요약
local function draw_synergy(workshop, input)
    local box = DAY.synergy
    local x, w = box.x, box.w
    local stats = workshop:grid_stats()
    local item, area = input:hovered_item()
    local stat = area == "grid" and item ~= nil and stats.stats[item] or nil
    if stat == nil then
        local weapons, income = 0, 0
        for _, placed in ipairs(stats.order) do
            weapons = weapons + (placed:is_weapon() and 1 or 0)
            income = income + stats.stats[placed].income
        end
        local summary = I18n.t("synergy.summary", { weapons = weapons, others = #stats.order - weapons, links = #stats.links,
            income = income })
        Draw.text(summary, x, box.y, w, "center", Draw.fit_size(summary, w, { SIZE.small, SIZE.tiny }), C.accent)
        Draw.text(I18n.t("synergy.hint"), x, box.y + 20, w, "center", SIZE.tiny, C.text_dim)
        return
    end
    local line = item:is_weapon()
        and I18n.t("synergy.weapon", { attack = string.format("%.1f", stat.attack), rate = string.format("%.2g", stat.fire_rate),
            income = stat.income })
        or I18n.t("synergy.relic", { income = stat.income })
    local head = I18n.item_name(item) .. "  ·  " .. line
    Draw.text(head, x, box.y, w, "center", Draw.fit_size(head, w, { SIZE.small, SIZE.tiny }), item:grade_info().color)
    local bonuses = #stat.bonuses > 0 and table.concat(stat.bonuses, "  ·  ") or I18n.t("synergy.none")
    Draw.text(bonuses, x, box.y + 20, w, "center", Draw.fit_size(bonuses, w, { SIZE.tiny }),
        #stat.bonuses > 0 and C.link_boost or C.text_dim)
end

-- 진열장 머리줄 제목이 쓸 수 있는 폭 ('스승의 흔적'이면 오른쪽 [수기] 버튼 앞까지) — 좁으면 글자를 줄인다
DayLayoutView.TITLE_SIZES = { "item_name", SIZE.small, SIZE.tiny }
function DayLayoutView.grid_title_width(campaign)
    local section = DAY.grid_section
    return campaign and LAYOUT.buttons.journal.x - 6 - (section.x + 16) or section.w - 32
end

local function draw_grid_section(workshop, input, time)
    local section = DAY.grid_section
    Frame.inset(section.x, section.y, section.w, section.h, 10, SECTION_FILL)
    local title = I18n.t("grid.board", { stage = Grid.stage_label(workshop.upgrades:grid_stage()) })
    local width = DayLayoutView.grid_title_width(workshop.master_trace ~= nil)
    Draw.text(title, section.x + 16, section.y + 6, width, "left", Draw.fit_size(title, width, DayLayoutView.TITLE_SIZES), C.text)
    GridView.draw_grid(workshop, input, time)
    draw_synergy(workshop, input)
end

-- ambient: ui/AmbientEffects (주인장 반응 · 유물 튀어 오름 · 금빛 먼지)
function DayLayoutView.draw(workshop, input, time, ambient)
    WorkbenchView.draw(workshop, input, time, ambient)
    if ambient ~= nil then
        ambient:draw_forge(time)            -- 용광로 오버클럭 가열·대성공 배너·파괴 균열 (ui/ForgeDrama)
    end
    local panel = DAY.panel
    Frame.panel(panel.x, panel.y, panel.w, panel.h, {
        style = "iron", texture = "stone", texture_alpha = 0.45, fill_alpha = ART.panel_fill_alpha,
    })
    HeroEquipView.draw(workshop, input, time)      -- 주인공 4부위 장비창 + 임시 거치대 3칸 (예전 보관함 자리)
    draw_grid_section(workshop, input, time)
    if ambient ~= nil then
        ambient:draw_motes()
    end
end

return DayLayoutView
