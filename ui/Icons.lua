-- ui/Icons.lua
-- 코드로 그리는 작은 아이콘 (버튼·HUD·메뉴용). 단위 좌표(-0.5 ~ 0.5)에 그린 뒤 size 로 확대한다.
--   Icons.draw(name, cx, cy, size, color, alpha)
-- 아이콘 이름은 버튼 opts.icon 과 같다. 파일이 아니라 코드라서 에셋이 없어도 항상 보인다.

local Icons = {}

local LG = love.graphics
local LINE = 0.1
local SEGMENTS = 20

local function circle(mode, x, y, r)
    LG.circle(mode, x, y, r, SEGMENTS)
end

local SHAPES = {}

function SHAPES.uv()            -- 손잡이 달린 UV 렌즈 + 빛살
    circle("line", -0.06, -0.06, 0.24)
    LG.line(0.11, 0.11, 0.4, 0.4)
    circle("fill", -0.06, -0.06, 0.09)
end

function SHAPES.brush()         -- 솔
    LG.polygon("fill", -0.42, 0.42, -0.1, 0.06, 0.06, 0.22, -0.3, 0.46)
    LG.line(0.0, 0.14, 0.4, -0.38)
end

function SHAPES.coin()
    circle("line", 0, 0, 0.36)
    circle("fill", 0, 0, 0.18)
end

function SHAPES.bell()          -- 새 손님: 상점 종
    LG.polygon("fill", -0.32, 0.24, 0.32, 0.24, 0.22, -0.12, 0.12, -0.28, -0.12, -0.28, -0.22, -0.12)
    circle("fill", 0, 0.34, 0.08)
    LG.line(0, -0.28, 0, -0.42)
end

function SHAPES.horn()          -- 모험가 호출: 나팔
    LG.polygon("fill", -0.42, -0.08, -0.12, -0.08, 0.36, -0.36, 0.36, 0.36, -0.12, 0.08, -0.42, 0.08)
end

function SHAPES.buy()           -- 매입: 금화 + 아래 화살표
    circle("line", 0, 0.12, 0.26)
    LG.line(0, -0.46, 0, -0.08)
    LG.line(-0.14, -0.2, 0, -0.06, 0.14, -0.2)
end

function SHAPES.sell()          -- 판매: 금화 + 위 화살표
    circle("line", 0, 0.12, 0.26)
    LG.line(0, -0.06, 0, -0.46)
    LG.line(-0.14, -0.32, 0, -0.46, 0.14, -0.32)
end

function SHAPES.dismiss()       -- 돌려보내기: 문 밖 화살표
    LG.line(0.36, 0, -0.3, 0)
    LG.line(-0.1, -0.22, -0.32, 0, -0.1, 0.22)
end

function SHAPES.stash()         -- 보관함: 상자
    LG.rectangle("line", -0.34, -0.12, 0.68, 0.46)
    LG.polygon("fill", -0.4, -0.12, 0.4, -0.12, 0.3, -0.34, -0.3, -0.34)
end

function SHAPES.scroll()
    LG.rectangle("line", -0.26, -0.34, 0.52, 0.68)
    LG.line(-0.14, -0.14, 0.14, -0.14)
    LG.line(-0.14, 0.04, 0.14, 0.04)
end

function SHAPES.flame()         -- 용광로 강화
    LG.polygon("fill", 0, -0.46, 0.22, -0.1, 0.3, 0.16, 0.16, 0.4, -0.16, 0.4, -0.3, 0.16, -0.2, -0.06)
end

function SHAPES.hammer()        -- 공방 개조
    LG.polygon("fill", -0.36, -0.34, 0.2, -0.34, 0.26, -0.16, -0.36, -0.16)
    LG.line(-0.08, -0.16, 0.26, 0.44)
end

function SHAPES.gear()          -- 설정
    local points = {}
    for i = 0, 15 do
        local radius = (i % 2 == 0) and 0.44 or 0.3
        local angle = i / 16 * math.pi * 2
        points[#points + 1] = math.cos(angle) * radius
        points[#points + 1] = math.sin(angle) * radius
    end
    LG.polygon("line", points)
    circle("fill", 0, 0, 0.12)
end

function SHAPES.moon()
    LG.stencil(function()
        circle("fill", 0.16, -0.12, 0.3)
    end, "replace", 1)
    LG.setStencilTest("equal", 0)
    circle("fill", 0, 0, 0.38)
    LG.setStencilTest()
end

function SHAPES.sun()
    circle("fill", 0, 0, 0.2)
    for i = 0, 7 do
        local angle = i / 8 * math.pi * 2
        LG.line(math.cos(angle) * 0.3, math.sin(angle) * 0.3, math.cos(angle) * 0.44, math.sin(angle) * 0.44)
    end
end

function SHAPES.shield()
    LG.polygon("fill", -0.34, -0.38, 0.34, -0.38, 0.34, 0.04, 0, 0.44, -0.34, 0.04)
end

function SHAPES.hourglass()     -- 상납 카운트다운
    LG.polygon("fill", -0.28, -0.42, 0.28, -0.42, 0, 0)
    LG.polygon("line", -0.28, 0.42, 0.28, 0.42, 0, 0)
    LG.line(-0.34, -0.42, 0.34, -0.42)
    LG.line(-0.34, 0.42, 0.34, 0.42)
end

function SHAPES.play()
    LG.polygon("fill", -0.26, -0.36, 0.38, 0, -0.26, 0.36)
end

function SHAPES.star()          -- 영구 강화
    local points = {}
    for i = 0, 9 do
        local radius = (i % 2 == 0) and 0.46 or 0.2
        local angle = -math.pi / 2 + i / 10 * math.pi * 2
        points[#points + 1] = math.cos(angle) * radius
        points[#points + 1] = math.sin(angle) * radius
    end
    LG.polygon("line", points)
end

function SHAPES.book()          -- 튜토리얼
    LG.polygon("line", 0, -0.3, -0.42, -0.38, -0.42, 0.3, 0, 0.38)
    LG.polygon("line", 0, -0.3, 0.42, -0.38, 0.42, 0.3, 0, 0.38)
end

function SHAPES.grid()          -- 진열장 배치 탭: 3x3 칸
    for row = 0, 2 do
        for col = 0, 2 do
            LG.rectangle("line", -0.42 + col * 0.29, -0.42 + row * 0.29, 0.24, 0.24)
        end
    end
end

function SHAPES.gem()           -- 유물 도감: 깎은 보석
    LG.polygon("line", -0.42, -0.12, -0.22, -0.38, 0.22, -0.38, 0.42, -0.12, 0, 0.42)
    LG.line(-0.42, -0.12, 0.42, -0.12)
    LG.line(-0.12, -0.12, 0, 0.42, 0.12, -0.12)
end

function SHAPES.door()          -- 종료
    LG.rectangle("line", -0.3, -0.42, 0.44, 0.84)
    circle("fill", 0.04, 0.02, 0.06)
    LG.line(0.14, 0, 0.46, 0)
end

function SHAPES.back()
    LG.line(0.36, 0, -0.34, 0)
    LG.line(-0.1, -0.24, -0.34, 0, -0.1, 0.24)
end

function SHAPES.hooded()        -- 손님 초상: 두건 쓴 모험가
    LG.polygon("fill", -0.42, 0.46, 0.42, 0.46, 0.3, 0.06, 0, -0.46, -0.3, 0.06)
end

function SHAPES.banner()        -- 길드: 깃대에 걸린 길드 깃발
    LG.line(-0.36, -0.46, -0.36, 0.48)
    LG.rectangle("fill", -0.32, -0.42, 0.74, 0.42)
    LG.polygon("fill", -0.32, -0.02, 0.05, -0.02, -0.32, 0.24)
    LG.polygon("fill", 0.05, -0.02, 0.42, -0.02, 0.42, 0.24)
end

function SHAPES.quest()         -- 의뢰: 밀랍 봉인이 찍힌 의뢰서
    LG.rectangle("line", -0.34, -0.42, 0.68, 0.84, 0.06, 0.06)
    LG.line(-0.2, -0.22, 0.2, -0.22)
    LG.line(-0.2, -0.04, 0.2, -0.04)
    circle("fill", 0.18, 0.26, 0.16)
end

function SHAPES.stone()         -- 연마석: 비스듬한 숫돌 + 반짝임
    LG.polygon("fill", -0.46, 0.12, 0.18, -0.34, 0.46, -0.1, -0.18, 0.36)
    LG.line(0.3, -0.46, 0.3, -0.3)
    LG.line(0.22, -0.38, 0.38, -0.38)
end

function SHAPES.lock()
    LG.arc("line", "open", 0, -0.08, 0.2, math.pi, math.pi * 2, 10)
    LG.rectangle("fill", -0.3, -0.08, 0.6, 0.44, 0.06, 0.06)
end

function Icons.has(name)
    return SHAPES[name] ~= nil
end

function Icons.draw(name, cx, cy, size, color, alpha)
    local shape = SHAPES[name]
    assert(shape ~= nil, "Icons: unknown icon '" .. tostring(name) .. "'")
    LG.push()
    LG.translate(cx, cy)
    LG.scale(size)
    LG.setLineWidth(LINE)
    LG.setLineJoin("bevel")
    LG.setColor(color[1], color[2], color[3], (color[4] or 1) * (alpha or 1))
    shape()
    LG.pop()
    LG.setLineJoin("miter")
end

return Icons
