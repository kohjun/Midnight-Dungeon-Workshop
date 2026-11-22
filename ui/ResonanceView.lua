-- ui/ResonanceView.lua
-- '스승의 흔적' 캠페인의 진열장 봉인 공명 슬롯 4칸 (systems/MasterTrace — 규칙 계산 없음: is_lit · is_complete 를 읽기만 한다).
--   draw(workshop, time) : ui/GridView 가 칸·유물 위에 그린다 (지금 화면 모드의 칸 좌표 = ui/Slots, 낮·밤 공통)
--     슬롯 칸마다 계열(data/items.lua 의 archetypes) 색 룬 모서리 틀 — 비어 있으면 가운데 계열 문양 + 도는 소켓 고리.
--     점화되면 칸 둘레에 룬 결계선(가산 발광 · 맥동 · 둘레를 도는 불씨 · 흐르는 룬 눈금), 막 점화된 칸은 결계선이
--     네 모서리에서 그어지며 섬광. 점화된 슬롯은 가운데 칸으로 옅은 점선을 잇고, 4칸이 모두 점화되면 은청색 공명선 +
--     중심으로 흐르는 빛 알갱이 + 가운데 칸의 봉인 문장 (ui/ResonanceSigil).
--   slot_lines(workshop, index, item) : 호버 툴팁 줄 (슬롯 이름·점화 상태 · 점화 조건 · +10 불멸 안내) — ui/Tooltip 이 쓴다

local I18n = require("systems.I18n")
local MasterTrace = require("systems.MasterTrace")
local Draw = require("ui.Draw")
local Slots = require("ui.Slots")
local ResonanceSigil = require("ui.ResonanceSigil")
local ITEMS = require("data.items")
local TRACE = require("data.master_trace")
local UI = require("data.ui")

local ResonanceView = {}

local C = UI.color
local SIZE = UI.font_size
local LG = love.graphics
local INK = { 0.03, 0.02, 0.03 }
local WHITE = { 1, 1, 1 }
local DORMANT = { 0.42, 0.40, 0.44 }
local IGNITE = 0.5             -- 막 점화된 칸의 결계선이 모서리에서 그어지는 시간 (초)

local _seen = setmetatable({}, { __mode = "k" })     -- trace → { lit = { [칸] = bool }, since = { [칸] = 점화 시각 } }

local function color_of(slot)
    return ITEMS.archetypes[slot.archetype].color
end

-- 점화 진행 0~1 (처음 본 상태는 연출 없이 1, 꺼짐 → 점화로 바뀐 순간부터 IGNITE 초)
local function ignition(trace, index, lit, time)
    local seen = _seen[trace]
    if seen == nil then
        seen = { lit = {}, since = {} }
        _seen[trace] = seen
    end
    if seen.lit[index] == nil then
        seen.lit[index] = lit
    elseif lit and not seen.lit[index] then
        seen.since[index] = time
    end
    seen.lit[index] = lit
    local since = seen.since[index]
    if not lit or since == nil or time < since then
        return 1
    end
    return math.min(1, (time - since) / IGNITE)
end

-- 룬 모서리 틀: 칸 바깥 테두리에 걸친 ㄱ자 꺾쇠 + 팔 끝 세리프 + 모서리 마름모
local function brackets(x, y, w, h, color, alpha, lit, pulse)
    local o, arm, serif = 2, math.floor(w * 0.3), math.max(4, w * 0.07)
    local corners = { { x - o, y - o, 1, 1 }, { x + w + o, y - o, -1, 1 }, { x - o, y + h + o, 1, -1 }, { x + w + o, y + h + o, -1, -1 } }
    for pass = 1, lit and 3 or 2 do
        if pass == 1 then
            Draw.set_color(INK, 0.9 * alpha)
            LG.setLineWidth(6)
        elseif pass == 2 then
            Draw.set_color(color, alpha)
            LG.setLineWidth(3)
        else
            LG.setBlendMode("add")
            Draw.set_color(WHITE, 0.35 + 0.35 * pulse)
            LG.setLineWidth(1.2)
        end
        for _, c in ipairs(corners) do
            local cx, cy, sx, sy = c[1], c[2], c[3], c[4]
            LG.line(cx + sx * arm, cy, cx, cy, cx, cy + sy * arm)
            LG.line(cx + sx * arm, cy, cx + sx * arm, cy + sy * serif)
            LG.line(cx, cy + sy * arm, cx + sx * serif, cy + sy * arm)
        end
    end
    LG.setBlendMode("alpha")
    local d = math.max(3.5, w * 0.055)
    for _, c in ipairs(corners) do
        Draw.set_color(INK, alpha)
        LG.polygon("fill", c[1], c[2] - d - 2, c[1] + d + 2, c[2], c[1], c[2] + d + 2, c[1] - d - 2, c[2])
        Draw.set_color(lit and Draw.lerp_color(color, WHITE, 0.45 * pulse) or color, alpha)
        LG.polygon("fill", c[1], c[2] - d, c[1] + d, c[2], c[1], c[2] + d, c[1] - d, c[2])
    end
end

-- 둘레 위의 점 (왼쪽 위에서 시계 방향으로 d 만큼)
local function perimeter(l, t, w, h, d)
    d = d % (2 * (w + h))
    if d < w then
        return l + d, t
    elseif d < w + h then
        return l + w, t + d - w
    elseif d < 2 * w + h then
        return l + w - (d - w - h), t + h
    end
    return l, t + h - (d - 2 * w - h)
end

-- 점화: 칸 둘레의 룬 결계선 (grow < 1 이면 네 모서리에서 시계 방향으로 그어지는 중 + 섬광)
local function barrier(x, y, w, h, color, time, grow, pulse)
    local o = math.max(5, w * 0.07)
    local l, t, bw, bh = x - o, y - o, w + o * 2, h + o * 2
    LG.setBlendMode("add")
    Draw.set_color(color, (0.16 + 0.14 * pulse) * grow)
    LG.setLineWidth(12)
    LG.rectangle("line", l, t, bw, bh, 6, 6)
    Draw.set_color(color, (0.55 + 0.35 * pulse))
    LG.setLineWidth(2)
    local edges = { { l, t, l + bw * grow, t }, { l + bw, t, l + bw, t + bh * grow },
        { l + bw, t + bh, l + bw - bw * grow, t + bh }, { l, t + bh, l, t + bh - bh * grow } }
    for _, e in ipairs(edges) do
        LG.line(e[1], e[2], e[3], e[4])
    end
    if grow >= 1 then                                     -- 흐르는 룬 눈금 (결계선을 가로지르는 바늘땀)
        local step = math.max(10, w * 0.17)
        local length = 2 * (bw + bh)
        Draw.set_color(color, 0.5 + 0.3 * pulse)
        LG.setLineWidth(1.4)
        for d = (time * 16) % step, length - 1, step do
            local px, py = perimeter(l, t, bw, bh, d)
            LG.line(px - 2.5, py - 2.5, px + 2.5, py + 2.5)
        end
        for k = 0, 1 do                                   -- 둘레를 도는 불씨 두 개
            local px, py = perimeter(l, t, bw, bh, time * 70 + k * length / 2)
            Draw.set_color(color, 0.45)
            LG.circle("fill", px, py, 5, 12)
            Draw.set_color(WHITE, 0.9)
            LG.circle("fill", px, py, 1.8, 8)
        end
    else                                                  -- 점화 섬광: 칸 안 흰 빛 + 퍼지는 테두리
        Draw.set_color(WHITE, 0.4 * (1 - grow))
        LG.rectangle("fill", x + 2, y + 2, w - 4, h - 4, 6, 6)
        local spread = 4 + 18 * grow
        Draw.set_color(color, 0.8 * (1 - grow))
        LG.setLineWidth(3)
        LG.rectangle("line", x - spread, y - spread, w + spread * 2, h + spread * 2, 8, 8)
    end
    LG.setBlendMode("alpha")
end

-- 빈 슬롯: 오목한 소켓 빛 + 천천히 도는 룬 고리 + 가운데 계열 문양
local function socket(slot, x, y, w, h, time)
    local color, cx, cy = color_of(slot), x + w / 2, y + h / 2
    local breathe = 0.5 + 0.5 * math.sin(time * 2 + slot.order)
    Draw.set_color(color, 0.08 + 0.04 * breathe)
    LG.circle("fill", cx, cy, w * 0.36, 32)
    local radius = w * 0.36
    for i = 0, 7 do
        local a = time * 0.5 + i * math.pi / 4
        Draw.set_color(INK, 0.7)
        LG.setLineWidth(4)
        LG.arc("line", "open", cx, cy, radius, a, a + 0.5, 6)
        Draw.set_color(color, 0.55 + 0.25 * breathe)
        LG.setLineWidth(1.8)
        LG.arc("line", "open", cx, cy, radius, a, a + 0.5, 6)
    end
    ResonanceSigil.glyph(slot.archetype, cx, cy, w * 0.42, color, 0.7 + 0.25 * breathe)
end

function ResonanceView.draw(workshop, time)
    local trace = workshop.master_trace
    if trace == nil then
        return
    end
    local complete = trace:is_complete()
    for _, slot in ipairs(MasterTrace.SLOTS) do
        local x, y, w, h = Slots.rect("grid", slot.index)
        local color = color_of(slot)
        local lit = trace:is_lit(slot.index)
        local pulse = 0.5 + 0.5 * math.sin(time * 4.2 + slot.order * 1.3)
        local item = workshop.inventory:get("grid", slot.index)
        if lit then
            barrier(x, y, w, h, color, time, ignition(trace, slot.index, true, time), pulse)
        else
            ignition(trace, slot.index, false, time)
            if item == nil then
                socket(slot, x, y, w, h, time)
            end
        end
        local tone = lit and color or Draw.lerp_color(color, DORMANT, 0.3)
        brackets(x, y, w, h, tone, lit and 1 or 0.85, lit, pulse)
    end
    ResonanceSigil.lines(trace, time, complete)          -- 공명선은 틀 위로 (모서리를 지나 가운데 칸까지 끊기지 않게)
    ResonanceSigil.center(trace, time, complete)
end

-- 호버 툴팁 줄 { text, color, size } 와 슬롯 계열 색 (슬롯이 아니거나 캠페인이 아니면 nil). item = 그 칸의 유물 (빈 칸이면 nil)
function ResonanceView.slot_lines(workshop, index, item)
    local trace = workshop and workshop.master_trace
    local slot = trace and index and MasterTrace.slot_at(index)
    if slot == nil then
        return nil
    end
    local color = color_of(slot)
    local name = I18n.t("trace.resonance.archetypes." .. slot.archetype)
    local lit = trace:is_lit(index)
    local state = I18n.t(lit and "trace.resonance.lit_state" or "trace.resonance.dark_state")
    local lines = {
        { text = I18n.t("trace.resonance.slot_state", { slot = I18n.t("trace.resonance.slot", { archetype = name }), state = state }),
            color = lit and color or Draw.lerp_color(color, C.text_dim, 0.45), size = item == nil and "tooltip_name" or SIZE.small },
        { text = I18n.t("trace.resonance.tip", { archetype = name, level = TRACE.resonance.min_level,
            mult = string.format("%.2g", trace:wear_mult(index)) }), color = C.text_dim, size = SIZE.small },
    }
    if item ~= nil and item:durability_state() == "immortal" then
        lines[#lines + 1] = { text = I18n.t("trace.resonance.immortal"), color = C.gold, size = SIZE.small }
    end
    return lines, color
end

return ResonanceView
