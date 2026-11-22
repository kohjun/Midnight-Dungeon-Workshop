-- states/TitleState.lua
-- 타이틀: 배경 그림(불티·안개) 위 금박 로고.
--   1) "Space 또는 클릭으로 시작" 화면 — 아무 키/클릭 → 메뉴 (ESC: 종료)
--   2) 세로 메뉴 한 줄: [시작하기] · [영구 능력치 강화] · [유물 도감] · [환경 설정] · [게임 종료]
--      진행 중인 런 저장(systems/RunSave)이 있으면 맨 위에 [이어하기 (N일차)], 그 아래 [새 게임]
--      ↑↓ / W·S 로 고르고 Enter·Space·클릭으로 실행, ESC: 시작 화면으로
--   [시작하기]: 처음 플레이(튜토리얼을 끝내거나 건너뛴 적 없음, Progress.tutorial_done)면 난이도 계약서 없이
--      wax_seal → IntroState → 견습 난이도 + 튜토리얼로 곧장 들어간다. 그 뒤로는 DifficultyState(계약서, [튜토리얼 다시 보기] 토글).
-- params: { from_intro = 인트로에서 바로 이어짐(로고가 이미 떠 있음), menu = 메뉴부터 }

local Class = require("lib.classic")
local Tween = require("lib.tween")
local StateManager = require("core.StateManager")
local Input = require("core.Input")
local Viewport = require("core.Viewport")
local Audio = require("systems.Audio")
local I18n = require("systems.I18n")
local Progress = require("systems.Progress")
local RunSave = require("systems.RunSave")
local MetaProgression = require("systems.MetaProgression")
local MetaUpgradeView = require("ui.MetaUpgradeView")
local SettingsModal = require("ui.SettingsModal")
local CompendiumModal = require("ui.CompendiumModal")
local MenuList = require("ui.MenuList")
local CalendarText = require("ui.CalendarText")
local TitleScene = require("ui.TitleScene")
local TitleWeather = require("ui.TitleWeather")
local TitleLogo = require("ui.TitleLogo")
local CursorManager = require("ui.CursorManager")
local TransitionManager = require("ui.TransitionManager")
local Draw = require("ui.Draw")
local DIFFICULTIES = require("data.difficulties")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local TitleState = Class:extend()

local L = LAYOUT.title
local C = UI.color
local LEFT_W = 600      -- 왼쪽 메뉴 구역 너비 (안내 문구 가운데 정렬 기준)

function TitleState:enter(params)
    CursorManager.install()          -- 커스텀 커서 (운영체제 커서를 숨기고 맨 위에 그린다)
    params = params or {}
    Audio.init()
    Audio.set_scene("title")         -- 공방 드론 + 밤비 앰비언스 (다른 화면으로 가면 크로스페이드)
    self._time = 0
    self._tweens = Tween.Group()
    self._scene = TitleScene()
    self._weather = TitleWeather(self._scene)
    self._modal = nil
    self._pointer_moved = false
    local x, y = Viewport.mouse_position()
    self._pointer = { x = x, y = y }
    self._anim = { logo = params.from_intro and 1 or 0, menu = 0 }
    if not params.from_intro then
        self._tweens:to(self._anim, UI.anim.title_intro, { logo = 1 }):ease("out_quad")
    end
    local items = {}
    self._resume = RunSave.load()               -- 진행 중인 런이 있으면 [이어하기]가 맨 위, 그 아래 [새 게임]
    if self._resume ~= nil then
        items[1] = { id = "continue", icon = "play",
            label = function() return I18n.t("title.menu_continue", { date = CalendarText.date(self._resume.fields.day) }) end,
            on_activate = function() self:_continue() end }
    end
    items[#items + 1] = { id = "start", icon = self._resume and "book" or "play",
        label = function() return I18n.t(self._resume and "title.menu_new" or "title.menu_start") end,
        on_activate = function() self:_start() end }
    for _, item in ipairs({
        { id = "meta", icon = "star", label = function() return I18n.t("title.meta_button", { rp = MetaProgression.rp() }) end,
            on_activate = function() self._modal = MetaUpgradeView.open() end },
        { id = "compendium", icon = "gem", label = function() return I18n.t("compendium.menu") end,
            on_activate = function() self._modal = CompendiumModal.open() end },
        { id = "settings", icon = "gear", label = function() return I18n.t("title.settings_button") end,
            on_activate = function() self._modal = SettingsModal.open() end },
        { id = "quit", icon = "door", label = function() return I18n.t("title.menu_quit") end,
            on_activate = function() love.event.quit() end },
    }) do
        items[#items + 1] = item
    end
    self._menu = MenuList(L.menu, items)
    self._phase = "press"
    if params.menu then
        self:_open_menu()
    end
end

function TitleState:exit()
    self._tweens:clear()
end

-- 개발 도구(스모크 테스트)용
function TitleState:get_phase()
    return self._phase
end

-- 메뉴 항목 id 의 순서 (없으면 nil) — [이어하기]가 있으면 항목이 한 칸씩 내려간다
function TitleState:menu_index(id)
    return self._menu:index_of(id)
end

function TitleState:get_modal()
    return self._modal
end

-- [이어하기]: 저장된 런으로 곧장 공방 (확대경 조리개 전환)
function TitleState:_continue()
    local data = self._resume
    TransitionManager.start("lens_iris", function()
        StateManager.switch("RunState", { resume = data })
    end)
end

-- [시작하기] / [새 게임]: 처음이면 계약서를 건너뛰고 견습 + 튜토리얼로 곧장 인트로, 아니면 난이도 계약서
function TitleState:_start()
    if Progress.tutorial_done() then
        StateManager.switch("DifficultyState")
        return
    end
    local rect = MenuList.item_rect(L.menu, self._menu:index_of("start"))
    local run = { difficulty = DIFFICULTIES.first_run, tutorial = true }     -- 이름은 RunState 가 저장된 이름 → 기본 호칭 순으로 채운다
    TransitionManager.start("wax_seal", function()
        StateManager.switch("IntroState", { run = run })
    end, { x = rect.x + rect.w / 2, y = rect.y + rect.h / 2 })
end

function TitleState:get_scene()
    return self._scene
end

function TitleState:get_weather()
    return self._weather
end

function TitleState:_open_menu()
    if self._phase ~= "menu" then
        self._phase = "menu"
        self._anim.menu = 0
        self._tweens:to(self._anim, 0.35, { menu = 1 }):ease("out_cubic")
    end
end

function TitleState:update(dt)
    self._time = self._time + dt
    self._tweens:update(dt)
    Audio.update(dt)
    local active = self._modal == nil
    local px = active and self._pointer.x or nil
    local py = active and self._pointer.y or nil
    self._scene:update(dt, px, py, active and self._pointer_moved)
    self._weather:update(dt, px, py, active and self._pointer_moved)
    if self._modal ~= nil then
        self._modal:update(dt, self._pointer.x, self._pointer.y)
        if self._modal.closed then
            self._modal = nil
        end
    elseif self._phase == "menu" then
        self._menu:update(dt, self._pointer.x, self._pointer.y, self._pointer_moved)
    end
    self._pointer_moved = false      -- 메뉴 항목·모달 버튼 호버 커서는 MenuList · Button 이 요청한다 (ui/CursorManager)
end

function TitleState:_draw_greeting()
    local name = Progress.player_name()
    if name == nil then
        return
    end
    local text = I18n.t("title.returning", { address = I18n.t("story.address", { name = name }) })
    Draw.text(text, 40, L.greeting_y, LEFT_W - 40, "center", "story", C.text, 0.85 * self._anim.logo)
end

function TitleState:draw()
    local flash, lu, lv = self._weather:lightning_state()
    self._scene:draw_base(flash, lu, lv)
    self._weather:draw_background()
    self._scene:draw_sign()
    self._weather:draw_foreground()
    self._scene:draw_dim(self._phase == "menu" and 0.14 or 0)
    local logo = L.logo
    TitleLogo.draw(logo.cx, logo.y, logo.w, self._anim.logo)
    self:_draw_greeting()
    if self._phase == "press" then
        local pulse = 0.55 + 0.45 * math.sin(self._time * 3)
        Draw.text(I18n.t("title.press_start"), 0, L.press_y, LEFT_W, "center", "menu", C.text, pulse * self._anim.logo)
    else
        love.graphics.push()
        love.graphics.translate(-30 * (1 - self._anim.menu), 0)
        self._menu:draw(self._anim.menu)
        love.graphics.pop()
        Draw.text(I18n.t("title.hint"), 0, L.hint_y, LEFT_W, "center", "label", C.text_dim, self._anim.menu)
    end
    if self._modal ~= nil then
        self._modal:draw()
    end
end

function TitleState:mousemoved(x, y)
    self._pointer.x, self._pointer.y = x, y
    self._pointer_moved = true
end

function TitleState:mousepressed(x, y, button)
    self._pointer.x, self._pointer.y = x, y
    if not Input.is_mouse_action(button, "confirm") then
        return
    end
    if self._modal ~= nil then
        self._modal:mousepressed(x, y)
    elseif self._phase == "press" then
        self:_open_menu()
    else
        -- 메뉴 버튼 클릭을 최우선으로 처리하고, 빈 좌측 하늘 클릭에만 번개를 트리거한다
        if not self._menu:mousepressed(x, y) then
            self._weather:try_click_lightning(x, y, false)
        end
    end
end

function TitleState:keypressed(key)
    if self._modal ~= nil then
        self._modal:keypressed(key)
    elseif self._phase == "press" then
        if Input.is_action(key, "back") then
            love.event.quit()
        else
            self:_open_menu()
        end
    elseif Input.is_action(key, "back") then
        self._phase = "press"
    else
        self._menu:keypressed(key)
    end
end

return TitleState
