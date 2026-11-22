-- data/ui.lua
-- UI 테마: 글꼴 크기·글자 유형, 색상, 연출 수치. 로직 없음.

return {
    -- 글자 유형: Draw.text / Draw.font 에 이름으로 넘긴다. role 은 data/fonts.lua 의 역할
    type = {
        logo = { role = "display", size = 64 },
        headline = { role = "display", size = 40 },
        title = { role = "display", size = 28 },        -- 모달·화면 제목
        card_title = { role = "display", size = 24 },
        plate = { role = "display", size = 17 },        -- 패널 간판
        menu = { role = "display", size = 25 },         -- 타이틀 메뉴 항목
        item_name = { role = "display", size = 18 },    -- 작업대·모달 행의 유물 이름
        tooltip_name = { role = "ui", size = 17 },      -- 툴팁 유물 이름 (툴팁은 전부 ui/body 글꼴)
        button = { role = "ui", size = 14 },
        button_small = { role = "ui", size = 13 },     -- 한글 가독성 최소 13px
        label = { role = "ui", size = 13 },
        value = { role = "ui", size = 22 },
        value_small = { role = "ui", size = 16 },
        story = { role = "story", size = 18 },
        story_large = { role = "story", size = 22 },
    },

    font_size = {
        title = 60,
        heading = 34,
        large = 22,
        body = 17,
        small = 14,
        tiny = 13,
    },

    -- 글자 래스터 배율 (ui/FontCache): 물리 픽셀 배율(창 확대 × 운영체제 DPI)을 step 단위로 양자화해 이 범위로 제한
    text_raster = { min_scale = 1, max_scale = 3, step = 0.25 },
    -- 버튼·색 배경 위 라벨의 드롭 섀도우 (Draw.label_text)
    text_shadow = { offset = 1, alpha = 0.55 },

    color = {
        background = { 0.05, 0.05, 0.08 },
        panel = { 0.10, 0.10, 0.14 },
        panel_border = { 0.22, 0.22, 0.30 },
        slot = { 0.14, 0.14, 0.19 },
        slot_border = { 0.26, 0.26, 0.34 },
        slot_hover = { 0.98, 0.78, 0.30 },
        text = { 0.92, 0.92, 0.95 },
        text_dim = { 0.74, 0.71, 0.65 },           -- 어두운 패널 위 설명·보조 문구 (웜 라이트 그레이)
        text_disabled = { 0.55, 0.57, 0.65 },      -- 비활성 버튼·잠긴 메뉴 글자
        accent = { 0.98, 0.78, 0.30 },
        good = { 0.45, 0.90, 0.50 },
        danger = { 0.95, 0.38, 0.38 },
        uv = { 0.62, 0.38, 1.00 },
        uv_tint = { 0.10, 0.03, 0.22 },
        grime = { 0.30, 0.22, 0.12 },
        link_boost = { 0.40, 0.88, 1.00 },
        link_curse = { 0.80, 0.30, 0.90 },
        overclock = { 1.00, 0.34, 0.18 },
        day_sky = { 0.14, 0.13, 0.17 },
        night_sky = { 0.04, 0.05, 0.12 },
        ground = { 0.09, 0.08, 0.10 },
        wall = { 0.58, 0.50, 0.42 },
        furnace = { 1.00, 0.45, 0.12 },
        stone = { 0.66, 0.80, 0.92 },          -- 연마석 (HUD · 용광로 비용 · 드랍)
        gold = { 1.00, 0.84, 0.30 },
        hp = { 0.85, 0.30, 0.30 },
        button = { 0.17, 0.17, 0.24 },
        button_accent = { 0.52, 0.36, 0.10 },
        button_danger = { 0.52, 0.16, 0.14 },
        button_tool = { 0.20, 0.17, 0.32 },
        button_active = { 0.42, 0.26, 0.72 },
        button_disabled = { 0.11, 0.11, 0.14 },
    },

    anim = {
        title_intro = 0.7,
        prompt_pulse = 0.9,
        gameover_fade = 0.4,
        button_press = 0.28,
        button_hover_speed = 14,
        gold_pulse = 0.35,
        toast_life = 2.4,
        toast_max = 2,
        lever_speed = 10,
        end_delay = 1.6,            -- 승패 결정 후 결과 화면까지(초)
        contract_dim = 0.4,         -- 난이도 계약서: 배경이 어두워지는 시간(초)
        contract_unroll = 0.75,     -- 양피지가 위에서 아래로 펼쳐지는 시간(초)
        contract_dark = 0.72,       -- 다 어두워졌을 때 배경 위 검은 막 알파
    },

    -- 강화 +min_level 이상 유물 아이콘의 포일 광택 (shaders/foil.glsl, ui/Foil — 색은 data/forge.lua 의 강화 등급)
    foil = { min_level = 5, strength = 0.5, per_level = 0.08, max_strength = 0.9, speed = 0.32 },

    fx = {
        max_particles = 1400,
        max_shake = 14,             -- px
        shake_decay = 1.7,          -- trauma/초
        float_life = 0.9,
        float_rise = 46,            -- px
    },
}
