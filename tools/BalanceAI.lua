-- tools/BalanceAI.lua
-- 밸런스 시뮬레이터(tools/BalanceSim)용 휴리스틱 플레이어. 실제 게임 API(Appraisal·Forge·Workshop·GuildShop)만 호출한다.
--   손님: UV 스윕(배터리 소모) → 드러난 정보로 기대 판매가 추정 → 마진이 충분하면 매입, 아니면 돌려보내기
--   매입품: 작업대에서 완세척 → (강화하지 않고) 진열장 빈 칸에 배치 / 더 약한 진열품과 교체 / 판매.
--           저주 대가 유물은 방벽이 넉넉하고 진열장 대가 합계가 예산 안일 때만 진열 (tools/BalanceGrid.toll_ok)
--   용광로: 하루 최대 2번 — 닳은 진열품 정비 → 가장 강한 진열 무기 성장 (tools/BalanceForge.plan_day)
--   하루 마무리: 상납일인데 모자라면 보관함 → 진열장(약한 것부터) 순으로 처분, 여유가 있으면 진열장 확장·방벽 보강
--   [의뢰]·[길드]: tools/BalanceGuild — 의뢰 수락·납품, 연마석(하루 제한)·UV·정화수 보급. 세척이 끝난 보관품은 진열장으로 바로
--   길드 상점(상납 직후): 방벽 수리 · 정화수/UV 보충. 밤: 앞 15초(과부하 시험 의뢰가 있으면 그 목표까지) 과부하
--   (거의 닳은 진열품이 있으면 쓰지 않는다). 방벽이 위험하면 저주 대가 유물부터 내린다.
--   '스승의 흔적' 캠페인: 은빛 인장 매입 · 계열별 봉인 후보 키우기·점화 · 아이기스 과부하는 tools/BalanceTrace.

local LAYOUT = require("data.layout")
local ITEMS = require("data.items")
local BALANCE = require("data.balance")
local BalanceGrid = require("tools.BalanceGrid")
local BalanceGuild = require("tools.BalanceGuild")
local BalanceForge = require("tools.BalanceForge")
local BalanceTrace = require("tools.BalanceTrace")
local BalanceHero = require("tools.BalanceHero")

local BalanceAI = {}

local open_empty_cell, power, weakest_on_grid = BalanceGrid.open_empty_cell, BalanceGrid.power, BalanceGrid.weakest
local toll_ok = BalanceGrid.toll_ok
local weapon_balance, is_weapon, not_weapon = BalanceGrid.weapon_balance, BalanceGrid.is_weapon, BalanceGrid.not_weapon

local SCAN_DT = 1 / 40          -- 스윕 한 점당 렌즈 시간 (81점 ≈ 2초 = 배터리 약 22%)
local SCRUB_STEP = 30           -- 한 번 문지르는 거리(px)
local BUY_MARGIN = 1.15         -- 기대 판매가 ≥ 제시가 × 이 배율이면 매입
local WEAPON_BUY_MARGIN = 0.9   -- 진열장 무기가 목표보다 적을 때의 무기 매입 기준
local SWAP_MARGIN = 1.25        -- 새 유물이 진열장 최약체보다 이만큼 비싸면 교체
local SUMMON_RESERVE = 250      -- 호출은 이 골드 + 다가오는 상납금 이상일 때만
local UPGRADE_RESERVE = 120
local REPAIR_BELOW = 0.6
local OVERCLOCK_SECONDS = 15    -- 밤 앞부분만 과부하 (보통 실력의 플레이어 기준, 초당 과열 OVERCLOCK_REF 일 때)
local OVERCLOCK_REF = 0.035     -- 과열 위험이 이보다 높으면 그만큼 짧게 켠다 (위험 0 = 밤새 켠다)
local OVERCLOCK_MIN = 4
local WEAR_GUARD = 12           -- AI 가 정비하는 진열품이 이 % 이하로 닳았으면 과부하를 쓰지 않는다 (과부하는 마모를 가속한다)

local function bench_center()
    local s = LAYOUT.day.bench_slot
    return s.x + s.w / 2, s.y + s.h / 2
end

-- 오늘 포함 within 일 안에 내야 할 상납금 (없으면 0)
BalanceAI.due_soon = BalanceGuild.due_soon

local function sweep(w)
    local a, s = w.appraisal, LAYOUT.day.bench_slot
    for row = 0, 8 do
        for col = 0, 8 do
            local item = a:bench_item()
            if item == nil or item.revealed.complete then
                return
            end
            if a:scan(s.x + 10 + col * 22.5, s.y + 10 + row * 22.5, SCAN_DT, true) == "empty" then
                if w.scrolls > 0 then
                    a:use_scroll()
                end
                return
            end
        end
    end
end

-- 지금 드러난 정보로 추정한 세척 후 판매가
local function expected_sale(w, item)
    local grade = item.revealed.grade and item.grade or item.claimed_grade
    local value = item.proto.value * ITEMS.grades[grade].mult * w.appraisal:clean_mult() * item:sale_forge_mult()
    if item.flaw ~= nil and item.revealed.flaw then
        value = value * ITEMS.flaws[item.flaw].value_mult
    end
    return value * (1 + w:meta_value("sale_bonus"))
end

local function to_bench(w, item)
    local area, index = w.inventory:locate(item)
    if area == "bench" then
        return true
    end
    return area ~= nil and w.inventory:get("bench", 1) == nil and w:move_item(area, index, "bench", 1)
end

local function sell(w, item, record)
    local worn = item:is_worn_out()
    if to_bench(w, item) and w.appraisal:sell() then
        record.sold = record.sold + 1
        record.sold_worn = record.sold_worn + (worn and 1 or 0)
        return true
    end
    return false
end

local function clean(w)
    local cx, cy = bench_center()
    for _ = 1, 200 do
        if w.appraisal:scrub(cx, cy, SCRUB_STEP) ~= "ok" then
            return
        end
    end
end

-- 작업대 위 보유 유물 처리: 세척 → 진열/교체/판매 (강화는 하루 계획에서 진열품만)
local function process(w, item, record)
    if not to_bench(w, item) then
        return
    end
    clean(w)
    if item:is_armor() then                     -- 방어구: 더 좋으면 장착, 아니면 되판다 (진열장에는 못 놓는다)
        return BalanceHero.process_armor(w, item, record, sell)
    end
    if BalanceTrace.stash(w, item) then         -- 캠페인 봉인 후보는 팔지 않고 둔다
        return
    end
    local weapons, target, empty = weapon_balance(w)
    local cell = open_empty_cell(w)
    -- 빈 칸: 무기는 언제나, 비무기는 무기 몫을 남겨 둘 수 있을 때만 (저주 대가 유물은 예산 안에서만)
    if cell ~= nil and (item:is_weapon() or empty > target - weapons) and toll_ok(w, item) then
        w:move_item("bench", 1, "grid", cell)
        return
    end
    -- 교체: 무기가 모자라면 새 무기가 가장 약한 비무기를, 아니면 같은 종류의 가장 약한 것을 밀어낸다
    local filter = item:is_weapon() and is_weapon or not_weapon
    local margin = SWAP_MARGIN
    if item:is_weapon() and weapons < target then
        filter, margin = not_weapon, 0
    end
    local weakest, index = weakest_on_grid(w, function(other) return filter(other) and not BalanceTrace.keeps(w, other) end)
    if weakest ~= nil and power(item) > power(weakest) * margin and toll_ok(w, item, weakest) then
        w:move_item("bench", 1, "grid", index)      -- 교체: 약한 유물이 작업대로 밀려난다
        item = weakest
    end
    if not BalanceHero.take_weapon(w, item, record, sell) then      -- 남는 무기는 주인공이 든다, 아니면 판다
        sell(w, item, record)
    end
end

local function handle_customer(w, record)
    local a = w.appraisal
    local item = a:bench_item()
    if BalanceHero.skips(w, item) then return a:dismiss() end     -- 감정 자원이 빠듯하면 방어구 손님은 돌려보낸다
    sweep(w)
    local price = item:asking_price()
    local keep = BalanceAI.due_soon(w, 0)
    local margin = BUY_MARGIN
    if item:is_weapon() then
        local weapons, target = weapon_balance(w)
        margin = weapons < target and WEAPON_BUY_MARGIN or margin     -- 무기가 모자라면 마진이 적어도 산다
    end
    local wanted = BalanceTrace.wants(w, item) and BalanceTrace.can_afford(w, price, keep)     -- 인장 · 빈 계열 후보
    wanted = wanted or BalanceHero.wants(w, item, price, keep)                              -- 더 좋은 방어구 (여유 골드 안에서)
    if (wanted or expected_sale(w, item) >= price * margin and w.gold - price >= keep * 0.5) and a:buy() then
        record.bought = record.bought + 1
        process(w, item, record)
    else
        a:dismiss()
    end
end

local function should_summon(w)
    return w.summons_today < 2 and w.gold >= w.appraisal:summon_cost() + SUMMON_RESERVE + BalanceAI.due_soon(w, 2)
end

-- 상납일인데 모자라면 보관함 → 진열장(약한 것부터) 순으로 처분
local function raise_tribute(w, record)
    local amount = BalanceAI.due_soon(w, 0)
    for index = 1, w.inventory:size("storage") do
        local item = w.inventory:get("storage", index)
        if w.gold >= amount then
            return
        end
        if item ~= nil and not BalanceTrace.keeps(w, item) then
            sell(w, item, record)
        end
    end
    local spare = function(item) return not BalanceTrace.keeps(w, item) end
    while w.gold < amount do
        local weakest = weakest_on_grid(w, function(item) return not_weapon(item) and spare(item) end) or weakest_on_grid(w, spare)
            or weakest_on_grid(w)
        if weakest == nil or not sell(w, weakest, record) then
            return
        end
    end
end

local function buy_upgrades(w)
    for _, id in ipairs({ "grid", "wall" }) do
        local level = w.upgrades:next_level(id)
        if level ~= nil and w.upgrades:can_buy(id)
            and w.gold - level.cost >= UPGRADE_RESERVE + BalanceAI.due_soon(w, 3) then
            w.upgrades:buy(id)
        end
    end
end


-- 세척이 끝난 보관품은 작업대를 거치지 않고 진열장 빈 칸으로 바로 옮긴다 (강화는 다음 정비 때)
local function place_direct(w, item)
    if BalanceTrace.parks(w, item) then         -- 캠페인: 아껴 둘 봉인 후보는 보관함에 그대로
        return true
    end
    local cell = open_empty_cell(w)
    if cell == nil or not item.cleaned or item:is_armor() or not toll_ok(w, item) then
        return false
    end
    return w:move_item("storage", select(2, w.inventory:locate(item)), "grid", cell)
end

-- 방벽이 위험하면 저주 대가 유물을 내린다 (팔아서 다음 매입·유지비에 보탠다)
local function shed_tolls(w, record)
    for _ = 1, 4 do
        local item = BalanceGrid.toll_to_shed(w)
        if item == nil or not sell(w, item, record) then
            return
        end
        record.shed = (record.shed or 0) + 1
    end
end

function BalanceAI.play_day(w, record)
    BalanceHero.set_reserve(function(shop) return BalanceAI.due_soon(shop, 0) end)
    BalanceGuild.answer(w)
    BalanceGuild.buy_supplies(w)
    BalanceGuild.buy_stones(w)
    shed_tolls(w, record)
    BalanceHero.tidy(w, record, sell)
    for _ = 1, 12 do
        local arrived = false
        if w.customers_left > 0 then
            arrived = w.appraisal:new_customer()
        elseif should_summon(w) then
            arrived = w.appraisal:summon_customer()
        end
        if not arrived then
            break
        end
        handle_customer(w, record)
    end
    for index = 1, w.inventory:size("storage") do       -- 남은 보관품(상점 유물·봉인 상자) 정리
        local item = w.inventory:get("storage", index)
        if item ~= nil and not place_direct(w, item) then
            process(w, item, record)
        end
    end
    BalanceTrace.plan_day(w, record)
    BalanceForge.plan_day(w, record)
    BalanceGuild.deliver(w)
    raise_tribute(w, record)
    buy_upgrades(w)
end

-- 이번 밤 과부하를 켤 시간: 과열 위험이 없으면 밤새, 높을수록 짧게
local function overclock_seconds(w)
    local chance = w:overheat_chance()
    if chance <= 0 then
        return math.huge
    end
    return math.max(OVERCLOCK_MIN, OVERCLOCK_SECONDS * math.min(1, OVERCLOCK_REF / chance))
end

-- 밤: 앞 몇 초(과부하 시험 의뢰가 있으면 그 목표까지) 동안 과부하. 단, 과부하가 마모를 가속하는 계약에서 AI 가 정비하는
-- 진열품(BalanceForge.maintained)이 거의 닳았으면(0% 초과 WEAR_GUARD% 이하) 시험 목표를 채운 뒤에는 끈다
function BalanceAI.night_tick(w)
    local goal = BalanceGuild.overclock_goal(w)
    local want = w.combat.elapsed < math.max(overclock_seconds(w), goal)
    if want and w.combat.elapsed >= goal and w:overclock_wear_mult() > 1 then
        for index = 1, w.inventory:size("grid") do
            local item = w.inventory:get("grid", index)
            if item ~= nil and item.durability > 0 and item.durability <= WEAR_GUARD and BalanceForge.maintained(item) then
                want = false
                break
            end
        end
    end
    want = BalanceTrace.overclock(w, want)
    if want ~= w.combat.overclock then
        w:set_overclock(want)
    end
end

function BalanceAI.shop(w)
    local shop = w.shop
    while w.hp < w.max_hp * REPAIR_BELOW and shop:availability("repair_kit") do
        shop:buy("repair_kit")
    end
    if w.supplies:get("water") < 40 and shop:availability("water_barrel") then
        shop:buy("water_barrel")
    end
    if w.supplies:get("uv") < 30 and shop:availability("uv_pack") then
        shop:buy("uv_pack")
    end
    BalanceGuild.buy_stones(w)
end

return BalanceAI
