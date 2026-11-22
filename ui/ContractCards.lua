-- ui/ContractCards.lua
-- 난이도 계약서 카드 (states/DifficultyState): 좌표와 그리기. 위 줄 3장 · 아래 줄 2장 (data/difficulties.lua 의 rows,
-- 줄 높이·카드 크기는 data/layout.lua 의 difficulty.cards — 줄마다 가운데 정렬).
--   일반 카드 : 단계 색 띠 · "N단계 · 난이도" · 이름(금박) · 조항 3줄 · 플레이타임 · [F키] · 오른쪽 위 클리어 표시 / 사계절 표식
--   잠긴 카드 : 자물쇠 + 해금 조건 (악몽 — 베테랑 클리어 전)
--   봉인 카드 : 5단계 스승의 흔적이 잠겨 있는 동안(악몽 클리어 전, Progress.is_veiled) — '???' 검은 잉크로 지워진 조항 + 붉은 밀랍 인장
--              + "봉인된 계약 · 악몽 완수 시 해금" (문구 difficulty.<id>.veiled.*, 누르면 해금 안내만)
--   캠페인 카드: 봉인이 풀린 진엔딩 캠페인(difficulty 의 campaign) — 룬이 새겨진 은빛 띠 · 보라 결계선 · 모서리 자수정 틀(ui/RuneArt),
--              "5단계 · 진엔딩" · 은빛 이름 · 조항 3줄. 그 캠페인의 훈장 엔딩(data/endings.lua 의 medal)을 봤으면 오른쪽 위에
--              진엔딩 훈장 + "진엔딩 훈장" (title.medal_badge)
-- 규칙(해금 판정 · 훈장 기록)은 systems/Progress. face(id) / medal_center(rect) 는 스모크 테스트용.

local I18n = require("systems.I18n")
local Progress = require("systems.Progress")
local Calendar = require("systems.Calendar")
local Draw = require("ui.Draw")
local Frame = require("ui.Frame")
local Icons = require("ui.Icons")
local Lettering = require("ui.Lettering")
local RuneArt = require("ui.RuneArt")
local TransitionSeal = require("ui.TransitionSeal")
local CALENDAR = require("data.calendar")
local DIFFICULTIES = require("data.difficulties")
local ENDINGS = require("data.endings")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local ContractCards = {}

local C = UI.color
local SIZE = UI.font_size
local CARDS = LAYOUT.difficulty.cards
local LG = love.graphics
local PAD = 22
local INK_BLACK = { 0.02, 0.015, 0.02 }
local BURNT_PAPER = { 0.19, 0.14, 0.10 }     -- 봉인 카드 바탕: 그을린 양피지 (먹 얼룩·먹줄이 또렷하게 보이도록)
local BLOTS = { { 0.12, 0.30, 16 }, { 0.30, 0.82, 22 }, { 0.62, 0.20, 12 }, { 0.86, 0.88, 18 }, { 0.48, 0.58, 9 } }
local REDACTED_LINE = 2         -- 봉인 카드에서 먹으로 지운 조항 줄
local VIOLET_LIGHT = { 0.82, 0.70, 1.00 }       -- 캠페인 카드 단계 글자 · 단축키
local CAMPAIGN_TEXT = { 0.94, 0.92, 1.00 }      -- 캠페인 카드 조항 (보랏빛 도는 흰색)
local MEDAL_INSET, MEDAL_Y, MEDAL_R = 44, 35, 14    -- 훈장 원판: 카드 오른쪽 끝에서 안쪽 · 카드 위에서 아래 · 반지름 (리본은 위 띠까지)

-- 카드 안쪽 글자 폭 (요약 줄 한 줄이 들어가야 하는 폭 — 스모크 테스트가 ko · en 문구를 잰다)
function ContractCards.inner_width()
    return CARDS.w - PAD * 2
end

-- 그 계약 카드의 얼굴: "veiled"(봉인 '???') | "campaign"(봉인이 풀린 진엔딩 캠페인) | "contract"(일반 · 잠김)
function ContractCards.face(id)
    if Progress.is_veiled(id) then
        return "veiled"
    end
    return DIFFICULTIES.modes[id].campaign ~= nil and "campaign" or "contract"
end

-- 그 캠페인의 훈장 엔딩(data/endings.lua 의 medal)을 본 적이 있는지
function ContractCards.has_medal(id)
    local campaign = DIFFICULTIES.modes[id].campaign
    for _, ending in ipairs(ENDINGS.order) do
        local spec = ENDINGS.list[ending]
        if campaign ~= nil and spec.medal and spec.campaign == campaign and Progress.has_medal(ending) then
            return true
        end
    end
    return false
end

-- 캠페인 카드의 훈장 원판 중심 (호버 확대 전 화면 좌표 — 스모크 테스트가 금빛 픽셀을 확인한다)
function ContractCards.medal_center(rect)
    return rect.x + rect.w - MEDAL_INSET, rect.y + MEDAL_Y
end

-- index 번째 카드 자리 (order 순서)
function ContractCards.rect(index)
    local first = 1
    for row, count in ipairs(DIFFICULTIES.rows) do
        if index < first + count then
            local spec = CARDS.rows[row]
            local total = count * CARDS.w + (count - 1) * CARDS.gap
            local x0 = (LAYOUT.screen.w - total) / 2
            return { x = x0 + (index - first) * (CARDS.w + CARDS.gap), y = spec.y, w = CARDS.w, h = spec.h }
        end
        first = first + count
    end
    error("ContractCards: no card slot for index " .. tostring(index))
end

-- 해금 조건 문구: "'그레이븐의 베테랑'" (여러 개면 "또는"으로 잇는다)
function ContractCards.requirement_text(id)
    local names = {}
    for _, required in ipairs(Progress.unlock_requirements(id)) do
        names[#names + 1] = I18n.t("title.quoted", { name = I18n.t("difficulty." .. required .. ".name") })
    end
    return table.concat(names, I18n.t("title.requirement_join"))
end

-- 사계절 표식: 네 계절 색 점 + "사계절"
local function seasons_mark(x, y, w, alpha)
    local text = I18n.t("title.seasons_badge")
    local font = Draw.font("label")
    local tw = font:getWidth(text)
    local left = x + w - tw
    Draw.label_text(text, left, y, tw, "left", "label", C.link_boost, alpha)
    for i, season in ipairs(CALENDAR.season_order) do
        Draw.set_color(Calendar.season_color(season), alpha)
        LG.circle("fill", left - 8 - (#CALENDAR.season_order - i) * 9, y + font:getHeight() / 2, 3.5, 12)
    end
end

local function draw_contract(index, card, x, y, w, h, unlocked, hover)
    local prefix = "difficulty." .. card.id
    local tier_color = C[card.mode.tier_color] or C.text
    local alpha = unlocked and 1 or 0.55
    Frame.panel(x, y, w, h, { style = "dark", texture = "stone", texture_alpha = 0.15, alpha = 0.97 })
    Draw.set_color(tier_color, 0.9 * alpha)
    LG.rectangle("fill", x + 10, y + 10, w - 20, 5, 2, 2)
    if hover > 0.01 then                -- 호버: 금빛 테두리
        Draw.set_color(C.gold, hover)
        LG.setLineWidth(3)
        LG.rectangle("line", x + 3, y + 3, w - 6, h - 6, 8, 8)
    end
    local iw = w - PAD * 2
    Draw.text(I18n.t("title.card_tier", { index = index, tier = I18n.t(prefix .. ".tier") }), x + PAD, y + 22, iw, "left", "label",
        tier_color, alpha)
    if Progress.is_cleared(card.id) then
        Draw.text(I18n.t("title.cleared"), x + PAD, y + 22, iw, "right", "label", C.gold)
    elseif card.mode.seasons then
        seasons_mark(x + PAD, y + 22, iw, alpha)
    end
    Lettering.draw(I18n.t(prefix .. ".name"), x + PAD, y + 40, iw, "left", "card_title", unlocked and "gold" or "silver", alpha)
    if unlocked then
        for i, line in ipairs(I18n.list(prefix .. ".summary")) do
            local text = "· " .. line
            Draw.text(text, x + PAD, y + 78 + (i - 1) * 23, iw, "left", Draw.fit_size(text, iw, { SIZE.small, SIZE.tiny }), C.text, 0.9)
        end
    else
        Icons.draw("lock", 0, y + 92, 32, C.danger, 0.9)
        Draw.text(I18n.t("title.unlock_requirement", { names = ContractCards.requirement_text(card.id) }), x + 16, y + 116, w - 32,
            "center", SIZE.small, C.text)
    end
    Draw.text(I18n.t("title.playtime", { time = I18n.t(prefix .. ".playtime") }), x + PAD, y + h - 30, iw, "left", "label",
        C.text_dim, alpha)
    Draw.text(string.format("[F%d]", index), x + PAD, y + h - 30, iw, "right", "label", C.accent, alpha)
end

-- 봉인된 계약: 그을린 양피지 위 검은 잉크 얼룩 + 먹으로 지운 조항 + 붉은 밀랍 인장
local function draw_sealed(index, card, x, y, w, h, hover, time)
    local prefix = "difficulty." .. card.id .. ".veiled"
    Frame.panel(x, y, w, h, { style = "dark", texture = "stone", texture_alpha = 0.1, alpha = 0.97 })
    Draw.set_color(BURNT_PAPER, 0.96)
    LG.rectangle("fill", x + 6, y + 6, w - 12, h - 12, 8, 8)
    for i, blot in ipairs(BLOTS) do     -- 번진 잉크 얼룩: 반투명 번짐 + 튄 방울 두 개
        local bx, by, r = x + blot[1] * w, y + blot[2] * h, blot[3]
        Draw.set_color(INK_BLACK, 0.42)
        LG.circle("fill", bx, by, r, 20)
        LG.circle("fill", bx + r * 0.7, by - r * 0.45, r * 0.55, 16)
        Draw.set_color(INK_BLACK, 0.7)
        LG.circle("fill", bx - r * 1.3, by + r * (i % 2 == 0 and 0.6 or -0.5), 2.5, 8)
        LG.circle("fill", bx + r * 1.4, by + r * 0.9, 1.8, 8)
    end
    Draw.set_color(C[card.mode.tier_color] or C.uv, 0.35 + 0.25 * hover)
    LG.rectangle("fill", x + 10, y + 10, w - 20, 5, 2, 2)
    Draw.set_color(C.danger, 0.25 + 0.55 * hover)              -- 호버: 핏빛 테두리
    LG.setLineWidth(2)
    LG.rectangle("line", x + 4, y + 4, w - 8, h - 8, 8, 8)
    local iw = w - PAD * 2
    Draw.text(I18n.t("title.card_tier", { index = index, tier = I18n.t(prefix .. ".tier") }), x + PAD, y + 22, iw, "left", "label",
        C.text_disabled)
    Lettering.draw(I18n.t(prefix .. ".name"), x + PAD, y + 40, iw, "left", "card_title", "blood", 0.85)
    local font = Draw.font(SIZE.small)
    for i, line in ipairs(I18n.list(prefix .. ".summary")) do
        local ly = y + 78 + (i - 1) * 23
        local text = "· " .. line
        Draw.text(text, x + PAD, ly, iw - 86, "left", Draw.fit_size(text, iw - 86, { SIZE.small, SIZE.tiny }), C.text_dim, 0.8)
        if i == REDACTED_LINE then      -- 가운데 조항은 검은 잉크로 완전히 지워져 있다 (번진 가장자리 + 흘러내린 방울)
            local bx, bw, bh = x + PAD + 9, math.min(iw - 96, font:getWidth(text)) - 4, font:getHeight()
            Draw.set_color(INK_BLACK, 0.97)
            LG.rectangle("fill", bx, ly, bw, bh, 5, 5)
            for k = 0, 4 do
                LG.circle("fill", bx + (k + 0.5) * bw / 5, ly + (k % 2 == 0 and 1 or bh - 1), 3 + k % 2, 10)
            end
            LG.circle("fill", bx + bw * 0.3, ly + bh + 4, 2.5, 8)
            LG.rectangle("fill", bx + bw * 0.3 - 1, ly + bh - 2, 2, 5)
            LG.circle("fill", bx + bw * 0.72, ly + bh + 2, 2, 8)
        end
    end
    TransitionSeal.draw_wax_seal(x + w - 62, y + 104, 30 + 2 * hover + math.sin(time * 2) * 0.6, 1)
    Draw.text(I18n.t("title.sealed_label") .. " · " .. I18n.t("title.sealed_hint"), x + PAD, y + h - 30, iw, "left", "label",
        C.text_dim)
    Draw.text(string.format("[F%d]", index), x + PAD, y + h - 30, iw, "right", "label", C.text_disabled)
end

-- 진엔딩 캠페인: 룬 은빛 띠 틀 + "N단계 · 진엔딩" · 은빛 이름 · 조항 3줄 (+ 훈장을 받았으면 오른쪽 위에 훈장과 "진엔딩 훈장")
local function draw_campaign(index, card, x, y, w, h, hover, time)
    local prefix = "difficulty." .. card.id
    local iw = w - PAD * 2
    RuneArt.frame(x, y, w, h, time, hover)
    Draw.text(I18n.t("title.card_tier", { index = index, tier = I18n.t(prefix .. ".tier") }), x + PAD, y + 22, iw, "left", "label",
        VIOLET_LIGHT)
    if ContractCards.has_medal(card.id) then
        Draw.label_text(I18n.t("title.medal_badge"), x + PAD, y + 22, iw - (MEDAL_INSET + MEDAL_R + 8 - PAD), "right", "label", C.gold)
        RuneArt.medal(x + w - MEDAL_INSET, y + MEDAL_Y, MEDAL_R, { time = time })
    elseif Progress.is_cleared(card.id) then
        Draw.text(I18n.t("title.cleared"), x + PAD, y + 22, iw, "right", "label", C.gold)
    end
    Lettering.draw(I18n.t(prefix .. ".name"), x + PAD, y + 40, iw, "left", "card_title", "silver")
    for i, line in ipairs(I18n.list(prefix .. ".summary")) do
        local text = "· " .. line
        Draw.text(text, x + PAD, y + 78 + (i - 1) * 23, iw, "left", Draw.fit_size(text, iw, { SIZE.small, SIZE.tiny }), CAMPAIGN_TEXT,
            0.92)
    end
    Draw.text(I18n.t("title.playtime", { time = I18n.t(prefix .. ".playtime") }), x + PAD, y + h - 30, iw, "left", "label",
        C.text_dim)
    Draw.text(string.format("[F%d]", index), x + PAD, y + h - 30, iw, "right", "label", VIOLET_LIGHT)
end

-- card = { id, mode, button } (button: ui/Button — 호버 애니메이션·확대)
function ContractCards.draw(index, card, time)
    local rect = card.button.rect
    local hover = card.button._anim.hover
    LG.push()
    LG.translate(rect.x + rect.w / 2, rect.y + rect.h / 2 - 4 * hover)
    LG.scale(card.button:scale())
    local x, y, w, h = -rect.w / 2, -rect.h / 2, rect.w, rect.h
    local face = ContractCards.face(card.id)
    if face == "veiled" then
        draw_sealed(index, card, x, y, w, h, hover, time)
    elseif face == "campaign" then
        draw_campaign(index, card, x, y, w, h, hover, time)
    else
        draw_contract(index, card, x, y, w, h, card.button:is_enabled(), hover)
    end
    LG.pop()
end

return ContractCards
