-- tools/SmokeTitleFx.lua
-- 타이틀 2.5D 배경 연출 헤드리스 검증:
--   1) shaders/title_scene.glsl · shaders/title_bolt.glsl 컴파일 및 리소스 로드
--   2) 마우스 패럴랙스 감쇠, 나무 간판 스치기 진자 물리 + sign_creak, 포탈 근접 활성화, 돌길 파동
--   3) 좌측 빈 하늘 클릭 수동 번개 · 모달/우측 차단 · 0.4~1.2초 시차 천둥 예약/재생 · 6~14초 자동 번개
--   4) assets/title_fx/ 누락 시 정적 폴백 렌더링 + --shots 오프스크린 캡처(평상시 · 번개 점멸 · 메뉴 가독성)

local SmokeTitleFx = {}

local function check(cond, msg)
    assert(cond, "SmokeTitleFx: " .. msg)
end

local function save_canvas(canvas, filename)
    canvas:newImageData():encode("png", filename)
end

local function render_title_frame(canvas, scene, weather, with_menu)
    local LG = love.graphics
    local TitleLogo = require("ui.TitleLogo")
    local MenuList = require("ui.MenuList")
    local I18n = require("systems.I18n")
    local LAYOUT = require("data.layout")
    local L = LAYOUT.title

    LG.push("all")
    LG.setCanvas(canvas)
    LG.clear(0.02, 0.03, 0.05, 1)
    local flash, lu, lv = weather:lightning_state()
    scene:draw_base(flash, lu, lv)
    weather:draw_background()
    scene:draw_sign()
    weather:draw_foreground()
    if with_menu then
        scene:draw_dim(0.14)
        TitleLogo.draw(L.logo.cx, L.logo.y, L.logo.w, 1)
        local menu = MenuList(L.menu, {
            { id = "start", icon = "play", label = function() return I18n.t("title.menu_start") end, on_activate = function() end },
            { id = "meta", icon = "star", label = function() return I18n.t("title.meta_button", { rp = 0 }) end, on_activate = function() end },
            { id = "compendium", icon = "gem", label = function() return I18n.t("compendium.menu") end, on_activate = function() end },
            { id = "settings", icon = "gear", label = function() return I18n.t("title.settings_button") end, on_activate = function() end },
            { id = "quit", icon = "door", label = function() return I18n.t("title.menu_quit") end, on_activate = function() end },
        })
        menu:update(0.2, 0, 0, false)
        menu:draw(1)
    end
    LG.setCanvas()
    LG.pop()
end

function SmokeTitleFx.run(log, shots, missing_assets)
    local RNG = require("core.RNG")
    local Audio = require("systems.Audio")
    local TitleScene = require("ui.TitleScene")
    local TitleWeather = require("ui.TitleWeather")
    local FX = require("data.title_fx")

    RNG.set_seed(4242)
    Audio.init()
    TitleScene.set_fx_enabled(true)

    local scene = TitleScene()
    local weather = TitleWeather(scene)

    -- 1) 셰이더 컴파일 및 활성 상태 확인
    if missing_assets then
        check(not scene:is_shader_active(), "shader FX must stay inactive in missing-assets mode")
    else
        check(scene:is_shader_active(), "title_scene.glsl and assets/title_fx/* must load cleanly")
        check(scene:depth_image() ~= nil, "depth.png must be loaded")
    end

    -- 2) 마우스 패럴랙스 감쇠 + 간판 스치기 진자 물리 + 포탈 근접 + 돌길 파동
    for _ = 1, 20 do
        scene:update(0.03, 1120, 220, true)
        weather:update(0.03, 1120, 220, true)
    end
    local st = scene:get_state()
    check(st.mouse_x > 0.25 and st.mouse_y < -0.10, "mouse parallax must damp toward pointer")

    -- 간판 영역 스치기
    local sx, sy = scene:uv_to_screen(FX.sign.pivot.x, FX.sign.pivot.y + 0.07, FX.sign.depth)
    scene:update(0.016, sx - 35, sy, true)
    scene:update(0.016, sx + 15, sy, true)
    scene:update(0.016, sx + 55, sy, true)
    local after_swipe = scene:get_state()
    check(math.abs(after_swipe.sign_vel) > 0.2, "swiping across the sign must impart pendulum angular velocity")
    for _ = 1, 8 do
        scene:update(0.02, sx + 55, sy, false)
    end
    check(math.abs(scene:get_state().sign_angle) > 0.02, "pendulum angle must deflect after swipe")

    -- 포탈 근접 활성화
    local px, py = scene:uv_to_screen(FX.portal.x, FX.portal.y, FX.portal.depth)
    for _ = 1, 15 do
        scene:update(0.04, px, py, true)
    end
    check(scene:portal_energy() > 1.25, "hovering near the portal must boost portal energy")

    -- 돌길 커서 파동
    local cx, cy = scene:uv_to_screen(FX.cobble.x + 0.18, FX.cobble.y + 0.12, 0.72)
    weather:update(0.2, cx, cy, true)
    check(scene:get_state().ripple_count >= 1, "cobblestone cursor/rain interaction must spawn ripples")

    -- 3) 수동·차단·자동 번개 & 0.4~1.2초 시차 천둥 예약/재생 검증
    local before_strikes = weather:strike_count()
    check(not weather:try_click_lightning(280, 240, true), "blocked overlay/modal must disable click lightning")
    check(not weather:try_click_lightning(1020, 420, false), "clicking right portal area must not fire left-sky lightning")
    check(weather:try_click_lightning(280, 240, false), "clicking empty left sky must trigger lightning")
    check(weather:strike_count() == before_strikes + 1, "strike count incremented on manual sky click")
    check(weather:pending_thunder_count() >= 1, "lightning strike must schedule delayed thunder")
    local flash_now = weather:lightning_state()
    check(flash_now > 0.7, "lightning double-flash intensity must spike immediately")

    -- 오프스크린 렌더링 & 스냅샷(--shots)
    local canvas = love.graphics.newCanvas(1280, 720)
    render_title_frame(canvas, scene, weather, true)
    if shots then
        save_canvas(canvas, "smoke_title_fx_lightning.png")
    end

    -- 1.4초 경과 → 예약된 시차 천둥 발화 확인
    for _ = 1, 28 do
        scene:update(0.05, 640, 360, false)
        weather:update(0.05, 640, 360, false)
    end
    check(weather:pending_thunder_count() == 0, "delayed thunder must trigger within 1.4s")
    if not missing_assets then
        local played = Audio.stats().played
        check((played.title_thunder or 0) >= 1, "title_thunder sound must play after delay")
        check((played.sign_creak or 0) >= 1, "sign_creak sound must play when swiping sign")
    end

    -- 평상시(번개 소멸 후) 스냅샷(--shots)
    render_title_frame(canvas, scene, weather, true)
    if shots then
        save_canvas(canvas, "smoke_title_fx_rest.png")
    end

    -- 자동 번개(6~14초 불규칙 주기) 검증: 15초 경과 시 최소 1회 자동 발생
    local pre_auto = weather:strike_count()
    for _ = 1, 150 do
        weather:update(0.1, 640, 360, false)
    end
    check(weather:strike_count() > pre_auto, "automatic irregular lightning must fire within 15s")

    -- 4) assets/title_fx/ 누락 폴백 경로 강제 검증
    TitleScene.set_fx_enabled(false)
    local fb_scene = TitleScene()
    local fb_weather = TitleWeather(fb_scene)
    check(not fb_scene:is_shader_active(), "disabled/missing title_fx must fall back safely")
    fb_scene:update(0.05, 400, 300, true)
    fb_weather:trigger_lightning(0.24)
    fb_weather:update(0.05, 400, 300, true)
    render_title_frame(canvas, fb_scene, fb_weather, true)
    TitleScene.set_fx_enabled(true)

    log("title fx ok (shader=%s, parallax/sign/portal/ripples, manual+auto lightning, delayed thunder, fallback render)",
        tostring(not missing_assets))
end

return SmokeTitleFx
