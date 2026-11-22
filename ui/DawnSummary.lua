-- ui/DawnSummary.lua
-- 새벽 방어 정산 결과창 (RunState 소유). 밤 웨이브를 다 소탕하면(Combat:time_to_dawn ~= nil) 셔터를 내리기 전에 띄운다:
--   "N일차 밤 방어 성공" · 처치 수 · 처치 보상 골드 · 과부하 보너스 골드 · 방벽 무피해 보너스(Workshop:dawn_bonus) · 획득 연마석 · 총합.
-- 열려 있는 동안 전투는 멈춘다(is_blocking). [다음 날 영업 시작] / 아무 곳 클릭 / Space·Enter → 무피해 보너스 지급 → 상단 HUD 의
-- 골드·연마석이 밤이 시작될 때 값에서 지금 값까지 빠르게 카운트업(반짝임 + coin_tally) → 남은 고요한 시간을 건너뛰고(skip_to_dawn)
-- dawn_candle 셔터 → 다음 날(또는 길드 상점). 화면이 없는 시뮬레이션은 DayCycle 이 보너스를 바로 지급한다.
-- 개발 도구용 set_auto_confirm(초): 열린 뒤 그 시간이 지나면 저절로 확인 (스모크 테스트가 무한 대기하지 않게).

local Class = require("lib.classic")
local EventBus = require("core.EventBus")
local I18n = require("systems.I18n")
local Audio = require("systems.Audio")
local Draw = require("ui.Draw")
local Frame = require("ui.Frame")
local Lettering = require("ui.Lettering")
local CalendarText = require("ui.CalendarText")
local SeasonBadge = require("ui.SeasonBadge")
local Button = require("ui.Button")
local TransitionManager = require("ui.TransitionManager")
local Input = require("core.Input")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local DawnSummary = Class:extend()

local C = UI.color
local P = LAYOUT.dawn_summary
local LG = love.graphics
local TALLY_TIME = 1.1
local ROW_H = 34
local SEASON_OFFSET = 24

local _auto = nil

function DawnSummary.set_auto_confirm(seconds)
    _auto = seconds
end

function DawnSummary.button_rect()
    return { x = P.x + (P.w - P.button_w) / 2, y = P.y + P.h - P.button_h - 20, w = P.button_w, h = P.button_h }
end

function DawnSummary:new(workshop, hud)
    self._workshop, self._hud = workshop, hud
    self.state = "idle"             -- idle → open → tally → done → (셔터) → idle
    self._time = 0
    self:_reset()
    self._button = Button(DawnSummary.button_rect(), function() return I18n.t("dawn.next_day") end, {
        style = "accent", emphasis = true, icon = "sun", key_hint = "Space", on_click = function() self:confirm() end,
    })
    EventBus.subscribe("phase:night_started", function()
        self:_reset()
        self.state = "idle"
    end, { owner = self })
    EventBus.subscribe("combat:monster_killed", function(p)
        local stats = self._stats
        stats.kills, stats.kill_gold = stats.kills + 1, stats.kill_gold + p.gold
        if p.combat ~= nil and p.combat.overclock then
            stats.overclock_gold = stats.overclock_gold + p.gold * (1 - 1 / workshop.overclock_rules.gold_mult)
        end
    end, { owner = self, priority = -150 })
    EventBus.subscribe("economy:stones_changed", function(p)
        if p.reason == "drop" and p.amount > 0 then
            self._stats.stones = self._stats.stones + p.amount
        end
    end, { owner = self, priority = -150 })
end

function DawnSummary:destroy()
    EventBus.unsubscribe_owner(self)
end

function DawnSummary:_reset()
    local w = self._workshop
    self._stats = { kills = 0, kill_gold = 0, overclock_gold = 0, stones = 0, gold0 = w.gold, stones0 = w.tempering_stones }
end

function DawnSummary:is_blocking()
    return self.state == "open" or self.state == "tally"
end

function DawnSummary:stats()
    return self._stats
end

function DawnSummary:_open()
    self.state, self._time = "open", 0
    self._bonus = self._workshop:dawn_bonus()
    self._hud:hold(self._stats.gold0, self._stats.stones0)       -- HUD 는 밤이 시작될 때 값에서 멈춰 있다가 카운트업
    EventBus.emit("dawn:summary_opened", { day = self._workshop.day, kills = self._stats.kills })
end

function DawnSummary:confirm()
    if self.state ~= "open" then
        return
    end
    self._workshop:claim_dawn_bonus()
    self.state, self._time = "tally", 0
    self._hud:count_to(TALLY_TIME)
    Audio.play("coin_tally")
    EventBus.emit("dawn:tallied", { day = self._workshop.day })
end

function DawnSummary:update(dt)
    local w = self._workshop
    if w.phase ~= "night" or w.result ~= nil then
        self.state = "idle"
        return
    end
    self._time = self._time + dt
    if self.state == "idle" and not TransitionManager.is_active() and w.combat:time_to_dawn() ~= nil then
        self:_open()
    elseif self.state == "open" then
        self._button:update(dt, self._pointer_x or 0, self._pointer_y or 0)
        if _auto ~= nil and self._time >= _auto then
            self:confirm()
        end
    elseif self.state == "tally" and self._time >= TALLY_TIME then
        self.state = "done"
        w.combat:skip_to_dawn()
        TransitionManager.start("dawn_candle", function() w.combat:release_dawn() end, {
            wait = function() return w.phase ~= "night" or w.result ~= nil end,
        })
    end
end

function DawnSummary:mousemoved(x, y)
    self._pointer_x, self._pointer_y = x, y
end

-- 열려 있으면 입력을 먹는다 (버튼 또는 아무 곳 클릭 = 확인)
function DawnSummary:mousepressed(x, y)
    if self.state ~= "open" then
        return self:is_blocking()
    end
    if not self._button:contains(x, y) or not self._button:press() then
        self:confirm()
    end
    return true
end

function DawnSummary:keypressed(key)
    if self.state == "open" and (Input.is_action(key, "confirm") or key == "space") then
        self._button:press()
    end
    return self:is_blocking()
end

local function row(label, value, y, color, size)
    Draw.label_text(label, P.x + 34, y, P.w - 68, "left", size or "button", C.text)
    Draw.label_text(value, P.x + 34, y, P.w - 68, "right", size or "button", color)
end

function DawnSummary:draw()
    if self.state ~= "open" and self.state ~= "tally" then
        return
    end
    local alpha = self.state == "tally" and math.max(0, 1 - self._time / TALLY_TIME) or 1
    LG.setColor(0, 0, 0, 0.55 * alpha)
    LG.rectangle("fill", 0, LAYOUT.top_bar.h, LAYOUT.screen.w, LAYOUT.screen.h - LAYOUT.top_bar.h)   -- HUD 는 밝게 둔다
    Frame.panel(P.x, P.y, P.w, P.h, { style = "dark", texture = "stone", texture_alpha = 0.2, alpha = alpha })
    local s, w = self._stats, self._workshop
    Lettering.draw(I18n.t("dawn.title", { date = CalendarText.date(w.day) }), P.x, P.y + 22, P.w, "center", "title", "gold", alpha)
    Draw.text(I18n.t("dawn.kills", { count = s.kills, progress = CalendarText.count(w) }), P.x, P.y + 62, P.w, "center", "label",
        C.text_dim, alpha)
    local y = P.y + 96
    local season, level = w:season(), w:interference()
    if season ~= nil then                -- 사계절 계약: 제목 아래 가운데 계절 배지, 정산 줄은 그만큼 내린다
        SeasonBadge.draw(season, P.x + (P.w - SeasonBadge.width(season)) / 2, P.y + 84, 20, alpha)
        y = y + SEASON_OFFSET
    elseif level ~= nil then             -- '스승의 흔적': 그 달의 포탈 간섭 배지
        SeasonBadge.draw_interference(level, P.x + (P.w - SeasonBadge.interference_width(level)) / 2, P.y + 84, 20, alpha, nil,
            self._time)
        y = y + SEASON_OFFSET
    end
    local base = math.floor(s.kill_gold - s.overclock_gold + 0.5)
    local overclock = math.floor(s.overclock_gold + 0.5)
    row(I18n.t("dawn.kill_gold"), string.format("+%d G", base), y, C.gold)
    row(I18n.t("dawn.overclock_gold"), string.format("+%d G", overclock), y + ROW_H, C.overclock)
    if self._bonus > 0 then
        row(I18n.t("dawn.flawless"), string.format("+%d G", self._bonus), y + ROW_H * 2, C.good)
    else
        row(I18n.t("dawn.flawless_none", { damage = math.ceil(w.night_damage or 0) }), "—", y + ROW_H * 2, C.text_dim)
    end
    row(I18n.t("dawn.stones"), string.format("+%d", s.stones), y + ROW_H * 3, C.stone)
    Draw.set_color(UI.color.accent, 0.5 * alpha)
    LG.setLineWidth(1)
    LG.line(P.x + 30, y + ROW_H * 4 - 6, P.x + P.w - 30, y + ROW_H * 4 - 6)
    row(I18n.t("dawn.total"), I18n.t("dawn.total_value", { gold = base + overclock + self._bonus, stones = s.stones }),
        y + ROW_H * 4, C.gold, "value_small")
    if self.state == "open" then
        self._button:draw()
        local blink = 0.45 + 0.35 * math.sin(self._time * 4)
        Draw.text(I18n.t("dawn.hint"), P.x, P.y + P.h + 8, P.w, "center", "label", C.text_dim, blink)
    end
end

return DawnSummary
