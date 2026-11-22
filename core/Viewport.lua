-- core/Viewport.lua
-- 논리 해상도(1280x720) ↔ 실제 창 크기 변환. 창모드에서는 항등 변환이고, 전체화면에서는 비율을 유지해
-- 확대한 뒤 남는 곳을 검은 띠로 채운다. 게임 코드는 항상 논리 좌표만 쓴다.
--   StateManager.draw     : Viewport.push() ... Viewport.pop()
--   StateManager.dispatch : 마우스 콜백 좌표를 Viewport.to_logical 로 변환
--   화면 크기가 필요하면 love.graphics.getWidth() 대신 Viewport.width() / height()
--   시저는 변환의 영향을 받지 않으므로 love.graphics.setScissor 대신 Viewport.set_scissor

local LAYOUT = require("data.layout")

local Viewport = {}

local WIDTH, HEIGHT = LAYOUT.screen.w, LAYOUT.screen.h

local _scale, _offset_x, _offset_y = 1, 0, 0
local _window_w, _window_h = WIDTH, HEIGHT

-- 실제 창 크기에 맞춰 배율·여백 재계산 (인자 생략 시 현재 창 크기)
function Viewport.configure(window_w, window_h)
    if window_w == nil then
        window_w, window_h = love.graphics.getDimensions()
    end
    _window_w, _window_h = window_w, window_h
    _scale = math.min(window_w / WIDTH, window_h / HEIGHT)
    _offset_x = math.floor((window_w - WIDTH * _scale) / 2)
    _offset_y = math.floor((window_h - HEIGHT * _scale) / 2)
end

function Viewport.width()
    return WIDTH
end

function Viewport.height()
    return HEIGHT
end

function Viewport.scale()
    return _scale
end

-- 논리 1픽셀이 실제 모니터 물리 픽셀 몇 개인지: 창 확대 배율 × 운영체제 DPI 배율 (ui/FontCache 가 글리프 래스터 배율로 쓴다)
function Viewport.pixel_scale()
    return _scale * love.graphics.getDPIScale()
end

-- 창 좌표 → 논리 좌표
function Viewport.to_logical(x, y)
    return (x - _offset_x) / _scale, (y - _offset_y) / _scale
end

-- 논리 좌표 → 창 좌표
function Viewport.to_window(x, y)
    return _offset_x + x * _scale, _offset_y + y * _scale
end

-- 현재 마우스 위치 (논리 좌표). 상태 진입 시 포인터 초기값으로만 쓴다
function Viewport.mouse_position()
    return Viewport.to_logical(love.mouse.getPosition())
end

function Viewport.push()
    Viewport.configure()
    love.graphics.push()
    love.graphics.translate(_offset_x, _offset_y)
    love.graphics.scale(_scale)
end

function Viewport.pop()
    love.graphics.pop()
    if _offset_x > 0 or _offset_y > 0 then
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", 0, 0, _offset_x, _window_h)
        love.graphics.rectangle("fill", _window_w - _offset_x, 0, _offset_x, _window_h)
        love.graphics.rectangle("fill", 0, 0, _window_w, _offset_y)
        love.graphics.rectangle("fill", 0, _window_h - _offset_y, _window_w, _offset_y)
    end
end

-- 논리 좌표 사각형으로 시저 설정 (인자 없이 부르면 해제)
function Viewport.set_scissor(x, y, w, h)
    if x == nil then
        love.graphics.setScissor()
        return
    end
    local wx, wy = Viewport.to_window(x, y)
    love.graphics.setScissor(wx, wy, w * _scale, h * _scale)
end

return Viewport
