-- ui/SealSigil.lua
-- 스승의 은빛 인장 표식 ('스승의 흔적' 캠페인 — item.silver_seal, systems/MasterTrace). 규칙 계산 없음.
-- 모양: 먹 받침 원 + 은청색 이중 고리 + 여덟 눈금 + 감정사의 눈(두 호 + 눈동자). 코드로 그려 원화가 필요 없다.
--   SealSigil.draw(x, y, r, alpha, time, opts) : 화면 좌표든 유물 정규화 좌표(UV 투시, ui/ItemRenderer)든 같은 모양
--                                                (선 굵기 · 빛번짐이 r 에 비례). opts = { glow = true, ink = true, color }
--   SealSigil.dot(x, y, r, alpha)              : 칸 모서리의 작은 은빛 마름모 (찾은 인장이 있는 내 유물)
--   SealSigil.COLOR (은청색) · SILVER (은백) · INK — 연출(ui/FeedbackTrace) · 수기 창이 같은 색을 쓴다

local Draw = require("ui.Draw")

local SealSigil = {}

local LG = love.graphics
local TWO_PI = math.pi * 2
local EYE_POINTS = 10           -- 눈 윤곽 한쪽 호의 점 수

SealSigil.COLOR = { 0.62, 0.84, 1.00 }
SealSigil.SILVER = { 0.90, 0.94, 1.00 }
SealSigil.INK = { 0.04, 0.03, 0.06 }

-- 감정사의 눈: (-w, 0) ~ (w, 0) 사이 위아래로 h 만큼 부푼 렌즈 모양 닫힌 선
local function eye(x, y, w, h)
    local points = {}
    for i = 0, EYE_POINTS do
        local t = i / EYE_POINTS * 2 - 1
        points[#points + 1] = x + t * w
        points[#points + 1] = y - (1 - t * t) * h
    end
    for i = EYE_POINTS - 1, 1, -1 do
        local t = i / EYE_POINTS * 2 - 1
        points[#points + 1] = x + t * w
        points[#points + 1] = y + (1 - t * t) * h
    end
    LG.polygon("line", points)
end

-- r: 바깥 고리 반지름. time 으로 은은하게 맥동한다
function SealSigil.draw(x, y, r, alpha, time, opts)
    opts = opts or {}
    alpha = alpha or 1
    local color = opts.color or SealSigil.COLOR
    local pulse = 0.5 + 0.5 * math.sin((time or 0) * 3.2)
    local radius = r * (1 + 0.04 * pulse)
    if opts.glow ~= false then
        Draw.glow(x, y, radius * 2.4, color, alpha * (0.45 + 0.35 * pulse))
    end
    if opts.ink ~= false then                   -- 먹 받침: 밝은 원화 위에서도 또렷하게
        Draw.set_color(SealSigil.INK, 0.55 * alpha)
        LG.circle("fill", x, y, radius * 1.12, 32)
    end
    local line = radius * 0.13
    Draw.set_color(color, alpha)
    LG.setLineWidth(line)
    LG.circle("line", x, y, radius, 32)
    LG.setLineWidth(line * 0.55)
    LG.circle("line", x, y, radius * 0.76, 32)
    for i = 0, 7 do                             -- 여덟 눈금 (네 방위는 길게)
        local a = i / 8 * TWO_PI
        local inner = i % 2 == 0 and 0.58 or 0.66
        LG.line(x + math.cos(a) * radius * inner, y + math.sin(a) * radius * inner,
            x + math.cos(a) * radius * 0.76, y + math.sin(a) * radius * 0.76)
    end
    Draw.set_color(SealSigil.SILVER, alpha)
    LG.setLineWidth(line * 0.75)
    eye(x, y, radius * 0.5, radius * 0.27)
    LG.circle("fill", x, y, radius * (0.12 + 0.03 * pulse), 16)
end

-- 작은 은빛 마름모 (먹 외곽선 + 윗면 반사)
function SealSigil.dot(x, y, r, alpha)
    alpha = alpha or 1
    Draw.set_color(SealSigil.INK, 0.9 * alpha)
    LG.polygon("fill", x, y - r - 1.5, x + r + 1.5, y, x, y + r + 1.5, x - r - 1.5, y)
    Draw.set_color(SealSigil.COLOR, alpha)
    LG.polygon("fill", x, y - r, x + r, y, x, y + r, x - r, y)
    Draw.set_color(SealSigil.SILVER, 0.85 * alpha)
    LG.polygon("fill", x, y - r * 0.7, x + r * 0.35, y - r * 0.15, x - r * 0.35, y - r * 0.15)
end

return SealSigil
