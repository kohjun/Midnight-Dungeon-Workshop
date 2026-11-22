-- data/achievements.lua
-- 업적 8종: 달성하면 특수 유물(relic, data/items.lua 의 special 원형)이 영구 해금되어 이후 손님·상점·봉인 상자에 나온다.
-- 달성 기록은 save_meta.lua (systems/MetaProgression). 판정은 systems/Achievements. 이름·조건 문구는 로케일 achievements.<id>.
-- 조건 문구의 자리표시자는 이 표의 값으로 채운다 (Achievements.condition_vars: {level} · {cursed} · {gold} · {percent} = ratio × 100).
-- trigger:
--   forge_level         : 용광로 강화 성공으로 level 단계 이상 도달 (+10 체계에서는 자홍 룬 등급 +7)
--   blood_moon_survived : 핏빛 달 계약을 받고 그 밤을 버텨냄
--   boss_killed         : boss(월말 대보스 몬스터 id) 처치 — 중간 보스는 세지 않는다 (Monster:is_boss)
--   boss_killed_cursed  : 진열장에 저주 유물 cursed 개 이상을 둔 채 아무 월말 대보스나 처치
--   gold_held           : 보유 골드 gold 이상 (한 런 안에서, 고정 금액 — 조건 문구에는 {gold} 로 이 값이 들어간다)
--   gold_ratio          : 보유 골드가 이번 계약의 상권 독점 기준(systems/Endings.monopoly_gold — 계약 일수·마지막 유지비 비례)의
--                         ratio 배 이상 (한 런 안에서) — 30일 계약과 120일 계약의 문턱이 계약 규모만큼 다르다
-- 로직 없음.

return {
    order = {
        "forge_master", "blood_moon", "cursed_quartet", "tycoon",
        "golem_slayer", "raider_slayer", "necro_slayer", "rift_slayer",
    },
    list = {
        forge_master = { relic = "starforge_hammer", trigger = "forge_level", level = 7 },
        blood_moon = { relic = "bloodmoon_chalice", trigger = "blood_moon_survived" },
        cursed_quartet = { relic = "abyss_crown", trigger = "boss_killed_cursed", cursed = 4 },
        tycoon = { relic = "tycoon_ledger", trigger = "gold_held", gold = 3000 },
        golem_slayer = { relic = "golem_heart", trigger = "boss_killed", boss = "gatekeeper_golem" },
        raider_slayer = { relic = "raider_sack", trigger = "boss_killed", boss = "greed_raider" },
        necro_slayer = { relic = "necro_codex", trigger = "boss_killed", boss = "abyss_necromancer" },
        rift_slayer = { relic = "rift_prism", trigger = "boss_killed", boss = "rift_lord" },
    },
}
