-- data/meta.lua
-- 장인 명성(RP) 영구 능력치와 RP 정산 공식. 저장 파일은 세이브 디렉토리의 save_meta.lua. 로직 없음.
-- 이름·효과 문구는 data/locales/<언어>/game.lua 의 meta.<id>.
-- per_level: 레벨마다 더해지는 보너스 (systems/MetaProgression.lua 의 bonuses() 가 합산)

return {
    save_file = "save_meta.lua",

    -- RP = (생존 일수 × per_day + 상납 성공 × per_tribute + 처치 수 / kills_divisor + 클리어 시 clear_bonus) × 난이도 rp_mult
    rp = { per_day = 15, per_tribute = 50, kills_divisor = 5, clear_bonus = 200 },

    order = { "start_capital", "trade", "appraisal_eye", "alchemy", "workshop_design", "black_market" },
    stats = {
        start_capital = {
            max = 5, costs = { 40, 80, 140, 220, 320 },
            per_level = { start_gold = 40 },
        },
        trade = {
            max = 5, costs = { 50, 100, 170, 260, 380 },
            per_level = { sale_bonus = 0.06 },
        },
        appraisal_eye = {
            max = 4, costs = { 60, 120, 200, 320 },
            per_level = { uv_saving = 0.1 },
        },
        alchemy = {
            max = 4, costs = { 70, 140, 240, 380 },
            per_level = { forge_bonus = 0.03 },
        },
        workshop_design = {
            max = 3, costs = { 80, 180, 320 },
            per_level = { max_hp = 10 },
            grid_stage_at_max = 2,
        },
        black_market = {
            max = 4, costs = { 60, 120, 200, 300 },
            per_level = { event_chance = 0.08, summon_discount = 4 },
        },
    },
}
