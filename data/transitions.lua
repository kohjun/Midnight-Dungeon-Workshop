-- data/transitions.lua
-- 화면 전환 연출(ui/TransitionManager) 시간표·색·세기. 로직 없음.
-- 모든 전환은 cover(덮기) → 콜백 → hold(덮은 채 대기) → reveal(걷기) 순서다. 시간 단위는 초.
--   wax_seal     : 난이도 계약 확정 → 인트로. 황동 도장이 내리꽂혀 붉은 밀랍 인장을 찍고, 인장에서 검은 잉크가 번진다
--   lens_iris    : 인트로 → 낮 공방. 황동 감정 확대경 조리개가 닫히고, 암전 순간 UV 십자 눈금이 번쩍인 뒤 열린다
--   shutter_slam : 낮 → 밤. 참나무·연철 방범 셔터가 위아래에서 가속해 쾅 맞물리고, 틈새로 포탈 빛이 스민 뒤 열린다
--   dawn_candle  : 밤 → 아침. 셔터가 내려와 빗장이 걸린 채 정산을 기다리다, 빗장이 풀리고 셔터가 걷히며 호박색 햇살

local INK = { 0.03, 0.02, 0.025 }
local BRASS = { 0.80, 0.62, 0.28 }
local BRASS_DARK = { 0.45, 0.31, 0.12 }

return {
    max_hold = 6,           -- 조건(wait)을 기다리는 최대 시간 (안전장치)
    ink = INK,
    outline = 5,            -- 굵은 잉크 외곽선 두께(px)

    modes = {
        wax_seal = {
            cover = 1.05, hold = 0.12, reveal = 0.55,
            drop = 0.18,            -- 도장이 내리꽂히는 시간 (이때 타격음·흔들림·인장)
            lift = 0.22,            -- 도장이 들려 사라지는 시간
            ink_start = 0.34,       -- 잉크가 번지기 시작하는 시각
            ripples = 3,            -- 잉크 앞쪽 파동 고리 수
            shake = 0.42,
            seal_radius = 56,
            stamp_size = 1.0,
            sound = "seal_stamp",
            wax = { 0.66, 0.09, 0.10 }, wax_dark = { 0.36, 0.03, 0.05 }, brass = BRASS, brass_dark = BRASS_DARK,
            wood = { 0.30, 0.17, 0.09 },
        },
        lens_iris = {
            cover = 0.7, hold = 0.18, reveal = 0.75,
            flash = 0.15,           -- 암전 순간 UV 십자 눈금이 번쩍이는 시간
            ring = 18,              -- 황동 테두리 두께(px)
            blades = 8,
            sound = "iris_brass",
            brass = BRASS, brass_dark = BRASS_DARK, blade = { 0.13, 0.11, 0.12 }, reticle = { 0.74, 0.56, 1.0 },
        },
        shutter_slam = {
            cover = 0.5, hold = 0.45, reveal = 0.6,
            shake = 0.8,
            dust = 90,
            slats = 7,
            sound = "shutter_slam",
            oak = { 0.27, 0.16, 0.09 }, oak_dark = { 0.16, 0.09, 0.05 }, iron = { 0.22, 0.22, 0.25 },
            iron_light = { 0.42, 0.42, 0.46 }, portal = { 0.72, 0.30, 0.95 }, dust_colors = { { 0.42, 0.36, 0.30 }, { 0.30, 0.26, 0.22 } },
        },
        dawn_candle = {
            cover = 0.45, hold = 0.3, reveal = 1.6,
            unbar = 0.45,           -- reveal 앞부분: 빗장이 옆으로 풀린다 (나머지는 셔터가 위로 걷힌다)
            bolt_travel = 300,      -- 빗장이 미끄러지는 거리(px)
            shake = 0.3,
            dust = 60,
            slats = 7,
            sound_cover = "shutter_slam", sound = "bolt_unlock",
            oak = { 0.27, 0.16, 0.09 }, oak_dark = { 0.16, 0.09, 0.05 }, iron = { 0.22, 0.22, 0.25 },
            iron_light = { 0.42, 0.42, 0.46 }, amber = { 1.0, 0.70, 0.32 }, amber_light = { 1.0, 0.86, 0.55 },
            dust_colors = { { 1.0, 0.80, 0.45 }, { 0.95, 0.65, 0.30 }, { 1.0, 0.92, 0.70 } },
        },
    },
}
