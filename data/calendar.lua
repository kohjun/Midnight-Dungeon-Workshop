-- data/calendar.lua
-- 장기 압축 달력 (systems/Calendar): 1개월 = month_days 일. HUD·새벽 정산은 "M개월 D일 (현재/목표일)" 로 보인다.
-- 결계 유지비는 매달 말일(data/balance.lua 의 tribute.every), 중간 보스는 월 중순(5일), 대보스는 월말(10일)에 나온다 (data/waves.lua 의 midboss · boss).
-- 난이도에 seasons = true 가 있으면 season_days 마다 봄 → 여름 → 가을 → 겨울이 바뀐다 (사계절 = 120일 계약).
-- 계절 효과는 난이도 season_scale 로 증폭한다 (배율은 1 에서 멀어지는 만큼, 가산은 그대로 곱):
--   overheat_add    : 과부하 과열 위험도 가산 (마모 가속, data/durability.lua)
--   honest_mult     : 손님이 등급을 정직하게 말할 확률 배율 (낮을수록 위조 증가) · overclaim_add : 부풀려 말할 확률 가산
--   monster_hp_mult : 밤 몬스터 체력 배율 · monster_defense : 몬스터가 받는 피해 감소 비율(방어력)
--   tribute_mult    : 그 계절에 징수하는 결계 유지비 배율
-- 이름·설명 문구는 data/locales/<언어>/ui.lua 의 calendar.*. 로직 없음.

return {
    month_days = 10,
    season_days = 30,
    season_order = { "spring", "summer", "autumn", "winter" },
    seasons = {
        spring = { color = { 0.56, 0.86, 0.46 } },
        summer = { color = { 1.00, 0.52, 0.24 }, overheat_add = 0.02 },
        autumn = { color = { 0.92, 0.64, 0.24 }, honest_mult = 0.7, overclaim_add = 0.1 },
        winter = { color = { 0.62, 0.84, 1.00 }, monster_hp_mult = 1.1, monster_defense = 0.06, tribute_mult = 1.15 },
    },
}
