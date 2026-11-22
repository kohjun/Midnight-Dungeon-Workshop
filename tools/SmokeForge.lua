-- tools/SmokeForge.lua
-- 용광로 +1 ~ +10 헤드리스 검사 (SmokeTest 가 SmokeQuests 다음에 실행) — data/forge.lua · systems/Forge · ui/FurnaceView · ui/ForgeTier:
--   결과 확률표(합 1 · +1 100% · +2~3 유지 · +4~5 하락 · +6 이상 하락/파괴 비율) · 지수 화력 곡선(+10 = x4.8) · 증폭기 시너지 배율
--   판매가 sale_share: +10 판매가 = Item:sale_value 공식 그대로 · 화력 배율로 판 값의 80% 미만 (화력은 x4.8 그대로) ·
--     세척한 전설 황금 성배의 +1 판매가 증가분 < +1 비용 (sale_share 가 없으면 넘는다) · 모든 원형(전설 · 세척) +1 되팔기 손해
--   결과 경로(고정): 성공 = +1 · 내구도 100% / 유지 = 단계·내구도 그대로 / 하락 = -1 · 내구도 그대로 / 파괴 = 사라짐 · 고철 · 잃은 수 +1
--   +10 = 불멸 각인(강화 불가 · 확률표 없음 · 사유 forge_max) · 실제 난수 +4 시도 300번 ≈ 64% (파괴 0)
--   시각 등급(+5 황금 · +7 자홍 룬 · +9 심연) · 확률 막대 픽셀 · 용광로 안내판(빈 칸 · +4 · +10) 오프스크린 렌더
--   (--shots 면 smoke_furnace.png — 확률 막대 · 안내판 3종 · 등급 테두리/게이지 견본)

local SmokeForge = {}

local function check(condition, message)
    if not condition then
        error("SmokeForge: " .. message, 2)
    end
end

local function near(a, b, eps)
    return math.abs(a - b) < (eps or 1e-6)
end

local function workshop()
    local w = require("systems.Workshop")({ difficulty = "broker" })
    w.gold, w.tempering_stones = 1000000, 999
    return w
end

-- 용광로의 item 을 한 번 강화 (force 로 결과 고정). forge:resolved 페이로드 반환
local function forge(w, force)
    local EventBus = require("core.EventBus")
    local probe, last = {}, nil
    EventBus.subscribe("forge:resolved", function(p) last = p end, { owner = probe })
    check(w.forge:start(force), "the forge should start")
    while w.forge.forging ~= nil do
        w.forge:update(0.1)
    end
    EventBus.unsubscribe_owner(probe)
    return last
end

-- entities/Item:sale_value 공식을 data 로 다시 계산 (곱하는 순서도 같게) — share = 판매가에 반영하는 강화 몫
local function sale_formula(item, share)
    local ITEMS, FORGE = require("data.items"), require("data.forge")
    local clean = item.cleaned and (item.clean_mult or require("data.balance").appraisal.clean_mult) or 1
    local flaw = item.flaw and ITEMS.flaws[item.flaw].value_mult or 1
    local forge = 1 + ((FORGE.power[item.level] or 1) - 1) * share
    return math.max(1, math.floor(item.proto.value * (ITEMS.grades[item.grade].mult * clean) * forge * flaw + 0.5))
end

-- 판매가에는 강화 몫의 sale_share 만 (화력은 강화 배율 그대로 — +10 = x4.8): 되팔려고 강화하는 클릭 반복이 이득이 아니다
local function check_sale_share()
    local FORGE = require("data.forge")
    local ItemFactory = require("systems.ItemFactory")
    check(FORGE.sale_share > 0 and FORGE.sale_share < 1, "only part of the forge power reaches the sale price (0 < sale_share < 1)")
    local top, flat = ItemFactory.make_ready("flame_sword", "rare", 10), ItemFactory.make_ready("flame_sword", "rare", 0)
    check(top:sale_value() == sale_formula(top, FORGE.sale_share) and flat:sale_value() == sale_formula(flat, FORGE.sale_share),
        string.format("sale value = value x quality x (1 + (power - 1) x sale_share) x flaw: +10 %d vs %d",
            top:sale_value(), sale_formula(top, FORGE.sale_share)))
    local full_price = flat:sale_value() * FORGE.power[10]
    check(near(top:sale_forge_mult(), 1 + (FORGE.power[10] - 1) * FORGE.sale_share)
        and near(top:power_mult() / flat:power_mult(), FORGE.power[10]) and top:sale_value() < full_price * 0.8,
        string.format("+10 sells for %d, below 80%% of the full x%.1f power price %.0f, while its attack keeps the full power",
            top:sale_value(), FORGE.power[10], full_price))
    -- 비싼 유물(세척한 전설 황금 성배)도 +1 판매가 증가분이 +1 비용보다 작다 — sale_share 가 없으면(= 1) 강화비가 남는다
    local cost = FORGE.levels[1].gold
    local cup, cup1 = ItemFactory.make_ready("golden_chalice", "legendary", 0), ItemFactory.make_ready("golden_chalice", "legendary", 1)
    local gain, full = cup1:sale_value() - cup:sale_value(), sale_formula(cup1, 1) - cup:sale_value()
    check(cup.cleaned and full >= cost and gain < cost, string.format("a cleaned legendary golden chalice: +1 adds %d G "
        .. "(would add %d G at full share) vs the +1 cost %d G", gain, full, cost))
    for _, id in ipairs(ItemFactory.prototype_ids()) do                -- 어떤 유물도 +1 되팔기로 남지 않는다 (전설 · 세척 기준)
        local base, raised = ItemFactory.make_ready(id, "legendary", 0), ItemFactory.make_ready(id, "legendary", 1)
        check(raised:sale_value() - base:sale_value() < cost, id .. ": forging +1 for resale should not pay back its cost")
    end
end

local function check_table()
    local FORGE = require("data.forge")
    local ItemFactory = require("systems.ItemFactory")
    local w = workshop()
    local item = ItemFactory.make_ready("flame_sword", "common", 0)
    for level = 0, 9 do
        item.level = level
        local o = w.forge:odds(item)
        check(near(o.success + o.keep + o.down + o.destroy, 1), "odds add up to 1 at +" .. level)
    end
    item.level = 0
    check(w.forge:odds(item).success == 1, "+1 never fails")
    item.level = 1
    check(near(w.forge:odds(item).keep, 0.12) and w.forge:odds(item).destroy == 0, "+2 failure keeps the level")
    item.level = 3
    check(near(w.forge:odds(item).down, 0.36) and w.forge:odds(item).destroy == 0, "+4 failure drops a level")
    item.level = 5
    check(near(w.forge:odds(item).destroy, 0.6 * 0.15) and near(w.forge:odds(item).down, 0.6 * 0.85), "+6 failure: 85% drop / 15% shatter")
    item.level = 9
    check(near(w.forge:odds(item).destroy, 0.92 * 0.35), "+10 failure: 35% shatter")
    check(FORGE.power[10] == 4.8 and FORGE.power[5] > FORGE.power[4] * 1.1, "exponential power curve up to x4.8")
    local plain, best = ItemFactory.make_ready("flame_sword", "common", 0), ItemFactory.make_ready("flame_sword", "common", 10)
    check(near(best:attack() / plain:attack(), 4.8, 1e-3), "+10 weapons hit x4.8 harder")
    check_sale_share()
    -- 증폭기 시너지: 보너스 몫이 강화 배율만큼 커진다 (마나 수정 +50% → +10 이면 +240%)
    local crystal = ItemFactory.make_ready("mana_crystal", "common", 0)
    w.inventory:place(plain, "grid", 13)
    w.inventory:place(crystal, "grid", 12)
    local base = w:grid_stats().stats[plain].attack_mult
    crystal.level = 10
    w._grid_stats = nil
    check(near(base, 1.5) and near(w:grid_stats().stats[plain].attack_mult, 1 + 0.5 * 4.8), "a +10 amplifier boosts x3.4")
    w:destroy()
end

local function check_paths()
    local ItemFactory = require("systems.ItemFactory")
    local FORGE = require("data.forge")
    local w = workshop()
    local item = ItemFactory.make_ready("flame_sword", "common", 0)
    item.durability = 20
    w.inventory:place(item, "furnace", 1)
    local gold = w.gold
    check(forge(w).outcome == "success" and item.level == 1 and item.durability == 100 and w.gold == gold - FORGE.levels[1].gold,
        "+1: gold only, always succeeds, durability back to 100%")
    item.durability = 33
    check(forge(w, "keep").outcome == "keep" and item.level == 1 and item.durability == 33, "a kept level keeps the durability")
    item.level, item.durability = 3, 41
    check(forge(w, "down").outcome == "down" and item.level == 2 and item.durability == 41, "a failed +4 drops to +2, durability kept")
    item.level = 5
    local lost, before = w.stats.items_lost, w.gold
    check(forge(w, "destroyed").outcome == "destroyed" and w.inventory:locate(item) == nil and w.stats.items_lost == lost + 1,
        "a failed +6 can shatter the relic")
    check(w.gold > before - require("data.forge").levels[6].gold, "shattering pays back some scrap")
    local seal = ItemFactory.make_ready("storm_rod", "rare", 9)
    seal.durability = 5
    w.inventory:place(seal, "furnace", 1)
    check(forge(w, "success").outcome == "success" and seal.level == 10 and seal:is_immortal() and seal.durability == 100,
        "+10 grants the immortal seal")
    check(not seal:can_forge() and w.forge:odds(seal) == nil and w.forge:cost_block(seal) == "disabled.forge_max", "+10 is the cap")
    w.inventory:remove(seal)
    local probe = ItemFactory.make_ready("flame_sword", "common", 3)       -- 실제 난수: +4 시도 300번
    w.inventory:place(probe, "furnace", 1)
    local wins = 0
    for _ = 1, 300 do
        probe.level = 3
        local result = forge(w).outcome
        check(result ~= "destroyed", "+4 never shatters")
        wins = wins + (result == "success" and 1 or 0)
    end
    check(wins > 300 * 0.55 and wins < 300 * 0.73, "+4 succeeds about 64% of the time, got " .. wins .. "/300")
    w:destroy()
end

local INPUT = {
    time = 0, is_drop_candidate = function() return false end, drop_target = function() return nil end,
    hovered_slot = function() return nil end, hovered_item = function() return nil end, is_dragging = function() return false end,
}

local function check_visuals(shots)
    local Viewport = require("core.Viewport")
    local ForgeTier = require("ui.ForgeTier")
    local FurnaceView = require("ui.FurnaceView")
    local ItemRenderer = require("ui.ItemRenderer")
    local ItemStatus = require("ui.ItemStatus")
    local ItemFactory = require("systems.ItemFactory")
    check(ForgeTier.of(4) == nil and ForgeTier.of(5).id == "gold" and ForgeTier.of(7).id == "rune" and ForgeTier.of(10).id == "mythic",
        "visual tiers at +5 / +7 / +9")
    local canvas = love.graphics.newCanvas(Viewport.width(), Viewport.height())
    love.graphics.push("all")
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.clear(0.08, 0.07, 0.08, 1)
    FurnaceView.draw_odds({ success = 0.52, keep = 0, down = 0.48, destroy = 0 }, 10, 10, 300, 10)
    love.graphics.setCanvas()
    local data = canvas:newImageData()
    local r1, g1 = data:getPixel(10 + 75, 15)
    local r2, g2, b2 = data:getPixel(10 + 240, 15)
    check(g1 > r1 and r2 > 0.8 and g2 > 0.5 and b2 < 0.45, "the odds bar paints success green and drop amber")
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.clear(0.08, 0.07, 0.08, 1)
    local w = workshop()
    local LAYOUT = require("data.layout")
    for i, level in ipairs({ false, 4, 10 }) do                     -- 빈 용광로(false) · +4 · +10 안내판을 세로로
        if level then
            w.inventory:place(ItemFactory.make_ready("flame_sword", "rare", level), "furnace", 1)
        end
        love.graphics.push()
        love.graphics.translate(0, (i - 1) * 170 - LAYOUT.day.furnace_section.y + 20)
        FurnaceView.draw(w, INPUT, 1, nil)
        love.graphics.pop()
        local placed = w.inventory:get("furnace", 1)
        if placed ~= nil then
            w.inventory:remove(placed)
        end
    end
    for i, spec in ipairs({ { 0, 100 }, { 3, 45 }, { 5, 22 }, { 7, 0 }, { 10, 100 } }) do       -- 등급 테두리 · 뱃지 · 게이지
        local item = ItemFactory.make_ready("flame_sword", "rare", spec[1])
        item.durability = spec[2]
        local x, y = 760 + ((i - 1) % 3) * 160, 80 + math.floor((i - 1) / 3) * 160
        ForgeTier.frame(item.level, x, y, 120, 120, 1.3)
        ItemRenderer.draw(item, x + 60, y + 60, 90, { time = 1.3 })
        ItemStatus.draw(item, x, y, 120, 120, 1.3)
    end
    love.graphics.setCanvas()
    love.graphics.pop()
    if shots then
        canvas:newImageData():encode("png", "smoke_furnace.png")
    end
    w:destroy()
end

function SmokeForge.run(log, shots)
    require("core.RNG").set_seed(6161)
    check_table()
    check_paths()
    check_visuals(shots)
    log("forge ok (+1~+10 odds table, x4.8 power curve, sale_share sale formula and no +1 resale profit, +10 amplifier x3.4, "
        .. "success/keep/drop/shatter paths with durability reset, "
        .. "+10 immortal cap, +4 ~64%% over 300 rolls, tiers +5/+7/+9, odds bar pixels, furnace panels)")
end

return SmokeForge
