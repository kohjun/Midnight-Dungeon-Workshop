-- ui/Hud.lua
-- 상단 상태 바: 철제·황동 이중 테두리 바 + 상납 D-1/D-Day 경고 띠 + 토스트 메시지. 구역 좌표는 data/layout.lua 의 hud.
-- 토스트는 낮에는 오른쪽 패널 위(LAYOUT.day.toast), 밤에는 전투 레인 위(LAYOUT.night.toast)에 쌓는다.
--   왼쪽 상태 영역: 날짜·페이즈 배지 · 방벽 내구도 · 결계 유지비 카드 · 골드·연마석 (ui/HudStatus)
--   오른쪽 메뉴 영역: [길드] [의뢰](대기 제안 숫자 배지) [도감] [공방 개조] [설정] → 최우측 황동 강조 [영업 마감]
--                    (버튼은 WorkshopInput 이 소유·그린다, 아이콘 원화 icon_* 는 ui/ButtonDecor)

local Class = require("lib.classic")
local Tween = require("lib.tween")
local I18n = require("systems.I18n")
local Draw = require("ui.Draw")
local HudStatus = require("ui.HudStatus")
local CalendarText = require("ui.CalendarText")
local SpriteBank = require("ui.SpriteBank")
local Slots = require("ui.Slots")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local Hud = Class:extend()

local C = UI.color
local SIZE = UI.font_size
local ZONES = LAYOUT.hud
local LG = love.graphics
local INK = { 0.03, 0.02, 0.02 }
local BRASS = { 0.78, 0.60, 0.30 }
local IRON = { 0.20, 0.20, 0.24 }
local RIVET_GAP = 64
local TOAST_HEIGHT = 30
local TOAST_KIND_COLORS = { info = C.text, warn = C.accent, good = C.good, bad = C.danger }

function Hud:new()
    self._toasts = {}
    self._anim = { gold = 1, hp = 0, stones = 1 }
    self._tweens = Tween.Group()
    self._gold_job = nil
    self._hp_job = nil
end

function Hud:toast(text, kind)
    table.insert(self._toasts, 1, { text = text, kind = kind or "info", life = UI.anim.toast_life })
    while #self._toasts > UI.anim.toast_max do
        table.remove(self._toasts)
    end
end

function Hud:pulse_gold()
    if self._gold_job ~= nil then
        self._gold_job:stop()
    end
    self._anim.gold = 1.35
    self._gold_job = self._tweens:to(self._anim, UI.anim.gold_pulse, { gold = 1 }):ease("out_back")
end

function Hud:pulse_stones()
    self._anim.stones = 1.4
    self._tweens:to(self._anim, UI.anim.gold_pulse, { stones = 1 }):ease("out_back")
end

function Hud:pulse_hp()
    if self._hp_job ~= nil then
        self._hp_job:stop()
    end
    self._anim.hp = 1
    self._hp_job = self._tweens:to(self._anim, 0.5, { hp = 0 }):ease("out_quad")
end

-- 새벽 정산(ui/DawnSummary): 골드·연마석 표시를 gold, stones 에 멈춰 두었다가
function Hud:hold(gold, stones)
    self._count = { gold = gold, stones = stones, t = 0 }
end

-- duration 초 동안 지금 값까지 빠르게 카운트업 (반짝임) → 끝나면 튀어 오름
function Hud:count_to(duration)
    if self._count ~= nil then
        self._count.duration, self._count.t = duration, 0
    end
end

-- 지금 상단 바에 보일 골드 · 연마석 · 반짝임(0~1)
function Hud:shown(workshop)
    local count = self._count
    if count == nil then
        return workshop.gold, workshop.tempering_stones, 0
    elseif count.duration == nil then
        return count.gold, count.stones, 0
    end
    local k = 1 - (1 - math.min(1, count.t / count.duration)) ^ 2
    return math.floor(count.gold + (workshop.gold - count.gold) * k + 0.5),
        math.floor(count.stones + (workshop.tempering_stones - count.stones) * k + 0.5), 1 - k * 0.3
end

function Hud:update(dt)
    self._tweens:update(dt)
    local count = self._count
    if count ~= nil and count.duration ~= nil then
        count.t = count.t + dt
        if count.t >= count.duration then
            self._count = nil
            self:pulse_gold()
            self:pulse_stones()
        end
    end
    for i = #self._toasts, 1, -1 do
        local toast = self._toasts[i]
        toast.life = toast.life - dt
        if toast.life <= 0 then
            table.remove(self._toasts, i)
        end
    end
end

-- 상납 D-1 / D-Day 낮: 목표 상납금과 부족액 경고 띠
function Hud:_draw_tribute_warning(workshop, time)
    if workshop.phase ~= "day" then
        return
    end
    local warning = workshop.tribute:warning(workshop.day)
    if warning == nil then
        return
    end
    local strip = LAYOUT.tribute_warning
    local short = warning.shortfall > 0
    local pulse = 0.7 + 0.3 * math.sin(time * 6)
    Draw.set_color(short and C.danger or C.button_accent, (short and 0.55 or 0.45) * pulse)
    love.graphics.rectangle("fill", strip.x, strip.y, strip.w, strip.h)
    local when = warning.days_left == 0 and I18n.t("hud.warning_tonight")
        or I18n.t("hud.warning_days", { days = warning.days_left, date = CalendarText.date(warning.due) })
    local status = short and I18n.t("hud.warning_short", { shortfall = warning.shortfall }) or I18n.t("hud.warning_ready")
    local text = I18n.t("hud.warning", { when = when, amount = warning.amount, gold = workshop.gold, status = status })
    Draw.text(text, strip.x, strip.y + 1, strip.w, "center", SIZE.tiny, { 1, 1, 1 })
end

-- 토스트는 낮 오른쪽 패널 위 / 밤 전투 레인 위쪽 중앙에 쌓는다.
-- 모달이 열려 있으면 모달 아래 화면 하단 중앙으로 옮긴다
function Hud:_draw_toasts(modal_open)
    local area = Slots.mode() == "night" and LAYOUT.night.toast or LAYOUT.day.toast
    local area_x, area_w, top, height = area.x, area.w, area.y, TOAST_HEIGHT
    if modal_open then
        local modal = LAYOUT.modal
        area_x, area_w, height = modal.x, modal.w, 26
        top = modal.y + modal.h + 6
    end
    for i, toast in ipairs(self._toasts) do
        local alpha = math.min(1, toast.life * 3)
        local font = Draw.font(SIZE.small)
        local text_w = font:getWidth(toast.text) + 28
        local y = top + (i - 1) * (height + 2)
        Draw.set_color({ 0.03, 0.03, 0.05 }, 0.88 * alpha)
        love.graphics.rectangle("fill", area_x + (area_w - text_w) / 2, y, text_w, height, 13, 13)
        Draw.text(toast.text, area_x, y + (height - font:getHeight()) / 2, area_w, "center", SIZE.small,
            TOAST_KIND_COLORS[toast.kind] or C.text, alpha)
    end
end

-- 바 바탕: 어두운 목재 + 위 황동 실선 + 아래 철 띠(리벳) · 황동선 · 먹선 이중 테두리, 상태/메뉴 구역 사이 칸막이
local function draw_bar()
    local bar = LAYOUT.top_bar
    Draw.set_color({ 0.10, 0.07, 0.06 })
    LG.rectangle("fill", bar.x, bar.y, bar.w, bar.h)
    SpriteBank.draw_texture("wood", bar.x, bar.y, bar.w, bar.h, 0, 0.3)
    Draw.set_color(BRASS, 0.5)
    LG.setLineWidth(1)
    LG.line(bar.x, bar.y + 0.5, bar.x + bar.w, bar.y + 0.5)
    local band = bar.y + bar.h - 5
    Draw.set_color(IRON)
    LG.rectangle("fill", bar.x, band, bar.w, 5)
    Draw.set_color(BRASS, 0.85)
    LG.line(bar.x, band + 0.5, bar.x + bar.w, band + 0.5)
    Draw.set_color(INK)
    LG.setLineWidth(2)
    LG.line(bar.x, bar.y + bar.h, bar.x + bar.w, bar.y + bar.h)
    for x = RIVET_GAP / 2, bar.w, RIVET_GAP do
        Draw.set_color(BRASS, 0.9)
        LG.circle("fill", x, band + 2.5, 1.6, 8)
    end
    local x = ZONES.divider
    Draw.set_color(INK, 0.8)
    LG.setLineWidth(2)
    LG.line(x, bar.y + 8, x, band - 3)
    Draw.set_color(BRASS, 0.45)
    LG.setLineWidth(1)
    LG.line(x + 1.5, bar.y + 8, x + 1.5, band - 3)
end

function Hud:draw(workshop, time)
    draw_bar()
    HudStatus.badge(workshop, time)
    HudStatus.ward(workshop, self._anim.hp)
    HudStatus.tribute(workshop, time)
    HudStatus.purse(workshop, self._anim, self:shown(workshop))
    self:_draw_tribute_warning(workshop, time)
end

-- 토스트는 흔들림 밖, 가장 위에 그린다
function Hud:draw_overlay(modal_open)
    self:_draw_toasts(modal_open)
end

return Hud
