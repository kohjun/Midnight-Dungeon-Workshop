-- ui/GuestReaction.lua
-- UV 감정으로 손님 유물의 숨긴 결함(저주 각인·균열)이나 등급 위조를 적발했을 때의 손님 반응. 규칙 계산 없음.
--   대사  : 모험가마다 성격에 맞는 당황·변명·인정 한마디 (로케일 adventurers.<id>.caught.{forgery, curse, crack}),
--           REACTION_TIME 동안 손님 카운터의 대사를 대신한다 (ui/CustomerCard)
--   초상  : 움찔 떨림 + 몸을 젖히거나 들이미는 기울기 (data/adventurers.lua 의 reaction — ui/AdventurerPortrait 가 받는다)
--   꼬리표: 감정 꼬리표의 등급(위조) / 결함(저주·균열) 줄이 잠깐 붉게 맥동한다 (ui/WorkbenchView)
-- 낙인 파동·스파크와 적발음은 ui/Feedback · systems/Audio. ui/AmbientEffects 가 소유한다.

local Class = require("lib.classic")
local EventBus = require("core.EventBus")
local I18n = require("systems.I18n")
local ADVENTURERS = require("data.adventurers")

local GuestReaction = Class:extend()

local REACTION_TIME = 5.0
local FLASH_TIME = 1.6
local PRIORITY = -100

function GuestReaction:new()
    self.state = nil        -- { uid, kind = "forgery" | "curse" | "crack", t }
    local function start(item, kind)
        if item ~= nil and not item.owned then
            self.state = { uid = item.uid, kind = kind, t = 0 }
        end
    end
    EventBus.subscribe("appraisal:flaw_revealed", function(p) start(p.item, p.item.flaw) end, { owner = self, priority = PRIORITY })
    EventBus.subscribe("appraisal:forgery_revealed", function(p) start(p.item, "forgery") end, { owner = self, priority = PRIORITY })
    EventBus.subscribe("appraisal:customer_arrived", function() self.state = nil end, { owner = self, priority = PRIORITY })
end

function GuestReaction:destroy()
    EventBus.unsubscribe_owner(self)
end

function GuestReaction:update(dt)
    if self.state ~= nil then
        self.state.t = self.state.t + dt
    end
end

local function active(self, item)
    local state = self.state
    return state ~= nil and item ~= nil and state.uid == item.uid and state or nil
end

-- 지금 보여 줄 적발 반응 대사 (없으면 nil)
function GuestReaction:line(item)
    local state = active(self, item)
    if state == nil or state.t > REACTION_TIME or item.adventurer == nil then
        return nil
    end
    return I18n.t("adventurers." .. item.adventurer .. ".caught." .. state.kind)
end

-- 초상 반응 포즈: dx(px), rot(라디안)
function GuestReaction:pose(item)
    local state = active(self, item)
    local data = item and item.adventurer and ADVENTURERS.list[item.adventurer]
    if state == nil or data == nil then
        return 0, 0
    end
    local t, reaction = state.t, data.reaction
    local dx = reaction.flinch * 6 * math.sin(t * 42) * math.exp(-t * 6)
    local rot = reaction.tilt * math.exp(-t * 2.5) * math.min(1, t * 10)
    return dx, rot
end

-- 감정 꼬리표 줄 강조 0~1. row: "grade"(위조) | "flaw"(저주·균열)
function GuestReaction:flash(item, row)
    local state = active(self, item)
    if state == nil or state.t > FLASH_TIME then
        return 0
    end
    if (row == "grade") ~= (state.kind == "forgery") then
        return 0
    end
    return (1 - state.t / FLASH_TIME) * (0.6 + 0.4 * math.sin(state.t * 18))
end

return GuestReaction
