-- data/combat.lua
-- 야간 전투 공통 규칙: 밤 길이, 피해 규칙(감전·연사 경감·면역), 치명타, 넉백, 투사체, 과부하. 로직 없음.
-- 몬스터·보스·중간 보스 스펙과 고유 패턴 수치는 data/enemies.lua, 웨이브·보스 일정은 data/waves.lua.
-- 몬스터 이름은 data/locales/<언어>/items.lua 의 monsters.<id>.

return {
    night = {
        duration = 30,              -- 초. 새벽 시각 — 이때 웨이브가 다 끝나 있어야(스폰·보스 출현 끝 + 살아 있는 몬스터 0) 밤이 끝난다
        overtime_max = 40,          -- 새벽이 지나도 몬스터가 남으면 소탕 시간. 이 초를 넘기면(안전장치) 남은 몬스터는 달아난다
    },

    -- 피해 규칙 (systems/DamageRules)
    damage = {
        elemental = { "fire", "lightning", "frost" },     -- 원소 면역에 막히는 피해 종류 (나머지는 물리)
        shock_bonus = 0.2,          -- 감전된 적이 받는 피해 +20% (x 몬스터 shock_vulnerability)
        immune_mult = 0,            -- 면역 피해 배율
    },

    -- 화상 중첩·폭발·낙뢰 연출 반경 등 전투 보조 수치
    area = {
        max_burn_stacks = 9,
    },

    -- 치명타: 무기의 직접 타격마다 chance 확률로 피해 x mult ("combat" 난수 스트림)
    crit = { chance = 0.06, mult = 1.8 },

    -- 넉백 (유물 효과 "knockback", 중량 물리 무기): 포탈 쪽(오른쪽)으로 밀어낸다. 정예·보스는 저항해 무한 경직을 막는다
    -- (몬스터 스펙의 knockback_resist 가 있으면 그 값 — 철갑 선봉장 0.95 등)
    knockback = { elite_resist = 0.5, boss_resist = 0.85 },

    projectiles = {
        target_margin = 85,         -- 레인 오른쪽 끝에서 이만큼 들어온 몬스터부터 조준(px) — 포탈에서 나와 진격하는 모습이 보이도록
        bullet_speed = 900,         -- px/s (유도탄 — 화염·물리·저주 딜러 무기)
        beam_life = 0.14,           -- 레이저 잔상(초)
        beam_width = 4,
    },

    -- 과부하 레버: 연사 x rate_mult · 처치 골드 x gold_mult. 켜 둔 동안 진열장 유물의 내구도 마모가
    -- 과열 위험 계수(overheat_chance, 난이도가 덮어쓴다)에 비례해 빨라진다 (data/durability.lua · systems/Wear)
    overclock = {
        rate_mult = 2.5,
        gold_mult = 2,
        overheat_chance = 0.08,
    },

    hit_flash = 0.1,                -- 피격 시 흰색 점멸(초)
}
