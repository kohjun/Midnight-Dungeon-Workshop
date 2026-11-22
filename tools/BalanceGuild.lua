-- tools/BalanceGuild.lua
-- 밸런스 시뮬레이터(tools/BalanceSim)용 [의뢰]·[길드] 판단 — tools/BalanceAI 가 부른다. 실제 게임 API 만 호출한다.
--   의뢰: 감정 적발 · 정화 납품 · 보스 토벌은 수락, 과부하 시험은 과열 위험도가 낮을 때만, 단조 납품은 +FORGED_MAX 까지만
--         (하루 1~2번 강화하는 템포로는 기한 안에 못 맞춘다 — 기한을 넘기면 위약금)
--         납품: 조건에 맞는 유물이 보관함·작업대에 있으면 바로, 진열장에만 있으면 비무기이거나 무기가 넉넉할 때 보관함으로 옮겨 납품
--         암시장: 장물아비만 수락 (봉인 상자 · 핏빛 달은 거절)
--   길드: 여유 골드로 연마석(하루 제한) · UV 배터리 · 정화수가 바닥나기 전에 보급 (낮 영업 중 [길드] 창과 같은 값)

local QuestRules = require("systems.QuestRules")
local BalanceGrid = require("tools.BalanceGrid")

local BalanceGuild = {}

local STONE_RESERVE = 220       -- 연마석은 이 골드 + 다가오는 상납금 이상 남을 때만 산다
local STONE_TARGET = 2          -- 이만큼 보유하면 더 사지 않는다
local CAMPAIGN_STONES = 24     -- '스승의 흔적' 캠페인은 봉인 후보 4개를 +5 로 올릴 연마석을 따로 모은다 (하루 1개 제한)
local SUPPLY_BELOW = 35         -- UV·정화수가 이 % 아래면 보급품을 산다
local SUPPLY_RESERVE = 60       -- 보급품은 이 골드 + 다가오는 상납금 이상 남을 때만
local SAFE_OVERHEAT = 0.04      -- 과부하 시험은 초당 과열 위험이 이 이하일 때만 수락
local REPAIR_BELOW = 0.6        -- 방벽이 이 비율 아래면 낮에도 수리 키트를 산다 (저주 유물이 매일 밤 내구도를 갉아먹는다)
local MIN_WEAPONS = 3           -- 진열장 무기를 납품으로 빼더라도 이만큼은 남긴다
local FORGED_MAX = 3            -- 단조 납품 의뢰는 이 강화 단계까지만 수락

local function due_soon(w, within)
    local due, amount = w.tribute:next_due(w.day)
    if due ~= nil and due - w.day <= within then
        return amount
    end
    return 0
end
BalanceGuild.due_soon = due_soon

local function wants(w, quest)
    if quest.kind == "overclock" then
        return w:overheat_chance() <= SAFE_OVERHEAT
    elseif quest.kind == "deliver_forged" then
        return (quest.level or 0) <= FORGED_MAX
    end
    return true
end

-- [의뢰] 창: 대기 중인 길드 의뢰 수락/거절, 암시장은 장물아비만
function BalanceGuild.answer(w)
    for index = #w.quests.board, 1, -1 do        -- 거절하면 게시판에서 빠지므로 뒤에서부터
        local quest = w.quests.board[index]
        if quest.state == "pending" then
            if wants(w, quest) then
                w.quests:accept(index)
            else
                w.quests:decline(index)
            end
        end
    end
    if w.black_market:is_pending() then
        if w.black_market.event == "fence_request" then
            w.black_market:accept()
        else
            w.black_market:decline()
        end
    end
end

-- 진열장에만 조건에 맞는 유물이 있으면 가장 값싼 것(비무기 먼저)을 보관함으로 옮긴다.
-- 가장 강한 무기는 넘기지 않고, 무기는 작동 중인 무기가 MIN_WEAPONS 보다 많을 때만 (0% 무기는 언제나 넘겨도 된다)
local function stage_from_grid(w, quest)
    local slot = w.inventory:find_empty("storage")
    if slot == nil then
        return
    end
    local strongest, active = BalanceGrid.weakest(w, BalanceGrid.is_weapon), 0
    for index = 1, w.inventory:size("grid") do
        local item = w.inventory:get("grid", index)
        if item ~= nil and item:is_weapon() and not item:is_worn_out() then
            active = active + 1
            strongest = BalanceGrid.power(item) > BalanceGrid.power(strongest) and item or strongest
        end
    end
    local pick, pick_index, pick_key = nil, nil, nil
    for index = 1, w.inventory:size("grid") do
        local item = w.inventory:get("grid", index)
        if item ~= nil and item ~= strongest and QuestRules.matches(quest, item)
            and (not item:is_weapon() or item:is_worn_out() or active > MIN_WEAPONS) then
            local key = (item:is_weapon() and 1e9 or 0) + item:sale_value()
            if pick_key == nil or key < pick_key then
                pick, pick_index, pick_key = item, index, key
            end
        end
    end
    if pick ~= nil then
        w:move_item("grid", pick_index, "storage", slot)
    end
end

-- 수락한 납품 의뢰를 넘길 수 있으면 넘긴다
function BalanceGuild.deliver(w)
    local keeps = require("tools.BalanceTrace").keeps
    for index, quest in ipairs(w.quests.board) do
        if quest.state == "accepted" and QuestRules.is_delivery(quest) then
            if w.quests:delivery_block(quest) == "quest_ui.deliver_missing" then
                stage_from_grid(w, quest)
            end
            if not keeps(w, QuestRules.candidate(w, quest)) then       -- '스승의 흔적' 봉인 후보는 넘기지 않는다
                w.quests:deliver(index)
            end
        end
    end
end

-- 밤: 진행 중인 과부하 시험이 있으면 그 목표(초)까지는 과부하를 유지한다
function BalanceGuild.overclock_goal(w)
    local goal = 0
    for _, quest in ipairs(w.quests.board) do
        if quest.state == "accepted" and quest.kind == "overclock" then
            goal = math.max(goal, quest.target + 1)
        end
    end
    return goal
end

-- [길드] 창: 여유가 있으면 연마석
function BalanceGuild.buy_stones(w)
    local target = STONE_TARGET + (w.master_trace and CAMPAIGN_STONES or 0)      -- '스승의 흔적': 봉인 후보 +5 몫까지 모은다
    while w.tempering_stones < target and w.shop:availability("tempering_stone")
        and w.gold - w.shop:price("tempering_stone") >= STONE_RESERVE + due_soon(w, 3) do
        w.shop:buy("tempering_stone")
    end
end

-- [길드] 창: UV 배터리 · 정화수가 떨어지기 전에 보급 (에너지 압박 — 감정·세척을 계속하려면 골드가 든다), 방벽 수리
function BalanceGuild.buy_supplies(w)
    while w.hp < w.max_hp * REPAIR_BELOW and w.shop:availability("repair_kit") do    -- 방벽이 무너지면 끝이니 유지비보다 먼저
        w.shop:buy("repair_kit")
    end
    for _, pair in ipairs({ { "uv", "uv_pack" }, { "water", "water_barrel" } }) do
        local kind, id = pair[1], pair[2]
        if w.supplies:get(kind) < SUPPLY_BELOW and w.shop:availability(id)
            and w.gold - w.shop:price(id) >= SUPPLY_RESERVE + due_soon(w, 2) then
            w.shop:buy(id)
        end
    end
end

return BalanceGuild
