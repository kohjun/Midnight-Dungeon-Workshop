-- ui/QuestText.lua
-- [의뢰] 창(ui/QuestModal)·토스트(ui/FeedbackEconomy)에 보일 의뢰 목록과 문구를 만든다 (현재 언어로, 그릴 때마다). 규칙 계산 없음.
--   QuestText.entries(workshop) → { { source = "market"|"guild", id, state, quest?, index? }, ... }
--     암시장 제안(systems/BlackMarket) 먼저, 그다음 길드 의뢰 게시판(systems/GuildQuests.board) 순서
--   QuestText.describe(workshop, entry) → { name, source, story, goal, reward, penalty, deadline?, risk, risk_level, progress? }
--   QuestText.name(quest) · QuestText.payout_text(payload) (의뢰 달성 토스트의 실제 보상)
-- 문구 키: 길드 의뢰 quests.<id>.{name, story, goal} · 암시장 events.<id>.name + market_quests.<id>.{story, goal, reward}
--          · quest_ui.* · risk.<level> (data/locales/<언어>/guild.lua)

local I18n = require("systems.I18n")
local QuestRules = require("systems.QuestRules")
local WaveSpawner = require("systems.WaveSpawner")
local CalendarText = require("ui.CalendarText")
local EVENTS = require("data.events")
local QUESTS = require("data.quests")

local QuestText = {}

function QuestText.entries(workshop)
    local list = {}
    local market = workshop.black_market
    if market.event ~= nil then
        list[#list + 1] = { source = "market", id = market.event, state = market.accepted and "accepted" or "pending" }
    end
    for index, quest in ipairs(workshop.quests.board) do
        list[#list + 1] = { source = "guild", id = quest.id, state = quest.state, quest = quest, index = index }
    end
    return list
end

-- 이름·조건 문구 변수 (속성 이름 · 보스 시기 · 보스 이름 · 등급 …)
local function vars(quest)
    local v = { target = quest.target, level = quest.level }
    if quest.element ~= nil then
        v.element = I18n.t("quest_ui.element." .. quest.element)
    end
    if quest.grade ~= nil then
        v.grade = I18n.grade(quest.grade)
    end
    if quest.kind == "boss" then
        local boss, kind = quest.boss, quest.boss_kind              -- 게시 때 정한 보스 (옛 저장이면 일정으로 다시 계산)
        if boss == nil then
            boss, kind = WaveSpawner.headliner(quest.deadline)
        end
        v.boss_time = I18n.t(kind == "midboss" and "quests.boss_time.mid" or "quests.boss_time.month_end")
        v.boss = I18n.t("monsters." .. boss)
        v.date = CalendarText.date(quest.deadline)
    end
    return v
end

function QuestText.name(quest)
    return I18n.t("quests." .. quest.id .. ".name", vars(quest))
end

local function join(parts)
    return table.concat(parts, I18n.t("quest_ui.reward_join"))
end

function QuestText.reward_text(reward)
    local parts = {}
    if (reward.gold or 0) > 0 then
        parts[#parts + 1] = I18n.t("quest_ui.reward_gold", { gold = reward.gold })
    end
    if (reward.stones or 0) > 0 then
        parts[#parts + 1] = I18n.t("quest_ui.reward_stones", { stones = reward.stones })
    end
    if (reward.discount or 0) > 0 then
        parts[#parts + 1] = I18n.t("quest_ui.reward_discount", { percent = math.floor(reward.discount * 100 + 0.5) })
    end
    if (reward.repair or 0) > 0 then
        parts[#parts + 1] = I18n.t("quest_ui.reward_repair", { amount = reward.repair })
    end
    return join(parts)
end

-- quest:completed 페이로드의 실제 지급분 (할인액 G · 실제 수리량)
function QuestText.payout_text(p)
    local parts = {}
    if (p.gold or 0) > 0 then
        parts[#parts + 1] = I18n.t("quest_ui.reward_gold", { gold = p.gold })
    end
    if (p.stones or 0) > 0 then
        parts[#parts + 1] = I18n.t("quest_ui.reward_stones", { stones = p.stones })
    end
    if (p.discount or 0) > 0 then
        parts[#parts + 1] = I18n.t("quest_ui.payout_discount", { amount = p.discount })
    end
    if (p.repair or 0) > 0 then
        parts[#parts + 1] = I18n.t("quest_ui.payout_repair", { amount = p.repair })
    end
    return join(parts)
end

-- 카드 한 줄 기한: "기한 2개월 3일 밤까지 (D-2)"
function QuestText.deadline_short(workshop, quest)
    local days = quest.deadline - workshop.day
    if days <= 0 then
        return I18n.t("quest_ui.card_deadline_today")
    end
    return I18n.t("quest_ui.card_deadline", { date = CalendarText.date(quest.deadline), days = days })
end

local function guild_progress(workshop, quest)
    if quest.state == "done" then
        return I18n.t("quest_ui.progress_done"), "good"
    elseif quest.state == "failed" then
        return I18n.t("quest_ui.progress_failed", { fine = quest.penalty, surcharge = quest.surcharge or 0 }), "bad"
    elseif quest.state ~= "accepted" then
        return nil
    elseif quest.kind == "overclock" then
        local now = workshop.phase == "night" and math.floor(workshop.combat.overclock_time or 0) or quest.progress
        return I18n.t("quest_ui.progress_overclock", { now = now, target = quest.target }), "info"
    elseif QuestRules.is_delivery(quest) then
        local ready = QuestRules.candidate(workshop, quest) ~= nil
        return I18n.t(ready and "quest_ui.progress_deliver_ready" or "quest_ui.progress_deliver_wait"), ready and "good" or "info"
    end
    return I18n.t("quest_ui.progress_count", { now = quest.progress, target = quest.target }), "info"
end

local function describe_guild(workshop, entry)
    local quest, prefix = entry.quest, "quests." .. entry.id
    local days = quest.deadline - workshop.day + 1
    local deadline = days <= 1 and I18n.t("quest_ui.deadline_today")
        or I18n.t("quest_ui.deadline", { date = CalendarText.date(quest.deadline), days = days })
    local progress, tone = guild_progress(workshop, quest)
    return {
        name = QuestText.name(quest),
        source = I18n.t("quest_ui.source_guild", { category = I18n.t("quest_ui.category." .. quest.category) }),
        story = workshop:personalize(I18n.t(prefix .. ".story", vars(quest))),
        goal = I18n.t(prefix .. ".goal", vars(quest)) .. "\n" .. deadline,
        reward = QuestText.reward_text(quest.reward),
        penalty = quest.state == "pending" and I18n.t("quest_ui.penalty_none") or I18n.t("quest_ui.penalty_text", { fine = quest.penalty }),
        card_line = (quest.state == "pending" or quest.state == "accepted") and QuestText.deadline_short(workshop, quest) or nil,
        risk_level = quest.risk, progress = progress, tone = tone, category = quest.category,
    }
end

local function describe_market(workshop, entry)
    local data, prefix = EVENTS.events[entry.id], "market_quests." .. entry.id
    local v = {
        mult = string.format("%.1f", data.flaw_sale_mult or 1), hp = string.format("%.1f", data.hp_mult or 1),
        speed = string.format("%.1f", data.speed_mult or 1), discount = data.tribute_discount or 0,
        success = math.floor((data.success_chance or 0) * 100 + 0.5), fail = math.floor((1 - (data.success_chance or 0)) * 100 + 0.5),
    }
    return {
        name = I18n.t("events." .. entry.id .. ".name"), source = I18n.t("quest_ui.source_market"),
        story = workshop:personalize(I18n.t(prefix .. ".story", v)), goal = I18n.t(prefix .. ".goal", v),
        reward = I18n.t(prefix .. ".reward", v), risk_level = data.risk,
        progress = entry.state == "accepted" and I18n.t(prefix .. ".accepted", v) or nil, tone = "info",
    }
end

function QuestText.describe(workshop, entry)
    local text = entry.source == "market" and describe_market(workshop, entry) or describe_guild(workshop, entry)
    text.risk = I18n.t("risk." .. (text.risk_level or "none"))
    return text
end

-- 위험도 → 0~1 (막대·색)
function QuestText.risk_ratio(level)
    for i, id in ipairs(QUESTS.risk_order) do
        if id == level then
            return (i - 1) / (#QUESTS.risk_order - 1)
        end
    end
    return 0
end

return QuestText
