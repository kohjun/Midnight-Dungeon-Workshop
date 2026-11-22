-- data/master_trace.lua
-- 5단계 진엔딩 캠페인 '스승의 흔적' (data/difficulties.lua 의 master_trace — 악몽 클리어로 영구 해금, systems/MasterTrace).
-- 문구(수기 6편 · 인장 · 봉인진 · 간섭 단계)는 data/locales/<언어>/trace.lua. 로직 없음.
--   60일(6개월) 고정 캠페인: 악몽 수준의 운영 압박(난이도 표) + 사계절 대신 달마다 단계적으로 커지는 포탈 균열 간섭.
--   interference : 간섭 단계 = 지금 달(1~months). 효과는 (단계 - 1) × per_level 만큼 쌓인다 (systems/Calendar.modifiers 가
--                  계절 효과 자리에 넣는다 — 몬스터 체력·방어력(받는 피해 감소) · 과부하 과열 위험도 가산(마모 가속) ·
--                  손님 정직 확률 감소(위조 증가)). 새 달 아침에 calendar:interference_rose
--   journals     : 스승의 수기 6편 (id = 로케일 trace.journal.<id>). opens 일차부터 그 편의 은빛 인장이 손님 유물에 숨을 수 있다
--   clues        : UV 로만 보이는 스승의 은빛 인장 (결함이 아니라 값은 그대로). 다음 수기가 열린 뒤 손님 유물 하나마다 chance,
--                  나올 수 있는데 pity_days 일 동안 한 번도 숨지 않았으면 다음 손님 유물에 반드시 숨긴다 (RNG 불운 보정).
--                  표식 위치는 유물 정규화 좌표 ±mark_range, 결함 표식과 mark_gap 이상 떨어지게
--   resonance    : 진열장 봉인 공명 슬롯 4칸 (row, col) — 그 계열(archetype) +min_level 이상 · 내구도 > 0% 유물이 놓이면 점화.
--                  슬롯에 놓인 유물은 무엇이든 밤 마모 x wear_mult (+10 불멸은 면역). 4칸이 모두 점화되면 center 칸으로 공명선
--   final        : 계약 마지막 날 밤의 최종 보스 (data/enemies.lua 의 boss_master) — 월말 대보스 대신 at 초에 등장
--   endings      : 마지막 밤을 넘겨 승리했을 때 — 보스를 봉인진 4/4 점화 상태로 쓰러뜨리면 sealed, 아니면 failed (data/endings.lua)

return {
    interference = {
        months = 6,
        color = { 0.70, 0.52, 1.00 },
        per_level = { monster_hp = 0.03, monster_defense = 0.01, overheat_add = 0.004, honest_drop = 0.04 },
    },
    journals = {
        { id = "omen", opens = 1 },
        { id = "ledger", opens = 8 },
        { id = "sockets", opens = 18 },
        { id = "resonance", opens = 28 },
        { id = "confession", opens = 38 },
        { id = "last_will", opens = 47 },
    },
    clues = { chance = 0.14, pity_days = 3, mark_range = 0.28, mark_gap = 0.22 },
    resonance = {
        min_level = 5,
        wear_mult = 1.5,
        center = { row = 3, col = 3 },
        slots = {
            { row = 2, col = 2, archetype = "fire" },
            { row = 2, col = 4, archetype = "lightning" },
            { row = 4, col = 2, archetype = "curse" },
            { row = 4, col = 4, archetype = "gold" },
        },
    },
    final = { type = "boss_master", at = 6, hp_mult = 1 },
    endings = { sealed = "true_dawn", failed = "new_gatekeeper" },
}
