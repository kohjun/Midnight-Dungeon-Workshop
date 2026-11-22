-- systems/Endings.lua
-- 승리한 런의 엔딩 판정 (기준 data/endings.lua): 심연 장악 → 던전 상권 독점 → 무사 이주 순서로 본다.
--   Endings.monopoly_gold(workshop) : 이 계약의 상권 독점 기준 골드 (계약 일수 · 마지막 결계 유지비 · 난이도 경제 규모 비례,
--                                     마스터 장인 할인 전)
--   Endings.status(workshop)        : 판정 재료 { gold, need(마스터 장인 할인 후), base_need, hp_ratio, min_hp_ratio,
--                                     best_level, master, cursed, cursed_need, share, share_need, abyss_contract } — 도감·시뮬도 본다
--   Endings.decide(workshop)        : "abyss" | "monopoly" | "relocation" — 승리 직후(마지막 결계 유지비를 낸 뒤) RunState ·
--                                     tools/BalanceSim 이 부른다. '스승의 흔적' 캠페인은 "true_dawn" | "new_gatekeeper"
--                                     (systems/MasterTrace:ending — 최종 보스를 봉인진 4/4 점화 상태로 쓰러뜨렸는지)
--   Endings.condition_vars()        : 엔딩 조건 문구(ending.<id>.condition)의 자리표시자 값
--                                     { hp(%), cursed, share(%), level(마스터 장인 단계), mult(마스터 장인 기준 %) }

local ENDINGS = require("data.endings")

local Endings = {}

local MONOPOLY = ENDINGS.monopoly
local ABYSS = ENDINGS.abyss
local OWNED_AREAS = { "grid", "storage", "bench", "furnace", "hero" }     -- 보유 유물을 찾는 영역 (손님 유물은 owned 가 아니다)

-- MONOPOLY.round 단위로 반올림한 정수
local function round_to_unit(value)
    local unit = MONOPOLY.round
    return math.floor(value / unit + 0.5) * unit
end

-- 계약의 마지막 결계 유지비 기본액 (할인·가산 전, 난이도·계절 배율 포함). 계약 안에 징수일이 없으면 0.
-- 계약 일수가 징수일(매달 말일)이면 base_for(max_days) 와 같다
local function final_upkeep(workshop)
    local tribute = workshop.tribute
    if tribute == nil then
        return 0
    end
    local schedule = tribute:schedule()
    local last = schedule[#schedule]
    return last ~= nil and tribute:base_for(last) or 0
end

-- 보유 유물(진열장·보관함·작업대·용광로) 중 가장 높은 강화 단계 (없으면 0)
local function best_level(workshop)
    local inventory, best = workshop.inventory, 0
    for _, area in ipairs(OWNED_AREAS) do
        for index = 1, inventory:size(area) or 0 do
            local item = inventory:get(area, index)
            if item ~= nil and item.owned then
                best = math.max(best, item.level or 0)
            end
        end
    end
    return best
end

-- 상권 독점 기준 = round((per_day × 계약 일수 + upkeep_mult × 마지막 결계 유지비 기본액) × scale[난이도] / round) × round
function Endings.monopoly_gold(workshop)
    local scale = MONOPOLY.scale and MONOPOLY.scale[workshop.difficulty_id] or 1
    return round_to_unit((MONOPOLY.per_day * workshop.max_days + MONOPOLY.upkeep_mult * final_upkeep(workshop)) * scale)
end

function Endings.status(workshop)
    local base_need = Endings.monopoly_gold(workshop)
    local level = best_level(workshop)
    local master = level >= MONOPOLY.master_level
    local max_hp = workshop.max_hp or 0
    return {
        gold = workshop.gold,
        need = master and round_to_unit(base_need * MONOPOLY.master_mult) or base_need,
        base_need = base_need,
        hp_ratio = max_hp > 0 and workshop.hp / max_hp or 0,
        min_hp_ratio = MONOPOLY.min_hp_ratio,
        best_level = level,
        master = master,
        cursed = workshop.stats.final_boss_cursed or 0,       -- 최종일 보스 처치 때 진열장의 저주 유물 수 (systems/Achievements)
        cursed_need = ABYSS.cursed,
        share = workshop.stats.final_boss_share or 0,         -- 그때 진열 유물 중 저주 유물 비율
        share_need = ABYSS.share or 0,
        abyss_contract = workshop.difficulty_id == ABYSS.difficulty,
        trace = workshop.master_trace and workshop.master_trace:status() or nil,   -- 캠페인: 수기 · 봉인진 점화 수
    }
end

-- workshop: 계약 기간을 버텨낸(result == "victory") 공방. 마지막 결계 유지비는 이미 빠져 있다
function Endings.decide(workshop)
    if workshop.master_trace ~= nil then
        return workshop.master_trace:ending()
    end
    local status = Endings.status(workshop)
    if status.abyss_contract and status.cursed >= status.cursed_need and status.share >= status.share_need then
        return "abyss"
    end
    if status.gold >= status.need and status.hp_ratio >= status.min_hp_ratio then
        return "monopoly"
    end
    return "relocation"
end

function Endings.condition_vars()
    return { hp = math.floor(MONOPOLY.min_hp_ratio * 100 + 0.5), cursed = ABYSS.cursed,
        share = math.floor((ABYSS.share or 0) * 100 + 0.5), level = MONOPOLY.master_level,
        mult = math.floor(MONOPOLY.master_mult * 100 + 0.5) }
end

return Endings
