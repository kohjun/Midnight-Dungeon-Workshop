-- ui/BenchTools.lua
-- 작업대 위 도구 연출: UV 렌즈(버튼 홀드 중 스텐실 투시 / 홀드 전 꺼진 테두리), 세척 브러시 커서. 규칙 계산 없음.

local I18n = require("systems.I18n")
local Draw = require("ui.Draw")
local Slots = require("ui.Slots")
local ItemRenderer = require("ui.ItemRenderer")
local LAYOUT = require("data.layout")
local UI = require("data.ui")

local BenchTools = {}

local C = UI.color
local LG = love.graphics

-- UV 모드지만 버튼을 누르지 않은 상태: 꺼진 렌즈 테두리와 "누른 채 스캔" 안내만 보인다 (투시·배터리 소모 없음)
local function draw_idle_lens(workshop, input, time)
    local px, py = input.pointer.x, input.pointer.y
    local radius = workshop.appraisal:lens_radius()
    Draw.set_color(C.uv, 0.3 + 0.12 * math.sin(time * 3))
    LG.setLineWidth(1.5)
    LG.circle("line", px, py, radius, 48)
    Draw.set_color(C.uv, 0.5)
    LG.circle("fill", px, py, 3, 10)
    Draw.shadow_text(I18n.t("bench.lens_hold"), px - 70, py + radius + 4, 140, "center", "label", C.uv, 0.9)
end

-- 켜진 렌즈: 원형 스텐실 안에서만 유물의 진짜 등급·결함이 비친다
local function draw_uv_lens(workshop, item, input, time)
    local px, py = input.pointer.x, input.pointer.y
    local radius = workshop.appraisal:lens_radius()
    local slot = LAYOUT.day.bench_slot
    local cx, cy = Slots.center("bench", 1)

    LG.stencil(function()
        LG.circle("fill", px, py, radius, 48)
    end, "replace", 1)
    LG.setStencilTest("greater", 0)
    Draw.set_color(C.uv_tint, 0.93)
    LG.rectangle("fill", slot.x - radius, slot.y - radius, slot.w + radius * 2, slot.h + radius * 2)
    if item ~= nil then
        ItemRenderer.draw_xray(item, cx, cy, slot.item_size, time)
    end
    LG.setStencilTest()

    local pulse = 0.6 + 0.4 * math.sin(time * 5)
    LG.setBlendMode("add")
    Draw.set_color(C.uv, 0.25 * pulse)
    LG.setLineWidth(9)
    LG.circle("line", px, py, radius + 2, 48)
    LG.setBlendMode("alpha")
    Draw.set_color(C.uv, pulse)
    LG.setLineWidth(3)
    LG.circle("line", px, py, radius, 48)
    Draw.set_color(C.uv, 0.5)
    LG.setLineWidth(1)
    LG.line(px - radius, py, px - radius + 10, py)
    LG.line(px + radius - 10, py, px + radius, py)
    LG.line(px, py - radius, px, py - radius + 10)
    LG.line(px, py + radius - 10, px, py + radius)
end

function BenchTools.draw_lens(workshop, item, input, time)
    if input.tool ~= "uv" or not workshop:is_day() then
        return
    end
    if workshop.appraisal.lens_on then
        draw_uv_lens(workshop, item, input, time)
    elseif Slots.at(input.pointer.x, input.pointer.y) == "bench" then
        draw_idle_lens(workshop, input, time)
    end
end

function BenchTools.draw_brush(input, time)
    local px, py = input.pointer.x, input.pointer.y
    local wiggle = input.pointer.down and math.sin(time * 40) * 0.25 or 0
    LG.push()
    LG.translate(px, py)
    LG.rotate(-0.6 + wiggle)
    Draw.set_color({ 0, 0, 0 }, 0.35)
    LG.rectangle("fill", -2, -38, 8, 50, 3, 3)
    Draw.set_color({ 0.55, 0.35, 0.2 })
    LG.rectangle("fill", -4, -42, 8, 30, 3, 3)
    Draw.set_color({ 0.75, 0.75, 0.8 })
    LG.rectangle("fill", -7, -14, 14, 6)
    Draw.set_color({ 0.95, 0.88, 0.6 })
    LG.rectangle("fill", -8, -8, 16, 12, 2, 2)
    LG.pop()
end

return BenchTools
