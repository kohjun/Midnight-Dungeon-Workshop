-- states/RunState.lua
-- 심야 던전 공방 인게임 상태: Workshop(규칙)·뷰·입력·연출·창(ui/RunOverlays)을 생성하고 LÖVE 콜백을 연결한다.
-- 게임 모달(길드 상점·공방 개조·암시장)과 시스템 메뉴([설정] 버튼 / ESC)는 RunOverlays 가 관리한다.
-- 시스템 메뉴가 열려 있는 동안 게임은 일시 정지된다. 밤 전투는 환경 설정의 배속(1.0x / 1.5x)으로 진행한다.
-- 승패(클리어·파산·붕괴)가 정해지면 잠시 연출 후 장인 명성(RP)을 정산하고 GameOverState 로 전환한다.
-- 시스템 메뉴의 [처음부터 다시하기] / [타이틀로 돌아가기]도 런을 "abandoned" 로 정산한 뒤 전환한다.

local Class = require("lib.classic")
local EventBus = require("core.EventBus")
local RNG = require("core.RNG")
local StateManager = require("core.StateManager")
local Viewport = require("core.Viewport")
local Audio = require("systems.Audio")
local I18n = require("systems.I18n")
local Settings = require("systems.Settings")
local FixedStep = require("core.FixedStep")
local HitStop = require("ui.HitStop")
local RunAudio = require("ui.RunAudio")
local Workshop = require("systems.Workshop")
local Progress = require("systems.Progress")
local RunSave = require("systems.RunSave")
local MetaProgression = require("systems.MetaProgression")
local Endings = require("systems.Endings")
local Effects = require("ui.Effects")
local Feedback = require("ui.Feedback")
local Hud = require("ui.Hud")
local WorkshopInput = require("ui.WorkshopInput")
local DayLayoutView = require("ui.DayLayoutView")
local NightLayoutView = require("ui.NightLayoutView")
local AttackEffects = require("ui.AttackEffects")
local EntityMotion = require("ui.EntityMotion")
local AmbientEffects = require("ui.AmbientEffects")
local Slots = require("ui.Slots")
local Tooltip = require("ui.Tooltip")
local TutorialView = require("ui.TutorialView")
local HoverTooltip = require("ui.HoverTooltip")
local DawnSummary = require("ui.DawnSummary")
local RunOverlays = require("ui.RunOverlays")
local SpriteBank = require("ui.SpriteBank")
local WorkshopCursor = require("ui.WorkshopCursor")
local Draw = require("ui.Draw")
local RoomBackdrop = require("ui.RoomBackdrop")
local UI = require("data.ui")

local RunState = Class:extend()

local RESULT_BANNERS = {
    victory = { key = "run.victory", color = UI.color.gold },
    defeat = { key = "run.defeat", color = UI.color.danger },
    bankrupt = { key = "run.bankrupt", color = UI.color.danger },
}
local BANNER_Y = 320

-- params: { seed?, difficulty?, tutorial?, name? } — 같은 시드·난이도면 같은 런을 재현한다
function RunState:enter(params)
    params = params or {}
    Audio.init()
    local workshop
    if params.resume ~= nil then                -- [이어하기]: 저장된 날짜 · 골드 · 진열장 그대로 (systems/RunSave)
        workshop = RunSave.resume(params.resume, Workshop)
    else
        RunSave.clear()                         -- 새 런을 시작하면 이전 저장은 버린다
        RNG.set_seed(params.seed or RNG.generate_seed())
        local name = params.name or Progress.player_name() or I18n.t("story.default_name")
        workshop = Workshop({
            difficulty = params.difficulty, tutorial = params.tutorial, name = name, meta = MetaProgression.bonuses(),
            starter = not params.tutorial,
        })
    end
    self._workshop = workshop
    workshop.combat:set_dawn_gate(true)     -- 밤은 웨이브를 다 소탕하고 셔터가 화면을 덮은 순간 끝난다 (_watch_dawn)
    self._fx = Effects()
    self._hud = Hud()
    self._input = WorkshopInput(workshop, function(kind)
        self._overlays:open(kind)
    end)
    self._overlays = RunOverlays(workshop, self._input, {
        restart = function()    -- 같은 난이도·이름으로 새 런 (튜토리얼이 아직 진행 중이었다면 다시 켠다)
            self:_end_run("abandoned", "RunState", {
                difficulty = workshop.difficulty_id, name = workshop.owner_name,
                tutorial = workshop.tutorial ~= nil and workshop.tutorial:is_active(),
            })
        end,
        to_title = function()                   -- 런을 저장하고 타이틀로 ([이어하기]로 돌아온다, RP 정산 없음)
            RunSave.write(workshop.phase == "night" and self._night_snapshot or RunSave.snapshot(workshop))
            self._ended = true
            StateManager.switch("TitleState", { menu = true })
        end,
    })
    self._feedback = Feedback(self._fx, self._hud, workshop)
    self._attacks = AttackEffects(self._fx)
    self._motion = EntityMotion(self._fx, workshop)        -- 몬스터 보행·방벽 공격·피격 모션
    self._ambient = AmbientEffects(self._fx)               -- 주인장 반응·유물 튀어 오름·진열장 부유·포탈·금빛 먼지
    self._layers = { attacks = self._attacks, motion = self._motion }
    self._hitstop = HitStop(self._fx)                      -- 번개·치명타 명중 시 전투만 잠깐 멈춘다
    self._tutorial_view = TutorialView(workshop)
    self._hover = HoverTooltip(workshop)                    -- 상단 HUD · 공방 도구 호버 설명
    self._dawn = DawnSummary(workshop, self._hud)           -- 밤 소탕 → 새벽 정산창 → 카운트업 → dawn_candle
    Slots.set_mode_provider(function()        -- 화면 모드: 밤 / 낮 (보관함 · 진열장 · 작업대가 함께 보인다)
        return workshop.phase == "night" and "night" or "day"
    end)
    self._time = 0
    self._end_timer = nil
    self._ended = false

    EventBus.subscribe("phase:night_starting", function()
        self._night_snapshot = RunSave.snapshot(workshop)
    end, { owner = self })
    EventBus.emit("run:started", { seed = RNG.get_seed(), difficulty = workshop.difficulty_id })
    if params.resume ~= nil then
        EventBus.emit("ui:message", { text = I18n.t("run.resumed", { day = workshop.day }), kind = "good" })
        if workshop.phase == "shop" then
            EventBus.emit("phase:shop_opened", { day = workshop.day })
        end
    else
        workshop:begin()
    end
end

-- 개발 도구(스모크 테스트)용 읽기 접근자
function RunState:get_workshop()
    return self._workshop
end

function RunState:get_modal()
    return self._overlays.modal
end

function RunState:get_menu()
    return self._overlays.menu
end

function RunState:get_input()
    return self._input
end

-- 개발 도구(스모크 테스트)용 연출 계층 접근자
for name, field in pairs({ get_tutorial_view = "_tutorial_view", get_hud = "_hud", get_dawn = "_dawn", get_hover = "_hover",
    get_hitstop = "_hitstop" }) do
    RunState[name] = function(self) return self[field] end
end

function RunState:exit()
    Audio.stop_loops()
    Slots.set_mode_provider(nil)
    self._tutorial_view:destroy()
    self._attacks:destroy()
    self._motion:destroy()
    self._ambient:destroy()
    self._hitstop:destroy()
    self._dawn:destroy()
    self._feedback:destroy()
    self._input:destroy()
    self._workshop:destroy()
    EventBus.unsubscribe_owner(self)
end

function RunState:update(dt)
    self._time = self._time + dt
    self._hud:update(dt)
    self._fx:update(dt)     -- 연출(파티클·플래시)은 일시 정지 중에도 마저 사라진다
    if self._overlays:update_menu(dt) then
        return      -- 시스템 메뉴가 열려 있다: 게임 규칙·입력은 일시 정지
    end
    local workshop = self._workshop
    local night = workshop.phase == "night"
    local speed = night and Settings.get("night_speed") or 1     -- 밤 전투 배속 (1x · 2x · 3x)
    local frozen = self._hitstop:consume(dt)
    -- 배속이 높아도 한 번에 1/60초 이하씩 나눠 진행한다 (투사체 관통·보스 패턴 타이밍 오류 방지). 화면 전환·모달은 실제 시간
    local tutorial = workshop.tutorial              -- 새벽 정산창 · 밤 튜토리얼 안내를 읽는 동안 전투는 멈춘다
    if not self._dawn:is_blocking() and not (tutorial ~= nil and tutorial:is_pausing()) then
        FixedStep.run(night and dt - frozen or dt, speed, function(step)
            workshop:update(step)
            self._attacks:update(step, workshop.combat)
            self._motion:update(step, workshop.combat)
        end)
    end
    self._ambient:update(dt, workshop.phase)
    self._dawn:update(dt)
    self._input:update(dt)
    WorkshopCursor.request(self._input, self._overlays:any_open())   -- 커스텀 커서 (모달이 덮으면 모달 버튼만)
    SpriteBank.update(dt)
    self._tutorial_view:update(dt, self._input.pointer.x, self._input.pointer.y, self._input)
    self._hover:update(dt, self._input.pointer, self._overlays:any_open() or self._input.drag ~= nil or self._dawn:is_blocking())
    self._overlays:update_modal(dt)
    RunAudio.update(dt, workshop, self._input)       -- 입력 루프음 · 낮/밤 배경음 크로스페이드 · 보스 긴장감
    self:_check_result(dt)
end

function RunState:_check_result(dt)
    local result = self._workshop.result
    if self._ended or result == nil then
        return
    end
    if self._end_timer == nil then
        self._overlays:close_all()
        self._end_timer = UI.anim.end_delay
        self._fx:shake(result == "victory" and 0.4 or 1)
        self._fx:flash(RESULT_BANNERS[result].color, 0.5, 1.2)
    end
    self._end_timer = self._end_timer - dt
    if self._end_timer <= 0 then
        self:_end_run(result)
    end
end

-- 런 정산(RP 적립·기록) 후 next_state 로 전환. 기본은 결과 화면(GameOverState, 정산 내역 전달)
function RunState:_end_run(reason, next_state, next_params)
    if self._ended then
        return
    end
    self._ended = true
    RunSave.clear()                             -- 끝난 런은 이어 할 수 없다
    local workshop = self._workshop
    local result = workshop:summary(reason)
    result.seed = RNG.get_seed()
    if reason == "victory" then
        result.unlocked = Progress.mark_cleared(workshop.difficulty_id)
        result.ending = Endings.decide(workshop)
        result.ending_new = MetaProgression.record_ending(result.ending)
        result.medal_new = Progress.record_ending(result.ending)         -- 진엔딩 훈장 (data/endings.lua 의 medal)
    end
    result.rp = MetaProgression.award(result)
    EventBus.emit("run:ended", result)
    if next_state ~= nil then
        StateManager.switch(next_state, next_params)
    else
        StateManager.switch(result.ending ~= nil and "EndingState" or "GameOverState", result)   -- 승리: 엔딩 연출 → 결과
    end
end

function RunState:draw()
    local workshop, input, time = self._workshop, self._input, self._time
    RoomBackdrop.draw(workshop.phase)

    self._fx:push_shake()
    if workshop.phase == "night" then          -- 낮과 밤은 배치가 완전히 다르다 (data/layout.lua 의 day / night)
        NightLayoutView.draw(workshop, input, time, self._layers)
    else
        DayLayoutView.draw(workshop, input, time, self._ambient)
    end
    self._hud:draw(workshop, time)
    input:draw()
    self._fx:draw()
    self._fx:pop_shake()

    self._fx:draw_flash()       -- 화면 플래시는 창(모달·메뉴) 아래에 깔린다
    self._dawn:draw()           -- 새벽 정산창 (상단 바는 밝게 둔다)
    local overlay_open = self._overlays:any_open()
    if not overlay_open then
        Tooltip.draw_hovered(workshop, input)
        self._hover:draw()
    end
    self._overlays:draw()
    self._hud:draw_overlay(overlay_open)
    if not overlay_open then
        self._tutorial_view:draw(input, time)     -- 스포트라이트 암막 + 안내 띠 (토스트보다 위, 모달이 열리면 숨김)
    end
    if self._end_timer ~= nil then
        local banner = RESULT_BANNERS[workshop.result]
        Draw.shadow_text(I18n.t(banner.key, { days = workshop.max_days }), 0, BANNER_Y, Viewport.width(), "center",
            UI.font_size.title, banner.color)
    end
end

function RunState:mousemoved(x, y)
    self._input:mousemoved(x, y)
    self._dawn:mousemoved(x, y)
end

function RunState:mousepressed(x, y, button)
    if self._end_timer ~= nil or self._overlays:mousepressed(x, y, button) or self._dawn:mousepressed(x, y) then
        return
    end
    if not self._tutorial_view:mousepressed(x, y) then
        self._input:mousepressed(x, y, button)
    end
end

function RunState:mousereleased(x, y, button)
    self._input:mousereleased(x, y, button)
end

function RunState:keypressed(key)
    if self._end_timer ~= nil or self._overlays:keypressed(key) or self._dawn:keypressed(key) then
        return
    end
    self._input:keypressed(key)
end

return RunState
