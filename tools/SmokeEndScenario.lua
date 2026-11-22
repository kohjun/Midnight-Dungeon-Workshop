-- tools/SmokeEndScenario.lua
-- 스모크 시나리오 J (SmokeScenario 가 D 다음에 끼워 넣는다 — 타이틀 메뉴에서 시작해 타이틀로 끝난다):
--   타이틀 [유물 도감] → 특수 유물 칸 클릭 → ESC 닫기
--   → 견습 계약 → 상단 바 [도감] (열려 있는 동안 게임 정지 · 상권 독점 카드 위에 이번 계약의 기준) → ESC
--   → 골드 업적: data 의 고정 문턱(gold_held, Achievements.gold_line)에서 1 G 모자라면 그대로 → 채우면 대상인의 금장부 해금(토스트)
--   → 상권 독점 기준(마스터 장인 할인 반영)만큼 골드 · 방벽 가득 → 최종일 승리 강제 → 엔딩 연출(던전 상권 독점)
--   → Space 로 에필로그 펼치기 → Space 로 결과 화면(엔딩 헤드라인) → Space 타이틀
-- 금액은 적어 두지 않고 읽는다: 상권 독점 기준은 systems/Endings (계약 규모에 따라 다름), 골드 업적 문턱은 data/achievements.lua 의 고정 금액.
-- build(S, ctx) 는 평평한 스텝 목록을 반환한다.

local SmokeEndScenario = {}

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

local function current()
    return require("core.StateManager").current()
end

function SmokeEndScenario.build(S, ctx)
    local CompendiumModal = require("ui.CompendiumModal")
    local MetaProgression = require("systems.MetaProgression")
    local Endings = require("systems.Endings")
    local function workshop()
        return current():get_workshop()
    end
    local function tycoon_line()            -- 골드 업적 문턱 (data/achievements.lua — systems/Achievements.gold_line)
        return require("systems.Achievements").gold_line("tycoon", workshop())
    end
    return flat(
        -- 앞 시나리오(E · G 의 골드)에서 열린 업적을 지우고 처음 플레이 상태로 (골드 업적 해금 순간을 직접 본다)
        S.call("fresh meta progress for the collection run", function() MetaProgression.use_memory_only() end),
        -- 타이틀 메뉴의 유물 도감
        S.menu_item("compendium"), S.wait(12), S.check("title menu opens the compendium", function()
            local modal = current():get_modal()
            return modal ~= nil and modal.kind == "compendium" and modal:target_text() == nil
        end),
        S.click_rect(CompendiumModal.cell_rect(4, 9), "select a sealed special relic"), S.wait(6), S.cursor("hover"),
        S.shot("compendium_title"),
        S.press("escape"), S.wait(4), S.check("ESC closes the title compendium", function()
            return current():get_modal() == nil
        end),
        -- 인게임 상단 바의 도감: 열려 있는 동안 게임이 멈추고, 이번 계약의 상권 독점 기준을 보여 준다
        S.menu_item("start"), S.expect_state("DifficultyState"), S.difficulty_card(1), S.expect_state("IntroState"),
        S.press("escape"), S.expect_state("RunState"),
        S.button("compendium"), S.wait(10), S.check("top bar opens the compendium as a pausing overlay", function()
            local menu = current():get_menu()
            return menu ~= nil and menu.kind == "compendium"
        end), S.check("the in-run compendium shows this contract's monopoly line", function()
            local text = current():get_menu():target_text()
            return text ~= nil and text:find(tostring(Endings.status(workshop()).need), 1, true) ~= nil
        end), S.shot("compendium_run"),
        S.press("escape"), S.wait(4), S.check("ESC closes the in-game compendium", function()
            return current():get_menu() == nil
        end),
        -- 업적: 골드 문턱 → 대상인의 금장부 즉시 해금
        S.call("earn up to 1 G short of the tycoon line", function()
            local w = workshop()
            local amount = tycoon_line() - 1 - w.gold
            assert(amount > 0, "SmokeEndScenario: the tycoon line should be above the starting gold")
            w:add_gold(amount, "smoke")
        end), S.wait(5), S.check("1 G short of the tycoon line keeps the ledger sealed", function()
            return not MetaProgression.has_achievement("tycoon") and workshop().unlocked_relics.tycoon_ledger == nil
        end),
        S.call("earn the last 1 G of the tycoon line", function()
            workshop():add_gold(1, "smoke")
        end), S.wait(20), S.check("tycoon achievement unlocks the ledger for this run", function()
            return MetaProgression.has_achievement("tycoon") and workshop().unlocked_relics.tycoon_ledger == true
        end), S.shot("achievement_toast"),
        -- 승리 → 엔딩 연출 → 결과
        S.call("reach the monopoly line with a full wall and force a victory on the final day", function()
            local w = workshop()
            w:add_gold(math.max(0, Endings.status(w).need - w.gold), "smoke")
            w.hp = w.max_hp
            w.day = w.max_days
            w.result = "victory"
        end), S.expect_state("EndingState", 12), S.wait_seconds(3.2), S.check("the contract's monopoly line plays the monopoly ending",
            function()
                return current():get_ending() == "monopoly"
            end), S.shot("ending_monopoly"),
        S.press("space"), S.wait(20), S.shot("ending_lines"), S.press("space"), S.expect_state("GameOverState"),
        S.check("results carry the ending", function()
            local result = ctx.last["run:ended"]
            return result.reason == "victory" and result.ending == "monopoly" and result.ending_new == true
                and MetaProgression.has_ending("monopoly")
        end), S.wait(30), S.shot("gameover_ending"),
        S.press("space"), S.expect_state("TitleState")
    )
end

return SmokeEndScenario
