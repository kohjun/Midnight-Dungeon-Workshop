-- ui/TutorialView.lua
-- 튜토리얼 화면: 스포트라이트 암막(ui/Spotlight — 설명 대상만 뚫고 나머지는 반투명 검정, 황금빛 맥동 테두리) +
-- 안내 띠(현재 단계 문구 · 진행도 · [다음] · [건너뛰기]). 안내 띠는 강조 영역과 겹치지 않는 후보 자리(LAYOUT.tutorial_banners)에 놓는다.
-- 대상 클릭은 막지 않는다 (띠의 버튼만 입력을 먹는다). 단계 판정은 systems/Tutorial — 여기서는 current_step() 을 읽어 그리기만 한다.

local Class = require("lib.classic")
local Tween = require("lib.tween")
local EventBus = require("core.EventBus")
local I18n = require("systems.I18n")
local Button = require("ui.Button")
local Slots = require("ui.Slots")
local Draw = require("ui.Draw")
local Spotlight = require("ui.Spotlight")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local TutorialView = Class:extend()

local C = UI.color
local SIZE = UI.font_size
local LABEL_W = 84
local PAD = 6                   -- 스포트라이트 여백 (대상 사각형 바깥으로)
local MAX_HINT_LINES = 3
local BANNERS = LAYOUT.tutorial_banners
-- 강조 대상 → 사각형 (버튼·슬롯 외의 고정 영역)
local AREAS = {
    workbench = LAYOUT.day.workbench, storage = LAYOUT.day.storage_section, counter = LAYOUT.day.customer_card,
    tag = LAYOUT.day.appraisal_tag, furnace = LAYOUT.day.furnace_section, lever = LAYOUT.night.lever_panel, lane = LAYOUT.night.lane,
}

function TutorialView:new(workshop)
    self._workshop = workshop
    self._anim = { pop = 1 }
    self._tweens = Tween.Group()
    self._skip = Button({ x = 0, y = 0, w = 1, h = 1 }, function() return I18n.t("tutorial.skip") end,
        { on_click = function() workshop.tutorial:skip() end })
    -- 안내 단계(info)에서만 보이는 [다음]
    self._next = Button({ x = 0, y = 0, w = 1, h = 1 }, function() return I18n.t("tutorial.next") end, {
        style = "accent", on_click = function() workshop.tutorial:next() end,
        visible = function()
            local step = workshop.tutorial and workshop.tutorial:current_step()
            return step ~= nil and step.info == true
        end,
    })
    EventBus.subscribe("tutorial:step_changed", function()
        self._anim.pop = 1.12
        self._tweens:clear()
        self._tweens:to(self._anim, 0.35, { pop = 1 }):ease("out_back")
    end, { owner = self })
end

function TutorialView:destroy()
    EventBus.unsubscribe_owner(self)
end

function TutorialView:is_visible()
    local tutorial = self._workshop.tutorial
    return tutorial ~= nil and tutorial:is_active()
end

-- "button:<id>" | "slot:<area>" | "area:<name>" | "hud:<card>" → x, y, w, h (여백 전)
function TutorialView.target_rect(target, input)
    local kind, name = target:match("^(%w+):([%w_]+)$")
    if kind == "button" then
        local rect = input:button(name).rect
        return rect.x, rect.y, rect.w, rect.h
    elseif kind == "slot" then
        return Slots.rect(name, 1)
    elseif kind == "area" and name == "grid" then
        return Slots.grid_bounds()
    elseif kind == "area" and AREAS[name] ~= nil then
        local r = AREAS[name]
        return r.x, r.y, r.w, r.h
    elseif kind == "hud" and LAYOUT.hud[name] ~= nil then
        local r = LAYOUT.hud[name]
        return r.x, r.y, r.w, r.h
    end
    error("TutorialView: unknown highlight target '" .. tostring(target) .. "'")
end

-- 지금 보이는 강조 대상들의 스포트라이트 사각형 (여백 포함)
function TutorialView:spot_rects(input)
    local rects, step = {}, self:_step()
    for _, target in ipairs(step and step.highlight or {}) do
        local area = target:match("^slot:(.+)$") or (target == "area:grid" and "grid") or nil
        local button = target:match("^button:(.+)$")
        if (area == nil or Slots.is_visible(area)) and (button == nil or input:button(button):is_visible()) then
            local x, y, w, h = TutorialView.target_rect(target, input)
            rects[#rects + 1] = { x = x - PAD, y = y - PAD, w = w + PAD * 2, h = h + PAD * 2 }
        end
    end
    return rects
end

function TutorialView:_step()
    local tutorial = self._workshop.tutorial
    return tutorial and tutorial:current_step()
end

local function overlaps(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

-- 안내 띠 자리: 스포트라이트와 겹치지 않는 첫 후보 (모두 겹치면 첫 후보)
function TutorialView:banner_rect()
    local list = Slots.mode() == "night" and BANNERS.night or BANNERS.day
    local rects = self._input and self:spot_rects(self._input) or {}
    for _, candidate in ipairs(list) do
        local free = true
        for _, r in ipairs(rects) do
            free = free and not overlaps(candidate, r)
        end
        if free then
            return candidate
        end
    end
    return list[1]
end

-- 안내 띠의 [건너뛰기] · [다음] 자리 (스모크 테스트도 같은 좌표를 쓴다)
function TutorialView:skip_rect()
    local banner = self:banner_rect()
    return { x = banner.x + banner.w - BANNERS.skip_w - 8, y = banner.y + 14, w = BANNERS.skip_w, h = banner.h - 28 }
end

function TutorialView:next_rect()
    local skip = self:skip_rect()
    return { x = skip.x - skip.w - 8, y = skip.y, w = skip.w, h = skip.h }
end

local function place(button, rect)
    button.rect.x, button.rect.y, button.rect.w, button.rect.h = rect.x, rect.y, rect.w, rect.h
end

function TutorialView:update(dt, pointer_x, pointer_y, input)
    self._tweens:update(dt)
    self._input = input
    place(self._skip, self:skip_rect())
    place(self._next, self:next_rect())
    if self:is_visible() then
        self._skip:update(dt, pointer_x, pointer_y)
        self._next:update(dt, pointer_x, pointer_y)
    end
end

-- 건너뛰기 버튼을 눌렀으면 true (입력 소비)
function TutorialView:mousepressed(x, y)
    if not self:is_visible() then
        return false
    end
    for _, button in ipairs({ self._skip, self._next }) do
        if button:contains(x, y) then
            button:press()
            return true
        end
    end
    return false
end

function TutorialView:_draw_banner(step, tutorial)
    local banner = self:banner_rect()
    love.graphics.push()
    love.graphics.translate(banner.x + banner.w / 2, banner.y + banner.h / 2)
    love.graphics.scale(self._anim.pop)
    local x, y = -banner.w / 2, -banner.h / 2
    Draw.panel(x, y, banner.w, banner.h, { 0.04, 0.03, 0.06, 0.94 }, C.accent, 10)
    Draw.text(I18n.t("tutorial.label"), x + 12, y + banner.h / 2 - 19, LABEL_W, "left", SIZE.tiny, C.accent)
    Draw.text(string.format("%d / %d", tutorial.index, tutorial:step_count()), x + 12, y + banner.h / 2 - 2, LABEL_W, "left",
        SIZE.small, C.text)
    local text_w = banner.w - LABEL_W - BANNERS.skip_w * (self._next:is_visible() and 2 or 1) - 40
    local hint = tutorial:hint_text(step)
    local size = SIZE.small
    local _, wrapped = Draw.font(size):getWrap(hint, text_w)
    if #wrapped > MAX_HINT_LINES then      -- 언어에 따라 길어지면 작은 글자로 줄인다
        size = SIZE.tiny
        _, wrapped = Draw.font(size):getWrap(hint, text_w)
    end
    local text_y = y + (banner.h - #wrapped * Draw.font(size):getHeight()) / 2
    Draw.text(hint, x + LABEL_W + 12, text_y, text_w, "left", size, C.text)
    love.graphics.pop()
    self._skip:draw()
    self._next:draw()
end

function TutorialView:draw(input, time)
    if not self:is_visible() then
        return
    end
    local tutorial = self._workshop.tutorial
    local step = tutorial:current_step()
    self._input = input
    Spotlight.draw(self:spot_rects(input), time, step.dim == false and 0 or Spotlight.DIM)
    self:_draw_banner(step, tutorial)
end

return TutorialView
