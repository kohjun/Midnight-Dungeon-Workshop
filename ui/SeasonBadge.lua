-- ui/SeasonBadge.lua
-- 계절 배지 (어려움·악몽 — 사계절 계약): 어두운 알약 + 계절 색 테두리 + 코드로 그린 계절 표식(새싹 · 해 · 단풍 · 눈송이) + 이름.
-- HUD 날짜 카드(ui/HudStatus) · 새벽 정산창(ui/DawnSummary)이 쓴다. 색은 data/calendar.lua.
--   SeasonBadge.width(season, spec) · SeasonBadge.draw(season, x, y, h, alpha, spec) → 그린 너비 (x = 왼쪽 끝)
-- '스승의 흔적'(계절 대신 포탈 간섭 1~6단계, data/master_trace.lua 의 interference)은 간섭 배지:
--   균열이 가로지르는 보라 포탈 표식 — 단계가 오를수록 빛번짐·맥동이 세지고 테두리가 밝아진다 + "간섭 N"
--   SeasonBadge.interference_width(level, spec) · SeasonBadge.draw_interference(level, x, y, h, alpha, spec, time) → 그린 너비

local I18n = require("systems.I18n")
local Draw = require("ui.Draw")
local CalendarText = require("ui.CalendarText")
local Calendar = require("systems.Calendar")
local TRACE = require("data.master_trace")

local SeasonBadge = {}

local LG = love.graphics
local INK = { 0.03, 0.02, 0.02 }
local FILL = { 0.07, 0.06, 0.06 }
local RIFT_FILL = { 0.08, 0.05, 0.12 }
local CRACK = { 1.0, 0.94, 1.0 }
local PAD = 6
local MARK = 12             -- 계절 표식 칸 너비
local RIFT_PAD = 4          -- 간섭 배지 안쪽 여백 (계절 배지보다 글자가 길어 날짜 카드 둘째 줄이 한 줄에 들도록 좁게)
local RIFT_MARK = 10        -- 간섭 표식 칸 너비
local RIFT_GAP = 2

local function mark(season, cx, cy, r, color, alpha)
    Draw.set_color(color, alpha)
    LG.setLineWidth(1.5)
    if season == "spring" then            -- 새싹: 줄기 + 잎 두 장
        LG.line(cx, cy + r, cx, cy - r * 0.2)
        LG.ellipse("fill", cx - r * 0.45, cy - r * 0.35, r * 0.5, r * 0.28)
        LG.ellipse("fill", cx + r * 0.45, cy - r * 0.55, r * 0.5, r * 0.28)
    elseif season == "summer" then        -- 해: 원 + 햇살 8줄
        LG.circle("fill", cx, cy, r * 0.45)
        for i = 0, 7 do
            local a = i * math.pi / 4
            LG.line(cx + math.cos(a) * r * 0.65, cy + math.sin(a) * r * 0.65, cx + math.cos(a) * r, cy + math.sin(a) * r)
        end
    elseif season == "autumn" then        -- 단풍: 5갈래 별
        local points = {}
        for i = 0, 9 do
            local a = -math.pi / 2 + i * math.pi / 5
            local radius = i % 2 == 0 and r or r * 0.45
            points[#points + 1] = cx + math.cos(a) * radius
            points[#points + 1] = cy + math.sin(a) * radius
        end
        for _, triangle in ipairs(love.math.triangulate(points)) do
            LG.polygon("fill", triangle)
        end
    else                                  -- 눈송이: 선 3줄 + 끝 가지
        for i = 0, 2 do
            local a = i * math.pi / 3
            local dx, dy = math.cos(a) * r, math.sin(a) * r
            LG.line(cx - dx, cy - dy, cx + dx, cy + dy)
        end
        LG.circle("fill", cx, cy, r * 0.22)
    end
end

function SeasonBadge.width(season, spec)
    return Draw.font(spec or "label"):getWidth(CalendarText.season_name(season)) + PAD * 2 + MARK + 3
end

function SeasonBadge.draw(season, x, y, h, alpha, spec)
    alpha = alpha or 1
    local color = Calendar.season_color(season)
    local w = SeasonBadge.width(season, spec)
    Draw.set_color(INK, alpha)
    LG.rectangle("fill", x - 1.5, y - 1.5, w + 3, h + 3, h / 2 + 1, h / 2 + 1)
    Draw.set_color(FILL, alpha)
    LG.rectangle("fill", x, y, w, h, h / 2, h / 2)
    Draw.set_color(color, 0.85 * alpha)
    LG.setLineWidth(1.5)
    LG.rectangle("line", x + 0.75, y + 0.75, w - 1.5, h - 1.5, h / 2, h / 2)
    mark(season, x + PAD + MARK / 2, y + h / 2, MARK / 2 - 0.5, color, alpha)
    local font = Draw.font(spec or "label")
    Draw.label_text(CalendarText.season_name(season), x + PAD + MARK + 3, y + (h - font:getHeight()) / 2, w - PAD * 2 - MARK,
        "left", spec or "label", color, alpha)
    return w
end

-- ── 포탈 간섭 ('스승의 흔적') ─────────────────────────────────
-- 포탈 표식: 세로 타원 + 안쪽 소용돌이 + 가로지르는 균열. ratio = 단계 / 최대 단계 (빛·맥동 세기)
local function rift(cx, cy, r, color, alpha, ratio, time)
    local pulse = 0.5 + 0.5 * math.sin(time * (2 + ratio * 6))
    LG.setBlendMode("add")
    Draw.set_color(color, alpha * (0.15 + 0.55 * ratio) * (0.55 + 0.45 * pulse))
    LG.ellipse("fill", cx, cy, r * 1.35, r * 1.55, 18)
    LG.setBlendMode("alpha")
    Draw.set_color(color, alpha * (0.3 + 0.5 * ratio))
    LG.ellipse("fill", cx, cy, r * 0.55, r * 0.85, 14)
    Draw.set_color(color, alpha)
    LG.setLineWidth(1.5)
    LG.ellipse("line", cx, cy, r * 0.72, r, 18)
    Draw.set_color(CRACK, alpha * (0.55 + 0.45 * ratio))
    LG.setLineWidth(1)
    LG.line(cx + r * 0.2, cy - r * 1.05, cx - r * 0.18, cy - r * 0.25, cx + r * 0.22, cy + r * 0.2, cx - r * 0.12, cy + r * 1.05)
end

local function interference_text(level)
    return I18n.t("trace.interference.badge", { level = level })
end

function SeasonBadge.interference_width(level, spec)
    return Draw.font(spec or "label"):getWidth(interference_text(level)) + RIFT_PAD * 2 + RIFT_MARK + RIFT_GAP
end

function SeasonBadge.draw_interference(level, x, y, h, alpha, spec, time)
    alpha, time = alpha or 1, time or 0
    local color = TRACE.interference.color
    local ratio = math.max(0, math.min(1, level / TRACE.interference.months))
    local w = SeasonBadge.interference_width(level, spec)
    Draw.set_color(INK, alpha)
    LG.rectangle("fill", x - 1.5, y - 1.5, w + 3, h + 3, h / 2 + 1, h / 2 + 1)
    Draw.set_color(RIFT_FILL, alpha)
    LG.rectangle("fill", x, y, w, h, h / 2, h / 2)
    Draw.set_color(color, (0.45 + 0.5 * ratio) * alpha)
    LG.setLineWidth(1.5)
    LG.rectangle("line", x + 0.75, y + 0.75, w - 1.5, h - 1.5, h / 2, h / 2)
    rift(x + RIFT_PAD + RIFT_MARK / 2 + 1, y + h / 2, RIFT_MARK / 2 - 0.5, color, alpha, ratio, time)
    local font = Draw.font(spec or "label")
    local tx = x + RIFT_PAD + RIFT_MARK + RIFT_GAP
    Draw.label_text(interference_text(level), tx, y + (h - font:getHeight()) / 2, x + w - tx, "left", spec or "label",
        Draw.lerp_color(color, CRACK, 0.25), alpha)
    return w
end

return SeasonBadge
