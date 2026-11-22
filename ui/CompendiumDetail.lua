-- ui/CompendiumDetail.lua
-- 유물 도감 오른쪽 상세 칸: 큰 아이콘 · 이름 · 아키타입/분류 · 무기 스탯(공격·연사·피해 속성·탄종) · 설명 · 시너지 문구,
-- 특수 유물은 해금 업적, 봉인된 특수 유물은 실루엣과 해금 조건만 보여 준다. 규칙 계산 없음 (data 값을 그대로 표시 —
-- 업적 조건 문구의 자리표시자 {level} · {cursed} · {percent} 는 systems/Achievements.condition_vars 가 채운다).

local I18n = require("systems.I18n")
local Achievements = require("systems.Achievements")
local Draw = require("ui.Draw")
local Frame = require("ui.Frame")
local ItemRenderer = require("ui.ItemRenderer")
local ITEMS = require("data.items")
local UI = require("data.ui")

local CompendiumDetail = {}

local C = UI.color
local SIZE = UI.font_size
local PAD = 16
local ICON = 104
local LINE_GAP = 6

local function wrapped_height(text, width, spec)
    local font = Draw.font(spec)
    local _, lines = font:getWrap(text, width)
    return math.max(1, #lines) * font:getHeight()
end

-- 위에서부터 문단을 쌓는 작은 도우미
local function writer(x, y, w)
    local cursor = { y = y }
    function cursor.line(text, spec, color, alpha)
        Draw.text(text, x, cursor.y, w, "center", spec, color, alpha)
        cursor.y = cursor.y + wrapped_height(text, w, spec) + LINE_GAP
    end
    function cursor.gap(amount)
        cursor.y = cursor.y + amount
    end
    return cursor
end

-- 시너지 문구 (label_key 가 있는 효과의 문구를 모은다)
local function synergy_text(proto)
    local labels = {}
    for _, effect in ipairs(proto.effects or {}) do
        if effect.label_key ~= nil then
            labels[#labels + 1] = I18n.t(effect.label_key)
        end
    end
    return #labels > 0 and table.concat(labels, " · ") or nil
end

local function draw_stats(cursor, proto)
    if proto.category ~= "weapon" then
        return
    end
    cursor.line(I18n.t("compendium.stats_weapon", {
        attack = proto.attack, rate = string.format("%.2g", proto.fire_rate),
    }), SIZE.body, C.text)
    cursor.line(I18n.t("compendium.stats_damage", {
        damage = I18n.t("compendium.damage." .. (proto.damage_type or "physical")),
        projectile = I18n.t("compendium.projectile." .. (proto.projectile or "bullet")),
    }), SIZE.small, C.text_dim)
end

-- entry = { id, item, locked, achievement (업적 id 또는 nil) }
function CompendiumDetail.draw(entry, rect, time)
    Frame.inset(rect.x, rect.y, rect.w, rect.h, 10, { 0.09, 0.08, 0.11 })
    if entry == nil then
        return
    end
    local proto = ITEMS.prototypes[entry.id]
    local archetype_color = ITEMS.archetypes[proto.archetype].color
    local cx = rect.x + rect.w / 2
    local icon_y = rect.y + PAD + ICON / 2
    Draw.glow(cx, icon_y, ICON * 0.75, proto.special and C.gold or archetype_color, 0.35 + 0.1 * math.sin(time * 2))
    local cursor = writer(rect.x + PAD, icon_y + ICON / 2 + 12, rect.w - PAD * 2)
    if entry.locked then
        ItemRenderer.draw_silhouette(entry.item, cx, icon_y, ICON, { 0.02, 0.02, 0.03 }, 0.92)
        cursor.line(I18n.t("compendium.locked_name"), "item_name", C.text_dim)
        cursor.gap(6)
        local id = entry.achievement
        cursor.line(I18n.t("achievements." .. id .. ".name"), "tooltip_name", C.gold)
        cursor.line(I18n.t("compendium.unlock_condition", {
            condition = I18n.t("achievements." .. id .. ".condition", Achievements.condition_vars(id)),
        }), SIZE.small, C.text)
        return
    end
    ItemRenderer.draw(entry.item, cx, icon_y, ICON, { time = time, badges = false })
    cursor.line(I18n.item_name(entry.item), "item_name", proto.special and C.gold or C.text)
    cursor.line(I18n.t("compendium.kind_line", {
        archetype = I18n.t("archetypes." .. proto.archetype), category = I18n.t("categories." .. (proto.subtype or proto.category)),
    }), SIZE.small, archetype_color)
    cursor.gap(4)
    draw_stats(cursor, proto)
    cursor.gap(4)
    cursor.line(I18n.item_description(entry.item), SIZE.small, C.text)
    local synergy = synergy_text(proto)
    if synergy ~= nil then
        cursor.line(I18n.t("compendium.synergy", { label = synergy }), SIZE.small, C.accent)
    end
    if proto.innate_flaw == "curse" then
        cursor.line(I18n.t("compendium.innate_curse"), SIZE.small, C.link_curse)
    end
    if entry.achievement ~= nil then
        cursor.gap(4)
        cursor.line(I18n.t("compendium.unlocked_by", { name = I18n.t("achievements." .. entry.achievement .. ".name") }),
            SIZE.tiny, C.gold)
    end
end

return CompendiumDetail
