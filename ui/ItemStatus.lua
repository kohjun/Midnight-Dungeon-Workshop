-- ui/ItemStatus.lua
-- 칸 위 유물 상태 표시 (ui/GridView.draw_slot — 진열장·보관함): 칸 아래쪽 얇은 내구도 게이지와 완전 마모 덮개. 규칙 계산 없음.
--   게이지 색 (data/durability.lua 의 gauge): 60% 이상 옥색 · 31~59% 황박색 · 1~30% 붉은 경고(맥동) · +10 불멸 황금(반짝임)
--   0% 완전 마모: 회색 덮개 + 균열 + "0%" 뱃지 (작동 정지)

local Draw = require("ui.Draw")
local DURABILITY = require("data.durability")
local UI = require("data.ui")

local ItemStatus = {}

local LG = love.graphics
local G = DURABILITY.gauge
local INK = { 0.03, 0.02, 0.02 }
local CRACK = { { -0.32, -0.3 }, { -0.08, -0.1 }, { -0.16, 0.08 }, { 0.1, 0.22 }, { 0.04, 0.36 } }
local CRACK_2 = { { 0.3, -0.34 }, { 0.12, -0.12 }, { 0.22, 0.02 } }
local GAUGE_H = 5

function ItemStatus.gauge_color(item)
    local state = item:durability_state()
    if state == "immortal" then
        return G.immortal
    elseif state == "broken" then
        return G.broken
    elseif state == "low" then
        return G.low
    end
    return state == "mid" and G.mid or G.ok
end

local function polyline(points, cx, cy, w, h)
    local list = {}
    for _, p in ipairs(points) do
        list[#list + 1] = cx + p[1] * w
        list[#list + 1] = cy + p[2] * h
    end
    LG.line(list)
end

-- 0% 완전 마모 덮개: 회색 막 + 균열 + "0%" 뱃지
local function draw_broken(x, y, w, h)
    LG.setColor(0.12, 0.11, 0.12, 0.62)
    LG.rectangle("fill", x + 2, y + 2, w - 4, h - 4, 6, 6)
    local cx, cy = x + w / 2, y + h / 2
    Draw.set_color(INK, 0.9)
    LG.setLineWidth(3)
    polyline(CRACK, cx, cy, w, h)
    polyline(CRACK_2, cx, cy, w, h)
    LG.setColor(0.75, 0.72, 0.7, 0.85)
    LG.setLineWidth(1)
    polyline(CRACK, cx + 1, cy, w, h)
    Draw.set_color(INK)
    LG.rectangle("fill", x + w - 34, y + h - 24, 30, 16, 5, 5)
    Draw.set_color(UI.color.danger)
    LG.setLineWidth(1.5)
    LG.rectangle("line", x + w - 34, y + h - 24, 30, 16, 5, 5)
    Draw.label_text("0%", x + w - 34, y + h - 24, 30, "center", { role = "ui", size = 12 }, UI.color.danger)
end

-- 유물 위에 그린다 (x, y, w, h = 칸)
function ItemStatus.draw(item, x, y, w, h, time)
    if not item.owned then
        return
    end
    if item:is_worn_out() then
        draw_broken(x, y, w, h)
    end
    local ratio = math.max(0, math.min(1, item.durability / item.max_durability))
    local bx, by, bw = x + 6, y + h - GAUGE_H - 4, w - 12
    Draw.set_color(INK, 0.85)
    LG.rectangle("fill", bx - 1, by - 1, bw + 2, GAUGE_H + 2, 2, 2)
    local color = ItemStatus.gauge_color(item)
    local state = item:durability_state()
    local alpha = 1
    if state == "low" then
        alpha = 0.65 + 0.35 * math.sin((time or 0) * 8)
    end
    if ratio > 0 then
        Draw.set_color(color, alpha)
        LG.rectangle("fill", bx, by, bw * ratio, GAUGE_H, 2, 2)
    end
    if state == "immortal" then          -- 불멸: 황금 막대 위로 흐르는 반짝임
        local t = ((time or 0) * 0.6) % 1
        LG.setColor(1, 1, 1, 0.7)
        LG.rectangle("fill", bx + bw * t, by, math.min(10, bw * (1 - t)), GAUGE_H, 2, 2)
    end
end

return ItemStatus
