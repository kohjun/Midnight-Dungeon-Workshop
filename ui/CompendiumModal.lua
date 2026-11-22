-- ui/CompendiumModal.lua
-- [유물 도감] 창 (타이틀 메뉴 · 인게임 상단 바에서 연다. 인게임에서는 열려 있는 동안 게임이 멈춘다).
--   왼쪽: 아키타입별 한 줄 — 기본 유물(분류 순) 뒤에 업적으로 해금되는 특수 유물(금테, 봉인 시 실루엣·자물쇠)
--   오른쪽: 가리키거나 클릭한 유물의 상세 (ui/CompendiumDetail)
--   아래: 엔딩 수집 두 줄 (ui/CompendiumEndings) — 일반 엔딩 3종 / '스승의 흔적' 엔딩 2종 + 진엔딩 훈장.
--         인게임(open(workshop))에서는 이번 계약의 기준 한 줄을 더 보여 준다 (systems/Endings.status — 일반 계약은 상권 독점
--         카드 위에 골드 · 방벽 %, '스승의 흔적' 계약은 캠페인 머리글 옆에 봉인진 · 수기 진행). 타이틀 메뉴(open())에서는 일반 조건만.
-- 해금·엔딩 기록은 systems/MetaProgression (save_meta.lua), 진엔딩 훈장은 systems/Progress. ESC / [닫기] 로 닫는다.
-- 좌표: CompendiumModal.cell_rect(row, col) / close_rect() (스모크 테스트용). target_text(): 이번 계약 기준 문구 또는 nil.

local Class = require("lib.classic")
local Tween = require("lib.tween")
local Input = require("core.Input")
local Viewport = require("core.Viewport")
local Item = require("entities.Item")
local I18n = require("systems.I18n")
local ItemFactory = require("systems.ItemFactory")
local MetaProgression = require("systems.MetaProgression")
local Endings = require("systems.Endings")
local Button = require("ui.Button")
local Draw = require("ui.Draw")
local Frame = require("ui.Frame")
local CursorManager = require("ui.CursorManager")
local Lettering = require("ui.Lettering")
local ItemRenderer = require("ui.ItemRenderer")
local CompendiumDetail = require("ui.CompendiumDetail")
local CompendiumEndings = require("ui.CompendiumEndings")
local ITEMS = require("data.items")
local ACHIEVEMENTS = require("data.achievements")
local ENDINGS = require("data.endings")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local CompendiumModal = Class:extend()

local C = UI.color
local SIZE = UI.font_size
local L = LAYOUT.compendium
local HOVER_PRIORITY = 1
local CATEGORY_RANK = {}
for rank, id in ipairs(ITEMS.role_order) do            -- 무기 → 증폭기 → 유물 (세부 구분)
    CATEGORY_RANK[id] = rank
end
local function role(proto)
    return proto.subtype or proto.category
end
local RELIC_ACHIEVEMENT = {}
for _, id in ipairs(ACHIEVEMENTS.order) do
    RELIC_ACHIEVEMENT[ACHIEVEMENTS.list[id].relic] = id
end

function CompendiumModal.cell_rect(row, col)
    local x = L.x + L.grid_x + L.label_w + (col - 1) * (L.cell + L.gap)
    local y = L.y + L.grid_y + (row - 1) * L.row_h + (L.row_h - L.cell) / 2
    return { x = x, y = y, w = L.cell, h = L.cell }
end

function CompendiumModal.close_rect()
    return { x = L.x + (L.w - L.close_w) / 2, y = L.y + L.h - L.close_h - 16, w = L.close_w, h = L.close_h }
end

-- 엔딩 카드 영역 (index = data/endings.lua 의 order 순서 — 카드 배치는 ui/CompendiumEndings)
function CompendiumModal.ending_rect(index)
    return CompendiumEndings.ending_rect(ENDINGS.order[index])
end

-- 아키타입마다: 특수 유물이 아닌 것(분류 → id 순) → 특수 유물(id 순)
local function sorted_row(archetype)
    local ids = {}
    for id, proto in pairs(ITEMS.prototypes) do
        if proto.archetype == archetype then
            ids[#ids + 1] = id
        end
    end
    table.sort(ids, function(a, b)
        local pa, pb = ITEMS.prototypes[a], ITEMS.prototypes[b]
        if (pa.special == true) ~= (pb.special == true) then
            return not pa.special
        end
        if role(pa) ~= role(pb) then
            return CATEGORY_RANK[role(pa)] < CATEGORY_RANK[role(pb)]
        end
        return a < b
    end)
    return ids
end

-- workshop: 인게임에서 연 경우의 공방 (없으면 타이틀 메뉴의 도감)
function CompendiumModal.open(workshop)
    return CompendiumModal(workshop)
end

function CompendiumModal:new(workshop)
    self.kind = "compendium"
    self.closed = false
    self._ending_status = workshop ~= nil and Endings.status(workshop) or nil   -- 열려 있는 동안 게임이 멈춰 있으니 한 번만
    self._time = 0
    self._anim = { scale = 0.94, alpha = 0 }
    self._tweens = Tween.Group()
    self._tweens:to(self._anim, 0.22, { scale = 1, alpha = 1 }):ease("out_back")
    local unlocked = MetaProgression.unlocked_relics()
    self._rows = {}
    self._unlocked_count = 0
    for row, archetype in ipairs(ITEMS.archetype_order) do
        local entries = {}
        for col, id in ipairs(sorted_row(archetype)) do
            local item = Item(id, { grade = "rare", contamination = 0 })
            item.revealed.grade, item.revealed.flaw, item.owned = true, true, true
            local locked = not ItemFactory.available(id, unlocked)
            entries[col] = { id = id, item = item, locked = locked, achievement = RELIC_ACHIEVEMENT[id], rect = CompendiumModal.cell_rect(row, col) }
            if not locked then
                self._unlocked_count = self._unlocked_count + 1
            end
        end
        self._rows[row] = { archetype = archetype, entries = entries }
    end
    self._selected = self._rows[1].entries[1]
    self._hover = nil
    self._close = Button(CompendiumModal.close_rect(), function() return I18n.t("modal.close") end, {
        style = "accent", on_click = function() self.closed = true end,
    })
end

function CompendiumModal:_entry_at(x, y)
    for _, row in ipairs(self._rows) do
        for _, entry in ipairs(row.entries) do
            local r = entry.rect
            if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
                return entry
            end
        end
    end
    return nil
end

function CompendiumModal:update(dt, pointer_x, pointer_y)
    self._time = self._time + dt
    self._tweens:update(dt)
    self._hover = self:_entry_at(pointer_x, pointer_y)
    if self._hover ~= nil then
        CursorManager.request("hover", HOVER_PRIORITY)       -- 도감 칸: 커스텀 커서 (ui/CursorManager)
    end
    self._close:update(dt, pointer_x, pointer_y)
end

-- 모든 클릭을 소비한다
function CompendiumModal:mousepressed(x, y)
    if self._close:contains(x, y) then
        self._close:press()
        return true
    end
    local entry = self:_entry_at(x, y)
    if entry ~= nil then
        self._selected = entry
    end
    return true
end

function CompendiumModal:keypressed(key)
    if Input.is_action(key, "back") then
        self.closed = true
    end
end

function CompendiumModal:_draw_cell(entry)
    local r = entry.rect
    local special = ITEMS.prototypes[entry.id].special
    local focused = entry == self._selected or entry == self._hover
    Frame.inset(r.x, r.y, r.w, r.h, 8, focused and { 0.20, 0.17, 0.12 } or { 0.11, 0.10, 0.13 })
    if special then
        Draw.set_color(C.gold, entry.locked and 0.35 or 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", r.x + 1, r.y + 1, r.w - 2, r.h - 2, 8, 8)
    end
    local cx, cy, size = r.x + r.w / 2, r.y + r.h / 2, r.w * 0.78
    if entry.locked then
        ItemRenderer.draw_silhouette(entry.item, cx, cy, size, { 0.02, 0.02, 0.03 }, 0.9)
        Draw.text("?", r.x, cy - 10, r.w, "center", "value_small", C.text_dim)
    else
        ItemRenderer.draw(entry.item, cx, cy, size, { time = self._time, badges = false })
    end
    if focused then
        Draw.set_color(C.slot_hover, 0.8 + 0.2 * math.sin(self._time * 6))
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", r.x - 2, r.y - 2, r.w + 4, r.h + 4, 9, 9)
    end
end

function CompendiumModal:_draw_grid()
    for row_index, row in ipairs(self._rows) do
        local first = CompendiumModal.cell_rect(row_index, 1)
        local color = ITEMS.archetypes[row.archetype].color
        Draw.text(I18n.t("archetypes." .. row.archetype), L.x + L.grid_x, first.y + (L.cell - 20) / 2, L.label_w - 10,
            "left", "button", color)
        for _, entry in ipairs(row.entries) do
            self:_draw_cell(entry)
        end
    end
end

-- 인게임 도감: 이번 계약의 기준 ("이번 계약: 68300 G 이상 · 방벽 50%" / 스승의 흔적: "이번 계약: 봉인진 2/4 · 수기 3/6").
-- 타이틀 메뉴의 도감이면 nil
function CompendiumModal:target_text()
    return CompendiumEndings.target_text(self._ending_status)
end

function CompendiumModal:draw()
    local alpha = self._anim.alpha
    love.graphics.setColor(0, 0, 0, 0.68 * alpha)
    love.graphics.rectangle("fill", 0, 0, Viewport.width(), Viewport.height())
    love.graphics.push()
    love.graphics.translate(L.x + L.w / 2, L.y + L.h / 2)
    love.graphics.scale(self._anim.scale)
    love.graphics.translate(-(L.x + L.w / 2), -(L.y + L.h / 2))
    Frame.panel(L.x, L.y, L.w, L.h, { style = "dark", texture = "stone", texture_alpha = 0.12 })
    Lettering.draw(I18n.t("compendium.title"), L.x, L.y + 14, L.w, "center", "title", "gold")
    local endings = 0
    for _, id in ipairs(ENDINGS.order) do
        endings = endings + (MetaProgression.has_ending(id) and 1 or 0)
    end
    local achieved = 0
    for _, id in ipairs(ACHIEVEMENTS.order) do
        achieved = achieved + (MetaProgression.has_achievement(id) and 1 or 0)
    end
    local total = 0
    for _, row in ipairs(self._rows) do
        total = total + #row.entries
    end
    Draw.text(I18n.t("compendium.subtitle", {
        owned = self._unlocked_count, total = total, achieved = achieved, achievements = #ACHIEVEMENTS.order,
        endings = endings, ending_total = #ENDINGS.order,
    }), L.x + 30, L.y + 56, L.w - 60, "center", SIZE.small, C.text)
    self:_draw_grid()
    CompendiumEndings.draw(self._ending_status, self._time)
    CompendiumDetail.draw(self._hover or self._selected,
        { x = L.x + L.detail_x, y = L.y + L.grid_y, w = L.detail_w, h = L.detail_h }, self._time)
    Draw.text(I18n.t("compendium.hint"), L.x + L.grid_x, L.y + L.h - 44, 420, "left", SIZE.tiny, C.text_dim)
    self._close:draw()
    love.graphics.pop()
end

return CompendiumModal
