-- tools/SmokeScenario.lua
-- 입력 이벤트 주입 시나리오 (실제 플레이와 같은 콜백 경로):
--   A. 처음 플레이: 타이틀 "시작하려면 누르세요" → 클릭 → 세로 메뉴 → [시작하기] → (난이도 계약서 없이) wax_seal
--      → 인트로 4단계(촬영) → Space 건너뛰기 → lens_iris 전환 → 견습 + 튜토리얼 낮 공방
--   B. 튜토리얼 (tools/SmokeTutorialScenario.lua): UV(움직이기만 하면 꺼짐 → 홀드로 결함) → 3 매입 → 세척 → [다음](+1 제련 안내)
--      → [보관함으로] → 보관함 → 진열장 끌어 놓기 → [다음](길드·의뢰·연마석) → Space 밤 → Tab 배속 → 몬스터 툴팁 → 과부하 → 완료
--      → tutorial_done 저장 → ESC 시스템 메뉴 → [타이틀로 돌아가기]
--   A2. 튜토리얼을 마친 뒤 [시작하기] → 양피지 계약서 펼침([튜토리얼 다시 보기] 꺼짐) → 잠긴 악몽 카드 → ESC 뒤로
--      → 다시 [시작하기] → 빈 서명으로 견습 카드 거부 → 이름 입력 → F4·클릭으로 [튜토리얼 다시 보기] 켜기 → 견습 카드
--      → wax_seal 전환(입력 잠금) → 인트로 건너뛰기 → 튜토리얼이 다시 켜진 런 → [건너뛰기] → 타이틀
--   C. 브로커 고정 시드 본편: 보관함·진열장이 함께 보이는 낮 화면 → 손님(모험가 프로필) → UV 홀드 → 매입 → 보관함 → 세척
--      → [길드] 창 정화수 구매 → 진열장 배치 → 시너지 미리보기·툴팁 → 용광로(4, +1 골드 제련) → 밤 화면 → 과부하 → 다음 날
--   E. [공방 개조] 모달 → 진열장 확장 구매 → 닫기
--   F. 암시장 제안 → [의뢰] 배지 → [의뢰] 창(게임 정지) → [수락] → 봉인 상자 개봉 → 닫기 → [길드] 창 연마석 구매
--   G. 5일차 상납 성공 → 길드 보급 상점 → 주문서 구매 → [다음 날 시작]
--   H. 10일차 상납 미달 → 파산 → 결과 화면 RP 정산 → [영구 능력치 강화] 구매 → 같은 시드 재도전
--   I. 시스템 메뉴·환경 설정·언어 전환·밤 배속 (tools/SmokeMenuScenario.lua)
--   D. 계약서 서명 경로: 브로커 카드 → [계약 서명] 도장 → 본게임 → 결과 → 타이틀
--   J. 유물 도감(타이틀·상단 바) · 골드 업적 · 승리 → 엔딩 연출(상권 독점) → 결과 (tools/SmokeEndScenario.lua)
--   마지막: 오디오 재생 기록 · 번역 키 누락 없음 확인

local SmokeSteps = require("tools.SmokeSteps")
local SmokeMenuScenario = require("tools.SmokeMenuScenario")
local SmokeEndScenario = require("tools.SmokeEndScenario")
local SmokeDayNightScenario = require("tools.SmokeDayNightScenario")
local SmokeTutorialScenario = require("tools.SmokeTutorialScenario")
local GuildModal = require("ui.GuildModal")
local QuestModal = require("ui.QuestModal")

local SmokeScenario = {}

local SEED = 777
local NIGHT_TIMEOUT_SECONDS = 45     -- 실시간 (x8 빨리 감기로 밤 30초 ≈ 4초 + 남은 몬스터 소탕)
local FIRST_SHOT_TIMEOUT_SECONDS = 15
-- 시나리오가 끝났을 때 한 번 이상 재생되었어야 하는 소리 (묶음은 그중 하나)
local EXPECTED_SOUNDS = {
    { "ui_click" }, { "uv_hum" }, { "scrub" }, { "flaw_found" }, { "uv_defect_reveal" }, { "coin_buy" }, { "forge_charge" },
    { "intro_thunder" },
    { "forge_success", "forge_fail" }, { "shoot_bullet", "shoot_laser" }, { "monster_hit" }, { "overclock_on" },
    { "seal_stamp" }, { "iris_brass" }, { "shutter_slam" }, { "bolt_unlock" },
}

-- 시나리오가 기다리는 이벤트 (SmokeTest 가 구독해 횟수·마지막 payload 를 기록)
SmokeScenario.WATCHED_EVENTS = {
    "appraisal:customer_arrived", "appraisal:grade_revealed", "appraisal:scan_complete", "appraisal:flaw_revealed",
    "appraisal:item_bought", "appraisal:cleaned", "inventory:item_moved", "ui:tool_changed",
    "forge:started", "forge:resolved", "phase:night_started", "phase:day_started",
    "combat:overclock_changed", "combat:fired", "tutorial:step_changed", "tutorial:completed",
    "upgrades:purchased", "blackmarket:box_opened", "phase:shop_opened", "shop:purchased", "meta:upgraded",
    "run:started", "run:ended", "settings:changed", "i18n:language_changed", "quest:accepted", "economy:stones_changed",
    "dawn:summary_opened", "dawn:tallied",
}

function SmokeScenario.build(ctx)
    local StateManager = require("core.StateManager")
    local RNG = require("core.RNG")
    local Slots = require("ui.Slots")
    local LAYOUT = require("data.layout")
    local Modal = require("ui.Modal")
    local I18n = require("systems.I18n")
    local S, script, add = SmokeSteps.new(ctx)

    local function workshop()
        return StateManager.current():get_workshop()
    end

    local bench_x, bench_y = Slots.center("bench", 1)
    local hover_x, hover_y = Slots.center("grid", 13)

    -- A. 처음 플레이: 타이틀 → [시작하기] → 계약서 없이 인트로 → 견습 + 튜토리얼
    local Progress = require("systems.Progress")
    local TutorialView = require("ui.TutorialView")
    local function title()
        return StateManager.current()
    end
    local function advance_intro(id)  -- Space 를 눌러 가며 인트로가 그 장면에 들어설 때까지
        return { label = "advance the intro to " .. id, timeout = 40, run = function(frame)
            if StateManager.current_name() ~= "IntroState" then
                return false
            elseif StateManager.current():get_stage() == id then
                return true
            end
            if frame % 8 == 0 then
                love.event.push("keypressed", "space", "space", false)
            end
            return false
        end }
    end
    add(S.expect_state("TitleState"), S.wait(30), S.shot("title_press"))
    add(S.check("title starts on the press-start screen", function() return title():get_phase() == "press" end))
    add(S.click(300, 500, "click anywhere to open the menu"), S.wait(25), S.check("menu opened", function()
        return title():get_phase() == "menu"
    end), S.cursor("hover", 300, 500), S.shot("title_menu"))     -- (300, 500) 은 메뉴 항목 위: 호버 커서
    add(S.check("first run: no tutorial done yet and nothing to continue", function()
        return not Progress.tutorial_done() and title():menu_index("continue") == nil and title():menu_index("start") == 1
    end))
    add(S.menu_item("start"), S.wait_seconds(0.25), S.shot("first_run_seal"), { label = "first run skips the contract for the intro",
        timeout = 10, run = function()
            local name = StateManager.current_name()
            assert(name ~= "DifficultyState", "first run must not open the difficulty contract")
            return name == "IntroState"
        end })
    -- 인트로: 문장이 다 찍혀도 입력 전에는 다음으로 넘어가지 않는다 → Space 로 문장 완성 · 다음 비트 → 장면마다 촬영 → [건너뛰기]
    add(S.wait_seconds(6), S.check("the intro waits for input after the first line", function()
        local intro = StateManager.current()
        return intro:get_beat() == 1 and intro:get_stage() == "peace" and intro:is_waiting()
    end), S.shot("intro_peace"))
    add(S.press("space"), S.wait(3), S.check("Space moves to the next narration beat", function()
        return StateManager.current():get_beat() == 2
    end), S.press("space"), S.check("a press while typing completes the line first", function()
        return StateManager.current():get_beat() == 2
    end))
    for _, id in ipairs({ "storm", "defense", "vanish", "contract", "circuit", "vow" }) do
        add(advance_intro(id), S.wait_seconds(1.6), S.shot("intro_" .. id))
    end
    add(S.click_rect(require("data.layout").intro_skip, "intro: [Skip] (top right)"), S.wait_seconds(0.45),
        S.shot("transition_lens_iris"))
    add(S.expect_state("RunState"))

    -- B. 튜토리얼 9단계 전체 (tools/SmokeTutorialScenario.lua) → tutorial_done 저장
    add(SmokeTutorialScenario.build(S, ctx, { night_timeout = NIGHT_TIMEOUT_SECONDS }))
    local saved = {}
    add(S.call("remember the run before leaving", function()
        local w = workshop()
        local relic = w.inventory:get("grid", 7)         -- 튜토리얼의 화염 검: [자동 배치]로 진열장 첫 빈칸 (2,2)
        saved.day, saved.gold, saved.relic = w.day, w.gold, relic and relic.proto_id
    end))
    add(SmokeMenuScenario.leave_to_title(S, "pause_menu"))

    -- A1. [타이틀로 돌아가기] = 저장 → 맨 위 [이어하기] · 그 아래 [새 게임] → [이어하기]로 같은 날 · 골드 · 진열장 복귀
    add(S.wait(10), S.check("title shows [Continue] above [New Game]", function()
        return title():menu_index("continue") == 1 and title():menu_index("start") == 2
    end), S.shot("title_continue"))
    add(S.menu_item("continue"), S.expect_state("RunState"), S.check("[Continue] restores the day, gold and showcase", function()
        local w = workshop()
        local relic = w.inventory:get("grid", 7)
        return w.day == saved.day and w.gold == saved.gold and saved.relic ~= nil and (relic and relic.proto_id) == saved.relic
            and w.phase == "day"
    end), S.wait(20), S.shot("continued_run"))
    add(SmokeMenuScenario.leave_to_title(S, "pause_menu_saved"))

    -- A2. 튜토리얼을 마친 뒤의 [시작하기] → 난이도 계약서 ([튜토리얼 다시 보기] 토글은 기본 꺼짐)
    add(S.menu_item("start"), S.expect_state("DifficultyState"), S.wait_seconds(0.4), S.shot("contract_unroll"))
    add(S.check("[Replay tutorial] starts OFF on the contract", function() return not title():is_replay_on() end))
    add(S.wait_seconds(0.9), S.shot("difficulty"))
    add(S.difficulty_card(4), S.wait(10), S.expect_state("DifficultyState"), S.cursor("default"), S.shot("difficulty_locked"))   -- 악몽은 베테랑 클리어 전까지 잠겨 있다 (호버 커서 없음)
    add(S.difficulty_card(5), S.wait(6), S.check("the ??? contract stays sealed and only shows its notice", function()
        return StateManager.current_name() == "DifficultyState" and title():get_chosen() == nil
            and title():get_notice() == require("systems.I18n").t("title.sealed_notice")
    end), S.shot("difficulty_sealed"))
    add(S.press("escape"), S.expect_state("TitleState"), S.wait(5), S.check("back lands on the title menu", function()
        return title():get_phase() == "menu"
    end))
    add(S.menu_item("start"), S.expect_state("DifficultyState"), S.wait_seconds(1.0), S.hover_card(2), S.cursor("hover"))
    add(S.difficulty_card(1), S.wait(10), S.check("an empty signature refuses the contract", function()
        return StateManager.current_name() == "DifficultyState" and title():get_chosen() == nil
    end), S.shot("contract_unsigned"))
    add(S.type_text("견습생"), S.wait(5), S.press("f6"), S.wait(3), S.check("F6 turns [Replay tutorial] on", function()
        return title():is_replay_on()
    end), S.click_rect(LAYOUT.difficulty.replay, "click [Replay tutorial] off"), S.wait(3), S.check("click turns it off", function()
        return not title():is_replay_on()
    end), S.click_rect(LAYOUT.difficulty.replay, "click [Replay tutorial] on"), S.wait(5), S.shot("contract_replay"))
    add(S.difficulty_card(1), S.call("mash ESC and [back] during the wax seal", function()
        local back = LAYOUT.difficulty.back
        love.event.push("keypressed", "escape", "escape", false)
        love.event.push("mousepressed", back.x + 20, back.y + 20, 1, false, 1)
    end), S.wait(4), S.check("input is locked while the transition plays", function()
        return StateManager.current_name() == "DifficultyState" and require("ui.TransitionManager").mode() == "wax_seal"
    end), S.wait_seconds(0.2), S.shot("transition_wax_seal"))
    add(S.wait_seconds(0.55), S.shot("transition_wax_ink"))
    add(S.expect_state("IntroState"), S.wait_seconds(0.5), S.press("escape"), S.expect_state("RunState"))
    add(S.expect_tutorial("hud_status"), S.check("[Replay tutorial] restarts the tutorial on the signed run", function()
        local w = workshop()
        return w.difficulty_id == "apprentice" and w.tutorial:is_active() and w.owner_name == "견습생"
    end), S.wait(5), S.click_at("tutorial: [Skip]", function() return StateManager.current():get_tutorial_view():skip_rect() end),
        S.expect_event("tutorial:completed"))
    add(S.check("[Skip] ends the replay and tutorial_done stays saved", function()
        return ctx.last["tutorial:completed"].skipped and not workshop().tutorial:is_active() and Progress.tutorial_done()
    end))
    add(SmokeMenuScenario.leave_to_title(S, "pause_menu_replay"))

    -- C. 브로커 고정 시드 본편: 낮 보관함·진열장·[길드] → 밤 화면 (tools/SmokeDayNightScenario.lua)
    add(SmokeDayNightScenario.build(S, ctx, { seed = SEED, night_timeout = NIGHT_TIMEOUT_SECONDS,
        first_shot_timeout = FIRST_SHOT_TIMEOUT_SECONDS }))

    -- E. 공방 개조
    add(S.call("grant test gold", function() workshop().gold = 4000 end))
    add(S.button("upgrades"), S.wait(10), S.check("upgrade modal open", function()
        local modal = StateManager.current():get_modal()
        return modal ~= nil and modal.kind == "upgrades"
    end), S.shot("workshop_upgrade"))
    add(S.click_rect(Modal.row_button_rect(1), "buy grid expansion"), S.expect_event("upgrades:purchased"))
    add(S.check("grid expanded to 3x4", function() return workshop().upgrades:grid_stage() == 2 end))
    add(S.press("escape"), S.wait(3), S.check("ESC closes the open modal first (no system menu)", function()
        return StateManager.current():get_modal() == nil and StateManager.current():get_menu() == nil
    end), S.wait(5), S.shot("grid_expanded"))

    -- F. [의뢰] 창: 암시장 제안(강제로 띄운다) 수락 → 봉인 상자 개봉 / [길드] 창: 연마석 구매
    local function menu_kind()
        local menu = StateManager.current():get_menu()
        return menu and menu.kind
    end
    add(S.call("force black market offer", function()
        workshop().black_market:start_event("mystery_boxes")
    end), S.wait(10), S.check("the [Quests] badge counts the offer", function()
        return StateManager.current():get_input():button("quests")._opts.badge() >= 1
    end), S.shot("quest_badge"))
    add(S.button("quests"), S.wait(15), S.check("[Quests] opens as a pausing window", function()
        return menu_kind() == "quests"
    end), S.shot("quest_board"))
    add(S.click_rect(QuestModal.accept_rect(), "accept the black market offer"), S.expect_event("quest:accepted"))
    add(S.click_rect(QuestModal.box_rect(1), "open mystery box"), S.expect_event("blackmarket:box_opened"), S.wait(10),
        S.shot("quest_boxes"))
    add(S.click_rect(QuestModal.close_rect(), "close the quest board"), S.wait(5))
    add(S.button("guild"), S.wait(15), S.check("[Guild] opens as a pausing window", function()
        return menu_kind() == "guild"
    end), S.shot("guild_window"))
    add(S.click_rect(GuildModal.buy_rect(4), "buy a tempering stone"), S.expect_event("economy:stones_changed"),
        S.check("the guild sells tempering stones", function() return workshop().tempering_stones >= 1 end))
    add(S.press("escape"), S.wait(5), S.check("ESC closes the guild window", function() return menu_kind() == nil end))

    -- G. 1개월차 말일(10일) 결계 유지비 납부 → 길드 보급 상점
    add(S.call("jump to the month-end (day 10) with gold", function()
        local w = workshop()                    -- 결계 유지비 흐름만 본다 (방벽은 넉넉히 — 중후반 몬스터 위협과 무관하게)
        w.day, w.gold, w.max_hp, w.hp = 10, 3000, 100000, 100000
    end), S.wait(5), S.shot("tribute_warning"))
    add(S.button("start_night"), S.expect_event("phase:night_started"))
    add(S.speed(8), S.expect_event("phase:shop_opened", NIGHT_TIMEOUT_SECONDS), S.speed(1), S.wait(20), S.shot("guild_shop"))
    add(S.click_rect(Modal.row_button_rect(5), "buy appraisal scroll"), S.expect_event("shop:purchased"))
    add(S.click_rect(Modal.footer_rect(1, 1), "start next day"), S.expect_event("phase:day_started"))
    add(S.check("day 11 (month 2) after the shop", function() return workshop().day == 11 and workshop().scrolls == 1 end))

    -- H. 2개월차 말일(20일) 결계 유지비 미달 → 파산 → RP 정산 → 영구 강화
    add(S.call("jump to day 20 broke", function()
        local w = workshop()                    -- 밤은 버티고 새벽 결계 유지비에서 파산해야 한다 (방벽 패배 X)
        w.day, w.gold, w.max_hp, w.hp = 20, 0, 100000, 100000
    end), S.button("start_night"), S.expect_event("phase:night_started"))
    add(S.speed(8), S.expect_state("GameOverState", NIGHT_TIMEOUT_SECONDS), S.speed(1))
    add(S.check("bankrupt with RP", function()
        local result = ctx.last["run:ended"]
        return result.reason == "bankrupt" and result.rp.total > 0
    end), S.wait(30), S.shot("gameover"))
    add(S.click_rect(LAYOUT.gameover.meta_button, "open meta upgrades"), S.wait(10), S.shot("meta_modal"))
    add(S.click_rect(Modal.row_button_rect(1), "buy start capital"), S.expect_event("meta:upgraded"))
    add(S.click_rect(Modal.footer_rect(1, 1), "close meta modal"), S.wait(5))
    add(S.press("r"), S.expect_state("RunState"), S.check("retry keeps seed and difficulty", function()
        return RNG.get_seed() == SEED and workshop().difficulty_id == "broker" and workshop().gold == 220
    end))

    -- I. 시스템 메뉴 · 환경 설정 · 언어 전환 · 밤 배속 (끝나면 타이틀, 한국어·기본 설정으로 복귀)
    add(SmokeMenuScenario.build(S, ctx))

    -- D. 계약서 서명 경로: 빈 이름 거부 → 이름 입력(백스페이스 포함) → 도장 → 본게임에서 이름 사용
    --    (튜토리얼은 이미 끝났으므로 꺼져 있어야 한다)
    add(S.menu_item("start"), S.expect_state("DifficultyState"), S.wait_seconds(1.0), S.check("signature is prefilled with the saved name",
        function() return title():get_name_text() == "견습생" end))
    add(S.press("backspace"), S.press("backspace"), S.press("backspace"), S.press("backspace"), S.wait(5))
    add(S.difficulty_card(2), S.wait(10), S.check("an erased signature refuses the contract", function()
        return StateManager.current_name() == "DifficultyState" and title():get_chosen() == nil
    end))
    add(S.type_text("모험왕X"), S.press("backspace"), S.wait(10), S.shot("contract_name"))
    add(S.difficulty_card(2), S.wait_seconds(0.25), S.shot("contract_signed"))
    add(S.expect_state("IntroState"), S.press("escape"))
    add(S.expect_state("RunState"), S.check("signed broker run uses the typed name", function()
        local w = workshop()
        local Progress = require("systems.Progress")
        return w.difficulty_id == "broker" and w.tutorial == nil and w.owner_name == "모험왕"
            and Progress.player_name() == "모험왕"
    end), S.button("new_customer"), S.wait(15), S.shot("broker_hud"))
    add(S.call("force a defeat (wall destroyed)", function()
        workshop():damage_hp(9999, "smoke")
    end), S.expect_state("GameOverState", 10), S.wait(30), S.shot("gameover_named"))
    add(S.press("space"), S.expect_state("TitleState"), S.wait(20), S.shot("title_returning"))

    -- J. 유물 도감(타이틀·인게임) · 업적 해금 · 승리 → 엔딩 연출 → 결과 (tools/SmokeEndScenario.lua)
    add(SmokeEndScenario.build(S, ctx))

    -- 마무리: 소리가 실제로 재생되었고, 화면에 번역 키가 그대로 노출된 적이 없어야 한다
    add(S.check("every sound group was played during the scenario", function()
        if ctx.missing_assets then
            return true     -- 소리 파일 없이 끝까지 통과했는지만 본다
        end
        local played = require("systems.Audio").stats().played
        for _, group in ipairs(EXPECTED_SOUNDS) do
            local count = 0
            for _, name in ipairs(group) do
                count = count + (played[name] or 0)
            end
            assert(count > 0, "sound never played: " .. table.concat(group, " / "))
        end
        return true
    end), S.check("no missing text keys were looked up", function()
        local missing = I18n.missing_lookups()
        assert(#missing == 0, "missing text keys: " .. table.concat(missing, ", "))
        return true
    end))
    return script
end

return SmokeScenario
