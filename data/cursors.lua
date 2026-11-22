-- data/cursors.lua
-- 커스텀 마우스 커서 (ui/CursorManager · ui/CursorShapes). 다크 판타지 그래픽노블 화풍:
-- 굵은 검은 잉크 외곽선 + 낡은 황동 · 가죽 · 흑요석 · UV 보라 포인트.
--   size     : 도안 상자(32 단위)를 논리 픽셀로 그릴 크기
--   hotspot  : 도안 상자(0~32) 안에서 실제 포인터가 가리키는 점 (단검 끝 · 손바닥 중심 · 렌즈 중심)
--   scale    : 상태 자체 배율 (hover 는 기본 포인터를 살짝 키운다)
--   click_scale : 누르고 있는 동안 줄어드는 배율
--   ripple   : 클릭 지점 파동 { color, ink(뒤따르는 잉크 고리), radius, sparks(튀는 불티 수) }
--   palette  : 도안 부위별 색 (CursorShapes 가 키 이름으로 찾는다)

local INK = { 0.035, 0.025, 0.045 }
local HALO = { 0.93, 0.86, 0.68 }
local GOLD = { 1.00, 0.80, 0.34 }
local BRASS = { 0.76, 0.58, 0.27 }
local BRASS_DARK = { 0.44, 0.31, 0.13 }
local LEATHER = { 0.43, 0.26, 0.14 }
local LEATHER_DARK = { 0.27, 0.15, 0.08 }
local UV = { 0.70, 0.42, 1.00 }

return {
    unit = 32,
    ink_width = 2.6,          -- 잉크 외곽선 굵기 (도안 단위)
    halo_width = 4.6,         -- 잉크 바깥 옅은 테두리 (어두운 배경에서도 보이게)
    shadow = { x = 1.4, y = 2.2, alpha = 0.38 },
    switch_pop = 0.14,        -- 상태가 바뀌는 순간 커졌다 돌아오는 양
    switch_speed = 9,
    hover_speed = 12,
    press = { down_speed = 34, up_speed = 13 },
    sway = { per_speed = 0.00042, max = 0.32, follow = 10, smooth = 14 },   -- 이동 속도(논리 px/초) → 기울기(라디안)
    ripple = { life = 0.42, width = 3, spark_len = 7, max = 12 },

    -- 대장장이 망치 커서 (assets/sprites/cursor_hammer.png, ui/CursorHammer): states 의 커서(기본 · 버튼 호버)를 이 그림으로 그린다
    -- (그림이 없으면 아래 단검 도안). hotspot = 망치 머리 타격면(그림 기준 정규화) = 실제 클릭 지점, grip = 휘두를 때 도는 축(자루 끝)
    --   strike : 클릭하면 time 초 동안 머리가 angle 라디안만큼 내려찍었다가 탄성 있게 복원
    --   ripple : 클릭 지점 금빛·백색 타격 불티 (작고 깔끔하게), sound: 버튼이 아닌 곳을 누를 때 (tap_cooldown 초 간격)
    hammer = {
        image = "cursor_hammer", size = 40, hotspot = { x = 0.09, y = 0.4 }, grip = { x = 0.92, y = 0.92 },
        states = { default = true, hover = true },
        strike = { time = 0.12, angle = 0.3 },
        ripple = { color = { 1.0, 0.93, 0.70 }, ink = INK, radius = 11, sparks = 4 },
        sound = "cursor_tap", tap_cooldown = 0.07, glow = GOLD,
    },

    states = {
        default = {
            size = 34, hotspot = { 3, 2 }, scale = 1, click_scale = 0.84,
            ripple = { color = GOLD, ink = INK, radius = 20, sparks = 5 },
            palette = {
                ink = INK, halo = HALO, blade = { 0.09, 0.07, 0.13 }, sheen = { 0.52, 0.40, 0.72 }, edge = { 0.80, 0.70, 0.95 },
                guard = BRASS, guard_dark = BRASS_DARK, grip = LEATHER, grip_dark = LEATHER_DARK, pommel = BRASS, glint = UV,
            },
        },
        hover = {
            size = 34, hotspot = { 3, 2 }, scale = 1.1, click_scale = 0.84, glow = GOLD,
            ripple = { color = GOLD, ink = INK, radius = 24, sparks = 7 },
            palette = {
                ink = INK, halo = GOLD, blade = { 0.09, 0.07, 0.13 }, sheen = { 0.62, 0.48, 0.80 }, edge = { 1.00, 0.88, 0.60 },
                guard = { 0.90, 0.70, 0.32 }, guard_dark = BRASS_DARK, grip = LEATHER, grip_dark = LEATHER_DARK,
                pommel = { 0.95, 0.76, 0.36 }, glint = GOLD,
            },
        },
        grab = {
            size = 38, hotspot = { 16, 17 }, scale = 1, click_scale = 0.86,
            ripple = { color = GOLD, ink = INK, radius = 20, sparks = 4 },
            palette = {
                ink = INK, halo = HALO, leather = { 0.50, 0.31, 0.17 }, leather_dark = LEATHER_DARK, stitch = { 0.86, 0.72, 0.48 },
                cuff = { 0.33, 0.19, 0.10 }, stud = BRASS,
            },
        },
        grabbing = {
            size = 38, hotspot = { 16, 18 }, scale = 0.96, click_scale = 0.9,
            ripple = { color = GOLD, ink = INK, radius = 18, sparks = 4 },
            palette = {
                ink = INK, halo = HALO, leather = { 0.50, 0.31, 0.17 }, leather_dark = LEATHER_DARK, stitch = { 0.86, 0.72, 0.48 },
                cuff = { 0.33, 0.19, 0.10 }, stud = BRASS, relic = { 0.58, 0.30, 0.86 }, relic_light = { 0.92, 0.78, 1.00 },
                relic_rim = GOLD,
            },
        },
        appraise = {
            size = 40, hotspot = { 13, 13 }, scale = 1, click_scale = 0.88,
            ripple = { color = UV, ink = INK, radius = 22, sparks = 6 },
            palette = {
                ink = INK, halo = HALO, rim = BRASS, rim_dark = BRASS_DARK, glass = { 0.30, 0.16, 0.52 }, uv = UV,
                handle = LEATHER, handle_dark = LEATHER_DARK, ferrule = BRASS, shine = { 0.95, 0.92, 1.00 },
            },
        },
        web_cut = {
            size = 36, hotspot = { 3, 3 }, scale = 1, click_scale = 0.8,
            ripple = { color = { 0.86, 0.90, 1.00 }, ink = INK, radius = 22, sparks = 8 },
            palette = {
                ink = INK, halo = HALO, blade = { 0.80, 0.84, 0.92 }, sheen = { 1.00, 1.00, 1.00 }, edge = { 0.55, 0.60, 0.72 },
                guard = { 0.62, 0.66, 0.76 }, guard_dark = { 0.32, 0.34, 0.42 }, grip = { 0.20, 0.14, 0.12 },
                grip_dark = { 0.10, 0.07, 0.06 }, pommel = { 0.62, 0.66, 0.76 }, glint = UV,
            },
        },
    },
}
