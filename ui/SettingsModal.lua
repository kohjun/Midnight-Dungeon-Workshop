-- ui/SettingsModal.lua
-- 환경 설정 모달 (시스템 메뉴 · 타이틀 화면에서 연다). 항목 정의는 data/settings.lua, 값은 systems/Settings.
--   choice / toggle 항목 : 선택지 버튼 줄 (현재 값이 강조된다) — 언어 · 음소거 · 화면 모드 · 흔들림 · 밤 배속
--   percent 항목        : [-] 막대 [+] 와 수치 (막대를 눌러 바로 지정) — 마스터 · 효과음 · 배경음 볼륨
-- 바꾸는 즉시 적용·저장된다 (언어는 재시작 없이 화면 전체에 반영).
-- 좌표: SettingsModal.option_rect(key, index) / step_rect(key, direction) / back_rect() (스모크 테스트용).

local Class = require("lib.classic")
local Tween = require("lib.tween")
local Input = require("core.Input")
local Viewport = require("core.Viewport")
local I18n = require("systems.I18n")
local Settings = require("systems.Settings")
local Button = require("ui.Button")
local Draw = require("ui.Draw")
local Lettering = require("ui.Lettering")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local SettingsModal = Class:extend()

local C = UI.color
local SIZE = UI.font_size
local M = LAYOUT.modal
local S = LAYOUT.settings
local VALUE_W = 64          -- percent 항목 오른쪽 수치 칸
local TOGGLE_VALUES = { false, true }
local TOGGLE_KEYS = { "off", "on" }

local function row_index(key)
    for index, id in ipairs(Settings.order()) do
        if id == key then
            return index
        end
    end
    error("SettingsModal: unknown option '" .. tostring(key) .. "'")
end

local function row_y(key)
    return M.y + S.row_top + (row_index(key) - 1) * S.row_h
end

local function control_y(key)
    return row_y(key) + (S.row_h - S.option_h) / 2
end

local function option_values(key)
    local option = Settings.definition(key)
    return option.kind == "toggle" and TOGGLE_VALUES or option.choices
end

-- 선택지 버튼 영역 (index: 선택지 순서, toggle 은 1 = off / 2 = on)
function SettingsModal.option_rect(key, index)
    local count = #option_values(key)
    local width = (S.control_w - S.option_gap * (count - 1)) / count
    return { x = M.x + S.control_x + (index - 1) * (width + S.option_gap), y = control_y(key), w = width, h = S.option_h }
end

-- percent 항목의 [-] (direction -1) / [+] (direction +1) 버튼 영역
function SettingsModal.step_rect(key, direction)
    local x = M.x + S.control_x
    if direction > 0 then
        x = x + S.control_w - VALUE_W - S.step_w
    end
    return { x = x, y = control_y(key), w = S.step_w, h = S.option_h }
end

local function bar_rect(key)
    local x = M.x + S.control_x + S.step_w + 12
    local right = M.x + S.control_x + S.control_w - VALUE_W - S.step_w - 12
    return { x = x, y = control_y(key) + S.option_h / 2 - 7, w = right - x, h = 14 }
end

function SettingsModal.back_rect()
    return { x = M.x + (M.w - M.footer_w) / 2, y = M.y + M.h - M.footer_h - 16, w = M.footer_w, h = M.footer_h }
end

function SettingsModal.open()
    return SettingsModal()
end

function SettingsModal:new()
    self.kind = "settings"
    self.closed = false
    self._anim = { scale = 0.92, alpha = 0 }
    self._tweens = Tween.Group()
    self._tweens:to(self._anim, 0.22, { scale = 1, alpha = 1 }):ease("out_back")
    self._buttons = {}
    self._bars = {}     -- percent 항목 키 목록
    for _, key in ipairs(Settings.order()) do
        if Settings.definition(key).kind == "percent" then
            self:_add_percent(key)
        else
            self:_add_options(key)
        end
    end
    self:_add(SettingsModal.back_rect(), function() return I18n.t("settings.back") end, {
        style = "accent", on_click = function() self.closed = true end,
    })
end

function SettingsModal:_add(rect, label, opts)
    self._buttons[#self._buttons + 1] = Button(rect, label, opts)
end

function SettingsModal:_add_options(key)
    local toggle = Settings.definition(key).kind == "toggle"
    for index, value in ipairs(option_values(key)) do
        local label_key = "settings.choices." .. key .. "." .. (toggle and TOGGLE_KEYS[index] or index)
        self:_add(SettingsModal.option_rect(key, index), function() return I18n.t(label_key) end, {
            style = "tool",
            active = function() return Settings.get(key) == value end,
            on_click = function() Settings.set(key, value) end,
        })
    end
end

function SettingsModal:_add_percent(key)
    self._bars[#self._bars + 1] = key
    for _, direction in ipairs({ -1, 1 }) do
        self:_add(SettingsModal.step_rect(key, direction), direction < 0 and "-" or "+", {
            enabled = function()
                local value = Settings.get(key)
                return (direction < 0 and value > 0) or (direction > 0 and value < 100)
            end,
            on_click = function() Settings.step(key, direction) end,
        })
    end
end

function SettingsModal:update(dt, pointer_x, pointer_y)
    self._tweens:update(dt)
    for _, button in ipairs(self._buttons) do
        button:update(dt, pointer_x, pointer_y)
    end
end

-- 모달이 열려 있으면 모든 클릭을 소비한다
function SettingsModal:mousepressed(x, y)
    for _, button in ipairs(self._buttons) do
        if button:contains(x, y) then
            button:press()
            return true
        end
    end
    for _, key in ipairs(self._bars) do     -- 막대를 직접 눌러 값 지정 (step 단위로 맞춘다)
        local bar = bar_rect(key)
        if x >= bar.x - 6 and x <= bar.x + bar.w + 6 and y >= bar.y - 10 and y <= bar.y + bar.h + 10 then
            local step = Settings.definition(key).step
            local ratio = math.max(0, math.min(1, (x - bar.x) / bar.w))
            Settings.set(key, math.floor(ratio * 100 / step + 0.5) * step)
            return true
        end
    end
    return true
end

function SettingsModal:keypressed(key)
    if Input.is_action(key, "back") then
        self.closed = true
    end
end

function SettingsModal:_draw_rows()
    local label_h = Draw.font(SIZE.body):getHeight()
    for index, key in ipairs(Settings.order()) do
        local y = row_y(key)
        if index % 2 == 1 then
            Draw.set_color({ 1, 1, 1 }, 0.03)
            love.graphics.rectangle("fill", M.x + 20, y, M.w - 40, S.row_h, 6, 6)
        end
        Draw.text(I18n.t("settings." .. key), M.x + S.label_x, y + (S.row_h - label_h) / 2, S.label_w, "left", SIZE.body, C.text)
    end
    local muted = Settings.get("mute")
    for _, key in ipairs(self._bars) do
        local bar = bar_rect(key)
        local value = Settings.get(key)
        Draw.bar(bar.x, bar.y, bar.w, bar.h, value / 100, muted and C.text_dim or C.accent)
        Draw.text(I18n.t("settings.percent", { value = value }), bar.x + bar.w + S.step_w + 20, bar.y - 4, VALUE_W, "right",
            SIZE.body, muted and C.text_dim or C.text)
    end
end

function SettingsModal:draw()
    local alpha = self._anim.alpha
    love.graphics.setColor(0, 0, 0, 0.62 * alpha)
    love.graphics.rectangle("fill", 0, 0, Viewport.width(), Viewport.height())

    love.graphics.push()
    love.graphics.translate(M.x + M.w / 2, M.y + M.h / 2)
    love.graphics.scale(self._anim.scale)
    love.graphics.translate(-(M.x + M.w / 2), -(M.y + M.h / 2))
    Draw.panel(M.x, M.y, M.w, M.h, { 0.07, 0.07, 0.10, 0.98 }, C.accent, 14)
    Lettering.draw(I18n.t("settings.title"), M.x, M.y + 14, M.w, "center", "title", "gold")
    Draw.text(I18n.t("settings.subtitle"), M.x + 30, M.y + 52, M.w - 60, "center", SIZE.small, C.text_dim)
    self:_draw_rows()
    for _, button in ipairs(self._buttons) do
        button:draw()
    end
    love.graphics.pop()
end

return SettingsModal
