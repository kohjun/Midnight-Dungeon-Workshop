-- ui/HoverTooltip.lua
-- 범용 호버 툴팁 (RunState 소유): 상단 HUD 상태 카드 · 메뉴 버튼과 낮 공방 도구(UV 스캐너 · 브러시 · 용광로 · 보관함 · 진열장 머리)에
-- 포인터를 잠깐(DELAY) 올려 두면 어두운 양피지·잉크 상자로 설명을 띄운다. 화면 밖으로 잘리지 않게 클램핑한다.
-- 영역은 data/layout.lua 좌표에서 만들고, 문구는 로케일 hover.* (설정 버튼은 밤 전투 일시정지 안내 포함). 규칙 계산 없음.
-- '스승의 흔적' 런(workshop.master_trace)에서만: [수기 · 봉인진] 버튼(trace.hover.*) · 날짜 카드에 포탈 간섭 단계와 지금 효과
-- (trace.interference.level · hover_body — 수치는 workshop:season_mods()).

local Class = require("lib.classic")
local I18n = require("systems.I18n")
local Draw = require("ui.Draw")
local CalendarText = require("ui.CalendarText")
local BALANCE = require("data.balance")
local TRACE = require("data.master_trace")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local HoverTooltip = Class:extend()

local C = UI.color
local HeroText = require("ui.HeroText")
local LaneHero = require("ui.LaneHero")

local LG = love.graphics
local HUD, B, DAY, NIGHT = LAYOUT.hud, LAYOUT.buttons, LAYOUT.day, LAYOUT.night
local DELAY = 0.35
local WIDTH = 300
local PAD = 12
local OFFSET = 18
local HEADER = 30
local PAPER = { 0.15, 0.115, 0.085 }
local INK = { 0.03, 0.02, 0.02 }
local BRASS = { 0.80, 0.62, 0.30 }
local BODY = { 0.93, 0.87, 0.76 }

local function header(rect)
    return { x = rect.x, y = rect.y, w = rect.w, h = HEADER }
end

local PURSE = HUD.purse
local HERO_NIGHT = (function()                      -- 밤 레인의 주인공 스프라이트 둘레
    local x, ground_y, height = LaneHero.anchor()
    return { x = x - height * 0.36, y = ground_y - height - 4, w = height * 0.72, h = height + 8 }
end)()
-- { id, rect, phase = nil(둘 다) | "day" | "night", trace = true('스승의 흔적' 런에서만) } — 앞에 있는 영역이 먼저
local REGIONS = {
    { id = "badge", rect = HUD.badge }, { id = "ward", rect = HUD.ward }, { id = "tribute", rect = HUD.tribute },
    { id = "gold", rect = { x = PURSE.x, y = PURSE.y, w = 92, h = PURSE.h } },
    { id = "stones", rect = { x = PURSE.x + 92, y = PURSE.y, w = PURSE.w - 92, h = PURSE.h } },
    { id = "guild", rect = B.guild }, { id = "quests", rect = B.quests }, { id = "compendium", rect = B.compendium },
    { id = "upgrades", rect = B.upgrades }, { id = "settings", rect = B.settings },
    { id = "journal", rect = B.journal, phase = "day", trace = true },
    { id = "journal", rect = B.journal_night, phase = "night", trace = true },
    { id = "uv", rect = B.uv, phase = "day" }, { id = "brush", rect = B.brush, phase = "day" },
    { id = "furnace", rect = DAY.furnace_info, phase = "day" },
    { id = "hero", rect = DAY.hero_title, phase = "day" }, { id = "hero", rect = DAY.hero_stats, phase = "day" },
    { id = "hero", rect = HERO_NIGHT, phase = "night" },
    { id = "storage", rect = DAY.rack_title, phase = "day" },
    { id = "grid", rect = header(DAY.grid_section), phase = "day" },
    { id = "grid", rect = { x = NIGHT.grid_panel.x + 80, y = NIGHT.grid_panel.y - 16, w = NIGHT.grid_panel.w - 160, h = 30 }, phase = "night" },
}

local function percent(v)
    return math.floor(v * 100 + 0.5)
end

-- 툴팁 내용: 제목 + 본문 줄들 { 문구, 색 }
local CONTENT = {
    badge = function(w)
        local night = w.phase == "night"
        local line = night and I18n.t("hover.badge.night", { seconds = math.ceil(w.combat:time_left()) })
            or I18n.t("hover.badge.day", { count = w.customers_left })
        local lines = { { line }, { I18n.t("hover.badge.contract", { date = CalendarText.date(w.day), day = w.day, max = w.max_days }),
            C.accent } }
        local season = w:season()
        if season ~= nil then
            lines[3] = { I18n.t("hover.badge.season", { season = CalendarText.season_name(season),
                effect = CalendarText.season_effect(w.rules, w.day) }), C.link_boost }
        end
        local level = w:interference()
        if level ~= nil then                -- '스승의 흔적': 포탈 간섭 단계 + 지금 효과 (실제 수정자 값)
            local mods = w:season_mods()
            lines[#lines + 1] = { I18n.t("trace.interference.level", { level = level }), TRACE.interference.color }
            lines[#lines + 1] = { I18n.t("trace.interference.hover_body", { max = TRACE.interference.months,
                hp = CalendarText.percent(mods.monster_hp_mult - 1), def = CalendarText.percent(mods.monster_defense),
                heat = CalendarText.percent(mods.overheat_add), honest = CalendarText.percent(1 - mods.honest_mult) }) }
        end
        return I18n.t("hover.badge.title"), lines
    end,
    ward = function(w)
        return I18n.t("hover.ward.title", { hp = math.ceil(w.hp), max = w.max_hp }), { { I18n.t("hover.ward.body") } }
    end,
    tribute = function(w)
        local due, amount = w.tribute:next_due(w.day)
        if due == nil then
            return I18n.t("hover.tribute.title"), { { I18n.t("hover.tribute.none"), C.good } }
        end
        local lines = { { I18n.t("hover.tribute.due", { date = CalendarText.date(due), amount = amount, days = due - w.day,
            gold = w.gold }) } }
        if w.gold < amount then
            lines[2] = { I18n.t("hover.tribute.short", { shortfall = amount - w.gold }), C.danger }
        else
            lines[2] = { I18n.t("hover.tribute.ready"), C.good }
        end
        return I18n.t("hover.tribute.title"), lines
    end,
    gold = function(w)
        return I18n.t("hover.gold.title", { gold = w.gold }), { { I18n.t("hover.gold.body") } }
    end,
    stones = function(w)
        return I18n.t("hover.stones.title", { count = w.tempering_stones }), { { I18n.t("hover.stones.body") } }
    end,
    settings = function()
        return I18n.t("hover.settings.title"), { { I18n.t("hover.settings.body") }, { I18n.t("hover.settings.pause"), C.accent } }
    end,
    uv = function(w)
        local rate = CalendarText.percent(w.appraisal:lens_drain_per_second() / 100)        -- 실제 소모량 (난이도·개조·영구 강화 반영)
        return I18n.t("hover.uv.title"), { { I18n.t("hover.uv.body") }, { I18n.t("hover.uv.cost", { rate = rate,
            value = math.floor(w.supplies.uv), low = BALANCE.supplies.low_warning }), C.uv } }
    end,
    brush = function(w)
        return I18n.t("hover.brush.title"), { { I18n.t("hover.brush.body") },
            { I18n.t("hover.brush.cost", { cost = CalendarText.percent(w.appraisal:water_per_point() / 10),
                full = CalendarText.percent(w.appraisal:water_per_point()), value = math.floor(w.supplies.water),
                low = BALANCE.supplies.low_warning }), C.link_boost } }
    end,
    furnace = function(w)
        local chances = w.forge:chances()
        return I18n.t("hover.furnace.title"), { { I18n.t("hover.furnace.body", { c2 = percent(chances[2]), c5 = percent(chances[5]),
            c8 = percent(chances[8]), c10 = percent(chances[10]) }) },
            { I18n.t("hover.furnace.risk"), C.danger }, { I18n.t("hover.furnace.durability"), C.link_boost } }
    end,
    journal = function(w)
        local status = w.master_trace:status()
        return I18n.t("trace.hover.journal_title"), { { I18n.t("trace.hover.journal_body") },
            { I18n.t("trace.button", { journals = status.journals, total = status.journal_total, lit = status.lit,
                slots = status.slots }), C.link_boost } }
    end,
}

local function static(id)
    return function()
        return I18n.t("hover." .. id .. ".title"), { { I18n.t("hover." .. id .. ".body") } }
    end
end

for _, id in ipairs({ "guild", "quests", "compendium", "upgrades", "storage" }) do
    CONTENT[id] = static(id)
end

-- 주인공 전용 툴팁: 스탯 · 장착 4부위(+N · 내구도) · 스킬 Q / E / R (ui/HeroText)
CONTENT.hero = function(w)
    return HeroText.tooltip(w)
end

-- 공명 진열장: 마력 도선으로 이어진 25칸 + 정중앙 직접 동조 슬롯
CONTENT.grid = function()
    return I18n.t("hover.grid.title"), { { I18n.t("hover.grid.body") }, { I18n.t("hover.grid.core"), C.gold } }
end

function HoverTooltip:new(workshop)
    self._workshop = workshop
    self._region, self._time, self._x, self._y = nil, 0, 0, 0
end

-- blocked: 모달·드래그 중이면 숨긴다
function HoverTooltip:update(dt, pointer, blocked)
    local found = nil
    if not blocked then
        local phase = self._workshop.phase == "night" and "night" or "day"
        local trace = self._workshop.master_trace ~= nil
        for _, region in ipairs(REGIONS) do
            local r = region.rect
            if (region.phase == nil or region.phase == phase) and (trace or not region.trace) and pointer.x >= r.x
                and pointer.x <= r.x + r.w and pointer.y >= r.y and pointer.y <= r.y + r.h then
                found = region
                break
            end
        end
    end
    self._time = found ~= nil and found == self._region and self._time + dt or 0
    self._region, self._x, self._y = found, pointer.x, pointer.y
end

-- 지금 보이는 툴팁 id (개발 도구용, 없으면 nil)
function HoverTooltip:visible_id()
    return self._region ~= nil and self._time >= DELAY and self._region.id or nil
end

-- 지금 보이는 툴팁의 제목, 줄 목록 { { 문구, 색 } } (개발 도구용, 없으면 nil)
function HoverTooltip:content()
    local id = self:visible_id()
    if id == nil then
        return nil
    end
    return CONTENT[id](self._workshop)
end

function HoverTooltip:draw()
    local title, lines = self:content()
    if title == nil then
        return
    end
    local inner, font = WIDTH - PAD * 2, Draw.font(UI.font_size.small)
    local h = PAD * 2 + 22
    for _, line in ipairs(lines) do
        h = h + #select(2, font:getWrap(line[1], inner)) * font:getHeight() + 4
    end
    local sw, sh = LAYOUT.screen.w, LAYOUT.screen.h
    local x = math.max(6, math.min(self._x + OFFSET, sw - WIDTH - 6))
    local y = self._y + OFFSET + h > sh - 6 and self._y - OFFSET - h or self._y + OFFSET
    y = math.max(6, y)
    Draw.set_color({ 0, 0, 0 }, 0.45)
    LG.rectangle("fill", x + 4, y + 5, WIDTH, h, 7, 7)
    Draw.set_color(INK)
    LG.rectangle("fill", x - 2, y - 2, WIDTH + 4, h + 4, 8, 8)
    Draw.set_color(PAPER)
    LG.rectangle("fill", x, y, WIDTH, h, 6, 6)
    Draw.set_color(BRASS, 0.7)
    LG.setLineWidth(1)
    LG.rectangle("line", x + 3.5, y + 3.5, WIDTH - 7, h - 7, 5, 5)
    Draw.label_text(title, x + PAD, y + PAD - 2, inner, "left", "button", C.gold)
    local ty = y + PAD + 22
    for _, line in ipairs(lines) do
        Draw.text(line[1], x + PAD, ty, inner, "left", UI.font_size.small, line[2] or BODY)
        ty = ty + #select(2, font:getWrap(line[1], inner)) * font:getHeight() + 4
    end
end

return HoverTooltip
