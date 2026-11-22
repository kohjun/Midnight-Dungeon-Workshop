-- states/EndingState.lua
-- 계약 기간을 버텨낸 런의 엔딩 연출 (판정 systems/Endings, 수치 data/endings.lua, 장면 ui/EndingScenes, 문구 ending.<id>.*):
--   장면 위 "에필로그" + 금박 제목(엔딩 style) → 에필로그 4~5줄이 차례로 타자기처럼 나타난다 → 끝나면 결과 화면(GameOverState)
--   줄마다 한 줄에 들어가는 가장 큰 서사 글꼴을 고르고(긴 이름·영어), 묶음 전체가 아래 레터박스 위에 들어가도록 시작 높이를 올린다.
--   제목이 뜰 때 엔딩마다 울림 하나 (CHIMES — 진엔딩은 스승의 은빛 인장 종, 새로운 문지기는 깊은 조종).
-- Space / Enter / 클릭: 아직 줄이 남았으면 전부 펼치고, 다 펼쳐졌으면 결과 화면으로 (min_time 전 입력은 무시).
-- params: RunState 가 넘긴 결과 표 (ending, name, medal_new, ... — GameOverState 로 그대로 넘긴다).

local Class = require("lib.classic")
local StateManager = require("core.StateManager")
local Viewport = require("core.Viewport")
local Text = require("lib.text")
local Audio = require("systems.Audio")
local I18n = require("systems.I18n")
local Draw = require("ui.Draw")
local Effects = require("ui.Effects")
local Lettering = require("ui.Lettering")
local EndingScenes = require("ui.EndingScenes")
local AUDIO = require("data.audio")
local ENDINGS = require("data.endings")
local UI = require("data.ui")

local EndingState = Class:extend()

local LG = love.graphics
local LETTERBOX = 40
local TITLE_Y = 70
local LINES_Y = 476             -- 에필로그 첫 줄 (줄이 많거나 길면 위로 올라간다)
local LINE_GAP = 6              -- 줄 사이 여백
local LINES_W = 980
local BOTTOM_PAD = 12           -- 마지막 줄과 아래 레터박스 사이
local LINE_SIZES = { "story_large", { role = "story", size = 20 }, "story" }     -- 한 줄에 들어가는 첫 크기
local CHIMES = { true_dawn = "seal_clue_found", new_gatekeeper = "master_toll" }    -- 그 밖(또는 목록에 없는 소리)은 DEFAULT_CHIME
local DEFAULT_CHIME = "forge_success"

function EndingState:enter(result)
    Audio.set_scene("menu")
    self._result = result or {}
    self._id = self._result.ending or ENDINGS.order[1]
    self._time = 0
    self._done = false
    self._fx = Effects()
    self._scene = EndingScenes(self._id, self._fx)
    self._address = I18n.t("story.address", { name = self._result.name or I18n.t("story.default_name") })
    self._chimed = false
    self._lines = self:_layout_lines()
end

-- 개발 도구(스모크 테스트)용
function EndingState:get_ending()
    return self._id
end

-- 에필로그 줄 배치 { text, size, y, height } — 개발 도구(스모크 테스트)도 아래 레터박스 위에 드는지 본다
function EndingState:get_lines()
    return self._lines
end

-- 모든 줄이 한 줄에 드는 가장 큰 크기를 함께 쓴다 (줄마다 크기가 달라 보이지 않게 — 그래도 넘치면 가장 작은 크기로 줄바꿈)
function EndingState:_layout_lines()
    local texts = {}
    for i, raw in ipairs(I18n.list("ending." .. self._id .. ".lines")) do
        texts[i] = Text.fill(raw, { address = self._address })
    end
    local size = LINE_SIZES[#LINE_SIZES]
    for _, candidate in ipairs(LINE_SIZES) do
        local fits = true
        for _, text in ipairs(texts) do
            fits = fits and Draw.font(candidate):getWidth(text) <= LINES_W
        end
        if fits then
            size = candidate
            break
        end
    end
    local font, lines, total = Draw.font(size), {}, 0
    for i, text in ipairs(texts) do
        local _, wrapped = font:getWrap(text, LINES_W)
        lines[i] = { text = text, size = size, height = font:getHeight() * math.max(1, #wrapped) }
        total = total + lines[i].height + (i > 1 and LINE_GAP or 0)
    end
    local y = math.min(LINES_Y, Viewport.height() - LETTERBOX - BOTTOM_PAD - total)
    for _, line in ipairs(lines) do
        line.y = y
        y = y + line.height + LINE_GAP
    end
    return lines
end

function EndingState:_lines_end()
    return ENDINGS.lines_at + #self._lines * ENDINGS.line_time
end

function EndingState:_finish()
    if not self._done then
        self._done = true
        StateManager.switch("GameOverState", self._result)
    end
end

function EndingState:update(dt)
    Audio.update(dt)          -- 배경음 크로스페이드
    self._time = self._time + dt
    self._scene:update(dt, self._time)
    self._fx:update(dt)
    if not self._chimed and self._time >= ENDINGS.title_at then
        self._chimed = true
        local chime = CHIMES[self._id]
        Audio.play(AUDIO.sfx[chime] ~= nil and chime or DEFAULT_CHIME)
    end
    if self._time >= self:_lines_end() + 3 then
        self:_finish()
    end
end

function EndingState:_advance()
    if self._time < ENDINGS.min_time then
        return
    end
    if self._time < self:_lines_end() then
        self._time = self:_lines_end()      -- 남은 줄을 한 번에 펼친다
    else
        self:_finish()
    end
end

function EndingState:_draw_lines(sw)
    local lines = self._lines
    if #lines == 0 then
        return
    end
    local band_alpha = math.min(1, math.max(0, (self._time - ENDINGS.lines_at + 0.4) / 0.6))
    local last = lines[#lines]
    LG.setColor(0, 0, 0, 0.5 * band_alpha)
    LG.rectangle("fill", 0, lines[1].y - 18, sw, last.y + last.height + 12 - (lines[1].y - 18))
    for i, line in ipairs(lines) do
        local start = ENDINGS.lines_at + (i - 1) * ENDINGS.line_time
        if self._time >= start then
            local shown = Text.prefix(line.text, math.floor((self._time - start) * ENDINGS.chars_per_second))
            local alpha = math.min(1, (self._time - start) * 2.5)
            local x = (sw - LINES_W) / 2
            Draw.text(shown, x + 2, line.y + 2, LINES_W, "center", line.size, { 0, 0, 0 }, alpha * 0.8)
            Draw.text(shown, x, line.y, LINES_W, "center", line.size, { 0.95, 0.9, 0.8 }, alpha)
        end
    end
end

function EndingState:draw()
    local sw, sh = Viewport.width(), Viewport.height()
    self._fx:push_shake()
    self._scene:draw(self._time)
    self._fx:draw()
    self._fx:pop_shake()
    LG.setColor(0, 0, 0, 1)
    LG.rectangle("fill", 0, 0, sw, LETTERBOX)
    LG.rectangle("fill", 0, sh - LETTERBOX, sw, LETTERBOX)
    local title_alpha = math.min(1, math.max(0, (self._time - ENDINGS.title_at) / 1.2))
    if title_alpha > 0 then
        Draw.shadow_text(I18n.t("ending.epilogue"), 0, TITLE_Y - 24, sw, "center", "label", UI.color.text_dim, title_alpha)
        Lettering.draw(I18n.t("ending." .. self._id .. ".title"), 0, TITLE_Y, sw, "center", "headline",
            ENDINGS.list[self._id].style, title_alpha)
    end
    self:_draw_lines(sw)
    local fade = math.max(0, 1 - self._time / ENDINGS.fade)
    if fade > 0 then
        LG.setColor(0, 0, 0, fade)
        LG.rectangle("fill", 0, 0, sw, sh)
    end
    self._fx:draw_flash()
    if self._time >= ENDINGS.min_time then
        Draw.text(I18n.t("ending.skip"), 0, sh - 30, sw - 24, "right", "label", UI.color.text_dim,
            0.5 + 0.3 * math.sin(self._time * 3))
    end
end

function EndingState:keypressed()
    self:_advance()
end

function EndingState:mousepressed()
    self:_advance()
end

return EndingState
