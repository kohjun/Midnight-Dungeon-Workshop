-- states/GameOverState.lua
-- 런 결과 정산 화면: 결과·통계·장인 명성(RP) 정산 내역, [영구 능력치 강화] 모달.
-- 승리면 헤드라인이 본 엔딩 이름 (장식 글자·안내 색은 data/endings.lua 의 style — 금 · 은 · 핏빛), 처음 본 엔딩이면 "새 엔딩" 안내,
-- 진엔딩 훈장을 처음 받았으면(result.medal_new — systems/Progress.record_ending) 해금 줄 아래에 훈장(ui/RuneArt)과 "진엔딩 훈장 획득".
-- SPACE/ENTER/ESC 또는 빈 곳 클릭 → TitleState(메뉴), R → 같은 시드·난이도로 RunState 재도전. 배경은 타이틀 배경을 어둡게 깐다.

local Audio = require("systems.Audio")
local Class = require("lib.classic")
local Tween = require("lib.tween")
local StateManager = require("core.StateManager")
local Input = require("core.Input")
local Viewport = require("core.Viewport")
local I18n = require("systems.I18n")
local MetaProgression = require("systems.MetaProgression")
local Button = require("ui.Button")
local MetaUpgradeView = require("ui.MetaUpgradeView")
local Draw = require("ui.Draw")
local Lettering = require("ui.Lettering")
local RuneArt = require("ui.RuneArt")
local TitleBackdrop = require("ui.TitleBackdrop")
local DIFFICULTIES = require("data.difficulties")
local ENDINGS = require("data.endings")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local GameOverState = Class:extend()

-- 결과별 헤드라인: 문구 키(gameover.<key>) · 장식 글자 스타일(ui/Lettering)
local HEADLINES = {
    victory = { key = "victory", lettering = "gold" },
    defeat = { key = "defeat", lettering = "blood" },
    bankrupt = { key = "bankrupt", lettering = "blood" },
    abandoned = { key = "abandoned", lettering = "silver" },
}
local DEFAULT_HEADLINE = { key = "closed", lettering = "silver" }
-- 엔딩 style(data/endings.lua) → 헤드라인 장식 글자 · "새 엔딩" 안내 색 (UI.color 이름)
local ENDING_STYLES = {
    gold = { lettering = "gold", color = "gold" },
    silver = { lettering = "silver", color = "stone" },
    blood = { lettering = "blood", color = "danger" },
}
local MEDAL_R = 13              -- 훈장 획득 줄 앞 훈장 원판 반지름
local HEADLINE_Y = 110
local DIFFICULTY_Y = 164
local STATS_Y = 214
local STATS_LINE_HEIGHT = 32
local RP_Y = 420
local UNLOCK_Y = 540
local HINT_Y = 668
local READ_PANEL = { x = 300, y = 86, w = 680, h = 410 }

-- result: RunState 가 넘긴 { reason, seed, day, gold, kills, gold_earned, items_lost, days_survived,
--                           tributes_paid, difficulty, name, unlocked, rp = MetaProgression.compute 내역 }
function GameOverState:enter(result)
    Audio.set_scene("menu")
    self._result = result or {}
    self._backdrop = TitleBackdrop()
    self._fade = { alpha = 0 }
    self._tweens = Tween.Group()
    self._tweens:to(self._fade, UI.anim.gameover_fade, { alpha = 1 }):ease("out_quad")
    self._modal = nil
    local x, y = Viewport.mouse_position()
    self._pointer = { x = x, y = y }
    self._meta_button = Button(LAYOUT.gameover.meta_button, function()
        return I18n.t("title.meta_button", { rp = MetaProgression.rp() })
    end, { style = "accent", on_click = function() self._modal = MetaUpgradeView.open() end })
    self._time = 0
    if self._result.medal_new then
        Audio.play("forge_success")         -- 진엔딩 훈장: 맑은 울림
    end
end

function GameOverState:exit()
    self._tweens:clear()
end

function GameOverState:update(dt)
    Audio.update(dt)          -- 배경음 크로스페이드
    self._time = self._time + dt
    self._tweens:update(dt)
    self._backdrop:update(dt)
    self._meta_button:update(dt, self._pointer.x, self._pointer.y)
    if self._modal ~= nil then
        self._modal:update(dt, self._pointer.x, self._pointer.y)
        if self._modal.closed then
            self._modal = nil
        end
    end
end

function GameOverState:_draw_rp(alpha)
    local C, SIZE = UI.color, UI.font_size
    local rp = self._result.rp
    if rp == nil then
        return
    end
    Lettering.draw(I18n.t("gameover.rp_total", { rp = rp.total }), 0, RP_Y - 4, Viewport.width(), "center", "title", "gold", alpha)
    local detail = I18n.t("gameover.rp_detail", {
        days = rp.days, tributes = rp.tributes, kills = rp.kills, clear = rp.clear, mult = string.format("%.1f", rp.mult),
    })
    Draw.centered_text(detail, RP_Y + 36, SIZE.small, C.text_dim, alpha)
end

-- 진엔딩 훈장 획득 줄: 왼쪽에 금빛 훈장, 가운데 정렬 (y = 글자 줄 위)
function GameOverState:_draw_medal(y, alpha)
    local SIZE, C = UI.font_size, UI.color
    local text = I18n.t("gameover.medal_new")
    local width = Draw.font(SIZE.large):getWidth(text)
    local left = (Viewport.width() - width - MEDAL_R * 2 - 12) / 2
    RuneArt.medal(left + MEDAL_R, y + 14, MEDAL_R, { alpha = alpha, time = self._time })
    Draw.text(text, left + MEDAL_R * 2 + 12, y, width + 2, "left", SIZE.large, C.gold, alpha)
end

function GameOverState:draw()
    local result, alpha = self._result, self._fade.alpha
    local C, SIZE = UI.color, UI.font_size
    self._backdrop:draw(nil, 0.72)
    love.graphics.setColor(0.02, 0.02, 0.04, 0.55 * alpha)          -- 통계 뒤 읽기 판
    love.graphics.rectangle("fill", READ_PANEL.x, READ_PANEL.y, READ_PANEL.w, READ_PANEL.h, 14, 14)

    local difficulty = result.difficulty or DIFFICULTIES.default
    local mode = DIFFICULTIES.modes[difficulty]
    local headline = HEADLINES[result.reason] or DEFAULT_HEADLINE
    local text, lettering = I18n.t("gameover." .. headline.key), headline.lettering
    if result.ending ~= nil then        -- 승리: 본 엔딩 이름 (처음 본 엔딩이면 표시)
        local look = ENDING_STYLES[ENDINGS.list[result.ending].style] or ENDING_STYLES.gold
        lettering = look.lettering
        text = I18n.t("gameover.ending_headline", { name = I18n.t("ending." .. result.ending .. ".name") })
        if result.ending_new then
            Draw.centered_text(I18n.t("gameover.ending_new"), HEADLINE_Y - 34, SIZE.small, C[look.color] or C.gold, alpha)
        end
    end
    Lettering.draw(text, 0, HEADLINE_Y - 8, Viewport.width(), "center", "headline", lettering, alpha)
    Draw.centered_text(I18n.t("gameover.owner_line", {
        tier = I18n.t("difficulty." .. difficulty .. ".tier"), mode = I18n.t("difficulty." .. difficulty .. ".name"),
        name = result.name or "-",
    }), DIFFICULTY_Y, SIZE.body, C[mode.tier_color] or C.text, alpha)

    local lines = {
        I18n.t("gameover.stat_days", { days = result.days_survived or 0, day = result.day or 0 }),
        I18n.t("gameover.stat_tributes", { count = result.tributes_paid or 0 }),
        I18n.t("gameover.stat_gold", { gold = result.gold or 0, earned = result.gold_earned or 0 }),
        I18n.t("gameover.stat_kills", { kills = result.kills or 0, lost = result.items_lost or 0 }),
        I18n.t("gameover.stat_seed", { seed = tostring(result.seed or "-") }),
    }
    for i, line in ipairs(lines) do
        Draw.centered_text(line, STATS_Y + (i - 1) * STATS_LINE_HEIGHT, SIZE.body, C.text, alpha)
    end
    self:_draw_rp(alpha)
    local unlocked = result.unlocked or {}
    for i, id in ipairs(unlocked) do
        Draw.centered_text(I18n.t("gameover.unlocked", {
            tier = I18n.t("difficulty." .. id .. ".tier"), mode = I18n.t("difficulty." .. id .. ".name"),
        }), UNLOCK_Y + (i - 1) * 30, SIZE.large, C.gold, alpha)
    end
    if result.medal_new then
        self:_draw_medal(UNLOCK_Y + #unlocked * 30, alpha)
    end
    self._meta_button:draw()
    Draw.centered_text(I18n.t("gameover.hint"), HINT_Y, SIZE.small, C.text_dim, alpha)
    if self._modal ~= nil then
        self._modal:draw()
    end
end

function GameOverState:mousemoved(x, y)
    self._pointer.x, self._pointer.y = x, y
end

function GameOverState:mousepressed(x, y, button)
    self._pointer.x, self._pointer.y = x, y
    if not Input.is_mouse_action(button, "confirm") then
        return
    end
    if self._modal ~= nil then
        self._modal:mousepressed(x, y)
    elseif self._meta_button:contains(x, y) then
        self._meta_button:press()
    else
        StateManager.switch("TitleState", { menu = true })
    end
end

function GameOverState:keypressed(key)
    if self._modal ~= nil then
        self._modal:keypressed(key)
    elseif Input.is_action(key, "retry") and self._result.seed ~= nil then
        StateManager.switch("RunState", { seed = self._result.seed, difficulty = self._result.difficulty, name = self._result.name })
    elseif Input.is_action(key, "confirm") or Input.is_action(key, "back") then
        StateManager.switch("TitleState", { menu = true })
    end
end

return GameOverState
