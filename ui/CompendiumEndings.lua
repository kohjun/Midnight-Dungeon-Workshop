-- ui/CompendiumEndings.lua
-- 유물 도감(ui/CompendiumModal) 아래쪽 엔딩 수집 두 줄 (좌표 data/layout.lua 의 compendium, 엔딩 목록 data/endings.lua):
--   첫 줄 "엔딩 수집"    : 일반 계약의 엔딩 3종(base). 본 엔딩은 이름, 아니면 ??? — 조건은 늘 보인다
--                          ({hp} · {cursed} · {share} · {level} · {mult} 는 systems/Endings.condition_vars).
--                          인게임 일반 계약이면 상권 독점 카드 위에 이번 계약의 기준 한 줄 (systems/Endings.status — 마스터 장인 할인)
--   둘째 줄 "스승의 흔적" : 캠페인 엔딩 2종(campaign) + 진엔딩 훈장 칸 (보라 · 은 테두리). 숨은 결말(hidden)은 보기 전까지 ??? +
--                          "숨겨진 결말", 훈장 칸은 받았으면 금빛 훈장 + 칭호, 아니면 잿빛 훈장 + 받는 법.
--                          캠페인 계약이 아직 봉인(Progress.is_veiled)이면 머리글은 "봉인된 계약", 세 칸 모두 ??? + 봉인 안내 + 밀랍 인장.
--                          인게임 '스승의 흔적' 계약이면 머리글 오른쪽에 이번 계약의 봉인진 · 수기 진행 한 줄 (상권 독점 기준 대신)
-- 좌표: card_rect(row, col) · ending_rect(id) · medal_rect() · text_width() / 문구: entries() · target_text(status)
-- (스모크 테스트가 모든 카드 문구가 두 줄 안에 드는지 잰다)

local I18n = require("systems.I18n")
local Progress = require("systems.Progress")
local MetaProgression = require("systems.MetaProgression")
local Endings = require("systems.Endings")
local Draw = require("ui.Draw")
local Frame = require("ui.Frame")
local RuneArt = require("ui.RuneArt")
local TransitionSeal = require("ui.TransitionSeal")
local DIFFICULTIES = require("data.difficulties")
local ENDINGS = require("data.endings")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local CompendiumEndings = {}

local LG = love.graphics
local C = UI.color
local SIZE = UI.font_size
local L = LAYOUT.compendium
local TARGET_ENDING = "monopoly"            -- 일반 계약: 이번 계약 기준을 위에 보여 줄 엔딩 카드
local TARGET_SIZES = { SIZE.small, SIZE.tiny, 12 }
local NAME_SIZES = { "item_name", { role = "display", size = 16 } }
local HEADER_TOP = 3                        -- 머리글(plate 17) 줄 안에서 기준 문구의 위 여백
local NAME_TOP, TEXT_TOP, TEXT_PAD = 7, 31, 10
local MEDAL_R = 8                           -- 훈장 칸 이름 앞 훈장 원판 반지름
local BASE_SEEN, BASE_DARK = { 0.18, 0.14, 0.08 }, { 0.09, 0.08, 0.11 }
local CAMPAIGN_SEEN, CAMPAIGN_DARK = { 0.16, 0.11, 0.22 }, { 0.08, 0.06, 0.12 }
local VEILED_FILL = { 0.07, 0.055, 0.06 }
local VEILED_NAME = { 0.80, 0.40, 0.38 }   -- 봉인된 칸의 ??? (계약서 봉인 카드의 핏빛 ??? 와 같은 결)
local VIOLET_LIGHT = { 0.82, 0.70, 1.00 }
local SILVER = { 0.84, 0.86, 0.94 }

-- 캠페인 줄의 계약(difficulty id)과 훈장 엔딩 — data 에서 찾는다
local CAMPAIGN_CONTRACT, MEDAL_ENDING = nil, nil
for _, id in ipairs(ENDINGS.campaign) do
    local spec = ENDINGS.list[id]
    MEDAL_ENDING = MEDAL_ENDING or (spec.medal and id or nil)
    for _, contract in ipairs(DIFFICULTIES.order) do
        if DIFFICULTIES.modes[contract].campaign == spec.campaign then
            CAMPAIGN_CONTRACT = contract
        end
    end
end

local function card_width()
    return (L.detail_x - L.grid_x - 16 - L.ending_gap * 2) / 3
end

-- row 1 = 일반 엔딩 · row 2 = 캠페인 엔딩 + 훈장, col 1 ~ 3
function CompendiumEndings.card_rect(row, col)
    local w = card_width()
    local y = L.y + L.endings_y + L.ending_top + (row - 1) * (L.ending_h + L.ending_row_gap)
    return { x = L.x + L.grid_x + (col - 1) * (w + L.ending_gap), y = y, w = w, h = L.ending_h }
end

function CompendiumEndings.ending_rect(id)
    for row, list in ipairs({ ENDINGS.base, ENDINGS.campaign }) do
        for col, other in ipairs(list) do
            if other == id then
                return CompendiumEndings.card_rect(row, col)
            end
        end
    end
    error("CompendiumEndings: no card for ending '" .. tostring(id) .. "'")
end

function CompendiumEndings.medal_rect()
    return CompendiumEndings.card_rect(2, #ENDINGS.campaign + 1)
end

-- 카드 안 조건·안내 문구의 줄바꿈 폭 (SIZE.tiny 로 두 줄까지)
function CompendiumEndings.text_width()
    return card_width() - TEXT_PAD * 2
end

-- 캠페인 계약이 아직 '???' 로 봉인되어 있는지
function CompendiumEndings.is_veiled()
    return CAMPAIGN_CONTRACT ~= nil and Progress.is_veiled(CAMPAIGN_CONTRACT)
end

-- 카드 여섯 장의 내용 { id, kind("ending"|"medal"), campaign, veiled, seen, earned, rect, name, text }
function CompendiumEndings.entries()
    local vars, unknown = Endings.condition_vars(), I18n.t("compendium.ending_unknown")
    local veiled = CompendiumEndings.is_veiled()
    local list = {}
    for col, id in ipairs(ENDINGS.base) do
        local seen = MetaProgression.has_ending(id)
        list[#list + 1] = { id = id, kind = "ending", seen = seen, rect = CompendiumEndings.card_rect(1, col),
            name = seen and I18n.t("ending." .. id .. ".name") or unknown, text = I18n.t("ending." .. id .. ".condition", vars) }
    end
    for col, id in ipairs(ENDINGS.campaign) do
        local seen = not veiled and MetaProgression.has_ending(id)
        local text = I18n.t("ending." .. id .. ".condition", vars)
        if veiled then
            text = I18n.t("compendium.campaign_locked")
        elseif ENDINGS.list[id].hidden and not seen then
            text = I18n.t("compendium.hidden_condition")
        end
        list[#list + 1] = { id = id, kind = "ending", campaign = true, veiled = veiled, seen = seen,
            rect = CompendiumEndings.card_rect(2, col), name = seen and I18n.t("ending." .. id .. ".name") or unknown, text = text }
    end
    local earned = not veiled and MEDAL_ENDING ~= nil and Progress.has_medal(MEDAL_ENDING)
    list[#list + 1] = { id = "medal", kind = "medal", campaign = true, veiled = veiled, earned = earned,
        rect = CompendiumEndings.medal_rect(), name = veiled and unknown or I18n.t("compendium.medal_name"),
        text = veiled and I18n.t("compendium.campaign_locked") or I18n.t(earned and "compendium.medal_earned" or "compendium.medal_locked") }
    return list
end

-- 인게임 도감의 이번 계약 기준 한 줄 (status = systems/Endings.status(workshop), 타이틀 메뉴의 도감이면 nil → nil)
--   '스승의 흔적' 계약: 봉인진 점화 · 수기 진행 / 그 밖: 상권 독점 기준 골드 · 방벽 % (+master_level 유물 할인 표시)
function CompendiumEndings.target_text(status)
    if status == nil then
        return nil
    end
    local trace = status.trace
    if trace ~= nil then
        return I18n.t("compendium.campaign_target", { lit = trace.lit, slots = trace.slots, journals = trace.journals,
            total = trace.journal_total })
    end
    local vars = Endings.condition_vars()
    return I18n.t(status.master and "compendium.ending_target_master" or "compendium.ending_target",
        { gold = status.need, hp = vars.hp, level = vars.level })
end

local function card_fill(entry)
    if entry.veiled then
        return VEILED_FILL
    elseif entry.campaign then
        return (entry.seen or entry.earned) and CAMPAIGN_SEEN or CAMPAIGN_DARK
    end
    return entry.seen and BASE_SEEN or BASE_DARK
end

local function draw_card(entry, time)
    local r = entry.rect
    Frame.inset(r.x, r.y, r.w, r.h, 8, card_fill(entry))
    local lit = entry.seen or entry.earned
    if entry.campaign and not entry.veiled then          -- 캠페인 칸: 은빛 테두리 + 본 칸은 보랏빛 결계선
        LG.setLineWidth(1)
        Draw.set_color(SILVER, 0.4)
        LG.rectangle("line", r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1, 8, 8)
        if lit then
            Draw.set_color(C.uv, 0.5 + 0.15 * math.sin(time * 2))
            LG.rectangle("line", r.x + 3.5, r.y + 3.5, r.w - 7, r.h - 7, 6, 6)
        end
    end
    local name_color = lit and (entry.campaign and VIOLET_LIGHT or C.gold) or (entry.veiled and VEILED_NAME or C.text_dim)
    if entry.kind == "medal" and not entry.veiled then   -- 훈장 칸: 이름 앞에 훈장 (이름과 함께 가운데)
        name_color = entry.earned and C.gold or C.text_dim
        local tw = Draw.font("item_name"):getWidth(entry.name)
        local left = r.x + (r.w - (MEDAL_R * 2 + 8 + tw)) / 2
        RuneArt.medal(left + MEDAL_R, r.y + NAME_TOP + 14, MEDAL_R, { earned = entry.earned, time = time })
        Draw.text(entry.name, left + MEDAL_R * 2 + 8, r.y + NAME_TOP, tw + 2, "left", "item_name", name_color)
    else
        Draw.text(entry.name, r.x + TEXT_PAD, r.y + NAME_TOP, r.w - TEXT_PAD * 2, "center",
            Draw.fit_size(entry.name, r.w - TEXT_PAD * 2, NAME_SIZES), name_color)
    end
    Draw.text(entry.text, r.x + TEXT_PAD, r.y + TEXT_TOP, r.w - TEXT_PAD * 2, "center", SIZE.tiny, C.text_dim)
    if entry.veiled then                                 -- 봉인된 캠페인: 오른쪽 위 붉은 밀랍 인장 (이름 줄 높이)
        TransitionSeal.draw_wax_seal(r.x + r.w - 22, r.y + 18, 10, 0.9)
    end
end

-- 캠페인 머리글: 룬 · "스승의 흔적"(봉인 중이면 "봉인된 계약") · 보라 선 · (인게임 캠페인) 이번 계약 진행
local function draw_campaign_header(target, veiled, time)
    local first, last = CompendiumEndings.card_rect(2, 1), CompendiumEndings.medal_rect()
    local y, right = first.y - L.ending_top, last.x + last.w
    local title = veiled and I18n.t("title.sealed_label") or I18n.t("compendium.campaign_title")
    local color = veiled and C.text_disabled or VIOLET_LIGHT
    local font = Draw.font("plate")
    local mid = y + font:getHeight() / 2
    LG.setLineWidth(1.5)
    Draw.set_color(color, 0.9)
    RuneArt.glyph(RuneArt.DAWN, first.x + 6, mid, 12)
    Draw.text(title, first.x + 18, y, 400, "left", "plate", color)
    local line_from = first.x + 18 + font:getWidth(title) + 12
    local line_to = right
    if target ~= nil then
        local size = Draw.fit_size(target, right - line_from - 16, TARGET_SIZES)
        local width = Draw.font(size):getWidth(target)
        Draw.text(target, right - width, y + HEADER_TOP, width, "right", size, VIOLET_LIGHT)
        line_to = right - width - 12
    end
    if line_to > line_from + 8 then
        Draw.set_color(C.uv, 0.3 + 0.1 * math.sin(time * 1.5))
        LG.setLineWidth(1)
        LG.line(line_from, mid, line_to, mid)
        LG.polygon("fill", line_to, mid - 3, line_to + 3, mid, line_to, mid + 3, line_to - 3, mid)
    end
end

-- status: systems/Endings.status(workshop) (인게임) 또는 nil (타이틀 메뉴)
function CompendiumEndings.draw(status, time)
    Draw.text(I18n.t("compendium.endings_title"), L.x + L.grid_x, L.y + L.endings_y, 400, "left", "plate", C.accent)
    local target = CompendiumEndings.target_text(status)
    local campaign_run = status ~= nil and status.trace ~= nil
    for _, entry in ipairs(CompendiumEndings.entries()) do
        draw_card(entry, time)
    end
    if target ~= nil and not campaign_run then          -- 일반 계약: 상권 독점 카드 바로 위 (머리글 줄의 빈 오른쪽)
        local r = CompendiumEndings.ending_rect(TARGET_ENDING)
        Draw.text(target, r.x, L.y + L.endings_y + HEADER_TOP, r.w, "center", Draw.fit_size(target, r.w, TARGET_SIZES), C.gold)
    end
    draw_campaign_header(campaign_run and target or nil, CompendiumEndings.is_veiled(), time)
end

return CompendiumEndings
