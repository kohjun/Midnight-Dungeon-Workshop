-- data/quests.lua
-- 던전 관리 길드 의뢰 게시판 (systems/GuildQuests · ui/QuestModal). first_day 부터 매일 아침 daily_chance 로 하나가 게시되고
-- (게시판의 대기·진행 중 의뢰가 max_board 개 미만일 때), [의뢰] 창에서 수락해야 진행된다.
--   수락하지 않은 의뢰는 그날 밤이 시작되면 내려간다 (벌칙 없음).
--   수락한 의뢰는 deadline(게시일 + days - 1) 일차의 밤이 끝나는 새벽까지 달성해야 한다 — 못 하면 실패:
--     위약금 = 보상 골드 × penalty_ratio 를 즉시 차감, 골드가 모자라면 남은 몫은 다음 결계 유지비에 더해진다.
-- 4분야 (category): forge = 단조 유물 납품 · appraisal = 감정 적발 · combat = 과부하 시험·보스 토벌 · purify = 정화 납품
--   kind  : "deliver_forged"(강화 levels · 등급 grades 이상 유물 [납품]) | "expose"(위조 인장·숨은 저주 적발 targets 번)
--           | "overclock"(하룻밤 과부하 targets 초 유지 + 생존) | "boss"(within 일 안의 월 중순·월말 보스 처치)
--           | "deliver_clean"(지정 속성 유물을 오염도 0% 로 [납품])
--   targets / levels / grades : 난이도 quest_tier(1 견습 · 2 브로커 · 3 베테랑 · 4 악몽) 번째 값 — 계약 기간에 비례
--   reward : gold(달마다 reward_growth 씩 증가) · stones · discount(다음 결계 유지비 할인 비율) · repair(방벽 긴급 수리)
-- 이름·배경·조건 문구는 data/locales/<언어>/guild.lua 의 quests.<id> · quest_ui.*. 로직 없음.

return {
    first_day = 2,
    daily_chance = 0.8,
    max_board = 3,
    reward_growth = 0.3,
    penalty_ratio = 0.5,
    order = { "forge_delivery", "expose_fraud", "overclock_trial", "boss_hunt", "purify_delivery" },
    category_order = { "forge", "appraisal", "combat", "purify" },

    quests = {
        forge_delivery = { category = "forge", kind = "deliver_forged", weight = 3, days = 4,
            levels = { 3, 4, 5, 6 }, grades = { "common", "rare", "common", "rare" },
            reward = { gold = 150, stones = 1, discount = 0.10 }, risk = "high" },
        expose_fraud = { category = "appraisal", kind = "expose", weight = 3, days = 3,
            targets = { 2, 3, 3, 4 }, reward = { gold = 70, stones = 1 }, risk = "low" },
        overclock_trial = { category = "combat", kind = "overclock", weight = 2, days = 2,
            targets = { 10, 14, 18, 22 }, reward = { gold = 60, stones = 2 }, risk = "mid" },
        boss_hunt = { category = "combat", kind = "boss", weight = 2, within = 2,
            reward = { gold = 90, stones = 1, repair = 25 }, risk = "high" },
        purify_delivery = { category = "purify", kind = "deliver_clean", weight = 3, days = 3,
            elements = { "fire", "lightning", "frost", "curse", "gold" }, element_weights = { 3, 3, 1, 3, 3 },
            reward = { gold = 110, discount = 0.05 }, risk = "none" },
    },

    -- 정화 납품 속성 판정: archetype(아키타입) · damage_type(피해 속성) · ids(원형 id) 중 하나라도 맞으면 그 속성이다
    elements = {
        fire = { archetype = "fire", color = { 1.00, 0.50, 0.20 } },
        lightning = { archetype = "lightning", color = { 0.55, 0.70, 1.00 } },
        frost = { damage_type = "frost", ids = { "cooling_fins" }, color = { 0.62, 0.88, 1.00 } },
        curse = { archetype = "curse", color = { 0.80, 0.30, 0.90 } },
        gold = { archetype = "gold", color = { 1.00, 0.84, 0.30 } },
    },
    category_colors = {
        forge = { 1.00, 0.55, 0.20 }, appraisal = { 0.62, 0.38, 1.00 }, combat = { 0.95, 0.38, 0.38 }, purify = { 0.45, 0.80, 0.95 },
    },
    risk_order = { "none", "low", "mid", "high" },
}
