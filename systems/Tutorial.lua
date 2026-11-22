-- systems/Tutorial.lua
-- Day 1 고정 시나리오 튜토리얼 단계 머신. 단계 정의·잠금 규칙은 data/tutorial.lua.
-- 게임 이벤트를 구독해 진행하고, 이후 단계의 완료 이벤트가 먼저 오면 그 단계까지 건너뛴다.
-- 그리기 금지 — 안내 띠·강조 표시는 ui/TutorialView 가 current_step() 을 읽어 그린다.

local Class = require("lib.classic")
local EventBus = require("core.EventBus")
local Item = require("entities.Item")
local I18n = require("systems.I18n")
local Progress = require("systems.Progress")
local TUTORIAL = require("data.tutorial")

local Tutorial = Class:extend()

-- 단계 완료 추가 조건
local CONDITIONS = {
    grid_not_empty = function(workshop)
        return workshop.inventory:count("grid") > 0
    end,
}

local function contains(list, value)
    for _, entry in ipairs(list or {}) do
        if entry == value then
            return true
        end
    end
    return false
end

function Tutorial:new(workshop)
    self._workshop = workshop
    self.index = 0
    self.active = false
    self.finished = false
end

function Tutorial:destroy()
    EventBus.unsubscribe_owner(self)
end

-- 첫 손님(균열 숨긴 화염 검)을 작업대에 올리고 1단계 시작
function Tutorial:start()
    self.active = true
    local watched = {}
    for _, step in ipairs(TUTORIAL.steps) do
        if not watched[step.complete_on] then
            watched[step.complete_on] = true
            EventBus.subscribe(step.complete_on, function()
                self:_on_event(step.complete_on)
            end, { owner = self, priority = -50 })
        end
    end
    EventBus.subscribe("forge:failed", function()
        EventBus.emit("ui:message", { text = I18n.t("tutorial.exploded"), kind = "warn" })
    end, { owner = self, priority = -50 })

    local spec = TUTORIAL.first_customer
    local item = Item(spec.proto, {
        grade = spec.grade, claimed_grade = spec.claimed_grade, flaw = spec.flaw,
        flaw_mark = spec.flaw_mark, contamination = spec.contamination, grime = spec.grime, adventurer = spec.adventurer,
    })
    self:_go_to(1)
    self._workshop.appraisal:present_customer(item)
end

function Tutorial:is_active()
    return self.active
end

function Tutorial:current_step()
    if not self.active then
        return nil
    end
    return TUTORIAL.steps[self.index]
end

-- 배율 표기 (1.4 → "1.4", 2 → "2")
local function mult_text(value)
    return tostring(math.floor((value or 1) * 10 + 0.5) / 10)
end

-- 단계 안내 문구 (현재 언어, {name} / {address} 를 플레이어 이름으로, {rate} / {gold} 를 이 계약의 과부하 배율로 치환)
function Tutorial:hint_text(step)
    local rules = self._workshop.overclock_rules or {}
    local text = I18n.t("tutorial.steps." .. step.id, { rate = mult_text(rules.rate_mult), gold = mult_text(rules.gold_mult) })
    return self._workshop:personalize(text)
end

-- 읽는 동안 밤 전투를 멈추는 단계인지 (data/tutorial.lua 의 pause, RunState 가 매 프레임 본다)
function Tutorial:is_pausing()
    local step = self:current_step()
    return step ~= nil and step.pause == true and self._workshop.phase == "night"
end

function Tutorial:step_count()
    return #TUTORIAL.steps
end

-- 튜토리얼 중 행동 허용 여부 (끝났거나 꺼져 있으면 항상 허용)
function Tutorial:allows(action)
    local step = self:current_step()
    return step == nil or not contains(TUTORIAL.locks[action], step.id)
end

function Tutorial:keeps_purchase_on_bench()
    local step = self:current_step()
    return step ~= nil and contains(TUTORIAL.keep_purchase_on_bench, step.id)
end

-- 안내 단계(info)의 [다음]: 지금 단계만 끝낸다 (다른 안내 단계까지 건너뛰지 않는다)
function Tutorial:next()
    local step = self:current_step()
    if step == nil or not step.info then
        return false
    end
    if self.index >= #TUTORIAL.steps then
        self:_finish(false)
    else
        self:_go_to(self.index + 1)
    end
    return true
end

function Tutorial:skip()
    if self.active then
        self:_finish(true)
    end
end

function Tutorial:_step_done(step, event)
    if step.complete_on ~= event then
        return false
    end
    local condition = step.condition and CONDITIONS[step.condition]
    assert(step.condition == nil or condition ~= nil, "Tutorial: unknown condition '" .. tostring(step.condition) .. "'")
    return condition == nil or condition(self._workshop)
end

function Tutorial:_on_event(event)
    if not self.active then
        return
    end
    -- 현재 단계부터 뒤로 훑어 가장 먼 완료 단계까지 진행
    local reached = nil
    for i = self.index, #TUTORIAL.steps do
        if self:_step_done(TUTORIAL.steps[i], event) then
            reached = i
        end
    end
    if reached == nil then
        return
    end
    if reached >= #TUTORIAL.steps then
        self:_finish(false)
    else
        self:_go_to(reached + 1)
    end
end

function Tutorial:_go_to(index)
    self.index = index
    local step = TUTORIAL.steps[index]
    EventBus.emit("tutorial:step_changed", { step = step.id, index = index, total = #TUTORIAL.steps, hint = self:hint_text(step) })
end

function Tutorial:_finish(skipped)
    self.active = false
    self.finished = true
    EventBus.unsubscribe_owner(self)
    Progress.mark_tutorial_done()
    EventBus.emit("tutorial:completed", { skipped = skipped })
    if not skipped then
        EventBus.emit("ui:message", { text = self._workshop:personalize(I18n.t("tutorial.completed")), kind = "good" })
    end
end

return Tutorial
