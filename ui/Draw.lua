-- ui/Draw.lua
-- 공용 그리기 헬퍼: 글꼴 조회, 색상, 정렬 텍스트(물리 픽셀 스냅 · 고해상도 글리프), 패널, 시간 표기.
-- 글꼴 지정(spec): 숫자 = 본문(body) 글꼴의 크기 / 문자열 = data/ui.lua 의 type 이름("button", "title" …)
--                  / 테이블 { role, size }. 로드·캐시·렌더 배율은 ui/FontCache, 역할별 후보 파일은 data/fonts.lua.
-- 글자는 반드시 Draw.text / shadow_text / label_text / print_text 로 찍는다 (love.graphics.print 직접 호출 금지 —
-- 그래야 전체화면·HiDPI 에서 고해상도 글리프와 픽셀 스냅이 적용된다).

local Viewport = require("core.Viewport")
local FontCache = require("ui.FontCache")
local UI = require("data.ui")

local utf8 = require("utf8")

local Draw = {}

local LG = love.graphics
local SHADOW = UI.text_shadow

-- spec → role, size
Draw.resolve = FontCache.resolve

-- 역할·크기별 글꼴 (측정·줄바꿈용 레이아웃 글꼴 — 화면 배율과 무관). 매 프레임 newFont 금지
function Draw.font(spec)
    return FontCache.layout(spec)
end

-- 역할의 글꼴(빌려 오는 글꼴 포함)이 text 의 모든 글자를 그릴 수 있는지. 없는 글자 목록도 돌려준다
function Draw.missing_glyphs(text, spec)
    local font = Draw.font(spec)
    local missing = {}
    for _, code in utf8.codes(text) do
        if code > 32 and not font:hasGlyphs(code) then
            missing[#missing + 1] = utf8.char(code)
        end
    end
    return missing
end

function Draw.has_korean_font()
    return FontCache.has_role_file(require("data.fonts").default_role)
end

-- 논리 좌표 (x, y)를 지금 변환 기준 가장 가까운 물리 픽셀 경계로 맞춘 논리 좌표 (한글 가로·세로 획이 서브픽셀에 걸려 번지지 않게).
-- 변환이 항등이면 math.floor(x + 0.5) 와 같고, 전체화면·DPI 배율·버튼 눌림 이동 중에도 실제 픽셀에 맞는다
function Draw.snap(x, y)
    local dpi = LG.getDPIScale()
    local px, py = LG.transformPoint(x, y)
    return LG.inverseTransformPoint(math.floor(px * dpi + 0.5) / dpi, math.floor(py * dpi + 0.5) / dpi)
end

-- 색은 그대로 두고 글자만 찍는다 (Lettering 등 색·셰이더를 직접 다루는 곳용).
-- 줄바꿈·정렬은 레이아웃 글꼴로 정하고(배율과 무관하게 같은 줄), 글리프는 물리 해상도로 래스터화한 렌더 글꼴로 그린다.
function Draw.print_text(text, x, y, width, align, spec)
    local layout, render = FontCache.layout(spec), FontCache.render(spec)
    LG.setFont(render)
    if render == layout or align == "justify" then
        local sx, sy = Draw.snap(x, y)
        LG.printf(text, sx, sy, width, align)
        return
    end
    local _, lines = layout:getWrap(text, width)
    local line_h = layout:getHeight() * layout:getLineHeight()
    for i, line in ipairs(lines) do
        local lx = x
        if align == "center" then
            lx = x + (width - render:getWidth(line)) / 2
        elseif align == "right" then
            lx = x + width - render:getWidth(line)
        end
        LG.print(line, Draw.snap(lx, y + (i - 1) * line_h))
    end
end

-- color: { r, g, b [, a] }, alpha: 추가 곱 (기본 1)
function Draw.set_color(color, alpha)
    love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * (alpha or 1))
end

function Draw.clear(color)
    love.graphics.clear(color[1], color[2], color[3], 1)
end

-- x ~ x + width 영역 안에서 align("left" | "center" | "right") 정렬. size = 글꼴 지정(spec)
function Draw.text(text, x, y, width, align, size, color, alpha)
    Draw.set_color(color, alpha)
    Draw.print_text(text, x, y, width, align, size)
end

-- sizes 중 text 가 width 안에 한 줄로 들어가는 첫 크기 (없으면 마지막 크기)와 그 크기에서의 줄 수.
-- 언어에 따라 길이가 크게 달라지는 한 줄 문구에 쓴다
function Draw.fit_size(text, width, sizes)
    for _, size in ipairs(sizes) do
        if Draw.font(size):getWidth(text) <= width then
            return size, 1
        end
    end
    local size = sizes[#sizes]
    local _, wrapped = Draw.font(size):getWrap(text, width)
    return size, #wrapped
end

-- 그림자가 있는 텍스트 (밝은 배경·이펙트 위 가독성)
function Draw.shadow_text(text, x, y, width, align, size, color, alpha)
    LG.setColor(0, 0, 0, 0.75 * (alpha or 1))
    Draw.print_text(text, x + 2, y + 2, width, align, size)
    Draw.set_color(color, alpha)
    Draw.print_text(text, x, y, width, align, size)
end

-- 버튼·색 배경 위 라벨: 아래로 1px 은은한 검은 그림자 (data/ui.lua 의 text_shadow) — 갈색·붉은색·황동색 위에서도 또렷하게
function Draw.label_text(text, x, y, width, align, size, color, alpha)
    LG.setColor(0, 0, 0, SHADOW.alpha * (alpha or 1))
    Draw.print_text(text, x, y + SHADOW.offset, width, align, size)
    Draw.set_color(color, alpha)
    Draw.print_text(text, x, y, width, align, size)
end

-- 화면 가로 중앙 정렬
function Draw.centered_text(text, y, size, color, alpha)
    Draw.text(text, 0, y, Viewport.width(), "center", size, color, alpha)
end

-- 사각 영역 정중앙 (세로 중앙 포함)
function Draw.text_in_rect(text, rect, size, color, alpha)
    local font = Draw.font(size)
    Draw.text(text, rect.x, rect.y + (rect.h - font:getHeight()) / 2, rect.w, "center", size, color, alpha)
end

-- 둥근 패널: 채우기 + 테두리
function Draw.panel(x, y, w, h, fill, border, radius, alpha)
    radius = radius or 8
    Draw.set_color(fill, alpha)
    love.graphics.rectangle("fill", x, y, w, h, radius, radius)
    if border ~= nil then
        Draw.set_color(border, alpha)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", x, y, w, h, radius, radius)
    end
end

-- 진행 막대 (ratio 0~1)
function Draw.bar(x, y, w, h, ratio, fill, back)
    Draw.set_color(back or { 0, 0, 0, 0.45 })
    love.graphics.rectangle("fill", x, y, w, h, h / 2, h / 2)
    ratio = math.max(0, math.min(1, ratio))
    if ratio > 0 then
        Draw.set_color(fill)
        love.graphics.rectangle("fill", x, y, w * ratio, h, h / 2, h / 2)
    end
end

function Draw.lerp_color(a, b, t)
    return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

-- 부드러운 원형 빛 (가산 혼합, 바깥으로 갈수록 옅어지는 동심원)
function Draw.glow(x, y, radius, color, alpha, rings)
    rings = rings or 10
    love.graphics.setBlendMode("add")
    for i = rings, 1, -1 do
        local k = i / rings
        Draw.set_color(color, alpha * (1 - k) * 2 / rings)
        love.graphics.circle("fill", x, y, radius * k, 48)
    end
    love.graphics.setBlendMode("alpha")
end

-- 초 → "m:ss" (올림)
function Draw.format_time(seconds)
    local total = math.max(0, math.ceil(seconds))
    return string.format("%d:%02d", math.floor(total / 60), total % 60)
end

return Draw
