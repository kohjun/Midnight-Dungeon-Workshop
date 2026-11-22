-- data/endings.lua
-- 엔딩 5종 판정 기준과 연출 수치 (states/EndingState, systems/Endings). 문구는 로케일 ending.<id>.*. 로직 없음.
-- 승리(계약 기간을 버티고 마지막 결계 유지비까지 냄) 직후 판정한다.
--   일반 계약: 우선순위는 base 의 역순 (abyss → monopoly → relocation)
--   진엔딩 캠페인(스승의 흔적, campaign = "master_trace"): 마지막 밤 최종 보스를 봉인진 4/4 점화 상태로 쓰러뜨렸으면 true_dawn,
--   아니면 new_gatekeeper (systems/MasterTrace:ending — data/master_trace.lua 의 endings). 다른 계약의 엔딩은 나오지 않는다.
--   medal  = true  : 이 엔딩을 보면 진행도(systems/Progress)에 '진엔딩 훈장'을 영구 기록
--   hidden = true  : 도감에서 보기 전까지 조건까지 가린 숨은 결말
--   fallback       : 일러스트가 없을 때 대신 깔 그림 + 덮을 색 (tint · tint_alpha — 황금빛 새벽 필터). 그것도 없으면 코드 연출
--   abyss      : 심연 장악    — abyss.difficulty 계약에서 진열장 유물의 abyss.share 이상(최소 abyss.cursed 개)을 저주 유물로 채운 채
--                               최종일 보스 처치 (악몽 계약은 저주 유물이 흔해 몇 개만으로는 저절로 된다 — 진열장을 저주로 '채운' 선택)
--   monopoly   : 던전 상권 독점 — 마지막 결계 유지비를 내고도 "상권 독점 기준" 이상 골드를 남기고 방벽을 min_hp_ratio 이상 지킴
--   relocation : 무사 이주    — 그 밖의 모든 승리 (기본 결말 — 부자라도 방벽을 못 지켰으면 여기)
-- 상권 독점 기준 (계약 규모에 비례, systems/Endings.monopoly_gold) =
--   (per_day × 계약 일수 + upkeep_mult × 마지막 결계 유지비 기본액(할인·가산 전, 난이도·계절 배율 포함)) × scale[난이도] 를
--   round 단위로 반올림. scale = 난이도 경제 규모 (짧은 계약은 하루 벌이가 크고, 사계절·악몽 계약은 운영비가 커서 하루 벌이가 작다)
--   — 기준 금액이 난이도 순서대로 계단(견습 < 브로커 < 베테랑 < 악몽)이 되도록 맞춘다.
--   마스터 장인: 보유 유물(진열장·보관함·작업대·용광로) 중 하나라도 +master_level 이상이면 기준 × master_mult (다시 round 단위로 반올림).
--   예 (작성 시점): 견습 30일 25400 G · 브로커 60일 45100 G · 베테랑 120일 49100 G · 악몽 120일 54500 G.
--   밸런스 시뮬(tools/BalanceSim)의 승리 런 최종 골드 분포(ending status 줄의 gold/need)에 맞춰 per_day · scale 을 다시 맞춘다
--   (목표: 견습·브로커·베테랑 승리 중 상권 독점 40~60%).
-- image  : 엔딩 일러스트 (16:9 · 정사각형도 화면을 덮게 자른다, assets/endings/). camera = ui/KenBurns 키프레임 (그림 안 정규화 위치 x·y, 확대 zoom ≥ 1)
--          파일이 없으면 ui/EndingScenes 가 하늘·성벽·스프라이트로 코드 연출을 그린다.

return {
    order = { "relocation", "monopoly", "abyss", "true_dawn", "new_gatekeeper" },
    base = { "relocation", "monopoly", "abyss" },              -- 일반 계약의 엔딩 (도감 첫 줄)
    campaign = { "true_dawn", "new_gatekeeper" },              -- 스승의 흔적 캠페인의 엔딩 (도감 둘째 줄 + 진엔딩 훈장)
    monopoly = {
        per_day = 1000,         -- 계약 하루당 골드
        upkeep_mult = 0.5,      -- + 마지막 결계 유지비 기본액 × 이 배율 (난이도 경제 규모)
        round = 100,            -- 반올림 단위 (G)
        min_hp_ratio = 0.5,     -- 방벽 내구도 최소 비율 (현재 / 최대)
        master_level = 7,       -- 이 강화 단계 이상 유물을 가지고 있으면
        master_mult = 0.75,     -- 기준 골드 × 이 배율
        scale = { apprentice = 0.8, broker = 0.66, veteran = 0.36, abyss = 0.4 },     -- 난이도 경제 규모 (없으면 1)
    },
    abyss = { difficulty = "abyss", cursed = 4, share = 0.75 },

    list = {
        relocation = {
            style = "silver", sky = { { 0.20, 0.14, 0.22 }, { 0.95, 0.62, 0.38 } }, glow = { 1.0, 0.75, 0.45 },
            image = "assets/endings/ending_relocate.png",
            camera = { { t = 0, x = 0.34, y = 0.42, zoom = 1.16 }, { t = 18, x = 0.58, y = 0.48, zoom = 1.03 } },
        },
        monopoly = {
            style = "gold", sky = { { 0.10, 0.07, 0.04 }, { 0.55, 0.38, 0.12 } }, glow = { 1.0, 0.84, 0.3 },
            image = "assets/endings/ending_monopoly.png",
            camera = { { t = 0, x = 0.28, y = 0.40, zoom = 1.18 }, { t = 18, x = 0.60, y = 0.46, zoom = 1.04 } },
        },
        abyss = {
            style = "blood", sky = { { 0.02, 0.0, 0.04 }, { 0.30, 0.04, 0.12 } }, glow = { 0.75, 0.2, 0.95 },
            image = "assets/endings/ending_abyss.png",
            camera = { { t = 0, x = 0.36, y = 0.44, zoom = 1.16 }, { t = 18, x = 0.64, y = 0.46, zoom = 1.05 } },
        },
        true_dawn = {
            style = "gold", sky = { { 0.30, 0.18, 0.22 }, { 1.0, 0.74, 0.42 } }, glow = { 1.0, 0.82, 0.5 }, medal = true,
            campaign = "master_trace", image = "assets/endings/ending_true.png",
            fallback = { image = "assets/backgrounds/day_workshop.png", tint = { 1.0, 0.74, 0.38 }, tint_alpha = 0.34 },
            camera = { { t = 0, x = 0.50, y = 0.40, zoom = 1.14 }, { t = 20, x = 0.42, y = 0.52, zoom = 1.02 } },
        },
        new_gatekeeper = {
            style = "silver", sky = { { 0.02, 0.02, 0.06 }, { 0.22, 0.14, 0.38 } }, glow = { 0.62, 0.48, 1.0 }, hidden = true,
            campaign = "master_trace",
            camera = { { t = 0, x = 0.5, y = 0.5, zoom = 1.0 }, { t = 20, x = 0.5, y = 0.5, zoom = 1.0 } },
        },
    },
    shade = 0.55,           -- 일러스트 아래쪽(에필로그 글 뒤)을 어둡게 덮는 최대 알파

    -- 연출 시간표 (초)
    title_at = 0.8,
    lines_at = 2.4,
    line_time = 3.4,
    chars_per_second = 26,
    fade = 0.9,
    min_time = 1.5,         -- 이 시간 전에는 건너뛰기 입력을 무시 (결과 화면에서 넘어온 클릭이 바로 넘기지 않도록)
    particles_per_second = 18,
}
