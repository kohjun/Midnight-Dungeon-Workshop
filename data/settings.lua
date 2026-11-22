-- data/settings.lua
-- 환경 설정 항목 정의. 저장 파일은 세이브 디렉토리의 save_settings.lua (systems/Settings.lua). 로직 없음.
-- kind: "choice"(choices 중 하나) | "percent"(0~100, step 단위) | "toggle"(true/false)
-- 표시 문구는 data/locales 의 settings.<id> / settings.choices.<id>.<값> 키.

return {
    save_file = "save_settings.lua",

    order = { "language", "master_volume", "sfx_volume", "bgm_volume", "mute", "fullscreen", "shake", "night_speed" },

    options = {
        language = { kind = "choice", default = "ko", choices = { "ko", "en" } },
        master_volume = { kind = "percent", default = 80, step = 10 },
        sfx_volume = { kind = "percent", default = 100, step = 10 },
        bgm_volume = { kind = "percent", default = 60, step = 10 },
        mute = { kind = "toggle", default = false },
        fullscreen = { kind = "toggle", default = false },     -- false = 창모드 1280x720
        shake = { kind = "choice", default = 1, choices = { 1, 0.5, 0 } },      -- 화면 흔들림 강도 배율
        night_speed = { kind = "choice", default = 1, choices = { 1, 2, 3 } },   -- 밤 전투 배속 (밤 화면 [>] 버튼 · Tab 과 같은 값)
    },
}
