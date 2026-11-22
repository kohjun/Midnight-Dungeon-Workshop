// shaders/title_scene.glsl
// 타이틀 2.5D 배경 단일 픽셀 셰이더 (LÖVE 11.5 호환 GLSL):
//   tex        : title_clean.png (간판 제거 클린 배경) 또는 title.png
//   u_depth    : 5계층 깊이 맵 (밝을수록 전경)
//   u_mask_env : RGBA (R=밤하늘, G=보름달, B=돌길, A=고목·풀숲)
//   u_mask_fx  : RGBA (R=포탈 공허, G=룬·화로 불꽃, B=호박색 창문, A=번개 림라이트 윤곽)

extern Image u_depth;
extern Image u_mask_env;
extern Image u_mask_fx;

extern number u_time;
extern vec2 u_mouse;           // 감쇠된 정규화 마우스 (-1..1, +y 아래)
extern vec2 u_parallax;        // (strength_x, strength_y)
extern number u_zoom;          // 1.03 미세 확대 (외곽 검은 틈 방지)
extern number u_aspect;        // 1360 / 768
extern number u_lightning;     // 0..1 좌측 번개 플래시 강도
extern vec2 u_lightning_pos;   // 번개 중심 정규화 UV (상단 원점)
extern number u_portal_energy; // 0.5..2.0 (마우스 근접 시 가속)

extern vec2 u_portal_center;
extern vec2 u_brazier_left;
extern vec2 u_brazier_right;
extern vec2 u_moon_center;
extern number u_moon_radius;
extern vec2 u_win1;
extern vec2 u_win2;

// 돌길 물결 파동 8슬롯: xy = 정규화 UV, z = 경과 시간(초), w = 강도(0=비활성)
extern vec4 u_ripples[8];

float hash21(vec2 p) {
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    mat2 rot = mat2(0.80, -0.60, 0.60, 0.80);
    for (int i = 0; i < 4; i++) {
        v += a * vnoise(p);
        p = rot * p * 2.03 + vec2(17.1, 31.7);
        a *= 0.5;
    }
    return v;
}

// 평면 먹칠 그래픽노블 다층 밤구름 (좌 -> 우 흐름). returns vec2(far, mid)
vec2 eval_clouds(vec2 uv, number t) {
    float drift_far = t * 0.011;
    float drift_mid = t * 0.024;
    // LÖVE 상단 원점: y=0 위쪽 하늘, y=0.65 산맥 부근
    float sky_band = smoothstep(0.72, 0.44, uv.y) * smoothstep(-0.02, 0.14, uv.y);

    vec2 pf = vec2((uv.x - drift_far) * 2.7, uv.y * 5.6);
    float nf = fbm(pf + vec2(0.0, fbm(pf * 1.4) * 0.25));
    float c_far = (smoothstep(0.42, 0.54, nf) * 0.72 + smoothstep(0.58, 0.68, nf) * 0.28) * sky_band;

    vec2 pm = vec2((uv.x - drift_mid) * 4.0 + 3.7, uv.y * 8.2 + 1.4);
    float warp = fbm(pm * 1.15 + vec2(1.3, 2.1));
    float nm = fbm(pm + vec2(warp * 0.36, -warp * 0.18));
    float mid_band = smoothstep(0.66, 0.38, uv.y);
    float c_mid = (smoothstep(0.46, 0.55, nm) * 0.78 + smoothstep(0.60, 0.69, nm) * 0.22) * mid_band;
    return vec2(c_far, c_mid);
}

// 10스텝 릴리프 POM 패럴랙스 (2D 잉크 외곽선 늘어짐 방지)
vec2 parallax_uv(vec2 base_uv, vec2 p_dir) {
    if (length(p_dir) < 0.0001) {
        return clamp(base_uv, 0.001, 0.999);
    }
    const int STEPS = 10;
    float step_h = 1.0 / float(STEPS);
    float prev_h = 1.0;

    for (int i = 1; i <= STEPS; i++) {
        float curr_h = 1.0 - float(i) * step_h;
        vec2 curr_uv = clamp(base_uv + p_dir * (curr_h - 0.5), 0.001, 0.999);
        float curr_d = Texel(u_depth, curr_uv).r;
        if (curr_d >= curr_h) {
            float lo_h = curr_h;
            float hi_h = prev_h;
            for (int j = 0; j < 3; j++) {
                float mid_h = 0.5 * (lo_h + hi_h);
                vec2 mid_uv = clamp(base_uv + p_dir * (mid_h - 0.5), 0.001, 0.999);
                if (Texel(u_depth, mid_uv).r >= mid_h) {
                    lo_h = mid_h;
                } else {
                    hi_h = mid_h;
                }
            }
            float hit_h = 0.5 * (lo_h + hi_h);
            return clamp(base_uv + p_dir * (hit_h - 0.5), 0.001, 0.999);
        }
        prev_h = curr_h;
    }
    return clamp(base_uv - p_dir * 0.5, 0.001, 0.999);
}

vec4 effect(vec4 color, Image tex, vec2 raw_uv, vec2 screen_coords) {
    // 1. 1.03배 미세 확대 + 깊이 패럴랙스
    vec2 base_uv = (raw_uv - 0.5) / u_zoom + 0.5;
    vec2 p_dir = u_mouse * u_parallax;
    vec2 uv = parallax_uv(base_uv, p_dir);
    float depth = Texel(u_depth, uv).r;

    vec4 env_m = Texel(u_mask_env, uv);
    vec4 fx_m  = Texel(u_mask_fx, uv);

    float sky_m     = env_m.r;
    float moon_m    = env_m.g;
    float cobble_m  = env_m.b;
    float foliage_m = env_m.a;

    float void_m = fx_m.r;
    float glow_m = fx_m.g;
    float win_m  = fx_m.b;
    float rim_m  = fx_m.a;

    // 2. 고목·풀숲 바람 흔들림 (mask_env.a)
    float gust = sin(u_time * 1.35 + uv.x * 9.0 + uv.y * 5.0) * 0.65
               + sin(u_time * 2.85 + uv.y * 16.0 + uv.x * 13.0) * 0.35;
    vec2 sway = vec2(gust * 0.0020, sin(u_time * 2.1 + uv.x * 18.0) * 0.0008) * foliage_m;
    vec2 s_uv = clamp(uv - sway, 0.001, 0.999);
    float dest_fol = Texel(u_mask_env, s_uv).a;
    vec2 tex_uv = mix(uv, s_uv, smoothstep(0.02, 0.25, max(foliage_m, dest_fol)));

    vec3 col = Texel(tex, tex_uv).rgb;
    float orig_luma = dot(col, vec3(0.299, 0.587, 0.114));
    // 굵은 검은 잉크선 보존 (어두운 선분 위에는 반사·스필을 억제)
    float ink_keep = smoothstep(0.035, 0.145, orig_luma);

    // 3. 이동하는 밤구름 (mask_env.r) & 빛나는 보름달 (mask_env.g)
    float moon_pulse = 0.90 + 0.12 * sin(u_time * 0.85) + 0.04 * sin(u_time * 1.9 + 0.7);
    float moon_dist = length((uv - u_moon_center) * vec2(u_aspect, 1.0));

    if (sky_m > 0.01 || moon_m > 0.01) {
        vec2 cl = eval_clouds(uv, u_time);
        float c_far = cl.x;
        float c_mid = cl.y;
        float c_tot = clamp(c_far * 0.45 + c_mid * 0.85, 0.0, 1.0);

        // 보름달 호흡 발광
        if (moon_m > 0.01) {
            vec3 m_lit = col * (0.96 + 0.13 * moon_pulse) + vec3(0.055, 0.05, 0.032) * moon_pulse;
            col = mix(col, m_lit, moon_m);
        }

        // 다층 달무리 (순수 하늘 영역에만 제한해 지붕·절벽 번짐 방지)
        float out_moon = smoothstep(u_moon_radius * 0.82, u_moon_radius * 1.28, moon_dist);
        float halo_in  = exp(-moon_dist * 13.5) * 0.28;
        float halo_out = exp(-moon_dist * 5.2) * 0.16;
        vec3 halo_col = vec3(0.92, 0.88, 0.74) * halo_in + vec3(0.66, 0.74, 0.88) * halo_out;
        col += halo_col * moon_pulse * out_moon * sky_m * (1.0 - c_tot * 0.45);

        // 평면 먹칠 밤구름 합성
        vec3 far_col = vec3(0.075, 0.105, 0.175);
        vec3 mid_col = mix(vec3(0.090, 0.112, 0.188), vec3(0.155, 0.168, 0.258), smoothstep(0.35, 0.82, c_mid));
        float veil = mix(1.0, 0.62, moon_m);
        vec3 sky_col = mix(col, far_col, c_far * 0.42 * veil);
        sky_col = mix(sky_col, mid_col, c_mid * 0.60 * veil);

        // 달 앞을 스치는 구름 가장자리의 은빛 테두리 (Silver Lining)
        float near_moon = exp(-moon_dist * 5.8);
        float c_rim = smoothstep(0.08, 0.38, c_tot) * smoothstep(0.90, 0.36, c_tot);
        sky_col += vec3(0.88, 0.90, 0.96) * c_rim * near_moon * (0.48 + 0.52 * moon_m) * moon_pulse * 0.55;

        // 번개 점멸 시 구름 아랫면 밝아짐 (LÖVE 상단 원점이므로 위쪽 샘플은 uv.y - 0.024)
        if (u_lightning > 0.002) {
            vec2 cl_up = eval_clouds(uv + vec2(0.0, -0.024), u_time);
            float up_tot = clamp(cl_up.x * 0.45 + cl_up.y * 0.85, 0.0, 1.0);
            float belly = clamp((up_tot - c_tot) * 2.6 + c_tot * 0.35, 0.0, 1.0);
            float l_dist = length((uv - u_lightning_pos) * vec2(u_aspect, 1.0));
            float spread = exp(-l_dist * 2.4);
            vec3 sky_flash = vec3(0.42, 0.41, 0.68) * (exp(-l_dist * 3.8) * 0.34 + exp(-l_dist * 1.4) * 0.10);
            vec3 belly_flash = vec3(0.80, 0.78, 0.98) * belly * (0.35 + 0.65 * spread) * 0.64;
            sky_col += (sky_flash + belly_flash) * u_lightning;
        }
        col = mix(col, sky_col, sky_m);
    }

    // 4. 번개 림라이트: 산맥 능선 & 공방 좌측 지붕·굴뚝 윤곽 (mask_fx.a)
    if (u_lightning > 0.002) {
        float bolt_prox = exp(-abs(uv.x - u_lightning_pos.x) * 3.2);
        if (rim_m > 0.01) {
            col += vec3(0.78, 0.77, 1.00) * rim_m * (0.48 + 0.52 * bolt_prox) * u_lightning * 0.58;
        }
        // 먼 산맥 및 공방 좌측면의 절제된 순간 반사광 (고목 실루엣 x<0.28 제외)
        float mtn_band = smoothstep(0.05, 0.10, depth) * smoothstep(0.26, 0.17, depth) * smoothstep(0.68, 0.20, uv.x);
        col += vec3(0.18, 0.21, 0.36) * mtn_band * (0.45 + 0.55 * bolt_prox) * u_lightning * 0.24;
        float roof_bounce = smoothstep(0.34, 0.42, uv.x) * smoothstep(0.70, 0.52, uv.x)
                          * smoothstep(0.76, 0.28, uv.y) * smoothstep(0.28, 0.40, depth) * ink_keep;
        col += vec3(0.22, 0.24, 0.42) * roof_bounce * u_lightning * 0.20;
    }

    // 5. 포탈 소용돌이 (mask_fx.r, 마우스 근접 시 가속)
    if (void_m > 0.01) {
        vec2 q = (uv - u_portal_center) * vec2(u_aspect, 1.0);
        float r = length(q);
        float ang = atan(q.y, q.x);
        float speed = 0.55 + u_portal_energy * 0.72;
        float twist = ang + (1.35 / (r + 0.18)) - u_time * speed;
        vec2 pflow = vec2(cos(twist), sin(twist)) * r;

        float n1 = fbm(pflow * 16.0 + vec2(0.0, u_time * (0.45 + u_portal_energy * 0.32)));
        float n2 = fbm(q * 20.0 + vec2(n1 * 1.6, u_time * 0.62));
        vec2 dist_uv = uv + vec2(n1 - 0.5, n2 - 0.5) * 0.020 * (0.65 + u_portal_energy * 0.42) * void_m;
        float valid_sw = Texel(u_mask_fx, clamp(dist_uv, 0.001, 0.999)).r;
        vec3 base_void = Texel(tex, mix(uv, dist_uv, valid_sw)).rgb;

        float wf = n1 * 0.58 + n2 * 0.42;
        vec3 p_void = mix(vec3(0.055, 0.018, 0.085), vec3(0.34, 0.085, 0.40), smoothstep(0.36, 0.50, wf));
        p_void = mix(p_void, vec3(0.58, 0.16, 0.58), smoothstep(0.52, 0.66, wf) * 0.85);
        p_void += vec3(0.76, 0.32, 0.78) * smoothstep(0.68, 0.82, wf) * smoothstep(0.24, 0.02, r) * (0.28 + u_portal_energy * 0.30);

        float cav = smoothstep(0.02, 0.35, void_m);
        vec3 res_void = mix(base_void * 0.82, p_void, 0.60) * (0.74 + 0.26 * cav) * (0.92 + u_portal_energy * 0.22);
        col = mix(col, res_void, void_m);
    }

    // 6. 룬 호흡 & 좌우 화로 보라색 불꽃 (mask_fx.g)
    float rune_breath = 0.68 + 0.32 * sin(u_time * 1.35 + uv.y * 4.5);
    float fl_l = 0.86 + 0.14 * sin(u_time * 9.5 + sin(u_time * 3.7) * 2.0);
    float fl_r = 0.86 + 0.14 * sin(u_time * 10.3 + 2.1 + cos(u_time * 4.1) * 1.8);

    if (glow_m > 0.01) {
        // 화로 불꽃 위치 (좌측 x<0.775 또는 우측 x>0.945, 하단 y>0.49) vs 아치 룬 문자
        float is_flame = step(0.49, uv.y) * max(step(uv.x, 0.778), step(0.942, uv.x));
        if (is_flame > 0.5) {
            float wx = (vnoise(vec2(uv.x * 48.0, uv.y * 36.0 + u_time * 5.8)) - 0.5) * 0.0055;
            float wy = (vnoise(vec2(uv.x * 32.0 + 7.2, uv.y * 28.0 + u_time * 7.2)) - 0.5) * 0.0065;
            vec2 f_uv = clamp(uv + vec2(wx, abs(wy) * 0.55) * glow_m, 0.001, 0.999);
            float f_ok = Texel(u_mask_fx, f_uv).g;
            vec3 f_col = Texel(tex, mix(uv, f_uv, f_ok)).rgb;
            float f_pulse = mix(fl_l, fl_r, step(0.85, uv.x)) * (0.94 + u_portal_energy * 0.16);
            float core = smoothstep(0.35, 0.85, dot(f_col, vec3(0.35, 0.25, 0.40)));
            col = mix(col, f_col * f_pulse + vec3(0.18, 0.04, 0.16) * core * f_pulse, glow_m * 0.92);
        } else {
            float r_boost = rune_breath * (0.85 + u_portal_energy * 0.32);
            vec3 r_col = col * (0.85 + 0.42 * r_boost) + vec3(0.24, 0.045, 0.17) * r_boost;
            col = mix(col, r_col, glow_m * 0.92);
        }
    }

    float d_bl = length((uv - u_brazier_left) * vec2(u_aspect, 1.0));
    float d_br = length((uv - u_brazier_right) * vec2(u_aspect, 1.0));
    float braz_b = exp(-d_bl * 15.0) * fl_l + exp(-d_br * 15.0) * fl_r;
    col += vec3(0.30, 0.08, 0.28) * braz_b * 0.14 * ink_keep * (1.0 - glow_m) * (1.0 - void_m);

    // 7. 공방 1·2층 창문 촛불 명멸 (mask_fx.b)
    float c1 = 0.86 + 0.07 * sin(u_time * 6.8) + 0.045 * sin(u_time * 13.4 + 1.3) + 0.025 * sin(u_time * 22.7 + 0.5);
    float c2 = 0.87 + 0.065 * sin(u_time * 5.9 + 2.4) + 0.045 * sin(u_time * 11.9 + 0.7) + 0.02 * sin(u_time * 19.3 + 3.1);
    if (win_m > 0.01) {
        float flk = mix(c2, c1, step(0.55, uv.y));
        vec3 warm = col * (0.82 + 0.34 * flk) + vec3(0.14, 0.065, 0.008) * (flk - 0.78);
        col = mix(col, warm, win_m);
    }
    float d_w1 = length((uv - u_win1) * vec2(u_aspect, 1.0));
    float d_w2 = length((uv - u_win2) * vec2(u_aspect, 1.0));
    col += vec3(0.42, 0.20, 0.04) * (exp(-d_w1 * 18.5) * c1 + exp(-d_w2 * 16.5) * c2) * 0.13 * ink_keep * (1.0 - win_m);

    // 8. 젖은 돌길 반사광 & 빗물 파동 (mask_env.b)
    if (cobble_m > 0.01) {
        col = mix(col, col * 0.88, cobble_m * ink_keep);
        float ring_sum = 0.0;
        vec2 rip_grad = vec2(0.0);
        for (int i = 0; i < 8; i++) {
            vec4 rip = u_ripples[i];
            if (rip.w > 0.001 && rip.z > 0.0 && rip.z < 1.35) {
                vec2 delta = (uv - rip.xy) * vec2(u_aspect, 2.75);
                float dist = length(delta);
                float rad = rip.z * 0.095;
                float w1 = exp(-pow((dist - rad) * 95.0, 2.0));
                float w2 = exp(-pow((dist - max(0.0, rad - 0.016)) * 115.0, 2.0)) * 0.45;
                float env = (1.0 - rip.z / 1.35);
                float tw = (w1 + w2) * env * env * rip.w;
                ring_sum += tw;
                if (dist > 0.0005) {
                    rip_grad += (delta / dist) * tw;
                }
            }
        }
        float p_noise = fbm(uv * vec2(42.0, 68.0) + rip_grad * 2.4);
        float gloss = (0.35 + 0.65 * smoothstep(0.28, 0.78, p_noise)) * cobble_m * ink_keep;

        float amber_w = smoothstep(0.84, 0.54, uv.x);
        float purple_w = smoothstep(0.56, 0.88, uv.x);
        col += vec3(0.92, 0.52, 0.16) * amber_w * (0.16 + 0.14 * c1) * gloss;
        col += vec3(0.68, 0.22, 0.78) * purple_w * (0.18 + 0.14 * rune_breath) * gloss;
        col += vec3(0.56, 0.58, 0.82) * u_lightning * 0.20 * gloss;

        vec3 r_tint = mix(vec3(0.92, 0.78, 0.60), vec3(0.84, 0.62, 0.94), smoothstep(0.64, 0.82, uv.x));
        col += r_tint * min(ring_sum, 1.5) * 0.58 * cobble_m * ink_keep;
    }

    return vec4(col, 1.0) * color;
}
