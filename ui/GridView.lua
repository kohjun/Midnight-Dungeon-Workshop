-- ui/GridView.lua
-- 5x5 진열장 그리드(칸 타일 · 봉인 자물쇠 · 시너지 연결선·발광 · 골렘 거미줄 · 과부하 열기) 렌더링 (과부하 레버는 ui/OverclockLever).
-- 칸 좌표는 ui/Slots 의 지금 모드를 따른다 (낮 [진열장 배치] 탭 = LAYOUT.day.grid, 밤 = LAYOUT.night.grid).
-- 패널 테두리는 ui/DayLayoutView · ui/NightLayoutView 가 그린다. draw_slot 은 보관함 칸에도 쓴다.
-- 칸마다: 강화 등급 테두리(+5 황금 · +7 자홍 룬 · +9 심연, ui/ForgeTier) → 유물 → 아래쪽 내구도 게이지·완전 마모 덮개(ui/ItemStatus).
-- 진열장은 두 겹으로 그린다: 칸 타일 → 마력 도선 · 중앙 코어 표식(ui/ConduitView — 25칸을 상하좌우로 잇는 공명 회로) → 유물.
-- '스승의 흔적' 캠페인: 봉인 공명 슬롯 틀·점화 결계·공명선(ui/ResonanceView), 최종 보스의 룬 사슬 봉쇄(ui/RuneChainView).

local I18n = require("systems.I18n")
local Draw = require("ui.Draw")
local Frame = require("ui.Frame")
local Icons = require("ui.Icons")
local Slots = require("ui.Slots")
local ItemRenderer = require("ui.ItemRenderer")
local ItemStatus = require("ui.ItemStatus")
local ForgeTier = require("ui.ForgeTier")
local AmbientEffects = require("ui.AmbientEffects")
local ResonanceView = require("ui.ResonanceView")
local RuneChainView = require("ui.RuneChainView")
local SpriteBank = require("ui.SpriteBank")
local ConduitView = require("ui.ConduitView")
local ART = require("data.art")
local Grid = require("systems.Grid")
local ITEMS = require("data.items")
local UI = require("data.ui")

local GridView = {}

local C = UI.color
local SIZE = UI.font_size
local LG = love.graphics
local WEB_COLOR = { 0.88, 0.88, 0.92 }

-- 칸 바탕: 보관함 = 목재 상자 타일(ui_storage_slot), 진열장 = 철제·황동 소켓 타일(ui_grid_slot). 원화가 없으면 오목한 칸
local function draw_tile(area, x, y, w, h, shade)
    local name = ART.slot_tiles[area]
    local image = name and SpriteBank.image(name)
    if image == nil then
        Frame.inset(x, y, w, h, 6, shade and { 0.05, 0.05, 0.07 } or nil)
        return
    end
    local tone = shade or 0.86
    SpriteBank.draw_fit(image, x + w / 2, y + h / 2, math.max(w, h) * ART.slot_tiles.scale, { color = { tone, tone, tone } })
end

-- layer: nil = 한 번에 다 / "tile" = 칸 바탕만 / "item" = 강조 테두리와 유물만 (진열장은 그 사이에 마력 도선을 그린다)
function GridView.draw_slot(area, index, workshop, input, time, tint, layer)
    local x, y, w, h = Slots.rect(area, index)
    if layer ~= "item" then
        draw_tile(area, x, y, w, h)
        if tint ~= nil then
            Draw.set_color(tint[1], tint[2])
            LG.rectangle("fill", x, y, w, h, 6, 6)
        end
    end
    if layer == "tile" then
        return
    end
    local target_area, target_index = input:drop_target()
    local hover_area, hover_index = input:hovered_slot()
    local item = workshop.inventory:get(area, index)
    if target_area == area and target_index == index then     -- 놓을 칸: 금빛 채움 + 굵은 테두리 (타일 위에서도 또렷하게)
        Draw.set_color(C.slot_hover, 0.22)
        LG.rectangle("fill", x + 2, y + 2, w - 4, h - 4, 6, 6)
        Draw.set_color({ 0.03, 0.02, 0.02 })
        LG.setLineWidth(5)
        LG.rectangle("line", x - 1, y - 1, w + 2, h + 2, 7, 7)
        Draw.set_color(C.slot_hover)
        LG.setLineWidth(3)
        LG.rectangle("line", x - 1, y - 1, w + 2, h + 2, 7, 7)
    elseif input:is_drop_candidate(area, index) then          -- 드래그 중: 놓을 수 있는 칸을 초록으로 맥동
        local pulse = 0.5 + 0.3 * math.sin(time * 6 + index)
        Draw.set_color(C.good, 0.12 * pulse)
        LG.rectangle("fill", x + 3, y + 3, w - 6, h - 6, 6, 6)
        Draw.set_color(C.good, pulse)
        LG.setLineWidth(2.5)
        LG.rectangle("line", x + 1.5, y + 1.5, w - 3, h - 3, 6, 6)
    elseif input.drag == nil and hover_area == area and hover_index == index and item ~= nil then
        Draw.set_color(C.accent, 0.55)
        LG.setLineWidth(2)
        LG.rectangle("line", x, y, w, h, 6, 6)
    end
    if item ~= nil and not input:is_dragging(item) then
        ForgeTier.frame(item.level, x, y, w, h, time)
        local cy, scale = y + h / 2, 1
        if area == "grid" and Slots.mode() == "night" then     -- 밤: 칸마다 다른 위상으로 부유 + 발사 직전 충전
            cy = cy + AmbientEffects.levitation(index, time)
            local glow
            scale, glow = AmbientEffects.charge_pose(item:is_weapon() and workshop.combat:charge(item) or 0)
            if glow > 0 then
                Draw.glow(x + w / 2, cy, w * 0.6, ITEMS.elements[item.element].color, glow)
            end
        end
        ItemRenderer.draw(item, x + w / 2, cy, Slots.item_size(area), { time = time, scale = scale })
        ItemStatus.draw(item, x, y, w, h, time)
    end
end

local function draw_links(workshop, time)
    local links = workshop:grid_stats().links
    local glowing = {}
    for _, link in ipairs(links) do                -- 시너지에 걸린 칸: 속성(연결) 색 테두리 발광
        local color = link.kind == "curse" and C.link_curse or C.link_boost
        glowing[link.from], glowing[link.to] = color, color
    end
    for index, color in pairs(glowing) do
        local x, y, w, h = Slots.rect("grid", index)
        local pulse = 0.55 + 0.3 * math.sin(time * 3 + index)
        Draw.set_color(color, 0.18 * pulse)
        LG.setLineWidth(7)
        LG.rectangle("line", x + 1, y + 1, w - 2, h - 2, 8, 8)
        Draw.set_color(color, 0.8 * pulse)
        LG.setLineWidth(2)
        LG.rectangle("line", x + 1, y + 1, w - 2, h - 2, 7, 7)
    end
    for i, link in ipairs(links) do
        local x1, y1 = Slots.center("grid", link.from)
        local x2, y2 = Slots.center("grid", link.to)
        local color = link.kind == "curse" and C.link_curse or C.link_boost
        local pulse = 0.55 + 0.35 * math.sin(time * 4 + i)
        Draw.set_color(color, 0.22 * pulse)
        LG.setLineWidth(10)
        LG.line(x1, y1, x2, y2)
        Draw.set_color(color, pulse)
        LG.setLineWidth(2.5)
        LG.line(x1, y1, x2, y2)
        local t = (time * 0.9 + i * 0.37) % 1
        Draw.set_color(color)
        LG.circle("fill", x1 + (x2 - x1) * t, y1 + (y2 - y1) * t, 4, 12)
    end
end

-- 봉인된 칸: 어둡게 덮고 자물쇠 표시 (드래그 대상이면 붉은 테두리)
local function draw_sealed(index, input)
    local x, y, w, h = Slots.rect("grid", index)
    draw_tile("grid", x, y, w, h, 0.32)
    Draw.set_color({ 0.22, 0.22, 0.27 }, 0.6)
    LG.setLineWidth(1)
    for i = 1, 3 do
        LG.line(x + i * w / 4, y + 4, x + i * w / 4 - 8, y + h - 4)
    end
    Icons.draw("lock", x + w / 2, y + h / 2, 22, { 0.45, 0.42, 0.38 })
    local target_area, target_index = input:drop_target()
    if target_area == "grid" and target_index == index then
        Draw.set_color(C.danger)
        LG.setLineWidth(3)
        LG.rectangle("line", x - 1, y - 1, w + 2, h + 2, 7, 7)
    end
end

-- 골렘의 거미줄: 칸을 덮는 실 + 남은 클릭 수 (클릭해서 걷어 낸다)
local function draw_web(index, left, time)
    local x, y, w, h = Slots.rect("grid", index)
    local cx, cy = x + w / 2, y + h / 2
    Draw.set_color({ 0.05, 0.05, 0.07 }, 0.55)
    LG.rectangle("fill", x, y, w, h, 6, 6)
    Draw.set_color(WEB_COLOR, 0.85)
    LG.setLineWidth(1.5)
    for i = 0, 7 do
        local a = i / 8 * math.pi * 2
        LG.line(cx, cy, cx + math.cos(a) * w * 0.55, cy + math.sin(a) * h * 0.55)
    end
    for ring = 1, 3 do
        local radius = ring * w * 0.15
        local points = {}
        for i = 0, 8 do
            local a = i / 8 * math.pi * 2
            points[#points + 1] = cx + math.cos(a) * radius
            points[#points + 1] = cy + math.sin(a) * radius
        end
        LG.line(points)
    end
    local pulse = 0.6 + 0.4 * math.sin(time * 6)
    Draw.shadow_text(string.format("x%d", left), x, y + h - 20, w - 6, "right", "button", C.accent, pulse)
end

-- 진열장 칸 전부 (지금 모드의 좌표)
function GridView.draw_grid(workshop, input, time)
    local overclock = workshop.combat.overclock
    local heat = overclock and (0.18 + 0.12 * math.sin(time * 10)) or 0
    for index = 1, Grid.SIZE do
        if workshop:is_cell_open(index) then
            GridView.draw_slot("grid", index, workshop, input, time, overclock and { C.overclock, heat } or nil, "tile")
        else
            draw_sealed(index, input)
        end
    end
    ConduitView.draw(workshop, time)                     -- 마력 도선 · 중앙 코어 표식 (타일 위 · 유물 아래)
    for index = 1, Grid.SIZE do
        if workshop:is_cell_open(index) then
            GridView.draw_slot("grid", index, workshop, input, time, nil, "item")
        end
    end
    ResonanceView.draw(workshop, time)                   -- 봉인 공명 슬롯 (캠페인 런에서만)
    draw_links(workshop, time)
    RuneChainView.draw(workshop.combat.chains, time)     -- 룬 사슬 봉쇄 (최종 보스)
    for index, left in pairs(workshop.combat.webs) do
        draw_web(index, left, time)
    end
    if overclock then
        local x, y, w, h = Slots.grid_bounds()
        Draw.set_color(C.overclock, 0.5 + 0.4 * math.sin(time * 14))
        LG.setLineWidth(4)
        LG.rectangle("line", x - 6, y - 6, w + 12, h + 12, 8, 8)
    end
end

return GridView
