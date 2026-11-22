-- data/events.lua
-- 암시장 특수 이벤트. 매일 아침 daily_chance 확률(영구 스탯 '암시장 인맥'으로 상승), guaranteed_every 일마다 확정. 로직 없음.
-- 이름·배너·상자 이름 문구는 data/locales/<언어>/game.lua 의 events.<id>, [의뢰] 창의 배경·조건·보상 문구는
-- data/locales/<언어>/guild.lua 의 market_quests.<id>. 제안은 [의뢰] 창에서 수락해야 효과가 생긴다 (systems/BlackMarket).

return {
    daily_chance = 0.35,
    guaranteed_every = 3,
    order = { "mystery_boxes", "fence_request", "blood_moon" },

    events = {
        mystery_boxes = {
            weight = 1, risk = "high",             -- [의뢰] 창에 표시하는 위험도 (data/quests.lua 의 risk_order)
            success_chance = 0.7,            -- 70% 고강화 유물 / 30% 저주 폭탄
            boxes = {
                { price = 70, grades = { "rare" }, levels = { 1, 1 } },
                { price = 140, grades = { "rare", "legendary" }, levels = { 1, 2 } },
                { price = 240, grades = { "legendary" }, levels = { 2, 2 } },
            },
            curse_bomb = { contamination = 60, durability_loss = 50, hp_if_empty = 10 },   -- 유물 하나: 오염 +60 · 내구도 -50%p
        },
        fence_request = {
            weight = 1, risk = "low",
            flaw_sale_mult = 2.5,
        },
        blood_moon = {
            weight = 1, risk = "high",
            hp_mult = 1.5,
            speed_mult = 1.2,
            tribute_discount = 250,
        },
    },
}
