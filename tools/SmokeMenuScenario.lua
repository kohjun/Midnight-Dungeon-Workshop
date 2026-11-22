-- tools/SmokeMenuScenario.lua
-- 스모크 시나리오 I (SmokeScenario 가 끼워 넣는다): 시스템 메뉴 · 환경 설정 · 언어 전환 · 밤 배속.
--   ESC → 시스템 메뉴(일시 정지) → [처음부터 다시하기] 1단계 확인 → 취소 → 다시 → [다시 시작] 2단계로 재시작
--   ESC → [환경 설정] → English (재시작 없이 즉시 반영) · 마스터 볼륨 · 흔들림 50% · 밤 배속 1.5x → 돌아가기 → ESC 계속
--   영어 HUD 확인 → 밤 시작 → 전투 시간이 1.5배로 흐르는지 측정 → 메뉴가 열리면 시간이 멈추는지 → [타이틀로 돌아가기]
--   타이틀 [환경 설정]에서 한국어·기본값으로 되돌린다
-- build(S, ctx) / leave_to_title(S, shot) 은 평평한 스텝 목록을 반환한다.

local SmokeMenuScenario = {}

local SPEED_SAMPLE_FRAMES = 40
local SPEED_TOLERANCE = 0.1

local function flat(...)
    local steps = {}
    for _, entry in ipairs({ ... }) do
        if entry.run ~= nil then
            steps[#steps + 1] = entry
        else
            for _, nested in ipairs(entry) do
                steps[#steps + 1] = nested
            end
        end
    end
    return steps
end

local function run_state()
    return require("core.StateManager").current()
end

-- ESC → 시스템 메뉴 → [타이틀로 돌아가기]
function SmokeMenuScenario.leave_to_title(S, shot)
    local Modal = require("ui.Modal")
    return flat(S.press("escape"), S.wait(8), S.check("ESC opens the system menu", function()
        local menu = run_state():get_menu()
        return menu ~= nil and menu.kind == "menu"
    end), S.shot(shot), S.click_rect(Modal.row_button_rect(4), "menu: return to title"), S.expect_state("TitleState"))
end

-- 밤 전투 시간이 실제 시간의 expected 배로 흐르는지 SPEED_SAMPLE_FRAMES 프레임 동안 측정 (히트스톱으로 멈춘 시간은 뺀다)
local function measure_night_speed(expected)
    local start, real, frozen = nil, 0, 0
    return {
        label = string.format("measure night speed x%.1f", expected),
        run = function(frame)
            local combat = run_state():get_workshop().combat
            local hitstop = run_state():get_hitstop()
            if frame == 1 then
                start, real, frozen = combat.elapsed, 0, hitstop.total_frozen
                return false
            end
            real = real + love.timer.getDelta()
            if frame < SPEED_SAMPLE_FRAMES then
                return false
            end
            local ratio = (combat.elapsed - start) / (real - (hitstop.total_frozen - frozen))
            assert(math.abs(ratio - expected) < SPEED_TOLERANCE,
                string.format("night speed should be x%.1f, measured x%.2f", expected, ratio))
            return true
        end,
    }
end

-- 시스템 메뉴가 열려 있는 동안 전투 시간이 멈춰 있는지
local function expect_paused()
    local start = nil
    return {
        label = "check the system menu pauses the night",
        run = function(frame)
            local state = run_state()
            local combat = state:get_workshop().combat
            if frame == 1 then
                start = combat.elapsed
                return false
            end
            if frame < 12 then
                return false
            end
            assert(state:get_menu() ~= nil and combat.elapsed == start, "combat must not advance while the system menu is open")
            return true
        end,
    }
end

function SmokeMenuScenario.build(S, ctx)
    local Modal = require("ui.Modal")
    local SettingsModal = require("ui.SettingsModal")
    local Settings = require("systems.Settings")
    local I18n = require("systems.I18n")
    local LAYOUT = require("data.layout")
    local function workshop()
        return run_state():get_workshop()
    end
    local function menu()
        return run_state():get_menu()
    end

    return flat(
        -- 처음부터 다시하기: 2단계 확인
        S.press("escape"), S.wait(8), S.check("system menu open", function() return menu() ~= nil end),
        S.click_rect(Modal.row_button_rect(3), "menu: restart (step 1)"), S.wait(5),
        S.check("restart asks for confirmation before doing anything", function()
            return menu() ~= nil and menu():is_confirming() and (ctx.events["run:started"] or 0) == 0
        end), S.shot("pause_confirm"),
        S.click_rect(Modal.footer_rect(2, 2), "menu: cancel restart"), S.wait(5),
        S.check("cancel returns to the menu", function() return menu() ~= nil and not menu():is_confirming() end),
        S.click_rect(Modal.row_button_rect(3), "menu: restart again"), S.wait(5),
        S.click_rect(Modal.footer_rect(1, 2), "menu: confirm restart (step 2)"), S.expect_event("run:started"),
        S.check("restarted from day 1 on the same difficulty", function()
            local w = workshop()
            return w.day == 1 and w.difficulty_id == "broker" and w.gold == 220 and menu() == nil
                and ctx.last["run:ended"].reason == "abandoned"
        end),

        -- 환경 설정: 언어 전환은 재시작 없이 즉시 반영
        S.press("escape"), S.wait(8), S.click_rect(Modal.row_button_rect(2), "menu: open settings"), S.wait(8),
        S.check("settings modal open", function() return menu() ~= nil and menu():settings_modal() ~= nil end), S.shot("settings_ko"),
        S.click_rect(SettingsModal.option_rect("language", 2), "settings: English"), S.expect_event("i18n:language_changed"),
        S.wait(5), S.check("English applied live", function()
            return I18n.language() == "en" and I18n.t("buttons.buy") == "Buy" and run_state():get_workshop() ~= nil
        end), S.shot("settings_en"),
        S.click_rect(SettingsModal.step_rect("master_volume", -1), "settings: master volume down"),
        S.expect_event("settings:changed"),
        S.click_rect(SettingsModal.option_rect("shake", 2), "settings: shake 50%"),
        S.click_rect(SettingsModal.option_rect("night_speed", 2), "settings: night speed 2x"), S.wait(3),
        S.check("volume, shake and night speed changed", function()
            return Settings.get("master_volume") == 70 and Settings.get("shake") == 0.5 and Settings.get("night_speed") == 2
        end),
        S.click_rect(SettingsModal.back_rect(), "settings: back"), S.wait(5),
        S.check("back returns to the system menu", function() return menu() ~= nil and menu():settings_modal() == nil end),
        S.shot("pause_menu_en"),
        S.press("escape"), S.wait(5), S.check("ESC resumes the game", function() return menu() == nil end),

        -- 영어 HUD · 밤 배속 · 일시 정지
        S.button("new_customer"), S.expect_event("appraisal:customer_arrived"), S.wait_seconds(0.9), S.shot("hud_en"),
        S.call("stock a weapon for the night", function()
            local item = require("entities.Item")("lightning_orb", { grade = "rare" })
            item.owned = true
            workshop().inventory:place(item, "grid", 13)
        end),
        S.button("start_night"), S.expect_event("phase:night_started"), S.wait(5),
        measure_night_speed(2), S.shot("night_en"),
        S.press("tab"), S.wait(2), S.check("Tab cycles the night speed to 3x (>>>)", function()
            return Settings.get("night_speed") == 3 and run_state():get_input():button("speed"):label_text() == ">>>"
        end), measure_night_speed(3), S.shot("night_speed3"),
        S.press("escape"), S.wait(3), expect_paused(), S.shot("pause_night_en"),
        S.click_rect(Modal.row_button_rect(4), "menu: return to title"), S.expect_state("TitleState"),
        S.check("leaving saves the run for [Continue]", function() return require("systems.RunSave").exists() end),
        S.wait(20), S.shot("title_en"),

        -- 타이틀의 [환경 설정]에서 한국어·기본값으로 복귀
        S.menu_item("settings"), S.wait(8),
        S.click_rect(SettingsModal.option_rect("language", 1), "settings: Korean"), S.expect_event("i18n:language_changed"),
        S.click_rect(SettingsModal.option_rect("shake", 1), "settings: shake 100%"),
        S.click_rect(SettingsModal.option_rect("night_speed", 1), "settings: night speed 1x"),
        S.click_rect(SettingsModal.step_rect("master_volume", 1), "settings: master volume up"), S.wait(5),
        S.shot("title_settings"),
        S.click_rect(SettingsModal.back_rect(), "settings: back"), S.wait(5),
        S.check("Korean and default settings restored", function()
            return I18n.language() == "ko" and I18n.t("buttons.buy") == "매입하기" and Settings.get("shake") == 1
                and Settings.get("night_speed") == 1 and Settings.get("master_volume") == 80
        end)
    )
end

return SmokeMenuScenario
