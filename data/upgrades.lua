-- data/upgrades.lua
-- 런 내부 공방 시설 개조 ([공방 개조] 패널). levels[k] = k레벨이 되는 비용과 그 레벨의 효과(누적값). 로직 없음.
-- 이름·설명·레벨별 효과 문구는 data/locales/<언어>/game.lua 의 upgrades.<id>.
-- grid 는 levels[k] 가 그리드 단계 k → k+1 로 여는 비용. 시작 단계는 1(3x3), 영구 스탯으로 2(3x4)부터 가능.

return {
    order = { "grid", "lens", "brush", "furnace", "wall" },

    -- 개방 영역 (행·열 범위, 5x5 기준). 나머지 칸은 봉인
    grid_stages = {
        { label = "3x3", rows = { 2, 4 }, cols = { 2, 4 } },
        { label = "3x4", rows = { 2, 4 }, cols = { 1, 4 } },
        { label = "4x4", rows = { 1, 4 }, cols = { 1, 4 } },
        { label = "4x5", rows = { 1, 4 }, cols = { 1, 5 } },
        { label = "5x5", rows = { 1, 5 }, cols = { 1, 5 } },
    },

    upgrades = {
        grid = {
            levels = {
                { cost = 150 },
                { cost = 350 },
                { cost = 700 },
                { cost = 1400 },
            },
        },
        lens = {
            levels = {
                { cost = 120, radius_bonus = 12, drain_mult = 0.8 },
                { cost = 260, radius_bonus = 24, drain_mult = 0.6 },
                { cost = 480, radius_bonus = 30, drain_mult = 0.5, auto_flaw = true },
            },
        },
        brush = {
            levels = {
                { cost = 100, water_mult = 0.75 },
                { cost = 240, water_mult = 0.6, clean_mult = 1.75 },
            },
        },
        furnace = {
            levels = {
                { cost = 150, forge_bonus = 0.05 },
                { cost = 320, forge_bonus = 0.10, scrap_mult = 2 },
                { cost = 600, forge_bonus = 0.15, scrap_mult = 3 },
            },
        },
        wall = {
            levels = {
                { cost = 100, max_hp_bonus = 20 },
                { cost = 220, max_hp_bonus = 45 },
                { cost = 400, max_hp_bonus = 75 },
            },
        },
    },
}
