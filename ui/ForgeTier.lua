-- ui/ForgeTier.lua
-- 강화 단계 시각 등급 (data/forge.lua 의 tiers): +5 황금 · +7 자홍 룬 · +9 ~ +10 심연 신화 오라. 규칙 계산 없음.
--   of(level)              : 그 단계의 등급 표 (등급 미만이면 nil)
--   badge(level, x, y, size, time) : 칸 왼쪽 위 "+N" 뱃지 — 등급마다 알약 바탕·테두리·광채가 격상된다
--   frame(level, x, y, w, h, time) : 진열장·보관함 칸 테두리 — 황금 이중선 / 자홍 룬 네 귀퉁이 / 심연 오라 + 공전하는 신화 불씨
-- ItemRenderer(뱃지) · ui/GridView(칸 테두리) · ui/Foil(포일 색)이 쓴다.

local Draw = require("ui.Draw")
local FORGE = require("data.forge")
local UI = require("data.ui")

local ForgeTier = {}

local C = UI.color
local LG = love.graphics
local INK = { 0.03, 0.02, 0.03 }
local ABYSS = { 0.10, 0.03, 0.16 }

function ForgeTier.of(level)
    local found = nil
    for _, tier in ipairs(FORGE.tiers) do
        if (level or 0) >= tier.from then
            found = tier
        end
    end
    return found
end

-- "+N" 뱃지 (x, y = 왼쪽 위). size = 글꼴 spec
function ForgeTier.badge(level, x, y, size, time)
    if (level or 0) <= 0 then
        return
    end
    local tier = ForgeTier.of(level)
    local text = "+" .. level
    if tier == nil then                  -- +1 ~ +4: 그림자 글자만
        Draw.shadow_text(text, x, y, 60, "left", size, C.accent)
        return
    end
    local font = Draw.font(size)
    local w, h = font:getWidth(text) + 12, font:getHeight() + 2
    local pulse = 0.5 + 0.5 * math.sin((time or 0) * 4 + level)
    if tier.id == "mythic" then          -- 심연 오라가 뱃지 뒤로 번진다
        LG.setBlendMode("add")
        Draw.set_color(tier.glow, 0.35 + 0.25 * pulse)
        LG.rectangle("fill", x - 4, y - 3, w + 8, h + 6, h / 2 + 3, h / 2 + 3)
        LG.setBlendMode("alpha")
    end
    Draw.set_color(INK)
    LG.rectangle("fill", x - 1.5, y - 1.5, w + 3, h + 3, h / 2 + 1, h / 2 + 1)
    Draw.set_color(tier.id == "mythic" and ABYSS or { 0.12, 0.08, 0.06 })
    LG.rectangle("fill", x, y, w, h, h / 2, h / 2)
    Draw.set_color(tier.color, 0.75 + 0.25 * pulse)
    LG.setLineWidth(tier.id == "gold" and 1.5 or 2)
    LG.rectangle("line", x + 0.75, y + 0.75, w - 1.5, h - 1.5, h / 2, h / 2)
    Draw.label_text(text, x + 6, y + 1, w - 6, "left", size, tier.color)
end

local function rune(x, y, s, angle)
    LG.push()
    LG.translate(x, y)
    LG.rotate(angle)
    LG.line(-s, 0, s, 0)
    LG.line(0, -s, 0, s)
    LG.line(-s * 0.6, -s * 0.6, s * 0.6, s * 0.6)
    LG.pop()
end

-- 칸 테두리 (등급 미만이면 아무것도 그리지 않는다)
function ForgeTier.frame(level, x, y, w, h, time)
    local tier = ForgeTier.of(level)
    if tier == nil then
        return
    end
    time = time or 0
    local pulse = 0.5 + 0.5 * math.sin(time * 3 + x * 0.01)
    if tier.id == "mythic" then          -- 심연 오라: 바깥으로 번지는 보랏빛 + 안쪽 신화 하늘빛 선 + 공전하는 불씨
        LG.setBlendMode("add")
        for i = 1, 3 do
            Draw.set_color(tier.glow, (0.16 - i * 0.04) * (0.7 + 0.3 * pulse))
            LG.setLineWidth(4 + i * 4)
            LG.rectangle("line", x - i * 2, y - i * 2, w + i * 4, h + i * 4, 9, 9)
        end
        LG.setBlendMode("alpha")
    end
    Draw.set_color(INK, 0.8)
    LG.setLineWidth(4)
    LG.rectangle("line", x + 1, y + 1, w - 2, h - 2, 7, 7)
    Draw.set_color(tier.color, 0.65 + 0.35 * pulse)
    LG.setLineWidth(2)
    LG.rectangle("line", x + 1, y + 1, w - 2, h - 2, 7, 7)
    if tier.id == "gold" then            -- 황금: 안쪽 가는 두 번째 선
        Draw.set_color(tier.color, 0.35)
        LG.setLineWidth(1)
        LG.rectangle("line", x + 4.5, y + 4.5, w - 9, h - 9, 5, 5)
    elseif tier.id == "rune" then        -- 자홍 룬: 네 귀퉁이 룬 문양이 천천히 돈다
        Draw.set_color(tier.color, 0.8 + 0.2 * pulse)
        LG.setLineWidth(1.5)
        for i, corner in ipairs({ { x + 8, y + 8 }, { x + w - 8, y + 8 }, { x + 8, y + h - 8 }, { x + w - 8, y + h - 8 } }) do
            rune(corner[1], corner[2], 4.5, time * 0.8 + i)
        end
    else
        local cx, cy = x + w / 2, y + h / 2
        for i = 0, 2 do
            local a = time * 1.6 + i * math.pi * 2 / 3
            Draw.set_color(i == 0 and tier.color or { 1, 1, 1 }, 0.9)
            LG.circle("fill", cx + math.cos(a) * w * 0.5, cy + math.sin(a) * h * 0.5, 2.5, 8)
        end
    end
end

return ForgeTier
