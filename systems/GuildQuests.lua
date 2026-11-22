-- systems/GuildQuests.lua
-- 던전 관리 길드 의뢰 게시판 (data/quests.lua · 규칙 systems/QuestRules). first_day 부터 매일 아침 하나씩 게시될 수 있다
-- ("quests" 난수 스트림, 대기·진행 중 의뢰가 max_board 개 미만일 때). 4분야: 단조 유물 납품 · 감정 적발 · 전투 · 정화 납품.
--   pending  → [의뢰] 창(ui/QuestModal)에서 수락/거절 (낮에만). 수락하지 않으면 그날 밤이 시작될 때 내려간다 (quest:expired, 벌칙 없음)
--   accepted → 기한(deadline 일차의 밤이 끝나는 새벽)까지 달성하면 즉시 보상 (quest:completed)
--              납품 의뢰는 [납품](deliver) — 보관함·작업대에서 조건에 맞는 유물을 넘긴다 (유물은 사라진다, quest:delivered)
--              적발(위조 인장·숨은 저주)·보스 처치는 이벤트로 센다 — 구독은 생성자에서 한 번 (이어하기 뒤에도 그대로 동작)
--              과부하 시험은 새벽(settle_night)에 그 밤의 과부하 유지 시간(Combat.overclock_time)으로 판정
--   기한 초과 → 실패 (quest:failed): 위약금(penalty)을 즉시 차감, 골드가 모자라면 남은 몫은 다음 결계 유지비에 가산
--   done / failed → 다음 날 아침 게시판에서 내려간다.
-- 보상: 골드 · 연마석 · 다음 결계 유지비 할인(Tribute:discount_ratio_next) · 방벽 긴급 수리(heal). 그리기 금지.

local Class = require("lib.classic")
local EventBus = require("core.EventBus")
local RNG = require("core.RNG")
local QuestRules = require("systems.QuestRules")
local QUESTS = require("data.quests")

local GuildQuests = Class:extend()

function GuildQuests:new(workshop)
    self._workshop = workshop
    self.board = {}     -- { id, kind, category, risk, state, progress, target, posted, deadline, reward, penalty [, level, grade, element] }
    local options = { owner = self, priority = -60 }
    EventBus.subscribe("appraisal:forgery_revealed", function(p)
        if p.item ~= nil and not p.item.owned then
            self:_advance("expose")
        end
    end, options)
    EventBus.subscribe("appraisal:flaw_revealed", function(p)
        if p.item ~= nil and not p.item.owned and p.item.flaw == "curse" then
            self:_advance("expose")
        end
    end, options)
    EventBus.subscribe("combat:monster_killed", function(p)
        if p.monster:is_boss() or p.monster:is_midboss() then       -- 월말 대보스 · 월 중순 중간 보스
            self:_advance("boss")
        end
    end, options)
end

function GuildQuests:destroy()
    EventBus.unsubscribe_owner(self)
end

function GuildQuests:_advance(kind)
    for _, quest in ipairs(self.board) do
        if quest.state == "accepted" and quest.kind == kind then
            quest.progress = quest.progress + 1
            if quest.progress >= quest.target then
                self:_complete(quest)
            end
        end
    end
end

function GuildQuests:has(id)
    for _, quest in ipairs(self.board) do
        if quest.id == id then
            return true
        end
    end
    return false
end

-- 아침 게시 (DayCycle): 끝난 의뢰를 내리고, 자리가 있으면 확률로 하나 게시
function GuildQuests:roll(day)
    local kept = {}
    for _, quest in ipairs(self.board) do
        if quest.state == "pending" or quest.state == "accepted" then
            kept[#kept + 1] = quest
        end
    end
    self.board = kept
    if day < QUESTS.first_day or #self.board >= QUESTS.max_board then
        return nil
    end
    local rng = RNG.stream("quests")
    if not rng:chance(QUESTS.daily_chance) then
        return nil
    end
    local entries = {}
    for _, id in ipairs(QUESTS.order) do
        if not self:has(id) and QuestRules.can_post(id, self._workshop, day) then
            entries[#entries + 1] = { id = id, weight = QUESTS.quests[id].weight }
        end
    end
    if #entries == 0 then
        return nil
    end
    return self:post(rng:weighted_pick(entries).id, day)
end

-- 의뢰 게시 (options.element: 정화 납품 속성 지정). 기한을 잡을 수 없으면(보스 밤 없음) nil
function GuildQuests:post(id, day, options)
    assert(QUESTS.quests[id] ~= nil, "GuildQuests: unknown quest '" .. tostring(id) .. "'")
    local quest = QuestRules.build(id, self._workshop, day or self._workshop.day, RNG.stream("quests"), options)
    if quest.deadline == nil then
        return nil
    end
    self.board[#self.board + 1] = quest
    EventBus.emit("quest:posted", { id = id, source = "guild", quest = quest })
    return quest
end

-- 그 상태의 첫 의뢰와 번호
function GuildQuests:first(state)
    for index, quest in ipairs(self.board) do
        if quest.state == state then
            return quest, index
        end
    end
    return nil
end

function GuildQuests:is_pending()
    return self:first("pending") ~= nil
end

function GuildQuests:pending_count()
    local count = 0
    for _, quest in ipairs(self.board) do
        count = count + (quest.state == "pending" and 1 or 0)
    end
    return count
end

-- [의뢰] 배지: 수락·거절을 기다리는 제안 수 (길드 의뢰 + 암시장 제안)
function GuildQuests:pending_total()
    return self:pending_count() + (self._workshop.black_market:is_pending() and 1 or 0)
end

local function resolve(self, index)
    if index == nil then
        return self:first("pending")
    end
    return self.board[index], index
end

-- 수락 (index 생략 = 첫 대기 의뢰). 낮에만
function GuildQuests:accept(index)
    local quest = resolve(self, index)
    if quest == nil or quest.state ~= "pending" or not self._workshop:is_day() then
        return false
    end
    quest.state = "accepted"
    EventBus.emit("quest:accepted", { id = quest.id, source = "guild", quest = quest })
    return true
end

function GuildQuests:decline(index)
    local quest, at = resolve(self, index)
    if quest == nil or quest.state ~= "pending" or not self._workshop:is_day() then
        return false
    end
    table.remove(self.board, at)
    EventBus.emit("quest:declined", { id = quest.id, source = "guild", quest = quest })
    return true
end

-- [납품]을 누를 수 없는 사유 (로케일 키) — 누를 수 있으면 nil
function GuildQuests:delivery_block(quest)
    if quest == nil or quest.state ~= "accepted" or not QuestRules.is_delivery(quest) then
        return "quest_ui.deliver_none"
    elseif not self._workshop:is_day() then
        return "quest_ui.day_only"
    elseif QuestRules.candidate(self._workshop, quest) == nil then
        return "quest_ui.deliver_missing"
    end
    return nil
end

-- 납품: 조건에 맞는 유물(보관함·작업대, 가장 싼 것)을 넘기고 보상
function GuildQuests:deliver(index)
    local quest = self.board[index]
    if self:delivery_block(quest) ~= nil then
        return false
    end
    local item = QuestRules.candidate(self._workshop, quest)
    self._workshop.inventory:remove(item)
    quest.progress = quest.target
    EventBus.emit("quest:delivered", { id = quest.id, item = item, quest = quest })
    self:_complete(quest)
    return true
end

function GuildQuests:_complete(quest)
    if quest.state ~= "accepted" then
        return
    end
    quest.state = "done"
    local workshop, reward = self._workshop, quest.reward
    workshop:add_gold(reward.gold, "quest")
    workshop:add_stones(reward.stones, "quest")
    local discount = 0
    if reward.discount > 0 then
        discount = select(2, workshop.tribute:discount_ratio_next(workshop.day, reward.discount))
    end
    local repaired = reward.repair > 0 and workshop:heal(reward.repair, "quest") or 0
    EventBus.emit("quest:completed", {
        id = quest.id, source = "guild", gold = reward.gold, stones = reward.stones, discount = discount, repair = repaired, quest = quest,
    })
end

-- 기한 초과: 위약금 즉시 차감, 모자란 몫은 다음 결계 유지비에 가산 (오늘 새벽 징수가 아니라 그다음 징수)
function GuildQuests:_fail(quest)
    quest.state = "failed"
    local workshop = self._workshop
    local paid = math.min(workshop.gold, quest.penalty)
    if paid > 0 then
        workshop:spend_gold(paid, "quest_penalty")
    end
    local rest = quest.penalty - paid
    if rest > 0 and workshop.tribute:surcharge_next(workshop.day + 1, rest) == nil then
        rest = 0
    end
    quest.paid, quest.surcharge = paid, rest
    EventBus.emit("quest:failed", { id = quest.id, source = "guild", fine = quest.penalty, paid = paid, surcharge = rest, quest = quest })
end

-- 밤 시작: 수락하지 않은 의뢰는 내려간다
function GuildQuests:night_started()
    local kept = {}
    for _, quest in ipairs(self.board) do
        if quest.state == "pending" then
            EventBus.emit("quest:expired", { id = quest.id, source = "guild", quest = quest })
        else
            kept[#kept + 1] = quest
        end
    end
    self.board = kept
end

-- 밤이 끝난 직후 (상납 징수 전): 과부하 시험 판정 → 기한이 오늘까지인 미완료 의뢰는 실패
function GuildQuests:settle_night()
    local workshop = self._workshop
    local held = workshop.combat.overclock_time or 0
    for _, quest in ipairs(self.board) do
        if quest.state == "accepted" and quest.kind == "overclock" then
            quest.progress = math.max(quest.progress, math.floor(held))
            if held >= quest.target and workshop.result == nil then
                self:_complete(quest)
            end
        end
        if quest.state == "accepted" and workshop.day >= quest.deadline then
            self:_fail(quest)
        end
    end
end

return GuildQuests
