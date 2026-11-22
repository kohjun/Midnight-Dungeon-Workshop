-- ui/NightLayoutView.lua
-- 밤(방어) 화면 배치 (좌표 LAYOUT.night). 낮의 손님 카운터·작업대·상점은 모두 숨긴다.
--   왼쪽 36% : 확대된 5x5 진열장(ui/GridView — 무기·내구도·시너지 연결선·골렘 거미줄 클릭) + 기계식 과부하 레버(ui/OverclockLever)
--   오른쪽 64%: 와이드 전투 레인(ui/LaneView — 방벽·포탈·몬스터·보스)
-- 무기 공격 연출(ui/AttackEffects)은 진열장과 레인 위에 그린다: 투사체·광선은 무기가 놓인 칸의 정중앙에서 나간다.
-- 몬스터에 마우스를 올리면 그 위에 양피지 툴팁(ui/MonsterTooltip)을 그린다.

local I18n = require("systems.I18n")
local Frame = require("ui.Frame")
local GridView = require("ui.GridView")
local LaneView = require("ui.LaneView")
local OverclockLever = require("ui.OverclockLever")
local MonsterTooltip = require("ui.MonsterTooltip")
local Grid = require("systems.Grid")
local ART = require("data.art")
local LAYOUT = require("data.layout")

local NightLayoutView = {}

local NIGHT = LAYOUT.night

-- layers: { attacks = ui/AttackEffects, motion = ui/EntityMotion } (RunState 소유)
function NightLayoutView.draw(workshop, input, time, layers)
    LaneView.draw(workshop, time, layers.motion)
    local panel = NIGHT.grid_panel
    Frame.panel(panel.x, panel.y, panel.w, panel.h, {
        style = "iron", texture = "stone", texture_alpha = 0.45, fill_alpha = ART.panel_fill_alpha,
        title = I18n.t("grid.board", { stage = Grid.stage_label(workshop.upgrades:grid_stage()) }),
    })
    GridView.draw_grid(workshop, input, time)
    OverclockLever.draw(workshop, input, time, NIGHT.lever_panel)
    layers.attacks:draw(workshop.combat)
    if input.drag == nil then
        MonsterTooltip.draw_hovered(workshop.combat, input.pointer)
    end
end

return NightLayoutView
