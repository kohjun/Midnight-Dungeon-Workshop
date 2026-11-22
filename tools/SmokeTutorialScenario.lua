-- tools/SmokeTutorialScenario.lua
-- 스모크 시나리오 B (SmokeScenario 가 A 다음에 끼워 넣는다): 처음 플레이(계약서 없이 견습 + 튜토리얼)의 첫 5분 9단계 전체 완주.
-- 끝나면 tutorial_done 이 저장되었는지 확인한다. check_skip_saves() 는 [건너뛰기]도 tutorial_done 을 저장하는지 헤드리스로 본다.
--   UV 스캔(움직이기만 하면 렌즈 꺼짐 → 누른 채 훑어 결함 적발) → 3 매입(할인) → 2 세척 → [다음](+1 골드 제련 안내)
--   → [자동 배치](무기 → 진열장 첫 빈칸) → [다음](3분류 · 주인공 장비창 · 거치대 안내) → [다음]([길드]·[의뢰]·연마석 안내)
--   → Space 영업 마감 → 밤: 배속 토글 Tab(2x → 3x → 1x) · 몬스터 호버 툴팁 · Space 과부하 → 첫 밤 생존 = 완료
-- build(S, ctx, env) 는 평평한 스텝 목록을 반환한다. env = { night_timeout }

local SmokeTutorialScenario = {}

-- 밤 레인에 몬스터가 나타날 때까지 기다렸다가 포인터를 올리고, 양피지 툴팁(ui/MonsterTooltip)이 그 몬스터를 가리키는지 확인
-- (--shots 면 툴팁이 뜬 화면을 smoke_<shot>.png 로 저장)
local function hover_monster_step(ctx, shot)
    local StateManager = require("core.StateManager")
    local MonsterTooltip = require("ui.MonsterTooltip")
    local PORTAL_X = require("data.layout").night.portal.x
    local hits = 0
    return { label = "hover a monster for its tooltip", timeout = 15, run = function()
        local state = StateManager.current()
        local combat, pointer = state:get_workshop().combat, state:get_input().pointer
        local target = nil
        for _, monster in ipairs(combat.monsters) do
            if not monster.dead and monster.x < PORTAL_X then      -- 포탈 아치를 빠져나온 몬스터
                target = monster
            end
        end
        if target == nil then
            return false
        end
        love.event.push("mousemoved", target.x, target.y, 0, 0, false)
        hits = MonsterTooltip.hovered(combat, pointer.x, pointer.y) ~= nil and hits + 1 or 0
        if hits == 3 and ctx.shots then
            love.graphics.captureScreenshot("smoke_" .. shot .. ".png")
        end
        return hits >= 4
    end }
end

function SmokeTutorialScenario.build(S, ctx, env)
    local StateManager = require("core.StateManager")
    local Slots = require("ui.Slots")
    local steps = {}
    local function add(...)
        for _, entry in ipairs({ ... }) do
            if entry.run ~= nil then
                steps[#steps + 1] = entry
            else
                for _, nested in ipairs(entry) do
                    steps[#steps + 1] = nested
                end
            end
        end
    end
    local function workshop()
        return StateManager.current():get_workshop()
    end
    local bench_x, bench_y = Slots.center("bench", 1)

    -- B. 튜토리얼 (메모리 진행도라 처음 플레이: 서명 없이 기본 호칭)
    local Progress = require("systems.Progress")
    local LAYOUT = require("data.layout")
    local function view()
        return StateManager.current():get_tutorial_view()
    end
    local function next_button(label)        -- 안내 띠는 스포트라이트를 피해 자리를 옮기므로 누르는 순간의 자리를 쓴다
        return S.click_at("tutorial: [Next] " .. label, function() return view():next_rect() end)
    end
    add(S.expect_tutorial("hud_status"), S.check("first run: apprentice with tutorial, unsigned default name", function()
        local w = workshop()
        return w.difficulty_id == require("data.difficulties").first_run and w.tutorial ~= nil and w.tutorial:is_active()
            and w.owner_name == require("systems.I18n").t("story.default_name") and Progress.player_name() == nil
            and not Progress.tutorial_done()
    end), S.wait(10), S.check("the spotlight cuts out exactly the HUD cards (+6 px)", function()
        local rects = view():spot_rects(StateManager.current():get_input())
        for i, id in ipairs({ "badge", "ward", "purse" }) do
            local r, card = rects[i], LAYOUT.hud[id]
            assert(r.x == card.x - 6 and r.y == card.y - 6 and r.w == card.w + 12 and r.h == card.h + 12, "spotlight off on " .. id)
        end
        return #rects == 3
    end), S.shot("tutorial_hud"))
    for _, id in ipairs({ "hud_tribute", "menu_bar", "areas", "scan" }) do        -- 읽고 [다음]: HUD → 메뉴 바 → 세 구역 → 첫 손님
        add(next_button(id), S.expect_tutorial(id), S.wait(8), S.shot("tutorial_" .. id))
    end
    add(S.check("the scan spotlight matches the UV button and bench slot", function()
        local input = StateManager.current():get_input()
        local rects = view():spot_rects(input)
        local uv = input:button("uv").rect
        return rects[2].x == uv.x - 6 and rects[2].y == uv.y - 6 and rects[2].w == uv.w + 12
    end))
    -- UV 모드를 켜도 움직이기만 하면 렌즈는 꺼져 있고 배터리도 줄지 않는다
    add(S.press("1"), S.expect_event("ui:tool_changed"), S.move(bench_x - 30, bench_y), S.move(bench_x + 30, bench_y), S.wait(8))
    add(S.check("UV hover without holding keeps the lens off", function()
        local w = workshop()
        local item = w.appraisal:bench_item()
        return not w.appraisal.lens_on and w.supplies.uv == 100 and not item.revealed.grade and w.appraisal:scan_coverage(item) == 0
    end), S.shot("uv_idle"))
    -- 버튼을 누른 채 훑어야 스캔된다
    add(S.sweep_bench(), S.expect_tutorial("buy"), S.wait(2), S.check("holding drains the battery, releasing turns the lens off", function()
        local w = workshop()
        return w.supplies.uv < 100 and not w.appraisal.lens_on
    end))
    add(S.press("1"), S.press("3"), S.expect_tutorial("clean"), S.check("shortcut 3 buys, tutorial purchase stays on bench", function()
        local item = workshop().appraisal:bench_item()
        return item ~= nil and item.owned
    end))
    add(S.press("2"), S.scrub(30, true, true), S.expect_tutorial("forge_info"), S.press("2"), S.wait(5), S.shot("tutorial_forge_info"))
    add(S.check("brush is disabled once contamination is 0%", function()
        local input = StateManager.current():get_input()
        return input.tool == "none" and not input:button("brush"):is_enabled()
    end))
    add(next_button("(skip the +1 refine)"), S.expect_tutorial("stash"))
    add(S.button("stash"), S.expect_tutorial("place"), S.check("[auto-place] sends the sword to the first showcase cell", function()
        local relic = workshop().inventory:get("grid", 7)
        return relic ~= nil and relic.proto_id == "flame_sword" and workshop().appraisal:bench_item() == nil
    end), S.wait(5), S.shot("tutorial_place"))                                             -- 작업대 → [자동 배치] → 진열장 (2,2)
    add(next_button("three categories + hero gear"), S.expect_tutorial("night"), S.wait(5), S.shot("tutorial_night"))
    -- 밤 안내 ⑧~⑩: 읽는 동안 전투가 멈추고 [다음]을 누르면 이어진다
    local frozen_at = nil
    add(S.press("space"), S.expect_tutorial("night_grid"), S.wait(20), S.check("night tutorial pauses the battle", function()
        local combat = workshop().combat
        frozen_at = frozen_at or combat.elapsed
        return workshop().tutorial:is_pausing() and combat.elapsed == frozen_at
    end), S.wait(15), S.check("still paused while reading", function()
        return workshop().combat.elapsed == frozen_at
    end), S.shot("tutorial_night_grid"))
    add(next_button("night_lever"), S.expect_tutorial("night_lever"), S.wait(15), S.shot("tutorial_night_lever"))
    add(S.check("the lever hint states this contract's overclock rate and gold (no unfilled placeholders)", function()
        local function fmt(value)
            return "x" .. tostring(math.floor(value * 10 + 0.5) / 10)
        end
        local function token(text)      -- "x2.5" 가 "x2" 로도 잡히지 않게 뒤 글자까지 본다
            return text:gsub("%.", "%%.") .. "[^%d%.]"
        end
        local function states(w)        -- 연사 배율은 정확히 한 번, 그걸 뺀 나머지에 골드 배율 (같은 값이면 두 번)
            local hint, rules = w.tutorial:hint_text({ id = "night_lever" }), w.overclock_rules
            local rate, gold = fmt(rules.rate_mult), fmt(rules.gold_mult)
            local rest, hits = hint:gsub(token(rate), "")
            return not hint:find("{", 1, true) and hits == (rate == gold and 2 or 1)
                and (rate == gold or rest:find(token(gold)) ~= nil)
        end
        local broker = require("systems.Workshop")({ difficulty = "broker", tutorial = true })   -- 연사 x2.5 · 골드 x2
        local ok = states(workshop()) and states(broker) and not broker.tutorial:hint_text({ id = "night_lever" }):find("x1.4", 1, true)
        broker:destroy()
        return ok
    end))
    add(next_button("night_speed"), S.expect_tutorial("night_speed"), S.wait(15), S.shot("tutorial_night_speed"))
    add(next_button("defend"), S.expect_tutorial("defend"), S.wait(30), S.check("[Next] resumes the battle", function()
        return not workshop().tutorial:is_pausing() and workshop().combat.elapsed > frozen_at
    end), S.shot("tutorial_defend"))
    add(S.check("tutorial highlights the speed toggle at night", function()
        return StateManager.current():get_input():button("speed"):is_visible()
    end), S.press("tab"), S.wait(2), S.check("Tab switches the battle to 2x", function()
        return require("systems.Settings").get("night_speed") == 2
    end), S.press("tab"), S.press("tab"), S.wait(2), S.check("Tab cycles back to 1x", function()
        return require("systems.Settings").get("night_speed") == 1
    end))
    add(hover_monster_step(ctx, "tutorial_tooltip"))
    add(S.press("space"), S.expect_event("combat:overclock_changed"), S.check("Space toggles the overclock lever at night", function()
        return workshop().combat.overclock
    end), S.press("space"), S.expect_event("combat:overclock_changed"))
    add(S.speed(8), S.expect_event("tutorial:completed", env.night_timeout), S.speed(1))
    add(S.check("finishing the tutorial saves tutorial_done", function()
        return not ctx.last["tutorial:completed"].skipped and Progress.tutorial_done()
    end))
    return steps
end

-- [건너뛰기]도 즉시 tutorial_done 을 저장한다 (헤드리스). 끝나면 진행도를 처음 플레이 상태로 되돌린다 (시나리오 A 가 그 상태에서 시작)
function SmokeTutorialScenario.check_skip_saves(log)
    local Progress = require("systems.Progress")
    local RNG = require("core.RNG")
    local Workshop = require("systems.Workshop")
    Progress.use_memory_only()
    assert(not Progress.tutorial_done(), "SmokeTutorial: fresh progress must not have tutorial_done")
    RNG.set_seed(99)
    local w = Workshop({ difficulty = "apprentice", tutorial = true })
    w:begin()
    assert(w.tutorial:is_active(), "SmokeTutorial: the tutorial should start with the run")
    w.tutorial:skip()
    assert(Progress.tutorial_done() and not w.tutorial:is_active(), "SmokeTutorial: [Skip] must save tutorial_done at once")
    w:destroy()
    Progress.use_memory_only()
    log("tutorial skip saves tutorial_done ok")
end

return SmokeTutorialScenario
