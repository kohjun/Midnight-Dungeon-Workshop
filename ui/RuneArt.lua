-- ui/RuneArt.lua
-- '스승의 흔적' 캠페인 화면 밖(계약서 · 도감 · 엔딩 · 결과)에서 함께 쓰는 코드 그림 (원화 없음, 모두 도형):
--   RuneArt.glyph(index, cx, cy, size)            : 룬 글자 하나 (색·굵기는 호출 측이 정한다). index 는 1 ~ RuneArt.COUNT 를 돈다
--   RuneArt.frame(x, y, w, h, time, hover, alpha) : 진엔딩 계약 카드 틀 — 먹선 외곽 · 룬이 새겨진 은빛 띠(보랏빛이 띠를 따라
--                                                   흐른다) · 보라 결계선 · 모서리 자수정 (호버: 바깥 보랏빛 번짐 + 밝은 결계선)
--   RuneArt.medal(cx, cy, r, opts)                : 진엔딩 훈장 — 보라·은 줄무늬 리본 + 금빛 원판 + 새벽(다가즈) 룬
--                                                   opts = { earned (false 면 잿빛 빈 훈장), alpha, time }
-- 색은 순수 표현용 상수다 (data 수치와 무관).

local Draw = require("ui.Draw")
local SpriteBank = require("ui.SpriteBank")
local UI = require("data.ui")

local RuneArt = {}

local LG = love.graphics
local C = UI.color
local INK = { 0.02, 0.015, 0.03 }
local SILVER = { 0.84, 0.86, 0.94 }
local SILVER_BAND = { 0.47, 0.48, 0.58 }
local VIOLET = C.uv
local VIOLET_LIGHT = { 0.82, 0.70, 1.00 }
local VIOLET_DEEP = { 0.34, 0.18, 0.62 }
local NIGHT = { 0.065, 0.05, 0.10 }
local GOLD = { 1.00, 0.80, 0.32 }
local GOLD_RIM = { 0.66, 0.42, 0.10 }
local GOLD_INK = { 0.36, 0.17, 0.04 }
local ASH = { 0.24, 0.23, 0.29 }
local ASH_RIM = { 0.15, 0.14, 0.19 }
local ASH_LIGHT = { 0.36, 0.35, 0.42 }
local BAND = 8              -- 은빛 띠 두께
local RADIUS = 10
local GLYPH_STEP = 13       -- 띠에 새긴 룬 간격
local DAGAZ = 13            -- 새벽 룬 (훈장 문양)

-- 룬 글자: 획(폴리라인) 목록, 정규화 좌표 (-0.5 ~ 0.5, 아래가 +y)
local GLYPHS = {
    { { 0, -0.5, 0, 0.5 }, { 0, -0.2, 0.3, -0.46 }, { 0, 0.06, 0.3, -0.2 } },                    -- 페후
    { { -0.24, 0.5, -0.24, -0.5, 0.24, -0.18, 0.24, 0.5 } },                                       -- 우루즈
    { { 0, -0.5, 0, 0.5 }, { 0, -0.24, 0.28, 0, 0, 0.24 } },                                       -- 투리사즈
    { { -0.08, -0.5, -0.08, 0.5 }, { -0.08, -0.5, 0.26, -0.22 }, { -0.08, -0.16, 0.26, 0.12 } },  -- 안수즈
    { { -0.2, 0.5, -0.2, -0.5, 0.2, -0.26, -0.2, 0, 0.24, 0.5 } },                                 -- 라이도
    { { 0.2, -0.42, -0.2, 0, 0.2, 0.42 } },                                                        -- 카우난
    { { -0.3, -0.45, 0.3, 0.45 }, { 0.3, -0.45, -0.3, 0.45 } },                                    -- 게보
    { { -0.24, -0.5, -0.24, 0.5 }, { 0.24, -0.5, 0.24, 0.5 }, { -0.24, -0.16, 0.24, 0.16 } },     -- 하갈라즈
    { { 0, -0.5, 0, 0.5 }, { -0.24, -0.14, 0.24, 0.14 } },                                         -- 나우디즈
    { { 0, -0.5, 0, 0.5 }, { -0.3, -0.46, 0, -0.06, 0.3, -0.46 } },                                -- 알기즈
    { { 0, -0.5, 0, 0.5 }, { -0.28, -0.2, 0, -0.5, 0.28, -0.2 } },                                 -- 티와즈
    { { -0.2, -0.5, -0.2, 0.5, 0.22, 0.25, -0.2, 0, 0.22, -0.25, -0.2, -0.5 } },                   -- 베르카난
    { { -0.3, -0.4, -0.3, 0.4, 0.3, -0.4, 0.3, 0.4, -0.3, -0.4 } },                                -- 다가즈 (새벽)
    { { -0.24, 0.5, -0.24, -0.5, 0.24, -0.04 }, { 0.24, 0.5, 0.24, -0.5, -0.24, -0.04 } },        -- 만나즈
    { { 0, -0.5, 0.26, -0.18, -0.26, 0.5 }, { 0, -0.5, -0.26, -0.18, 0.26, 0.5 } },               -- 오탈라
    { { 0.16, -0.5, -0.2, -0.12, 0.2, 0.12, -0.16, 0.5 } },                                        -- 소윌로 (해)
}
RuneArt.COUNT = #GLYPHS
RuneArt.DAWN = DAGAZ

function RuneArt.glyph(index, cx, cy, size)
    local strokes = GLYPHS[(index - 1) % #GLYPHS + 1]
    for _, stroke in ipairs(strokes) do
        local points = {}
        for i = 1, #stroke, 2 do
            points[i] = cx + stroke[i] * size
            points[i + 1] = cy + stroke[i + 1] * size
        end
        LG.line(points)
    end
end

-- 띠 한 줄에 새긴 룬: 먹으로 판 글자 + 띠를 따라 흐르는 보랏빛 (row = 0 위 / 1 아래 — 빛이 서로 반대로 흐른다)
local function inscription(x0, x1, cy, row, time, alpha)
    local count = math.floor((x1 - x0) / GLYPH_STEP)
    local start = x0 + ((x1 - x0) - (count - 1) * GLYPH_STEP) / 2
    LG.setLineWidth(1)
    for k = 0, count - 1 do
        local gx = start + k * GLYPH_STEP
        local index = (k * 7 + row * 5) % #GLYPHS + 1
        Draw.set_color(INK, 0.8 * alpha)
        RuneArt.glyph(index, gx, cy, 6)
        local phase = row == 0 and (time * 1.3 - k * 0.42) or (time * 1.3 + k * 0.42)
        local light = math.max(0, math.cos(phase)) ^ 10
        if light > 0.02 then
            LG.setBlendMode("add")
            Draw.set_color(VIOLET_LIGHT, light * 0.9 * alpha)
            RuneArt.glyph(index, gx, cy, 6)
            LG.setBlendMode("alpha")
        end
    end
end

-- 모서리 자수정: 먹 외곽 · 보라 면 · 흰 반짝임
local function gem(cx, cy, alpha, pulse)
    LG.setBlendMode("add")
    Draw.set_color(VIOLET, (0.18 + 0.14 * pulse) * alpha)
    LG.circle("fill", cx, cy, 8, 16)
    LG.setBlendMode("alpha")
    Draw.set_color(INK, alpha)
    LG.polygon("fill", cx, cy - 6.5, cx + 6.5, cy, cx, cy + 6.5, cx - 6.5, cy)
    Draw.set_color(VIOLET, alpha)
    LG.polygon("fill", cx, cy - 4.5, cx + 4.5, cy, cx, cy + 4.5, cx - 4.5, cy)
    Draw.set_color(VIOLET_LIGHT, alpha)
    LG.polygon("fill", cx, cy - 4.5, cx + 4.5, cy, cx, cy)
    Draw.set_color({ 1, 1, 1 }, 0.8 * alpha)
    LG.circle("fill", cx - 1, cy - 1.5, 1, 6)
end

function RuneArt.frame(x, y, w, h, time, hover, alpha)
    hover, alpha = hover or 0, alpha or 1
    local pulse = 0.5 + 0.5 * math.sin(time * 1.7)
    LG.setBlendMode("add")                                       -- 바깥 보랏빛 번짐 (호버 때 짙어진다)
    LG.setLineWidth(2)
    for i = 1, 4 do
        Draw.set_color(VIOLET, (0.04 + 0.03 * pulse + 0.12 * hover) * (5 - i) / 4 * alpha)
        LG.rectangle("line", x - 3 - i * 2, y - 3 - i * 2, w + 6 + i * 4, h + 6 + i * 4, RADIUS + 3 + i * 2, RADIUS + 3 + i * 2)
    end
    LG.setBlendMode("alpha")
    Draw.set_color({ 0, 0, 0 }, 0.45 * alpha)                     -- 그림자
    LG.rectangle("fill", x + 4, y + 6, w, h, RADIUS, RADIUS)
    Draw.set_color(INK, alpha)                                    -- 굵은 먹선 외곽
    LG.rectangle("fill", x - 3, y - 3, w + 6, h + 6, RADIUS + 3, RADIUS + 3)
    Draw.set_color(SILVER_BAND, alpha)                            -- 은빛 띠 (윗면 반사 · 아랫면 그늘)
    LG.rectangle("fill", x, y, w, h, RADIUS, RADIUS)
    Draw.set_color(SILVER, 0.75 * alpha)
    LG.rectangle("fill", x + 3, y + 1, w - 6, 2.5, 1, 1)
    Draw.set_color(SILVER, 0.35 * alpha)
    LG.rectangle("fill", x + 1, y + 3, 2, h - 6, 1, 1)
    Draw.set_color({ 0, 0, 0 }, 0.35 * alpha)
    LG.rectangle("fill", x + 3, y + h - 3, w - 6, 2, 1, 1)
    local ix, iy, iw, ih = x + BAND, y + BAND, w - BAND * 2, h - BAND * 2
    Draw.set_color(INK, alpha)
    LG.rectangle("fill", ix - 1.5, iy - 1.5, iw + 3, ih + 3, RADIUS - 2, RADIUS - 2)
    Draw.set_color(NIGHT, alpha)
    LG.rectangle("fill", ix, iy, iw, ih, RADIUS - 3, RADIUS - 3)
    SpriteBank.draw_texture("stone", ix, iy, iw, ih, RADIUS - 3, 0.1 * alpha)
    Draw.set_color({ 0, 0, 0 }, 0.35 * alpha)                     -- 안쪽 위 그늘
    LG.rectangle("fill", ix, iy, iw, 7, RADIUS - 3, RADIUS - 3)
    inscription(x + 18, x + w - 18, y + BAND / 2 + 0.5, 0, time, alpha)
    inscription(x + 18, x + w - 18, y + h - BAND / 2 - 0.5, 1, time, alpha)
    Draw.set_color(VIOLET, (0.32 + 0.22 * pulse + 0.4 * hover) * alpha)      -- 보라 결계선
    LG.setLineWidth(1.5)
    LG.rectangle("line", ix + 3.5, iy + 3.5, iw - 7, ih - 7, RADIUS - 5, RADIUS - 5)
    for _, corner in ipairs({ { x + 5, y + 5 }, { x + w - 5, y + 5 }, { x + 5, y + h - 5 }, { x + w - 5, y + h - 5 } }) do
        gem(corner[1], corner[2], alpha, pulse)
    end
end

-- 리본: 원판 위로 보라·은·보라 세로 줄무늬 띠 (아래쪽은 원판 뒤로 숨는다)
local function ribbon(cx, cy, r, earned, alpha)
    local rw, top, bottom = r * 1.15, cy - r * 2.05, cy - r * 0.35
    local stripes = earned and { VIOLET_DEEP, SILVER, VIOLET_DEEP } or { ASH_RIM, ASH_LIGHT, ASH_RIM }
    Draw.set_color(INK, alpha)
    LG.polygon("fill", cx - rw / 2 - 1.5, top - 1.5, cx + rw / 2 + 1.5, top - 1.5, cx + rw / 2 + 1.5, bottom, cx - rw / 2 - 1.5, bottom)
    for i = 1, 3 do
        Draw.set_color(stripes[i], alpha)
        LG.rectangle("fill", cx - rw / 2 + (i - 1) * rw / 3, top, rw / 3 + 0.4, bottom - top)
    end
    Draw.set_color({ 1, 1, 1 }, 0.18 * alpha)                     -- 접힌 천의 윗면 빛
    LG.rectangle("fill", cx - rw / 2, top, rw, math.max(1, r * 0.12))
end

-- 진엔딩 훈장 (cx, cy = 원판 중심, r = 원판 반지름 — 리본은 위로 약 2r 까지)
function RuneArt.medal(cx, cy, r, opts)
    opts = opts or {}
    local alpha = opts.alpha or 1
    local earned = opts.earned ~= false
    local time = opts.time or 0
    ribbon(cx, cy, r, earned, alpha)
    if earned then
        Draw.glow(cx, cy, r * 2.4, GOLD, (0.5 + 0.18 * math.sin(time * 2.2)) * alpha)
    end
    Draw.set_color(INK, alpha)
    LG.circle("fill", cx, cy, r + 1.6, 40)
    Draw.set_color(earned and GOLD_RIM or ASH_RIM, alpha)
    LG.circle("fill", cx, cy, r, 40)
    Draw.set_color(earned and GOLD or ASH, alpha)
    LG.circle("fill", cx, cy, r * 0.8, 40)
    LG.setLineWidth(math.max(1, r * 0.07))
    Draw.set_color(earned and GOLD_RIM or ASH_RIM, 0.85 * alpha)
    LG.circle("line", cx, cy, r * 0.62, 40)
    for i = 0, 11 do                                              -- 테두리 눈금
        local a = i / 12 * math.pi * 2
        LG.line(cx + math.cos(a) * r * 0.82, cy + math.sin(a) * r * 0.82, cx + math.cos(a) * r * 0.95, cy + math.sin(a) * r * 0.95)
    end
    LG.setLineJoin("bevel")
    LG.setLineWidth(math.max(1.2, r * 0.13))
    Draw.set_color(earned and GOLD_INK or ASH_LIGHT, alpha)
    RuneArt.glyph(DAGAZ, cx, cy, r * 0.82)
    LG.setLineJoin("miter")
    Draw.set_color({ 1, 1, 1 }, (earned and 0.55 or 0.16) * alpha)         -- 왼쪽 위 반사 (초승달 빛)
    LG.setLineWidth(math.max(1, r * 0.1))
    LG.arc("line", "open", cx, cy, r * 0.7, math.pi * 1.1, math.pi * 1.45, 10)
    if earned then                                                -- 반짝임
        local twinkle = math.max(0, math.sin(time * 2.6)) ^ 3
        local sx, sy, s = cx + r * 0.62, cy - r * 0.62, r * (0.35 + 0.35 * twinkle)
        Draw.set_color({ 1, 1, 0.92 }, (0.35 + 0.65 * twinkle) * alpha)
        LG.polygon("fill", sx, sy - s, sx + s * 0.22, sy, sx, sy + s, sx - s * 0.22, sy)
        LG.polygon("fill", sx - s, sy, sx, sy - s * 0.22, sx + s, sy, sx, sy + s * 0.22)
    end
end

return RuneArt
