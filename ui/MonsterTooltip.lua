-- ui/MonsterTooltip.lua
-- 밤 전투 레인의 몬스터에 마우스를 올리면 커서 근처에 뜨는 양피지·잉크 툴팁 (화면 밖으로 잘리지 않게 클램핑). 규칙 계산 없음.
--   이름 · 일반/정예/중간 보스/월말 대보스/최종 보스 등급 · 현재/최대 체력 막대
--   · 적용 중인 상태이상(감전 +n% · 둔화/빙결 · 화상 · 붉은 보호막 · 면역 · 균열 아이기스(피해 감소 · 파훼 진행) · 그로기)
--   · 고유 특성(중장갑 연사 경감 · 감전 취약 · 넉백 저항 · 보스 기믹 한 줄 요약)
-- 숫자는 data/combat.lua 에서 읽어 문구(로케일 monster_tip.*)에 넣는다. NightLayoutView 가 공격 연출 위에 그린다.

local I18n = require("systems.I18n")
local Draw = require("ui.Draw")
local Parchment = require("ui.Parchment")
local COMBAT = require("data.combat")
local ENEMIES = require("data.enemies")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local MonsterTooltip = {}

local SIZE = UI.font_size
local LG = love.graphics
local NIGHT = LAYOUT.night
local WIDTH = 268
local PAD = 12
local OFFSET = 20
local MARGIN = 8
local LINE = 18
local HP_BLOCK = 40        -- 체력 막대 + 숫자 줄
local PAPER = { 0.86, 0.77, 0.58 }
local INK, RED = Parchment.INK, Parchment.RED_INK
local TIER_COLORS = { normal = Parchment.EDGE, elite = { 0.55, 0.30, 0.05 }, midboss = { 0.52, 0.10, 0.50 }, boss = RED,
    final = { 0.30, 0.12, 0.62 } }
local STATUS_COLORS = { shock = { 0.26, 0.30, 0.78 }, slow = { 0.12, 0.42, 0.55 }, burn = { 0.72, 0.30, 0.05 }, other = RED,
    aegis = { 0.38, 0.14, 0.66 }, groggy = { 0.58, 0.38, 0.02 } }
local MASTER = ENEMIES.boss_patterns.master

local function percent(ratio)
    return math.floor(ratio * 100 + 0.5)
end

-- (x, y) 에 그려진 몬스터 (그림 크기 = 충돌 반경 × sprite_scale). 여럿이면 가장 가까운 것
function MonsterTooltip.hovered(combat, x, y)
    local lane = NIGHT.lane
    if x < lane.x or x > lane.x + lane.w or y < lane.y or y > lane.y + lane.h then
        return nil
    end
    local best, best_d = nil, math.huge
    for _, monster in ipairs(combat.monsters) do
        local r = monster.radius * NIGHT.sprite_scale
        local d = (monster.x - x) ^ 2 + (monster.y - r * 0.2 - y) ^ 2
        if not monster.dead and d <= r * r and d < best_d then
            best, best_d = monster, d
        end
    end
    return best
end

-- "final"('스승의 흔적' 최종 보스) | "boss"(월말 대보스) | "midboss"(월 중순 중간 보스) | "elite" | "normal"
function MonsterTooltip.tier(monster)
    if monster.spec.final then
        return "final"
    elseif monster:is_boss() then
        return "boss"
    elseif monster:is_midboss() then
        return "midboss"
    end
    return monster.spec.elite and "elite" or "normal"
end

local function number(value)
    local text = string.format("%.1f", value):gsub("%.0$", "")
    return text
end

-- 고유 기믹 한 줄 (그 달의 기믹 강도를 반영한 실제 간격·세기). 간격은 패턴의 주기 수치(interval · summon_interval ·
-- shield_interval · 최종 보스의 lock_interval)를, pct 는 비율 수치(reflect · threshold · heal · 최종 보스의 reduction)를 쓴다
local function gimmick(monster)
    local spec = monster.spec
    local data = ENEMIES.boss_patterns[spec.pattern]
    local k = monster.intensity or 1
    local interval = data.interval or data.summon_interval or data.shield_interval or data.lock_interval
    local ratio = data.reflect or data.threshold or (data.heal and data.heal * k) or data.reduction or 0
    return I18n.t("monster_tip.gimmick_" .. spec.pattern, {
        interval = interval and number(interval / k), clicks = data.clicks, steal = data.steal and math.floor(data.steal * k + 0.5),
        mult = number(data.refund_mult or data.charge_mult or (data.dash_mult and data.dash_mult * (1 + 0.3 * (k - 1))) or 1),
        pct = percent(ratio), count = data.count and (data.count + math.floor((k - 1) / data.per_count)),
    })
end

-- 적용 중인 상태이상 줄 { 문구, 색 키 }
function MonsterTooltip.statuses(monster)
    local list = {}
    if monster:is_shocked() then
        local bonus = COMBAT.damage.shock_bonus * (monster.spec.shock_vulnerability or 1)
        list[#list + 1] = { I18n.t("monster_tip.shocked", { pct = percent(bonus) }), "shock" }
    end
    if monster:is_slowed() then
        local key = monster.slow_factor <= 0.5 and "monster_tip.frozen" or "monster_tip.slowed"
        list[#list + 1] = { I18n.t(key, { pct = percent(1 - monster.slow_factor) }), "slow" }
    end
    if monster:is_burning() then
        list[#list + 1] = { I18n.t("monster_tip.burning", { stacks = monster.burn_stacks, dps = math.floor(monster.burn_dps + 0.5) }),
            "burn" }
    end
    if monster.shield_time > 0 then
        list[#list + 1] = { I18n.t("monster_tip.shielded"), "other" }
    end
    if monster.immunity ~= nil then
        list[#list + 1] = { I18n.t("monster_tip.immune_" .. monster.immunity), "other" }
    end
    local aegis = monster.aegis                   -- 최종 보스: 균열 아이기스 (파훼 진행 = 과부하로 준 피해 / 필요량) · 그로기
    if aegis ~= nil then
        list[#list + 1] = { I18n.t("monster_tip.aegis", { pct = percent(MASTER.reduction),
            progress = math.floor(math.min(1, aegis.dealt / math.max(1, aegis.need)) * 100) }), "aegis" }
    end
    if (monster.groggy_time or 0) > 0 then
        list[#list + 1] = { I18n.t("monster_tip.groggy", { pct = percent(MASTER.groggy_mult - 1) }), "groggy" }
    end
    return list
end

-- 고유 특성·내성 줄. modifiers = 그 밤 몬스터 수정자 (combat.modifiers — interference 가 있으면 방어력은 포탈 간섭에서 온 것)
function MonsterTooltip.traits(monster, modifiers)
    local spec, list = monster.spec, {}
    if spec.rapid_resist ~= nil then
        list[#list + 1] = I18n.t("monster_tip.trait_armor", { pct = percent(spec.rapid_resist) })
    end
    if (spec.shock_vulnerability or 1) > 1 then
        list[#list + 1] = I18n.t("monster_tip.trait_shock_weak", { mult = spec.shock_vulnerability })
    end
    if (monster.defense or 0) > 0 then        -- 겨울 방어력 (사계절 계약) · 포탈 간섭 방어력 ('스승의 흔적')
        local key = modifiers ~= nil and modifiers.interference ~= nil and "monster_tip.trait_interference" or "monster_tip.trait_winter"
        list[#list + 1] = I18n.t(key, { pct = percent(monster.defense) })
    end
    if spec.slow_immune then
        list[#list + 1] = I18n.t("monster_tip.trait_slow_immune")
    end
    local tier = MonsterTooltip.tier(monster)
    if tier ~= "normal" then
        local resist = spec.knockback_resist or (tier == "boss" and COMBAT.knockback.boss_resist or COMBAT.knockback.elite_resist)
        list[#list + 1] = I18n.t("monster_tip.trait_knockback", { pct = percent(resist) })
    end
    if spec.pattern ~= nil then
        list[#list + 1] = gimmick(monster)
    end
    if #list == 0 then
        list[1] = I18n.t("monster_tip.no_traits")
    end
    return list
end

local function wrapped_height(text, size, w)
    local font = Draw.font(size)
    return #select(2, font:getWrap(text, w)) * font:getHeight()
end

-- 툴팁 상자 그리기 (x, y = 커서 위치, modifiers = 그 밤 몬스터 수정자 또는 nil)
function MonsterTooltip.draw(monster, x, y, modifiers)
    local inner = WIDTH - PAD * 2
    local statuses, traits = MonsterTooltip.statuses(monster), MonsterTooltip.traits(monster, modifiers)
    local h = PAD * 2 + 26 + HP_BLOCK + LINE
    for _, line in ipairs(statuses) do
        h = h + wrapped_height(line[1], SIZE.small, inner) + 2
    end
    h = h + (#statuses == 0 and LINE or 0) + 8 + LINE
    for _, line in ipairs(traits) do
        h = h + wrapped_height(line, SIZE.small, inner) + 2
    end
    local bx = x + OFFSET + WIDTH > LAYOUT.screen.w - MARGIN and x - OFFSET - WIDTH or x + OFFSET
    -- 몬스터는 레인 아래쪽 돌길을 걸으므로 커서 위(하늘 쪽)에 띄운다 — 아래 안내 띠·레버에 가리지 않게. 위에 자리가 없을 때만 아래로
    local above = y - OFFSET - h
    local by = above >= NIGHT.lane.y and above or math.min(y + OFFSET, LAYOUT.screen.h - MARGIN - h)
    by = math.max(MARGIN, by)
    Draw.set_color({ 0, 0, 0 }, 0.45)
    LG.rectangle("fill", bx + 5, by + 6, WIDTH, h, 6, 6)
    Draw.set_color(PAPER)
    LG.rectangle("fill", bx, by, WIDTH, h, 6, 6)
    Draw.set_color(INK)
    LG.setLineWidth(3)
    LG.rectangle("line", bx, by, WIDTH, h, 6, 6)
    local tx, ty, tier = bx + PAD, by + PAD, MonsterTooltip.tier(monster)
    local name = I18n.t("monsters." .. monster.type_id)
    Draw.text(name, tx, ty, inner - 64, "left", Draw.fit_size(name, inner - 64, { "item_name", SIZE.body }), INK)
    Draw.text(I18n.t("monster_tip.tier_" .. tier), tx, ty + 3, inner, "right", "label", TIER_COLORS[tier])
    ty = ty + 26
    Draw.bar(tx, ty + 4, inner, 9, math.max(0, monster.hp) / monster.max_hp, RED)
    Draw.text(I18n.t("monster_tip.hp", { hp = math.max(0, math.ceil(monster.hp)), max = math.ceil(monster.max_hp) }), tx, ty + 14,
        inner, "left", SIZE.small, INK)
    ty = ty + HP_BLOCK
    Draw.text(I18n.t("monster_tip.status_title"), tx, ty, inner, "left", "label", RED)
    ty = ty + LINE
    for _, line in ipairs(statuses) do
        Draw.text(line[1], tx, ty, inner, "left", SIZE.small, STATUS_COLORS[line[2]])
        ty = ty + wrapped_height(line[1], SIZE.small, inner) + 2
    end
    if #statuses == 0 then
        Draw.text(I18n.t("monster_tip.no_status"), tx, ty, inner, "left", SIZE.small, INK, 0.6)
        ty = ty + LINE
    end
    ty = ty + 8
    Draw.text(I18n.t("monster_tip.traits_title"), tx, ty, inner, "left", "label", RED)
    ty = ty + LINE
    for _, line in ipairs(traits) do
        Draw.text(line, tx, ty, inner, "left", SIZE.small, INK)
        ty = ty + wrapped_height(line, SIZE.small, inner) + 2
    end
    return bx, by, WIDTH, h
end

-- pointer 아래 몬스터가 있으면 툴팁 (드래그 중이 아닐 때). 그린 몬스터 또는 nil
function MonsterTooltip.draw_hovered(combat, pointer)
    local monster = MonsterTooltip.hovered(combat, pointer.x, pointer.y)
    if monster ~= nil then
        MonsterTooltip.draw(monster, pointer.x, pointer.y, combat.modifiers)
    end
    return monster
end

return MonsterTooltip
