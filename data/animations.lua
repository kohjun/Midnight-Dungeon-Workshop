-- data/animations.lua
-- 절차적 애니메이션 수치 (추가 그림 없이 원화 한 장을 움직인다). 로직 없음.
--   presets : ui/MeshDeformer 의 4x6 격자 메시 변형 (좌표는 그림 긴 변 = 1 단위)
--   gaits   : ui/EntityMotion 의 밤 몬스터 보행 사이클 (px 는 몬스터 반경 배율)
--   wall    : 방벽 공격 예비 동작 → 돌진 → 타격 스쿼시 → 복귀 / hit : 피격 흰 점멸 + 넉백 스프링
--   ambient : ui/AmbientEffects 의 주인장 반응 · 유물 튀어 오름 · 진열장 부유 · 포탈 소용돌이 · 금빛 먼지

return {
    mesh = { cols = 4, rows = 6 },

    presets = {
        -- 발바닥 고정, 가슴·어깨가 부풀고 고개가 살짝 끄덕인다
        breathe = { speed = 1.7, swell = 0.05, rise = 0.02, chest = 0.42, chest_width = 0.2, nod = 0.035 },
        -- breathe 를 가볍게 (손님 카운터의 모험가 초상 — 얼굴·어깨만 보이므로 움직임을 줄인다)
        breathe_soft = { speed = 1.35, swell = 0.022, rise = 0.01, chest = 0.6, chest_width = 0.25, nod = 0.016 },
        -- 바닥 고정, 아래에서 위로 시차를 두고 출렁이며 찌그러졌다 복원
        jelly = { speed = 3.4, sway = 0.07, squash = 0.1, lag = 1.8 },
        -- 바닥 고정 없이 8자로 부유, 아래쪽 옷자락이 바람에 물결친다
        float_cape = { speed = 1.15, drift_x = 0.035, drift_y = 0.03, cape_from = 0.45, cape = 0.075, wave = 3.4 },
        -- 육중한 석조 몸체의 미세한 기계 진동 + 룬 명멸 (가산 혼합 한 겹)
        heavy_mech = { speed = 11, jitter = 0.006, settle = 0.012, glow_speed = 2.3, glow = 0.42, glow_color = { 1.0, 0.3, 0.75 } },
    },

    -- 원화 id → 메시 변형 프리셋
    monsters = {
        goblin = "breathe", ogre = "breathe", shield_bearer = "breathe", greed_raider = "breathe", skeleton = "breathe",
        slime = "jelly",
        abyss_necromancer = "float_cape", rift_lord = "float_cape", shadow_assassin = "float_cape",
        boss_master = "breathe",          -- 스승의 잔영: 묵직하게 숨 쉬며 걷는다 (보행 heavy)
        gatekeeper_golem = "heavy_mech",
    },
    shopkeeper = "breathe",
    adventurer = "breathe_soft",       -- 손님 카운터 모험가 초상 (ui/AdventurerPortrait)

    -- 보행: light = 통통 튀는 빠른 보폭 + 전방 기울기, heavy = 묵직한 한 걸음마다 내려앉는 스쿼시 + 발밑 먼지,
    -- float = 걷지 않는다 (float_cape 메시가 부유를 맡는다)
    gaits = {
        light = { tempo = 2.6, hop = 0.32, tilt = 0.12 },
        heavy = { tempo = 0.9, lift = 0.16, squash = 0.12, dust = 7 },
        float = {},
    },
    monster_gaits = {
        goblin = "light", shadow_assassin = "float", slime = "light", skeleton = "light",
        ogre = "heavy", shield_bearer = "heavy", gatekeeper_golem = "heavy", greed_raider = "heavy",
        abyss_necromancer = "float", rift_lord = "float", boss_master = "heavy",
    },

    -- 밤 전투 레인의 주인공 (ui/LaneHero) — 전투 규칙과 무관한 연출. 시간은 초, 거리는 px
    --   breathe : 대기 호흡 (세로 배율 ±amount)  ·  aura : 망치 끝·건틀릿 속성 오라 (radius = 키 배율)
    --   cast    : 진열장 유물이 쏠 때의 동조 투사 — cooldown_min ~ max 마다 공격 포즈(pose_time) + 마력 파동(wave_time 동안 wave_reach 까지)
    --   flash   : 유물이 쏠 때마다 스치는 황금 마력 섬광이 사라지는 시간
    --   melee   : 방벽 앞 range 안의 마물이 맞으면 근접 망치 내려찍기 — 공격 포즈 · 내려찍는 호(arc_time · arc_radius = 반지름 배율)
    --   block   : 방벽이 맞으면 방어 포즈(pose_time) · 뒤로 밀림(recoil) · 황금 룬 방패 파동(shield_time · shield_radius)
    hero = {
        breathe = { speed = 1.7, amount = 0.014 },
        aura = { radius = 0.24, alpha = 0.6, pulse = 2.6, front = 0.75, back = 0.16, back_radius = 0.62 },
        cast = { cooldown_min = 0.25, cooldown_max = 0.35, pose_time = 0.2, lunge = 5, wave_time = 0.45, wave_reach = 150 },
        flash = 0.14,
        melee = { range = 95, cooldown = 0.32, pose_time = 0.26, lunge = 12, arc_time = 0.3, arc_radius = 1.5 },
        block = { pose_time = 0.5, recoil = 7, shield_time = 0.6, shield_radius = 62 },
        default_color = { 1.0, 0.84, 0.36 },
        gold = { 1.0, 0.86, 0.42 },
    },

    wall = {
        windup = 0.18,          -- 몸을 뒤로 젖히며 붉은 기운을 모은다
        lunge = 0.08,           -- 방벽 쪽으로 돌진
        lean_back = 0.55,       -- 뒤로 젖히는 거리 (반경 배율)
        lean_angle = 0.22,
        overshoot = 0.35,       -- 방벽에 파고드는 거리 (반경 배율)
        impact = 0.08,          -- 타격 스쿼시
        recover = 0.24,         -- 원위치로 물러나며 사라진다
        glow = { 1.0, 0.18, 0.12 },
    },
    hit = {
        flash = 0.06,           -- 흰 점멸
        impulse = 260,          -- 넉백 초기 속도 (px/s)
        stiffness = 320,        -- 스프링 복원
        damping = 18,
    },

    ambient = {
        portrait = { nod = 0.14, lean = 0.1, bounce = 7, recoil = 6, decay = 5 },
        hop = { height = 16, time = 0.42 },             -- 세척·강화 성공 시 유물이 튀어 오른다
        levitate = { height = 3.2, speed = 1.7, phase = 0.7 },
        charge = { from = 0.85, scale = 0.1, glow = 0.45 },   -- 공격 쿨타임이 이만큼 차면 에너지를 모은다
        portal = { rings = 4, spin = 0.9, embers_per_second = 22 },
        motes = { count = 46, speed = 9, size = 1.6, alpha = 0.3, color = { 1.0, 0.82, 0.45 } },
    },
}
