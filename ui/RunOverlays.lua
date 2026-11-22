-- ui/RunOverlays.lua
-- 인게임 화면 위에 뜨는 창 관리 (RunState 가 소유): 게임 모달 하나 + 시스템 메뉴.
--   modal : 길드 보급 상점(상납 성공 직후 자동) · 공방 개조 — 열려 있으면 입력은 모달이 받는다
--   menu  : 시스템 메뉴(ui/PauseModal) · 유물 도감(ui/CompendiumModal — 공방을 넘겨 이번 계약의 엔딩 기준도 보여 준다)
--           · [길드](ui/GuildModal) · [의뢰](ui/QuestModal) · '스승의 흔적' [수기](ui/MasterJournalModal, 낮·밤 모두)
--           — 열려 있는 동안 게임은 일시 정지되고, 다른 모달 위에 그린다
-- ESC: 닫을 수 있는 모달이 열려 있으면 그 모달을 먼저 닫고, 아니면 시스템 메뉴를 연다.
-- actions = { restart = fn, to_title = fn } — 런 정산·상태 전환은 RunState 가 한다.

local Class = require("lib.classic")
local Input = require("core.Input")
local Audio = require("systems.Audio")
local GuildShopView = require("ui.GuildShopView")
local WorkshopUpgradeView = require("ui.WorkshopUpgradeView")
local PauseModal = require("ui.PauseModal")
local CompendiumModal = require("ui.CompendiumModal")
local GuildModal = require("ui.GuildModal")
local QuestModal = require("ui.QuestModal")
local MasterJournalModal = require("ui.MasterJournalModal")

local RunOverlays = Class:extend()

local MODAL_VIEWS = {
    upgrades = WorkshopUpgradeView,
    shop = GuildShopView,
}
-- 게임을 멈추고 맨 위에 여는 창 (kind → 여는 함수)
local MENU_VIEWS = {
    compendium = function(workshop) return CompendiumModal.open(workshop) end,
    guild = function(workshop) return GuildModal.open(workshop) end,
    quests = function(workshop) return QuestModal.open(workshop) end,
    journal = function(workshop) return MasterJournalModal.open(workshop) end,
}

function RunOverlays:new(workshop, input, actions)
    self._workshop = workshop
    self._input = input
    self._actions = actions
    self.modal = nil
    self.menu = nil
    self.locked = false     -- 승패 연출 중: 더 이상 창을 열지 않는다
end

-- kind: "upgrades" | "shop" | "menu" | "compendium" | "guild" | "quests" | "journal"
function RunOverlays:open(kind)
    if self.locked then
        return
    end
    if kind == "menu" or MENU_VIEWS[kind] ~= nil then
        self:open_menu(kind)
        return
    end
    local view = MODAL_VIEWS[kind]
    assert(view ~= nil, "RunOverlays: unknown modal '" .. tostring(kind) .. "'")
    self._input:release()
    self.modal = view.open(self._workshop)
end

-- 시스템 메뉴(또는 유물 도감 · 길드 · 의뢰): 도구·드래그·루프음을 내려놓고 게임을 멈춘다
function RunOverlays:open_menu(kind)
    if self.menu ~= nil or self.locked then
        return
    end
    self._input:set_tool("none")
    self._input:release()
    Audio.stop_loops()
    if MENU_VIEWS[kind] ~= nil then
        self.menu = MENU_VIEWS[kind](self._workshop)
        self.menu.kind = kind
        return
    end
    self.menu = PauseModal.open({
        resume = function() end,
        restart = self._actions.restart,
        to_title = self._actions.to_title,
    })
end

function RunOverlays:any_open()
    return self.modal ~= nil or self.menu ~= nil
end

-- 승패가 정해졌다: 모두 닫고 잠근다
function RunOverlays:close_all()
    self.modal, self.menu = nil, nil
    self.locked = true
end

-- 시스템 메뉴 갱신. 열려 있으면(= 일시 정지) true
function RunOverlays:update_menu(dt)
    if self.menu == nil then
        return false
    end
    self.menu:update(dt, self._input.pointer.x, self._input.pointer.y)
    if self.menu.closed then
        self.menu = nil
    end
    return true
end

function RunOverlays:update_modal(dt)
    local workshop = self._workshop
    if workshop.phase == "shop" and workshop.result == nil and (self.modal == nil or self.modal.kind ~= "shop") then
        self:open("shop")
    end
    if self.modal ~= nil then
        self.modal:update(dt, self._input.pointer.x, self._input.pointer.y)
        if self.modal.closed or (self.modal.kind ~= "shop" and not workshop:is_day()) then
            self.modal = nil
        end
    end
end

function RunOverlays:draw()
    if self.modal ~= nil then
        self.modal:draw()
    end
    if self.menu ~= nil then
        self.menu:draw()
    end
end

-- 창이 열려 있으면 클릭을 소비하고 true
function RunOverlays:mousepressed(x, y, button)
    local top = self.menu or self.modal
    if top == nil then
        return false
    end
    self._input.pointer.x, self._input.pointer.y = x, y
    if Input.is_mouse_action(button, "primary") then
        top:mousepressed(x, y)
    end
    return true
end

-- 키를 창이 처리했으면 true (ESC 는 창이 없어도 시스템 메뉴를 열며 소비한다)
function RunOverlays:keypressed(key)
    if self.menu ~= nil then
        self.menu:keypressed(key)
        return true
    end
    if Input.is_action(key, "back") then
        if self.modal ~= nil and self.modal:can_cancel() then
            self.modal:keypressed(key)      -- 다른 모달이 열려 있으면 그 모달을 먼저 닫는다
        else
            self:open_menu()
        end
        return true
    end
    if self.modal ~= nil then
        self.modal:keypressed(key)
        return true
    end
    return false
end

return RunOverlays
