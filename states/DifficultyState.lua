-- states/DifficultyState.lua
-- 난이도 계약서: [시작하기] 직후 타이틀 배경이 어두워지고, 양피지 계약서가 위에서 아래로 펼쳐진다 (ui/Parchment).
--   조항 카드 5장 — 위 줄 쉬움·보통·어려움, 아래 줄 악몽·???(봉인) (ui/ContractCards, 호버: 1.0 → 1.03 확대 + 금빛 테두리)
--   + 서명란(이름, 한글 IME, 저장된 이름이 미리 채워짐).
--   카드 클릭 또는 F1~F5 → 서명 확인(빈 이름이면 거부) → 이름 저장 → wax_seal 전환(클릭 지점 또는 카드 중앙에 밀랍 인장)
--   → IntroState(이야기) → lens_iris 전환 → RunState. [뒤로] / ESC → TitleState 메뉴.
-- 악몽은 베테랑 클리어 전까지 잠겨 있고(누르면 해금 조건 안내), 5단계 스승의 흔적은 악몽 클리어 전까지 '???' 봉인 카드로
-- 가려져 있다 (누르면 "악몽 계약을 완수하면 봉인이 풀립니다"). 악몽을 클리어하면 진엔딩 캠페인 카드로 열린다.
-- 처음 플레이는 여기를 거치지 않는다 (TitleState 가 견습 + 튜토리얼로 곧장 인트로). 여기서 시작하는 런은 튜토리얼이 꺼져 있고,
-- 오른쪽 아래 [튜토리얼 다시 보기] 토글(기본 꺼짐, F6)을 켜면 고른 난이도에서 튜토리얼을 다시 켠다.

local Class = require("lib.classic")
local Tween = require("lib.tween")
local StateManager = require("core.StateManager")
local Input = require("core.Input")
local Viewport = require("core.Viewport")
local Audio = require("systems.Audio")
local I18n = require("systems.I18n")
local Progress = require("systems.Progress")
local Button = require("ui.Button")
local NameField = require("ui.NameField")
local Draw = require("ui.Draw")
local Lettering = require("ui.Lettering")
local ContractCards = require("ui.ContractCards")
local Parchment = require("ui.Parchment")
local TitleBackdrop = require("ui.TitleBackdrop")
local TransitionManager = require("ui.TransitionManager")
local DIFFICULTIES = require("data.difficulties")
local LAYOUT = require("data.layout")
local STORY = require("data.story")
local UI = require("data.ui")

local DifficultyState = Class:extend()

local L = LAYOUT.difficulty
local NOTICE_TIME = 2.4
local HOVER_SCALE = 0.03
local TITLE_DIM = 0.12      -- 타이틀 메뉴의 배경 어둡기 (여기서부터 어두워진다)

function DifficultyState.card_rect(index)
    return ContractCards.rect(index)
end

function DifficultyState:enter()
    Audio.set_scene("menu")
    self._replay = false
    self._time = 0
    self._backdrop = TitleBackdrop()
    self._notice, self._notice_timer, self._chosen = nil, 0, nil
    self._anim = { dim = 0, unroll = 0 }
    self._tweens = Tween.Group()
    self._tweens:to(self._anim, UI.anim.contract_dim, { dim = 1 }):ease("out_quad")
    self._tweens:to(self._anim, UI.anim.contract_unroll, { unroll = 1 }):ease("out_cubic"):delay(UI.anim.contract_dim * 0.5)
    local x, y = Viewport.mouse_position()
    self._pointer = { x = x, y = y }
    self._cards = {}
    for i, id in ipairs(DIFFICULTIES.order) do
        local card = { id = id, mode = DIFFICULTIES.modes[id] }
        card.button = Button(DifficultyState.card_rect(i), "", {
            hidden = true, hover_scale = HOVER_SCALE,
            enabled = function() return Progress.is_unlocked(id) end,
            on_click = function() self:_choose(i) end,
        })
        self._cards[i] = card
    end
    self._back = Button(L.back, function() return I18n.t("difficulty_select.back") end, {
        icon = "back", key_hint = "Esc", hover_scale = HOVER_SCALE, gold_hover = true,
        on_click = function() StateManager.switch("TitleState", { menu = true }) end,
    })
    self._replay_button = Button(L.replay, function()
        return I18n.t(self._replay and "difficulty_select.replay_on" or "difficulty_select.replay_off")
    end, {
        icon = "book", key_hint = "F6", hover_scale = HOVER_SCALE, gold_hover = true,
        active = function() return self._replay end,
        on_click = function() self._replay = not self._replay end,
    })
    self._name = NameField(L.name_field, {
        text = Progress.player_name() or "", max_chars = STORY.contract.name_max_chars,
        placeholder = I18n.t("story.name_placeholder"), font_size = "story_large", ink = Parchment.INK, line = Parchment.EDGE,
    })
    self._name:set_active(true)
end

-- 개발 도구(스모크 테스트)용
function DifficultyState:get_name_text()
    return self._name:value()
end

function DifficultyState:get_chosen()
    return self._chosen
end

function DifficultyState:is_replay_on()
    return self._replay
end

-- 지금 떠 있는 안내 문구 (없으면 nil)
function DifficultyState:get_notice()
    return self._notice_timer > 0 and self._notice or nil
end

function DifficultyState:exit()
    self._tweens:clear()
    self._name:set_active(false)
end

-- 계약 확정: 서명(이름) 확인 → 밀랍 인장 전환 → 인트로 → 본게임
function DifficultyState:_choose(index)
    if self._chosen ~= nil then
        return
    end
    local name = Progress.set_player_name(self._name:value())
    if name == nil then
        self._name:nudge()
        self._notice, self._notice_timer = I18n.t("story.empty_name"), NOTICE_TIME
        return
    end
    local card = self._cards[index]
    self._chosen = card.id
    self._notice_timer = 0
    self._name.text = name
    self._name:set_active(false)
    local rect = card.button.rect
    local point = self._press_point or { x = rect.x + rect.w / 2, y = rect.y + rect.h / 2 }
    local run = { difficulty = card.id, tutorial = self._replay, name = name }
    TransitionManager.start("wax_seal", function()
        StateManager.switch("IntroState", { run = run })
    end, { x = point.x, y = point.y })
end

-- point: 클릭 지점 (키로 고르면 nil → 카드 중앙)
function DifficultyState:_press_card(index, point)
    local card = self._cards[index]
    self._press_point = point
    if not card.button:press() then
        self._notice = Progress.is_veiled(card.id) and I18n.t("title.sealed_notice")     -- 봉인 카드: 악몽 완수 시 해금
            or I18n.t("title.unlock_notice", { names = ContractCards.requirement_text(card.id) })
        self._notice_timer = NOTICE_TIME
    end
    self._press_point = nil
end

function DifficultyState:update(dt)
    self._time = self._time + dt
    self._tweens:update(dt)
    Audio.update(dt)
    self._backdrop:update(dt)
    self._name:update(dt)
    self._notice_timer = math.max(0, self._notice_timer - dt)
    for _, card in ipairs(self._cards) do          -- 카드·[뒤로] 호버 커서는 Button 이 요청한다 (ui/CursorManager)
        card.button:update(dt, self._pointer.x, self._pointer.y)
    end
    self._back:update(dt, self._pointer.x, self._pointer.y)
    self._replay_button:update(dt, self._pointer.x, self._pointer.y)
end

-- 서명란: "서명: [이름] (그레이븐 외곽 감정 공방 주인)" + 경고/안내
function DifficultyState:_draw_signature()
    local field = L.name_field
    local label_y = field.y + (field.h - Draw.font("story"):getHeight()) / 2
    Draw.text(I18n.t("story.signature_label"), field.x - 70, label_y, 64, "right", "story", Parchment.INK)
    self._name:draw()
    Draw.text(I18n.t("story.signature_role"), field.x + field.w + 12, label_y + 2, 320, "left", { role = "story", size = 15 },
        Parchment.INK)
    local sw = Viewport.width()
    if self._notice_timer > 0 then
        Draw.text(self._notice, 0, L.notice_y, sw, "center", "button", Parchment.RED_INK, math.min(1, self._notice_timer * 2))
    end
    Draw.text(I18n.t("difficulty_select.hint"), 0, L.hint_y, sw, "center", "label", Parchment.EDGE)
end

function DifficultyState:draw()
    local sw = Viewport.width()
    local dim = self._anim.dim
    self._backdrop:draw(nil, TITLE_DIM + (UI.anim.contract_dark - TITLE_DIM) * dim)
    local paper = L.parchment
    local unroll = self._anim.unroll
    Parchment.draw_paper(paper, unroll)
    local bottom = Parchment.bottom(paper, unroll)
    if bottom > paper.y + 2 then        -- 펼쳐진 부분까지만 내용이 보인다
        Viewport.set_scissor(paper.x, paper.y, paper.w, bottom - paper.y)
        Lettering.draw(I18n.t("difficulty_select.title"), 0, L.title_y, sw, "center", "headline", "ink")
        Draw.text(I18n.t("difficulty_select.subtitle"), 0, L.title_y + 50, sw, "center", "story", Parchment.INK)
        for i, card in ipairs(self._cards) do
            ContractCards.draw(i, card, self._time)
        end
        self:_draw_signature()
        self._back:draw()
        self._replay_button:draw()
        Viewport.set_scissor()
    end
    Parchment.draw_rods(paper, unroll)
end

function DifficultyState:mousemoved(x, y)
    self._pointer.x, self._pointer.y = x, y
end

function DifficultyState:mousepressed(x, y, button)
    self._pointer.x, self._pointer.y = x, y
    if not Input.is_mouse_action(button, "confirm") or self._chosen ~= nil then
        return
    end
    for _, button in ipairs({ self._back, self._replay_button }) do
        if button:contains(x, y) then
            button:press()
            return
        end
    end
    for i, card in ipairs(self._cards) do
        if card.button:contains(x, y) then
            self:_press_card(i, { x = x, y = y })
            return
        end
    end
end

function DifficultyState:textinput(text)
    self._name:textinput(text)
    self._notice_timer = 0
end

function DifficultyState:textedited(text)
    self._name:textedited(text)
end

-- 서명란에 글자가 들어가므로 숫자 대신 F1~F5 로 고른다 (F6 = 튜토리얼 다시 보기)
function DifficultyState:keypressed(key)
    if self._chosen ~= nil then
        return
    end
    if Input.is_action(key, "back") then
        self._back:press()
    elseif Input.is_action(key, "replay_tutorial") then
        self._replay_button:press()
    elseif key == "backspace" then
        self._name:backspace()
    else
        for i = 1, #self._cards do
            if Input.is_action(key, "difficulty_" .. i) then
                self:_press_card(i)
                return
            end
        end
    end
end

return DifficultyState
