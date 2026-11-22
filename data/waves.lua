-- data/waves.lua
-- 밤 웨이브 스케줄 (systems/WaveSpawner). 실효 일차(wave_day = 1 + (일차-1) × 난이도 pace)에 따라 간격·체력·구성·동시 출현 수가 변한다.
-- 2단계 물량: 예전(간격 2.0초 시작) 대비 같은 실효 일차의 총 스폰 수가 약 1.6~1.9배 (tools/SmokeWaves 가 검사한다).
--   interval_*   : 일반 스폰 간격(초) — 시작 · 일차마다 감소 · 최저
--   group_every_days : 이 실효 일차마다 한 번에 나오는 수 +1
--   packs        : 돌격 무리(Pack Burst) — 밤 at 초에 count + per_day × (실효 일차-1) 마리를 포탈에서 한꺼번에 (types 중에서, 없으면 웨이브 구성)
--   boss / midboss : 월말(10·20·30…일) 대보스 · 월 중순(5·15·25…일) 중간 보스 — 밤 at 초에 등장 (난이도 boss · midboss 규칙이 덮어쓴다)
--   late         : 중후반 위협 — 실효 일차 late.from 이후 n 일마다 체력 x (1 + late.hp × n) · 방벽 피해 x (1 + late.damage × n).
--                  체력 배율은 그 밤의 모든 몬스터(우두머리 포함 — hp_growth · 계절 · 핏빛 달처럼)가 함께 받고,
--                  방벽 피해 배율은 일반 몬스터(돌격 무리·소환 포함)만 받는다 — 우두머리의 피해는 escalation 의 달별 배율만.
--                  초반은 그대로, 중후반에 새는 몬스터가 더 아프다 (밤 방어선 돌파가 패배의 주원인이 되도록)
--   escalation   : 달이 지날수록 보스·중간 보스 능력치와 기믹 강도 상승 — 강도 = 1 + per_month × (달-1) (상한 max),
--                  체력 x (1 + hp_per_month × (달-1)) — 그 밤의 체력 배율 위에 곱한다, 방벽 피해 x (1 + damage_per_month × (달-1))
--   midboss.reward : 중간 보스 처치 확정 보상 — 연마석 stones · 골드 gold + gold_per_month × (달-1) (systems/Drops)
--   crowd_cap    : 하룻밤 몬스터 수 상한 (프레임 · 레인 시인성, systems/WaveCrowd). 일반 스폰 + 돌격 무리의 계획 물량이 per_night 를
--                  넘으면 넘는 비율 r 만큼 마릿수를 1/r 로 줄이고, 정예 가중치 x(1 + elite_weight × (r - 1)) · 개별 체력 배율로
--                  그 밤의 총 체력을 메운다 (hp_share = 메우는 몫 — 적고 단단한 몬스터가 연쇄·범위 무기에 덜 맞는 만큼 1 보다 작게,
--                  밸런스 시뮬로 예전 승률에 맞춘 값). total = 우두머리·소환(해골·졸개)까지 합친 그 밤 레인 몬스터 상한 (소환을 막는다).

return {
    first_delay = 0.8,
    spawn_window = 24,
    interval_start = 1.5,
    interval_decay = 0.055,
    interval_min = 0.36,
    hp_growth = 0.2,
    late = { from = 5, hp = 0.04, damage = 0.05 },
    group_every_days = 6,
    packs = {
        { at = 6, count = 1, per_day = 0.25, types = { "goblin", "slime" } },
        { at = 13, count = 1, per_day = 0.35, types = { "goblin", "ogre", "shield_bearer" } },
        { at = 20, count = 2, per_day = 0.45, types = { "ogre", "shield_bearer", "shadow_assassin" } },
    },
    pack_spacing = 26,          -- 돌격 무리 안 몬스터 사이 가로 간격(px, 반경 배율 아님)
    crowd_cap = { per_night = 100, total = 130, elite_weight = 0.3, hp_share = 0.8 },

    boss = { every = 10, offset = 0, at = 9, hp_mult = 1 },
    midboss = { every = 10, offset = 5, at = 11, hp_mult = 1, reward = { stones = 1, gold = 40, gold_per_month = 12 } },
    boss_cycle = { "gatekeeper_golem", "greed_raider", "abyss_necromancer", "rift_lord" },
    midboss_cycle = { "mid_vanguard", "mid_raider", "mid_hexer", "mid_stalker" },
    escalation = { per_month = 0.1, max = 2.2, hp_per_month = 0.08, damage_per_month = 0.08 },
}
