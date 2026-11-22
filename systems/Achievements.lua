-- systems/Achievements.lua
-- 업적 판정 (data/achievements.lua): 게임 이벤트를 구독해 조건을 만족하면 MetaProgression 에 영구 기록하고,
-- 그 업적의 특수 유물을 지금 런의 해금 목록(workshop.unlocked_relics)에도 바로 더한다 → 오늘부터 손님·상점에 나온다.
-- 엔딩 판정용 런 기록도 남긴다: 최종일 밤에 보스를 쓰러뜨릴 때 진열장의 저주 유물 수와 비율
--   (workshop.stats.final_boss_cursed · final_boss_share = 저주 유물 / 진열 유물).
-- 골드 업적: gold_held = 고정 금액, gold_ratio = 이번 계약의 상권 독점 기준(systems/Endings.monopoly_gold) × ratio.
--   Achievements.gold_line(id, workshop) 이 지금 데이터 기준의 문턱을 돌려준다 (스모크 테스트도 이 값을 쓴다).
-- Achievements.condition_vars(id): 조건 문구(achievements.<id>.condition)의 자리표시자 값 (도감 ui/CompendiumDetail).

local Class = require("lib.classic")
local EventBus = require("core.EventBus")
local MetaProgression = require("systems.MetaProgression")
local Endings = require("systems.Endings")
local ACHIEVEMENTS = require("data.achievements")

local Achievements = Class:extend()

local OBSERVER = -150       -- 수정자(≥ 0)가 끝난 결과만 읽는다

function Achievements:new(workshop)
    self._workshop = workshop
    local function on(event, fn)
        EventBus.subscribe(event, fn, { owner = self, priority = OBSERVER })
    end
    on("forge:succeeded", function(p)
        self:_check("forge_level", function(spec) return (p.level or 0) >= spec.level end)
    end)
    on("blackmarket:blood_moon_cleared", function()
        self:_check("blood_moon_survived")
    end)
    on("economy:gold_changed", function(p)
        local gold = p.gold or 0
        self:_check("gold_held", function(spec) return gold >= spec.gold end)
        self:_check("gold_ratio", function(spec) return gold >= spec.ratio * Endings.monopoly_gold(self._workshop) end)
    end)
    on("combat:monster_killed", function(p)
        if p.monster ~= nil and p.monster:is_boss() then
            self:_boss_killed(p.monster)
        end
    end)
end

function Achievements:destroy()
    EventBus.unsubscribe_owner(self)
end

-- 진열장에 놓인 저주 유물 수, 진열 유물 수
function Achievements.cursed_on_grid(workshop)
    local inventory, count, total = workshop.inventory, 0, 0
    for index = 1, inventory:size("grid") do
        local item = inventory:get("grid", index)
        if item ~= nil then
            total = total + 1
            count = count + (item.flaw == "curse" and 1 or 0)
        end
    end
    return count, total
end

-- 골드 업적의 이번 계약 문턱 (골드 업적이 아니면 nil)
function Achievements.gold_line(id, workshop)
    local spec = ACHIEVEMENTS.list[id]
    if spec == nil then
        return nil
    elseif spec.trigger == "gold_held" then
        return spec.gold
    elseif spec.trigger == "gold_ratio" then
        return math.ceil(spec.ratio * Endings.monopoly_gold(workshop))
    end
    return nil
end

-- 조건 문구의 자리표시자 값: data 표의 수치 그대로 + percent(= ratio × 100)
function Achievements.condition_vars(id)
    local spec = ACHIEVEMENTS.list[id]
    assert(spec ~= nil, "Achievements: unknown achievement '" .. tostring(id) .. "'")
    return {
        level = spec.level, cursed = spec.cursed, gold = spec.gold,
        percent = spec.ratio ~= nil and math.floor(spec.ratio * 100 + 0.5) or nil,
    }
end

function Achievements:_boss_killed(monster)
    local workshop = self._workshop
    local cursed, total = Achievements.cursed_on_grid(workshop)
    if workshop.day >= workshop.max_days then
        local stats = workshop.stats
        stats.final_boss_cursed = math.max(stats.final_boss_cursed or 0, cursed)
        stats.final_boss_share = math.max(stats.final_boss_share or 0, total > 0 and cursed / total or 0)
    end
    self:_check("boss_killed", function(spec) return spec.boss == monster.type_id end)
    self:_check("boss_killed_cursed", function(spec) return cursed >= spec.cursed end)
end

-- trigger 종류가 같은 업적 중 아직 못 딴 것을 condition(spec) 으로 판정한다
function Achievements:_check(trigger, condition)
    for _, id in ipairs(ACHIEVEMENTS.order) do
        local spec = ACHIEVEMENTS.list[id]
        if spec.trigger == trigger and not MetaProgression.has_achievement(id) and (condition == nil or condition(spec)) then
            self._workshop.unlocked_relics[spec.relic] = true
            MetaProgression.unlock_achievement(id)
        end
    end
end

return Achievements
