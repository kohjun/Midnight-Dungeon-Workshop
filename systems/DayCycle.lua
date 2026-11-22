-- systems/DayCycle.lua
-- 낮/밤/상점 전환 흐름: 밤 종료 → 일일 수익 → 핏빛 달 정산 → 길드 의뢰 판정(보상·위약금) → 결계 유지비(매달 말일, 미달 시 파산) →
-- (납부 성공 시) 길드 보급 상점 → 다음 날 아침(손님·호출비·상점 하루 수량 초기화, 자원 보충,
-- 암시장 추첨 · 길드 의뢰 게시 · 사계절 계약이면 새 계절 알림 calendar:season_changed,
-- '스승의 흔적' 캠페인이면 새 달 아침에 포탈 간섭 단계 상승 알림 calendar:interference_rose).

local EventBus = require("core.EventBus")
local Calendar = require("systems.Calendar")
local BALANCE = require("data.balance")

local DayCycle = {}

local function collect_income(workshop)
    local grid_stats = workshop:grid_stats()
    local total, entries = 0, {}
    for _, item in ipairs(grid_stats.order) do
        local amount = grid_stats.stats[item].income
        total = total + amount
        entries[#entries + 1] = { item = item, amount = amount }
    end
    local payout = EventBus.emit("economy:daily_income", { total = total, entries = entries })
    local income = math.floor(payout.total + 0.5)
    if income > 0 then
        workshop:add_gold(income, "income")
    end
    return income
end

-- 1일차 아침 (암시장은 1일차에도 추첨)
function DayCycle.announce_first_day(workshop)
    workshop.black_market:roll(workshop.day)
    workshop.quests:roll(workshop.day)
    EventBus.emit("phase:day_started", { day = workshop.day, income = 0 })
end

function DayCycle.finish_night(workshop)
    workshop:claim_dawn_bonus()                -- 새벽 정산창에서 이미 받았으면 그대로
    workshop.combat:end_night()
    workshop.stats.days_survived = workshop.stats.days_survived + 1
    EventBus.emit("phase:night_ended", { day = workshop.day })
    workshop._pending_income = collect_income(workshop)
    workshop.black_market:settle_night()
    workshop.quests:settle_night()

    local paid = workshop.tribute:collect(workshop.day)
    if paid == false then
        workshop.result = "bankrupt"
        return
    end
    if workshop.result ~= nil then
        return
    end
    if workshop.day >= workshop.max_days then
        workshop.result = "victory"
        return
    end
    if paid == true then
        workshop.phase = "shop"
        workshop.shop:open(workshop.day)
        EventBus.emit("phase:shop_opened", { day = workshop.day })
        return
    end
    DayCycle.start_next_day(workshop)
end

function DayCycle.start_next_day(workshop)
    workshop.day = workshop.day + 1
    workshop.phase = "day"
    workshop.customers_left = BALANCE.workshop.customers_per_day
    workshop.summons_today = 0
    workshop.supplies:morning_refill()
    workshop.shop:new_day()
    workshop.black_market:roll(workshop.day)
    workshop.quests:roll(workshop.day)
    local income = workshop._pending_income or 0
    workshop._pending_income = nil
    EventBus.emit("phase:day_started", { day = workshop.day, income = income })
    local season = Calendar.season_started(workshop.rules, workshop.day)
    if season ~= nil then
        EventBus.emit("calendar:season_changed", { season = season, day = workshop.day, workshop = workshop })
    end
    local level = Calendar.interference_started(workshop.rules, workshop.day)
    if level ~= nil then
        EventBus.emit("calendar:interference_rose", { level = level, day = workshop.day, workshop = workshop })
    end
end

return DayCycle
