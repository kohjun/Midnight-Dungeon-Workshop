-- ui/PauseModal.lua
-- 시스템 메뉴 모달 (인게임 [설정] 버튼 또는 ESC). 공용 ui/Modal 의 행 버튼으로 구성한다.
--   [계속하기] · [환경 설정] · [처음부터 다시하기] (2단계 확인) · [타이틀로 돌아가기]
-- [환경 설정]은 ui/SettingsModal 을 자식으로 띄우고, 닫히면 다시 이 메뉴로 돌아온다.
-- actions = { resume = fn, restart = fn, to_title = fn } — 실제 동작은 RunState 가 넘긴다.
-- 버튼 좌표: 행 i 는 Modal.row_button_rect(i) (1 계속 · 2 설정 · 3 다시하기 · 4 타이틀), 확인 단계는 Modal.footer_rect(1|2, 2).

local Class = require("lib.classic")
local Input = require("core.Input")
local I18n = require("systems.I18n")
local Modal = require("ui.Modal")
local SettingsModal = require("ui.SettingsModal")

local PauseModal = Class:extend()

local ROWS = {
    { id = "resume", style = "accent" },
    { id = "settings", style = "accent" },
    { id = "restart", style = "danger" },
    { id = "to_title", style = "danger" },
}

function PauseModal.open(actions)
    return PauseModal(actions)
end

function PauseModal:new(actions)
    self.kind = "menu"
    self.closed = false
    self._actions = actions
    self._confirming = false    -- [처음부터 다시하기] 2단계 확인 화면인지
    self._settings = nil
    self._modal = Modal({
        title = function() return I18n.t("pause.title") end,
        subtitle = function() return I18n.t(self._confirming and "pause.confirm_subtitle" or "pause.subtitle") end,
        rows = function() return self:_rows() end,
        footer = function() return self:_footer() end,
        on_cancel = function() self:_back() end,
    })
end

function PauseModal:is_confirming()
    return self._confirming
end

function PauseModal:settings_modal()
    return self._settings
end

function PauseModal:_select(id)
    if id == "resume" then
        self:_resume()
    elseif id == "settings" then
        self._settings = SettingsModal.open()
    elseif id == "restart" then
        self._confirming = true     -- 1단계: 확인 화면으로 (실제 재시작은 [다시 시작]을 한 번 더 눌러야 한다)
    elseif id == "to_title" then
        self.closed = true
        self._actions.to_title()
    end
end

function PauseModal:_rows()
    if self._confirming then
        return { { title = I18n.t("pause.confirm"), text = I18n.t("pause.confirm_text"), color = { 0.95, 0.38, 0.38 } } }
    end
    local rows = {}
    for i, row in ipairs(ROWS) do
        rows[i] = {
            title = I18n.t("pause." .. row.id), text = I18n.t("pause." .. row.id .. "_text"),
            button = {
                label = function() return I18n.t("pause." .. row.id .. "_button") end,
                style = row.style,
                on_click = function() self:_select(row.id) end,
            },
        }
    end
    return rows
end

function PauseModal:_footer()
    if not self._confirming then
        return {}
    end
    return {
        { label = function() return I18n.t("pause.confirm_yes") end, style = "danger", on_click = function()
            self.closed = true
            self._actions.restart()
        end },
        { label = function() return I18n.t("pause.confirm_no") end, on_click = function() self._confirming = false end },
    }
end

function PauseModal:_resume()
    self.closed = true
    self._actions.resume()
end

-- ESC: 확인 화면 → 메뉴, 메뉴 → 게임
function PauseModal:_back()
    if self._confirming then
        self._confirming = false
    else
        self:_resume()
    end
end

function PauseModal:update(dt, pointer_x, pointer_y)
    if self._settings ~= nil then
        self._settings:update(dt, pointer_x, pointer_y)
        if self._settings.closed then
            self._settings = nil
        end
        return
    end
    self._modal:update(dt, pointer_x, pointer_y)
end

function PauseModal:mousepressed(x, y)
    if self._settings ~= nil then
        return self._settings:mousepressed(x, y)
    end
    return self._modal:mousepressed(x, y)
end

function PauseModal:keypressed(key)
    if self._settings ~= nil then
        self._settings:keypressed(key)
    elseif Input.is_action(key, "back") then
        self._modal:keypressed(key)
    end
end

function PauseModal:draw()
    if self._settings ~= nil then
        self._settings:draw()
    else
        self._modal:draw()
    end
end

return PauseModal
