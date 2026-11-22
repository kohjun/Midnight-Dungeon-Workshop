-- conf.lua
-- LÖVE 엔진 설정. 게임 로직 금지.

-- t.console 로 띄운 콘솔(또는 lovec)에 print 로그가 즉시 보이도록 stdout 버퍼링 해제
io.stdout:setvbuf("no")

function love.conf(t)
    t.identity = "midnight_workshop"  -- 세이브 디렉토리 이름 (%APPDATA%\LOVE\midnight_workshop)
    t.version = "11.5"
    t.console = true                  -- Windows 표준 출력 로깅용 콘솔

    t.window.title = "Midnight Dungeon Workshop"
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = false
    t.window.vsync = 1
    -- 125%/150% 디스플레이 배율에서 운영체제가 1배 화면을 늘려 번지게 하지 않고 물리 픽셀로 그린다.
    -- 그리기·마우스 좌표는 DPI 배율 단위로 유지되고(core/Viewport), 글자는 ui/FontCache 가 물리 해상도로 래스터화한다
    t.window.highdpi = true
    t.window.usedpiscale = true
end
