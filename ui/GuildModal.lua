-- ui/GuildModal.lua
-- [길드] 창 (상단 [길드] 버튼, 낮에만. 열려 있는 동안 게임 정지 — ui/RunOverlays 의 menu 로 연다). 좌표 LAYOUT.guild.
--   왼쪽 : 그레이븐 던전 관리 길드 세계관 안내 · 결계 유지비 현황(다음 납부일·요구 금액·현재 부족액 막대·전체 일정)
--   오른쪽: 길드 보급 상점 (data/shop.lua 의 day_offers — 정화수 · UV 배터리 · 방벽 수리 키트 · 연마석(하루 제한))
-- ESC / [닫기] 로 닫는다. 규칙 계산 없음: 구매는 systems/GuildShop, 일정은 systems/Tribute 를 읽는다.
-- 좌표: GuildModal.buy_rect(i) / close_rect() (스모크 테스트용, i = day_offers 순서).

local Class = require("lib.classic")
local Tween = require("lib.tween")
local Input = require("core.Input")
local Viewport = require("core.Viewport")
local I18n = require("systems.I18n")
local Button = require("ui.Button")
local Draw = require("ui.Draw")
local Frame = require("ui.Frame")
local Icons = require("ui.Icons")
local Lettering = require("ui.Lettering")
local CalendarText = require("ui.CalendarText")
local SHOP = require("data.shop")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local GuildModal = Class:extend()

local C = UI.color
local SIZE = UI.font_size
local SCHEDULE_ROWS = 3           -- 결계 유지비 일정: 다가오는 징수 3줄 × 2칸
local L = LAYOUT.guild
local LG = love.graphics
local ROW_FILL = { 0.09, 0.08, 0.10, 0.94 }
local BOX_FILL = { 0.06, 0.05, 0.07, 0.94 }
local OFFER_ICONS = { water_barrel = "brush", uv_pack = "uv", repair_kit = "shield", tempering_stone = "stone" }
local OFFER_COLORS = { water_barrel = C.link_boost, uv_pack = C.uv, repair_kit = C.good, tempering_stone = C.stone }

function GuildModal.row_rect(index)
    return { x = L.x + L.shop_x, y = L.y + L.row_top + (index - 1) * (L.row_h + L.row_gap), w = L.w - L.shop_x - 28, h = L.row_h }
end

function GuildModal.buy_rect(index)
    local row = GuildModal.row_rect(index)
    return { x = row.x + row.w - L.button_w - 14, y = row.y + (row.h - L.button_h) / 2, w = L.button_w, h = L.button_h }
end

function GuildModal.close_rect()
    return { x = L.x + (L.w - L.close_w) / 2, y = L.y + L.h - L.close_h - 18, w = L.close_w, h = L.close_h }
end

function GuildModal.open(workshop)
    return GuildModal(workshop)
end

function GuildModal:new(workshop)
    self._workshop = workshop
    self.closed = false
    self._time = 0
    self._anim = { scale = 0.94, alpha = 0 }
    self._tweens = Tween.Group()
    self._tweens:to(self._anim, 0.24, { scale = 1, alpha = 1 }):ease("out_back")
    local shop = workshop.shop
    self._buttons = {}
    for i, id in ipairs(SHOP.day_offers) do
        self._buttons[i] = Button(GuildModal.buy_rect(i), function() return I18n.t("modal.cost_gold", { cost = shop:price(id) }) end, {
            style = "accent", icon = "coin",
            enabled = function() return (shop:availability(id)) end,
            disabled_message = function() return select(2, shop:availability(id)) end,
            on_click = function() shop:buy(id) end,
        })
    end
    self._close = Button(GuildModal.close_rect(), function() return I18n.t("modal.close") end, {
        style = "accent", on_click = function() self.closed = true end,
    })
    self._buttons[#self._buttons + 1] = self._close
end

function GuildModal:update(dt, pointer_x, pointer_y)
    self._time = self._time + dt
    self._tweens:update(dt)
    for _, button in ipairs(self._buttons) do
        button:update(dt, pointer_x, pointer_y)
    end
end

-- 모든 클릭을 소비한다
function GuildModal:mousepressed(x, y)
    for _, button in ipairs(self._buttons) do
        if button:contains(x, y) then
            button:press()
            return true
        end
    end
    return true
end

function GuildModal:keypressed(key)
    if Input.is_action(key, "back") then
        self.closed = true
    end
end

-- 결계 유지비 현황: 다음 납부일·금액·부족액 막대 + 전체 일정 (납부 완료 / 오늘 밤 / 예정)
local function draw_upkeep(workshop, x, y, w)
    local h = 250
    Frame.inset(x, y, w, h, 10, BOX_FILL)
    local ix, iw = x + 16, w - 32
    Draw.text(I18n.t("guild.upkeep_title"), ix, y + 10, iw, "left", "item_name", C.gold)
    local due, amount = workshop.tribute:next_due(workshop.day)
    if due == nil then
        Draw.text(I18n.t("dayshop.upkeep_done"), ix, y + 44, iw, "left", SIZE.small, C.good)
    else
        local short = math.max(0, amount - workshop.gold)
        Draw.text(I18n.t("dayshop.upkeep", { date = CalendarText.date(due), days = due - workshop.day, amount = amount }), ix, y + 42,
            iw, "left",
            SIZE.small, C.text)
        Draw.bar(ix, y + 66, iw, 10, workshop.gold / math.max(1, amount), short > 0 and C.danger or C.good)
        local status = short > 0 and I18n.t("dayshop.upkeep_short", { gold = workshop.gold, short = short })
            or I18n.t("dayshop.upkeep_ready", { gold = workshop.gold })
        Draw.text(status, ix, y + 82, iw, "left", SIZE.small, short > 0 and C.danger or C.good)
    end
    Draw.text(I18n.t("guild.schedule_title"), ix, y + 112, iw, "left", "label", C.text_dim)
    local shown, paid, more = 0, 0, 0              -- 다가오는 징수 SCHEDULE_ROWS × 2 회 + 납부 완료 · 남은 횟수 요약
    for _, day in ipairs(workshop.tribute:schedule()) do
        if day < workshop.day then
            paid = paid + 1
        elseif shown < SCHEDULE_ROWS * 2 then
            local key = day == workshop.day and "guild.schedule_tonight" or "guild.schedule_due"
            local col, line = shown % 2, math.floor(shown / 2)
            Draw.text(I18n.t(key, { date = CalendarText.date(day), amount = workshop.tribute:amount_for(day) }), ix + col * (iw / 2),
                y + 134 + line * 22, iw / 2 - 6, "left", SIZE.small, day == due and C.accent or C.text)
            shown = shown + 1
        else
            more = more + 1
        end
    end
    local footer = {}
    if paid > 0 then
        footer[#footer + 1] = I18n.t("guild.schedule_paid_count", { count = paid })
    end
    if more > 0 then
        footer[#footer + 1] = I18n.t("guild.schedule_more", { count = more })
    end
    Draw.text(table.concat(footer, "  ·  "), ix, y + 134 + SCHEDULE_ROWS * 22, iw, "left", SIZE.tiny, C.text_dim)
    Draw.text(I18n.t("dayshop.stock", {
        uv = math.floor(workshop.supplies.uv + 0.5), water = math.floor(workshop.supplies.water + 0.5),
        hp = math.ceil(workshop.hp), max_hp = workshop.max_hp,
    }), ix, y + h - 30, iw, "left", SIZE.tiny, C.text_dim)
end

local function draw_offer(workshop, index, id)
    local r = GuildModal.row_rect(index)
    Frame.inset(r.x, r.y, r.w, r.h, 10, ROW_FILL)
    local color = OFFER_COLORS[id] or C.accent
    Icons.draw(OFFER_ICONS[id] or "coin", r.x + 34, r.y + r.h / 2, 34, color)
    local x, w = r.x + 66, r.w - 66 - L.button_w - 26
    Draw.text(I18n.t("shop." .. id .. ".name"), x, r.y + 10, w, "left", "item_name", color)
    Draw.text(I18n.t("shop." .. id .. ".text"), x, r.y + 36, w, "left", SIZE.small, C.text_dim)
    local left = workshop.shop:remaining(id)
    if left ~= nil then
        local limit = SHOP.offers[id].daily_limit
        Draw.text(I18n.t("guild.daily_left", { left = left, limit = limit, have = workshop.tempering_stones }), x, r.y + r.h - 22,
            w, "left", SIZE.tiny, left > 0 and C.stone or C.danger)
    end
end

function GuildModal:draw()
    local workshop = self._workshop
    LG.setColor(0, 0, 0, 0.66 * self._anim.alpha)
    LG.rectangle("fill", 0, 0, Viewport.width(), Viewport.height())
    LG.push()
    LG.translate(L.x + L.w / 2, L.y + L.h / 2)
    LG.scale(self._anim.scale)
    LG.translate(-(L.x + L.w / 2), -(L.y + L.h / 2))
    Frame.panel(L.x, L.y, L.w, L.h, { style = "dark", texture = "stone", texture_alpha = 0.14 })
    Lettering.draw(I18n.t("guild.title"), L.x, L.y + 14, L.w, "center", "title", "gold")
    Draw.text(I18n.t("guild.subtitle", { gold = workshop.gold, stones = workshop.tempering_stones }), L.x + 30, L.y + 56,
        L.w - 60, "center", SIZE.small, C.text)
    local x = L.x + 28
    Draw.text(I18n.t("guild.lore"), x, L.y + L.row_top, L.lore_w, "left", SIZE.small, C.text)
    draw_upkeep(workshop, x, L.y + L.row_top + 176, L.lore_w)
    Draw.text(I18n.t("guild.shop_title"), L.x + L.shop_x, L.y + L.row_top - 26, L.w - L.shop_x - 28, "left", "label", C.accent)
    for i, id in ipairs(SHOP.day_offers) do
        draw_offer(workshop, i, id)
    end
    for _, button in ipairs(self._buttons) do
        button:draw()
    end
    LG.pop()
end

return GuildModal
