-- ui/HeroText.lua
-- 주인공 · 방어구 문구 만들기 (로케일 hero.* — 규칙 계산은 systems/HeroStats 가 한다).
--   armor_lines(item)   : 방어구 유물 툴팁의 스탯 줄 { { text, color } } (+ 갑옷의 E 스킬 줄)
--   place_line(item)    : 3분류 배치 안내 한 줄 (무기 = 진열장 + 주인공 / 방어구 = 주인공 전용 / 유물 = 진열장 전용)
--   category_line(item) : 방어구·무기의 "분류 · 부위" 표기
--   summary(stats)      : 장비창 아래 스탯 요약 줄 (HP / 공격력 / 방어력 / 이동속도)
--   tooltip(workshop)   : 주인공 전용 툴팁 — 제목, 줄 목록 { { 문구, 색 } } (ui/HoverTooltip 형식):
--                         스탯 · 장착 4부위(이름 +N · 내구도 %) · 스킬 Q / E / R · 밤 레인 기여

local I18n = require("systems.I18n")
local HeroStats = require("systems.HeroStats")
local HERO = require("data.hero")
local ARMORS = require("data.armors")
local UI = require("data.ui")

local HeroText = {}

local C = UI.color
local STAT_ORDER = {
    helmet = { "crit", "resist", "cooldown" },
    chest = { "max_hp", "defense" },
    boots = { "move_speed", "roll_cooldown", "roll_invuln" },
}
local PERCENT = { crit = true, resist = true, cooldown = true, move_speed = true, roll_cooldown = true }
local SKILL_COLOR = { q = { 1.0, 0.72, 0.36 }, e = { 0.62, 0.86, 1.0 }, r = { 1.0, 0.46, 0.34 } }
local BROKEN = { 0.62, 0.58, 0.56 }

-- 소수 한 자리까지 (끝의 .0 은 뗀다)
local function number(value)
    return (string.format("%.1f", value):gsub("%.0$", ""))
end

local function percent(value)
    return number(value * 100)
end

local function slot_name(slot)
    return I18n.t("hero.slots." .. slot)
end

-- "[Q] 이름 — 요약 (쿨 N초)"
function HeroText.skill(key, skill)
    local vars = {
        power = number(skill.power or 0), duration = number(skill.duration or 0), reduction = percent(skill.reduction or 0),
        shield = percent(skill.shield or 0), reflect = percent(skill.reflect or 0),
    }
    return I18n.t("hero.tooltip.skill", {
        key = key, name = I18n.t("hero.skills." .. skill.id .. ".name"),
        summary = I18n.t("hero.skills." .. skill.id .. ".summary", vars), cooldown = number(skill.cooldown),
    })
end

function HeroText.armor_lines(item)
    local lines = {}
    local mult = item:gear_mult()
    local color = item:is_worn_out() and BROKEN or C.good
    if item:is_worn_out() then
        lines[#lines + 1] = { text = I18n.t("hero.worn_out"), color = C.danger }
    end
    for _, key in ipairs(STAT_ORDER[item.equip_slot] or {}) do
        local value = (item.proto.stats[key] or 0) * mult
        local vars = { value = PERCENT[key] and percent(value) or (key == "roll_invuln" and string.format("%.2f", value) or number(value)) }
        if key == "defense" then
            vars.guard = percent(math.min(HERO.guard.max, value * HERO.guard.per_defense))
        end
        lines[#lines + 1] = { text = I18n.t("hero.stat." .. key, vars), color = color }
    end
    local skill = item.proto.skill and ARMORS.skills[item.proto.skill]
    if skill ~= nil then
        local spec = { id = item.proto.skill }
        for key, value in pairs(skill) do
            spec[key] = value
        end
        lines[#lines + 1] = { text = HeroText.skill("E", spec), color = SKILL_COLOR.e }
    end
    return lines
end

function HeroText.place_line(item)
    return I18n.t("hero.place." .. item.category)
end

function HeroText.category_line(item)
    return I18n.t("hero.category", { category = I18n.t("categories." .. item:role()), slot = slot_name(item.equip_slot) })
end

function HeroText.summary(stats)
    return I18n.t("hero.summary", {
        hp = number(stats.max_hp), attack = number(stats.attack), defense = number(stats.defense), speed = percent(stats.move_speed),
    })
end

local function gear_line(entry)
    local label = slot_name(entry.slot)
    local item = entry.item
    if item == nil then
        return { entry.slot == "weapon" and I18n.t("hero.unarmed") or I18n.t("hero.tooltip.gear_empty", { slot = label }), C.text_dim }
    end
    local vars = { slot = label, name = I18n.item_name(item), level = item.level, pct = math.floor(item.durability + 0.5) }
    if entry.broken then
        return { I18n.t("hero.tooltip.gear_broken", vars), C.danger }
    end
    return { I18n.t("hero.tooltip.gear", vars), item:grade_info().color }
end

function HeroText.tooltip(workshop)
    local stats = HeroStats.compute(workshop)
    local lines = {
        { I18n.t("hero.tooltip.vital", { hp = number(stats.max_hp), attack = number(stats.attack), defense = number(stats.defense) }) },
        { I18n.t("hero.tooltip.offense", {
            crit = percent(stats.crit), mult = number(stats.crit_mult), speed = percent(stats.move_speed),
            roll = string.format("%.2f", stats.roll_cooldown),
        }) },
    }
    if stats.resist > 0 or stats.cooldown > 0 then
        lines[#lines + 1] = { I18n.t("hero.tooltip.utility", { resist = percent(stats.resist), cooldown = percent(stats.cooldown) }) }
    end
    for _, entry in ipairs(stats.gear) do
        lines[#lines + 1] = gear_line(entry)
    end
    lines[#lines + 1] = { HeroText.skill("Q", stats.skills.q), SKILL_COLOR.q }
    lines[#lines + 1] = { HeroText.skill("E", stats.skills.e), SKILL_COLOR.e }
    lines[#lines + 1] = { HeroText.skill("R", stats.skills.r), SKILL_COLOR.r }
    lines[#lines + 1] = { I18n.t("hero.tooltip.lane", {
        interval = string.format("%.2f", stats.strike_interval), guard = percent(stats.guard), counter = number(stats.counter),
    }), C.gold }
    return workshop:personalize(I18n.t("hero.tooltip.title")), lines
end

return HeroText
