-- ui/FontCache.lua
-- 역할별 글꼴 로드·캐시 (ui/Draw 가 쓴다 — 게임 코드는 Draw.font / Draw.text 를 쓴다). 글꼴은 두 벌이다:
--   레이아웃 글꼴(layout) — dpiscale 1. 너비·높이·줄바꿈 측정은 항상 이것으로 한다 → 창 배율이 바뀌어도 배치·줄바꿈이 그대로.
--   렌더 글꼴(render)  — dpiscale = 실제 물리 픽셀 배율(Viewport.pixel_scale = 창 확대 배율 × 운영체제 DPI 배율)을
--                        data/ui.lua 의 text_raster(1~3배, 0.25 단위)로 양자화한 값. 글리프만 모니터 물리 해상도로 래스터화하므로
--                        전체화면·125/150% 디스플레이에서 1배 글리프를 늘려 그릴 때의 번짐이 없다. 배율 1 이면 레이아웃 글꼴 그대로.
--   배율이 바뀌면(창 크기·전체화면 전환·DPI 변경 — love.resize → StateManager → Viewport.configure) 다음 조회 때 렌더 캐시를
--   비우고 새 배율로 다시 만든다. 역할별 후보 파일·빌려 올 글꼴은 data/fonts.lua (없으면 맑은 고딕 → LÖVE 기본 글꼴).

local Viewport = require("core.Viewport")
local FONTS = require("data.fonts")
local UI = require("data.ui")

local FontCache = {}

local RASTER = UI.text_raster
local HINTING = "normal"

local _layout = {}          -- "role:size" -> Font (dpiscale 1)
local _render = {}          -- "role:size" -> Font (dpiscale = _render_scale)
local _render_scale = 1
local _override = nil       -- 개발 도구(스모크 테스트)용 배율 고정
local _role_data = {}       -- role -> FileData | false
local _file_data = {}       -- path -> FileData | false

local function read_file(path)
    local cached = _file_data[path]
    if cached ~= nil then
        return cached or nil
    end
    local data = nil
    if path:sub(1, 7) == "assets/" then
        if love.filesystem.getInfo(path) ~= nil then
            local ok, loaded = pcall(love.filesystem.newFileData, path)
            data = ok and loaded or nil
        end
    else    -- 게임 폴더 밖(시스템 글꼴)은 love.filesystem 대신 io 로 읽는다
        local file = io.open(path, "rb")
        if file ~= nil then
            local bytes = file:read("*a")
            file:close()
            local ok, loaded = pcall(love.filesystem.newFileData, bytes, path:match("[^/]+$"))
            data = ok and loaded or nil
        end
    end
    _file_data[path] = data or false
    return data
end

local function role_data(role)
    local cached = _role_data[role]
    if cached ~= nil then
        return cached or nil
    end
    local candidates = FONTS.roles[role]
    assert(candidates ~= nil, "FontCache: unknown font role '" .. tostring(role) .. "'")
    for _, path in ipairs(candidates) do
        local data = read_file(path)
        if data ~= nil and pcall(love.graphics.newFont, data, 12) then
            _role_data[role] = data
            print(string.format("[Draw] font role '%s': %s", role, path))
            return data
        end
    end
    print(string.format("[Draw] font role '%s': no font file found - using the default font", role))
    _role_data[role] = false
    return nil
end

-- spec → role, size. 숫자 = 본문(body) 크기 / 문자열 = data/ui.lua 의 type 이름 / { role, size }
function FontCache.resolve(spec)
    if type(spec) == "number" then
        return FONTS.default_role, spec
    elseif type(spec) == "string" then
        local style = UI.type[spec]
        assert(style ~= nil, "Draw: unknown text type '" .. spec .. "'")
        return style.role, style.size
    end
    return spec.role or FONTS.default_role, spec.size
end

local function new_font(data, size, dpiscale)
    local ok, font = pcall(love.graphics.newFont, data, size, HINTING, dpiscale)
    return ok and font or nil
end

-- 이 글꼴에 없는 글자를 빌려 올 글꼴들 (같은 크기·같은 배율): data/fonts.lua 의 fallbacks 역할 → last_resort
local function attach_fallbacks(font, role, size, own, dpiscale)
    local seen, list, sources = { [own] = true }, {}, {}
    for _, other in ipairs(FONTS.fallbacks[role] or {}) do
        sources[#sources + 1] = role_data(other)
    end
    sources[#sources + 1] = read_file(FONTS.last_resort)
    for _, data in ipairs(sources) do
        if data ~= nil and not seen[data] then
            seen[data] = true
            list[#list + 1] = new_font(data, size, dpiscale)
        end
    end
    if #list > 0 then
        pcall(font.setFallbacks, font, unpack(list))
    end
end

local function build(role, size, dpiscale)
    local data = role_data(role)
    local font = data and new_font(data, size, dpiscale)
    if font == nil then
        return love.graphics.newFont(size, HINTING, dpiscale)
    end
    attach_fallbacks(font, role, size, data, dpiscale)
    return font
end

-- 글리프를 래스터화할 배율: 물리 픽셀 배율을 0.25 단위로 양자화해 1~3배로 제한
function FontCache.render_scale()
    local raw = _override or Viewport.pixel_scale()
    local quantized = math.floor(raw / RASTER.step + 0.5) * RASTER.step
    return math.max(RASTER.min_scale, math.min(RASTER.max_scale, quantized))
end

-- 측정·줄바꿈용 (dpiscale 1, 배율과 무관하게 항상 같은 글꼴)
function FontCache.layout(spec)
    local role, size = FontCache.resolve(spec)
    local key = role .. ":" .. size
    local font = _layout[key]
    if font == nil then
        font = build(role, size, 1)
        _layout[key] = font
    end
    return font
end

-- 렌더 캐시 비우기 (배율이 바뀌면 render 가 알아서 부른다)
function FontCache.flush()
    _render = {}
end

-- 그리기용: 지금 물리 픽셀 배율로 래스터화한 글꼴 (배율 1 이면 레이아웃 글꼴)
function FontCache.render(spec)
    local scale = FontCache.render_scale()
    if scale ~= _render_scale then
        FontCache.flush()
        _render_scale = scale
    end
    if scale == 1 then
        return FontCache.layout(spec)
    end
    local role, size = FontCache.resolve(spec)
    local key = role .. ":" .. size
    local font = _render[key]
    if font == nil then
        font = build(role, size, scale)
        _render[key] = font
    end
    return font
end

-- 개발 도구용: 배율 고정(nil 이면 해제). 100% 모니터에서도 전체화면·150% 경로를 검사할 수 있다
function FontCache.set_override(scale)
    _override = scale
end

function FontCache.has_role_file(role)
    return role_data(role) ~= nil
end

return FontCache
