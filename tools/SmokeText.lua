-- tools/SmokeText.lua
-- 글자 선명도·가독성 검사 (100% 모니터에서도 전체화면·150% 경로를 배율 고정으로 검사한다):
--   1) 래스터 배율 양자화(1~3배, 0.25 단위) · 배율 1 이면 레이아웃 글꼴 그대로 · 배율이 바뀌면 렌더 캐시를 새로 만듦
--   2) 레이아웃 불변: 측정·줄바꿈은 배율과 무관하게 같은 글꼴(dpiscale 1), 렌더 글꼴만 dpiscale = 배율
--   3) 물리 픽셀 스냅: 소수 이동·확대 변환 아래에서도 글자 원점이 정수 픽셀
--   4) 선명도: 1.5배 화면에서 예전 방식(1배 글리프를 늘림)보다 새 방식의 번진 중간 톤 픽셀 비율이 낮다 (--shots 면 비교 이미지)
--   5) 명도 대비(WCAG 4.5:1 이상: 버튼 위 글자 · 어두운 패널 위 설명 글자) · 본문·라벨 최소 13px

local Draw = require("ui.Draw")
local FontCache = require("ui.FontCache")
local UI = require("data.ui")

local SmokeText = {}

local LG = love.graphics
local C = UI.color
local SAMPLE = "결계 유지비 D-4 · 남은 몬스터 5마리 — 매입한 유물을 끌어다 넣으세요. Overclock gold x2.5"
local MIN_SIZE = 13

local function check(condition, message)
    assert(condition, "SmokeText: " .. message)
end

local function luminance(color)
    local function channel(v)
        return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4
    end
    return 0.2126 * channel(color[1]) + 0.7152 * channel(color[2]) + 0.0722 * channel(color[3])
end

local function contrast(a, b)
    local la, lb = luminance(a), luminance(b)
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
end

local function check_scales()
    for _, case in ipairs({ { 0.8, 1 }, { 1, 1 }, { 1.37, 1.25 }, { 1.5, 1.5 }, { 2.2, 2.25 }, { 3.6, 3 } }) do
        FontCache.set_override(case[1])
        check(FontCache.render_scale() == case[2], string.format("scale %.2f should rasterize at %.2f", case[1], case[2]))
    end
    FontCache.set_override(1)
    check(FontCache.render("button") == Draw.font("button"), "at 1x the render font is the layout font itself")
    FontCache.set_override(1.5)
    local first = FontCache.render("button")
    check(first ~= Draw.font("button") and math.abs(first:getDPIScale() - 1.5) < 1e-6, "1.5x renders with a 1.5x glyph font")
    check(Draw.font("button"):getDPIScale() == 1, "layout fonts stay at dpiscale 1 (wrapping never depends on the scale)")
    FontCache.set_override(2)
    check(math.abs(FontCache.render("button"):getDPIScale() - 2) < 1e-6, "a scale change rebuilds the render font")
    FontCache.set_override(1.5)
    check(FontCache.render("button") ~= first, "the old-scale render cache was flushed")
end

local function check_snap()
    LG.push()
    LG.origin()
    LG.translate(0.37, 0.61)
    LG.scale(1.5)
    local x, y = Draw.snap(10.2, 20.7)
    local px, py = LG.transformPoint(x, y)
    LG.pop()
    local dpi = LG.getDPIScale()
    check(math.abs(px * dpi - math.floor(px * dpi + 0.5)) < 1e-4 and math.abs(py * dpi - math.floor(py * dpi + 0.5)) < 1e-4,
        "text origins snap to whole physical pixels under fractional transforms")
    check(select(1, Draw.snap(3.4, 0)) == 3, "identity transform snaps like math.floor(x + 0.5)")
end

-- 흰 글자를 검은 캔버스에 그린 뒤, 글자 픽셀 중 번진 중간 톤(밝기 0.2~0.8) 비율
local function blur_ratio(draw)
    local canvas = LG.newCanvas(1500, 120, { dpiscale = 1 })
    LG.push("all")
    LG.setCanvas(canvas)
    LG.clear(0, 0, 0, 1)
    LG.origin()
    LG.scale(1.5)
    LG.setColor(1, 1, 1, 1)
    draw()
    LG.pop()
    local data = canvas:newImageData()
    local mid, lit = 0, 0
    data:mapPixel(function(_, _, r, g, b, a)
        if r > 0.02 then
            lit = lit + 1
            if r > 0.2 and r < 0.8 then
                mid = mid + 1
            end
        end
        return r, g, b, a
    end)
    return mid / math.max(1, lit), canvas
end

local function check_sharpness(shots)
    local old_ratio, old_canvas = blur_ratio(function()        -- 예전: 1배 글리프를 1.5배로 늘려 그림
        LG.setFont(Draw.font("label"))
        LG.printf(SAMPLE, 10.3, 10.6, 980, "left")
    end)
    FontCache.set_override(1.5)
    local new_ratio, new_canvas = blur_ratio(function()        -- 지금: 1.5배로 래스터화 + 픽셀 스냅
        Draw.text(SAMPLE, 10.3, 10.6, 980, "left", "label", { 1, 1, 1 })
    end)
    check(new_ratio < old_ratio, string.format("1.5x text must be crisper (mid-tone %.3f vs old %.3f)", new_ratio, old_ratio))
    if shots then
        local out = LG.newCanvas(1500, 240, { dpiscale = 1 })
        LG.push("all")
        LG.setCanvas(out)
        LG.origin()
        LG.draw(old_canvas, 0, 0)
        LG.draw(new_canvas, 0, 120)
        LG.pop()
        out:newImageData():encode("png", "smoke_text_hidpi.png")
    end
    return old_ratio, new_ratio
end

local function check_readability()
    for _, fill in ipairs({ "button", "button_accent", "button_danger", "button_tool", "button_active" }) do
        check(contrast(C.text, C[fill]) >= 4.5, "button text contrast on " .. fill .. " should be at least 4.5:1")
    end
    check(contrast(C.text_dim, C.panel) >= 4.5 and contrast(C.text_dim, C.background) >= 4.5,
        "secondary text on dark panels should be at least 4.5:1")
    for name, style in pairs(UI.type) do
        if style.role == "ui" or style.role == "body" then
            check(style.size >= MIN_SIZE, "text type '" .. name .. "' should be at least " .. MIN_SIZE .. "px")
        end
    end
    check(UI.font_size.tiny >= MIN_SIZE, "font_size.tiny should be at least " .. MIN_SIZE .. "px")
    return contrast(C.text_dim, C.panel)
end

function SmokeText.run(log, shots)
    check_scales()
    check_snap()
    local old_ratio, new_ratio = check_sharpness(shots)
    FontCache.set_override(nil)
    local dim = check_readability()
    log("text ok (raster 1-3x quantized, layout fonts fixed at 1x, pixel snap, 1.5x mid-tone %.0f%% -> %.0f%%, dim text %.1f:1)",
        old_ratio * 100, new_ratio * 100, dim)
end

return SmokeText
