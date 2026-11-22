-- data/shop.lua
-- 길드 보급 상점 (상납 성공 직후). 소모품은 여러 번 살 수 있고, 희귀 유물은 방문마다 1점. 로직 없음.
-- day_offers 는 낮 영업 중에도 [길드] 창(ui/GuildModal)에서 같은 값에 살 수 있다.
-- daily_limit 이 있는 상품(연마석)은 하루 구매 수량이 제한된다 (아침마다 초기화, 낮·상납 직후 상점 합산).
-- 이름·설명 문구는 data/locales/<언어>/game.lua 의 shop.<id>.

return {
    order = { "uv_pack", "water_barrel", "repair_kit", "tempering_stone", "appraisal_scroll", "rare_relic" },
    day_offers = { "water_barrel", "uv_pack", "repair_kit", "tempering_stone" },
    offers = {
        uv_pack = { price = 45, kind = "supply", supply = "uv", amount = 60 },
        water_barrel = { price = 45, kind = "supply", supply = "water", amount = 60 },
        repair_kit = { price = 60, kind = "repair", amount = 30 },
        tempering_stone = { price = 60, kind = "stone", amount = 1, daily_limit = 1 },
        appraisal_scroll = { price = 80, kind = "scroll", amount = 1 },
        rare_relic = { kind = "relic", grade = "rare", price_mult = 1.4 },
    },
}
