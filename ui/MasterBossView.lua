-- ui/MasterBossView.lua
-- '스승의 흔적' 최종 보스(균열의 잔영 — data/enemies.lua 의 final) 레인 표현. ui/LaneView 가 부른다.
-- 규칙 계산 없음: monster.aegis(파훼 진행 = dealt / need) · groggy_time 을 읽기만 한다.
--   aura(monster, x, y, r, time)              : 몸 아래 보랏빛 균열 오라 — 땅에 번진 먹 + 갈라진 균열 빛 + 맴도는 은빛 불티
--   status(monster, x, y, r, time, sprite_k)  : 몸 위 — 균열 아이기스 반투명 돔(가장자리 빛 · 벌집 일렁임 · 파훼 진행만큼
--                                               번지는 금, 거의 깨지면 깜빡임) · 그로기(머리 위를 도는 별 + "그로기")
--   draw_overlay(combat, lane, time, motion)  : 레인 아래쪽 전용 체력 띠 · 출현 경고 · 결말 배너 (ui/MasterBossHud)
-- sprite_k = ui/LaneView 의 그림 배율 (그림 높이 = 반경 × sprite_k × 원화 배율) — 돔이 원화를 감싸게 맞춘다.

local I18n = require("systems.I18n")
local Draw = require("ui.Draw")
local SpriteCatalog = require("ui.SpriteCatalog")
local MasterBossHud = require("ui.MasterBossHud")

local MasterBossView = {}

local LG = love.graphics
local INK = { 0.03, 0.02, 0.04 }
local WHITE = { 1, 1, 1 }
local VIOLET = { 0.62, 0.38, 1.00 }
local SILVER = { 0.82, 0.90, 1.00 }
local AMBER = { 1.00, 0.80, 0.30 }
local CRACK_COUNT, CRACK_STEPS, BRANCH_AT, BRANCH_STEPS = 7, 5, 2, 3

MasterBossView.VIOLET, MasterBossView.SILVER = VIOLET, SILVER

-- 정규화 좌표 금 경로: (px, py) 에서 heading 쪽으로 꺾이며 steps 마디 (난수 없이 고정 모양)
local function crack_path(seed, heading, px, py, steps, length)
    local path = { { px, py } }
    for s = 1, steps do
        local a = heading + math.sin(seed * 12.9898 + s * 78.233) * 0.7
        px, py = px + math.cos(a) * length, py + math.sin(a) * length
        path[#path + 1] = { px, py }
    end
    return path
end

-- 돔의 금: 가장자리에서 안쪽으로 파고드는 줄기 + BRANCH_AT 마디에서 갈라지는 잔금
local CRACKS = {}
for i = 1, CRACK_COUNT do
    local a = i * 2.39996 + 0.4
    local main = crack_path(i, a + math.pi, math.cos(a) * 0.97, math.sin(a) * 0.97, CRACK_STEPS, 0.14)
    local fork = main[BRANCH_AT + 1]
    local branch = crack_path(i + 31, a + math.pi + (i % 2 == 0 and 0.9 or -0.9), fork[1], fork[2], BRANCH_STEPS, 0.1)
    CRACKS[i] = { main = main, branch = branch }
end

-- 지금 살아 있는 최종 보스 (없으면 nil)
function MasterBossView.alive(combat)
    for _, monster in ipairs(combat.monsters) do
        if not monster.dead and monster.spec.final then
            return monster
        end
    end
    return nil
end

function MasterBossView.aura(monster, x, y, r, time)
    local pulse = 0.5 + 0.5 * math.sin(time * 2.2 + monster.anim)
    local gy = y + r * 0.95
    Draw.set_color(INK, 0.5)                          -- 땅에 번진 먹
    LG.ellipse("fill", x, gy, r * 2.3, r * 0.62, 32)
    LG.setBlendMode("add")
    Draw.set_color(VIOLET, 0.16 + 0.12 * pulse)
    LG.ellipse("fill", x, gy, r * 2.0, r * 0.5, 32)
    Draw.set_color(VIOLET, 0.55 + 0.3 * pulse)        -- 땅의 균열: 발밑에서 사방으로 갈라진 빛
    LG.setLineWidth(2)
    for i = 0, 5 do
        local a = i * math.pi / 3 + 0.3
        local mx, my = x + math.cos(a) * r * 0.9, gy + math.sin(a) * r * 0.24
        LG.line(x + math.cos(a) * r * 0.35, gy + math.sin(a) * r * 0.1, mx + math.sin(i * 7.1) * 6, my,
            x + math.cos(a) * r * 1.8, gy + math.sin(a) * r * 0.46)
    end
    for i = 0, 3 do                                   -- 맴도는 은빛 불티 (위로 솟았다 사라진다)
        local t = (time * 0.45 + i * 0.25) % 1
        local a = time * 0.8 + i * 1.7
        Draw.set_color(SILVER, 0.8 * (1 - t))
        LG.circle("fill", x + math.cos(a) * r * 1.6, gy - t * r * 2.4, 2.2, 8)
    end
    LG.setBlendMode("alpha")
end

-- 경로의 앞 shown 마디 (마지막 마디는 비율만큼)
local function partial(path, shown, x, cy, rx, ry)
    for s = 1, math.min(#path - 1, math.ceil(shown)) do
        local a, b = path[s], path[s + 1]
        local k = math.min(1, shown - (s - 1))
        LG.line(x + a[1] * rx, cy + a[2] * ry, x + (a[1] + (b[1] - a[1]) * k) * rx, cy + (a[2] + (b[2] - a[2]) * k) * ry)
    end
end

local function crack_lines(x, cy, rx, ry, progress, time)
    local shown = progress * CRACK_STEPS
    for pass = 1, 2 do
        if pass == 1 then
            Draw.set_color(INK, 0.75)
            LG.setLineWidth(3.5)
        else
            LG.setBlendMode("add")
            Draw.set_color(Draw.lerp_color(SILVER, WHITE, progress), 0.75 + 0.25 * math.sin(time * 9))
            LG.setLineWidth(1.6)
        end
        for _, crack in ipairs(CRACKS) do
            partial(crack.main, shown, x, cy, rx, ry)
            if shown > BRANCH_AT then
                partial(crack.branch, (shown - BRANCH_AT) * BRANCH_STEPS / (CRACK_STEPS - BRANCH_AT), x, cy, rx, ry)
            end
        end
    end
    LG.setBlendMode("alpha")
end

-- 균열 아이기스: 반투명 돔 (가운데는 맑고 가장자리가 빛난다) + 벌집 일렁임 + 파훼 금
local function dome(monster, x, cy, rx, ry, time)
    local aegis = monster.aegis
    local progress = math.max(0, math.min(1, aegis.dealt / math.max(1, aegis.need)))
    local flicker = progress > 0.7 and (0.75 + 0.25 * math.sin(time * 31)) or 1
    local pulse = 0.5 + 0.5 * math.sin(time * 3)
    Draw.set_color(VIOLET, 0.13 * flicker)
    LG.ellipse("fill", x, cy, rx, ry, 48)
    LG.setBlendMode("add")
    for i = 0, 3 do                                   -- 가장자리 빛 (안쪽으로 갈수록 옅게)
        local k = 1 - i * 0.035
        Draw.set_color(VIOLET, (0.3 - i * 0.065) * flicker)
        LG.setLineWidth(6)
        LG.ellipse("line", x, cy, rx * k, ry * k, 48)
    end
    for k = 0, 1 do                                   -- 테를 따라 도는 은빛 기운 두 줄기
        local head = time * 1.6 + k * math.pi
        local arc = {}
        for i = 0, 10 do
            local a = head - i * 0.09
            arc[#arc + 1], arc[#arc + 2] = x + math.cos(a) * rx * 0.985, cy + math.sin(a) * ry * 0.985
        end
        Draw.set_color(SILVER, 0.55 * flicker)
        LG.setLineWidth(3)
        LG.line(arc)
    end
    local cell = rx * 0.2                             -- 벌집 일렁임: 가장자리 근처 육각 칸이 위에서 아래로 물결친다
    for row = -6, 6 do
        for col = -6, 6 do
            local hx, hy = col * cell * 1.5, row * cell * 1.72 + (col % 2) * cell * 0.86
            local d = (hx / rx) ^ 2 + (hy / ry) ^ 2
            if d > 0.42 and d < 0.86 then
                local glow = math.max(0, math.sin(time * 2.4 - hy / ry * 4 + col * 0.3))
                Draw.set_color(SILVER, 0.3 * glow * flicker)
                LG.setLineWidth(1.2)
                local points = {}
                for v = 0, 5 do
                    points[#points + 1] = x + hx + math.cos(v * math.pi / 3) * cell * 0.86
                    points[#points + 1] = cy + hy + math.sin(v * math.pi / 3) * cell * 0.86
                end
                LG.polygon("line", points)
            end
        end
    end
    LG.setBlendMode("alpha")
    Draw.set_color(INK, 0.6)                          -- 먹 테두리 + 보랏빛 테 + 왼쪽 위 은빛 반사
    LG.setLineWidth(5)
    LG.ellipse("line", x, cy, rx, ry, 64)
    Draw.set_color(VIOLET, (0.7 + 0.3 * pulse) * flicker)
    LG.setLineWidth(2.5)
    LG.ellipse("line", x, cy, rx, ry, 64)
    Draw.set_color(SILVER, 0.6)
    LG.setLineWidth(2.5)
    local arc = {}
    for i = 0, 8 do
        local a = math.pi * (1.12 + i * 0.03)
        arc[#arc + 1], arc[#arc + 2] = x + math.cos(a) * rx * 0.86, cy + math.sin(a) * ry * 0.86
    end
    LG.line(arc)
    if progress > 0 then
        crack_lines(x, cy, rx, ry, progress, time)
    end
end

-- 5갈래 별 (가운데 원 + 꼭짓점 삼각형 — 오목 다각형 없이)
local function star(x, y, s, color, alpha, spin)
    for pass = 1, 2 do
        local size = pass == 1 and s + 1.6 or s
        Draw.set_color(pass == 1 and INK or color, alpha)
        for i = 0, 4 do
            local a = spin + i * math.pi * 2 / 5
            local l, r = a - 0.42, a + 0.42
            LG.polygon("fill", x + math.cos(l) * size * 0.42, y + math.sin(l) * size * 0.42, x + math.cos(a) * size,
                y + math.sin(a) * size, x + math.cos(r) * size * 0.42, y + math.sin(r) * size * 0.42)
        end
        LG.circle("fill", x, y, size * 0.45, 10)
    end
end

-- 그로기: 머리 위를 도는 별 다섯(뒤쪽 별은 작고 옅게, 궤도는 먹 고리) + 깜빡이는 "그로기"
local function dizzy(x, head_y, r, time)
    Draw.set_color(AMBER, 0.35)
    LG.setLineWidth(1.5)
    LG.ellipse("line", x, head_y, r * 1.05, r * 0.3, 32)
    local back, front = {}, {}
    for i = 0, 4 do
        local a = time * 3.4 + i * math.pi * 2 / 5
        local list = math.sin(a) > 0 and front or back
        list[#list + 1] = a
    end
    for _, list in ipairs({ back, front }) do
        for _, a in ipairs(list) do
            local near = math.sin(a) > 0
            star(x + math.cos(a) * r * 1.05, head_y + math.sin(a) * r * 0.3, near and 12 or 8, AMBER, near and 1 or 0.55, a * 1.5)
        end
    end
    Draw.shadow_text(I18n.t("trace.boss.groggy"), x - 90, head_y - r * 0.95, 180, "center", "value", AMBER,
        0.7 + 0.3 * math.sin(time * 8))
end

-- sprite_k: 그림 배율 (LaneView.SPRITE_SCALE) — 원화가 있으면 원화 배율까지 곱한 그림 반 높이로 돔을 맞춘다
function MasterBossView.status(monster, x, y, r, time, sprite_k)
    local _, art = SpriteCatalog.monster_image(monster)
    local half = r * (sprite_k or 2.9) * (art and art.scale or 1) * 0.5
    local cy = y - r * 0.25
    if monster.aegis ~= nil then
        dome(monster, x, cy, half * 0.98, half * 1.1, time)
    end
    if (monster.groggy_time or 0) > 0 then
        dizzy(x, cy - half * 0.92, r, time)
    end
end

function MasterBossView.draw_overlay(combat, lane, time, motion)
    MasterBossHud.draw(combat, lane, time, motion, MasterBossView.alive(combat))
end

return MasterBossView
