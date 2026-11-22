-- ui/ConduitView.lua
-- 공명 진열장의 마력 도선 (수치 data/circuit.lua — 규칙 계산 없음, ui/GridView 가 칸 타일과 유물 사이에 그린다).
-- 스승이 진열장 아래 25칸의 철제·황동 소켓을 상하좌우로 이어 둔 회로를 화면에 드러낸다:
--   도선   : 이웃한 두 칸의 경계를 가로지르는 황동 토막(가로 20 · 세로 20). 낮에는 불 꺼진 황동.
--            밤이 시작되면 정중앙 칸에서 바깥으로 황금빛 마력이 번져 점등되고(Combat.elapsed), 상태에 따라 밝기가 다르다 —
--            idle(빈 칸) < live(양쪽에 작동 중인 유물: 빛 알갱이가 흐른다) < link(시너지로 이어진 두 칸: 굵게 맥동).
--            과부하 레버를 켜면 붉은 주황색으로 고동친다. 봉인 칸에 걸친 도선은 어둡게 꺼져 있다.
--   중앙 코어 : 정중앙 (3,3) 직접 동조 슬롯(systems/Grid.CORE) — 은은한 황금 모서리 표식. 밤에 공방 문 앞 주인공(ui/LaneHero)이
--            이 칸의 유물에 동조한다. core_lines 가 툴팁 줄(ui/Tooltip)을 만든다.

local I18n = require("systems.I18n")
local Grid = require("systems.Grid")
local Draw = require("ui.Draw")
local Slots = require("ui.Slots")
local CIRCUIT = require("data.circuit")
local UI = require("data.ui")

local ConduitView = {}

local LG = love.graphics
local SPEC = CIRCUIT.conduit
local MARK = CIRCUIT.core_mark
local CORE_ROW, CORE_COL = Grid.to_row_col(Grid.CORE)

-- 이웃한 칸 쌍 { a, b, horizontal, dist(정중앙에서 먼 쪽 칸까지의 칸 수) } — 행 → 열 순서
local SEGMENTS = {}
for index = 1, Grid.SIZE do
    local row, col = Grid.to_row_col(index)
    for _, step in ipairs({ { 0, 1 }, { 1, 0 } }) do
        local r, c = row + step[1], col + step[2]
        if r <= Grid.ROWS and c <= Grid.COLS then
            local far = math.max(math.abs(row - CORE_ROW) + math.abs(col - CORE_COL), math.abs(r - CORE_ROW) + math.abs(c - CORE_COL))
            SEGMENTS[#SEGMENTS + 1] = { a = index, b = Grid.to_index(r, c), horizontal = step[2] == 1, dist = far }
        end
    end
end
ConduitView.SEGMENTS = SEGMENTS

-- 도선 토막의 화면 좌표 x1, y1, x2, y2 (지금 화면 모드의 칸 좌표)
function ConduitView.segment_points(segment)
    local ax, ay, aw, ah = Slots.rect("grid", segment.a)
    local bx, by = Slots.rect("grid", segment.b)
    if segment.horizontal then
        return ax + aw - SPEC.reach, ay + ah / 2, bx + SPEC.reach, ay + ah / 2
    end
    return ax + aw / 2, ay + ah - SPEC.reach, ax + aw / 2, by + SPEC.reach
end

local function working(workshop, index)
    local item = workshop.inventory:get("grid", index)
    return item ~= nil and not item:is_worn_out()
end

-- 도선 상태: "sealed" | "idle" | "live" | "link" (linked = 시너지로 이어진 칸 쌍 집합)
function ConduitView.state(workshop, segment, linked)
    if not (workshop:is_cell_open(segment.a) and workshop:is_cell_open(segment.b)) then
        return "sealed"
    elseif linked[segment.a * 100 + segment.b] then
        return "link"
    elseif working(workshop, segment.a) and working(workshop, segment.b) then
        return "live"
    end
    return "idle"
end

-- 밤이 시작된 뒤 그 도선이 켜진 정도 0~1 (정중앙에서 바깥으로 번진다). 낮에는 0
function ConduitView.lit(workshop, segment)
    if workshop.phase ~= "night" then
        return 0
    end
    local since = workshop.combat.elapsed - (segment.dist - 1) * SPEC.ignite_step
    return math.max(0, math.min(1, since / SPEC.ignite_fade))
end

local function linked_pairs(workshop)
    local pairs_set = {}
    for _, link in ipairs(workshop:grid_stats().links) do
        local a, b = math.min(link.from, link.to), math.max(link.from, link.to)
        pairs_set[a * 100 + b] = true
    end
    return pairs_set
end

local function brass(x1, y1, x2, y2, alpha)
    Draw.set_color(SPEC.dark, alpha)
    LG.setLineWidth(SPEC.width + 3)
    LG.line(x1, y1, x2, y2)
    Draw.set_color(SPEC.brass, alpha)
    LG.setLineWidth(SPEC.width)
    LG.line(x1, y1, x2, y2)
    Draw.set_color(SPEC.dark, alpha)
    LG.circle("fill", x1, y1, SPEC.node + 1.5, 10)
    LG.circle("fill", x2, y2, SPEC.node + 1.5, 10)
    Draw.set_color(Draw.lerp_color(SPEC.brass, { 1, 1, 1 }, 0.25), alpha)
    LG.circle("fill", x1, y1, SPEC.node, 10)
    LG.circle("fill", x2, y2, SPEC.node, 10)
end

-- 켜진 도선의 마력 빛 (가산): 상태별 밝기 · 맥동 · 흐르는 빛 알갱이
local function glow(x1, y1, x2, y2, state, lit, overclock, time, phase)
    local color = overclock and SPEC.overclock or SPEC.mana
    local speed = overclock and SPEC.pulse.overclock or (SPEC.pulse[state] or 0)
    local beat = speed > 0 and (0.5 + 0.5 * math.sin(time * speed + phase)) or 1
    if overclock then
        beat = beat * beat                          -- 과부하: 심장처럼 짧고 세게 고동친다
    end
    local alpha = SPEC.alpha[state] * lit * (0.55 + 0.45 * beat)
    Draw.set_color(color, alpha * 0.45)
    LG.setLineWidth(state == "link" and SPEC.glow_width + 4 or SPEC.glow_width)
    LG.line(x1, y1, x2, y2)
    Draw.set_color(Draw.lerp_color(color, { 1, 1, 1 }, 0.45), alpha)
    LG.setLineWidth(state == "link" and 3 or 2)
    LG.line(x1, y1, x2, y2)
    if state ~= "idle" then                         -- 마력이 흐른다
        local t = (time * (state == "link" and 1.6 or 0.9) + phase) % 1
        Draw.set_color({ 1, 1, 1 }, alpha)
        LG.circle("fill", x1 + (x2 - x1) * t, y1 + (y2 - y1) * t, state == "link" and 3 or 2.2, 8)
    end
end

-- 정중앙 직접 동조 슬롯: 황금 모서리 표식 (밤에는 조금 더 밝게 맥동)
local function core_mark(workshop, time)
    if not workshop:is_cell_open(Grid.CORE) then
        return
    end
    local x, y, w, h = Slots.rect("grid", Grid.CORE)
    local night = workshop.phase == "night"
    local alpha = MARK.alpha * (night and (0.8 + 0.2 * math.sin(time * 3)) or 0.75)
    local len, d = w * MARK.length, MARK.inset
    Draw.set_color(SPEC.dark, alpha)
    LG.setLineWidth(MARK.width + 2)
    for pass = 1, 2 do
        if pass == 2 then
            Draw.set_color(MARK.color, alpha)
            LG.setLineWidth(MARK.width)
        end
        LG.line(x + d, y + d + len, x + d, y + d, x + d + len, y + d)
        LG.line(x + w - d - len, y + d, x + w - d, y + d, x + w - d, y + d + len)
        LG.line(x + d, y + h - d - len, x + d, y + h - d, x + d + len, y + h - d)
        LG.line(x + w - d - len, y + h - d, x + w - d, y + h - d, x + w - d, y + h - d - len)
    end
    if night then                                   -- 밤: 주인공이 동조하는 자리 — 은은한 황금 숨결
        LG.setBlendMode("add")
        Draw.glow(x + w / 2, y + h / 2, w * 0.62, MARK.color, 0.10 + 0.05 * math.sin(time * 3))
        LG.setBlendMode("alpha")
    end
end

-- 칸 타일 위 · 유물 아래에 그린다 (ui/GridView.draw_grid)
function ConduitView.draw(workshop, time)
    local linked = linked_pairs(workshop)
    local overclock = workshop.phase == "night" and workshop.combat.overclock
    local lit_segments = {}
    for i, segment in ipairs(SEGMENTS) do
        local state = ConduitView.state(workshop, segment, linked)
        local x1, y1, x2, y2 = ConduitView.segment_points(segment)
        brass(x1, y1, x2, y2, state == "sealed" and SPEC.alpha.sealed or SPEC.alpha.day)
        local lit = state ~= "sealed" and ConduitView.lit(workshop, segment) or 0
        if lit > 0 then
            lit_segments[#lit_segments + 1] = { x1, y1, x2, y2, state, lit, i * 1.7 }
        end
    end
    LG.setBlendMode("add")
    for _, s in ipairs(lit_segments) do
        glow(s[1], s[2], s[3], s[4], s[5], s[6], overclock, time, s[7])
    end
    LG.setBlendMode("alpha")
    core_mark(workshop, time)
end

-- 툴팁 줄 { text, color, size } 과 강조 색: 정중앙 직접 동조 슬롯이면 (ui/Tooltip — 유물 툴팁 끝 · 빈 칸의 작은 상자)
function ConduitView.core_lines(index)
    if index ~= Grid.CORE then
        return nil
    end
    return {
        { text = I18n.t("grid.core_title"), color = MARK.color, size = UI.font_size.small },
        { text = I18n.t("grid.core_body"), color = UI.color.text_dim, size = UI.font_size.small },
    }, MARK.color
end

return ConduitView
