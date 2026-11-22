-- states/IntroState.lua
-- 새 런의 7장면 · 14비트 2.5D 모션 코믹스 인트로 (시간표 data/intro.lua, 장면 ui/IntroScenes, 문구 로케일 intro.lines):
--   스승의 공방 → 마나 폭풍·균열 포탈·길드 결계 → 스승의 밤 방어 → 스승의 실종 → 공방 상속·결계 유지비 계약
--   → 진열장 아래의 공명 회로(25칸 소켓 · 마력 도선 · 문 앞의 주인공) → 과부하·금속 피로, 낮과 밤의 이중 생활
-- 내레이션 비트마다 문장이 타자기로 찍히고, 장면 시계는 비트의 hold 에서 멈춰 입력을 기다린다 (멈춰도 불티·전투는 계속):
--   클릭 / Space / Enter: 찍는 중이면 문장 즉시 완성, 다 찍혔으면 다음 비트 (마지막 비트 뒤 → 끝)
--   Esc / 오른쪽 위 [건너뛰기]: 바로 끝. 다 찍힌 채 기다릴 때는 아래에 "클릭 또는 Space 로 계속" 이 은은하게 깜빡인다.
-- assets/video/intro.ogv 가 있으면 그 영상을 대신 재생한다 (아무 키·클릭 = 건너뛰기).
-- params: { run = RunState 매개변수 } — 끝나면 lens_iris 전환으로 낮 공방(RunState). run 이 없으면 타이틀로.

local Class = require("lib.classic")
local StateManager = require("core.StateManager")
local Viewport = require("core.Viewport")
local Input = require("core.Input")
local Text = require("lib.text")
local utf8 = require("utf8")
local Audio = require("systems.Audio")
local I18n = require("systems.I18n")
local Progress = require("systems.Progress")
local Draw = require("ui.Draw")
local Button = require("ui.Button")
local Effects = require("ui.Effects")
local IntroScenes = require("ui.IntroScenes")
local TitleLogo = require("ui.TitleLogo")
local TransitionManager = require("ui.TransitionManager")
local INTRO = require("data.intro")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local IntroState = Class:extend()

local LG = love.graphics
local NARRATION_W = 1040
local NARRATION_H = 84
local TEXT = { 0.94, 0.89, 0.78 }

function IntroState:enter(params)
    Audio.init()
    Audio.set_scene("menu")
    self._run = params and params.run
    self._time, self._beat, self._typed = 0, 1, 0
    self._done = false
    self._fx = Effects()
    self._scenes = IntroScenes(self._fx)
    self._lightning = 1
    self._pointer = { x = 0, y = 0 }
    local name = (self._run and self._run.name) or Progress.player_name() or I18n.t("story.default_name")
    self._address = I18n.t("story.address", { name = name })
    self._skip = Button(LAYOUT.intro_skip, function() return I18n.t("intro.skip") end, {
        icon = "door", key_hint = "Esc", gold_hover = true, on_click = function() self:_finish() end,
    })
    self._video = nil
    if love.filesystem.getInfo(INTRO.video) ~= nil then
        local ok, video = pcall(LG.newVideo, INTRO.video)
        if ok then
            self._video = video
            video:play()
        else
            print("[IntroState] failed to open intro video: " .. tostring(video))
        end
    end
end

function IntroState:exit()
    if self._video ~= nil then
        self._video:pause()
    end
end

-- 개발 도구(스모크 테스트)용: 지금 장면 id · 비트 번호
function IntroState:get_stage()
    return self:_stage().id
end

function IntroState:get_beat()
    return self._beat
end

function IntroState:_stage()
    for _, stage in ipairs(INTRO.stages) do
        if self._time < stage.stop then
            return stage
        end
    end
    return INTRO.stages[#INTRO.stages]
end

function IntroState:_line(index)
    local line = I18n.list("intro.lines")[index]
    return line and Text.fill(line, { address = self._address }) or nil
end

function IntroState:_finish()
    if self._done then
        return
    end
    self._done = true
    if self._run == nil then
        StateManager.switch("TitleState", { from_intro = true })
        return
    end
    local run = self._run       -- 감정 확대경 조리개가 닫혔다 열리며 낮 공방으로
    TransitionManager.start("lens_iris", function()
        StateManager.switch("RunState", run)
    end)
end

-- 클릭 · Space · Enter: 문장 완성 → 다음 비트
function IntroState:_advance()
    local beat = INTRO.beats[self._beat]
    if beat == nil then
        self:_finish()
        return
    end
    local line = self:_line(self._beat) or ""
    if self._time < beat.start then
        self._time = beat.start
    end
    if self._typed < utf8.len(line) then
        self._typed = math.huge
        return
    end
    self._time = math.max(self._time, beat.hold)
    self._beat, self._typed = self._beat + 1, 0
end

-- 다 찍힌 문장이 hold 에서 입력을 기다리는 중인지
function IntroState:is_waiting()
    local beat = INTRO.beats[self._beat]
    local line = self:_line(self._beat)
    return beat ~= nil and line ~= nil and self._time >= beat.hold and self._typed >= utf8.len(line)
end

function IntroState:update(dt)
    Audio.update(dt)          -- 배경음 크로스페이드
    self._skip:update(dt, self._pointer.x, self._pointer.y)
    if self._video ~= nil then
        self._time = self._time + dt
        if self._time > 0.5 and not self._video:isPlaying() then
            self:_finish()
        end
        return
    end
    local beat = INTRO.beats[self._beat]
    self._time = math.min(beat and beat.hold or INTRO.duration, self._time + dt)
    if beat ~= nil and self._time >= beat.start then
        self._typed = self._typed + dt * INTRO.chars_per_second
    end
    local stage = self:_stage()
    self._scenes:update(dt, stage.id, self._time)
    self._fx:update(dt)
    local strike = INTRO.lightning[self._lightning]
    if strike ~= nil and self._time >= strike then      -- 마나 폭풍: 보라 벼락 + 섬광 + 흔들림 + 천둥
        self._lightning = self._lightning + 1
        self._scenes:strike(INTRO.portal.x, INTRO.ground_y - INTRO.portal.size * 0.8)
        self._fx:flash({ 0.75, 0.55, 1.0 }, 0.55, 0.45)
        self._fx:shake(0.75)
        Audio.play("intro_thunder")
    end
    if beat == nil and self._time >= INTRO.duration then
        self:_finish()
    end
end

function IntroState:_draw_narration(sw, sh)
    local beat = INTRO.beats[self._beat]
    local line = self:_line(self._beat)
    if beat == nil or line == nil or self._time < beat.start then
        return
    end
    local y = sh - INTRO.letterbox - NARRATION_H
    LG.setColor(0, 0, 0, 0.6)
    LG.rectangle("fill", 0, y, sw, NARRATION_H)
    local shown = Text.prefix(line, math.floor(math.min(self._typed, 1e6)))
    local x = (sw - NARRATION_W) / 2
    local _, wrapped = Draw.font("story_large"):getWrap(line, NARRATION_W)
    local text_y = y + (NARRATION_H - #wrapped * Draw.font("story_large"):getHeight()) / 2
    Draw.text(shown, x + 2, text_y + 2, NARRATION_W, "center", "story_large", { 0, 0, 0 }, 0.8)
    Draw.text(shown, x, text_y, NARRATION_W, "center", "story_large", TEXT)
    if self:is_waiting() then
        Draw.label_text(I18n.t("intro.continue"), 0, sh - INTRO.letterbox + 12, sw, "center", "label", UI.color.accent,
            0.45 + 0.4 * math.sin(love.timer.getTime() * 4))
    end
end

-- 장면 경계 암전 (첫 장면은 페이드인, 마지막 장면은 타이틀로 그대로 이어지므로 끝에서 어두워지지 않는다)
function IntroState:_stage_fade(stage)
    local into = (self._time - stage.start) / INTRO.fade
    local out = stage.id == INTRO.stages[#INTRO.stages].id and 1 or (stage.stop - self._time) / INTRO.fade
    return 1 - math.max(0, math.min(1, into, out))
end

function IntroState:draw()
    local sw, sh = Viewport.width(), Viewport.height()
    if self._video ~= nil then
        Draw.clear({ 0, 0, 0 })
        local vw, vh = self._video:getDimensions()
        local scale = math.min(sw / vw, sh / vh)
        LG.setColor(1, 1, 1, 1)
        LG.draw(self._video, (sw - vw * scale) / 2, (sh - vh * scale) / 2, 0, scale, scale)
    else
        local stage = self:_stage()
        self._fx:push_shake()
        self._scenes:draw(stage.id, self._time)
        self._fx:draw()
        self._fx:pop_shake()
        if self._time >= INTRO.logo_at then
            local k = math.min(1, (self._time - INTRO.logo_at) / INTRO.logo_time)
            local logo = LAYOUT.title.logo
            TitleLogo.draw(logo.cx, logo.y, logo.w, k, 1.2 - 0.2 * k)
        end
        local bar = INTRO.letterbox * (stage.id == "vow" and math.max(0, 1 - (self._time - INTRO.logo_at)) or 1)
        LG.setColor(0, 0, 0, 1)
        LG.rectangle("fill", 0, 0, sw, bar)
        LG.rectangle("fill", 0, sh - bar, sw, bar)
        local fade = self:_stage_fade(stage)
        if fade > 0 then
            LG.setColor(0, 0, 0, fade)
            LG.rectangle("fill", 0, 0, sw, sh)
        end
        self:_draw_narration(sw, sh)
        self._fx:draw_flash()
    end
    self._skip:draw()
end

function IntroState:mousemoved(x, y)
    self._pointer.x, self._pointer.y = x, y
end

function IntroState:keypressed(key)
    if Input.is_action(key, "back") or self._video ~= nil then
        self:_finish()
    elseif Input.is_action(key, "confirm") then
        self:_advance()
    end
end

function IntroState:mousepressed(x, y, button)
    self._pointer.x, self._pointer.y = x, y
    if self._skip:contains(x, y) then
        self._skip:press()
    elseif self._video ~= nil then
        self:_finish()
    elseif Input.is_mouse_action(button, "confirm") then
        self:_advance()
    end
end

return IntroState
