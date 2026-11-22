-- ui/HudStatus.lua
-- 상단 HUD 왼쪽 상태 카드 4장 (좌표 data/layout.lua 의 hud, ui/Hud 가 부른다). 규칙 계산 없음.
--   badge  : 날짜·페이즈 배지 — "M개월 D일" + (현재/목표일) / 낮 정비(호박색) · 밤 방어(보라) · 소탕 시간(붉은색) + 남은 손님·시간
--            + 오른쪽 아래 계절 배지(사계절 계약, ui/SeasonBadge) · 포탈 간섭 배지('스승의 흔적', 1~6단계) 또는 난이도 단계 글자,
--            밤 과부하 중에는 깜빡이는 "과부하!"
--   ward   : 방벽 내구도 — icon_ward + 석조 체력 게이지(10칸 눈금) + 현재/최대, 피격 시 붉은 테두리
--   tribute: 결계 유지비 카드 — "D-N · 금액 G" 압축 표기, 보유 골드가 모자라면 붉게 맥동하는 테두리
--   purse  : 보유 재화 — icon_gold + 골드, icon_stone + 연마석 (획득 시 튀어 오름)
-- 아이콘 원화(data/art.lua 의 ui_props)가 없으면 ui/Icons 도형으로 그린다.

local I18n = require("systems.I18n")
local Draw = require("ui.Draw")
local Icons = require("ui.Icons")
local Lettering = require("ui.Lettering")
local CalendarText = require("ui.CalendarText")
local SeasonBadge = require("ui.SeasonBadge")
local SpriteBank = require("ui.SpriteBank")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local HudStatus = {}

local C = UI.color
local Z = LAYOUT.hud
local LG = love.graphics
local INK = { 0.03, 0.02, 0.02 }
local BRASS = { 0.78, 0.60, 0.30 }
local CARD_FILL = { 0.085, 0.07, 0.065 }
local STONE = { 0.17, 0.15, 0.15 }
local TONES = {
    day = { fill = { 0.27, 0.17, 0.07 }, edge = { 0.98, 0.72, 0.30 }, text = { 1.0, 0.84, 0.50 } },
    night = { fill = { 0.18, 0.08, 0.24 }, edge = { 0.74, 0.44, 0.96 }, text = { 0.88, 0.74, 1.0 } },
    overtime = { fill = { 0.28, 0.06, 0.09 }, edge = C.danger, text = { 1.0, 0.66, 0.60 } },
}
local FIT_SMALL = { "label", { role = "ui", size = 12 }, { role = "ui", size = 11 } }
local FIT_MAIN = { "button", "button_small", { role = "ui", size = 12 } }

-- 카드 바탕: 먹 외곽선 + 어두운 바탕 + 황동 안쪽 선 (border = 경고 색 테두리)
local function card(r, fill, border, border_alpha)
    LG.setColor(0, 0, 0, 0.4)
    LG.rectangle("fill", r.x + 1, r.y + 3, r.w, r.h, 7, 7)
    Draw.set_color(INK)
    LG.rectangle("fill", r.x - 2, r.y - 2, r.w + 4, r.h + 4, 8, 8)
    Draw.set_color(fill or CARD_FILL)
    LG.rectangle("fill", r.x, r.y, r.w, r.h, 6, 6)
    Draw.set_color({ 1, 1, 1 }, 0.06)
    LG.rectangle("fill", r.x + 2, r.y + 2, r.w - 4, r.h * 0.42, 5, 5)
    Draw.set_color(border or BRASS, border_alpha or 0.55)
    LG.setLineWidth(border and 2 or 1)
    LG.rectangle("line", r.x + 1.5, r.y + 1.5, r.w - 3, r.h - 3, 5, 5)
end

local function icon(sprite, fallback, cx, cy, size, color)
    local image = SpriteBank.image(sprite)
    if image ~= nil then
        SpriteBank.draw_fit(image, cx, cy, size)
    else
        Icons.draw(fallback, cx, cy, size * 0.7, color)
    end
end

local function fitted(text, x, y, w, align, sizes, color, alpha)
    Draw.label_text(text, x, y, w, align, Draw.fit_size(text, w, sizes), color, alpha)
end

function HudStatus.badge(workshop, time)
    local r = Z.badge
    local night = workshop.phase == "night"
    local combat = workshop.combat
    local overtime = night and combat:in_overtime()
    local tone = TONES[overtime and "overtime" or (night and "night" or "day")]
    card(r, tone.fill, tone.edge, 0.85)
    local x, w = r.x + 10, r.w - 20
    local count = CalendarText.count(workshop)                     -- 1줄: "2개월 3일" ……… "(13/60)"
    local count_w = Draw.font("label"):getWidth(count)
    Draw.label_text(count, x, r.y + 7, w, "right", "label", C.text_dim)
    fitted(CalendarText.date(workshop.day), x, r.y + 5, w - count_w - 6, "left", FIT_MAIN, tone.text)
    local chip_w = 0                                   -- 2줄 오른쪽: 과부하 깜빡임 · 계절 배지 · 포탈 간섭 배지 · 난이도 단계
    if night and combat.overclock then
        chip_w = Draw.font("label"):getWidth(I18n.t("hud.overclock")) + 4
        if math.sin(time * 12) > -0.3 then
            Draw.label_text(I18n.t("hud.overclock"), x, r.y + 27, w, "right", "label", C.overclock)
        end
    elseif workshop:season() ~= nil then
        chip_w = SeasonBadge.width(workshop:season()) + 4
        SeasonBadge.draw(workshop:season(), x + w - chip_w + 4, r.y + 25, 17)
    elseif workshop:interference() ~= nil then                     -- '스승의 흔적': 계절 대신 포탈 간섭 단계
        local level = workshop:interference()
        chip_w = SeasonBadge.interference_width(level) + 4
        SeasonBadge.draw_interference(level, x + w - chip_w + 4, r.y + 25, 17, 1, nil, time)
    else
        local tier = I18n.t("difficulty." .. workshop.difficulty_id .. ".tier")
        chip_w = Draw.font("label"):getWidth(tier) + 4
        Draw.label_text(tier, x, r.y + 27, w, "right", "label", C[workshop.rules.tier_color] or C.text_dim)
    end
    Icons.draw(night and "moon" or "sun", x + 7, r.y + 33, 14, tone.edge)
    local detail
    if overtime then
        detail = I18n.t("hud.badge_overtime", { count = combat:alive_count() })
    elseif night then
        detail = I18n.t("hud.badge_seconds", { seconds = math.ceil(combat:time_left()) })
    else
        detail = I18n.t("hud.badge_customers", { count = workshop.customers_left })
    end
    local line = I18n.t(night and "hud.badge_phase_night" or "hud.badge_phase_day") .. " · " .. detail
    if Draw.font(FIT_MAIN[#FIT_MAIN]):getWidth(line) > w - 18 - chip_w then
        line = detail       -- 가장 작은 글자로도 한 줄에 안 들면 페이즈 이름은 해·달 아이콘에 맡기고 내용만 (줄바꿈 방지)
    end
    fitted(line, x + 18, r.y + 25, w - 18 - chip_w, "left", FIT_MAIN, overtime and C.danger or C.text)
end

-- hit: 피격 직후 0~1 (붉은 테두리)
function HudStatus.ward(workshop, hit)
    local r = Z.ward
    card(r, nil, hit > 0 and C.danger or nil, hit > 0 and hit or nil)
    icon("icon_ward", "shield", r.x + 19, r.y + r.h / 2, 32, C.text_dim)
    local x, w = r.x + 38, r.w - 46
    local ratio = math.max(0, math.min(1, workshop.hp / workshop.max_hp))
    Draw.label_text(I18n.t("hud.wall_hp"), x, r.y + 5, w, "left", "label", C.text_dim)
    Draw.label_text(string.format("%d / %d", math.ceil(workshop.hp), workshop.max_hp), x, r.y + 4, w, "right", "button",
        ratio > 0.25 and C.text or C.danger)
    local by, bh = r.y + 27, 12                                -- 석조 게이지: 먹 홈 + 돌 바탕 + 채움 + 10칸 눈금
    Draw.set_color(INK)
    LG.rectangle("fill", x - 2, by - 2, w + 4, bh + 4, 4, 4)
    Draw.set_color(STONE)
    LG.rectangle("fill", x, by, w, bh, 3, 3)
    local fill = ratio > 0.5 and C.good or (ratio > 0.25 and C.accent or C.danger)
    if ratio > 0 then
        Draw.set_color(fill)
        LG.rectangle("fill", x, by, w * ratio, bh, 3, 3)
        Draw.set_color({ 1, 1, 1 }, 0.28)
        LG.rectangle("fill", x + 1, by + 1, w * ratio - 2, 3, 2, 2)
    end
    Draw.set_color(INK, 0.75)
    LG.setLineWidth(1)
    for i = 1, 9 do
        local nx = math.floor(x + w * i / 10) + 0.5
        LG.line(nx, by + 1, nx, by + bh - 1)
    end
end

function HudStatus.tribute(workshop, time)
    local r = Z.tribute
    local due, amount = workshop.tribute:next_due(workshop.day)
    local short = due ~= nil and workshop.gold < amount
    card(r, nil, short and C.danger or nil, short and (0.55 + 0.45 * math.sin(time * 5)) or nil)
    local x, w = r.x + 8, r.w - 16
    fitted(I18n.t("hud.tribute_label"), x, r.y + 5, w, "left", FIT_SMALL, C.text_dim)
    local text, color
    if due == nil then
        text, color = I18n.t("hud.tribute_card_none"), C.good
    elseif due == workshop.day then
        text, color = I18n.t("hud.tribute_card_today", { amount = amount }), C.danger
    else
        text, color = I18n.t("hud.tribute_card", { days = due - workshop.day, amount = amount }), short and C.danger or C.accent
    end
    fitted(text, x, r.y + 24, w, "left", FIT_MAIN, color)
end

-- 재화 하나: 아이콘 + 장식 숫자 (scale = 획득 튀어 오름)
local function amount(sprite, fallback, color, text, style, cx, cy, scale)
    local font = Draw.font("value_small")
    local width = 30 + font:getWidth(text)
    LG.push()
    LG.translate(cx, cy)
    LG.scale(scale)
    icon(sprite, fallback, -width / 2 + 13, 0, 28, color)
    Lettering.draw(text, -width / 2 + 30, -font:getHeight() / 2, width, "left", "value_small", style)
    LG.pop()
end

-- gold, stones: 보일 값 (새벽 정산 카운트업 중에는 Hud 가 올라가는 값을 준다), glow: 카운트업 반짝임 0~1
function HudStatus.purse(workshop, anim, gold, stones, glow)
    local r = Z.purse
    card(r, nil, glow > 0 and C.gold or nil, glow > 0 and glow or nil)
    if glow > 0 then
        LG.setBlendMode("add")
        Draw.set_color(C.gold, 0.22 * glow * (0.7 + 0.3 * math.sin(love.timer.getTime() * 18)))
        LG.rectangle("fill", r.x - 4, r.y - 4, r.w + 8, r.h + 8, 9, 9)
        LG.setBlendMode("alpha")
    end
    amount("icon_gold", "coin", C.gold, string.format("%d G", gold), "gold", Z.gold.cx, Z.gold.cy, anim.gold + 0.12 * glow)
    amount("icon_stone", "stone", C.stone, tostring(stones), "ember", Z.stones.cx, Z.stones.cy, anim.stones + 0.12 * glow)
end

return HudStatus
