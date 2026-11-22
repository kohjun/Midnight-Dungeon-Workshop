-- data/title_fx.lua
-- 타이틀 2.5D 배경 연출 수치 및 정규화 좌표(0~1, LÖVE 상단 원점). 로직 없음.
-- 좌표는 tools/build_title_maps.py 가 assets/backgrounds/title.png 기준으로 자동 기록한다.

return {
    assets = {
        clean = "assets/title_fx/title_clean.png",
        fallback = "assets/backgrounds/title.png",
        depth = "assets/title_fx/depth.png",
        mask_env = "assets/title_fx/mask_env.png",
        mask_fx = "assets/title_fx/mask_fx.png",
        sign = "assets/title_fx/sign_sprite.png",
        shader = "shaders/title_scene.glsl",
    },

    image = { w = 1360, h = 768, aspect = 1.770833 },

    parallax = {
        zoom = 1.03,
        strength_x = 0.017,
        strength_y = 0.012,
        damp = 6.0,
        idle_x = 0.06,
        idle_y = 0.04,
    },

    sign = {
        pivot = { x = 0.71176, y = 0.4388 },
        box = { x = 0.68603, y = 0.4349, w = 0.05735, h = 0.15234 },
        sprite_pivot = { x = 35.0, y = 3.0 },
        depth = 0.3569,
        stiffness = 22.0,
        damping = 1.8,
        max_angle = 0.48,
        wind_amp = 0.18,
        swipe_gain = 0.0085,
        max_vel = 3.5,
        creak_threshold = 0.14,
        creak_cooldown = 0.42,
    },

    chimney = {
        x = 0.49706,
        y = 0.21094,
        depth = 0.3333,
        rate = 4.2,
    },

    portal = {
        x = 0.86373,
        y = 0.59389,
        box = { x = 0.81103, y = 0.41276, w = 0.10441, h = 0.34375 },
        depth = 0.2824,
        brazier_left = { x = 0.75172, y = 0.58471 },
        brazier_right = { x = 0.97574, y = 0.5923 },
        ember_rate = 11.0,
    },

    moon = {
        x = 0.73554,
        y = 0.12591,
        radius = 0.04434,
    },

    windows = {
        { x = 0.50407, y = 0.65851 },
        { x = 0.60135, y = 0.43865 },
    },

    cobble = {
        x = 0.47574,
        y = 0.75651,
        w = 0.44191,
        h = 0.24219,
        ripple_max = 8,
        ripple_life = 1.35,
        rain_ripple_rate = 5.5,
        cursor_ripple_cd = 0.11,
    },

    lightning = {
        interval_min = 6.0,
        interval_max = 14.0,
        first_min = 3.2,
        first_max = 6.0,
        duration_min = 0.15,
        duration_max = 0.24,
        thunder_delay_min = 0.4,
        thunder_delay_max = 1.2,
        depth = 0.14,
        sky_click = { x_min = 0.03, x_max = 0.47, y_min = 0.02, y_max = 0.68 },
        bolt_x_min = 0.11,
        bolt_x_max = 0.42,
        bolt_end_y_min = 0.64,
        bolt_end_y_max = 0.74,
    },

    rain = {
        bg_count = 72,
        fg_count = 54,
        slant = -0.13,
        speed_bg = 520,
        speed_fg = 860,
    },

    mist = {
        count = 6,
        y_min = 0.62,
        y_max = 0.90,
        x_max = 0.54,
    },
}
