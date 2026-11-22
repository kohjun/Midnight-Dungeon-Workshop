-- ui/QuestModal.lua
-- [의뢰] 창 (상단 [의뢰] 버튼 — 대기 제안 수 배지. 열려 있는 동안 게임 정지, ui/RunOverlays 의 menu). 좌표 LAYOUT.quests.
-- 넓은 양피지(ui/Parchment)가 위에서 펼쳐지고, 왼쪽에 의뢰 카드 목록(분야 색 띠 · 출처 · 상태 · 이름 · 보상 · 기한),
-- 오른쪽에 고른 의뢰의 배경 · 달성 조건(+ 기한) · 보상 · 기한 초과 시 위약금 · 위험도 · 진행 상황을 줄바꿈으로 보여 준다.
--   대기 중  : [수락] / [거절] (낮에만) — 길드 의뢰는 systems/GuildQuests, 암시장 제안은 systems/BlackMarket
--   납품 의뢰: 수락한 뒤 [납품] (낮에만, 보관함·작업대에 조건에 맞는 유물이 있을 때 — 없으면 어둡게 + 사유)
--   봉인 상자: 수락하면 상자 3종 [N G 개봉] 버튼이 나타난다
-- 문구는 ui/QuestText. ESC / [닫기] 로 닫는다.
-- 좌표: card_rect(i) · accept_rect() · decline_rect() · deliver_rect() · box_rect(i) · close_rect().

local Class = require("lib.classic")
local Tween = require("lib.tween")
local Input = require("core.Input")
local Viewport = require("core.Viewport")
local I18n = require("systems.I18n")
local Button = require("ui.Button")
local Draw = require("ui.Draw")
local Lettering = require("ui.Lettering")
local Parchment = require("ui.Parchment")
local QuestText = require("ui.QuestText")
local CursorManager = require("ui.CursorManager")
local EVENTS = require("data.events")
local QUESTS = require("data.quests")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local QuestModal = Class:extend()

local SIZE = UI.font_size
local L = LAYOUT.quests
local LG = love.graphics
local INK, RED = Parchment.INK, Parchment.RED_INK
local GREEN = { 0.18, 0.36, 0.14 }
local RISK_COLORS = { none = { 0.18, 0.40, 0.16 }, low = { 0.22, 0.32, 0.14 }, mid = { 0.66, 0.38, 0.08 }, high = RED }
local TONE_COLORS = { good = GREEN, bad = RED, info = { 0.20, 0.24, 0.42 } }
local CARD_FILL = { 0.78, 0.68, 0.48 }
local CARD_SELECTED = { 0.95, 0.86, 0.62 }
local UNROLL_TIME = 0.42
local SECTION_GAP = 8

function QuestModal.card_rect(index)
    return { x = L.x + L.list_x, y = L.y + L.list_top + (index - 1) * (L.card_h + L.card_gap), w = L.list_w, h = L.card_h }
end

function QuestModal.accept_rect()
    return { x = L.x + L.detail_x, y = L.y + L.h - 132, w = L.button_w, h = L.button_h }
end

function QuestModal.decline_rect()
    return { x = L.x + L.detail_x + L.button_w + 16, y = L.y + L.h - 132, w = L.button_w, h = L.button_h }
end

-- [납품]: 수락한 납품 의뢰에서 [수락] 자리에
function QuestModal.deliver_rect()
    return QuestModal.accept_rect()
end

function QuestModal.box_rect(index)
    return { x = L.x + L.detail_x + L.detail_w - L.button_w, y = L.y + 428 + (index - 1) * 50, w = L.button_w, h = 42 }
end

function QuestModal.close_rect()
    return { x = L.x + L.list_x + (L.list_w - L.close_w) / 2, y = L.y + L.h - L.close_h - 42, w = L.close_w, h = L.close_h }
end

function QuestModal.open(workshop)
    return QuestModal(workshop)
end

function QuestModal:new(workshop)
    self._workshop = workshop
    self.closed = false
    self._anim = { unroll = 0 }
    self._tweens = Tween.Group()
    self._tweens:to(self._anim, UNROLL_TIME, { unroll = 1 }):ease("out_cubic")
    self._entries = QuestText.entries(workshop)
    self._selected = 1
    for i, entry in ipairs(self._entries) do       -- 대기 중인 의뢰를 먼저 보여 준다
        if entry.state == "pending" then
            self._selected = i
            break
        end
    end
    self:_build_buttons()
end

function QuestModal:selected()
    return self._entries[self._selected]
end

local function decide(workshop, entry, accept)
    if entry.source == "market" then
        return accept and workshop.black_market:accept() or workshop.black_market:decline()
    end
    return accept and workshop.quests:accept(entry.index) or workshop.quests:decline(entry.index)
end

function QuestModal:_build_buttons()
    local workshop, market = self._workshop, self._workshop.black_market
    local function pending()
        local entry = self:selected()
        return entry ~= nil and entry.state == "pending"
    end
    local function delivery()
        local entry = self:selected()
        return entry ~= nil and entry.source == "guild" and entry.state == "accepted"
            and (entry.quest.kind == "deliver_forged" or entry.quest.kind == "deliver_clean")
    end
    local function deliver_block()
        local entry = self:selected()
        return workshop.quests:delivery_block(entry and entry.quest)
    end
    local function day_only() return workshop:is_day() end
    local function night_reason() return I18n.t("quest_ui.day_only") end
    self._buttons = {
        Button(QuestModal.accept_rect(), function() return I18n.t("quest_ui.accept") end, {
            style = "accent", icon = "quest", visible = pending, enabled = day_only, disabled_message = night_reason,
            on_click = function() decide(workshop, self:selected(), true) end,
        }),
        Button(QuestModal.decline_rect(), function() return I18n.t("quest_ui.decline") end, {
            style = "danger", icon = "dismiss", visible = pending, enabled = day_only, disabled_message = night_reason,
            on_click = function() decide(workshop, self:selected(), false) end,
        }),
        Button(QuestModal.deliver_rect(), function() return I18n.t("quest_ui.deliver") end, {
            style = "accent", icon = "stash", visible = delivery, enabled = function() return deliver_block() == nil end,
            disabled_message = function() return I18n.t(deliver_block() or "quest_ui.deliver_none") end,
            on_click = function() workshop.quests:deliver(self:selected().index) end,
        }),
    }
    for index, box in ipairs(EVENTS.events.mystery_boxes.boxes) do
        self._buttons[#self._buttons + 1] = Button(QuestModal.box_rect(index), function()
            return market.opened[index] and I18n.t("market.box_opened") or I18n.t("market.box_open", { price = box.price })
        end, {
            style = "danger",
            visible = function()
                local entry = self:selected()
                return entry ~= nil and entry.id == "mystery_boxes" and entry.state == "accepted"
            end,
            enabled = function() return (market:box_availability(index)) end,
            disabled_message = function() return select(2, market:box_availability(index)) end,
            on_click = function() market:open_box(index) end,
        })
    end
    self._buttons[#self._buttons + 1] = Button(QuestModal.close_rect(), function() return I18n.t("modal.close") end, {
        style = "accent", on_click = function() self.closed = true end,
    })
end

function QuestModal:update(dt, pointer_x, pointer_y)
    self._tweens:update(dt)
    self._entries = QuestText.entries(self._workshop)
    self._selected = math.max(1, math.min(self._selected, #self._entries))
    for i = 1, #self._entries do
        local r = QuestModal.card_rect(i)
        if pointer_x >= r.x and pointer_x <= r.x + r.w and pointer_y >= r.y and pointer_y <= r.y + r.h then
            CursorManager.request("hover", 1)
        end
    end
    for _, button in ipairs(self._buttons) do
        button:update(dt, pointer_x, pointer_y)
    end
end

-- 모든 클릭을 소비한다
function QuestModal:mousepressed(x, y)
    for _, button in ipairs(self._buttons) do
        if button:contains(x, y) then
            button:press()
            return true
        end
    end
    for i = 1, #self._entries do
        local r = QuestModal.card_rect(i)
        if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
            self._selected = i
        end
    end
    return true
end

function QuestModal:keypressed(key)
    if Input.is_action(key, "back") then
        self.closed = true
    end
end

local function fit(text, w, sizes)
    return Draw.fit_size(text, w, sizes)
end

local function draw_card(index, entry, text, selected)
    local r = QuestModal.card_rect(index)
    Draw.set_color(selected and CARD_SELECTED or CARD_FILL, 0.92)
    LG.rectangle("fill", r.x, r.y, r.w, r.h, 8, 8)
    local stripe = entry.source == "market" and RED or (QUESTS.category_colors[text.category] or INK)
    Draw.set_color(stripe, 0.9)                     -- 분야 색 띠
    LG.rectangle("fill", r.x + 4, r.y + 8, 5, r.h - 16, 2, 2)
    Draw.set_color(entry.source == "market" and RED or INK, selected and 1 or 0.6)
    LG.setLineWidth(selected and 3 or 1.5)
    LG.rectangle("line", r.x, r.y, r.w, r.h, 8, 8)
    local x, w = r.x + 16, r.w - 28
    local state = I18n.t("quest_ui.state_" .. entry.state)
    local state_w = Draw.font("label"):getWidth(state)
    Draw.text(text.source, x, r.y + 7, w - state_w - 8, "left", fit(text.source, w - state_w - 8, { "label", SIZE.tiny }),
        entry.source == "market" and RED or Parchment.EDGE)
    Draw.text(state, x, r.y + 7, w, "right", "label", entry.state == "pending" and RED or INK)
    Draw.text(text.name, x, r.y + 27, w, "left", fit(text.name, w, { "item_name", SIZE.body, SIZE.small }), INK)
    local reward = I18n.t("quest_ui.card_reward", { reward = text.reward })
    Draw.text(reward, x, r.y + 53, w, "left", fit(reward, w, { SIZE.small, SIZE.tiny }), INK, 0.85)
    if text.card_line ~= nil then
        Draw.text(text.card_line, x, r.y + 73, w, "left", fit(text.card_line, w, { SIZE.tiny }), RED, 0.9)
    end
end

-- 봉인 상자 줄: 이름 · 나오는 등급 · 강화 범위 (버튼은 오른쪽)
local function draw_boxes(x, w)
    local names = I18n.list("events.mystery_boxes.boxes")
    for index, box in ipairs(EVENTS.events.mystery_boxes.boxes) do
        local grades = {}
        for i, grade in ipairs(box.grades) do
            grades[i] = I18n.grade(grade)
        end
        local r = QuestModal.box_rect(index)
        Draw.text(I18n.t("quest_ui.box_line", { name = names[index], grades = table.concat(grades, "·"), min = box.levels[1],
            max = box.levels[2] }), x, r.y + 11, w - L.button_w - 16, "left", SIZE.small, INK)
    end
end

-- 제목 + 본문(줄바꿈) 한 묶음. 다음 묶음의 y 를 돌려준다
local function section(label, body, x, y, w, color)
    Draw.text(label, x, y, w, "left", "label", RED)
    local font = Draw.font(SIZE.small)
    local _, lines = font:getWrap(body, w)
    Draw.text(body, x, y + 18, w, "left", SIZE.small, color or INK)
    return y + 18 + math.max(1, #lines) * font:getHeight() + SECTION_GAP
end

function QuestModal:_draw_detail()
    local entry = self:selected()
    local x, w = L.x + L.detail_x, L.detail_w
    local y = L.y + L.list_top
    if entry == nil then
        Draw.text(I18n.t("quest_ui.empty_detail"), x, y + 40, w, "left", "story", INK)
        return
    end
    local text = QuestText.describe(self._workshop, entry)
    Draw.text(text.name, x, y - 6, w, "left", fit(text.name, w, { "title", "item_name" }), INK)
    y = section(I18n.t("quest_ui.story"), text.story, x, y + 36, w)
    y = section(I18n.t("quest_ui.goal"), text.goal, x, y, w)
    y = section(I18n.t("quest_ui.reward"), text.reward, x, y, w, GREEN)
    if text.penalty ~= nil then
        y = section(I18n.t("quest_ui.penalty"), text.penalty, x, y, w, RED)
    end
    local risk_color = RISK_COLORS[text.risk_level] or INK
    Draw.text(I18n.t("quest_ui.risk"), x, y, w, "left", "label", RED)
    Draw.text(text.risk, x + 90, y - 2, 120, "left", "button", risk_color)
    Draw.bar(x + 200, y + 4, 180, 8, math.max(0.05, QuestText.risk_ratio(text.risk_level)), risk_color)
    if text.progress ~= nil then
        Draw.text(text.progress, x, y + 26, w, "left", fit(text.progress, w, { SIZE.small, SIZE.tiny }), TONE_COLORS[text.tone] or INK)
    end
    if entry.id == "mystery_boxes" and entry.state == "accepted" then
        draw_boxes(x, w)
    end
end

function QuestModal:draw()
    local workshop = self._workshop
    local unroll = self._anim.unroll
    LG.setColor(0, 0, 0, 0.62 * math.min(1, unroll * 2))
    LG.rectangle("fill", 0, 0, Viewport.width(), Viewport.height())
    local paper = { x = L.x, y = L.y, w = L.w, h = L.h }
    Parchment.draw_paper(paper, unroll)
    local bottom = Parchment.bottom(paper, unroll)
    Viewport.set_scissor(L.x, L.y, L.w, bottom - L.y)
    Lettering.draw(I18n.t("quest_ui.title"), L.x, L.y + 22, L.w, "center", "title", "ink")
    local subtitle = I18n.t("quest_ui.subtitle", { count = workshop.quests:pending_total() })
    Draw.text(subtitle, L.x + 30, L.y + 66, L.w - 60, "center", fit(subtitle, L.w - 60, { SIZE.small, SIZE.tiny }), Parchment.EDGE)
    if #self._entries == 0 then
        Draw.text(I18n.t("quest_ui.empty"), L.x + L.list_x, L.y + L.list_top + 20, L.list_w, "left", "story", INK)
    end
    for i, entry in ipairs(self._entries) do
        draw_card(i, entry, QuestText.describe(workshop, entry), i == self._selected)
    end
    self:_draw_detail()
    for _, button in ipairs(self._buttons) do
        button:draw()
    end
    Viewport.set_scissor()
    Parchment.draw_rods(paper, unroll)
end

return QuestModal
