-- data/armors.lua
-- 방어구 12종 (순수 데이터). 이름·설명·스킬 문구는 로케일 armors.<id> · hero.skills.<id> (data/locales/<언어>/hero.lua).
-- 방어구(category = "armor")는 주인공 전용이다 — 5x5 진열장에 놓을 수 없고, 주인공 장비창의 equip_slot 칸에만 장착한다
-- (systems/HeroEquip). 그 밖의 규칙은 유물과 같다: 모험가 매입(등급 위조·저주·균열 UV 감정) · 길드 상점 · 용광로 +1~+10 ·
-- 내구도 0~100% (주인공이 밤 전투에 참여한 만큼 닳는다 — data/hero.lua 의 wear).
-- 원화: assets/sheets/armors.png (3행 4열, 순흑색 배경 — tools/sprite_black_bg.py) → assets/sprites/armor_<id>.png
--   행 = 부위 slots (투구 · 갑옷 · 신발), 열 = 등급 tiers (일반 · 길드 강철 · 황금 룬 공명 · 심연 균열)
--   share      : 손님·상점·봉인 상자 아이템 중 방어구가 나올 확률 (진열장 무기·유물 수급을 해치지 않는 선)
--                방어구를 가져온 손님은 하루 무료 손님 수를 쓰지 않는 덤 방문이라(systems/Appraisal.new_customer),
--                무기·유물 손님은 예전처럼 하루 3명 그대로다
--   stat_share : 등급 · 세척 · 강화 배율 가운데 방어구 스탯에 실리는 몫 — 스탯 배율 = 1 + (배율 − 1) × stat_share
--   curse      : 저주 결함 방어구 — 스탯 x stat_mult, 대신 x wear_mult 로 빨리 닳는다 (균열은 유물과 같이 마모 x1.6)
--   stats      : 투구 crit(치명타 확률) · resist(저주·상태이상 저항) · cooldown(스킬 쿨타임 감소)
--                갑옷 max_hp(주인공 최대 HP) · defense(방어력 — 방벽 피격 경감) + skill(E 스킬 id, 포탈 결투장에서 쓴다)
--                신발 move_speed(이동속도 보너스) · roll_cooldown(구르기 쿨타임 감소) · roll_invuln(구르기 무적 시간 +초)
--   skills     : 갑옷 E 스킬 — cooldown(초) · 핵심 수치 (문구의 자리표시자를 채운다)

return {
    slots = { "helmet", "chest", "boots" },
    tiers = {
        { id = "plain", weight = 10 },
        { id = "guild", weight = 6 },
        { id = "rune", weight = 3 },
        { id = "rift", weight = 1.4 },
    },
    share = 0.20,
    stat_share = 0.35,
    curse = { stat_mult = 1.3, wear_mult = 1.5 },

    prototypes = {
        -- ── 투구 ──
        kettle_helm = {
            category = "armor", equip_slot = "helmet", tier = 1, element = "ancient", shape = "helmet", value = 30,
            color = { 0.50, 0.50, 0.52 }, accent = { 0.52, 0.32, 0.20 },
            stats = { crit = 0.02, resist = 0.05, cooldown = 0.03 },
        },
        guild_sallet = {
            category = "armor", equip_slot = "helmet", tier = 2, element = "ancient", shape = "helmet", value = 55,
            color = { 0.62, 0.62, 0.66 }, accent = { 0.72, 0.56, 0.30 },
            stats = { crit = 0.035, resist = 0.10, cooldown = 0.06 },
        },
        rune_greathelm = {
            category = "armor", equip_slot = "helmet", tier = 3, element = "ancient", shape = "helmet", value = 90,
            color = { 0.30, 0.29, 0.30 }, accent = { 0.96, 0.76, 0.32 },
            stats = { crit = 0.05, resist = 0.16, cooldown = 0.09 },
        },
        rift_horned_helm = {
            category = "armor", equip_slot = "helmet", tier = 4, element = "arcane", shape = "helmet", value = 140,
            color = { 0.26, 0.23, 0.30 }, accent = { 0.72, 0.46, 0.96 },
            stats = { crit = 0.07, resist = 0.24, cooldown = 0.13 },
        },
        -- ── 갑옷 ──
        leather_jerkin = {
            category = "armor", equip_slot = "chest", tier = 1, element = "ancient", shape = "chest", value = 30,
            color = { 0.50, 0.30, 0.20 }, accent = { 0.74, 0.58, 0.30 },
            stats = { max_hp = 20, defense = 4 }, skill = "brace",
        },
        guild_plate = {
            category = "armor", equip_slot = "chest", tier = 2, element = "ancient", shape = "chest", value = 55,
            color = { 0.60, 0.60, 0.64 }, accent = { 0.50, 0.34, 0.22 },
            stats = { max_hp = 40, defense = 7 }, skill = "guild_bulwark",
        },
        rune_cuirass = {
            category = "armor", equip_slot = "chest", tier = 3, element = "ancient", shape = "chest", value = 90,
            color = { 0.30, 0.29, 0.30 }, accent = { 0.96, 0.76, 0.32 },
            stats = { max_hp = 65, defense = 10 }, skill = "rune_aegis",
        },
        rift_carapace = {
            category = "armor", equip_slot = "chest", tier = 4, element = "arcane", shape = "chest", value = 140,
            color = { 0.26, 0.23, 0.30 }, accent = { 0.72, 0.46, 0.96 },
            stats = { max_hp = 95, defense = 14 }, skill = "rift_shroud",
        },
        -- ── 신발 ──
        leather_boots = {
            category = "armor", equip_slot = "boots", tier = 1, element = "ancient", shape = "boots", value = 30,
            color = { 0.50, 0.30, 0.20 }, accent = { 0.60, 0.60, 0.64 },
            stats = { move_speed = 0.05, roll_cooldown = 0.05, roll_invuln = 0.03 },
        },
        guild_greaves = {
            category = "armor", equip_slot = "boots", tier = 2, element = "ancient", shape = "boots", value = 55,
            color = { 0.60, 0.60, 0.64 }, accent = { 0.50, 0.34, 0.22 },
            stats = { move_speed = 0.09, roll_cooldown = 0.10, roll_invuln = 0.05 },
        },
        rune_sabatons = {
            category = "armor", equip_slot = "boots", tier = 3, element = "ancient", shape = "boots", value = 90,
            color = { 0.30, 0.29, 0.30 }, accent = { 0.96, 0.76, 0.32 },
            stats = { move_speed = 0.13, roll_cooldown = 0.15, roll_invuln = 0.08 },
        },
        rift_striders = {
            category = "armor", equip_slot = "boots", tier = 4, element = "arcane", shape = "boots", value = 140,
            color = { 0.26, 0.23, 0.30 }, accent = { 0.72, 0.46, 0.96 },
            stats = { move_speed = 0.18, roll_cooldown = 0.22, roll_invuln = 0.12 },
        },
    },

    -- 시트 순서 (행 → 열). tools/sprite_black_bg.py 의 ARMOR_NAMES 와 같다
    order = {
        "kettle_helm", "guild_sallet", "rune_greathelm", "rift_horned_helm",
        "leather_jerkin", "guild_plate", "rune_cuirass", "rift_carapace",
        "leather_boots", "guild_greaves", "rune_sabatons", "rift_striders",
    },

    skills = {
        brace = { cooldown = 14, duration = 3, reduction = 0.3 },             -- 버티기: 받는 피해 감소
        guild_bulwark = { cooldown = 16, duration = 4, reduction = 0.45 },    -- 길드 방진: 큰 피해 감소 + 밀려나지 않음
        rune_aegis = { cooldown = 18, duration = 4, shield = 0.35 },          -- 룬 공명 방벽: 최대 HP 비례 보호막
        rift_shroud = { cooldown = 20, duration = 3, reflect = 0.5 },         -- 균열 장막: 무적에 가까운 장막 + 반사
    },
}
