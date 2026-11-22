-- ui/MasterBossHud.lua
-- 최종 보스 전용 레인 덮개 (ui/MasterBossView.draw_overlay 가 부른다, 규칙 계산 없음 — 수치는 data/enemies.lua 의 boss_patterns.master):
--   체력 띠   : 레인 아래쪽 가운데 어두운 철판 — 은빛 이름 · 체력 숫자 · 체력 막대(아이기스 문턱 thresholds 눈금 — 지난 문턱은
--               어둡게, 체력이 멈춰 서는 다음 관문 monster.hp_floor 는 보랏빛으로 맥동).
--               아이기스가 서 있으면 막대 위에 보랏빛 막 + 아래 줄 "균열 아이기스 [파훼 게이지] 파훼 n%",
--               과부하가 꺼져 있으면 판 위에 깜빡이는 "과부하로 보호막을 파훼하라!", 그로기면 아래 줄이 호박색 남은 시간 막대
--   경고 배너 : boss:master_arrived 뒤 ARRIVAL 초 — 레인을 가로지르는 들쭉날쭉한 먹 띠 + "최후의 밤"(은빛) + 부제
--   결말 배너 : master:final_resolved 뒤 VERDICT 초 — 봉인(은빛) / 미봉인(검붉은) 결말 문구 (점화 수/슬롯 수) +
--               봉인진 마름모 4개 (쓰러뜨린 순간 점화된 수만큼 계열 색으로 빛난다)
-- 배너 시각은 ui/EntityMotion 이 이벤트를 받아 기록하고 처음 그려지는 순간(실시간 time)부터 잰다 — 배속과 무관하게 같은 길이.

local I18n = require("systems.I18n")
local MasterTrace = require("systems.MasterTrace")
local Draw = require("ui.Draw")
local Frame = require("ui.Frame")
local Lettering = require("ui.Lettering")
local ENEMIES = require("data.enemies")
local ITEMS = require("data.items")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local MasterBossHud = {}

local C = UI.color
local LG = love.graphics
local DATA = ENEMIES.boss_patterns.master
local INK = { 0.03, 0.02, 0.04 }
local WHITE = { 1, 1, 1 }
local VIOLET = { 0.62, 0.38, 1.00 }
local SILVER = { 0.82, 0.90, 1.00 }
local AMBER = { 1.00, 0.80, 0.30 }
local HP_FILL = { 0.66, 0.22, 0.78 }
local HP_TOP = { 0.86, 0.52, 1.00 }
local GEO = LAYOUT.master_boss
local BAR_H = 14
local ARRIVAL, VERDICT, OPEN, CLOSE = 2.6, 3.4, 0.22, 0.5

-- 체력 띠 판 · 막대 좌표 (스모크 테스트용)
function MasterBossHud.plate_rect(lane)
    return { x = lane.x + (lane.w - GEO.plate_w) / 2, y = lane.y + lane.h - GEO.plate_h - GEO.plate_bottom, w = GEO.plate_w,
        h = GEO.plate_h }
end

function MasterBossHud.bar_rect(lane)
    local plate = MasterBossHud.plate_rect(lane)
    return { x = plate.x + 24, y = plate.y + 38, w = plate.w - 48, h = BAR_H }
end

local function gauge(x, y, w, h, ratio, fill, alpha)
    Draw.set_color(INK, 0.9 * alpha)
    LG.rectangle("fill", x - 2, y - 2, w + 4, h + 4, 3, 3)
    Draw.set_color({ 0.10, 0.08, 0.13 }, alpha)
    LG.rectangle("fill", x, y, w, h, 2, 2)
    ratio = math.max(0, math.min(1, ratio))
    if ratio > 0 then
        Draw.set_color(fill, alpha)
        LG.rectangle("fill", x, y, w * ratio, h, 2, 2)
        Draw.set_color(WHITE, 0.28 * alpha)
        LG.rectangle("fill", x, y, w * ratio, math.max(1, h * 0.3), 2, 2)
    end
end

local function hp_bar(monster, bar, time)
    local ratio = math.max(0, monster.hp) / monster.max_hp
    gauge(bar.x, bar.y, bar.w, bar.h, ratio, HP_FILL, 1)
    Draw.set_color(HP_TOP, 0.55)
    LG.rectangle("fill", bar.x, bar.y + 2, bar.w * ratio, 2)
    if monster.aegis ~= nil then                     -- 아이기스: 막대를 덮는 보랏빛 막 + 흐르는 빗금
        LG.setBlendMode("add")
        Draw.set_color(VIOLET, 0.22 + 0.1 * math.sin(time * 5))
        LG.rectangle("fill", bar.x - 3, bar.y - 3, bar.w + 6, bar.h + 6, 4, 4)
        Draw.set_color(SILVER, 0.35)
        LG.setLineWidth(1.5)
        for sx = bar.x + (time * 40) % 18, bar.x + bar.w - 6, 18 do
            LG.line(sx, bar.y + bar.h, sx + 7, bar.y)
        end
        LG.setBlendMode("alpha")
    end
    for _, threshold in ipairs(DATA.thresholds) do  -- 아이기스 문턱 눈금 (지난 문턱은 어둡게, 다음 관문은 맥동)
        local mx = bar.x + bar.w * threshold
        local gate = monster.hp_floor ~= nil and math.abs(monster.hp_floor - monster.max_hp * threshold) < 1e-6
        local passed = ratio <= threshold and not gate
        if gate then                                  -- 체력이 이 문턱에서 멈춘다 (다음 아이기스가 서야 내려간다)
            Draw.glow(mx, bar.y + bar.h / 2, 16, VIOLET, 0.5 + 0.4 * math.sin(time * 6))
        end
        Draw.set_color(INK)
        LG.setLineWidth(3)
        LG.line(mx, bar.y - 5, mx, bar.y + bar.h + 3)
        Draw.set_color(passed and { 0.4, 0.34, 0.48 } or SILVER)
        LG.setLineWidth(gate and 2 or 1.2)
        LG.line(mx, bar.y - 4, mx, bar.y + bar.h + 2)
        local d = gate and 5.5 or 4.5
        Draw.set_color(INK)
        LG.polygon("fill", mx, bar.y - 11 - d, mx + d + 1.5, bar.y - 11, mx, bar.y - 11 + d + 1.5, mx - d - 1.5, bar.y - 11)
        Draw.set_color(passed and { 0.4, 0.34, 0.48 } or VIOLET)
        LG.polygon("fill", mx, bar.y - 11 - d + 1.5, mx + d, bar.y - 11, mx, bar.y - 11 + d, mx - d, bar.y - 11)
    end
end

-- 아래 줄: 아이기스 파훼 게이지 또는 그로기 남은 시간
local function state_row(monster, plate)
    local y = plate.y + 62
    local label_w = 132
    if monster.aegis ~= nil then
        local share = monster.aegis.dealt / math.max(1, monster.aegis.need)
        local progress = I18n.t("trace.boss.aegis_progress", { pct = math.floor(math.min(1, share) * 100) })
        Draw.label_text(I18n.t("trace.boss.aegis"), plate.x + 24, y - 3, label_w, "left", "label", VIOLET)
        gauge(plate.x + 24 + label_w, y + 1, plate.w - 48 - label_w - 96, 8, share, Draw.lerp_color(VIOLET, SILVER, share), 1)
        Draw.label_text(progress, plate.x + plate.w - 24 - 90, y - 3, 90, "right", "label", SILVER)
    elseif (monster.groggy_time or 0) > 0 then
        Draw.label_text(I18n.t("trace.boss.groggy"), plate.x + 24, y - 3, label_w, "left", "label", AMBER)
        gauge(plate.x + 24 + label_w, y + 1, plate.w - 48 - label_w, 8, monster.groggy_time / DATA.groggy_time, AMBER, 1)
    end
end

-- 과부하를 켜라는 깜빡이는 안내 (판 바로 위)
local function overclock_hint(plate, time)
    local text = I18n.t("trace.boss.aegis_hint")
    local font = Draw.font("button")
    local w, h = font:getWidth(text) + 36, 28
    local x, y = plate.x + (plate.w - w) / 2, plate.y - h - 8
    local blink = 0.55 + 0.45 * math.sin(time * 9)
    Draw.set_color(INK, 0.85)
    LG.rectangle("fill", x - 2, y - 2, w + 4, h + 4, 14, 14)
    Draw.set_color({ 0.24, 0.06, 0.2 }, 0.95)
    LG.rectangle("fill", x, y, w, h, 12, 12)
    Draw.set_color(C.overclock, blink)
    LG.setLineWidth(2)
    LG.rectangle("line", x + 1, y + 1, w - 2, h - 2, 12, 12)
    Draw.label_text(text, x, y + (h - font:getHeight()) / 2, w, "center", "button", Draw.lerp_color(C.overclock, WHITE, 0.35 * blink))
end

local function plate(combat, monster, lane, time)
    local p = MasterBossHud.plate_rect(lane)
    Frame.panel(p.x, p.y, p.w, p.h, { style = "dark", alpha = 0.95 })
    Draw.set_color(VIOLET, 0.45)
    LG.setLineWidth(1)
    LG.rectangle("line", p.x + 9.5, p.y + 9.5, p.w - 19, p.h - 19, 4, 4)
    Lettering.draw(I18n.t("trace.boss.bar_name"), p.x, p.y + 8, p.w, "center", "item_name", "silver")
    Draw.label_text(string.format("%d / %d", math.max(0, math.ceil(monster.hp)), math.ceil(monster.max_hp)), p.x + 24, p.y + 13,
        p.w - 48, "right", "label", C.text)
    hp_bar(monster, MasterBossHud.bar_rect(lane), time)
    state_row(monster, p)
    if monster.aegis ~= nil and not combat.overclock then
        overclock_hint(p, time)
    end
end

-- 레인을 가로지르는 들쭉날쭉한 먹 띠 (open 0~1 = 위아래로 펼쳐진 정도)
local function band(lane, cy, half_h, open, alpha, edge, time)
    local steps = 24
    local h = half_h * open
    local function jag(i, side)
        return math.sin(i * 7.31 + side) * 4 + math.sin(i * 2.17 + side * 3) * 3
    end
    Draw.set_color(INK, 0.86 * alpha)
    for i = 0, steps - 1 do
        local x1, x2 = lane.x + lane.w * i / steps, lane.x + lane.w * (i + 1) / steps
        LG.polygon("fill", x1, cy - h + jag(i, 0) * open, x2, cy - h + jag(i + 1, 0) * open,
            x2, cy + h + jag(i + 1, 1) * open, x1, cy + h + jag(i, 1) * open)
    end
    LG.setBlendMode("add")
    for _, side in ipairs({ -1, 1 }) do              -- 위·아래 가장자리의 균열 빛
        Draw.set_color(edge, (0.55 + 0.25 * math.sin(time * 7 + side)) * alpha)
        LG.setLineWidth(2)
        LG.line(lane.x, cy + side * (h + 2), lane.x + lane.w, cy + side * (h + 2))
        Draw.set_color(edge, 0.18 * alpha)
        LG.setLineWidth(10)
        LG.line(lane.x, cy + side * (h + 4), lane.x + lane.w, cy + side * (h + 4))
    end
    for i = 0, 9 do                                  -- 띠를 따라 흐르는 은빛 불티
        local t = (time * 0.18 + i * 0.1) % 1
        Draw.set_color(SILVER, 0.7 * alpha * math.sin(math.pi * t))
        LG.circle("fill", lane.x + lane.w * t, cy + math.sin(i * 3.7 + time * 2) * h * 0.8, 1.8, 6)
    end
    LG.setBlendMode("alpha")
end

local function banner(motion, lane, time)
    local state, t = motion:banner_at(time)
    if state == nil then
        return
    end
    local life = state.kind == "arrival" and ARRIVAL or VERDICT
    if t >= life then
        return
    end
    local open = math.min(1, t / OPEN)
    open = 1 - (1 - open) * (1 - open)
    if open < 0.02 then
        return
    end
    local alpha = math.min(1, (life - t) / CLOSE)
    local sealed = state.kind == "verdict" and state.slain and state.lit >= state.total
    local edge = (state.kind == "arrival" or sealed) and VIOLET or C.danger
    local cy = lane.y + GEO.banner_y
    band(lane, cy, GEO.banner_half_h, open, alpha, edge, time)
    local scale = 1 + 0.32 * math.exp(-t * 7) * math.cos(t * 16)
    LG.push()
    LG.translate(lane.x + lane.w / 2, cy)
    LG.scale(scale)
    if state.kind == "arrival" then
        Lettering.draw(I18n.t("trace.boss.banner"), -lane.w / 2, -44, lane.w, "center", "headline", "silver", alpha * open)
        Draw.shadow_text(I18n.t("trace.boss.banner_sub"), -lane.w / 2, 12, lane.w, "center", "story", SILVER, alpha * open)
    else
        local key = sealed and "trace.boss.sealed" or "trace.boss.unsealed"
        Lettering.draw(I18n.t(key, { lit = state.lit, slots = state.total }), -lane.w / 2 + 20, -36, lane.w - 40, "center", "title",
            sealed and "silver" or "blood", alpha * open)
        for i, slot in ipairs(MasterTrace.SLOTS) do   -- 봉인진 마름모: 쓰러뜨린 순간 점화된 수만큼 계열 색으로
            local nx, lit = (i - (#MasterTrace.SLOTS + 1) / 2) * 38, i <= state.lit
            local color = lit and ITEMS.archetypes[slot.archetype].color or { 0.26, 0.24, 0.3 }
            Draw.set_color(INK, alpha * open)
            LG.polygon("fill", nx, 8, nx + 13, 21, nx, 34, nx - 13, 21)
            Draw.set_color(color, alpha * open)
            LG.polygon("fill", nx, 11, nx + 10, 21, nx, 31, nx - 10, 21)
            if lit then
                Draw.glow(nx, 21, 22, color, 0.6 * alpha * open)
                Draw.set_color(WHITE, 0.8 * alpha * open)
                LG.polygon("fill", nx, 16, nx + 4, 21, nx, 26, nx - 4, 21)
            end
        end
    end
    LG.pop()
end

-- monster = 살아 있는 최종 보스 (없으면 체력 띠 없이 배너만)
function MasterBossHud.draw(combat, lane, time, motion, monster)
    if monster ~= nil then
        plate(combat, monster, lane, time)
    end
    if motion ~= nil and motion.banner_at ~= nil then
        banner(motion, lane, time)
    end
end

return MasterBossHud
