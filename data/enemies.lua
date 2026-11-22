-- data/enemies.lua
-- 밤 몬스터 스펙: 일반 몬스터 · 소환수 · 중간 보스 4종 · 월말 대보스 4종, 보스·중간 보스 고유 패턴 수치. 로직 없음.
-- 이름은 data/locales/<언어>/items.lua 의 monsters.<id>, 툴팁 기믹 문구는 combat.lua 의 monster_tip.gimmick_<pattern>.
--   hp · speed · damage(방벽 피해) · gold(처치 골드, balance.economy.kill_gold_mult 를 곱한다) · radius(충돌 반경)
--   weight + weight_growth × (실효 일차-1), min_day(실효 일차) — 일반 웨이브 구성 (data/waves.lua)
--   elite = 정예 (연마석 드랍·넉백 저항) · boss = 월말 대보스 · midboss = 월 중순 중간 보스 · pattern = systems/BossPatterns 패턴
--   knockback_resist = 넉백 저항 (없으면 data/combat.lua 의 knockback 규칙) · slow_immune = 둔화·빙결 면역
--   중간 보스 그림: sprite 의 원화를 scale(1.35)배 · tint 색조 · aura("red" | "purple") 잉크 오라로 그린다 (ui/MidBossView)
--   final = '스승의 흔적' 캠페인 마지막 밤의 최종 보스 (월말 대보스 대신, data/master_trace.lua 의 final — systems/MasterBossPattern)

return {
    monster_order = { "slime", "goblin", "ogre", "shield_bearer", "shadow_assassin" },
    monsters = {
        slime = {
            shape = "slime", hp = 20, speed = 38, damage = 5, gold = 3, radius = 15,
            weight = 60, weight_growth = 0, min_day = 1, color = { 0.45, 0.32, 0.62 },
        },
        goblin = {
            shape = "goblin", hp = 14, speed = 72, damage = 4, gold = 4, radius = 13,
            weight = 15, weight_growth = 4, min_day = 2, color = { 0.62, 0.66, 0.34 },
        },
        ogre = {
            shape = "ogre", hp = 90, speed = 24, damage = 15, gold = 14, radius = 22,
            weight = 4, weight_growth = 3, min_day = 4, color = { 0.62, 0.42, 0.62 }, elite = true,
        },
        -- 중장갑 방패병: 연사 무기(실제 연사 rapid_rate 회/초 이상)의 직접 타격 피해 -70%. 폭발·화상·낙뢰는 그대로
        shield_bearer = {
            shape = "shield", hp = 70, speed = 25, damage = 12, gold = 10, radius = 18,
            weight = 0, weight_growth = 3, min_day = 6, color = { 0.55, 0.58, 0.66 }, elite = true,
            rapid_resist = 0.7, rapid_rate = 1.0,
        },
        -- 그림자 암살자: 빠르지만 감전에 취약 (감전 추가 피해 x shock_vulnerability)
        shadow_assassin = {
            shape = "assassin", hp = 20, speed = 118, damage = 9, gold = 8, radius = 12,
            weight = 0, weight_growth = 3, min_day = 8, color = { 0.30, 0.24, 0.44 }, elite = true,
            shock_vulnerability = 3,
        },
        -- 사령술사가 불러내는 해골 (일반 웨이브에는 없다)
        skeleton = {
            shape = "skeleton", hp = 22, speed = 50, damage = 6, gold = 2, radius = 13,
            weight = 0, weight_growth = 0, min_day = 1, color = { 0.85, 0.82, 0.72 },
        },

        -- 중간 보스 (월 중순 5·15·25…일, data/waves.lua 의 midboss_cycle). 처치하면 연마석·보너스 골드 확정
        mid_vanguard = {        -- 철갑 선봉장: 중장갑 + 넉백 강한 저항 + 둔화 면역, 주기적으로 아군을 이끌고 돌파
            shape = "shield", sprite = "shield_bearer", hp = 300, speed = 23, damage = 28, gold = 40, radius = 24,
            weight = 0, weight_growth = 0, min_day = 1, color = { 0.70, 0.42, 0.36 }, midboss = true, pattern = "vanguard",
            rapid_resist = 0.6, rapid_rate = 1.0, knockback_resist = 0.95, slow_immune = true,
            scale = 1.35, tint = { 1.0, 0.62, 0.52 }, aura = "red",
        },
        mid_raider = {          -- 약탈 대장: 빠르고, 체력이 떨어지면 짧게 돌진 가속
            shape = "goblin", sprite = "goblin", hp = 210, speed = 64, damage = 18, gold = 50, radius = 18,
            weight = 0, weight_growth = 0, min_day = 1, color = { 0.82, 0.70, 0.30 }, midboss = true, pattern = "dash",
            knockback_resist = 0.6, scale = 1.35, tint = { 1.0, 0.86, 0.42 }, aura = "red",
        },
        mid_hexer = {           -- 역병 주술사: 주기적으로 주변 몬스터 이동 속도 · 체력 강화 오라
            shape = "skeleton", sprite = "skeleton", hp = 230, speed = 27, damage = 16, gold = 45, radius = 18,
            weight = 0, weight_growth = 0, min_day = 1, color = { 0.50, 0.80, 0.38 }, midboss = true, pattern = "hex",
            knockback_resist = 0.6, scale = 1.35, tint = { 0.62, 1.0, 0.52 }, aura = "purple",
        },
        mid_stalker = {         -- 균열 추적자: 일정 간격으로 소형 졸개 2마리를 앞쪽에 소환
            shape = "assassin", sprite = "shadow_assassin", hp = 220, speed = 42, damage = 20, gold = 45, radius = 16,
            weight = 0, weight_growth = 0, min_day = 1, color = { 0.52, 0.34, 0.78 }, midboss = true, pattern = "stalker",
            knockback_resist = 0.6, scale = 1.35, tint = { 0.80, 0.58, 1.0 }, aura = "purple",
        },

        -- 월말 대보스 (10·20·30…일, data/waves.lua 의 boss_cycle). pattern 수치는 boss_patterns
        gatekeeper_golem = {
            shape = "golem", hp = 640, speed = 15, damage = 45, gold = 130, radius = 32,
            weight = 0, weight_growth = 0, min_day = 1, color = { 0.52, 0.48, 0.42 }, boss = true, pattern = "web",
        },
        greed_raider = {
            shape = "raider", hp = 520, speed = 19, damage = 35, gold = 150, radius = 26,
            weight = 0, weight_growth = 0, min_day = 1, color = { 0.70, 0.62, 0.28 }, boss = true, pattern = "greed",
        },
        abyss_necromancer = {
            shape = "necro", hp = 560, speed = 14, damage = 50, gold = 170, radius = 28,
            weight = 0, weight_growth = 0, min_day = 1, color = { 0.42, 0.20, 0.30 }, boss = true, pattern = "necro",
        },
        rift_lord = {
            shape = "rift", hp = 620, speed = 13, damage = 60, gold = 220, radius = 34,
            weight = 0, weight_growth = 0, min_day = 1, color = { 0.36, 0.22, 0.58 }, boss = true, pattern = "rift",
        },
        -- 균열에 삼켜진 스승의 잔영 ('스승의 흔적' 마지막 밤): 공방 봉쇄 + 균열 아이기스 (boss_patterns.master)
        boss_master = {
            shape = "master", hp = 5200, speed = 11, damage = 60, gold = 400, radius = 36,
            weight = 0, weight_growth = 0, min_day = 1, color = { 0.46, 0.34, 0.66 }, boss = true, final = true, pattern = "master",
            knockback_resist = 0.95, slow_immune = true,
        },
    },

    -- 고유 패턴 (systems/BossPatterns · systems/MidBossPatterns). 간격은 그 달의 기믹 강도(data/waves.lua 의 escalation)로 나눈다
    boss_patterns = {
        -- 문지기 골렘: interval 초마다 진열장 무기 칸 하나를 거미줄로 봉인 (그 칸은 사격 불가, clicks 번 클릭해 해제)
        web = { interval = 10, first = 3, clicks = 5 },
        -- 탐욕의 약탈자: interval 초마다 골드 steal(x 강도) 강탈, 방벽 도달 전 처치하면 강탈액 x refund_mult 반환
        greed = { interval = 1, steal = 5, refund_mult = 2 },
        -- 심연의 사령술사: summon_interval 초마다 해골 summon_count 마리, shield_interval 초마다 shield_time 초 동안
        -- 받는 피해의 reflect 비율을 방벽 내구도로 반사하는 붉은 보호막 (보호막 하나당 최대 reflect_cap)
        necro = { summon_interval = 6, summon_count = 2, summon_type = "skeleton", shield_interval = 9, shield_first = 4,
            shield_time = 4, reflect = 0.25, reflect_cap = 12 },
        -- 차원의 균열 군주: interval 초마다 물리 면역 ↔ 원소 면역 교대
        rift = { interval = 10, first = "physical" },
        -- 철갑 선봉장: interval 초마다 charge_time 초 동안 이동 x charge_mult, 뒤따르는 ally_radius 안 아군도 x ally_mult
        vanguard = { interval = 7, first = 4, charge_time = 1.6, charge_mult = 1.7, ally_mult = 1.3, ally_radius = 170 },
        -- 약탈 대장: 체력이 threshold 이하면 interval 초마다 dash_time 초 동안 이동 x dash_mult
        dash = { threshold = 0.45, interval = 4, dash_time = 1.1, dash_mult = 2.3 },
        -- 역병 주술사: interval 초마다 radius 안 몬스터 이동 x speed_mult(speed_time 초) + 최대 체력의 heal(x 강도) 회복
        hex = { interval = 5, first = 3, radius = 170, speed_mult = 1.25, speed_time = 3, heal = 0.12 },
        -- 균열 추적자: interval 초마다 summon_type 졸개 count 마리(강도 per_count 마다 +1)를 ahead px 앞쪽에 소환
        stalker = { interval = 6, first = 3, summon_type = "goblin", count = 2, per_count = 0.5, ahead = 70 },
        -- 균열의 잔영 (systems/MasterBossPattern):
        --   공방 봉쇄 — lock_first 초 뒤부터 lock_interval 초마다(강도로 나눔) 무기가 있는 진열장 행 또는 열 하나를 lock_time 초 봉인
        --   균열 아이기스 — 체력이 thresholds 비율 아래로 내려갈 때마다 보호막: 받는 피해 x (1 - reduction).
        --     과부하를 켠 동안 준 피해(감쇄 전)가 최대 체력 x break_ratio 에 닿으면 깨지고 groggy_time 초 그로기(멈춤 · 받는 피해 x groggy_mult)
        master = { lock_first = 4, lock_interval = 9, lock_time = 3.5,
            thresholds = { 0.65, 0.30 }, reduction = 0.75, break_ratio = 0.1, groggy_time = 4, groggy_mult = 1.5 },
    },
}
