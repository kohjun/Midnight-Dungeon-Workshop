-- ui/CustomerCard.lua
-- 낮 손님 카운터 (좌표 LAYOUT.day.customer_card, 거래 버튼은 WorkshopInput 이 그린다). 규칙 계산 없음.
--   손님 유물: 방문한 모험가 프로필 — "{이명} {이름}"(뱃지 색) · 특성 태그 칩 · 대사 톤별 한마디 · 제시가(흥정 반영) · 발견 메모
--             왼쪽 주인장 초상(ui/ShopkeeperPortrait)과 오른쪽 모험가 초상(ui/AdventurerPortrait)이 대사를 사이에 두고 마주 본다
--   내 유물  : 작업 중인 유물 이름 · 판매가 / 빈 작업대: 손님 대기 안내
-- 모험가 데이터는 data/adventurers.lua, 문구는 로케일 adventurers.<id>.{name, epithet, lines} · adventurers.tags.<tag>.

local Text = require("lib.text")
local I18n = require("systems.I18n")
local Draw = require("ui.Draw")
local Frame = require("ui.Frame")
local ShopkeeperPortrait = require("ui.ShopkeeperPortrait")
local AdventurerPortrait = require("ui.AdventurerPortrait")
local ADVENTURERS = require("data.adventurers")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local CustomerCard = {}

local C = UI.color
local SIZE = UI.font_size
local LG = love.graphics
local CARD_FILL = { 0.07, 0.05, 0.05, 0.92 }
local CHIP_FILL = { 0.03, 0.02, 0.03, 0.85 }
local CHIP_H = 19
local CHIP_PAD = 8
local CHIP_GAP = 6

-- 모험가 표시 이름 ("강철의 베른" / "Bern the Iron")
function CustomerCard.display_name(id)
    return I18n.t("adventurers.display", {
        name = I18n.t("adventurers." .. id .. ".name"), epithet = I18n.t("adventurers." .. id .. ".epithet"),
    })
end

-- 모험가의 대사 톤으로 한마디 (유물마다 고정: uid 로 고른다)
function CustomerCard.line(workshop, item)
    local vars = { address = workshop:address(), grade = I18n.grade(item.claimed_grade), item = I18n.item_name(item) }
    if item.adventurer == nil then
        return I18n.t("bench.customer_claim", vars)
    end
    local lines = I18n.list("adventurers." .. item.adventurer .. ".lines")
    return Text.fill(lines[item.uid % #lines + 1], vars)
end

-- 특성 태그 칩 (뱃지 색 테두리), 오른쪽 끝을 넘으면 그만 그린다
local function draw_tags(adventurer, x, y, w, badge)
    local font = Draw.font(SIZE.tiny)
    local right = x + w
    for _, tag in ipairs(adventurer.tags) do
        local text = I18n.t("adventurers.tags." .. tag)
        local chip_w = font:getWidth(text) + CHIP_PAD * 2
        if x + chip_w > right then
            return
        end
        Draw.set_color(CHIP_FILL)
        LG.rectangle("fill", x, y, chip_w, CHIP_H, 9, 9)
        Draw.set_color(badge, 0.9)
        LG.setLineWidth(1.5)
        LG.rectangle("line", x + 0.5, y + 0.5, chip_w - 1, CHIP_H - 1, 9, 9)
        Draw.text(text, x, y + (CHIP_H - font:getHeight()) / 2, chip_w, "center", SIZE.tiny, badge)
        x = x + chip_w + CHIP_GAP
    end
end

-- 제시가 줄: 감정으로 깎였으면 "제시 120 G → 78 G (-35% 위조 적발)"
local function price_line(item)
    local list, price = item:list_price(), item:asking_price()
    if price >= list then
        return I18n.t("bench.asking_price", { price = price })
    end
    local flaw, forgery = item.flaw ~= nil and item.revealed.flaw, item:is_forgery_revealed()
    local reason = (flaw and forgery) and "bench.reason_both" or (forgery and "bench.reason_forgery" or "bench.reason_flaw")
    return I18n.t("bench.asking_discount", { list = list, price = price, pct = math.floor((1 - price / list) * 100 + 0.5),
        reason = I18n.t(reason) })
end

local function draw_customer(workshop, item, card, guest, time)
    local adventurer = item.adventurer and ADVENTURERS.list[item.adventurer] or nil
    local x, w = card.text_x, adventurer and card.guest_text_w or card.text_w      -- 오른쪽에 모험가 초상 자리
    if adventurer ~= nil then
        local name = CustomerCard.display_name(item.adventurer)
        Draw.text(name, x, card.y + 6, w, "left", Draw.fit_size(name, w, { "item_name", SIZE.body }), adventurer.badge)
        draw_tags(adventurer, x, card.y + 32, w, adventurer.badge)
    else
        Draw.text(I18n.t("bench.customer_label"), x, card.y + 10, w, "left", "label", C.accent)
    end
    local reaction = guest and guest:line(item)          -- 결함·위조를 들킨 직후의 당황·변명·인정 한마디
    local claim = reaction or CustomerCard.line(workshop, item)
    local size = SIZE.small
    if #select(2, Draw.font(size):getWrap(claim, w)) > 2 then      -- 두 줄을 넘으면 작은 글자로
        size = SIZE.tiny
    end
    local settled = adventurer and AdventurerPortrait.arrived(item, time) or 1      -- 초상이 자리 잡을 무렵 대사가 뜬다 (더빙과 함께)
    Draw.text(claim, x, card.y + 56, w, "left", size, reaction and C.accent or C.text, math.max(0, (settled - 0.8) / 0.2))
    local price = price_line(item)
    Draw.text(price, x, card.y + 96, w, "left", Draw.fit_size(price, w, { "value_small", SIZE.small, SIZE.tiny }),
        item:asking_price() < item:list_price() and C.good or C.gold)
end

function CustomerCard.draw(workshop, time, ambient)
    local card = LAYOUT.day.customer_card
    local item = workshop.appraisal:bench_item()
    Frame.inset(card.x, card.y, card.w, card.h, 8, CARD_FILL)
    ShopkeeperPortrait.draw(card, item, time, ambient)
    local x, w = card.text_x, card.text_w
    if item ~= nil and not item.owned then
        local guest = ambient and ambient.guest
        draw_customer(workshop, item, card, guest, time)
        if item.adventurer ~= nil then
            local dx, rot = 0, 0
            if guest ~= nil then
                dx, rot = guest:pose(item)
            end
            AdventurerPortrait.draw(card, item, time, dx, rot)
        end
    elseif item ~= nil then
        Draw.text(I18n.t("bench.working_label"), x, card.y + 14, w, "left", "label", C.accent)
        Draw.text(I18n.item_name(item), x, card.y + 36, w, "left", "item_name", item:grade_info().color)
        Draw.text(I18n.t("bench.sale_price", { price = workshop:sale_price(item) }), x, card.y + 72, w, "left", "value_small", C.gold)
    else
        Draw.text(I18n.t("bench.waiting"), x, card.y + 30, w, "left", "item_name", C.text_dim)
        Draw.text(I18n.t("bench.waiting_detail", { count = workshop.customers_left, cost = workshop.appraisal:summon_cost() }),
            x, card.y + 64, w, "left", SIZE.small, C.text_dim)
    end
end

return CustomerCard
