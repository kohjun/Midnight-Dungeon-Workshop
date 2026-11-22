-- data/forge.lua
-- 연금술 용광로 +1 ~ +10 강화 (systems/Forge · entities/Item · ui/FurnaceView · ui/ForgeDrama · ui/ForgeTier). 로직 없음.
--   levels[N] = +N 으로 올리는 시도: gold · stones(연마석) 비용(시작할 때 낸다, 실패해도 돌려주지 않음), chance(기본 성공률),
--               fail = 실패 시 결과 — "keep"(단계 유지) | "down"(-1 하락) | "risk"(destroy 확률로 파괴, 나머지는 -1 하락)
--               (+1 은 실패가 없다). 성공률에는 난이도·영구 스탯·공방 개조 보정을 더한다 (max_chance 상한, 100% 단계는 그대로)
--   power[N]  = +N 의 화력 배율 — 지수 곡선 4.8^(N/10) (+10 = x4.8). 증폭기·유물의 시너지 배율도 같은 배율로 커진다
--   sale_share = 판매가에는 강화 몫(power - 1)의 이 비율만 반영 — 되팔려고 모든 유물을 강화하는 클릭 반복이 이득이 되지 않게
--   강화에 성공하면 내구도가 100% 로 돌아오고(실패는 그대로), +10 은 '불멸 각인' (data/durability.lua)
--   tiers: 시각 등급 — 진열장 칸 테두리·강화 뱃지·포일 색 (+5 황금 · +7 자홍 룬 · +9 심연 신화)
-- 이름·문구는 data/locales/<언어>/ui.lua 의 bench.* · forge_fx.*.

return {
    max_level = 10,
    max_chance = 0.95,
    levels = {
        { gold = 40, stones = 0, chance = 1.00 },
        { gold = 60, stones = 1, chance = 0.88, fail = "keep" },
        { gold = 90, stones = 1, chance = 0.76, fail = "keep" },
        { gold = 135, stones = 2, chance = 0.64, fail = "down" },
        { gold = 195, stones = 2, chance = 0.52, fail = "down" },
        { gold = 270, stones = 3, chance = 0.40, fail = "risk", destroy = 0.15 },
        { gold = 375, stones = 3, chance = 0.30, fail = "risk", destroy = 0.20 },
        { gold = 510, stones = 4, chance = 0.22, fail = "risk", destroy = 0.25 },
        { gold = 675, stones = 5, chance = 0.14, fail = "risk", destroy = 0.30 },
        { gold = 900, stones = 6, chance = 0.08, fail = "risk", destroy = 0.35 },
    },
    power = { 1.17, 1.37, 1.60, 1.87, 2.19, 2.56, 3.00, 3.51, 4.10, 4.80 },
    sale_share = 0.5,

    anticipation = 0.9,         -- 결과 발표 전 긴장 연출(초) — +1 기본 제련
    risky_anticipation = 0.42,  -- 연마석을 쓰는 +2 이상: 짧고 날카로운 가열 맥동 뒤 결과 (ui/ForgeDrama)
    scrap_ratio = 0.15,         -- 파괴 시 고철 회수 = 판매가 × 비율 (공방 개조 용광로 안정화로 증가)
    scrap_min = 5,

    tiers = {
        { from = 5, id = "gold", color = { 1.00, 0.80, 0.30 }, glow = { 1.00, 0.68, 0.18 } },
        { from = 7, id = "rune", color = { 1.00, 0.32, 0.78 }, glow = { 0.86, 0.18, 1.00 } },
        { from = 9, id = "mythic", color = { 0.62, 0.92, 1.00 }, glow = { 0.42, 0.16, 0.86 } },
    },
}
