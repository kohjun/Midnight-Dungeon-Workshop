-- data/attacks.lua
-- 무기 공격 연출(ui/AttackEffects) 종류별 색·크기·수명. 로직 없음.
-- 종류는 유물의 attack_style(있으면) → damage_type 로 정한다. 물리 피해라도 저주 아키타입이면 "curse".
--   fire      : 초승달 화염 검기(crescent_shapes 의 무기) 또는 불티 꼬리 화염탄 → 불꽃 파편 폭발
--   lightning : 무기 정중앙 → 몬스터까지 여러 갈래 지그재그 전격 아크 → 감전 스파크 고리
--   frost     : 고드름 창 투사체(광선이면 얼음 광선) → 육각 서리 결정 파동
--   physical  : 회전하는 강철 도끼날 → 굵은 흑백 잉크 베기 충격파
--   curse     : 일렁이는 암보라 심연 구체 + 검은 잉크 궤적 → 잉크 방울

return {
    -- 히트스톱 (ui/HitStop): 번개 피해·치명타 명중 시 전투 레이어만 잠깐 멈춘다 (실제 시간, 배속과 무관).
    -- 재발동 쿨타임으로 다중 번개·3배속에서도 버벅이지 않게 한다
    hitstop = { lightning = 0.028, crit = 0.034, cooldown = 0.18, shake = 0.12 },
    -- 화염 스플래시 충격 고리 · 넉백 먼지
    splash = { life = 0.32, embers = 10, colors = { { 1.0, 0.62, 0.2 }, { 1.0, 0.88, 0.4 }, { 0.8, 0.22, 0.08 } } },
    knockback = { dust = 8, color = { 0.72, 0.62, 0.48 } },
    muzzle = { life = 0.16, radius = 26, sparks = 5 },      -- 칸 정중앙 점화 플래시
    recoil = 1.0,                                           -- 발사 반동 세기 (ItemRenderer 의 kick)
    ink = { 0.03, 0.02, 0.025 },

    styles = {
        fire = {
            colors = { { 1.0, 0.55, 0.15 }, { 1.0, 0.85, 0.35 }, { 0.85, 0.2, 0.08 } },
            crescent_shapes = { sword = true, hammer = true },
            crescent_radius = 18, ball_radius = 8, trail_per_second = 50,
            impact = { count = 16, ring = 40, life = 0.3 },
        },
        lightning = {
            color = { 0.62, 0.78, 1.0 }, core = { 0.96, 0.98, 1.0 },
            segments = 9, jitter = 16, strands = 3,
            impact = { ring = 30, sparks = 6, life = 0.28 },
        },
        frost = {
            color = { 0.62, 0.9, 1.0 }, core = { 0.94, 0.99, 1.0 },
            shard_length = 22, shard_width = 6,
            impact = { radius = 34, life = 0.4, shards = 8 },
        },
        physical = {
            color = { 0.8, 0.82, 0.86 }, edge = { 1.0, 1.0, 1.0 },
            blade_radius = 13, spin = 16,
            impact = { length = 52, life = 0.22, width = 9 },
        },
        curse = {
            color = { 0.36, 0.1, 0.5 }, core = { 0.78, 0.32, 0.98 },
            radius = 10, trail_per_second = 60,
            trail_colors = { { 0.03, 0.02, 0.025 }, { 0.3, 0.08, 0.42 } },
            impact = { count = 14, ring = 28, life = 0.32 },
        },
    },
}
