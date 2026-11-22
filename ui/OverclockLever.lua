-- ui/OverclockLever.lua
-- 밤 화면의 과부하 레버 패널 (ui/NightLayoutView 가 부른다, 클릭은 WorkshopInput 의 "overclock" 버튼 자리).
-- 그래픽노블 잉크·황동 스타일을 코드로 그려 ON/OFF 가 한눈에 갈린다 (원화가 필요 없다):
--   OFF(안전): 강철·청회색 호(弧) 트랙, 손잡이 공이 트랙 위쪽 끝, 강철색 [OFF] 배지, 경고등 꺼짐, 열기 게이지 비어 있음
--   ON(과부하): 손잡이가 아래쪽 끝으로 확 꺾이고(트랙 아래 절반이 붉게), 붉은 경고등 점멸·발광, 붉은 [ON] 배지,
--               뜨겁게 맥동하는 열기 게이지, 미세 진동 + 증기·불티
--   오른쪽: 이름 · 상태 · 지금 연사 배율(x1.0 / x2.5) · 과열 위험(0% / 8%/초)을 큰 장식 글자로, 그 아래 골드 배율 · 증폭기 안내

local I18n = require("systems.I18n")
local Draw = require("ui.Draw")
local Frame = require("ui.Frame")
local Lettering = require("ui.Lettering")
local CalendarText = require("ui.CalendarText")
local UI = require("data.ui")

local OverclockLever = {}

local C = UI.color
local SIZE = UI.font_size
local LG = love.graphics
local INK = { 0.03, 0.02, 0.03 }
local BRASS = { 0.84, 0.64, 0.30 }
local STEEL = { 0.46, 0.53, 0.62 }
local STEEL_DARK = { 0.16, 0.19, 0.24 }
local RED = { 1.0, 0.24, 0.16 }
local HOT = { 1.0, 0.58, 0.18 }
local STEAM = { 0.86, 0.83, 0.80 }
local ARC_R = 46                -- 손잡이가 도는 반지름
local ARC_OFF, ARC_ON = -1.0, 1.0   -- 해제(위) · 가동(아래) 각도 (라디안)
local KNOB_R = 12

local _pos = 0          -- 손잡이 위치 0(해제) ~ 1(가동), 화면 연출 전용 상태

local function inked(mode, fn, width)
    Draw.set_color(INK)
    LG.setLineWidth(width or 3)
    fn("line")
    if mode then
        mode()
    end
end

local function steam(x, y, w, time)
    for i = 1, 6 do
        local phase = (time * 0.9 + i / 6) % 1
        local sx = x + w * (0.15 + 0.7 * ((i * 0.37) % 1)) + math.sin(time * 2 + i) * 5
        Draw.set_color(STEAM, (1 - phase) * 0.24)
        LG.circle("fill", sx, y - phase * 40, 4 + phase * 9, 14)
        if i % 2 == 0 then
            Draw.set_color(HOT, (1 - phase) * 0.85)
            LG.circle("fill", sx + 6, y + 6 - phase * 40, 1.7, 6)
        end
    end
end

local function badge(text, x, y, color, active)
    local font = Draw.font("button")
    local w, h = font:getWidth(text) + 14, font:getHeight() + 2
    Draw.set_color(INK, active and 1 or 0.6)
    LG.rectangle("fill", x - w / 2 - 2, y - h / 2 - 2, w + 4, h + 4, 7, 7)
    Draw.set_color(active and color or STEEL_DARK)
    LG.rectangle("fill", x - w / 2, y - h / 2, w, h, 6, 6)
    Draw.label_text(text, x - w / 2, y - font:getHeight() / 2, w, "center", "button", active and { 1, 1, 1 } or C.text_disabled)
end

-- 레버 본체 (버튼 중심 좌표계)
local function draw_lever(rect, on, enabled, time)
    local w, h = rect.w, rect.h
    Draw.set_color(INK)                                                   -- 판: 먹 외곽선 + 어두운 철판 + 황동 실선 · 리벳
    LG.rectangle("fill", -w / 2 - 3, -h / 2 - 3, w + 6, h + 6, 11, 11)
    Draw.set_color(on and { 0.18, 0.09, 0.08 } or { 0.12, 0.13, 0.16 })
    LG.rectangle("fill", -w / 2, -h / 2, w, h, 9, 9)
    Draw.set_color(BRASS, 0.6)
    LG.setLineWidth(1)
    LG.rectangle("line", -w / 2 + 3.5, -h / 2 + 3.5, w - 7, h - 7, 7, 7)
    for _, p in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
        Draw.set_color(BRASS)
        LG.circle("fill", p[1] * (w / 2 - 8), p[2] * (h / 2 - 8), 2.6, 10)
    end
    local blink = on and math.sin(time * 14) > -0.2
    local lamp_x, lamp_y = -w / 2 + 18, -h / 2 + 18                     -- 경고등
    if blink then
        LG.setBlendMode("add")
        Draw.set_color(RED, 0.35)
        LG.circle("fill", lamp_x, lamp_y, 20, 24)
        LG.setBlendMode("alpha")
    end
    inked(function()
        Draw.set_color(blink and RED or STEEL_DARK)
        LG.circle("fill", lamp_x, lamp_y, 8, 20)
        Draw.set_color({ 1, 1, 1 }, blink and 0.7 or 0.25)
        LG.circle("fill", lamp_x - 2.5, lamp_y - 2.5, 2.4, 10)
    end, function(mode) LG.circle(mode, lamp_x, lamp_y, 9, 20) end)
    local hub_x, hub_y = -w / 2 + 26, 10                                  -- 호 트랙: 위 = OFF, 아래 = ON
    Draw.set_color(INK)
    LG.setLineWidth(18)
    LG.arc("line", "open", hub_x, hub_y, ARC_R, ARC_OFF - 0.12, ARC_ON + 0.12, 32)
    Draw.set_color(STEEL)
    LG.setLineWidth(12)
    LG.arc("line", "open", hub_x, hub_y, ARC_R, ARC_OFF - 0.08, 0, 24)
    Draw.set_color(on and RED or STEEL_DARK)
    LG.arc("line", "open", hub_x, hub_y, ARC_R, 0, ARC_ON + 0.08, 24)
    local gauge_x, gauge_y, gauge_h = w / 2 - 18, -h / 2 + 14, h - 28    -- 열기 게이지
    inked(function()
        Draw.set_color(STEEL_DARK)
        LG.rectangle("fill", gauge_x, gauge_y, 9, gauge_h, 4, 4)
        local fill = _pos * (on and (0.82 + 0.18 * math.sin(time * 9)) or 1) * gauge_h
        Draw.set_color(Draw.lerp_color(HOT, RED, 0.5 + 0.5 * math.sin(time * 6)))
        LG.rectangle("fill", gauge_x, gauge_y + gauge_h - fill, 9, fill, 4, 4)
    end, function(mode) LG.rectangle(mode, gauge_x - 1, gauge_y - 1, 11, gauge_h + 2, 5, 5) end)
    local angle = ARC_OFF + (ARC_ON - ARC_OFF) * _pos                     -- 손잡이: 축 → 공
    local kx, ky = hub_x + math.cos(angle) * ARC_R, hub_y + math.sin(angle) * ARC_R
    Draw.set_color(INK)
    LG.setLineWidth(9)
    LG.line(hub_x, hub_y, kx, ky)
    Draw.set_color(BRASS)
    LG.setLineWidth(4.5)
    LG.line(hub_x, hub_y, kx, ky)
    inked(function()
        Draw.set_color(BRASS)
        LG.circle("fill", hub_x, hub_y, 8, 16)
    end, function(mode) LG.circle(mode, hub_x, hub_y, 9, 16) end)
    if on then
        LG.setBlendMode("add")
        Draw.set_color(RED, 0.4)
        LG.circle("fill", kx, ky, KNOB_R * 2, 24)
        LG.setBlendMode("alpha")
    end
    inked(function()
        Draw.set_color(on and RED or (enabled and STEEL or STEEL_DARK))
        LG.circle("fill", kx, ky, KNOB_R, 24)
        Draw.set_color({ 1, 1, 1 }, 0.45)
        LG.circle("fill", kx - 4, ky - 4, 3.5, 12)
    end, function(mode) LG.circle(mode, kx, ky, KNOB_R + 1, 24) end)
    badge(I18n.t("grid.lever_off"), w / 2 - 44, -h / 2 + 18, STEEL, not on)     -- 배지: 위 OFF / 아래 ON
    badge(I18n.t("grid.lever_on"), w / 2 - 44, h / 2 - 18, RED, on)
end

local function draw_readout(workshop, button, panel, time)
    local rules = workshop.overclock_rules
    local on, night = workshop.combat.overclock, workshop.phase == "night"
    local x = button.rect.x + button.rect.w + 14
    local w = panel.x + panel.w - x - 12
    Draw.label_text(I18n.t("grid.lever"), x, panel.y + 10, w, "left", "item_name", on and C.overclock or C.text)
    if on then
        Draw.label_text(I18n.t("grid.lever_running"), x, panel.y + 10, w, "right", "button", C.overclock,
            math.sin(time * 12) > -0.2 and 1 or 0.45)
    else
        Draw.label_text(I18n.t(night and "grid.lever_pull" or "grid.lever_night_only"), x, panel.y + 12, w, "right", "label",
            night and C.accent or C.text_dim)
    end
    local half = math.floor(w / 2)
    Draw.label_text(I18n.t("grid.lever_rate_label"), x, panel.y + 40, half, "left", "label", C.text_dim)
    Draw.label_text(I18n.t("grid.lever_heat_label"), x + half, panel.y + 40, half, "left", "label", C.text_dim)
    Lettering.draw(I18n.t("grid.lever_rate_value", { rate = string.format("%.1f", on and rules.rate_mult or 1) }), x, panel.y + 56,
        half, "left", "value", on and "ember" or "silver")
    local wear = workshop:overclock_wear_mult()       -- 과부하 중 내구도 마모 배율 (난이도 + 여름, 견습 = x1)
    local wear_text = string.format("%.1f", wear)
    Lettering.draw(I18n.t("grid.lever_heat_value", { mult = on and wear_text or "1.0" }),
        x + half, panel.y + 56, half, "left", "value", on and wear > 1 and "blood" or "silver")
    local next_line = on and I18n.t("grid.lever_gold", { gold = rules.gold_mult })
        or I18n.t("grid.lever_preview", { rate = rules.rate_mult, gold = rules.gold_mult, wear = wear_text })
    Draw.label_text(next_line, x, panel.y + 92, w, "left", SIZE.small, C.accent)
    Draw.label_text(I18n.t("grid.amp_hint"), x, panel.y + 122, w, "left", SIZE.tiny, C.text_dim)
end

function OverclockLever.draw(workshop, input, time, panel)
    local button = input:button("overclock")
    local on = workshop.combat.overclock
    _pos = _pos + ((on and 1 or 0) - _pos) * math.min(1, love.timer.getDelta() * UI.anim.lever_speed * 1.6)
    Frame.panel(panel.x, panel.y, panel.w, panel.h, { style = "ember" })
    local rect = button.rect
    LG.push()
    LG.translate(rect.x + rect.w / 2 + (on and math.sin(time * 55) * 0.8 or 0), rect.y + rect.h / 2 + (on and math.cos(time * 47) * 0.6 or 0))
    LG.scale(button:scale())
    if on then
        steam(-rect.w / 2, -rect.h / 2, rect.w, time)
    end
    draw_lever(rect, on, button:is_enabled(), time)
    LG.pop()
    if workshop.phase == "night" and button:key_hint() ~= nil then
        Draw.label_text("[" .. button:key_hint() .. "]", rect.x, rect.y - 16, rect.w, "center", "label", C.accent)
    end
    draw_readout(workshop, button, panel, time)
end

return OverclockLever
