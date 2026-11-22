-- data/hero.lua
-- 주인공(공방주) 수치 (순수 데이터). 장비창 · 스탯 합산은 systems/HeroEquip · systems/HeroStats, 밤 전투 연동은 systems/HeroCombat.
-- 방어구 스탯은 data/armors.lua, 문구는 로케일 hero.* (data/locales/<언어>/hero.lua).
--   slots   : 장비창 칸 순서 = Inventory "hero" 영역의 1~4번 (무기 · 투구 · 갑옷 · 신발)
--   base    : 장비가 없을 때의 기본 스탯. move_speed 는 배율(1 = 기본), roll_* 은 포탈 결투장(2단계)의 구르기
--   caps    : 합산 상한 (강화·등급 배율이 겹쳐도 넘지 않는다)
--   weapon  : attack_share = 장착 무기 공격력 중 주인공의 근접 타격에 실리는 몫 (진열장 사격보다 약하다 — 문 앞 최후 방어선)
--   melee   : 일반 밤 레인 — 방벽 앞 range(px, field_scale 적용 전) 안의 가장 앞선 마물을 interval 초마다 친다.
--             이동속도 보너스의 speed_share 만큼 간격이 줄어든다
--   guard   : 방벽이 맞을 때 주인공이 막는 비율 = 방어력 × per_defense (상한 max)
--   counter : 방벽이 맞은 직후의 반격 — range 안의 가장 앞선 마물에게 공격력 × (base + 이동속도 보너스 × per_speed)
--   wear    : 장착 장비 마모 — data/durability.lua 의 wear.per_second 대비 배율(per_second) · 타격 1회(per_strike = per_shot 배율)
--             · 방어 1회당 방어구 %p(per_block). 과부하 가속은 받지 않는다 (과부하는 진열장 회로를 몰아붙인다)
--   skills  : 액티브 스킬 3종 — Q = 장착 무기(피해 속성별) · E = 장착 갑옷(data/armors.lua 의 skill) · R = 공방주 과부하 각성.
--             cooldown 은 기본 쿨타임(초, 투구의 쿨타임 감소가 줄인다) · power 는 공격력 배율. 2단계 포탈 결투장에서 쓴다

return {
    slots = { "weapon", "helmet", "chest", "boots" },

    base = {
        max_hp = 100, attack = 4, defense = 0, crit = 0.05, crit_mult = 1.8,
        move_speed = 1.0, roll_cooldown = 1.2, roll_invuln = 0.25, resist = 0, cooldown = 0,
    },
    caps = { crit = 0.6, defense = 60, resist = 0.8, cooldown = 0.5, move_speed = 2.0, roll_cooldown_min = 0.4 },

    weapon = { attack_share = 0.4 },
    melee = { range = 95, interval = 1.1, speed_share = 0.5 },
    guard = { per_defense = 0.006, max = 0.3 },
    counter = { base = 0.35, per_speed = 0.8, range = 140 },
    wear = { per_second = 0.5, per_strike = 1.0, per_block = 0.15 },

    skills = {
        weapon = {                                   -- Q: 장착 무기의 피해 속성 (저주 무기는 curse)
            fire = { id = "ember_smash", cooldown = 8, power = 2.4 },
            lightning = { id = "chain_surge", cooldown = 7, power = 1.6 },
            frost = { id = "frost_cleave", cooldown = 9, power = 1.8 },
            physical = { id = "crushing_blow", cooldown = 8, power = 2.8 },
            curse = { id = "blood_brand", cooldown = 10, power = 3.2 },
        },
        unarmed = { id = "bare_swing", cooldown = 6, power = 1.5 },       -- Q: 무기 없음
        bare_chest = { id = "steady_breath", cooldown = 20 },             -- E: 갑옷 없음
        overdrive = { id = "overdrive_awakening", cooldown = 45, duration = 8, power = 1.5 },     -- R: 공방주 과부하 각성
    },
}
