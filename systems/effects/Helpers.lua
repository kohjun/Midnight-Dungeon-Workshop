-- systems/effects/Helpers.lua
-- 효과 핸들러 공용 도우미: 유물의 그리드 위치, 보너스 문구, 인접 배율 효과.
-- 핸들러 팩토리 시그니처: (item, effect, ctx) → { { event, fn, priority? }, ... }  (ctx = { inventory, workshop })

local Grid = require("systems.Grid")
local I18n = require("systems.I18n")

local Helpers = {}

function Helpers.grid_index(inventory, item)
    local area, index = inventory:locate(item)
    if area == "grid" then
        return index
    end
    return nil
end

function Helpers.add_bonus(stat, text)
    stat.bonuses[#stat.bonuses + 1] = text
end

-- "유물 이름: 보너스 문구" (effect.label_key 는 로케일 키)
function Helpers.add_label_bonus(stat, item, effect)
    Helpers.add_bonus(stat, I18n.t("bonus.adjacent", { name = I18n.item_name(item), label = I18n.t(effect.label_key) }))
end

-- 두 유물이 그리드에서 상하좌우로 붙어 있는지
function Helpers.adjacent(inventory, a, b)
    local ia, ib = Helpers.grid_index(inventory, a), Helpers.grid_index(inventory, b)
    if ia == nil or ib == nil then
        return false
    end
    for _, neighbor in ipairs(Grid.neighbors(ia)) do
        if neighbor == ib then
            return true
        end
    end
    return false
end

-- 보너스 몫(배율 - 1)에 강화 배율을 곱한다 — +10 증폭기의 +25% 는 +120%. 감소(배율 < 1)는 그대로
local function scaled(mult, power)
    if mult == nil or mult <= 1 then
        return mult or 1
    end
    return 1 + (mult - 1) * power
end

-- 인접 칸 배율 효과 공통 구현 (kind: 연결선 종류 "boost" | "curse"). 증폭 몫은 그 유물의 강화 단계만큼 커진다
function Helpers.adjacent_modifier(item, effect, inventory, kind)
    return { {
        event = "grid:compute_stats",
        priority = 10,
        fn = function(payload)
            local index = Helpers.grid_index(inventory, item)
            if index == nil then
                return
            end
            for _, neighbor in ipairs(Grid.neighbors(index)) do
                local target = inventory:get("grid", neighbor)
                local stat = target and payload.stats[target]
                if stat ~= nil and (effect.target == nil or effect.target == "any" or target.category == effect.target) then
                    local power = item:forge_power()
                    stat.attack_mult = stat.attack_mult * scaled(effect.attack_mult, power)
                    stat.rate_mult = stat.rate_mult * scaled(effect.rate_mult, power)
                    stat.income_mult = stat.income_mult * scaled(effect.income_mult, power)
                    Helpers.add_label_bonus(stat, item, effect)
                    payload.links[#payload.links + 1] = { from = index, to = neighbor, kind = kind }
                end
            end
        end,
    } }
end

return Helpers
