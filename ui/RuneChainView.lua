-- ui/RuneChainView.lua
-- 최종 보스(균열의 잔영)의 공방 봉쇄 룬 사슬 덮개 (systems/CombatLocks 의 combat.chains = 칸 → 남은 초, 규칙 계산 없음).
-- ui/GridView 가 칸·유물 위, 골렘 거미줄 아래에 그린다:
--   묶인 칸      : 먹빛으로 어둡게 + 보랏빛 안쪽 테두리 (그 칸 무기는 쏘지 않는다)
--   통째로 묶인 행·열: 진열장 끝에서 끝까지 가로지르는 검은 쇠사슬(보랏빛 룬이 새겨진 고리) + 가운데 룬 자물쇠(남은 시간 호)
--   줄을 이루지 않는 칸: 칸 안을 가로지르는 짧은 사슬
-- 막 묶인 사슬은 포탈 쪽(행은 오른쪽 · 열은 위)에서 채찍처럼 뻗어 와 꽂히고(SLAM 초), 풀리기 전 FADE 초 동안 옅어진다.
-- 묶는 시간은 data/enemies.lua 의 boss_patterns.master.lock_time.

local Draw = require("ui.Draw")
local Slots = require("ui.Slots")
local Grid = require("systems.Grid")
local ENEMIES = require("data.enemies")

local RuneChainView = {}

local LG = love.graphics
local LOCK_TIME = ENEMIES.boss_patterns.master.lock_time
local SLAM = 0.28
local FADE = 0.7
local INK = { 0.03, 0.02, 0.04 }
local IRON = { 0.22, 0.19, 0.27 }
local IRON_LIGHT = { 0.56, 0.50, 0.66 }
local RUNE = { 0.74, 0.38, 1.00 }
local AXES = { "row", "col" }

-- 통째로 묶인 행·열 { axis, cells, left } 와 그 줄에 든 칸 집합
local function lines_of(chains)
    local lines, covered = {}, {}
    for _, axis in ipairs(AXES) do
        for line = 1, Grid.ROWS do
            local cells, left = {}, math.huge
            for k = 1, Grid.COLS do
                local index = axis == "row" and Grid.to_index(line, k) or Grid.to_index(k, line)
                local time = chains[index]
                if time == nil then
                    cells = nil
                    break
                end
                cells[#cells + 1], left = index, math.min(left, time)
            end
            if cells ~= nil then
                lines[#lines + 1] = { axis = axis, cells = cells, left = left }
                for _, index in ipairs(cells) do
                    covered[index] = true
                end
            end
        end
    end
    return lines, covered
end

local function fade_of(left)
    return math.max(0, math.min(1, left / FADE))
end

-- (x1, y1) → (x2, y2) 사슬. link = 고리 길이(px)
local function chain(x1, y1, x2, y2, link, alpha, time)
    local dx, dy = x2 - x1, y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 1 then
        return
    end
    LG.push()
    LG.translate(x1, y1)
    LG.rotate(math.atan2(dy, dx))
    LG.setBlendMode("add")                            -- 사슬을 감싼 보랏빛 기운
    Draw.set_color(RUNE, 0.16 * alpha)
    LG.setLineWidth(link * 1.1)
    LG.line(0, 0, length, 0)
    LG.setBlendMode("alpha")
    local rx, ry = link * 0.62, link * 0.34
    for i = 0, math.floor(length / link) do
        local cx = math.min(length, i * link + link * 0.5)
        if i % 2 == 0 then                            -- 정면 고리 (타원)
            Draw.set_color(INK, alpha)
            LG.setLineWidth(link * 0.34)
            LG.ellipse("line", cx, 0, rx, ry, 16)
            Draw.set_color(IRON, alpha)
            LG.setLineWidth(link * 0.18)
            LG.ellipse("line", cx, 0, rx, ry, 16)
            Draw.set_color(IRON_LIGHT, 0.85 * alpha)
            LG.setLineWidth(1)
            LG.arc("line", "open", cx, 0, rx - 1, math.pi * 1.15, math.pi * 1.75, 6)
        else                                          -- 옆으로 누운 고리 (막대) — 몇 개에 보랏빛 룬
            Draw.set_color(INK, alpha)
            LG.rectangle("fill", cx - rx - 1.5, -link * 0.15 - 1.5, rx * 2 + 3, link * 0.3 + 3, 2, 2)
            Draw.set_color(IRON, alpha)
            LG.rectangle("fill", cx - rx, -link * 0.15, rx * 2, link * 0.3, 2, 2)
            if i % 4 == 1 then
                LG.setBlendMode("add")
                Draw.set_color(RUNE, (0.6 + 0.4 * math.sin(time * 5 + i)) * alpha)
                LG.rectangle("fill", cx - rx * 0.45, -1, rx * 0.9, 2)
                LG.setBlendMode("alpha")
            end
        end
    end
    LG.pop()
end

-- 룬 자물쇠: 먹 테두리 쇠 원판 + 보랏빛 룬 + 남은 시간 호
local function seal(x, y, r, left, alpha, time)
    Draw.set_color(INK, alpha)
    LG.circle("fill", x, y, r + 3, 20)
    Draw.set_color(IRON, alpha)
    LG.circle("fill", x, y, r, 20)
    LG.setBlendMode("add")
    Draw.set_color(RUNE, (0.75 + 0.25 * math.sin(time * 6)) * alpha)
    LG.setLineWidth(2)
    LG.line(x, y - r * 0.6, x, y + r * 0.6)
    LG.line(x - r * 0.45, y - r * 0.1, x, y - r * 0.6, x + r * 0.45, y - r * 0.1)
    LG.line(x - r * 0.35, y + r * 0.35, x + r * 0.35, y + r * 0.35)
    LG.setBlendMode("alpha")
    Draw.set_color(INK, 0.8 * alpha)
    LG.setLineWidth(5)
    LG.circle("line", x, y, r + 5, 24)
    Draw.set_color(RUNE, alpha)
    LG.setLineWidth(2.5)
    local share = math.max(0, math.min(1, left / LOCK_TIME))
    LG.arc("line", "open", x, y, r + 5, -math.pi / 2, -math.pi / 2 + math.pi * 2 * share, 24)
end

-- 진열장 한 줄 사슬 (슬램: 포탈 쪽 끝에서 뻗어 온다)
local function draw_line(line, time)
    local gx, gy, gw, gh = Slots.grid_bounds()
    local _, _, cell = Slots.rect("grid", line.cells[1])
    local link = cell * 0.22
    local alpha = fade_of(line.left)
    local grow = math.min(1, (LOCK_TIME - line.left) / SLAM)
    grow = 1 - (1 - grow) * (1 - grow)
    local cx, cy = Slots.center("grid", line.cells[3])
    if line.axis == "row" then
        local x2 = gx + gw + 10
        chain(x2 - (gw + 20) * grow, cy, x2, cy, link, alpha, time)
    else
        local y1 = gy - 10
        chain(cx, y1, cx, y1 + (gh + 20) * grow, link, alpha, time)
    end
    if grow >= 1 then
        seal(cx, cy, cell * 0.17, line.left, alpha, time)
    end
end

-- combat.chains 덮개 전부 (지금 화면 모드의 칸 좌표)
function RuneChainView.draw(chains, time)
    if next(chains) == nil then
        return
    end
    local lines, covered = lines_of(chains)
    for index, left in pairs(chains) do               -- 묶인 칸: 먹빛 + 보랏빛 안쪽 테두리 (막 묶이면 흰 번쩍임)
        local x, y, w, h = Slots.rect("grid", index)
        local alpha = fade_of(left)
        local slam = math.max(0, 1 - (LOCK_TIME - left) / SLAM)
        Draw.set_color(INK, 0.5 * alpha)
        LG.rectangle("fill", x, y, w, h, 6, 6)
        Draw.set_color(RUNE, 0.55 * alpha)
        LG.setLineWidth(2)
        LG.rectangle("line", x + 3, y + 3, w - 6, h - 6, 5, 5)
        if slam > 0 then
            LG.setBlendMode("add")
            Draw.set_color({ 0.9, 0.8, 1.0 }, 0.5 * slam)
            LG.rectangle("fill", x, y, w, h, 6, 6)
            LG.setBlendMode("alpha")
        end
        if not covered[index] then
            local cy = y + h / 2
            chain(x + 4, cy, x + w - 4, cy, w * 0.22, alpha, time)
            seal(x + w / 2, cy, w * 0.15, left, alpha, time)
        end
    end
    for _, line in ipairs(lines) do
        draw_line(line, time)
    end
end

return RuneChainView
