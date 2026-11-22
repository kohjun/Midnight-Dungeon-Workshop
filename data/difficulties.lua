-- data/difficulties.lua
-- 난이도 = 길드 계약서 5장 (states/DifficultyState · ui/ContractCards). order 순서대로 위 줄 rows[1]장 · 아래 줄 rows[2]장.
-- 계약 기간이 길어질수록 운영 압박(결계 유지비 · 자원 소모 · 과부하 마모)과 계절 변화가 함께 커진다. 1개월 = 10일 (data/calendar.lua).
--   days          : 계약 일수 — 30 = 3개월 · 60 = 6개월 · 120 = 1년(사계절)
--   pace          : 밤 웨이브가 강해지는 속도 (실효 일차 = 1 + (일차 - 1) × pace, systems/WaveSpawner) — 긴 계약일수록 완만하다
--   tribute_mult  : 결계 유지비 배율 (data/balance.lua 의 tribute.amounts 월별 금액 ×)
--   supply_mult   : UV 배터리·정화수 소모 배율 (data/balance.lua 의 supplies 기본 소모량 ×)
--   seasons       : true 면 30일마다 봄 → 여름 → 가을 → 겨울 (data/calendar.lua 의 seasons 효과 × season_scale)
--   quest_tier    : 길드 의뢰 목표·납품 조건 단계 (data/quests.lua 의 표에서 몇 번째 값을 쓸지)
--   overclock.rate_mult · gold_mult : 과부하 중 연사 · 처치 골드 배율 (견습은 마모 가속이 없는 대신 x1.4 로 순하다)
--   overclock.overheat_chance : 과부하 과열 위험도 — 마모 가속 x(1 + 값 × 22.2, 상한 3.6) (data/durability.lua · systems/Wear,
--                               0 = 가속 없음, 여름에는 data/calendar.lua 가산)
--   unlock_after  : 이 난이도 중 하나를 클리어하면 해금 (systems/Progress)
--   veiled        : 해금 전에는 그을린 양피지 '???' 봉인 카드로 보이고(누르면 해금 조건 안내), 해금되면 제 모습으로 열린다
--   campaign      : 진엔딩 캠페인 규칙 표 이름 (data/<campaign>.lua — 5단계 스승의 흔적 = data/master_trace.lua, systems/MasterTrace)
--   interference  : true 면 사계절 대신 달마다 포탈 균열 간섭이 단계적으로 커진다 (data/master_trace.lua 의 interference)
-- 이름·요약·브리핑 문구는 data/locales/<언어>/game.lua 의 difficulty.<id>. 로직 없음.

return {
    order = { "apprentice", "broker", "veteran", "abyss", "master_trace" },
    rows = { 3, 2 },            -- 계약서 카드 줄 구성 (위 3장 · 아래 2장)
    default = "apprentice",
    first_run = "apprentice",   -- 처음 플레이(튜토리얼 직행)는 이 난이도
    modes = {
        apprentice = {
            tier_color = "good", days = 30, start_gold = 200, max_hp = 100, forge_bonus = 0.10, tribute_mult = 0.9,
            rp_mult = 1.0, pace = 0.85, supply_mult = 1.0, quest_tier = 1,
            customer = { honest_chance = 0.7, overclaim_chance = 0.5, flaw_chance = 0.35 },
            overclock = { rate_mult = 1.4, gold_mult = 1.4, overheat_chance = 0 },     -- 마모 가속 없는 대신 순한 과부하
        },
        broker = {
            tier_color = "accent", days = 60, start_gold = 180, max_hp = 100, forge_bonus = 0, tribute_mult = 1.4,
            rp_mult = 1.5, pace = 0.43, supply_mult = 1.0, quest_tier = 2,
            customer = { honest_chance = 0.45, overclaim_chance = 0.8, flaw_chance = 0.4 },
            overclock = { rate_mult = 2.5, gold_mult = 2, overheat_chance = 0.035 },
        },
        veteran = {
            tier_color = "overclock", days = 120, start_gold = 180, max_hp = 100, forge_bonus = 0, tribute_mult = 0.95,
            rp_mult = 2.0, pace = 0.203, supply_mult = 1.1, quest_tier = 3, seasons = true, season_scale = 1.0,
            customer = { honest_chance = 0.42, overclaim_chance = 0.82, flaw_chance = 0.45 },
            overclock = { rate_mult = 2.5, gold_mult = 2, overheat_chance = 0.06 },
        },
        abyss = {
            tier_color = "danger", unlock_after = { "veteran" }, days = 120, start_gold = 180, max_hp = 100, forge_bonus = 0,
            tribute_mult = 0.9, rp_mult = 3.0, pace = 0.16, supply_mult = 1.2, quest_tier = 4, seasons = true, season_scale = 1.35,
            customer = { honest_chance = 0.35, overclaim_chance = 0.85, flaw_chance = 0.6, flaw_weights = { crack = 1, curse = 3 },
                legendary_mult = 2.5, cursed_proto_mult = 3 },
            overclock = { rate_mult = 2.5, gold_mult = 2.5, overheat_chance = 0.09 },
            boss = { at = 7, hp_mult = 1.3 },
        },
        -- 5단계 진엔딩 캠페인 '스승의 흔적': 악몽을 클리어하면 영구 해금. 60일 · 악몽 수준의 자원 소모·유지비·마모 압박,
        -- 사계절 대신 달마다 포탈 균열 간섭. 은빛 인장 → 스승의 수기 6편, 봉인 공명 슬롯 4칸, 마지막 밤 최종 보스 (data/master_trace.lua)
        master_trace = {
            tier_color = "uv", veiled = true, campaign = "master_trace", unlock_after = { "abyss" }, days = 60, start_gold = 180,
            max_hp = 100, forge_bonus = 0, tribute_mult = 1.4, rp_mult = 3.0, pace = 0.42, supply_mult = 1.2, quest_tier = 3,
            interference = true,
            customer = { honest_chance = 0.38, overclaim_chance = 0.85, flaw_chance = 0.5, flaw_weights = { crack = 1, curse = 2 },
                legendary_mult = 1.8 },
            overclock = { rate_mult = 2.5, gold_mult = 2.5, overheat_chance = 0.09 },
        },
    },
}
