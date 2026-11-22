-- tools/SmokeDayNightScenario.lua
-- 스모크 시나리오 C (SmokeScenario 가 B 다음에 끼워 넣는다): 브로커 고정 시드 본편 — 낮/밤 화면 분리 검증.
--   낮: 주인공 장비창·거치대·진열장이 탭 없이 함께 보이고 과부하 레버는 없다 → 손님(모험가 프로필) → UV 홀드 → 매입(자동 배치: 진열장 첫 빈칸) → 작업대 세척
--   → [길드] 창에서 정화수 구매 → 진열장 배치 → 툴팁 → 용광로(4, +1 골드 제련) → 무기 직접 배치 → [영업 마감] shutter_slam
--   → 밤 화면(작업대 숨김, 레버 보임) → 무기는 자기 칸 정중앙에서 발사 → 과부하 → dawn_candle → 다음 날
-- 커스텀 커서: UV 감정 중 작업대 = appraise · 진열 유물 위 = grab · 셔터 전환 중 = default
-- build(S, ctx, env) 는 평평한 스텝 목록을 반환한다. env = { seed, night_timeout, first_shot_timeout }

local SmokeDayNightScenario = {}

function SmokeDayNightScenario.build(S, ctx, env)
    local StateManager = require("core.StateManager")
    local RNG = require("core.RNG")
    local Slots = require("ui.Slots")
    local GuildModal = require("ui.GuildModal")
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
    local hover_x, hover_y = Slots.center("grid", 13, "day")

    -- C. 브로커 고정 시드 본편 (튜토리얼 없음)
    add(S.call("start broker run with fixed seed", function()
        StateManager.switch("RunState", { seed = env.seed, difficulty = "broker" })
    end), S.wait(2), S.check("seed and difficulty applied", function()
        return RNG.get_seed() == env.seed and workshop().difficulty_id == "broker" and workshop().tutorial == nil
    end))
    add(S.check("day screen shows hero gear, spare rack and showcase together, no lever", function()
        local input = StateManager.current():get_input()
        return Slots.mode() == "day" and Slots.is_visible("storage") and Slots.is_visible("hero") and Slots.is_visible("grid")
            and not input:button("overclock"):is_visible()
    end), S.button("new_customer"), S.expect_event("appraisal:customer_arrived"), S.check("customers are named adventurers",
        function() return workshop().appraisal:bench_item().adventurer ~= nil end), S.wait(5), S.shot("day_layout"))
    add(S.call("this walkthrough needs a showcase relic: swap an armor guest's item for a weapon", function()
        local w = workshop()                         -- 방어구(20%)가 나오면 아래의 진열장 배치 흐름을 탈 수 없다
        local item = w.appraisal:bench_item()
        if item:is_armor() then
            w.inventory:remove(item)
            w.inventory:place(require("entities.Item")("frost_crossbow", { grade = "rare", claimed_grade = "rare", contamination = 45,
                grime = { { x = 0.05, y = -0.1, r = 0.15 }, { x = -0.12, y = 0.2, r = 0.12 } }, adventurer = item.adventurer,
                ask_mult = item.ask_mult }), "bench", 1)
        end
    end))
    add(S.wait_seconds(0.8), S.check("door bell first, then the adventurer's voice once the portrait settles", function()
        local voice, played = require("systems.VoiceOver").stats(), require("systems.Audio").stats().played
        local id = workshop().appraisal:bench_item().adventurer
        assert(voice.last ~= nil and voice.last:find(id .. "_greet_", 1, true) == 1, "the greeting voice belongs to the guest")
        if ctx.missing_assets then
            return voice.requested > 0           -- 파일이 없으면 조용히 건너뛴다
        end
        return (played.shop_door_bell or 0) > 0 and voice.played > 0
    end))
    local B, HUD = require("data.layout").buttons, require("data.layout").hud
    local function hover(id, x, y, shot)
        return { label = "hover tooltip " .. id, timeout = 10, run = function()
            love.event.push("mousemoved", x, y, 0, 0, false)
            local seen = StateManager.current():get_hover():visible_id() == id
            if seen and shot and ctx.shots then
                love.graphics.captureScreenshot("smoke_" .. shot .. ".png")
            end
            return seen
        end }
    end
    add(hover("gold", HUD.purse.x + 30, HUD.purse.y + 20), hover("tribute", HUD.tribute.x + 40, HUD.tribute.y + 20, "hover_tribute"))
    add(hover("settings", B.settings.x + 30, B.settings.y + 20, "hover_settings"), S.check("the settings tooltip mentions the night pause",
        function() return require("systems.I18n").t("hover.settings.pause") ~= "" end))
    add(hover("uv", B.uv.x + 50, B.uv.y + 60, "hover_uv"), hover("furnace", require("data.layout").day.furnace_info.x + 40, require("data.layout").day.furnace_info.y + 10,
        "hover_furnace"))
    add(S.button("uv"), S.expect_event("ui:tool_changed"))
    add(S.sweep_bench(true), S.expect_event("appraisal:grade_revealed"), S.expect_event("appraisal:scan_complete"))
    add(S.move(bench_x + 20, bench_y - 10), S.wait(3), S.cursor("appraise", bench_x + 20, bench_y - 10), S.shot("uv_scan"), S.release(bench_x + 20, bench_y - 10))
    add(S.button("uv"), S.button("buy"), S.expect_event("appraisal:item_bought"), S.wait_seconds(0.6),
        S.check("the guest leaves with footsteps after the sale", function()
            return ctx.missing_assets or (require("systems.Audio").stats().played.guest_footsteps_out or 0) > 0
        end))
    add(S.check("the purchase was auto-placed on the first free showcase cell", function()
        local bought = ctx.last["appraisal:item_bought"]
        return bought.area == "grid" and bought.index == 7 and workshop().inventory:get("grid", 7) == bought.item
    end))
    add(S.drag("grid", 7, "bench", 1), S.expect_event("inventory:item_moved"))       -- 세척하려고 작업대로 다시
    add(S.button("brush"), S.expect_event("ui:tool_changed"))
    add(S.scrub(5, true, false), S.shot("scrub"), S.scrub(25, false, true), S.expect_event("appraisal:cleaned"))
    add(S.button("brush"))
    add(S.check("cleaning used purified water", function() return workshop().supplies.water < 100 end))
    add(S.button("guild"), S.wait(12), S.click_rect(GuildModal.buy_rect(1), "guild: buy water"), S.expect_event("shop:purchased"),
        S.check("the guild window sells water by day", function()
            return ctx.last["shop:purchased"].id == "water_barrel"
        end), S.shot("day_shop"), S.press("escape"), S.wait(5))
    add(S.drag("bench", 1, "grid", 13), S.expect_event("inventory:item_moved"))
    add(S.move(hover_x, hover_y), S.wait(3), S.cursor("grab", hover_x, hover_y), S.shot("tooltip"))       -- 진열 유물 위: 펼친 장갑
    add(S.drag("grid", 13, "furnace", 1), S.expect_event("inventory:item_moved"))
    add(S.call("ensure gold for the +1 refine", function() workshop().gold = math.max(workshop().gold, 200) end))
    add(S.press("4"), S.expect_event("forge:started"), S.wait(25), S.shot("forge_charge"))   -- 단축키 4: 용광로 +1 골드 제련
    add(S.expect_event("forge:resolved"), S.wait(8), S.shot("forge_result"))
    local return_to_grid = S.drag("furnace", 1, "grid", 13)
    add(S.skip_unless("forged item survived", function()
        return ctx.last["forge:resolved"].success
    end, #return_to_grid + 1))
    add(return_to_grid, S.expect_event("inventory:item_moved"))

    -- 전투 연출 커버리지: 무기·증폭기를 직접 배치 (시드에 따라 무기가 없을 수 있으므로)
    add(S.call("stock grid with weapon + amplifier", function()
        local Item = require("entities.Item")
        for id, index in pairs({ lightning_orb = 18, mana_crystal = 17, frost_crossbow = 14 }) do  -- 12 = 시작 지급 화염 검
            local item = Item(id, { grade = "rare" })
            item.owned = true
            workshop().inventory:place(item, "grid", index)
        end
    end), S.wait(10), S.shot("synergy"))

    add(S.button("start_night"), S.wait_seconds(0.62), S.cursor("default"), S.shot("transition_shutter"),   -- 전환 중: 기본 커서
        S.expect_event("phase:night_started"))
    add(S.check("night screen hides the workbench", function()
        local input = StateManager.current():get_input()
        return require("ui.Slots").mode() == "night" and not input:button("new_customer"):is_visible()
            and not input:button("forge"):is_visible() and input:button("overclock"):is_visible()
    end))
    add(S.move(900, 200), S.expect_event("combat:fired", env.first_shot_timeout), S.check("weapons fire from their cell centers",
        function()
            local fired = ctx.last["combat:fired"]
            local index = select(2, workshop().inventory:locate(fired.item))
            local cx, cy = require("systems.Grid").cell_center(index)
            return math.abs(fired.x - cx) < 0.5 and math.abs(fired.y - cy) < 0.5
        end), S.wait(30), S.shot("night"))
    add(S.button("overclock"), S.expect_event("combat:overclock_changed"), S.wait(90), S.shot("overclock"))
    local DawnSummary = require("ui.DawnSummary")
    local paused_at = nil
    add(S.call("manual dawn summary", function() DawnSummary.set_auto_confirm(nil) end), S.speed(8),
        S.expect_event("dawn:summary_opened", env.night_timeout), S.speed(1), S.wait_seconds(0.4), S.shot("dawn_summary"))
    add(S.check("the summary pauses the battle and holds the HUD gold", function()
        local state = StateManager.current()
        local combat = state:get_workshop().combat
        paused_at = paused_at or combat.elapsed
        local shown = state:get_hud():shown(state:get_workshop())
        return state:get_dawn().state == "open" and combat.elapsed == paused_at and shown <= state:get_workshop().gold
    end), S.wait(10), S.check("still paused", function()
        return StateManager.current():get_workshop().combat.elapsed == paused_at
    end))
    add(S.click_rect(DawnSummary.button_rect(), "dawn: [Open Shop Next Day]"), S.expect_event("dawn:tallied"), S.wait_seconds(0.35),
        S.check("the HUD counts the night's earnings up with a glow", function()
            local state = StateManager.current()
            return select(3, state:get_hud():shown(state:get_workshop())) > 0
        end), S.shot("dawn_tally"))
    add(S.expect_event("phase:day_started", env.night_timeout), S.call("auto dawn summary", function()
        DawnSummary.set_auto_confirm(0.4)
    end), S.wait_seconds(0.25), S.shot("transition_dawn_bolt"), S.wait_seconds(0.55), S.shot("transition_dawn_lift"))
    add(S.check("advanced to day 2", function()
        return ctx.last["phase:day_started"].day == 2
    end), S.wait(20), S.shot("day2"))
    return steps
end

return SmokeDayNightScenario
