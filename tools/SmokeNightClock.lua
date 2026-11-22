-- tools/SmokeNightClock.lua
-- 밤의 끝 판정 (systems/NightClock) 헤드리스 검사:
--   1) 새벽 시각이 지나도 몬스터가 남아 있으면 밤이 이어지고(소탕 시간 · combat:overtime 한 번), 마지막 몬스터가 쓰러지면 바로 끝난다
--   2) 새벽 게이트(화면이 있을 때): 웨이브를 다 소탕해도 셔터가 덮을 때(release_dawn)까지 밤이 끝나지 않는다
--   3) 소탕 시간 한도(night.overtime_max)를 넘기면 안전장치로 끝나고 남은 몬스터는 달아난다 (combat:monsters_fled)
-- 시작 무기가 없는 견습 1일차 밤을 쓰고, 방벽이 무너지지 않게 내구도를 크게 둔다.
-- 소탕 시간 화면(상단 바 "남은 몬스터" · 레인 붉은 진행 막대·문구 · [영업 마감] 자리 문구)을 오프스크린으로 그린다 (--shots 면 저장).

local RNG = require("core.RNG")
local EventBus = require("core.EventBus")
local Workshop = require("systems.Workshop")
local COMBAT = require("data.combat")
local LAYOUT = require("data.layout")

local SmokeNightClock = {}

local DT = 1 / 60
local NIGHT = COMBAT.night
local LANE, FIELD = LAYOUT.night.lane, LAYOUT.night.field

local function check(condition, message)
    assert(condition, "SmokeNightClock: " .. message)
end

local function fresh_night(seed)
    RNG.set_seed(seed)
    local w = Workshop({ difficulty = "apprentice" })
    w.hp = 1000000          -- 무기가 없으니 몬스터는 방벽까지 걸어와 부딪힌다 (패배로 끝나지 않게)
    check(w:start_night(), "night should start")
    return w
end

local function run_until(w, condition, limit)
    local steps = 0
    while not condition() do
        w:update(DT)
        steps = steps + 1
        check(steps < limit / DT, "timed out after " .. limit .. "s of night")
    end
end

-- 포탈 앞에 움직이지 않는 낙오 몬스터 하나 (둔화 배율 0)
local function add_straggler(combat)
    combat:summon("slime", LANE.x + LANE.w - 80, FIELD.y + FIELD.h / 2)
    local straggler = combat.monsters[#combat.monsters]
    straggler:apply_slow(0, 999)
    return straggler
end

local function kill_all(combat)
    for _, monster in ipairs(combat.monsters) do
        if not monster.dead then
            combat:damage_monster(monster, 1e9)
        end
    end
end

-- 소탕 시간 화면 그리기: 상단 바 + 레인 + [영업 마감] 버튼 문구 (--shots 면 smoke_night_overtime.png)
local function render_overtime(w, shots)
    local Hud = require("ui.Hud")
    local LaneView = require("ui.LaneView")
    local Slots = require("ui.Slots")
    local I18n = require("systems.I18n")
    local hud, canvas = Hud(), love.graphics.newCanvas(1280, 720)
    Slots.set_mode_provider(function() return "night" end)
    love.graphics.push("all")
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.origin()
    LaneView.draw(w, 1.5, nil)
    hud:draw(w, 1.5)
    love.graphics.setCanvas()
    love.graphics.pop()
    Slots.set_mode_provider(nil)
    check(I18n.t("hud.monsters_left", { count = w.combat:alive_count() }):find(tostring(w.combat:alive_count()), 1, true) ~= nil,
        "the HUD overtime text carries the remaining count")
    if shots then
        canvas:newImageData():encode("png", "smoke_night_overtime.png")
    end
end

local function waits_for_the_wave(shots)
    local w = fresh_night(4242)
    local combat, overtime = w.combat, {}
    local token = EventBus.subscribe("combat:overtime", function(p) overtime[#overtime + 1] = p end)
    run_until(w, function() return combat.elapsed >= NIGHT.duration - 0.5 end, NIGHT.duration)
    add_straggler(combat)
    run_until(w, function() return combat.elapsed >= NIGHT.duration + 2 end, NIGHT.duration + 3)
    check(w.phase == "night", "the night must go on while a monster is still alive after dawn")
    check(combat:in_overtime() and combat:time_to_dawn() == nil, "after dawn with monsters left the clean-up continues")
    check(#overtime == 1 and overtime[1].remaining >= 1, "combat:overtime fires once with the remaining count")
    render_overtime(w, shots)
    kill_all(combat)
    w:update(DT)
    check(w.phase ~= "night", "the night ends as soon as the last monster falls")
    EventBus.unsubscribe(token)
    w:destroy()
end

local function dawn_gate_holds()
    local w = fresh_night(4243)
    local combat = w.combat
    combat:set_dawn_gate(true)
    run_until(w, function() return combat.elapsed >= NIGHT.duration - 0.2 end, NIGHT.duration)
    kill_all(combat)
    run_until(w, function() return combat.elapsed >= NIGHT.duration + 0.5 end, NIGHT.duration + 1)
    check(w.phase == "night" and combat:time_to_dawn() == 0, "with the dawn gate the night waits for the shutter")
    combat:release_dawn()
    w:update(DT)
    check(w.phase ~= "night", "releasing the dawn gate ends the cleared night")
    w:destroy()
end

local function overtime_cap()
    local w = fresh_night(4244)
    local combat, fled = w.combat, 0
    local token = EventBus.subscribe("combat:monsters_fled", function(p) fled = fled + p.count end)
    run_until(w, function() return combat.elapsed >= NIGHT.duration - 0.5 end, NIGHT.duration)
    add_straggler(combat)
    run_until(w, function() return w.phase ~= "night" end, NIGHT.duration + NIGHT.overtime_max + 2)
    check(combat.elapsed >= NIGHT.duration + NIGHT.overtime_max - DT, "only the overtime cap may cut a night short")
    check(fled >= 1, "monsters left at the overtime cap flee")
    EventBus.unsubscribe(token)
    w:destroy()
end

function SmokeNightClock.run(log, shots)
    waits_for_the_wave(shots)
    dawn_gate_holds()
    overtime_cap()
    log("night clock ok (dawn waits for the wave, overtime once, dawn gate, %ds overtime cap)", NIGHT.overtime_max)
end

return SmokeNightClock
