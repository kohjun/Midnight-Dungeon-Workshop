-- tools/SmokeSystems.lua
-- 3단계(설정·다국어·오디오·스프라이트·조작) 헤드리스 검사:
--   다국어: ko/en 키 누락, 소스의 문구 키 실재 여부, 재시작 없는 언어 전환 / 설정: 정규화·저장 형식 왕복
--   화면: 전체화면 확대·레터박스 좌표 변환 / 오디오: 13종 로딩·피치 변조 재생 / 스프라이트: 30종 로딩·도형 폴백
--   버튼: 유물 없음·오염도 0%·골드/자원 부족 시 비활성(클릭 차단) 규칙과 키 힌트

local SmokeSystems = {}


local function check(condition, message)
    assert(condition, "SmokeSystems: " .. message)
end

local function check_i18n()
    local I18n = require("systems.I18n")
    local Settings = require("systems.Settings")
    local Item = require("entities.Item")
    for _, pair in ipairs({ { "ko", "en" }, { "en", "ko" } }) do
        local missing = I18n.missing(pair[1], pair[2])
        check(#missing == 0, string.format("locale '%s' lacks %d keys of '%s': %s", pair[2], #missing, pair[1],
            table.concat(missing, ", ", 1, math.min(#missing, 8))))
    end
    local SmokeI18n = require("tools.SmokeI18n")
    local checked = SmokeI18n.check_source_keys(I18n)
    SmokeI18n.check_data_keys(I18n)

    -- 실시간 전환: 같은 호출이 언어 설정에 따라 바로 다른 문구를 낸다
    local sword = Item("flame_sword", {})
    check(I18n.language() == "ko" and I18n.t("buttons.buy") == "매입하기" and I18n.item_name(sword) == "화염 검", "default language is Korean")
    local revision, events = I18n.revision(), 0
    local probe = {}
    require("core.EventBus").subscribe("i18n:language_changed", function() events = events + 1 end, { owner = probe })
    check(Settings.set("language", "en"), "language should switch to English")
    check(I18n.t("buttons.buy") == "Buy" and I18n.item_name(sword) == "Flame Sword", "English text after switching")
    check(I18n.t("fx.daily_income", { amount = 30 }) == "Daily income +30 G", "placeholders are filled")
    check(#I18n.list("difficulty.broker.summary") == 3 and I18n.t("upgrades.grid.levels.2") == "3x4 → 4x4", "list and index lookup")
    check(I18n.revision() == revision + 1 and events == 1, "language change bumps the revision and emits an event")
    check(not Settings.set("language", "xx") and I18n.language() == "en", "unknown language is rejected")
    Settings.set("language", "ko")
    require("core.EventBus").unsubscribe_owner(probe)
    check(I18n.t("story.address", { name = "A" }) == "A 사장님", "switched back to Korean")
    return checked
end

local function check_settings()
    local Settings = require("systems.Settings")
    check(Settings.get("mute") == true and Settings.get("fullscreen") == false, "smoke runs muted and windowed")
    check(Settings.set("master_volume", 55) and Settings.get("master_volume") == 55, "percent option")
    check(Settings.step("master_volume", 1) and Settings.get("master_volume") == 65, "step up")
    Settings.set("master_volume", 100)
    check(not Settings.step("master_volume", 1) and Settings.get("master_volume") == 100, "percent clamps at 100")
    check(not Settings.set("shake", 0.3) and Settings.set("shake", 0.5) and Settings.get("shake") == 0.5, "choice option validation")
    check(Settings.set("night_speed", 3) and not Settings.set("night_speed", 1.5) and not Settings.set("mute", "yes"),
        "toggle and choice validation (night speed 1x · 2x · 3x)")
    Settings.set("shake", 1)
    Settings.set("night_speed", 1)
    Settings.set("master_volume", 80)

    -- save_settings.lua 형식 왕복 (임시 파일) + 깨진 값은 기본값으로
    local path = "smoke_settings_roundtrip.lua"
    love.filesystem.write(path, Settings.serialize({
        language = "en", master_volume = 30, sfx_volume = 250, bgm_volume = 0, mute = true, fullscreen = false,
        shake = 0, night_speed = 9,
    }))
    local loaded = Settings.read_file(path)
    love.filesystem.remove(path)
    check(loaded.language == "en" and loaded.master_volume == 30 and loaded.bgm_volume == 0 and loaded.shake == 0, "settings round trip")
    check(loaded.sfx_volume == 100 and loaded.night_speed == 1 and loaded.mute == true, "out-of-range values are clamped or reset")
end

local function check_viewport()
    local Viewport = require("core.Viewport")
    Viewport.configure(1920, 1080)
    local x, y = Viewport.to_logical(960, 540)
    check(Viewport.scale() == 1.5 and x == 640 and y == 360, "fullscreen 1080p scales the 720p layout by 1.5")
    Viewport.configure(1600, 1200)     -- 4:3 화면: 위아래 레터박스
    x, y = Viewport.to_logical(0, 150)
    check(Viewport.scale() == 1.25 and x == 0 and y == 0, "letterboxed viewport offsets input")
    Viewport.configure()
    x, y = Viewport.to_logical(100, 50)
    check(Viewport.scale() == 1 and x == 100 and y == 50, "windowed mode is the identity transform")
end

-- missing_assets: 소리 파일이 하나도 없는 상태 — 전부 조용히 건너뛰어야 한다
local function check_audio(missing_assets)
    local Audio = require("systems.Audio")
    local AUDIO = require("data.audio")
    Audio.init()
    local stats = Audio.stats()
    if missing_assets then
        check(stats.loaded == 0 and not Audio.play("ui_click") and not Audio.is_bgm_playing(), "missing sounds must be skipped silently")
        Audio.set_loop("uv_hum", true)
        Audio.update(0.1)
        Audio.stop_loops()
        return 0, 0
    end
    check(stats.loaded == Audio.expected_count() and #stats.missing == 0,
        string.format("audio: %d of %d sounds loaded, missing: %s", stats.loaded, Audio.expected_count(), table.concat(stats.missing, ", ")))
    check(Audio.is_bgm_playing(), "ambient loop should be playing")
    local played = 0
    for name in pairs(AUDIO.sfx) do
        check(Audio.play(name), "sound should play: " .. name)
        played = played + 1
    end
    check(not Audio.play("ui_click"), "min_interval should rate-limit repeated sounds")
    Audio.set_loop("uv_hum", true)
    Audio.update(0.5)
    check(Audio.is_loop_on("uv_hum"), "hold loop should start")
    Audio.set_loop("uv_hum", false)
    Audio.update(0.5)
    Audio.stop_loops()
    return stats.loaded, played
end

local function check_sprites(missing_assets)
    local SpriteBank = require("ui.SpriteBank")
    local SpriteCatalog = require("ui.SpriteCatalog")
    local Item = require("entities.Item")
    local ItemRenderer = require("ui.ItemRenderer")
    local ItemFactory = require("systems.ItemFactory")
    local stats = SpriteCatalog.preload()
    if missing_assets then
        check(stats.loaded == 0, "expected no sprites in missing-assets mode, found " .. stats.loaded)
    else
        check(#stats.missing == 0 and stats.loaded == #SpriteCatalog.expected_names(),
            string.format("sprites: %d loaded, missing: %s", stats.loaded, table.concat(stats.missing, ", ")))
    end

    -- 스프라이트 경로와 도형 폴백 경로 모두 오류 없이 그려져야 한다 (오프스크린)
    local canvas = love.graphics.newCanvas(256, 256)
    love.graphics.push("all")
    love.graphics.setCanvas({ canvas, stencil = true })
    for pass = 1, 2 do
        SpriteBank.set_enabled(pass == 1)
        for _, id in ipairs(ItemFactory.prototype_ids()) do
            local item = Item(id, { grade = "legendary", flaw = "crack", contamination = 50, grime = { { x = 0, y = 0, r = 0.2 } } })
            item.revealed.grade, item.level = true, 9        -- +9: 심연 등급 포일 광택·강화 뱃지 경로도 함께
            SpriteBank.kick(item)
            ItemRenderer.draw(item, 128, 128, 120, { time = 1 })
            ItemRenderer.draw_xray(item, 128, 128, 120, 1)
        end
        check((SpriteCatalog.item_image(Item("flame_sword", {})) ~= nil) == (pass == 1 and not missing_assets),
            "sprites are used only when present and enabled")
    end
    SpriteBank.set_enabled(true)
    SpriteBank.update(1)
    check(require("ui.Foil").available(), "foil shader (shaders/foil.glsl) compiles")
    love.graphics.setCanvas()
    love.graphics.pop()
    return stats.loaded
end

-- 상황별 버튼 비활성화: 비활성 버튼은 눌러도 동작하지 않는다
local function check_buttons()
    local Workshop = require("systems.Workshop")
    local WorkshopInput = require("ui.WorkshopInput")
    local Item = require("entities.Item")
    local w = Workshop({ difficulty = "broker" })
    local input = WorkshopInput(w)
    local function enabled(id)
        return input:button(id):is_enabled()
    end
    check(not enabled("uv") and not enabled("brush") and not enabled("buy") and not enabled("sell") and not enabled("forge")
        and not enabled("scroll"), "empty workbench disables its buttons")
    check(not input:button("uv"):press() and input.tool == "none", "a disabled button blocks the click")

    w.appraisal:present_customer(Item("frost_crossbow", {}), false)
    check(enabled("dismiss") and input:button("dismiss"):press() and w.appraisal:bench_item() == nil,
        "[send away] clears the customer from the bench")
    local item = Item("flame_sword", { grade = "rare", contamination = 60, grime = {} })
    w.appraisal:present_customer(item, false)
    check(enabled("uv") and enabled("buy") and not enabled("brush") and not enabled("sell"), "customer relic: scan and buy only")
    w.gold = 1
    check(not enabled("buy") and not enabled("summon"), "not enough gold disables buy and summon")
    w.gold = 500
    check(w.appraisal:buy() and w.inventory:locate(item) == "grid", "a bought weapon is auto-placed on the showcase")
    check(w:move_item("grid", select(2, w.inventory:locate(item)), "bench", 1), "return it to the bench")
    check(enabled("brush") and enabled("sell") and enabled("stash") and not enabled("buy"), "owned dirty relic: brush, sell, stash")
    check(input:button("sell"):is_visible() and not input:button("buy"):is_visible() and not input:button("new_customer"):is_visible(),
        "the customer counter shows only the buttons for an owned relic")
    w.supplies:spend("water", 100)
    check(not enabled("brush"), "no purified water disables the brush")
    w.supplies:add("water", 100, "test")
    item.contamination, item.cleaned = 0, true
    check(not enabled("brush"), "0% contamination disables the brush")
    w.supplies:spend("uv", 100)
    check(not enabled("uv"), "dead UV battery disables the scanner")
    check(input:button("uv"):key_hint() == "1" and input:button("forge"):key_hint() == "4"
        and input:button("start_night"):key_hint() == "Space", "buttons carry their key hints")
    input:destroy()
    w:destroy()
end

function SmokeSystems.run(log, missing_assets)
    require("core.RNG").set_seed(3131)
    local keys = check_i18n()
    check_settings()
    check_viewport()
    local sounds, played = check_audio(missing_assets)
    local sprites = check_sprites(missing_assets)
    check_buttons()
    log("systems ok (i18n: %d source keys, ko/en in sync, live switch; settings round trip; viewport; audio %d loaded / %d played; sprites %d + shape fallback; button gating)",
        keys, sounds, played, sprites)
end

return SmokeSystems
