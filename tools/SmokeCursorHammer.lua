-- tools/SmokeCursorHammer.lua
-- 대장장이 망치 커서 검사 (ui/CursorHammer, SmokeCursor 다음에 돈다):
--   기본·호버 상태만 망치로 그림(원화가 있을 때) · 핫스팟 바로 안쪽(망치 머리 타격면)에 불투명 픽셀 · 클릭하면 내려찍기(swing > 0)
--   → 0.12초 뒤 복원 · 연타해도 효과음은 쿨타임 간격으로만 · 버튼 호버 클릭은 효과음 없음. --shots 면 쉼/내려찍기 견본 smoke_cursor_hammer.png
-- 원화가 없으면(--missing-assets) 망치를 쓰지 않는지(단검 도안 폴백)만 본다.

local SmokeCursorHammer = {}

local function check(condition, message)
    assert(condition, "SmokeCursorHammer: " .. message)
end

local function render(CursorHammer, swing_frames)
    local canvas = love.graphics.newCanvas(96, 96)
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.origin()
    love.graphics.translate(30, 40)                  -- 포인터 = (30, 40)
    for _ = 1, swing_frames do
        CursorHammer.update(1 / 120)
    end
    CursorHammer.draw(0)
    love.graphics.pop()
    return canvas
end

function SmokeCursorHammer.run(log, shots)
    local CursorHammer = require("ui.CursorHammer")
    local Audio = require("systems.Audio")
    local CURSORS = require("data.cursors")
    if CursorHammer.image() == nil then
        check(not CursorHammer.applies("default") and not CursorHammer.press("default", 0), "without art the dagger cursor is kept")
        log("cursor hammer ok (no art: dagger fallback)")
        return
    end
    check(CursorHammer.applies("default") and CursorHammer.applies("hover") and not CursorHammer.applies("grab")
        and not CursorHammer.applies("appraise"), "only the default/hover cursors become the hammer")
    CursorHammer.update(1)
    local rest = render(CursorHammer, 0)
    local hx, hy = 30 + 1, 40                         -- 핫스팟 바로 안쪽 = 망치 머리 타격면
    check(select(4, rest:newImageData():getPixel(hx, hy)) > 0.5, "the hammer face sits on the hotspot")
    local played = Audio.stats().played.cursor_tap or 0
    check(CursorHammer.press("default", 100), "a click on the default cursor swings the hammer")
    CursorHammer.press("default", 100.02)            -- 연타: 쿨타임 안 → 소리 한 번
    CursorHammer.press("hover", 100.5)               -- 버튼 위: 버튼이 자기 소리를 낸다
    check((Audio.stats().played.cursor_tap or 0) - played <= 1, "rapid taps are throttled and buttons stay silent")
    CursorHammer.update(CURSORS.hammer.strike.time * 0.3)
    check(CursorHammer.swing() > 0.3, "the hammer head swings down right after the click")
    local strike = render(CursorHammer, 0)
    CursorHammer.update(CURSORS.hammer.strike.time)
    check(CursorHammer.swing() == 0, "the hammer springs back after the strike")
    if shots then
        local sheet = love.graphics.newCanvas(192, 96)
        love.graphics.push("all")
        love.graphics.setCanvas(sheet)
        love.graphics.clear(0.12, 0.1, 0.12, 1)
        love.graphics.origin()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(rest, 0, 0)
        love.graphics.draw(strike, 96, 0)
        love.graphics.setColor(1, 0.3, 0.3, 1)
        love.graphics.circle("fill", 30, 40, 1.5)
        love.graphics.circle("fill", 126, 40, 1.5)
        love.graphics.pop()
        sheet:newImageData():encode("png", "smoke_cursor_hammer.png")
    end
    log("cursor hammer ok (default/hover hammer, hotspot on the face, strike + spring back, tap throttled)")
end

return SmokeCursorHammer
