-- tools/BalanceHero.lua
-- 밸런스 시뮬 AI 의 주인공 장비 운용 (tools/BalanceAI 가 부른다 — 3분류 라우팅: 매입 자동 배치 · 4부위 장착/교체 · 임시 거치대).
--   방어구  : 그 부위가 비었거나 지금 것보다 SWAP 배 넘게 좋으면 마진과 상관없이 사서(wants) 세척 뒤 장착하고,
--             벗은 것은 판다. 더 못하면 되판다 (process_armor). 매입할 때 부위가 차 있으면 임시 거치대로 가 있다가
--             하루 정리에서 같은 판단을 받는다
--   무기    : 진열장에 못 올려 팔려던 무기 · 진열장에서 밀려난 무기는 주인공 무기 칸이 비었거나 더 강하면 장착한다
--             (take_weapon) — 진열장 화력을 깎지 않고 남는 무기만 문 앞으로 간다
--   여유    : 장비는 여유 골드(다가오는 결계 유지비를 뺀 골드) 안에서만 — 웃돈 매입은 그 BUDGET 까지, 장착(= 팔지 않음)은
--             그 물건의 판매가가 여유 골드의 KEEP_SHARE 이하일 때만. 진열장을 채워야 하는 초반에는 팔아서 돈으로 쓴다
--   정리    : 완전 마모(0%)된 장비는 아침에 판다 (tidy) — 새로 사서 채운다

local HeroEquip = require("systems.HeroEquip")
local ITEMS = require("data.items")
local ARMORS = require("data.armors")

local BalanceHero = {}

local SWAP = 1.2
local BUDGET = 0.05     -- 마진 없는 방어구 매입에 쓰는 돈: 여유 골드의 이 비율까지
local KEEP_SHARE = 0.08 -- 팔지 않고 장착해도 되는 물건: 판매가가 여유 골드의 이 비율 이하
local SPARE = 55        -- 방어구 손님을 받아 줄 UV 배터리 · 정화수 하한(%)
local SPARE_TRACE = 30  -- '스승의 흔적'에서의 UV 하한(%)

-- 여유 골드: 다가오는 결계 유지비를 뺀 골드 (keep 은 BalanceAI.due_soon — set_reserve 가 알려 준다)
local _reserve = function() return 0 end
function BalanceHero.set_reserve(fn)
    _reserve = fn
end

local function affordable(w, item)
    return w:sale_price(item) <= (w.gold - _reserve(w)) * KEEP_SHARE
end

-- 장착 가치: 방어구 = 등급 열 × 스탯 배율, 무기 = 공격력 (완전 마모 · 빈 칸 = 0)
function BalanceHero.score(item)
    if item == nil or item:is_worn_out() then
        return 0
    elseif item:is_armor() then
        return item.proto.tier * item:gear_mult()
    end
    return item:attack()
end

-- 아직 사지 않은 방어구의 가치 (드러난 등급, 없으면 손님이 말한 등급 — 세척한 뒤 기준)
local function prospect(w, item)
    local grade = item.revealed.grade and item.grade or item.claimed_grade
    local mult = ITEMS.grades[grade].mult * w.appraisal:clean_mult()
    return item.proto.tier * (1 + (mult - 1) * ARMORS.stat_share)
end

local function worn_piece(w, item)
    return w.inventory:get("hero", HeroEquip.slot_index(item.equip_slot))
end

-- 방어구 손님을 감정도 하지 않고 돌려보낼까: UV 배터리 · 정화수가 SPARE% 아래면 진열장에 올릴 무기·유물 몫으로 아낀다
-- (방어구 손님은 무료 손님 수를 쓰지 않는 덤 방문이라, 다 받으면 감정 자원이 먼저 바닥난다)
function BalanceHero.skips(w, item)
    if not item:is_armor() then
        return false
    elseif w.master_trace ~= nil then           -- 캠페인: 은빛 인장이 숨어 있을 수 있으니 UV 가 바닥일 때만 돌려보낸다
        return w.supplies.uv < SPARE_TRACE
    end
    return w.supplies.uv < SPARE or w.supplies.water < SPARE
end

-- 손님의 방어구를 마진과 상관없이 살 만한가 (price = 제시가, keep = 곧 낼 결계 유지비 — 그 돈은 건드리지 않는다)
function BalanceHero.wants(w, item, price, keep)
    return item:is_armor() and price <= (w.gold - keep) * BUDGET
        and prospect(w, item) > BalanceHero.score(worn_piece(w, item)) * SWAP
end

-- 작업대의 내 방어구 (세척 끝): 장착하거나 판다. sell(w, item, record) 는 BalanceAI 의 판매 함수
function BalanceHero.process_armor(w, item, record, sell)
    local slot = HeroEquip.slot_index(item.equip_slot)
    local current = w.inventory:get("hero", slot)
    if (current == nil or BalanceHero.score(item) > BalanceHero.score(current) * SWAP) and affordable(w, item)
        and w:move_item("bench", 1, "hero", slot) then
        record.equipped = (record.equipped or 0) + 1
        if current ~= nil then
            sell(w, current, record)                -- 맞바꿈으로 작업대에 내려온 헌 방어구
        end
        return
    end
    sell(w, item, record)
end

-- 작업대의 남는 무기: 주인공 무기 칸이 비었거나 더 강하면 장착 (헌 무기는 판다). 장착했으면 true
function BalanceHero.take_weapon(w, item, record, sell)
    if not item:is_weapon() or w.inventory:locate(item) ~= "bench" then
        return false
    end
    local slot = HeroEquip.slot_index("weapon")
    local current = w.inventory:get("hero", slot)
    if (current ~= nil and BalanceHero.score(item) <= BalanceHero.score(current) * SWAP) or not affordable(w, item) then
        return false
    end
    if not w:move_item("bench", 1, "hero", slot) then
        return false
    end
    record.equipped = (record.equipped or 0) + 1
    if current ~= nil then
        sell(w, current, record)
    end
    return true
end

-- 아침 정리: 완전 마모된 장비를 판다
function BalanceHero.tidy(w, record, sell)
    for index = 1, w.inventory:size("hero") do
        local item = w.inventory:get("hero", index)
        if item ~= nil and item:is_worn_out() then
            sell(w, item, record)
        end
    end
end

-- 보고 한 줄: 주인공의 밤 기여 (밤당 타격 수 · 런당 준 피해 · 런당 막아 낸 방벽 피해 · 런당 장착 횟수)
function BalanceHero.report(emit, records)
    local runs, nights, strikes, damage, blocked, equipped = math.max(1, #records), 0, 0, 0, 0, 0
    for _, r in ipairs(records) do
        nights = nights + (r.crowd_nights or 0)
        strikes, damage = strikes + (r.hero_strikes or 0), damage + (r.hero_damage or 0)
        blocked, equipped = blocked + (r.hero_blocked or 0), equipped + (r.equipped or 0)
    end
    emit("hero: %.1f strikes/night · %.0f damage dealt/run · %.1f wall damage blocked/run · %.1f equips/run",
        strikes / math.max(1, nights), damage / runs, blocked / runs, equipped / runs)
end

return BalanceHero
