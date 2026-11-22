-- systems/ItemFactory.lua
-- 손님이 가져오는 미확인 유물 생성 (원형·등급·주장 등급·결함·오염도).
-- 손님은 고유 모험가 6인 중 한 명(data/adventurers.lua)이고, 그 성향(선호 아키타입·분류·모양, 오염도 범위,
-- 결함·저주·위조 확률, 전설 등급 운, 흥정 = 제시가 배율)이 유물에 반영된다.
-- 방어구(data/armors.lua)는 ARMORS.share 확률로 나온다 (등급 열 가중치 tiers — 진열장 무기·유물 수급을 해치지 않는 선).
-- 난수 소비 순서가 결정론에 영향을 주므로 원형/결함 목록은 정렬된 키로 순회한다.

local Item = require("entities.Item")
local ITEMS = require("data.items")
local ARMORS = require("data.armors")
local BALANCE = require("data.balance")
local ADVENTURERS = require("data.adventurers")

local ItemFactory = {}

local function sorted_keys(map)
    local keys = {}
    for key in pairs(map) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local PROTO_IDS = sorted_keys(ITEMS.prototypes)
local FLAW_IDS = sorted_keys(ITEMS.flaws)
local BASE_IDS = {}
for _, id in ipairs(PROTO_IDS) do
    if not ITEMS.prototypes[id].special then
        BASE_IDS[#BASE_IDS + 1] = id
    end
end

local ARMOR_ENTRIES = {}
for _, id in ipairs(sorted_keys(ARMORS.prototypes)) do
    ARMOR_ENTRIES[#ARMOR_ENTRIES + 1] = { id = id, weight = ARMORS.tiers[ARMORS.prototypes[id].tier].weight }
end

-- 방어구 원형 id 목록 (정렬)
function ItemFactory.armor_ids()
    local ids = {}
    for i, entry in ipairs(ARMOR_ENTRIES) do
        ids[i] = entry.id
    end
    return ids
end

-- 이번 아이템이 방어구면 그 원형 id, 아니면 nil (share = 방어구 비중, mult = 모험가 성향 배율)
local function roll_armor(rng, mult)
    if rng:chance(math.min(0.9, ARMORS.share * (mult or 1))) then
        return rng:weighted_pick(ARMOR_ENTRIES).id
    end
    return nil
end

-- 전체 원형 (특수 유물 포함)
function ItemFactory.prototype_ids()
    return PROTO_IDS
end

-- 기본 원형 24종 (특수 유물 제외)
function ItemFactory.base_ids()
    return BASE_IDS
end

-- 특수 유물(special)은 업적으로 해금된 것(unlocked[id] == true)만 나온다
function ItemFactory.available(id, unlocked)
    local proto = ITEMS.prototypes[id]
    return proto == nil or not proto.special or (unlocked ~= nil and unlocked[id] == true)       -- 방어구는 언제나 나온다
end

-- 감정·세척이 끝난 보유 유물 한 점 (시작 지급품 등)
function ItemFactory.make_ready(id, grade, level)
    local item = Item(id, { grade = grade, contamination = 0 })
    item.owned = true
    item.level = level or 0
    item.revealed.grade, item.revealed.flaw, item.revealed.complete = true, true, true
    for i = 1, 16 do
        item.scan_points[i] = true
    end
    return item
end

-- 무작위 보유 유물 (상점·봉인 상자 보상). 고유 저주 원형은 제외한다
-- allow_armor = false 면 방어구는 나오지 않는다 (둘 자리가 없을 때)
function ItemFactory.ready_item(rng, grade, level, unlocked, allow_armor)
    local armor = allow_armor ~= false and roll_armor(rng) or nil
    if armor ~= nil then
        return ItemFactory.make_ready(armor, grade, level)
    end
    local entries = {}
    for _, id in ipairs(PROTO_IDS) do
        local proto = ITEMS.prototypes[id]
        if proto.innate_flaw == nil and ItemFactory.available(id, unlocked) then
            entries[#entries + 1] = { id = id, weight = proto.weight or 1 }
        end
    end
    return ItemFactory.make_ready(rng:weighted_pick(entries).id, grade, level)
end

-- 난이도 customer 규칙이 있으면 우선, 없으면 data/balance.lua 기본값
local function setting(rules, key)
    local value = rules and rules[key]
    if value == nil then
        value = BALANCE.customer[key]
    end
    return value
end

-- 방문할 모험가 id (난이도 customer.adventurer_weights 가 방문 가중치에 곱해진다)
function ItemFactory.pick_adventurer(rng, rules)
    local bias = setting(rules, "adventurer_weights") or {}
    local entries = {}
    for _, id in ipairs(ADVENTURERS.order) do
        entries[#entries + 1] = { id = id, weight = ADVENTURERS.list[id].weight * (bias[id] or 1) }
    end
    return rng:weighted_pick(entries).id
end

local PREFERENCE_FIELDS = { archetypes = "archetype", categories = "category", shapes = "shape" }

-- 선호 분류(categories)는 세부 구분으로 견준다: 증폭기는 subtype, 그 밖에는 category
local function preferred(adventurer, proto)
    local prefers = adventurer and adventurer.prefers
    if prefers == nil then
        return false
    end
    for list_key, field in pairs(PREFERENCE_FIELDS) do
        local own = field == "category" and (proto.subtype or proto.category) or proto[field]
        for _, value in ipairs(prefers[list_key] or {}) do
            if own == value then
                return true
            end
        end
    end
    return false
end

local function trait(adventurer, key)
    return adventurer and adventurer[key] or 1
end

local function pick_prototype(rng, rules, unlocked, adventurer)
    local armor = roll_armor(rng, adventurer and adventurer.armor_mult)
    if armor ~= nil then
        return armor
    end
    local cursed_mult = (setting(rules, "cursed_proto_mult") or 1) * trait(adventurer, "curse_mult")
    local entries = {}
    for _, id in ipairs(PROTO_IDS) do
        local proto = ITEMS.prototypes[id]
        local weight = proto.weight or 1
        if proto.innate_flaw == "curse" then
            weight = weight * cursed_mult
        end
        if preferred(adventurer, proto) then
            weight = weight * adventurer.prefers.mult
        end
        if ItemFactory.available(id, unlocked) then
            entries[#entries + 1] = { id = id, weight = weight }
        end
    end
    return rng:weighted_pick(entries).id
end

local function pick_grade(rng, day, rules, adventurer)
    local legendary_mult = (setting(rules, "legendary_mult") or 1) * trait(adventurer, "legendary_mult")
    local entries = {}
    for _, id in ipairs(ITEMS.grade_order) do
        local grade = ITEMS.grades[id]
        local weight = math.max(0, grade.weight + (grade.weight_per_day or 0) * (day - 1))
        if id == "legendary" then
            weight = weight * legendary_mult
        end
        entries[#entries + 1] = { id = id, weight = weight }
    end
    return rng:weighted_pick(entries).id
end

local function shift_grade(grade, delta)
    local order = ITEMS.grade_order
    local rank = math.max(1, math.min(#order, ITEMS.grades[grade].rank + delta))
    return order[rank]
end

-- 손님이 말하는 등급: 정직하거나, 부풀리거나(악덕 손님·위조), 모르고 낮춰 말한다
local function claim_grade(rng, grade, rules, adventurer)
    if rng:chance(math.min(0.98, setting(rules, "honest_chance") * trait(adventurer, "honest_mult"))) then
        return grade
    end
    local overclaim = adventurer and adventurer.overclaim or setting(rules, "overclaim_chance")
    local delta = rng:chance(overclaim) and 1 or -1
    return shift_grade(grade, delta)
end

local function roll_flaw(rng, proto, rules, adventurer)
    if proto.innate_flaw ~= nil then
        return proto.innate_flaw
    end
    if not rng:chance(math.min(0.95, setting(rules, "flaw_chance") * trait(adventurer, "flaw_mult"))) then
        return nil
    end
    local weights = setting(rules, "flaw_weights") or {}
    local entries = {}
    for _, id in ipairs(FLAW_IDS) do
        local weight = weights[id] or 1
        if id == "curse" then
            weight = weight * trait(adventurer, "curse_mult")
        end
        entries[#entries + 1] = { id = id, weight = weight }
    end
    return rng:weighted_pick(entries).id
end

local function make_grime(rng)
    local range = BALANCE.customer.grime_spots
    local spots = {}
    for i = 1, rng:int(range.min, range.max) do
        spots[i] = { x = rng:float(-0.38, 0.38), y = rng:float(-0.42, 0.42), r = rng:float(0.07, 0.17) }
    end
    return spots
end

-- rng: RNG 스트림, day: 현재 일차 (전설 확률 상승), rules: 난이도 customer 규칙 (없으면 기본값),
-- unlocked: 해금된 특수 유물 id 집합 (Workshop.unlocked_relics), adventurer_id: 방문한 모험가 (없으면 성향 없음)
function ItemFactory.customer_item(rng, day, rules, unlocked, adventurer_id)
    local adventurer = adventurer_id and ADVENTURERS.list[adventurer_id] or nil
    local proto_id = pick_prototype(rng, rules, unlocked, adventurer)
    local proto = Item.prototype(proto_id)
    local grade = pick_grade(rng, day, rules, adventurer)
    local claimed = claim_grade(rng, grade, rules, adventurer)
    local flaw = roll_flaw(rng, proto, rules, adventurer)
    local flaw_mark = { x = rng:float(-0.3, 0.3), y = rng:float(-0.3, 0.3) }
    local contamination = adventurer and adventurer.contamination or BALANCE.customer.contamination
    return Item(proto_id, {
        adventurer = adventurer_id,
        ask_mult = adventurer and adventurer.haggle or 1,
        grade = grade,
        claimed_grade = claimed,
        flaw = flaw,
        flaw_mark = flaw_mark,
        contamination = rng:int(contamination.min, contamination.max),
        grime = make_grime(rng),
    })
end

return ItemFactory
