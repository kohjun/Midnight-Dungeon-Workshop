-- systems/QuestRules.lua
-- 길드 의뢰 규칙 (data/quests.lua) — systems/GuildQuests 가 쓰는 순수 함수: 의뢰 만들기(목표·기한·보상·위약금),
-- 게시 가능 여부(보스 토벌은 가까운 보스 밤이 있을 때만), 납품 조건 판정·납품할 유물 고르기. 상태 없음, 그리기 금지.

local Calendar = require("systems.Calendar")
local WaveSpawner = require("systems.WaveSpawner")
local QUESTS = require("data.quests")
local ITEMS = require("data.items")

local QuestRules = {}

local DELIVERY_AREAS = { "storage", "bench" }      -- 납품은 보관함·작업대에서만 (진열장 무기를 실수로 넘기지 않게)

local function tier_value(list, tier)
    return list[math.max(1, math.min(#list, tier))]
end

function QuestRules.is_delivery(quest)
    return quest ~= nil and (quest.kind == "deliver_forged" or quest.kind == "deliver_clean")
end

-- 정화 납품 속성 판정: 아키타입 · 피해 속성 · 원형 id 중 하나라도 맞으면 그 속성
function QuestRules.element_matches(element, item)
    local spec = QUESTS.elements[element]
    if spec == nil then
        return false
    end
    local proto = item.proto
    if (spec.archetype ~= nil and proto.archetype == spec.archetype) or (spec.damage_type ~= nil and proto.damage_type == spec.damage_type) then
        return true
    end
    for _, id in ipairs(spec.ids or {}) do
        if item.proto_id == id then
            return true
        end
    end
    return false
end

function QuestRules.matches(quest, item)
    if item == nil or not item.owned then
        return false
    end
    if quest.kind == "deliver_forged" then
        return item.level >= quest.level and ITEMS.grades[item.grade].rank >= ITEMS.grades[quest.grade].rank
    elseif quest.kind == "deliver_clean" then
        return item.cleaned == true and QuestRules.element_matches(quest.element, item)
    end
    return false
end

-- 납품할 유물: 보관함·작업대의 조건에 맞는 보유 유물 중 판매가가 가장 낮은 것 (없으면 nil)
function QuestRules.candidate(workshop, quest)
    local best, best_price = nil, math.huge
    for _, area in ipairs(DELIVERY_AREAS) do
        for index = 1, workshop.inventory:size(area) do
            local item = workshop.inventory:get(area, index)
            if QuestRules.matches(quest, item) and not workshop.forge:is_locked(item) then
                local price = workshop:sale_price(item)
                if price < best_price then
                    best, best_price = item, price
                end
            end
        end
    end
    return best
end

-- day 부터 within 일 안의 보스 밤 (월 중순 중간 보스 · 월말 대보스, 계약 기간 안). 없으면 nil
function QuestRules.boss_day(workshop, day, within)
    for d = day, math.min(workshop.max_days, day + within) do
        if WaveSpawner.headliner(d) ~= nil then
            return d
        end
    end
    return nil
end

function QuestRules.can_post(id, workshop, day)
    local spec = QUESTS.quests[id]
    if spec.kind == "boss" then
        return QuestRules.boss_day(workshop, day, spec.within) ~= nil
    end
    return day <= workshop.max_days
end

local function pick_element(spec, rng)
    local entries = {}
    for i, element in ipairs(spec.elements) do
        entries[i] = { id = element, weight = spec.element_weights[i] or 1 }
    end
    return rng:weighted_pick(entries).id
end

-- 새 의뢰 (게시일 day, 상태 pending). options.element 로 정화 납품 속성을 정할 수 있다 (스모크 테스트)
function QuestRules.build(id, workshop, day, rng, options)
    local spec = QUESTS.quests[id]
    local tier = workshop.rules.quest_tier or 1
    local growth = 1 + QUESTS.reward_growth * (Calendar.month(day) - 1)
    local gold = math.floor((spec.reward.gold or 0) * growth + 0.5)
    local quest = {
        id = id, kind = spec.kind, category = spec.category, risk = spec.risk, state = "pending", progress = 0, target = 1,
        posted = day, deadline = math.min(workshop.max_days, day + (spec.days or 1) - 1),
        reward = { gold = gold, stones = spec.reward.stones or 0, discount = spec.reward.discount or 0, repair = spec.reward.repair or 0 },
        penalty = math.floor(gold * QUESTS.penalty_ratio + 0.5),
    }
    if spec.targets ~= nil then
        quest.target = tier_value(spec.targets, tier)
    end
    if spec.kind == "deliver_forged" then
        quest.level, quest.grade = tier_value(spec.levels, tier), tier_value(spec.grades, tier)
    elseif spec.kind == "deliver_clean" then
        quest.element = (options and options.element) or pick_element(spec, rng)
    elseif spec.kind == "boss" then
        quest.deadline = QuestRules.boss_day(workshop, day, spec.within)
        quest.boss, quest.boss_kind = WaveSpawner.headliner(quest.deadline, workshop.final_rules)    -- 캠페인 마지막 밤 = 최종 보스
    end
    return quest
end

return QuestRules
