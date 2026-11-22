-- ui/MasterJournalModal.lua
-- '스승의 흔적' 캠페인의 [수기] 창 — 스승의 수기 (공방 [수기 N/6 · 봉인진 N/4] 버튼, 낮·밤 모두. 열려 있는 동안 게임 정지 —
-- ui/RunOverlays 의 menu 로 연다). 좌표 LAYOUT.journal. 넓은 양피지(ui/Parchment)가 위에서 펼쳐진다.
--   왼쪽 위 : 봉인진 상자 — 진열장 축소도의 봉인 공명 슬롯 4칸(계열 색, 점화 = 빛남) + "봉인진 N/4" + 계열별 점화/소등
--   왼쪽    : 수기 6편 카드 — 열린 편 = 은빛 인장 + "N편 · 제목" / 봉인 = 자물쇠 + "N편 · 봉인된 수기",
--             지난번에 창을 연 뒤 새로 열린 편 = "새 수기"
--   오른쪽  : 고른 편의 본문(문단 · 서명 · 은빛 인장 도장) / 봉인된 편은 찾는 법 (다음 편이면 인장이 숨기 시작하는 날짜)
-- 그리기 조각은 ui/MasterJournalPage. 카드를 클릭해 편을 고르고, ESC / [닫기] 로 닫는다.
-- 규칙 계산 없음: systems/MasterTrace 의 수기 수 · 점화 상태를 읽기만 한다.
-- 안 읽은 수기 수 MasterJournalModal.unread(workshop) — [수기] 버튼의 숫자 배지 (창을 열면 0, 이어하기 직후에도 0).
-- 좌표: card_rect(i) · close_rect() · page_rect() (스모크 테스트용).

local Class = require("lib.classic")
local Tween = require("lib.tween")
local Input = require("core.Input")
local Viewport = require("core.Viewport")
local I18n = require("systems.I18n")
local MasterTrace = require("systems.MasterTrace")
local Button = require("ui.Button")
local Draw = require("ui.Draw")
local Lettering = require("ui.Lettering")
local Parchment = require("ui.Parchment")
local SealSigil = require("ui.SealSigil")
local CursorManager = require("ui.CursorManager")
local MasterJournalPage = require("ui.MasterJournalPage")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local MasterJournalModal = Class:extend()

local L = LAYOUT.journal
local LG = love.graphics
local SIZE = UI.font_size
local UNROLL_TIME = 0.42
local PAGE_FADE = 0.28
local HOVER_PRIORITY = 1
local SUBTITLE_SIZES = { SIZE.small, SIZE.tiny }
local SEEN = setmetatable({}, { __mode = "k" })     -- MasterTrace → 지난번에 창을 열었을 때까지 본 수기 수

-- 이 런에서 본 수기 수 (처음 묻는 순간의 수 = 이어하기 직후에는 이미 열린 편을 다 본 것으로 친다)
local function seen_count(trace)
    if SEEN[trace] == nil then
        SEEN[trace] = trace.journals
    end
    return SEEN[trace]
end

function MasterJournalModal.unread(workshop)
    local trace = workshop.master_trace
    if trace == nil then
        return 0
    end
    return math.max(0, trace.journals - seen_count(trace))
end

function MasterJournalModal.array_rect()
    return { x = L.x + L.list_x, y = L.y + L.array_top, w = L.list_w, h = L.array_h }
end

function MasterJournalModal.card_rect(index)
    return { x = L.x + L.list_x, y = L.y + L.list_top + (index - 1) * (L.card_h + L.card_gap), w = L.list_w, h = L.card_h }
end

function MasterJournalModal.close_rect()
    return { x = L.x + L.list_x + (L.list_w - L.close_w) / 2, y = L.y + L.h - L.close_h - 30, w = L.close_w, h = L.close_h }
end

-- 본문 쪽 (제목부터 쪽 아래까지)
function MasterJournalModal.page_rect()
    return { x = L.x + L.detail_x, y = L.y + L.page_top, w = L.detail_w, h = L.h - L.page_top - 34 }
end

local function inside(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function MasterJournalModal.open(workshop)
    return MasterJournalModal(workshop)
end

function MasterJournalModal:new(workshop)
    self._workshop = workshop
    self.closed = false
    self._time = 0
    self._hovered = nil
    self._anim = { unroll = 0, page = 0 }
    self._tweens = Tween.Group()
    self._tweens:to(self._anim, UNROLL_TIME, { unroll = 1 }):ease("out_cubic")
    local trace = workshop.master_trace
    local journals = trace and trace.journals or 0
    self._new_from = trace and seen_count(trace) + 1 or journals + 1     -- 이 번호부터 "새 수기"
    if trace ~= nil then
        SEEN[trace] = journals
    end
    self:select(math.max(1, journals))           -- 가장 최근에 열린 편 (없으면 1편 — 찾는 법 안내)
    self._close = Button(MasterJournalModal.close_rect(), function() return I18n.t("trace.journal.close") end, {
        style = "accent", on_click = function() self.closed = true end,
    })
end

function MasterJournalModal:journals()
    local trace = self._workshop.master_trace
    return trace and trace.journals or 0
end

function MasterJournalModal:is_unlocked(index)
    return index <= self:journals()
end

function MasterJournalModal:selected()
    return self._selected
end

-- 편 고르기: 본문이 은은하게 다시 번진다
function MasterJournalModal:select(index)
    index = math.max(1, math.min(MasterTrace.JOURNALS, index))
    if index ~= self._selected then
        self._selected = index
        self._anim.page = 0
        self._tweens:to(self._anim, PAGE_FADE, { page = 1 }):ease("out_quad")
    end
end

function MasterJournalModal:update(dt, pointer_x, pointer_y)
    self._time = self._time + dt
    self._tweens:update(dt)
    self._hovered = nil
    for i = 1, MasterTrace.JOURNALS do
        if inside(MasterJournalModal.card_rect(i), pointer_x, pointer_y) then
            self._hovered = i
            CursorManager.request("hover", HOVER_PRIORITY)
        end
    end
    self._close:update(dt, pointer_x, pointer_y)
end

-- 모든 클릭을 소비한다
function MasterJournalModal:mousepressed(x, y)
    if self._close:contains(x, y) then
        self._close:press()
        return true
    end
    for i = 1, MasterTrace.JOURNALS do
        if inside(MasterJournalModal.card_rect(i), x, y) then
            self:select(i)
        end
    end
    return true
end

function MasterJournalModal:keypressed(key)
    if Input.is_action(key, "back") then
        self.closed = true
    end
end

-- 제목 양옆의 은빛 인장 + 제목 + 부제(수기 수)
local function draw_header(journals, time)
    local title = I18n.t("trace.journal.title")
    local half = Draw.font("title"):getWidth(title) / 2 + 34
    local cx, cy = L.x + L.w / 2, L.y + 40
    Lettering.draw(title, L.x, L.y + 20, L.w, "center", "title", "ink")
    SealSigil.draw(cx - half, cy, 13, 1, time)
    SealSigil.draw(cx + half, cy, 13, 1, time + 1.7)
    local subtitle = I18n.t("trace.journal.subtitle", { count = journals, total = MasterTrace.JOURNALS })
    local w = L.w - 120
    Draw.text(subtitle, L.x + 60, L.y + 64, w, "center", Draw.fit_size(subtitle, w, SUBTITLE_SIZES), Parchment.EDGE)
end

-- 왼쪽 목록과 오른쪽 본문 사이 먹선 (가운데 은빛 마름모)
local function draw_divider()
    local x = L.x + L.list_x + L.list_w + (L.detail_x - L.list_x - L.list_w) / 2
    local top, bottom = L.y + L.array_top, L.y + L.h - 40
    Draw.set_color(Parchment.INK, 0.55)
    LG.setLineWidth(2)
    LG.line(x, top, x, bottom)
    local mid = (top + bottom) / 2
    Draw.set_color(Parchment.INK)
    LG.polygon("fill", x, mid - 9, x + 7, mid, x, mid + 9, x - 7, mid)
    Draw.set_color(SealSigil.COLOR)
    LG.polygon("fill", x, mid - 5, x + 4, mid, x, mid + 5, x - 4, mid)
end

function MasterJournalModal:draw()
    local workshop, time = self._workshop, self._time
    local unroll = self._anim.unroll
    LG.setColor(0, 0, 0, 0.62 * math.min(1, unroll * 2))
    LG.rectangle("fill", 0, 0, Viewport.width(), Viewport.height())
    local paper = { x = L.x, y = L.y, w = L.w, h = L.h }
    Parchment.draw_paper(paper, unroll)
    local bottom = Parchment.bottom(paper, unroll)
    Viewport.set_scissor(L.x, L.y, L.w, bottom - L.y)
    local journals = self:journals()
    draw_header(journals, time)
    draw_divider()
    MasterJournalPage.array(workshop.master_trace, MasterJournalModal.array_rect(), time)
    for i = 1, MasterTrace.JOURNALS do
        local info = { unlocked = i <= journals, new = i >= self._new_from and i <= journals }
        MasterJournalPage.card(MasterJournalModal.card_rect(i), i, info, i == self._selected, i == self._hovered, time)
    end
    local alpha = self._anim.page
    if self:is_unlocked(self._selected) then
        MasterJournalPage.page(MasterJournalModal.page_rect(), self._selected, alpha, time, L.text_top - L.page_top)
    else
        MasterJournalPage.sealed(MasterJournalModal.page_rect(), self._selected, workshop, alpha, time)
    end
    self._close:draw()
    Viewport.set_scissor()
    Parchment.draw_rods(paper, unroll)
end

return MasterJournalModal
