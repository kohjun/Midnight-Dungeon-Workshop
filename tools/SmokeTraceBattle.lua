-- tools/SmokeTraceBattle.lua
-- '스승의 흔적' 캠페인 전투 화면 스모크 검사 (SmokeTest 가 SmokeTraceUI 다음에 실행):
--   ① 봉인 공명 슬롯 (ui/ResonanceView · ResonanceSigil): 일반 계약에는 아무것도 없음 · 낮 진열장 2칸 점화 + 2칸 소등
--      (+3 저주 유물 · 빈 황금 슬롯) — 점화 칸 둘레 계열 색 결계선 · 빈 슬롯 금화 문양 픽셀, 툴팁 줄(슬롯 · 점화 상태 · 조건 ·
--      +10 불멸)과 빈 슬롯 안내 상자(채워지지 않은 '{' 없음), 막 점화된 칸의 점화 연출 경로
--   ② · ③ 밤 진열장 공명선 · 룬 사슬 · 최종 보스 화면은 tools/SmokeTraceBattleBoss (이 파일의 kit 를 쓴다)
--   --shots 면 smoke_trace_grid_day.png (밤 · 보스 화면은 SmokeTraceBattleBoss 가 저장)
-- 공방·연출 계층은 끝나면 모두 정리하고 화면 모드 제공자를 되돌린다.

local SmokeTraceBattle = {}

local DT = 1 / 30
local SLOT = { fire = 7, lightning = 9, curse = 17, gold = 19, center = 13 }

local function check(condition, message)
    if not condition then
        error("SmokeTraceBattle: " .. message, 2)
    end
end

local function t(key, vars)
    return require("systems.I18n").t(key, vars)
end

local function ready(w, id, level, cell)
    local item = require("systems.ItemFactory").make_ready(id, "rare", level)
    w.inventory:place(item, "grid", cell)
    return item
end

-- 툴팁 줄 목록에 채워지지 않은 자리표시자가 없는지 ({ text } 표 또는 { 문구, 색 } 또는 문자열)
local function no_holes(lines, what)
    for _, line in ipairs(lines) do
        local text = type(line) == "table" and (line.text or line[1]) or line
        check(type(text) == "string" and text ~= "" and not text:find("{", 1, true), what .. " has an unfilled line: " .. tostring(text))
    end
end

-- 오프스크린 1280x720 에 그린 ImageData (shots 이고 name 이 있으면 파일로)
local function render(name, shots, draw)
    local canvas = love.graphics.newCanvas(1280, 720)
    love.graphics.push("all")
    love.graphics.setCanvas({ canvas, stencil = true })
    require("ui.Draw").clear(require("data.ui").color.background)
    draw()
    love.graphics.setCanvas()
    love.graphics.pop()
    local data = canvas:newImageData()
    if shots and name ~= nil then
        data:encode("png", name)
    end
    return data
end

-- (x, y) 둘레 radius 안 픽셀 중 하나라도 test(r, g, b) 를 만족하는지
local function any_pixel(data, x, y, radius, test)
    for py = math.floor(y - radius), math.ceil(y + radius) do
        for px = math.floor(x - radius), math.ceil(x + radius) do
            if px >= 0 and py >= 0 and px < data:getWidth() and py < data:getHeight() and test(data:getPixel(px, py)) then
                return true
            end
        end
    end
    return false
end

-- 사각형 안 평균 밝기 (r + g + b)
local function brightness(data, x, y, w, h)
    local sum, count = 0, 0
    for py = math.floor(y), math.floor(y + h) - 1, 2 do
        for px = math.floor(x), math.floor(x + w) - 1, 2 do
            local r, g, b = data:getPixel(px, py)
            sum, count = sum + r + g + b, count + 1
        end
    end
    return sum / math.max(1, count)
end

-- 실제 런과 같은 연출 계층 (Feedback → FeedbackBoss → FeedbackMaster 구독 · 모션 · 공격 연출)
local function attach_ui(w)
    local ui = { fx = require("ui.Effects")(), hud = require("ui.Hud")(), input = require("ui.WorkshopInput")(w) }
    ui.feedback = require("ui.Feedback")(ui.fx, ui.hud, w)
    ui.attacks = require("ui.AttackEffects")(ui.fx)
    ui.motion = require("ui.EntityMotion")(ui.fx, w)
    -- seconds 만큼 진행 (each 가 true 를 돌려주면 그 자리에서 멈춘다). 멈췄으면 true
    function ui.step(seconds, each)
        for _ = 1, math.max(1, math.floor(seconds / DT + 0.5)) do
            w:update(DT)
            ui.attacks:update(DT, w.combat)
            ui.motion:update(DT, w.combat)
            ui.fx:update(DT)
            ui.hud:update(DT)
            if each ~= nil and each() then
                return true
            end
        end
        return false
    end
    function ui.destroy()
        ui.motion:destroy()
        ui.attacks:destroy()
        ui.feedback:destroy()
        ui.input:destroy()
    end
    return ui
end

local function grid_only(w, ui, time)
    return render(nil, false, function()
        require("ui.GridView").draw_grid(w, ui.input, time)
    end)
end

SmokeTraceBattle.kit = { check = check, t = t, ready = ready, no_holes = no_holes, render = render, any_pixel = any_pixel,
    brightness = brightness, grid_only = grid_only, attach_ui = attach_ui, DT = DT, SLOT = SLOT }

-- 일반 계약: 슬롯 틀·툴팁 줄이 없고 진열장은 예전 그대로 그려진다
local function check_plain()
    local Workshop, ResonanceView = require("systems.Workshop"), require("ui.ResonanceView")
    local w = Workshop({ difficulty = "broker" })
    local ui = attach_ui(w)
    check(w.master_trace == nil and ResonanceView.slot_lines(w, SLOT.fire) == nil, "other contracts have no seal sockets")
    require("ui.Slots").set_mode_provider(function() return "night" end)
    grid_only(w, ui, 1)
    require("ui.Slots").set_mode_provider(nil)
    ui.destroy()
    w:destroy()
    local MonsterShapes, body = require("ui.MonsterShapes"), { 0.46, 0.34, 0.66 }     -- 원화가 없을 때의 최종 보스 도형
    local data = render(nil, false, function() MonsterShapes.draw("master", 640, 360, 40, 0, body) end)
    check(MonsterShapes.has("master") and any_pixel(data, 640, 380, 2, function(r, g, b) return b > 0.5 and r > g end),
        "the final boss has its own shape fallback")
end

-- ① 낮: 2칸 점화(화염 +5 · 번개 +7) · 2칸 소등(저주 +3 · 빈 황금 슬롯)
local function check_day(w, ui, shots)
    local Slots, Tooltip, ResonanceView = require("ui.Slots"), require("ui.Tooltip"), require("ui.ResonanceView")
    local trace = w.master_trace
    ready(w, "flame_sword", 5, SLOT.fire)
    ready(w, "storm_rod", 7, SLOT.lightning)
    local dim_curse = ready(w, "hex_scythe", 3, SLOT.curse)
    ready(w, "mana_crystal", 2, SLOT.center)
    check(trace:is_lit(SLOT.fire) and trace:is_lit(SLOT.lightning) and not trace:is_lit(SLOT.curse) and not trace:is_lit(SLOT.gold),
        "precondition: 2 lit + 2 dark seal sockets")
    Slots.set_mode_provider(function() return "day" end)
    local gx, gy = Slots.center("grid", SLOT.gold)
    ui.input.pointer.x, ui.input.pointer.y = gx + 8, gy + 4
    local data = render("smoke_trace_grid_day.png", shots, function()
        require("ui.DayLayoutView").draw(w, ui.input, 3.2, nil)
        ui.hud:draw(w, 3.2)
        Tooltip.draw_hovered(w, ui.input)                         -- 빈 황금 슬롯 안내 상자
        local cx, cy = Slots.center("grid", SLOT.curse)
        Tooltip.draw(dim_curse, nil, cx - 520, cy - 330, w)       -- 소등된 저주 슬롯 유물 툴팁 (빈 작업대 위)
    end)
    local x, y, cw = Slots.rect("grid", SLOT.fire)
    check(any_pixel(data, x + cw / 2, y - 6, 2, function(r, _, b) return r > 0.6 and r > b + 0.25 end),
        "a lit flame socket glows orange around its cell")
    check(any_pixel(data, gx + 6, gy, 3, function(r, g, b) return r > 0.55 and g > 0.42 and b < 0.45 end),
        "an empty gold socket shows its coin glyph")
    local lines = Tooltip.lines(dim_curse, nil, w)
    local tip = t("trace.resonance.tip", { archetype = t("trace.resonance.archetypes.curse"), level = 5, mult = "1.5" })
    check(lines[#lines].text == tip and lines[#lines - 1].text:find(t("trace.resonance.dark_state"), 1, true) ~= nil,
        "a dark curse socket appends its state and rule lines")
    no_holes(lines, "curse socket tooltip")
    local empty = ResonanceView.slot_lines(w, SLOT.gold)
    check(empty ~= nil and #empty == 2 and empty[1].size == "tooltip_name", "an empty socket gets its own small box")
    no_holes(empty, "empty socket box")
    check(ResonanceView.slot_lines(w, SLOT.center) == nil and ResonanceView.slot_lines(w, 1) == nil, "only the 4 sockets have lines")
    grid_only(w, ui, 5)                                          -- 소등 상태를 본 뒤 +5 로 바꿔 점화 → 점화 연출 경로
    w.inventory:remove(dim_curse)
    ready(w, "hex_scythe", 5, SLOT.curse)
    grid_only(w, ui, 5.2)
    check(trace:lit_count() == 3, "the forged curse relic lights its socket")
    Slots.set_mode_provider(nil)
end

function SmokeTraceBattle.run(log, shots)
    require("core.RNG").set_seed(6060)
    check_plain()
    local w = require("systems.Workshop")({ difficulty = "master_trace" })
    local ui = attach_ui(w)
    check_day(w, ui, shots)
    local boss = require("tools.SmokeTraceBattleBoss").run(w, ui, shots, SmokeTraceBattle.kit)
    require("ui.Slots").set_mode_provider(nil)
    ui.destroy()
    w:destroy()
    log("trace battle ok (seal sockets: rune frames/glyphs/lit barriers/ignition, tooltip + empty-socket box; "
        .. "4/4 resonance lines, rune chains slam/fade; %s: banner, lockdown FX, aegis dome/bar/gauge/hint, shatter, groggy, "
        .. "verdict, final-tier tooltip)", boss)
end

return SmokeTraceBattle
