-- ui/Lettering.lua
-- 게임용 장식 글자: 그림자 + 외곽선 + 세로 그라데이션 채움(셰이더) + 은은한 빛번짐.
-- 제목 로고·화면 제목·패널 간판·큰 수치에 쓴다. 문구와 글꼴 지정(spec)은 Draw.text 와 같다.
--   Lettering.draw(text, x, y, width, align, spec, style, alpha)
--   style: "gold" | "silver" | "ember" | "blood" | "ink"   (data 가 아닌 순수 표현용 팔레트)

local Draw = require("ui.Draw")

local Lettering = {}

local LG = love.graphics
local GLOW_MIN_HEIGHT = 34
local GRADIENT_SHADER = [[
    extern vec3 top_color;
    extern vec3 bottom_color;
    extern vec2 span;       // 글자 줄의 화면 y 위·아래 (픽셀)
    extern number shine;    // 가운데 금속 반사 띠 세기
    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen)
    {
        number alpha = Texel(tex, uv).a * color.a;
        number t = clamp((screen.y - span.x) / max(span.y - span.x, 1.0), 0.0, 1.0);
        vec3 c = mix(top_color, bottom_color, t);
        c += shine * (smoothstep(0.38, 0.5, t) - smoothstep(0.5, 0.62, t));
        return vec4(c, alpha);
    }
]]

local STYLES = {
    gold = { top = { 1.0, 0.95, 0.70 }, bottom = { 0.80, 0.45, 0.12 }, shine = 0.18,
        outline = { 0.14, 0.06, 0.02 }, glow = { 1.0, 0.62, 0.22 } },
    silver = { top = { 0.97, 0.98, 1.0 }, bottom = { 0.55, 0.58, 0.68 }, shine = 0.12,
        outline = { 0.06, 0.06, 0.10 } },
    ember = { top = { 1.0, 0.82, 0.45 }, bottom = { 0.92, 0.28, 0.10 }, shine = 0.1,
        outline = { 0.18, 0.04, 0.02 }, glow = { 1.0, 0.35, 0.1 } },
    blood = { top = { 1.0, 0.55, 0.50 }, bottom = { 0.62, 0.08, 0.10 }, shine = 0.08,
        outline = { 0.12, 0.02, 0.03 }, glow = { 0.9, 0.1, 0.1 } },
    ink = { top = { 0.30, 0.18, 0.10 }, bottom = { 0.16, 0.09, 0.05 }, shine = 0 },
}

local _shader = nil
local _shader_failed = false

local function shader()
    if _shader == nil and not _shader_failed then
        local ok, result = pcall(LG.newShader, GRADIENT_SHADER)
        if ok then
            _shader = result
        else
            _shader_failed = true
            print("[Lettering] gradient shader unavailable - using flat colors: " .. tostring(result))
        end
    end
    return _shader
end

local _spec = nil      -- 지금 그리는 글자의 글꼴 지정 (Lettering.draw 가 설정)

-- 색·셰이더는 그대로 두고 찍기 (Draw.print_text: 고해상도 글리프 + 물리 픽셀 스냅)
local function print_at(text, x, y, width, align, dx, dy)
    Draw.print_text(text, x + dx, y + dy, width, align, _spec)
end

-- 줄 수까지 고려한 글자 블록 높이
function Lettering.height(text, width, spec)
    local font = Draw.font(spec)
    local _, lines = font:getWrap(text, width)
    return math.max(1, #lines) * font:getHeight()
end

-- 한 줄 그리기 (그라데이션은 줄마다 위→아래)
local function draw_line(line, x, y, width, align, font, style, alpha, stroke)
    LG.setColor(0, 0, 0, 0.55 * alpha)                      -- 그림자
    print_at(line, x, y, width, align, stroke + 1, stroke + 2)
    if style.glow ~= nil and font:getHeight() >= GLOW_MIN_HEIGHT then   -- 큰 글자만 빛번짐 (작은 글자는 번져 보인다)
        LG.setBlendMode("add")
        LG.setColor(style.glow[1], style.glow[2], style.glow[3], 0.045 * alpha)
        for i = 0, 7 do
            local angle = i / 8 * math.pi * 2
            print_at(line, x, y, width, align, math.cos(angle) * stroke * 2.4, math.sin(angle) * stroke * 2.4)
        end
        LG.setBlendMode("alpha")
    end
    if style.outline ~= nil then                             -- 외곽선
        local o = style.outline
        LG.setColor(o[1], o[2], o[3], 0.95 * alpha)
        for dx = -stroke, stroke do
            for dy = -stroke, stroke do
                if dx ~= 0 or dy ~= 0 then
                    print_at(line, x, y, width, align, dx, dy)
                end
            end
        end
    end
    local effect = shader()
    if effect == nil then
        LG.setColor(style.top[1], style.top[2], style.top[3], alpha)
        print_at(line, x, y, width, align, 0, 0)
        return
    end
    local _, top = LG.transformPoint(x, y)
    local _, bottom = LG.transformPoint(x, y + font:getHeight())
    effect:send("top_color", style.top)
    effect:send("bottom_color", style.bottom)
    effect:send("span", { top + (bottom - top) * 0.18, bottom - (bottom - top) * 0.12 })
    effect:send("shine", style.shine)
    LG.setShader(effect)
    LG.setColor(1, 1, 1, alpha)
    print_at(line, x, y, width, align, 0, 0)
    LG.setShader()
end

function Lettering.draw(text, x, y, width, align, spec, style_name, alpha)
    local style = STYLES[style_name or "gold"]
    assert(style ~= nil, "Lettering: unknown style '" .. tostring(style_name) .. "'")
    alpha = alpha or 1
    local font = Draw.font(spec)
    _spec = spec
    local stroke = math.max(1, math.floor(font:getHeight() / 22 + 0.5))
    local _, lines = font:getWrap(text, width)
    for i, line in ipairs(lines) do
        draw_line(line, x, y + (i - 1) * font:getHeight(), width, align, font, style, alpha, stroke)
    end
end

return Lettering
